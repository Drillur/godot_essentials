class_name FlyingText
extends Control


const DEFAULT_LINGER_DURATION: float = 0.3

static var available_nodes: Array[FlyingText]
static var pending_currencies: Dictionary # dict of dicts. first key: the spawner_node

var tween: Tween
var linger_duration: float = DEFAULT_LINGER_DURATION

#region Onready Var

@onready var icon: TextureRect = %Icon
@onready var label: RichLabel = %Label
@onready var margin_container: MarginContainer = $MarginContainer
@onready var crit_label: RichLabel = %crit_label

#endregion


#region Init


static func cache() -> void:
	LORED.signals.lored_killed.connect(validate_texts)


func _ready() -> void:
	hide()
	crit_label.hide()
	margin_container.position = Vector2(
		randf_range(0, size.x) - (margin_container.size.x / 2),
		randf_range(0, size.y) - (margin_container.size.y / 2)
	)
	tree_exiting.connect(kill_tween)


#endregion


func set_text(_text: String) -> void:
	label._set_text(_text)
	label.show()


func set_crit_text(_text: String) -> void:
	crit_label._set_text(_text)
	crit_label.show()


func set_icon(_icon: Texture2D) -> void:
	if _icon:
		icon.texture = _icon
		icon.show()


func go(_spawn_node: Node) -> void:
	set_deferred("size", get_parent().size)
	await Utility.process()
	margin_container.position = Vector2(
		randf_range(0, size.x) - (margin_container.size.x / 2),
		randf_range(0, size.y) - (margin_container.size.y / 2)
	)
	show()
	animate_normal()


