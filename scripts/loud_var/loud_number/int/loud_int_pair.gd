class_name LoudIntPair
extends Resource


signal filled
signal emptied
signal pending_changed

@export var current: LoudInt:
	set = _set_current

var total: LoudInt

var text: String
var text_requires_update := true
var limit_to_zero := true
var limit_to_total := true

var result_of_previous_random_point: int ## Updated by get_random_point()


#region Init


func _init(base_value: int, base_total: int, _limit_to_total: bool = true):
	current = LoudInt.new(base_value)
	current.pending_changed.connect(pending_changed.emit)
	total = LoudInt.new(base_total)
	limit_to_total = _limit_to_total
	total.text_changed.connect(text_changed)
	total.changed.connect(check_if_full)
	total.changed.connect(emit_changed)
	SaveManager.loading_ended.connect(_game_loaded)


func _game_loaded() -> void:
	clamp_current()
	check_if_empty()
	check_if_full()


#endregion


#region Setters


func _set_current(_val: LoudInt) -> void:
	if current:
		if current == _val:
			return
		current.text_changed.disconnect(text_changed)
		current.changed.disconnect(check_if_empty)
		current.changed.disconnect(check_if_full)
		current.changed.disconnect(emit_changed)
	current = _val
	current.text_changed.connect(text_changed)
	current.changed.connect(check_if_empty)
	current.changed.connect(check_if_full)
	current.changed.connect(emit_changed)


#endregion


#region Internal


func text_changed() -> void:
	text_requires_update = true


func check_if_full() -> void:
	if is_full():
		if limit_to_total and current.is_greater_than(get_total()):
			fill()
		filled.emit()


func check_if_empty() -> void:
	if is_empty():
		if limit_to_zero and current.is_less_than(0):
			dump()
		emptied.emit()


#endregion


#region Action


func do_not_limit_to_total() -> LoudIntPair:
	limit_to_total = false
	return self


func do_not_limit_to_zero() -> LoudIntPair:
	limit_to_zero = false
	return self


func plus_equals(amount: int) -> void:
	if limit_to_total and is_full():
		return
	current.plus_equals(amount)
	check_if_full()
	clamp_current()


func plus_equals_one() -> void:
	current.current += LoudInt.ONE


func minus_equals(amount: int) -> void:
	if limit_to_zero and is_empty():
		return
	current.minus_equals(amount)
	check_if_empty()
	clamp_current()


func minus_equals_one() -> void:
	current.current -= LoudInt.ONE


func clamp_current() -> void:
	if limit_to_total:
		if limit_to_zero:
			current.current = clampi(get_current(), 0, get_total())
		else:
			current.current = mini(get_current(), get_total())
	else:
		if limit_to_zero:
			current.current = maxi(get_current(), 0)


func fill() -> void:
	current.set_to(get_total())


func dump() -> void:
	current.set_to(LoudInt.ZERO)


#endregion


#region Get


func get_value() -> int:
	return current.get_value()


func val() -> int:
	return current.val()


func get_current() -> int:
	return get_value()


func get_total() -> int:
	return total.get_value()


func get_current_percent() -> float:
	return float(get_value()) / get_total()


func get_pending_percent() -> float:
	return float(current.get_effective_value()) / get_total()


func get_deficit() -> int:
	return absi(total.current - current.current)


func get_surplus() -> int:
	if is_full():
		return get_current() - get_total()
	return 0


func get_midpoint() -> int:
	if is_full():
		return get_total()
	return roundi(float(get_current() + get_total()) / 2)


func get_random_point() -> int:
	result_of_previous_random_point = (
		get_total() if is_full() else
		randi_range(get_current(), get_total())
	)
	return get_previous_random_point()


func get_average() -> int:
	return roundi(float(get_current() + get_total()) / 2)


func get_previous_random_point() -> int:
	return result_of_previous_random_point


func get_text() -> String:
	if text_requires_update:
		text_requires_update = false
		text = "%s/%s" % [get_current_text(), get_total_text()]
	return text


func get_current_text() -> String:
	return current.get_text()


func get_total_text() -> String:
	return total.get_text()


func is_full() -> bool:
	return get_current() >= get_total()


func is_effectively_full() -> bool:
	return current.get_effective_value() >= get_total()


func is_empty() -> bool:
	return current.is_zero()


#endregion
