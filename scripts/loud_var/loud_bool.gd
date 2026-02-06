class_name LoudBool
extends LoudVar


signal became_true
signal became_false

@export var current: bool:
	set = _set_current

var base: bool
var copied_bool: LoudBool
var button: Control
var display_node: Control


#region Init


func _init(_base: bool = false) -> void:
	base = _base
	current = _base


#endregion


#region Set Get


func _set_current(new_current: bool) -> void:
	if current == new_current:
		return
	
	current = new_current
	
	changed.emit()
	if new_current:
		became_true.emit()
	else:
		became_false.emit()


#endregion


#region Action


func invert() -> void:
	set_to(not current)


func invert_default_value() -> void:
	set_default_value(not base)


func set_true() -> void:
	set_to(true)


func set_false() -> void:
	set_to(false)


func set_to(new_current: bool) -> void:
	current = new_current


func set_default_value(new_base: bool) -> void:
	base = new_base


func reset() -> void:
	set_to(base)


func tie_node_visibility(_node: Control, _equal_to: bool = true, _flash := false, _flash_color := Color.WHITE) -> void:
	_node.visible = is_true()
	var update: Callable
	if _equal_to:
		if _flash:
			update = func():
				_node.visible = is_true()
				if _node.visible and Settings.flashes_allowed.is_true():
					Flash.flash(_node, _flash_color)
		else:
			update = func():
				_node.visible = is_true()
	else:
		if _flash:
			update = func():
				_node.visible = is_false()
				if _node.visible and Settings.flashes_allowed.is_true():
					Flash.flash(_node, _flash_color)
		else:
			update = func():
				_node.visible = is_false()
	_node.tree_exiting.connect(changed.disconnect.bind(update))
	changed.connect(update)
	update.call()


#region Button


func tie_button_pressed(_button: Control) -> void:
	if button:
		pass
	button = _button
	await Utility.process()
	
	if not is_instance_valid(button):
		button = null
		return
	
	button.button_pressed = is_true()
	if not changed.is_connected(_update_button_pressed):
		changed.connect(_update_button_pressed)
	if not button.toggled.is_connected(_button_toggled):
		button.toggled.connect(_button_toggled)


func clear_button() -> void:
	changed.disconnect(_update_button_pressed)
	if button:
		button.toggled.disconnect(_button_toggled)
	button = null


func _button_toggled(_toggled: bool) -> void:
	button.toggled.disconnect(_button_toggled)
	set_to(_toggled)
	await Utility.process()
	if not button:
		clear_button()
	else:
		if not button.toggled.is_connected(_button_toggled):
			button.toggled.connect(_button_toggled)


func _update_button_pressed() -> void:
	if not button:
		clear_button()
		return
	button.button_pressed = is_true()


#endregion


#region Copycat


func copycat(_copied_bool: LoudBool) -> void:
	assert(not is_copycat(), "already a copycat")
	copied_bool = _copied_bool
	copied_bool.changed.connect(copycat_changed)
	copycat_changed()


func copycat_changed() -> void:
	set_to(copied_bool.val())


func remove_copycat() -> void:
	if not copied_bool:
		return
	if copied_bool.changed.is_connected(copycat_changed):
		copied_bool.changed.disconnect(copycat_changed)
	if copied_bool.changed.is_connected(contradict_changed):
		copied_bool.changed.disconnect(contradict_changed)
	copied_bool = null


func contradict(_bool: LoudBool) -> void: # has the opposite effect of copycat
	copied_bool = _bool
	_bool.changed.connect(contradict_changed)
	contradict_changed()


func contradict_changed() -> void:
	set_to(copied_bool.is_false())


func is_copycat() -> bool:
	return copied_bool != null


#endregion


#endregion


#region Get


func get_value() -> bool:
	return current


func val() -> bool:
	return current


func get_text() -> String:
	return str(get_value())


func is_true() -> bool:
	return current


func is_false() -> bool:
	return not current


func default() -> bool:
	return base


#endregion
