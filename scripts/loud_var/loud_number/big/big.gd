class_name Big
extends RefCounted

signal changed

const MANTISSA_PRECISION: float = 0.0000001

static var NEGATIVE_ONE: Big = Big.new(-1.0)
static var ZERO: Big = Big.new(0.0, 0)
static var ONE: Big = Big.new(1.0, 0)
static var TEN: Big = Big.new(10.0, 0)
static var SIXTY: Big = Big.new(60.0, 0)
static var ONE_E_10: Big = Big.new("1e10")

const POW10_OFFSET: int = 12
## Used for quicker pow(10, x) as long as x is >= -12 and <= 11
const POW10: Array[float] = [
	1e-12,
	1e-11,
	1e-10,
	1e-9,
	1e-8,
	1e-7,
	1e-6,
	1e-5,
	1e-4,
	1e-3,
	1e-2,
	1e-1,
	1.0,
	10.0,
	1e2,
	1e3,
	1e4,
	1e5,
	1e6,
	1e7,
	1e8,
	1e9,
	1e10,
	1e11,
]

var mantissa: float
var exponent: int

#region Init

func _init(m: Variant = 1.0, e: int = 0) -> void:
	if m is Big:
		mantissa = m.mantissa
		exponent = m.exponent
	elif typeof(m) == TYPE_STRING or typeof(m) == TYPE_STRING_NAME:
		var scientific: PackedStringArray = m.to_lower().split("e")
		mantissa = float(scientific[0])
		exponent = int(scientific[1]) if scientific.size() > 1 else 0
	else:
		mantissa = m
		exponent = e
	normalize(self)

#endregion

#region Static

static func to_big(_n: Variant) -> Big:
	return _n if _n is Big else Big.new(_n)


static func normalize(_big: Big) -> void:
	var _sign := signf(_big.mantissa)
	_big.mantissa = absf(_big.mantissa)

	if _big.mantissa != 0.0 and (_big.mantissa < 1.0 or _big.mantissa >= 10.0):
		var diff: int = floori(LoudNumber.log10(_big.mantissa))
		if diff > -10 and diff < 248:
			var div: float = 10.0 ** diff
			if div > MANTISSA_PRECISION:
				_big.mantissa /= div
				_big.exponent += diff

	while _big.exponent < 0:
		_big.mantissa *= 0.1
		_big.exponent += 1
	if is_zero_approx(_big.mantissa):
		_big.mantissa = 0.0
		_big.exponent = 0
	while _big.mantissa >= 10.0:
		_big.mantissa *= 0.1
		_big.exponent += 1
	_big.mantissa = snappedf(_big.mantissa, MANTISSA_PRECISION)

	_big.mantissa *= _sign


static func absolute(_n: Variant) -> Big:
	var result := Big.new(_n)
	result.mantissa = absf(result.mantissa)
	return result


static func format_int(value: int) -> String:
	const THOUSANDS_SEPARATOR: String = ","

	if value < 1000:
		return str(value)

	if value > 1_000_000:
		var temp := Big.new(value)
		return temp.to_logarithmic_notation()

	var string: String = str(value)
	var string_mod: int = string.length() % 3
	var output: String = ""
	for i: int in string.length():
		if i != 0 and i % 3 == string_mod:
			output += THOUSANDS_SEPARATOR
		output += string[i]
	return output


static func rand_range(_x: Variant, _y: Variant) -> Big:
	var a := Big.new(_x)
	var b := Big.new(_y)

	if a.is_equal_to(b):
		return a

	# Ensure a < b
	if a.is_greater_than(b):
		var temp: Big = b
		b = a
		a = temp

	var result: Big

	# If a and b are within e10 of each other, calculate it like this
	if absi(b.exponent - a.exponent) <= 10:
		var subtraction := Big.subtract(b, a)
		if subtraction.exponent <= 300:
			var big_range: float = subtraction.to_float()
			result = Big.new(randf_range(0.0, big_range)).plus(a)
			return result

	var random_exponent := randi_range(a.exponent, b.exponent)
	var random_mantissa: float

	if random_exponent == a.exponent:
		random_mantissa = randf_range(a.mantissa, 10.0)
	elif random_exponent == b.exponent:
		random_mantissa = randf_range(1.0, b.mantissa)
	else:
		random_mantissa = randf_range(1.0, 10.0)

	result = Big.new(random_mantissa, random_exponent)

	# Ensure the result is within the original range
	if result.is_less_than(a):
		return a

	if result.is_greater_than(b):
		return b

	return result


