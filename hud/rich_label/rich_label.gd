@tool
class_name RichLabel
extends RichTextLabel


enum AttachType {
	NONE,
	PRICE,
	CURRENCY,
}

@export var autowrap := true:
	set = _set_autowrap
@export var hide_icon := false
@export var percent_mode := false
@export var italics := false:
	set = _set_italics
@export var bold := false:
	set = _set_bold
@export var center := false:
	set = _set_center
@export var custom_decimal_places := -1
@export var font_size := 12:
	set = _set_font_size
@export var prepended_text: String = ""
@export var appended_text: String = ""
@export var flash_on_changed := false
@export_group("Time Mode")
@export var time_mode := false
@export var short_time_text := false
@export_group("")

var color := Color.WHITE
var queue: Queueable
var color_queue: Queueable
var watched_strings: Array[LoudString]
var base_text: String
var attach_type: AttachType
var standard_theme: bool


#region Init


func _ready() -> void:
	const MSDF_THEMES: Array[Theme] = [
			preload("uid://bbsyitixspj7m"),
			preload("uid://boqclar58m1s5")]
	
	if text.contains("[img") and not text.contains("uid"):
		printerr("Do not add [img] bbcode in labels without UID. ", text)
		#print(" - Why not? Because if the path, UID, or size of your image changes, it can cause misc issues. Future-proof your game! Don't freakin do it!")
		pass
	
	set_physics_process(false)
	set_base_text()
	
	if MSDF_THEMES.has(theme) and not Engine.is_editor_hint():
		Settings.stretch_scale.changed.connect(update_theme)
		Settings.stretch_mode.changed.connect(update_theme)
		standard_theme = theme == MSDF_THEMES[0]
		update_theme()


func update_theme() -> void:
	if Settings.stretch_scale.is_equal_to(1.0) or Settings.stretch_mode.is_false():
		if standard_theme:
			theme = ResourceBag.get_theme(&"standard")
		else:
			theme = ResourceBag.get_theme(&"substandard")
	else:
		if standard_theme:
			theme = ResourceBag.get_theme(&"standard_msdf")
		else:
			theme = ResourceBag.get_theme(&"substandard_msdf")


func set_base_text() -> void:
	if center:
		base_text = "[center]"
	if font_size != 12:
		base_text += "[font_size=%s]" % str(font_size)
	if italics:
		base_text += "[i]"
	if bold:
		base_text += "[b]"
	base_text = prepended_text + base_text + "%s" + appended_text


#endregion


#region Set Get


func _set_autowrap(val: bool) -> void:
	if autowrap == val:
		return
	
	autowrap = val
	
	if autowrap:
		enable_autowrap()
	else:
		disable_autowrap()


func _set_bold(val: bool) -> void:
	if bold == val:
		return
	
	bold = val
	
	if Engine.is_editor_hint():
		text = text.replace("[b]", "")
		if val:
			text = "[b]" + text


func _set_italics(val: bool) -> void:
	if italics == val:
		return
	
	italics = val
	text = text.replace("[i]", "")
	if val:
		text = "[i]" + text


func _set_center(val: bool) -> void:
	if center == val:
		return
	
	center = val
	
	if Engine.is_editor_hint():
		text = text.replace("[center]", "")
		if val:
			text = "[center]" + text


func _set_font_size(val: int) -> void:
	if font_size == val:
		return
	font_size = val
	#if not Engine.is_editor_hint():
		#return
	if text.contains("[font_size="):
		var previous_font_size_text: String = text.split("[font_size=")[1].split("]")[0]
		text = text.replace("[font_size=%s]" % previous_font_size_text, "")
	if font_size != 12:
		text = "[font_size=%s]" % str(font_size) + text


#endregion


#region Action


func _set_text(_text: String) -> void:
	if percent_mode and not _text.ends_with("%"):
		_text += "%"
	text = base_text % _text


func disable_autowrap() -> void:
	autowrap_mode = TextServer.AUTOWRAP_OFF


func enable_autowrap() -> void:
	autowrap_mode = TextServer.AUTOWRAP_WORD_SMART


func _validate_queue() -> void:
	if not queue:
		queue = await Queueable.new_node_queueable(
				self, Queueable.CooldownType.DURATION, 0.1)


func reset() -> void:
	if value:
		clear_value()
	queue.reset()
	text = ""


#endregion


#region Timer


var timer: LoudTimer


## Timer only
func _physics_process(_delta: float) -> void:
	if not visible:
		return
	
	match custom_decimal_places:
		-1:
			_set_text(timer.get_time_left_text())
		0:
			_set_text(str(floori(timer.get_time_left())))
		_:
			_set_text(String.num(timer.get_time_left(), custom_decimal_places))



func attach_timer(_timer: LoudTimer) -> void:
	if timer:
		if timer == _timer:
			return
		clear_timer()
	timer = _timer
	set_physics_process(true)


func clear_timer() -> void:
	set_physics_process(false)
	timer = null


#endregion


#region LoudString(s)


func attach_string(_strings: Variant) -> void:
	_validate_queue()
	clear_string()
	if _strings is LoudString:
		watched_strings.append(_strings)
	else:
		for x in _strings:
			watched_strings.append(x)
	queue.method = string_changed
	for x in watched_strings:
		x.changed.connect(queue.call_method)
	#string_changed()
	queue.call_method()


