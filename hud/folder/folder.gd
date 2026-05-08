@tool
class_name Folder
extends MarginContainer


@export var icon: Texture2D = null: set = _set_icon
@export var header_label_text: String = "Folder": set = _set_header_label_text
@export var is_open: bool = false: set = _set_is_open
@export var color: Color = Color.WHITE: set = _set_color

#region Onready Variables

@onready var icon_texture_rect: TextureRect = %IconTextureRect
@onready var header_label: RichLabel = %HeaderLabel
@onready var arrow_texture_rect: TextureRect = %ArrowTextureRect
@onready var content_container: MarginContainer = %ContentContainer
@onready var header_button: InvisButton = %HeaderButton
@onready var background: Panel = $Background

#endregion


#region Region


func _ready() -> void:
	if not Engine.is_editor_hint():
		if not icon:
			icon_texture_rect.queue_free()
		await Utility.process()
	_update()


#endregion


#region Setters


func _set_icon(new_texture: Texture2D) -> void:
	if icon == new_texture:
		return
	
	icon = new_texture
	
	if not is_node_ready():
		await ready
	
	icon_texture_rect.texture = new_texture
	icon_texture_rect.visible = icon != null


func _set_header_label_text(new_text: String) -> void:
	if header_label_text == new_text:
		return
	
	header_label_text = new_text
	
	if not is_node_ready():
		await ready
	
	header_label.text = new_text
	
	header_label.visible = not new_text.is_empty()


func _set_is_open(new_val: bool) -> void:
	if is_open == new_val:
		return
	
	is_open = new_val
	
	_update()


func _set_color(new_color: Color) -> void:
	if not is_node_ready():
		await ready
	
	color = new_color
	arrow_texture_rect.modulate = color
	background.modulate = color
	if icon_texture_rect != null:
		icon_texture_rect.modulate = color


#endregion


#region Control


func _update() -> void:
	const ARROW_S_LINE_UP: Texture2D = preload("uid://ca7587w1g2bcy")
	const ARROW_S_LINE_DOWN: Texture2D = preload("uid://dmm7w4jdsctsb")
	
	if not is_node_ready():
		await ready
	
	content_container.visible = is_open
	arrow_texture_rect.texture = ARROW_S_LINE_DOWN if not is_open else ARROW_S_LINE_UP
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