## Useful for [code]Array.reduce()[/code] to get the sum of a Big Array
static func sum(a: Big, b: Big) -> Big:
	return add(a, b)

#region Operations

static func add(_x: Variant, _y: Variant) -> Big:
	_x = to_big(_x)
	_y = to_big(_y)
	var result := Big.new(_x)

	var exponent_delta: int = _y.exponent - _x.exponent
	if absi(exponent_delta) < 12:
		var scaled_mantissa: float = _y.mantissa * POW10[exponent_delta + POW10_OFFSET]
		result.mantissa = _x.mantissa + scaled_mantissa

	elif _x.is_less_than(_y):
		# Discard whichever is smaller between x and y
		result.set_to(_y)

	normalize(result)
	return result


static func subtract(_x: Variant, _y: Variant) -> Big:
	var y := to_big(_y)
	var negated_y := Big.new(-y.mantissa, y.exponent)
	return add(negated_y, _x)


static func multiply(_x: Variant, _y: Variant) -> Big:
	_x = to_big(_x)
	_y = to_big(_y)
	var result := Big.new()

	var new_exponent: int = _y.exponent + _x.exponent
	var new_mantissa: float = _y.mantissa * _x.mantissa
	while new_mantissa >= 10.0:
		new_mantissa /= 10.0
		new_exponent += 1
	result.mantissa = new_mantissa
	result.exponent = new_exponent
	normalize(result)
	return result


static func divide(_x: Variant, _y: Variant) -> Big:
	_x = to_big(_x)
	_y = to_big(_y)

	if _y.mantissa == 0.0:
		printerr("Big Error: Divide by ZERO. %se%s" % [_y.mantissa, _y.exponent])
		return _x

	var new_exponent: int = _x.exponent - _y.exponent
	var new_mantissa: float = _x.mantissa / _y.mantissa
	while new_mantissa > 0.0 and new_mantissa < 1.0 and new_exponent > 0:
		new_mantissa *= 10.0
		new_exponent -= 1

	var result := Big.new(new_mantissa, new_exponent)
	return result


static func power(base: Variant, raised: Variant) -> Big:
	assert(raised is not Big)
	var result := Big.new(base)

	if typeof(raised) == TYPE_INT:
		if raised <= 0:
			if raised < 0:
				printerr("Big Error: Negative exponents are not supported!")
			result.mantissa = 1.0
			result.exponent = 0
			return result

		var y_mantissa: float = 1.0
		var y_exponent: int = 0

		while raised > 1:
			normalize(result)
			if raised % 2 == 0:
				result.exponent *= 2
				result.mantissa **= 2
				raised = raised / 2
			else:
				y_mantissa = result.mantissa * y_mantissa
				y_exponent = result.exponent + y_exponent
				result.exponent *= 2
				result.mantissa **= 2
				raised = (raised - 1) / 2

		result.exponent = y_exponent + result.exponent
		result.mantissa = y_mantissa * result.mantissa
		normalize(result)
		return result

	if typeof(raised) == TYPE_FLOAT:
		if result.mantissa == 0.0:
			return result

		# fast track
		var temp: float = result.exponent * raised
		var new_mantissa: float = result.mantissa ** raised

		var fast_track: bool = (
				roundi(raised) == raised
				and temp <= LoudNumber.MAX_INT
				and temp >= LoudNumber.MIN_INT
				and is_finite(temp)
				and is_finite(new_mantissa))

		if fast_track:
			result.mantissa = new_mantissa
			result.exponent = int(temp)
			normalize(result)
			return result

		# a bit slower, still supports floats
		var new_exponent: int = int(temp)
		var residue: float = temp - new_exponent
		new_mantissa = 10 ** (raised * LoudNumber.log10(result.mantissa) + residue)
		if new_mantissa != INF and new_mantissa != -INF:
			result.mantissa = new_mantissa
			result.exponent = new_exponent
			normalize(result)
			return result

		if round(raised) != raised:
			printerr("Big Error: Power function does not support large floats, use integers!")

		return power(base, int(raised))

	printerr("Big Error: Unknown/unsupported data type passed as an exponent in power function!")
	return base


