class_name LoudInt
extends LoudNumber


const ZERO: int = 0
const ONE: int = 1

@warning_ignore("unused_private_class_variable")
@export var current: int:
	set = _set_current
@export var saved_pending_value: int = 0

var previous: int
var base: int
var custom_minimum_limit := MIN_INT:
	set = _set_minimum_limit
var custom_maximum_limit := MAX_INT:
	set = _set_maximum_limit
var _save_pending: bool = false:
	set = _set_save_pending


#region Init


func _init(_base: int = ZERO, _custom_minimum_limit := MIN_INT, _custom_maximum_limit := MAX_INT) -> void:
	base = _base
	current = base
	previous = base
	changed.connect(loud_number_init)
	
	custom_minimum_limit = _custom_minimum_limit
	custom_maximum_limit = _custom_maximum_limit


func _create_book() -> void:
	book = Book.new(Book.Type.INT)
	book.changed.connect(sync)
	book.pending_changed.connect(pending_changed.emit)


#endregion


#region Setters


func _set_current(n: int) -> void:
	n = clampi(n, custom_minimum_limit, custom_maximum_limit)
	
	if current == n:
		return
	
	previous = current
	current = n
	text_requires_update = true
	
	_emit_signals(previous, current)


func _set_minimum_limit(n: int) -> void:
	custom_minimum_limit = n
	clamp_current()


func _set_maximum_limit(n: int) -> void:
	custom_maximum_limit = n
	clamp_current()


func _set_save_pending(x: bool) -> void:
	_save_pending = x
	if _save_pending:
		SaveManager.saving_started.connect(save_pending_value)
		SaveManager.loading_ended.connect(load_pending_value)


#endregion


#region Signals


func _emit_signals(_previous: int, _current: int) -> void:
	assert(_current != _previous, "Do not emit signals if nothing changed.")
	if _previous > _current:
		decreased.emit(_previous - _current)
	elif _previous < _current:
		increased.emit(_current - _previous)
	number_changed.emit(self)
	changed.emit()


func save_pending_value() -> void:
	saved_pending_value = int(book.get_pending())


func load_pending_value() -> void:
	plus_equals(saved_pending_value)


#endregion


#region Action


func reset() -> void:
	current = base
	super()


func set_to(amount: int) -> void:
	current = amount


func plus_equals(amount: int) -> void:
	if is_zero_approx(amount):
		return
	current += amount


func plus_equals_one() -> void:
	current += ONE


func minus_equals(amount: int) -> void:
	if is_zero_approx(amount):
		return
	current -= amount


func minus_equals_one() -> void:
	current -= ONE


func times_equals(amount: int) -> void:
	if is_equal_approx(amount, 1):
		return
	current *= amount


func divided_by_equals(amount: int) -> void:
	if is_equal_approx(amount, 1):
		return
	current /= amount


func sync() -> void:
	if book.sync_allowed.is_true():
		set_to(book.sync.call(base))


func set_default_value(n: int) -> void:
	base = n


func clamp_current() -> void:
	current = clampi(current, custom_minimum_limit, custom_maximum_limit)


func copycat(cat: Resource) -> void:
	set_default_value(0)
	set_to(0)
	super(cat)


func set_bool_limiter(b: LoudBool, limit: int) -> void:
	if b.is_false():
		custom_minimum_limit = limit
		custom_maximum_limit = limit
		set_to(limit)
	b.became_true.connect(
		func():
			custom_minimum_limit = MIN_INT
			custom_maximum_limit = MAX_INT
	)
	b.became_false.connect(
		func():
			custom_minimum_limit = limit
			custom_maximum_limit = limit
			set_to(limit)
	)


func save_pending() -> void:
	_save_pending = true


#endregion


#region Get


func get_value() -> int:
	return current


func val() -> int:
	return current


func get_effective_value() -> int:
	return current + book.get_pending()


func get_text() -> String:
	if text_requires_update:
		update_text(current)
	return text


func is_between(a: Variant, b: Variant) -> bool:
	return is_greater_than_or_equal_to(a) and is_less_than_or_equal_to(b)


func is_positive() -> bool:
	return current >= ZERO


func is_greater_than(n) -> bool:
	return not is_less_than_or_equal_to(n)


func is_greater_than_or_equal_to(n) -> bool:
	return not is_less_than(n)


func is_equal_to(n) -> bool:
	assert(VALID_COMPARISON_TYPES.has(typeof(n)), INVALID_TYPE_MESSAGE)
	return is_equal_approx(current, n)


func is_less_than_or_equal_to(n) -> bool:
	return is_less_than(n) or is_equal_to(n)


func is_less_than(n) -> bool:
	assert(VALID_COMPARISON_TYPES.has(typeof(n)), INVALID_TYPE_MESSAGE)
	return current < n


func to_float() -> float:
	return float(current)


func get_x_percent(x: float) -> float:
	return float(current) * x


func is_zero() -> bool:
	return is_equal_to(ZERO)


#region Operations


func plus(_amount: int) -> int:
	return current + _amount


func minus(_amount: int) -> int:
	return current - _amount


func times(_amount: float) -> float:
	return to_float() * _amount


func divided_by(_amount: float) -> float:
	return to_float() / _amount


func to_the_power_of(_n: float) -> float:
	return pow(current, _n)


func modulo(_amount: int) -> int:
	return current % _amount


#endregion


#endregion
