class_name BigFloat
extends LoudNumber

@warning_ignore("unused_private_class_variable")
@export var saved_value: String
@export var saved_pending_value: String

var current := Big.new(0.0):
	get = _get_current
var base: Big
var previous := Big.new(0.0)
#var unclamped_value: Big
var cat: Variant
var custom_minimum_limit: Big:
	set = _set_minimum_limit
var custom_maximum_limit: Big:
	set = _set_maximum_limit
var save_pending: bool = false

#region Init

func _init(x: Variant = 1.0) -> void:
	base = Big.new(x)
	current = Big.new(base)
	changed.connect(loud_number_init)
	loud_number_init()


func _create_book() -> void:
	book = Book.new(Book.Type.BIG)
	book.changed.connect(sync.call_deferred)
	book.sync_allowed.became_true.connect(sync.call_deferred)
	book.pending_changed.connect(pending_changed.emit)

#endregion

#region Setters

func _set_current(n: Big) -> void:
	previous.set_to(current)

	if custom_maximum_limit != null or custom_minimum_limit != null:
		#unclamped_value.set_to(n)

		if custom_maximum_limit != null:
			n = Big.get_min(n, custom_maximum_limit)
		if custom_minimum_limit != null:
			n = Big.get_max(n, custom_minimum_limit)

	if not current.is_equal_to(n):
		current.set_to(n)
		text_requires_update = true

	if not previous.is_equal_to(current):
		_emit_signals(previous, current)


func _get_current() -> Big:
	sync()
	return current


func _set_minimum_limit(n: Big) -> void:
	custom_minimum_limit = n
	#if not unclamped_value:
	#unclamped_value = Big.new(0.0)
	clamp_current()


func _set_maximum_limit(n: Big) -> void:
	custom_maximum_limit = n
	#if not unclamped_value:
	#unclamped_value = Big.new(0.0)
	clamp_current()

#endregion

#region Save

func save_current_value() -> void:
	saved_value = current.to_plain_scientific()
	if save_pending:
		saved_pending_value = book.get_pending().to_plain_scientific()


func load_saved_value() -> void:
	if not saved_value.is_empty():
		set_to(saved_value)
	if save_pending and not saved_pending_value.is_empty():
		plus_equals(saved_pending_value)

#endregion

#region Signals

func _emit_signals(_previous: Big, _current: Big) -> void:
	assert(not _previous.is_equal_to(_current), "Do not emit signals if nothing changed.")

	if _previous.is_greater_than(_current):
		decreased.emit(_previous.minus(_current))
	elif _previous.is_less_than(_current):
		increased.emit(_current.minus(_previous))

	if _previous.is_zero():
		became_non_zero.emit(_current)
	elif _current.is_zero():
		became_zero.emit(_previous)

	changed.emit()

#endregion

#region Action

func reset() -> void:
	current.set_to(base)
	super()


func set_to(amount: Variant) -> void:
	_set_current(Big.to_big(amount))


func plus_equals(amount: Variant) -> void:
	previous.set_to(current)
	current.set_to_sum(current, amount)
	_apply_change()


func plus_equals_one() -> void:
	previous.set_to(current)
	current.set_to_sum(current, LoudInt.ONE)
	_apply_change()


func minus_equals(amount: Variant) -> void:
	previous.set_to(current)
	current.set_to_difference(current, amount)
	_apply_change()


func minus_equals_one() -> void:
	previous.set_to(current)
	current.set_to_difference(current, LoudInt.ONE)
	_apply_change()


func times_equals(amount: Variant) -> void:
	previous.set_to(current)
	current.set_to_product(current, amount)
	_apply_change()


func times_equals_ten() -> void:
	previous.set_to(current)
	current.times_equals_ten()
	_apply_change()


func divided_by_equals(amount: Variant) -> void:
	previous.set_to(current)
	current.set_to_quotient(current, amount)
	_apply_change()


func sync() -> void:
	if book.sync_allowed.is_true() and book.sync_required:
		book.sync_required = false
		set_to(book.sync.call(base))


func clamp_current() -> void:
	if custom_maximum_limit:
		current.set_to_min(current, custom_maximum_limit)
	if custom_minimum_limit:
		current.set_to_max(current, custom_minimum_limit)


func _apply_change() -> void:
	clamp_current()
	if not previous.is_equal_to(current):
		text_requires_update = true
		_emit_signals(previous, current)


func set_default_value(n: Variant) -> void:
	base = Big.new(n)


func set_default_value_and_reset(n: Variant) -> void:
	set_default_value(n)
	reset()


func copycat(_cat: Variant) -> void:
	cat = _cat
	set_default_value_and_reset(0.0)
	copy()
	cat.changed.connect(copy)


func copy() -> void:
	book.edit_change(Book.Category.ADDED, cat, cat.get_value())


func clear_copycat() -> void:
	cat.changed.disconnect(copy)
	cat = null

#endregion

#region Get

func get_value() -> Big:
	return current


func val() -> Big:
	return current


func get_effective_value() -> Big:
	return Big.add(current, book.get_pending())


func get_text() -> String:
	if text_requires_update:
		text_requires_update = false
		#if not unclamped_value or current.is_equal_to(unclamped_value.val()):
		text = current.get_text()
		#else:
		#text = "%s (%s)" % [current.get_text(), unclamped_value.get_text()]
	return text


func get_pending() -> Big:
	return book.get_pending()


func get_pending_text() -> String:
	return get_pending().get_text()


func is_positive() -> bool:
	return current.is_positive()


func is_between(a: Variant, b: Variant) -> bool:
	return is_greater_than_or_equal_to(a) and is_less_than_or_equal_to(b)


func is_greater_than(n: Variant) -> bool:
	return not is_less_than_or_equal_to(n)


func is_greater_than_or_equal_to(n: Variant) -> bool:
	return not is_less_than(n)


func is_equal_to(n: Variant) -> bool:
	return current.is_equal_to(n)


func is_less_than_or_equal_to(n: Variant) -> bool:
	return is_less_than(n) or is_equal_to(n)


func is_less_than(n: Variant) -> bool:
	return current.is_less_than(n)


func is_zero() -> bool:
	return (
			current.mantissa == Big.ZERO.mantissa
			and current.exponent == Big.ZERO.exponent)

#region - Operations

func plus(_amount: Variant) -> Big:
	return current.plus(_amount)


func minus(_amount: Variant) -> Big:
	return current.minus(_amount)


func times(_amount: Variant) -> Big:
	return current.times(_amount)


func times_ten() -> Big:
	return current.times_ten()


func divided_by(_amount: Variant) -> Big:
	return current.divided_by(_amount)


func to_the_power_of(_n: Variant) -> Big:
	return current.to_the_power_of(_n)

#endregion

#endregion