static func modulo(x: Variant, y: Variant) -> Big:
	x = to_big(x)
	y = to_big(y)
	var result: Big = x.divided_by(y)
	result.round_down()
	result.times_equals(y)
	result.set_to(x.minus(result))
	return result


## Returns the minimum of the given values
static func get_min(_x: Variant, _y: Variant) -> Big:
	_x = to_big(_x)
	return _x if _x.is_less_than(_y) else to_big(_y)


## Returns the maximum of the given values
static func get_max(_x: Variant, _y: Variant) -> Big:
	_x = to_big(_x)
	return _x if _x.is_greater_than(_y) else to_big(_y)


static func delta(_x: Variant, _y: Variant) -> Big:
	_x = to_big(_x)
	_y = to_big(_y)
	if _x.is_greater_than_or_equal_to(_y):
		return subtract(_x, _y)
	return subtract(_y, _x)

#endregion

#endregion

#region Modifiers

func set_to(_n: Variant) -> Big:
	var new_value: Big = to_big(_n)
	if new_value.exponent == exponent and is_equal_approx(new_value.mantissa, mantissa):
		return self
	mantissa = new_value.mantissa
	exponent = new_value.exponent
	changed.emit()
	return self


## Allocates a new Big
func plus(_n: Variant) -> Big:
	return add(self, _n)


## Alters this Big
func plus_equals(_n: Variant) -> Big:
	return set_to_sum(self, _n)


## Allocates a new Big
func minus(_n: Variant) -> Big:
	return Big.subtract(self, _n)


## Alters this Big
func minus_equals(_n: Variant) -> Big:
	return set_to_difference(self, _n)


## Allocates a new Big
func times(_n: Variant) -> Big:
	return Big.multiply(self, _n)


## Allocates a new Big with an exponent 1 greater than this one's.
func times_ten() -> Big:
	return Big.new(mantissa, exponent + 1)


## Allocates a new Big with an exponent 1 less than this one's.
func divided_by_ten() -> Big:
	return Big.new(mantissa, exponent - 1)


## Alters this Big
func times_equals(_n: Variant) -> Big:
	return set_to_product(self, _n)


## Alters this Big
func times_equals_ten() -> Big:
	exponent += 1
	changed.emit()
	return self


## Alters this Big
func times_equals_n_tens(n: int) -> Big:
	exponent += n
	changed.emit()
	return self


## Allocates a new Big
func divided_by(_n: Variant) -> Big:
	return Big.divide(self, _n)


## Alters this Big
func divided_by_equals(_n: Variant) -> Big:
	return set_to_quotient(self, _n)


func mod(_n: Variant) -> Big:
	return Big.modulo(self, _n)


func mod_equals(_n: Variant) -> Big:
	return set_to(Big.modulo(self, _n))


func to_the_power_of(_n: Variant) -> Big:
	return power(self, _n)


func to_the_power_of_equals(_n: Variant) -> Big:
	return set_to(power(self, _n))


func rounded() -> Big:
	var precision: float = POW10[mini(11, exponent) + POW10_OFFSET]
	mantissa = roundf(mantissa * precision) / precision
	changed.emit()
	return self


func round_up() -> Big:
	var precision: float = POW10[mini(11, exponent) + POW10_OFFSET]
	mantissa = ceilf(mantissa * precision) / precision
	changed.emit()
	return self


## Round up to 10.0 (next power of 10). 4.5 -> 10 || 8.323e13 -> 1e14
func round_up_tens() -> Big:
	if mantissa != 1.0:
		mantissa = 1.0
		exponent += 1
		changed.emit()
	return self