func string_changed() -> void:
	if watched_strings.size() == 0:
		return
	var _text := ""
	
	for x in watched_strings.size():
		if x >= 1:
			_text += " "
		_text += watched_strings[x].val()
	_set_text(_text)


func clear_string() -> void:
	if watched_strings.size() == 0:
		return
	for x in watched_strings:
		x.changed.disconnect(queue.call_method)
	watched_strings.clear()


#endregion


#region LoudNumber (value)


var value: RefCounted


func clear_value() -> void:
	assert(currency == null, "You probably don't want to clear_value when a currency is attached. fix ur shit ")
	if value:
		value.changed.disconnect(queue.call_method)
		value = null
	match attach_type:
		AttachType.PRICE, AttachType.CURRENCY:
			if currency:
				currency.amount.changed.disconnect(queue.call_method)
				currency = null
	attach_type = AttachType.NONE


func attach_float_pair(_value: LoudFloatPair) -> void:
	_validate_queue()
	if value:
		if value == _value:
			return
		clear_value()
	value = _value
	queue.method = _update_text_from_value
	value.changed.connect(queue.call_method)
	queue.call_method()


func attach_float(_value: LoudFloat) -> void:
	_validate_queue()
	if value:
		if value == _value:
			return
		clear_value()
	value = _value
	queue.method = _update_text_from_value
	value.changed.connect(queue.call_method)
	queue.call_method()


func attach_int_pair(_value: LoudIntPair) -> void:
	_validate_queue()
	if value:
		if value == _value:
			return
		clear_value()
	value = _value
	queue.method = _update_text_from_value
	value.changed.connect(queue.call_method)
	queue.call_method()


func attach_int(_value: LoudInt) -> void:
	_validate_queue()
	if value:
		if value == _value:
			return
		clear_value()
	value = _value
	queue.method = _update_text_from_value
	value.changed.connect(queue.call_method)
	queue.call_method()


func attach_big_float_pair(_value: BigFloatPair) -> void:
	_validate_queue()
	if value:
		if value == _value:
			return
		clear_value()
	value = _value
	queue.method = _update_text_from_value
	value.changed.connect(queue.call_method)
	queue.call_method()


func attach_big_float(_value: BigFloat) -> void:
	_validate_queue()
	if value:
		if value == _value:
			return
		clear_value()
	value = _value
	queue.method = _update_text_from_value
	value.changed.connect(queue.call_method)
	queue.call_method()


func attach_big(_value: Big) -> void:
	_validate_queue()
	if value:
		if value == _value:
			return
		clear_value()
	value = _value
	queue.method = _update_text_from_value
	value.changed.connect(queue.call_method)
	queue.call_method()


#region Update Text


func _update_text_from_value() -> void:
	if value == null:
		return
	
	if percent_mode:
		_update_text__percent_mode()
	elif time_mode:
		_update_text__time_mode()
	else:
		# NOTE - If value is a Big, this must be -1
		match custom_decimal_places:
			-1:
				_set_text(value.get_text())
			0:
				_set_text(str(roundi(value.val())))
			_:
				_set_text(str(snappedf(value.val(), 1.0 / (10 ** custom_decimal_places))))
	
	if flash_on_changed:
		await Utility.physics(2)
		Flash.flash(self, color)


func _update_text__percent_mode() -> void:
	var value_is_pair: bool = (
			value is LoudFloatPair
			or value is LoudIntPair
			or value is BigFloatPair)
	
	_set_text(LoudNumber.format_percent(
		value.get_current_percent() if value_is_pair
		else value.times(LoudFloat.ONE_PERCENT)))


func _update_text__time_mode() -> void:
	if value is LoudInt or value is LoudFloat:
		_set_text(
				LoudTimer.format_time(value.val()) if short_time_text
				else LoudTimer.get_time_text_from_dict(
						LoudTimer.get_time_dict(value.val())))
	
	elif value is Big or value is BigFloat:
		if value.is_zero():
			_set_text("0/s")
		elif short_time_text:
			_set_text(
					"~0/s" if value.is_between(-0.01, 0.01)
					else value.get_text() + "/s")
		else:
			var _sign := signf(value.val().mantissa)
			var abs_val := Big.absolute(value.val())
			if abs_val.is_less_than(0.1):
				abs_val.times_equals(60)
				if abs_val.is_less_than(1):
					abs_val.times_equals(60)
					abs_val.times_equals(_sign)
					_set_text(abs_val.get_text() + "/h")
				else:
					abs_val.times_equals(_sign)
					_set_text(abs_val.get_text() + "/m")
			else:
				_set_text(value.get_text() + "/s")


#endregion


#endregion


#region game-specific


var currency: Currency


func attach_price(key: StringName, _price: Price) -> void:
	attach_type = AttachType.PRICE
	await _validate_queue()
	currency = Currency.fetch(key)
	value = _price.current[key]
	queue.method = update_text_price
	currency.amount.changed.connect(queue.call_method)
	value.changed.connect(queue.call_method)
	update_text_price()


func clear_price() -> void:
	queue.clear()
	clear_currency()
	clear_value()


func update_text_price() -> void:
	if value == null:
		return
	var result_text: String = value.get_text()
	if not hide_icon:
		result_text += currency.details.get_icon_and_name()
	_set_text.call_deferred(result_text)


func clear_currency() -> void:
	if not currency:
		return
	currency.amount.changed.disconnect(queue.call_method)
	currency = null


#endregion
