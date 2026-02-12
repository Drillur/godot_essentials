class_name LoudFloat
extends LoudNumber

const ONE: float = 1.0
const ZERO: float = 0.0
const ONE_PERCENT: float = 0.01
const ONE_THIRD: float = 1.0 / 3
const FIFTY_PERCENT: float = 0.5
const NATURAL_LOGARITHM: float = 2.71828

@export var current: float:
	set = _set_current
@export var saved_pending_value: float = 0.0

var previous: float
var base: float
var custom_minimum_limit := LoudNumber.MIN_FLOAT:
	set = _set_minimum_limit
var custom_maximum_limit := LoudNumber.MAX_FLOAT:
	set = _set_maximum_limit

#region Static

static func roll_as_int(n: float) -> int:
	var chance_to_return_plus_one: float = get_decimals(n)
	var result: int = floori(n)
	if randf() < chance_to_return_plus_one:
		result += 1
	return result


static func get_decimals(n: float) -> float:
	return n - floorf(n)


static func to_float(n: Variant) -> float:
	match typeof(n):
		TYPE_FLOAT:
			return n
		TYPE_INT:
			return float(n)
		TYPE_OBJECT:
			if n is Big:
				return n.to_float()
			elif n is LoudFloat:
				return n.current
			elif n is LoudInt:
				return float(n.current)
	return float(n)

#endregion

#region Init

func _init(_base: float = 0.0, _custom_minimum_limit := MIN_FLOAT, _custom_maximum_limit := MAX_FLOAT) -> void:
	base = _base
	current = base
	previous = base
	changed.connect(loud_number_init)

	custom_minimum_limit = _custom_minimum_limit
	custom_maximum_limit = _custom_maximum_limit


func _create_book() -> void:
	book = Book.new(Book.Type.FLOAT)
	book.changed.connect(sync)
	book.pending_changed.connect(pending_changed.emit)

#endregion

#region Setters

func _set_current(n: float) -> void:
	n = clampf(n, custom_minimum_limit, custom_maximum_limit)
	if is_zero_approx(n):
		n = 0.0

	if current == n:
		return

	previous = current
	current = n
	text_requires_update = true

	_emit_signals(previous, current)


func _set_minimum_limit(n: float) -> void:
	custom_minimum_limit = n
	clamp_current()


func _set_maximum_limit(n: float) -> void:
	custom_maximum_limit = n
	clamp_current()

#endregion

#region Signals

func _emit_signals(_previous: float, _current: float) -> void:
	assert(_current != _previous, "Do not emit signals if nothing changed.")
	if _previous > _current:
		decreased.emit(_previous - _current)
	elif _previous < _current:
		increased.emit(_current - _previous)
	
	if _previous == 0.0:
		became_non_zero.emit()
	elif _current == 0.0:
		became_zero.emit()
	
	changed.emit()


func save_pending_value() -> void:
	saved_pending_value = float(book.get_pending())


func load_pending_value() -> void:
	plus_equals(saved_pending_value)

#endregion

#region Action

func reset() -> void:
	current = base
	super()


func set_to(amount: float) -> void:
	current = amount


func plus_equals(amount: float) -> void:
	if is_zero_approx(amount):
		return
	current += amount


func plus_equals_one() -> void:
	current += ONE


func minus_equals(amount: float) -> void:
	if is_zero_approx(amount):
		return
	current -= amount


func minus_equals_one() -> void:
	current -= ONE


func times_equals(amount: float) -> void:
	if is_equal_approx(amount, ONE):
		return
	current *= amount


func divided_by_equals(amount: float) -> void:
	if is_equal_approx(amount, ONE):
		return
	current /= amount


func sync() -> void:
	if book.sync_allowed.is_true():
		set_to(book.sync.call(base))


func clamp_current() -> void:
	current = clampf(current, custom_minimum_limit, custom_maximum_limit)


func set_default_value(n: float) -> void:
	base = n


func copycat(cat: Resource) -> void:
	set_default_value(ZERO)
	set_to(ZERO)
	super(cat)


func set_bool_limiter(b: LoudBool, limit: float) -> void:
	if b.is_false():
		custom_minimum_limit = limit
		custom_maximum_limit = limit
		set_to(limit)
	b.became_true.connect(
		func():
			custom_minimum_limit = MIN_FLOAT
			custom_maximum_limit = MAX_FLOAT
			reset()
	)
	b.became_false.connect(
		func():
			custom_minimum_limit = limit
			custom_maximum_limit = limit
			set_to(limit)
	)

#endregion

#region Get

func get_value() -> float:
	return current


func val() -> float:
	return current


func get_effective_value() -> float:
	return current + book.get_pending()


func get_text() -> String:
	if text_requires_update:
		update_text(current)
	return text


func is_between(a: Variant, b: Variant) -> bool:
	return is_greater_than_or_equal_to(a) and is_less_than_or_equal_to(b)


func is_positive() -> bool:
	return current >= ZERO


func is_greater_than(n: Variant) -> bool:
	return not is_less_than_or_equal_to(n)


func is_greater_than_or_equal_to(n: Variant) -> bool:
	return not is_less_than(n)


func is_equal_to(n: Variant) -> bool:
	assert(VALID_COMPARISON_TYPES.has(typeof(n)), INVALID_TYPE_MESSAGE)
	return is_equal_approx(current, n)


func is_less_than_or_equal_to(n: Variant) -> bool:
	return is_less_than(n) or is_equal_to(n)


func is_less_than(n: Variant) -> bool:
	assert(VALID_COMPARISON_TYPES.has(typeof(n)), INVALID_TYPE_MESSAGE)
	return current < n


func to_int() -> int:
	return int(current)


func get_x_percent(x: float) -> float:
	return current * x


func is_zero() -> bool:
	return is_equal_to(ZERO)

#region Operations

func plus(_amount: float) -> float:
	return current + _amount


func minus(_amount: float) -> float:
	return current - _amount


func times(_amount: float) -> float:
	return current * _amount


func divided_by(_amount: float) -> float:
	return current / _amount


func to_the_power_of(_n: float) -> float:
	return pow(current, _n)


func to_ceil() -> float:
	return ceilf(current)

#endregion

#endregion