func round_down() -> Big:
	var precision: float = POW10[mini(11, exponent) + POW10_OFFSET]
	mantissa = floorf(mantissa * precision) / precision
	changed.emit()
	return self


## Allocates a new Big
func squared() -> Big:
	return power(self, 2)


## Alters this Big
func squared_equals() -> Big:
	return set_to(squared())


## Allocates a new Big
func square_root() -> Big:
	assert(mantissa >= 0, "Can't square root a negative!")
	var result := Big.new(self)
	if result.exponent % 2 == 1:
		result.mantissa *= 10
		result.exponent -= 1
	result.mantissa = sqrt(result.mantissa)
	result.exponent /= 2
	normalize(result)
	return result


## Alters this Big
func square_root_equals() -> Big:
	assert(mantissa >= 0, "Can't square root a negative!")
	if exponent % 2 == 1:
		mantissa *= 10
		exponent -= 1
	mantissa = sqrt(mantissa)
	exponent /= 2
	normalize(self)
	changed.emit()
	return self


func set_to_sum(_x: Variant, _y: Variant) -> Big:
	var old_m := mantissa
	var old_e := exponent
	_x = to_big(_x)
	_y = to_big(_y)
	var exponent_delta: int = _y.exponent - _x.exponent
	if absi(exponent_delta) < 12:
		mantissa = _x.mantissa + _y.mantissa * POW10[exponent_delta + POW10_OFFSET]
		exponent = _x.exponent
	elif _x.is_less_than(_y):
		mantissa = _y.mantissa
		exponent = _y.exponent
	else:
		mantissa = _x.mantissa
		exponent = _x.exponent
	if mantissa != old_m or exponent != old_e:
		normalize(self)
		changed.emit()
	return self


func set_to_difference(_x: Variant, _y: Variant) -> Big:
	_x = to_big(_x)
	_y = to_big(_y)
	var old_m := mantissa
	var old_e := exponent
	var neg_mantissa: float = -_y.mantissa
	var exponent_delta: int = _y.exponent - _x.exponent
	if absi(exponent_delta) < 12:
		mantissa = _x.mantissa + neg_mantissa * POW10[exponent_delta + POW10_OFFSET]
		exponent = _x.exponent
	elif _x.is_less_than(_y):
		mantissa = neg_mantissa
		exponent = _y.exponent
	else:
		mantissa = _x.mantissa
		exponent = _x.exponent
	if mantissa != old_m or exponent != old_e:
		normalize(self)
		changed.emit()
	return self


func set_to_product(_x: Variant, _y: Variant) -> Big:
	var old_m := mantissa
	var old_e := exponent
	_x = to_big(_x)
	_y = to_big(_y)
	exponent = _x.exponent + _y.exponent
	mantissa = _x.mantissa * _y.mantissa
	while mantissa >= 10.0:
		mantissa /= 10.0
		exponent += 1
	if mantissa != old_m or exponent != old_e:
		normalize(self)
		changed.emit()
	return self


func set_to_quotient(_x: Variant, _y: Variant) -> Big:
	_x = to_big(_x)
	_y = to_big(_y)
	if _y.mantissa == 0.0:
		printerr("Big Error: Divide by ZERO. %se%s" % [_y.mantissa, _y.exponent])
		set_to(_x)
		return self
	var old_m := mantissa
	var old_e := exponent
	exponent = _x.exponent - _y.exponent
	mantissa = _x.mantissa / _y.mantissa
	while mantissa > 0.0 and mantissa < 1.0 and exponent > 0:
		mantissa *= 10.0
		exponent -= 1
	if mantissa != old_m or exponent != old_e:
		normalize(self)
		changed.emit()
	return self


func set_to_min(_x: Variant, _y: Variant) -> Big:
	_x = to_big(_x)
	_y = to_big(_y)
	if _x.is_less_than(_y):
		if _x.mantissa == mantissa and _x.exponent == exponent:
			return self
		mantissa = _x.mantissa
		exponent = _x.exponent
	else:
		if _y.mantissa == mantissa and _y.exponent == exponent:
			return self
		mantissa = _y.mantissa
		exponent = _y.exponent
	changed.emit()
	return self


