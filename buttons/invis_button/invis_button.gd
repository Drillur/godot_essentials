class_name InvisButton
extends Button


signal left_pressed
signal right_pressed

const BUTTON_CLICK_AUDIO_POOL: Array[StringName] = [
	&"button_click_1",
	&"button_click_2",
	&"button_click_3",
	&"button_click_4",
]
const BUTTON_DOWN_AUDIO_POOL: Array[StringName] = [
	&"button_down_1",
	&"button_down_2",
	&"button_down_3",
	&"button_down_4",
]
const BUTTON_UP_AUDIO_POOL: Array[StringName] = [
	&"button_up_1",
	&"button_up_2",
	&"button_up_3",
	&"button_up_4",
]

@export var audio_enabled: bool = true
@export var separate_audios: bool = true

var color: Color:
	set = _set_color


#region Set Get


func _set_color(val: Color) -> void:
	if color == val:
		return
	color = val
	modulate = val


#endregion


#region Signals


func _on_gui_input(_event: InputEvent) -> void:
	if not visible or disabled:
		return
	
	if _event.is_action_pressed(&"ui_accept"):
		left_pressed.emit()
	elif _event.is_action_pressed(&"joy_y"):
		right_pressed.emit()
	elif _event is InputEventMouseButton and _event.is_pressed():
		if _event.button_mask == MOUSE_BUTTON_RIGHT:
			right_pressed.emit()
		elif _event.button_mask == MOUSE_BUTTON_LEFT:
			left_pressed.emit()


func _on_button_up() -> void:
	if not separate_audios:
		return
	_play_button_up_audio()


#endregion


#region Actions


func disable() -> void:
	disabled = true


func enable() -> void:
	disabled = false


func set_pointing_hand_cursor_shape() -> void:
	mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND


func set_arrow_cursor_shape() -> void:
	mouse_default_cursor_shape = Control.CURSOR_ARROW


#endregion


#region Private


func _play_appropriate_audio() -> void:
	if separate_audios:
		_play_button_down_audio()
	else:
		_play_button_click_audio()


func _play_button_click_audio() -> void:
	if audio_enabled:
		Main.play_audio(ResourceBag.get_audio(BUTTON_CLICK_AUDIO_POOL.pick_random()), Utility.AudioLayer.UI)


func _play_button_down_audio() -> void:
	if audio_enabled:
		Main.play_audio(ResourceBag.get_audio(BUTTON_DOWN_AUDIO_POOL.pick_random()), Utility.AudioLayer.UI)


func _play_button_up_audio() -> void:
	if audio_enabled:
		Main.play_audio(ResourceBag.get_audio(BUTTON_UP_AUDIO_POOL.pick_random()), Utility.AudioLayer.UI)


#endregion
