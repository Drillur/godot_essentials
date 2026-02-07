class_name Big
extends RefCounted


signal changed

const MANTISSA_PRECISION: float = 0.0000001

static var ZERO: Big = Big.new(0.0, 0)
static var ONE: Big = Big.new(1.0, 0)
static var SIXTY: Big = Big.new(60.0, 0)

var mantissa: float
var exponent: int


#region Init


func _init(m: Variant = 1.0, e: int = 0) -> void:
	if m is Big:
		mantissa = m.mantissa
		exponent = m.exponent
	elif typeof(m) == TYPE_STRING or typeof(m) == TYPE_STRING_NAME:
		var scientific: PackedStringArray = m.split("e")
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
	
	if _big.mantissa < 1.0 or _big.mantissa >= 10.0:
		var diff: int = floor(LoudNumber.log10(_big.mantissa))
		if diff > -10 and diff < 248:
			var div := 10.0 ** diff
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
	elif value > 1_000_000:
		var temp := Big.new(value)
		return temp.to_logarithmic_notation()
	var string := str(value)
	var string_mod := string.length() % 3
	var output := ""
	for i in range(0, string.length()):
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
	elif result.is_greater_than(b):
		return b
	
	return result


#region Operations


static func add(_x: Variant, _y: Variant) -> Big:
	_x = to_big(_x)
	_y = to_big(_y)
	var result := Big.new(_x)
	
	var exponent_delta: int = _y.exponent - _x.exponent
	if exponent_delta < 248.0:
		var scaled_mantissa: float = _y.mantissa * pow(10, exponent_delta)
		result.mantissa = _x.mantissa + scaled_mantissa
	elif _x.is_less_than(_y): # When difference between values is too big, discard the smaller number
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


static func power(_x: Variant, _y: Variant) -> Big:
	var result := Big.new(_x)
	if typeof(_y) == TYPE_INT:
		if _y <= 0:
			if _y < 0:
				printerr("Big Error: Negative exponents are not supported!")
			result.mantissa = 1.0
			result.exponent = 0
			return result
		
		var y_mantissa: float = 1.0
		var y_exponent: int = 0
		
		while _y > 1:
			normalize(result)
			if _y % 2 == 0:
				result.exponent *= 2
				result.mantissa **= 2
				_y = _y / 2
			else:
				y_mantissa = result.mantissa * y_mantissa
				y_exponent = result.exponent + y_exponent
				result.exponent *= 2
				result.mantissa **= 2
				_y = (_y - 1) / 2
		
		result.exponent = y_exponent + result.exponent
		result.mantissa = y_mantissa * result.mantissa
		normalize(result)
		return result
	
	elif typeof(_y) == TYPE_FLOAT:
		if result.mantissa == 0:
			return result
		
		# fast track
		var temp: float = result.exponent * _y
		var newMantissa = result.mantissa ** _y
		if (
			roundi(_y) == _y and
			temp <= LoudNumber.MAX_INT and
			temp >= LoudNumber.MIN_INT and
			is_finite(temp)
		):
			if is_finite(newMantissa):
				result.mantissa = newMantissa
				result.exponent = int(temp)
				normalize(result)
				return result
		
		# a bit slower, still supports floats
		var newExponent: int = int(temp)
		var residue: float = temp - newExponent
		newMantissa = 10 ** (_y * LoudNumber.log10(result.mantissa) + residue)
		if newMantissa != INF and newMantissa != -INF:
			result.mantissa = newMantissa
			result.exponent = newExponent
			normalize(result)
			return result
		
		if round(_y) != _y:
			printerr("Big Error: Power function does not support large floats, use integers!")
		
		return power(_x, int(_y))
	
	elif _y is Big:
		# warning - this might be slow!
		if _y.isEqualTo(0):
			return Big.new(1)
		if _y.isLessThan(0):
			printerr("Big Error: Negative exponents are not supported!")
			return Big.new(0)
		
		var exponent_decremented: Big = _y.minus(1)
		while exponent_decremented.isGreaterThan(0):
			result.times_equals(_x)
			exponent_decremented.minus_equals(1)
		return result
	
	else:
		printerr("Big Error: Unknown/unsupported data type passed as an exponent in power function!")
		return _x


static func root(_x: Big) -> Big:
	var result := Big.new(_x)
	if result.exponent % 2 == 0:
		result.mantissa = sqrt(result.mantissa)
		@warning_ignore("integer_division")
		result.exponent = result.exponent / 2
	else:
		result.mantissa = sqrt(result.mantissa * 10)
		@warning_ignore("integer_division")
		result.exponent = (result.exponent - 1) / 2
	normalize(result)
	return result


static func modulo(_x: Big, _y: Variant) -> Big:
	var result := Big.new(_x.mantissa, _x.exponent)
	_y = to_big(_y)
	var big := { "mantissa": _x.mantissa, "exponent": _x.exponent }
	result.divided_by_equals(_y)
	Big.round_down(result)
	result.times_equals(_y)
	result.minus_equals(big)
	result.mantissa = absf(result.mantissa)
	return result


static func round_up_to_even_power_of_10(x: Big) -> Big:
	# If mantissa is 1.0, it's at 10^n which is already a power of 10
	if x.mantissa == 1.0:
		return x
	
	# Round up to 10.0 (next power of 10)
	x.mantissa = 10.0
	normalize(x)
	
	return x


static func round_up(n: Big) -> Big:
	if n.exponent == 0:
		n.mantissa = ceilf(n.mantissa)
	else:
		var precision: float = pow(10, mini(8, n.exponent))
		n.mantissa = ceilf(n.mantissa * precision) / precision
	return n


