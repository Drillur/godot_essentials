@tool
class_name RichButton
extends MarginContainer


signal pressed
signal toggled(_toggled: bool)

@export var text: String:
	set(val):
		text = val
		if not is_node_ready():
			await ready
		label.text = text
		if text == "":
			label.hide()
		else:
			label.show()
@export var tooltip: String = ""
@export var color := Color.WHITE:
	set = _set_color
@export var center_content := false:
	set = _set_center_content

@export var display_background := false:
	set(val):
		if display_background == val:
			return
		display_background = val
		if not is_node_ready():
			await ready
		update_background_visibility()

@export var in_bottom_left := false
@export var in_bottom_right := false
@export var autowrap_text := false:
	set = _set_autowrap
@export var disabled: bool = false:
	set = _set_disabled

@export var allow_focus := false

@export_group("Audio")
@export var audio_enabled: bool = true:
	set = _set_audio_enabled
@export var separate_audios: bool = true:
	set = _set_separate_audios
	

@export_group("Icon")
@export var icon: Texture2D:
	set(val):
		icon = val
		if not is_node_ready():
			await ready
		update_icon()
@export_range(15, 64) var icon_size := 24:
	set(val):
		icon_size = val
		if not is_node_ready():
			await ready
		icon_container.custom_minimum_size = Vector2(val, val)
		texture_rect.custom_minimum_size = Vector2(val, val)
		texture_rect.size = texture_rect.custom_minimum_size
@export var modulate_icon: bool = false:
	set = _set_modulate_icon

@export_group("Check Button Mode")
@export var check_button_mode: bool = false:
	set = _set_check_button_mode
@export var button_pressed: bool = true:
	set = _set_button_pressed
@export var hide_check_button: bool = false:
	set = set_hide_check_button
@export var pressed_displays_background: bool = false:
	set = set_button_pressed_displays_background
@export var pressed_icon: Texture2D
@export var not_pressed_icon: Texture2D

@export_group("Drop Down")
@export var drop_down: Node
@export var second_drop_down: Node
@export var open_by_default := false:
	set = _set_open_by_default
@export var open_duration: float = -1.0
@export_group("")

var open_duration_timer_started: bool = false
var response: DialogueResponse:
	set = _set_response

#region Onready Variables

@onready var icon_container: Control = %IconContainer as Control
@onready var texture_rect: TextureRect = %TextureRect as TextureRect
@onready var label: RichLabel = %Label as RichLabel
@onready var h_box: HBoxContainer = %HBox as HBoxContainer
@onready var background: Panel = %Background as Panel
@onready var check_button: CheckButton = %CheckButton as CheckButton
@onready var invis_button: InvisButton = $InvisButton

#endregion


#region Init


func _ready():
	if not Engine.is_editor_hint():
		await Utility.physics()
	invis_button.tooltip_text = tooltip
	color = color
	if drop_down:
		drop_down.visible = open_by_default
	if second_drop_down:
		second_drop_down.visible = not drop_down.visible
	
	if text == "":
		label.hide()
	else:
		label.show()
	
	if not Engine.is_editor_hint():
		if in_bottom_left:
			invis_button.theme = ResourceBag.get_theme(&"invis_bottom_left")
		elif in_bottom_right:
			invis_button.theme = ResourceBag.get_theme(&"invis_bottom_right")
		else:
			invis_button.theme = ResourceBag.get_theme(&"invis")
	
	
	invis_button.gui_input.connect(gui_input.emit)
	
	await Utility.physics()
	
	update_icon()
	update_check_button_visibility()
	
	if not Engine.is_editor_hint():
		if not Main.done.is_true():
			await Main.done.became_true
		Settings.joypad_detected.changed.connect(_update_focus_mode)
		_update_focus_mode()


func _ready_focus() -> void:
	invis_button.focus_neighbor_left = focus_neighbor_left
	invis_button.focus_neighbor_top = focus_neighbor_top
	invis_button.focus_neighbor_right = focus_neighbor_right
	invis_button.focus_neighbor_bottom = focus_neighbor_bottom
	invis_button.focus_next = focus_next
	invis_button.focus_previous = focus_previous


#endregion


#region Set & Get


func _set_color(val: Color) -> void:
	color = val
	if not is_node_ready():
		await ready
	invis_button.modulate = val
	if background:
		background.modulate = val
	#if val == Color.BLACK or val == Color.WHITE:
		#label.modulate = val
	if check_button:
		check_button.modulate = val
	if modulate_icon:
		texture_rect.modulate = val


func _set_modulate_icon(val: bool) -> void:
	if texture_rect == null:
		return
	modulate_icon = val
	if val:
		texture_rect.modulate = color
	else:
		texture_rect.modulate = Color.WHITE


func _set_open_by_default(val: bool) -> void:
	open_by_default = val
	if drop_down:
		drop_down.visible = val
	if second_drop_down:
		second_drop_down.visible = not drop_down.visible


func _set_response(new_response: DialogueResponse) -> void:
	const BASE_TEXT: String = "%s. "
	response = new_response
	await Utility.process()
	text = BASE_TEXT % str(get_index()) + "..."


