class_name LoudFloatPair
extends Resource


signal filled
signal emptied
signal pending_changed

@export var current: LoudFloat

var total: LoudFloat

var text: String
var text_requires_update := true
var limit_to_zero := true
var limit_to_total := true

## Calling get_random_point() updates this value
var result_of_previous_random_point: float


#region Init


func _init(base_value: float, base_total: float, _limit_to_total = true):
	current = LoudFloat.new(base_value)
	total = LoudFloat.new(base_total)
	limit_to_total = _limit_to_total
	current.changed.connect(text_changed)
	current.pending_changed.connect(pending_changed.emit)
	total.changed.connect(text_changed)
	current.changed.connect(check_if_full)
	current.changed.connect(check_if_empty)
	total.changed.connect(check_if_full)
	current.changed.connect(emit_changed)
	total.changed.connect(emit_changed)


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


func do_not_limit_to_total() -> LoudFloatPair:
	limit_to_total = false
	return self


func do_not_limit_to_zero() -> LoudFloatPair:
	limit_to_zero = false
	return self


func plus_equals(amount: float) -> void:
	if limit_to_total and is_full():
		return
	current.plus_equals(amount)
	check_if_full()
	clamp_current()


func plus_equals_one() -> void:
	current.current += LoudFloat.ONE


func minus_equals(amount: float) -> void:
	if limit_to_zero and is_empty():
		return
	current.minus_equals(amount)
	check_if_empty()
	clamp_current()


func minus_equals_one() -> void:
	current.current -= LoudFloat.ONE


func clamp_current() -> void:
	if limit_to_total:
		if limit_to_zero:
			current.current = clampf(get_current(), 0.0, get_total())
		else:
			current.current = minf(get_current(), get_total())
	else:
		if limit_to_zero:
			current.current = maxf(get_current(), 0.0)


func fill() -> void:
	if not is_full():
		current.set_to(get_total())


func dump() -> void:
	if not is_empty():
		current.set_to(0.0)


#endregion


#region Get


func get_value() -> float:
	return current.get_value()


func val() -> float:
	return current.val()


func get_current() -> float:
	return get_value()


func get_total() -> float:
	return total.get_value()


func get_current_percent() -> float:
	return get_value() / get_total()


func get_pending_percent() -> float:
	return current.get_effective_value() / get_total()


func get_deficit() -> float:
	return absf(get_total() - get_current())


func get_surplus() -> float:
	if is_full():
		return get_current() - get_total()
	return 0.0


func get_midpoint() -> float:
	if is_full():
		return get_total()
	return (get_current() + get_total()) / 2


func get_random_point() -> float:
	result_of_previous_random_point = (
		get_total() if is_full() else
		randf_range(get_current(), get_total())
	)
	return get_previous_random_point()


func get_average() -> float:
	return get_midpoint()


func get_previous_random_point() -> float:
	return result_of_previous_random_point


func get_text() -> String:
	if text_requires_update:
		text_requires_update = false
		text = get_current_text() + "/" + get_total_text()
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


func has(amount: int) -> bool:
	return current.is_greater_than_or_equal_to(amount)


#endregion
