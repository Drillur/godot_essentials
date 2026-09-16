class_name Queueable
extends RefCounted

signal method_called

enum CooldownType { PROCESS, PHYSICS_PROCESS, DURATION }
enum QueueType { NODE, RESOURCE }

var type: QueueType

var cooldown := false
var cooldown_type: CooldownType
var cooldown_duration: float = -1.0

var queued := false
var method: Callable:
	set = _set_method

var node: CanvasItem
var parent: CanvasItem
var parent_visible_in_tree := false

#region Static

static func new_node_queueable(
		_node: CanvasItem,
		_cooldown_type := CooldownType.PROCESS,
		_cooldown_duration := -1.0,
) -> Queueable:
	var queue := Queueable.new(QueueType.NODE, _cooldown_type, _cooldown_duration)
	queue.node = _node
	if not queue.node.is_node_ready():
		await queue.node.ready
	queue.parent = queue.node.get_parent()
	if not queue.parent.is_node_ready():
		await queue.parent.ready
	queue.node.visibility_changed.connect(queue.on_visibility_changed)
	queue.parent.visibility_changed.connect(queue.on_visibility_changed)
	queue.on_visibility_changed()
	return queue


static func new_resource_queueable(
		_cooldown_type := CooldownType.PROCESS,
		_cooldown_duration := -1.0,
) -> Queueable:
	var queue := Queueable.new(QueueType.RESOURCE, _cooldown_type, _cooldown_duration)
	return queue


## Creates a resource Queueable with CooldownType.DURATION equal to
## [code]duration[/code]
static func new_duration_resource(duration: float) -> Queueable:
	return new_resource_queueable(CooldownType.DURATION, duration)


static func call_deferred_duration(_method: Callable, duration: float = 1.0) -> void:
	await Utility.timer(duration)
	_method.call()

#endregion

#region Init

func _init(_type: QueueType, _cooldown_type: CooldownType, _cooldown_duration := -1.0) -> void:
	type = _type
	cooldown_type = _cooldown_type
	cooldown_duration = _cooldown_duration

#endregion

#region Setters

func _set_method(val: Callable) -> void:
	if method:
		if method == val:
			return
	reset()
	method = val

#endregion

#region Node

func on_visibility_changed():
	parent_visible_in_tree = (
			parent.is_visible_in_tree() if parent is CanvasItem
			else node.is_visible_in_tree())
	if parent_visible_in_tree and queued:
		queued = false
		method.call()
		method_called.emit()

#endregion

#region Method

#region Interact

func call_method() -> void:
	if not is_method_assigned():
		return

	if queued:
		return
	if Main.done.is_false() and type == QueueType.NODE:
		queued = true
		await Main.done.await_true()
		queued = false
	if cooldown:
		queued = true
		return

	var should_enqueue: bool = type == QueueType.NODE and (
			not parent_visible_in_tree
			or not node.visible)
	if should_enqueue:
		queued = true
		return

	queued = false
	method.call_deferred()
	cooldown = true
	method_called.emit()

	await _cooldown_period()

	if _should_call_method_again():
		cooldown = false
		if queued:
			queued = false
			call_method()


func _should_call_method_again() -> bool:
	if not is_method_assigned():
		return false
	if type == QueueType.RESOURCE:
		return true
	# type == QueueType.NODE
	return is_instance_valid(node) and is_instance_valid(parent)


func reset() -> void:
	queued = false
	cooldown = false


func clear() -> void:
	reset()


func enable_looping() -> void:
	if not method_called.is_connected(call_method):
		method_called.connect(call_method)


func disable_looping() -> void:
	if method_called.is_connected(call_method):
		method_called.disconnect(call_method)


func _cooldown_period() -> void:
	match cooldown_type:
		CooldownType.PROCESS:
			await Utility.process()
		CooldownType.PHYSICS_PROCESS:
			await Utility.physics()
		CooldownType.DURATION:
			await Utility.timer(cooldown_duration)


## Connects [param sig] to [method call_method]
func connect_signals(sigs: Array[Signal]) -> void:
	for sig: Signal in sigs:
		sig.connect(call_method)

#endregion

#region Get

func is_method_assigned() -> bool:
	return method != null

#endregion

#endregion