func _set_autowrap(val: bool) -> void:
	if autowrap_text == val:
		return
	autowrap_text = val
	if not is_node_ready():
		await ready
	if val:
		label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	else:
		label.autowrap_mode = TextServer.AUTOWRAP_OFF


func _set_center_content(val: bool) -> void:
	if center_content == val:
		return
	center_content = val
	if not is_node_ready():
		await ready
	if center_content:
		h_box.alignment = HBoxContainer.ALIGNMENT_CENTER
		label.size_flags_horizontal = SIZE_FILL
	else:
		h_box.alignment = HBoxContainer.ALIGNMENT_BEGIN
		label.size_flags_horizontal = SIZE_EXPAND_FILL


func _set_disabled(val: bool) -> void:
	if disabled == val:
		return
	disabled = val
	if not is_node_ready():
		await ready
	if val:
		disable()
	else:
		enable()


func _set_check_button_mode(val: bool) -> void:
	if check_button_mode == val:
		return
	check_button_mode = val
	if not is_node_ready():
		await ready
	update_check_button_visibility()
	update_background_visibility()


func _set_button_pressed(val: bool) -> void:
	if button_pressed == val or not check_button_mode:
		return
	
	if not is_node_ready():
		await ready
		await get_tree().physics_frame
	
	if val:
		button_pressed = val
	
	if drop_down:
		drop_down.visible = val
	
	button_pressed = val
	update_background_visibility()
	update_icon()
	check_button.button_pressed = val


func set_hide_check_button(val: bool) -> void:
	if hide_check_button == val:
		return
	hide_check_button = val
	if not is_node_ready():
		await ready
	update_check_button_visibility()


func set_button_pressed_displays_background(val: bool) -> void:
	if pressed_displays_background == val:
		return
	pressed_displays_background = val
	if not is_node_ready():
		await ready
	update_background_visibility()


func update_icon() -> void:
	icon_container.visible = (
		icon != null or 
		check_button_mode and (
			pressed_icon != null or
			not_pressed_icon != null
		)
	)
	if icon_container.visible:
		if button_pressed:
			if check_button_mode and pressed_icon != null:
				texture_rect.texture = pressed_icon
			else:
				texture_rect.texture = icon
		else:
			if check_button_mode and not_pressed_icon != null:
				texture_rect.texture = not_pressed_icon
			else:
				texture_rect.texture = icon


func update_background_visibility() -> void:
	if check_button_mode and pressed_displays_background:
		background.visible = button_pressed
	else:
		background.visible = display_background



func update_check_button_visibility() -> void:
	if check_button_mode:
		check_button.visible = not hide_check_button
	else:
		check_button.hide()


func _set_separate_audios(val: bool) -> void:
	if separate_audios == val:
		return
	separate_audios = val
	if not is_node_ready():
		await ready
	invis_button.separate_audios = val


func _set_audio_enabled(val: bool) -> void:
	if audio_enabled == val:
		return
	audio_enabled = val
	if not is_node_ready():
		await ready
	invis_button.audio_enabled = val


#endregion


func _on_button_left_pressed() -> void:
	if drop_down:
		drop_down.visible = not drop_down.visible
		close_after_open_duration_timer()
	if second_drop_down:
		second_drop_down.visible = not drop_down.visible
	if check_button_mode:
		button_pressed = not button_pressed
		toggled.emit(button_pressed)
	pressed.emit()


func close_after_open_duration_timer() -> void:
	if open_duration_timer_started:
		return
	if open_duration > LoudTimer.MINIMUM_DURATION:
		open_duration_timer_started = true
		await Utility.timer(open_duration)
		open_duration_timer_started = false
		drop_down.hide()
		if second_drop_down:
			second_drop_down.hide()


func _on_button_mouse_exited():
	mouse_exited.emit()


func _on_button_mouse_entered():
	mouse_entered.emit()


func _on_button_button_down():
	texture_rect.position.y = 1


func _on_button_button_up():
	texture_rect.position.y = 0


func set_text_visibility(val: bool) -> void:
	label.visible = val


func show_text() -> void:
	set_text_visibility(true)


func hide_text() -> void:
	set_text_visibility(false)


func set_color(val: Color) -> void:
	color = val


func enable() -> void:
	modulate = Color.WHITE
	invis_button.disabled = false
	invis_button.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND


func disable() -> void:
	modulate = Color(0.5, 0.5, 0.5)
	invis_button.disabled = true
	invis_button.mouse_default_cursor_shape = Control.CURSOR_ARROW


#region Signals


func _on_focus_entered() -> void:
	invis_button.grab_focus.call_deferred()


#endregion


#region Focus


func _update_focus_mode() -> void:
	if not allow_focus:
		return
	if Settings.joypad_detected.is_true():
		focus_mode = Control.FOCUS_ALL
		invis_button.focus_mode = Control.FOCUS_ALL
	else:
		focus_mode = Control.FOCUS_NONE
		invis_button.focus_mode = Control.FOCUS_NONE


#endregion
