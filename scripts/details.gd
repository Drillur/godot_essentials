class_name Details
extends RefCounted


var name: String = "": ## A setter/getter var for details_name
	set = _set_name, get = _get_name

var details_name := DetailsName.new()
var icon := DetailsIcon.new()
var color := DetailsColor.new()
var title := DetailsTitle.new()

var icon_and_name: String
var icon_and_title: String
var icon_and_colored_title: String
var icon_and_colored_name: String
var description: String


#region Init


func _init() -> void:
	for x in [icon, details_name, color, title]:
		x.changed.connect(_value_set)


#endregion


#region Update


func _value_set() -> void:
	if color.is_set and icon.is_set and not icon.is_colored and icon.text == "":
		icon.text = icon.text % color.html
	
	if title.is_set:
		if color.is_set:
			title.colored_text = color.text % title.text
		
		if icon.is_set:
			icon_and_title = icon.text + " " + title.text
		
		if icon.is_set and color.is_set:
			icon_and_colored_title = icon.text + " [color=#" + color.bright_color.to_html() + "]%s[/color]" % title.text
	
	if details_name.is_set:
		if color.is_set:
			details_name.colored_text = color.text % details_name.text
			if not details_name.plural.is_empty():
				details_name.colored_plural = color.text % details_name.plural
		
		if icon.is_set:
			icon_and_name = icon.text + " " + details_name.text
		
		if color.is_set and icon.is_set:
			icon_and_colored_name = icon.text + " [color=#" + color.bright_color.to_html() + "]%s[/color]" % details_name.text


func set_color(_color: Color) -> void:
	color.color = _color
	color.html = _color.to_html()
	color.is_set = true
	
	color.bright_color = Utility.validate_color_brightness(Color(_color))
	color.dark_color = Utility.validate_color_darkness(Color(_color))
	color.text = "[color=#" + color.html + "]%s[/color]"


func set_icon(_icon: Texture2D, _is_colored: bool = true) -> void:
	if not _icon:
		return
	
	icon.texture = _icon
	icon.is_colored = _is_colored
	icon.path = _icon.get_path()
	icon.is_set = true

	if icon.is_colored:
		icon.text = "[img=<16>]" + icon.path + "[/img]"
	else:
		icon.text = "[img=<16> color=#%s]" + icon.path + "[/img]"


func _set_name(_name: String) -> void:
	details_name.is_set = true
	details_name.text = _name


func set_title(_title: String) -> void:
	title.is_set = true
	title.text = _title


func set_description(_description: String) -> void:
	description = _description


#endregion


#region Get


func get_icon() -> Texture2D:
	return icon.texture


func get_icon_path() -> String:
	return icon.path


func get_icon_text() -> String:
	return icon.text


func get_icon_and_title() -> String:
	return icon_and_title


func get_icon_and_colored_title() -> String:
	return icon_and_colored_title


func get_icon_and_name() -> String:
	return icon_and_name


func _get_name() -> String:
	return details_name.text


func get_title() -> String:
	return title.text


func get_colored_title() -> String:
	return title.colored_text


func get_plural_name() -> String:
	return details_name.plural


func get_colored_plural_name() -> String:
	return details_name.colored_plural


func get_color_text() -> String:
	return color.text


func get_html() -> String:
	return color.html


func get_colored_name() -> String:
	return details_name.colored_text


func get_color() -> Color:
	return color.color


func get_bright_color() -> Color:
	return color.bright_color


func get_icon_and_colored_name() -> String:
	return icon_and_colored_name


func get_icon_and_colored_plural_name() -> String:
	return "%s %s" % [get_icon_text(), get_colored_plural_name()]


func get_icon_and_plural_name() -> String:
	return "%s %s" % [get_icon_text(), get_plural_name()]


func is_color_set() -> bool:
	return color.is_set


func is_title_set() -> bool:
	return title.is_set


func is_icon_set() -> bool:
	return icon.is_set


func is_description_set() -> bool:
	return description != ""


func get_description() -> String:
	return description


#endregion


#region Sub-classes


class DetailsObject extends Resource:
	var text := "":
		set(val):
			if text == val:
				return
			text = val
			emit_changed()
	var is_set := false


class DetailsIcon extends DetailsObject:
	var texture: Texture2D
	var is_colored := false
	var path := "":
		set(val):
			if path == val:
				return
			path = val
			emit_changed()


class DetailsColor extends DetailsObject:
	var html := ""
	var color := Color.WHITE
	var bright_color := Color.WHITE
	var dark_color := Color.BLACK


class DetailsName extends DetailsObject:
	var plural := "":
		set(val):
			if plural == val:
				return
			plural = val
			emit_changed()
	var colored_plural := ""
	var colored_text := ""


class DetailsTitle extends DetailsObject:
	var colored_text := ""


#endregion
