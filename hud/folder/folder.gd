@tool
class_name Folder
extends MarginContainer


@export var header_label_text: String = "Folder"
@export var is_open: bool = false:
	set = _set_is_open

#region Onready Variables

@onready var header_label: RichLabel = %HeaderLabel
@onready var arrow_texture_rect: TextureRect = %ArrowTextureRect
@onready var content_container: MarginContainer = %ContentContainer
@onready var header_button: InvisButton = %HeaderButton

#endregion


#region Region


func _ready() -> void:
	header_label.text = header_label_text


#endregion


#region Setters


func _set_is_open(new_val: bool) -> void:
	if is_open == new_val:
		return
	
	is_open = new_val
	
	_update()


#endregion


#region Control


func _update() -> void:
	if Engine.is_editor_hint():
		return
	
	if not is_node_ready():
		await ready
	
	content_container.visible = is_open
	arrow_texture_rect.texture = ResourceBag.get_icon(
			&"arrow_s_line_down" if not is_open else &"arrow_s_line_up")
	header_label.text = ("[b]" if is_open else "") + header_label_text


func open() -> void:
	is_open = true


func close() -> void:
	is_open = false


#endregion


#region Signals


func _on_header_button_left_pressed() -> void:
	is_open = not is_open


func _on_bottom_button_left_pressed() -> void:
	is_open = not is_open


#endregion