func animate_normal() -> void:
	tween = create_tween()
	var new_pos := Vector2(position.x, position.y - randf_range(20, 25))
	tween.tween_property(self, "position", new_pos, 0.5).set_trans(
			Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
	tween.tween_interval(linger_duration)
	tween.tween_property(self, "modulate", Color(1, 1, 1, 0), 0.2).set_trans(
			Tween.TRANS_SINE).set_ease(Tween.EASE_IN)
	tween.finished.connect(_become_available)


func kill_tween() -> void:
	Utility.kill_tween(tween)


func _become_available() -> void:
	hide()
	linger_duration = 0.3
	label._set_text("")
	crit_label.hide()
	modulate = Color(1, 1, 1, 1)
	position = Vector2.ZERO
	process_mode = PROCESS_MODE_DISABLED
	available_nodes.append(self)


#region Static


static func cannot_throw(_spawn_node: Node) -> bool:
	return (
			not _spawn_node.is_visible_in_tree()
			or not _spawn_node.can_process()
			or not Utility.running_above_minimum_fps())


static func new_text_with_icon(
		_spawn_node: Node, _text: String, _icon: Texture2D,
		_color := Color.WHITE, _crit_text := "") -> void:
	
	if cannot_throw(_spawn_node):
		return
	var prefab: FlyingText = _get_node(_spawn_node)
	prefab.set_icon(_icon)
	prefab.set_text(_text)
	if not _crit_text.is_empty():
		prefab.set_crit_text(_crit_text)
	prefab.go(_spawn_node)


static func new_text(
		_spawn_node: Node, _text: String, ignore_conditions := false,
		_linger_duration := DEFAULT_LINGER_DURATION) -> void:
	
	if not ignore_conditions and cannot_throw(_spawn_node):
		return
	var prefab: FlyingText = _get_node(_spawn_node)
	prefab.icon.hide()
	prefab.set_text(_text)
	prefab.linger_duration = _linger_duration
	prefab.go(_spawn_node)


static func new_icon(_spawn_node: Node, _icon: Texture2D) -> void:
	if cannot_throw(_spawn_node):
		return
	var prefab: FlyingText = _get_node(_spawn_node)
	prefab.label.hide()
	prefab.set_icon(_icon)
	prefab.go(_spawn_node)


static func got_currencies(
		_spawn_node: Control,
		currencies: Dictionary,
		_consolidate: bool,
		_crit_mutliplier: Big = Big.new(1.0),
		gained := true
	) -> void:
	
	const BASE_TEXT: String = "[b]%s%s[/b]"
	const BASE_CRIT_TEXT: String = " [font_size=10][i]x[b]%s"
	const CRIT_MULTIPLIER: String = "crit_multiplier"
	
	if cannot_throw(_spawn_node):
		return
	
	if _consolidate and pending_currencies.has(_spawn_node):
		for currency_key in currencies.keys():
			pending_currencies[_spawn_node].get_or_add(
				currency_key,
				Big.new(Big.ZERO)
			).plus_equals(currencies[currency_key])
		var current_mult: Big = pending_currencies[_spawn_node].get(
			CRIT_MULTIPLIER,
			Big.new(1.0)
		)
		if _crit_mutliplier.is_greater_than(current_mult):
			pending_currencies[_spawn_node][CRIT_MULTIPLIER] = _crit_mutliplier
		return
	
	if _consolidate:
		pending_currencies[_spawn_node] = {}
	
	var crit_text: String = ""
	if _crit_mutliplier.is_greater_than(1.0):
		crit_text = BASE_CRIT_TEXT % _crit_mutliplier.get_text()
	var _sign := "+" if gained else "-"
	for x in currencies:
		if (
			not is_instance_valid(_spawn_node)
			or _spawn_node.is_queued_for_deletion()
		):
			return
		
		var color: Color = Currency.get_color(x)
		var _text: String = BASE_TEXT % [_sign, currencies[x].get_text()]
		new_text_with_icon(
				_spawn_node, _text, Currency.get_icon(x), color, crit_text)
		
		await Utility.timer(LoudTimer.MINIMUM_DURATION)
	
	if _consolidate:
		await Utility.timer(randf_range(0.9, 1.25))
		
		if (
			not is_instance_valid(_spawn_node)
			or _spawn_node.is_queued_for_deletion()
			or not pending_currencies.has(_spawn_node)
		):
			return
		
		var _pending_currencies: Dictionary = pending_currencies[_spawn_node]
		pending_currencies.erase(_spawn_node)
		if _pending_currencies.is_empty():
			return
		
		var crit_multiplier: Big = _pending_currencies.get(
				CRIT_MULTIPLIER, Big.new(1.0))
		_pending_currencies.erase(CRIT_MULTIPLIER)
		got_currencies(
			_spawn_node,
			_pending_currencies,
			_consolidate,
			crit_multiplier,
			LoudFloat.ONE
		)


static func lost_currencies(
		_spawn_node: Control, currencies: Dictionary) -> void:
	got_currencies(_spawn_node, currencies, false, Big.new(1.0), false)


static func _get_node(_spawn_node: Node) -> FlyingText:
	const SCENE_NAME: StringName = &"flying_text"
	
	var prefab: FlyingText
	var no_node_available: bool = (
			available_nodes.is_empty()
			or not is_instance_valid(available_nodes.back()))
	
	if no_node_available:
		prefab = ResourceBag.instantiate(SCENE_NAME)
	else:
		prefab = available_nodes.pop_back()
	
	# Reparents the node only if the previous parent was a different node
	if prefab.get_parent():
		if prefab.get_parent() != _spawn_node:
			prefab.get_parent().remove_child(prefab)
			_spawn_node.add_child(prefab)
			prefab.owner = Main.instance
	else:
		_spawn_node.add_child(prefab)
	
	prefab.process_mode = PROCESS_MODE_INHERIT
	return prefab


static func validate_texts() -> void:
	var invalid: Array[FlyingText] = []
	for text: FlyingText in available_nodes:
		if not is_instance_valid(text):
			invalid.append(text)
	for text: FlyingText in invalid:
		available_nodes.erase(text)


#endregion