func set_to_max(_x: Variant, _y: Variant) -> Big:
	_x = to_big(_x)
	_y = to_big(_y)
	if _x.is_greater_than(_y):
		if _x.mantissa == mantissa and _x.exponent == exponent:
			return self
		mantissa = _x.mantissa
		exponent = _x.exponent
	else:
		if _y.mantissa == mantissa and _y.exponent == exponent:
			return self
		mantissa = _y.mantissa
		exponent = _y.exponent
	changed.emit()
	return self

#endregion

#region Comparisons

func to_float() -> float:
	assert(exponent < 307, "The resulting float would be too big. Fix ur fucking game")
	if exponent < 12:
		return snappedf(mantissa * POW10[exponent + POW10_OFFSET], MANTISSA_PRECISION)
	return snappedf(mantissa * (10.0 ** exponent), MANTISSA_PRECISION)


## Returns the log (base 10) value of this Big
func log10() -> float:
	if mantissa <= 0.0:
		return 0.0
	var result: float = float(exponent) + LoudNumber.log10(mantissa)
	return result


## Returns the natural log (base e) value of this Big
func ln() -> float:
	return log10() * LoudNumber.NATURAL_LOG


func to_int() -> int:
	return roundi(mantissa * pow(10, exponent))


func get_value() -> Big:
	return self


func val() -> Big:
	return self


func is_equal_to(_n: Variant) -> bool:
	_n = to_big(_n)
	normalize(_n)
	return _n.exponent == exponent and is_equal_approx(_n.mantissa, mantissa)


func is_between(a: Variant, b: Variant) -> bool:
	return is_greater_than_or_equal_to(a) and is_less_than_or_equal_to(b)


func is_greater_than(_n: Variant) -> bool:
	return not is_less_than_or_equal_to(_n)


func is_greater_than_or_equal_to(_n: Variant) -> bool:
	return not is_less_than(_n)


func is_less_than(_n: Variant) -> bool:
	_n = to_big(_n)
	if (
			mantissa == 0 and (
					_n.mantissa > MANTISSA_PRECISION or
					mantissa < MANTISSA_PRECISION
			) and _n.mantissa == 0
	):
		return false
	if exponent < _n.exponent:
		if exponent == _n.exponent - 1 and mantissa > 10 * _n.mantissa:
			return false
		return true

	if exponent == _n.exponent:
		if mantissa < _n.mantissa:
			return true
		return false

	if exponent == _n.exponent + 1 and mantissa * 10 < _n.mantissa:
		return true
	return false


func is_less_than_or_equal_to(_n: Variant) -> bool:
	_n = to_big(_n)
	if _n.exponent == exponent and is_equal_approx(_n.mantissa, mantissa):
		return true
	if is_less_than(_n):
		return true
	return false


func is_zero() -> bool:
	return is_equal_to(ZERO)


func is_positive() -> bool:
	return mantissa >= LoudFloat.ZERO


func is_negative() -> bool:
	return mantissa < LoudFloat.ZERO


func percent_of(_n: Variant) -> float:
	_n = to_big(_n)

	assert(not is_zero_approx(_n.mantissa))

	if exponent > _n.exponent:
		return LoudFloat.ONE

	var exponent_delta: int = _n.exponent - exponent
	if exponent_delta > 9:
		return LoudFloat.ZERO

	var result := Big.new(mantissa / _n.mantissa, exponent - _n.exponent)
	normalize(result)

	return clampf(result.mantissa * pow(10, result.exponent), 0.0, 1.0)

#endregion

#region Get Text

func get_text() -> String:
	if exponent < 6:
		return LoudNumber.format_number(to_float())

	if exponent >= 1000:
		return "e" + Big.new(exponent).get_text()

	var sign_text: String = "-" if signf(mantissa) == -1.0 else ""
	var result: String

	match LoudNumber.notation:
		LoudNumber.Notation.STANDARD:
			result = to_standard_notation()
		LoudNumber.Notation.LETTERS:
			result = to_letters_notation()
		LoudNumber.Notation.LOGARITHMIC:
			result = to_logarithmic_notation()
		LoudNumber.Notation.SCIENTIFIC:
			result = to_scientific_notation()
		LoudNumber.Notation.ENGINEERING:
			result = to_engineering_notation()

	return sign_text + result


