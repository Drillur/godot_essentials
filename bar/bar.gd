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
	set = _set_color
var progress: float = -1:
	set = _set_progress
var queue: Queueable
var bar_size: LoudInt = LoudInt.new(-1)

#region Onready Variables

@onready var progress_bar: Panel = %"Progress Bar"
@onready var edge: Panel = %Edge
@onready var control: Control = %Control
@onready var background: Panel = %background
@onready var animation_container: MarginContainer = %AnimationContainer

#endregion

#region Ready

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

	bar_size.changed.connect(_update_progress_bar_size_x)
	_update_progress_bar_size_x()

	visibility_changed.connect(_on_visibility_changed)
	tree_exiting.connect(kill_tween)

	resized.connect(_on_resized)
	_on_resized.call_deferred()

#endregion

#region Setters

func _set_color(new_color: Color) -> void:
	if color == new_color:
		return
	color = new_color
	progress_bar.modulate = color


func _set_progress(new_progress: float) -> void:
	var previous: float = progress
	if is_equal_approx(previous, new_progress):
		return
	progress = new_progress
	bar_size.set_to(floori(progress * size.x))
	if color_red_to_green:
		color = Utility.get_red_to_green_fade(progress)
	if animate:
		new_animation(previous, progress)

#endregion

#region Signals

func _on_resized():
	bar_size.custom_maximum_limit = floori(size.x)
	bar_size.set_to(floori(progress * size.x))
	progress_bar.size.y = size.y


func _on_visibility_changed():
	if visible:
		animation_cd.start()

#endregion

#region Update

func _update_progress_bar_size_x() -> void:
	progress_bar.size.x = bar_size.val()

#endregion

#region Attachments

func attach_timer(timer: LoudTimer, timer_inverted_mode := false) -> void:
	assert(timer != null, "Why is timer null?")

	var update: Callable

	if timer_inverted_mode:
		update = func() -> void:
			set_deferred("progress", timer.get_inverted_percent())
	else:
		update = func() -> void:
			set_deferred("progress", timer.get_percent())

	get_tree().process_frame.connect(update)

#region - Color

var watched_color: LoudColor


func attach_color(_color: LoudColor) -> void:
	if watched_color:
		assert(watched_color != _color, "Why assigning this LoudColor twice?")
		if watched_color == _color:
			return
		_clear_color()
	watched_color = _color
	queue.method = _update_color
	watched_color.changed.connect(queue.call_method)
	queue.call_method()


func _update_color() -> void:
	var _color: Color = watched_color.val()
	color = _color


func _clear_color() -> void:
	if not watched_color:
		return
	watched_color.changed.disconnect(queue.call_method)
	watched_color = null
	queue.clear()

#endregion - Color

#region - LoudFloat and LoudInt

func attach_float(_float: LoudFloat) -> void:
	var update: Callable = func() -> void:
		set_deferred("progress", _float.val())
	queue.method = update
	_float.changed.connect(queue.call_method)
	queue.call_method()


func attach_int(x: LoudInt, divisor := 1.0) -> void:
	var update: Callable = func() -> void:
		set_deferred("progress", x.divided_by(divisor))
	queue.method = update
	x.changed.connect(queue.call_method)
	queue.call_method()

#endregion - LoudFloat and LoudInt

#region - LoudPairs

var loud_pair: Resource


func _update_pair_progress() -> void:
	assert(loud_pair != null, "Why is this called if loud_pair is null?")
	if not loud_pair:
		return

	if display_pending:
		assert(not logarithmic_mode, "Add code for pending logarithmic percent")
		set_deferred(&"progress", loud_pair.get_pending_percent())
	else:
		if logarithmic_mode:
			set_deferred(&"progress", loud_pair.get_current_logarithmic_percent())
		else:
			set_deferred(&"progress", loud_pair.get_current_percent())


func attach_float_pair(_float_pair: LoudFloatPair) -> void:
	clear_loud_pair()
	loud_pair = _float_pair
	queue.method = _update_pair_progress
	loud_pair.changed.connect(queue.call_method)
	loud_pair.filled.connect(queue.call_method)
	queue.call_method()


func attach_int_pair(_int_pair: LoudIntPair) -> void:
	clear_loud_pair()
	loud_pair = _int_pair
	queue.method = _update_pair_progress
	loud_pair.changed.connect(queue.call_method)
	loud_pair.filled.connect(queue.call_method)
	queue.call_method()


func attach_big_float_pair(_bfp: BigFloatPair) -> void:
	clear_loud_pair()
	loud_pair = _bfp
	queue.method = _update_pair_progress
	if display_pending:
		loud_pair.pending_changed.connect(queue.call_method)
	loud_pair.changed.connect(queue.call_method)
	loud_pair.filled.connect(queue.call_method)
	queue.call_method()


## Clears the attached loud_pair
func clear_loud_pair() -> void:
	if not loud_pair:
		return
	if display_pending:
		loud_pair.pending_changed.disconnect(queue.call_method)
	stop_animation()
	loud_pair.changed.disconnect(queue.call_method)
	loud_pair.filled.disconnect(queue.call_method)
	loud_pair = null
	queue.clear()

#endregion - LoudPairs

#region - Price

var price: Price


func attach_price(_price: Price) -> void:
	price = _price
	if not is_node_ready():
		await ready
	progress = 0.0
	queue.method = _update_price
	queue.enable_looping()
	queue.call_method()


func _update_price() -> void:
	var _progress: float = (
			price.get_pending_progress_percent() if display_pending
			else price.get_logarithmic_progress_percent() if logarithmic_mode
			else price.get_progress_percent())
	set_deferred("progress", _progress)

	var display_edge: bool = (
			not price.get_pending_progress_percent() == 1.0 if display_pending
			else not price.get_progress_percent() == 1.0)
	edge.set_deferred("visible", display_edge)

#endregion - Price

#endregion Attachments

#region Animate

var animation_cd := LoudTimer.new(0.35)
var tween: Tween


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
