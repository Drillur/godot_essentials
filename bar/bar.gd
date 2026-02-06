class_name Bar
extends MarginContainer


@export var kill_background := false
@export var default_color: Color
@export var animate := false
@export var color_red_to_green := false
@export var display_pending := false
@export var logarithmic_mode := false ## Progress is based on the log values
@export var performant_updates: bool = true

var color: Color:
	set(val):
		color = val
		progress_bar.modulate = color
var progress: float = -1:
	set(val):
		var previous: float = progress
		if is_equal_approx(previous, val):
			return
		progress = val
		bar_size.set_to(roundi(minf(progress * size.x, size.x)))
		if color_red_to_green:
			update_color()
		if animate:
			new_animation(previous, progress)
var queue: Queueable
var bar_size: LoudInt = LoudInt.new(-1)
var resize_queued := false
var visible_in_tree := false
var timer: LoudTimer
var timer_inverted_mode := false
var value: Resource
var watched_color: LoudColor
var color_alpha: float
var tween: Tween

#region Onready Variables

@onready var progress_bar: Panel = %"Progress Bar" as Panel
@onready var edge: Panel = %Edge as Panel
@onready var control: Control = %Control as Control
@onready var background: Panel = %background
@onready var animation_container: MarginContainer = %AnimationContainer

#endregion



func _ready() -> void:
	set_process(false)
	
	if performant_updates:
		queue = await Queueable.new_node_queueable(self, Queueable.CooldownType.DURATION, 0.25)
	else:
		queue = await Queueable.new_node_queueable(self, Queueable.CooldownType.PHYSICS_PROCESS)
	
	if default_color != Color.BLACK:
		color = default_color
	if kill_background:
		background.hide()
	call_deferred("_on_resized")
	bar_size.changed.connect(bar_size_changed)
	if resize_queued:
		bar_size_changed()
	visibility_changed.connect(_on_visibility_changed)
	tree_exiting.connect(kill_tween)


func _on_resized():
	if not is_node_ready():
		resize_queued = true
		return
	bar_size.set_to(min(progress * size.x, size.x))
	progress_bar.size.y = size.y


func bar_size_changed() -> void:
	progress_bar.size = Vector2(bar_size.get_value(), size.y)


func _on_visibility_changed():
	if visible:
		animation_cd.start()





# - Action


func stop() -> void:
	set_process(false)
	progress = 0.0


func hide_edge() -> void:
	edge.hide()


func show_edge() -> void:
	edge.show()


func attach_float(_float: LoudFloat) -> void:
	var update = func():
		set_deferred("progress", _float.get_value())
	queue.method = update
	_float.changed.connect(queue.call_method)
	queue.call_method()


func attach_int(x: LoudInt, divisor := 1.0) -> void:
	var update = func():
		set_deferred("progress", float(x.get_value()) / divisor)
	queue.method = update
	x.changed.connect(queue.call_method)
	queue.call_method()


func attach_float_pair(_float_pair: LoudFloatPair) -> void:
	clear_value()
	value = _float_pair
	queue.method = update_progress
	value.changed.connect(queue.call_method)
	value.filled.connect(queue.call_method)
	queue.call_method()


func attach_int_pair(_int_pair: LoudIntPair) -> void:
	clear_value()
	value = _int_pair
	queue.method = update_progress
	value.changed.connect(queue.call_method)
	value.filled.connect(queue.call_method)
	queue.call_method()


func attach_big_float_pair(_bfp: BigFloatPair) -> void:
	clear_value()
	value = _bfp
	queue.method = update_progress
	if display_pending:
		value.pending_changed.connect(queue.call_method)
	value.changed.connect(queue.call_method)
	value.filled.connect(queue.call_method)
	queue.call_method()



func clear_value() -> void:
	if not value:
		return
	if display_pending:
		value.pending_changed.disconnect(queue.call_method)
	stop_animation()
	value.changed.disconnect(queue.call_method)
	value.filled.disconnect(queue.call_method)
	value = null
	queue.clear()


func update_progress() -> void:
	if value:
		if display_pending:
			set_deferred("progress", value.get_pending_percent())
		else:
			set_deferred("progress", value.get_current_percent())


func attach_color(_color: LoudColor, _alpha := 1.0) -> void:
	if watched_color:
		if watched_color == _color:
			return
		clear_color()
	color_alpha = _alpha
	watched_color = _color
	queue.method = color_changed
	watched_color.changed.connect(queue.call_method)
	queue.call_method()


func color_changed() -> void:
	var _color: Color = watched_color.get_value()
	_color.a = color_alpha
	color = _color


func clear_color() -> void:
	if not watched_color:
		return
	watched_color.changed.disconnect(queue.call_method)
	watched_color = null
	queue.clear()


func update_color():
	color = Utility.get_red_to_green_fade(progress)


# - Timer based


func _process(_delta) -> void:
	if timer_inverted_mode:
		set_deferred("progress", timer.get_inverted_percent())
	else:
		set_deferred("progress", timer.get_percent())


func attach_timer(_timer: LoudTimer, _timer_inverted_mode := false) -> void:
	assert(_timer != null, "You're attaching a null time. fix ur broken shit")
	if timer != null:
		timer = null
	timer_inverted_mode = _timer_inverted_mode
	timer = _timer
	set_process(true)


func clear_timer() -> void:
	timer = null
	set_process(false)
	queue.clear()


#region Animate


var animation_cd := LoudTimer.new(0.35)


func new_animation(_previous: float, _next: float) -> void:
	if Settings.play_bar_animations.is_false():
		return
	if animation_cd.is_running():
		return
	var delta := absf(_next - _previous)
	var highlight_size := minf(size.x, delta * size.x)
	if highlight_size < 5:
		return
	
	animation_container.size.x = highlight_size
	animation_container.size.y = size.y
	animation_container.modulate = color
	animation_container.get_node("Panel").custom_minimum_size.x = animation_container.size.x
	if _previous < _next:
		animation_container.get_node("Panel").size_flags_horizontal = Control.SIZE_SHRINK_END
		animation_container.position.x = edge.position.x + 1 - animation_container.size.x
	else:
		animation_container.get_node("Panel").size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
		animation_container.position.x = edge.position.x
	animation_container.show()
	
	var tween_existed: bool = tween != null and tween.is_valid()
	kill_tween()
	tween = get_tree().create_tween()
	if not tween_existed:
		tween.tween_interval(0.15)
	tween.tween_property(animation_container.get_node("Panel"), "custom_minimum_size", Vector2(0, size.x), 0.25).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN)
	tween.tween_callback(animation_container.hide)


func stop_animation() -> void:
	animation_container.hide()
	kill_tween()


func kill_tween() -> void:
	Utility.kill_tween(tween)


#endregion


#region Price


var price: Price


func attach_price(_price: Price) -> void:
	price = _price
	if not is_node_ready():
		await ready
	progress = 0.0
	queue.method = update_by_price
	queue.enable_looping()
	call_method()


func call_method() -> void:
	queue.call_method()


func update_by_price() -> void:
	set_progress_by_price()
	update_edge_by_price()


func update_edge_by_price() -> void:
	if display_pending:
		edge.set_deferred("visible", not is_equal_approx(price.get_pending_progress_percent(), 1.0))
	else:
		edge.set_deferred("visible", not is_equal_approx(price.get_progress_percent(), 1.0))


func set_progress_by_price() -> void:
	if display_pending:
		set_deferred("progress", price.get_pending_progress_percent())
	else:
		if logarithmic_mode:
			set_deferred("progress", price.get_logarithmic_progress_percent())
		else:
			set_deferred("progress", price.get_progress_percent())


#endregion