func to_standard_notation() -> String:
	var index: int = floori(float(exponent) * LoudFloat.ONE_THIRD)
	if index >= LoudNumber.STANDARD_SUFFIXES.size():
		return to_scientific_notation()

	var _mod: int = exponent % 3

	var mantissa_value: float = absf(mantissa) * pow(10, _mod)
	var mantissa_text: String = String.num(mantissa_value, 1 if mantissa_value < 10 else 0)
	if mantissa_text == "1000":
		mantissa_text = "1"
		index += 1
		if index >= LoudNumber.STANDARD_SUFFIXES.size():
			return to_scientific_notation()
	if mantissa_text.ends_with(".0"):
		mantissa_text = mantissa_text.replace(".0", "")

	var exponent_text: String = LoudNumber.STANDARD_SUFFIXES[index]

	return "%s%s" % [mantissa_text, exponent_text]


func to_letters_notation() -> String:
	var index: int = floori(float(exponent) * LoudFloat.ONE_THIRD)
	if index >= LoudNumber.LETTER_SUFFIXES.size():
		return to_scientific_notation()

	var _mod: int = exponent % 3

	var mantissa_value: float = absf(mantissa) * pow(10, _mod)
	var mantissa_text: String = String.num(mantissa_value, 1 if mantissa_value < 10 else 0)
	if mantissa_text == "1000":
		mantissa_text = "1"
		index += 1
		if index >= LoudNumber.STANDARD_SUFFIXES.size():
			return to_scientific_notation()
	if mantissa_text.ends_with(".0"):
		mantissa_text = mantissa_text.replace(".0", "")

	var exponent_text: String = LoudNumber.LETTER_SUFFIXES[index]

	return "%s%s" % [mantissa_text, exponent_text]


func to_engineering_notation() -> String:
	const BASE_TEXT: String = "%se%s"
	var _mod: int = exponent % 3
	var mantissa_value: float = absf(mantissa) * pow(10, _mod)
	var mantissa_text: String = String.num(mantissa_value, 1 if mantissa_value < 10 else 0)
	var exponent_text: String
	if mantissa_text == "1000":
		mantissa_text = "1"
		exponent_text = format_int(exponent + 1)
	else:
		exponent_text = format_int(exponent - _mod)
	if mantissa_text.ends_with(".0"):
		mantissa_text = mantissa_text.replace(".0", "")
	return BASE_TEXT % [mantissa_text, exponent_text]


func to_logarithmic_notation() -> String:
	if exponent >= 100:
		return "e" + Big.new(exponent).get_text()

	var log_value: float = exponent + LoudNumber.log10(absf(mantissa))
	var decimals: int = 2 if log_value < 10 else 1

	var result := "e" + LoudNumber.format_number(log_value, decimals)
	if result.ends_with(".0"):
		result = result.replace(".0", "")

	return result


func to_scientific_notation() -> String:
	const BASE_TEXT: String = "%se%s"

	var mantissa_text: String = str(absf(mantissa)).pad_decimals(1)
	var exponent_text: String
	if mantissa_text == "10.0":
		mantissa_text = "1"
		exponent_text = format_int(exponent + 1)
	else:
		if mantissa_text.ends_with(".0"):
			mantissa_text = mantissa_text.replace(".0", "")
		exponent_text = format_int(exponent)

	return BASE_TEXT % [mantissa_text, exponent_text]


## Returns [code]mantisa + "e" + exponent[/code] with no formatting or rounding
func to_plain_scientific() -> String:
	const BASE_TEXT: String = "%se%s"
	if is_nan(mantissa):
		mantissa = 1.0
	if is_nan(exponent):
		exponent = 0
	return BASE_TEXT % [mantissa, exponent]

#endregion
