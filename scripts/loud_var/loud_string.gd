class_name LoudString
extends LoudVar


@export var current: String:
	set = set_text

var base: String
var copycat_string: LoudString


#region Init

#region Init


func _init(_base := "") -> void:
	base = _base
	current = base


func set_text(new_value: String) -> void:
	if current == new_value:
		return
	current = new_value
	changed.emit()


#endregion


#region Action


func reset() -> void:
	set_to(base)


func set_to(new_current: String) -> void:
	current = new_current


func attach_resource(_resource: Resource) -> void:
	var update = func():
		set_to(_resource.get_text())
	_resource.changed.connect(update)
	update.call()


func copycat(_string: LoudString) -> void:
	copycat_string = _string
	copycat_string.changed.connect(copycat_string_changed)
	copycat_string_changed()


func copycat_string_changed() -> void:
	set_to(copycat_string.get_text())


func clear_copycat() -> void:
	if copycat_string:
		copycat_string.changed.disconnect(copycat_string_changed)
	copycat_string = null


func replace(what: String, forwhat: String) -> void:
	var new_current: String = current.replace(what, forwhat)
	set_to(new_current)


func plus_equals(text: String) -> void:
	set_to(current + text)


#endregion



#region Get


func get_value() -> String:
	return current


func val() -> String:
	return current


func get_text() -> String:
	return current


func is_equal_to(_text: String) -> bool:
	return current == _text


func is_empty() -> bool:
	return current.is_empty()


func contains(what: String) -> bool:
	return current.contains(what)


func split(delimiter: String = "", allow_empty: bool = true, maxsplit: int = 0) -> Array:
	return current.split(delimiter, allow_empty, maxsplit)


func ends_with(text: String) -> bool:
	return current.ends_with(text)


#endregion