static func round_big(n: Big) -> Big:
	if n.exponent == 0:
		n.mantissa = roundf(n.mantissa)
	else:
		var precision: float = pow(10, mini(8, n.exponent))
		n.mantissa = roundf(n.mantissa * precision) / precision
	return n


static func round_down(n: Big) -> Big:
	if n.exponent == 0:
		n.mantissa = floorf(n.mantissa)
	else:
		var precision: float = pow(10, mini(8, n.exponent))
		n.mantissa = floorf(n.mantissa * precision) / precision
	return n


static func get_min(_x: Variant, _y: Variant) -> Big:
	_x = to_big(_x)
	return _x if _x.is_less_than(_y) else to_big(_y)


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


func plus(_n: Variant) -> Big:
	return add(self, _n)


func plus_equals(_n: Variant) -> Big:
	set_to(add(self, _n))
	return self


func minus(_n: Variant) -> Big:
	return Big.subtract(self, _n)


func minus_equals(_n: Variant) -> Big:
	set_to(Big.subtract(self, _n))
	return self


func times(_n: Variant) -> Big:
	return Big.multiply(self, _n)


func times_equals(_n: Variant) -> Big:
	set_to(Big.multiply(self, _n))
	return self


func divided_by(_n: Variant) -> Big:
	return Big.divide(self, _n)


func divided_by_equals(_n: Variant) -> Big:
	set_to(Big.divide(self, _n))
	return self


func mod(_n: Variant) -> Big:
	return Big.modulo(self, _n)


func mod_equals(_n: Variant) -> Big:
	set_to(Big.modulo(self, _n))
	return self


func to_the_power_of(_n: Variant) -> Big:
	return power(self, _n)


func to_the_power_of_equals(_n: Variant) -> Big:
	set_to(power(self, _n))
	return self


func squared() -> Big:
	return to_the_power_of(2)


func squared_equals() -> Big:
	set_to(squared())
	return self


func square_root() -> Big:
	var new_value := Big.root(self)
	mantissa = new_value.mantissa
	exponent = new_value.exponent
	return self


#endregion


#region Comparisons


func to_float() -> float:
	assert(exponent < 307, "The resulting float would be too big. Fix ur fucking game")
	return snappedf(
		float("%se%s" % [mantissa, exponent]),
		MANTISSA_PRECISION
	)


## Returns the log (base 10) value of this Big
func to_log() -> float:
	if is_zero():
		return 0.0
	var result: float = float(exponent) + LoudNumber.log10(mantissa)
	return result


## Multiply the common log of this Big by log(10), resulting in ln(this Big)
## In GDScript, log(10) = ~2.302585
## Natural log of x: log(x)
## Common log of x: log(x) / log(10)
func to_natural_log() -> float:
	return to_log() * LoudNumber.NATURAL_LOG


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
	normalize(_n)
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
	elif exponent == _n.exponent:
		if mantissa < _n.mantissa:
			return true
		return false
	else:
		if exponent == _n.exponent + 1 and mantissa * 10 < _n.mantissa:
			return true
		return false


func is_less_than_or_equal_to(_n: Variant) -> bool:
	_n = to_big(_n)
	normalize(_n)
	if is_less_than(_n):
		return true
	if _n.exponent == exponent and is_equal_approx(_n.mantissa, mantissa):
		return true
	return false


func is_zero() -> bool:
	return is_equal_to(ZERO)


func is_positive() -> bool:
	return mantissa >= LoudFloat.ZERO


func percent_of(_n: Variant) -> float:
	_n = to_big(_n)
	
	assert(not is_zero_approx(_n.mantissa),
			"You can't divide by ZERO, it's impossible. Why isn't it possible you stupid bastard?")
	
	if exponent > _n.exponent:
		return LoudFloat.ONE
	
	var exponent_delta: int = _n.exponent - exponent
	if exponent_delta > 9:
		return LoudFloat.ZERO
	
	var result := Big.new(
			mantissa / _n.mantissa,
			exponent - _n.exponent)
	normalize(result)
	
	return clampf(
		result.mantissa * pow(10, result.exponent),
		LoudFloat.ZERO,
		LoudFloat.ONE
	)


#endregion


#region Get Text


func get_text() -> String:
	if exponent < 6:
		return LoudNumber.format_number(to_float())
	elif exponent >= 1000:
		return "e" + Big.new(exponent).get_text()
	
	var sign_text: String = "-" if signf(mantissa) == -1.0 else ""
	var result: String
	match Settings.notation:
		Settings.Notation.STANDARD:
			result = to_standard_notation()
		Settings.Notation.LETTERS:
			result = to_letters_notation()
		Settings.Notation.LOGARITHMIC:
			result = to_logarithmic_notation()
		Settings.Notation.SCIENTIFIC:
			result = to_scientific_notation()
		Settings.Notation.ENGINEERING:
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


func to_plain_scientific() -> String:
	const BASE_TEXT: String = "%se%s"
	if is_nan(mantissa):
		mantissa = 1.0
	if is_nan(exponent):
		exponent = 0
	if not is_positive():
		mantissa = 0.0
	return BASE_TEXT % [str(mantissa), str(exponent)]


#endregion


#region Leftovers. Uncomment if u need em i guess


# func ln() -> float:
# 	return 2.302585092994045 * logN(10)


# func logN(base) -> float:
# 	return (2.302585092994046 / log(base)) * (exponent + Big.LoudNumber.log10(mantissa))


# func pow10(value: int) -> void:
# 	mantissa = 10 ** (value % 1)
# 	exponent = int(value)


#endregion
