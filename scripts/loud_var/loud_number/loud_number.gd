class_name LoudNumber
extends LoudVar

@warning_ignore("unused_signal")
signal pending_changed
@warning_ignore("unused_signal")
signal increased(amount)
@warning_ignore("unused_signal")
signal decreased(amount)
@warning_ignore("unused_signal")
signal number_changed(number)
signal text_changed

const NATURAL_LOG: float = log(10)
const MAX_INT := 9223372036854775807
const MIN_INT := -9223372036854775808
const MAX_FLOAT := 1.79769e308
const MIN_FLOAT := -1.79769e308
const VALID_COMPARISON_TYPES: Array[Variant.Type] = [
	TYPE_FLOAT,
	TYPE_INT,
]
const INVALID_TYPE_MESSAGE: String = "n must be int or float"
const STANDARD_SUFFIXES: PackedStringArray = [
	"",
	"K",
	"M",
	"B",
	"T",
	"Qa",
	"Qi",
	"Sx",
	"Sp",
	"Oc",
	"No", # 1e30
	"Dc",
	"UDc",
	"DDc",
	"TDc",
	"QaDc",
	"QiDc",
	"SxDc",
	"SpDc",
	"OcDc",
	"NoDc", # 1e60
	"Vg",
	"UVg",
	"DVg",
	"TVg",
	"QaVg",
	"QiVg",
	"SxVg",
	"SpVg",
	"OcVg",
	"NoVg", # 1e90
	"Tg",
	"UTg",
	"DTg",
	"TTg",
	"QaTg",
	"QiTg",
	"SxTg",
	"SpTg",
	"OcTg",
	"NoTg", # 1e120
	"Qag",
	"UQag",
	"DQag",
	"TQag",
	"QaQag",
	"QiQag",
	"SxQag",
	"SpQag",
	"OcQag",
	"NoQag", # 1e150
	"Qig",
	"UQig",
	"DQig",
	"TQig",
	"QaQig",
	"QiQig",
	"SxQig",
	"SpQig",
	"OcQig",
	"NoQig", # 1e180
	"Sxg",
	"USxg",
	"DSxg",
	"TSxg",
	"QaSxg",
	"QiSxg",
	"SxSxg",
	"SpSxg",
	"OcSxg",
	"NoSxg", # 1e210
	"Spg",
	"USpg",
	"DSpg",
	"TSpg",
	"QaSpg",
	"QiSpg",
	"SxSpg",
	"SpSpg",
	"OcSpg",
	"NoSpg", # 1e240
	"Ocg",
	"UOcg",
	"DOcg",
	"TOcg",
	"QaOcg",
	"QiOcg",
	"SxOcg",
	"SpOcg",
	"OcOcg",
	"NoOcg", # 1e270
	"Nog",
	"UNog",
	"DNog",
	"TNog",
	"QaNog",
	"QiNog",
	"SxNog",
	"SpNog",
	"OcNog",
	"NoNog", # 1e300
	"C",
	"UC",
	"DC",
	"TC",
	"QaC",
	"QiC",
	"SxC",
	"SpC",
	"OcC",
	"NoC", # 1e330
]
const LETTER_SUFFIXES: PackedStringArray = [
	"",
	"K",
	"a",
	"b",
	"c",
	"d",
	"e",
	"f",
	"g",
	"h",
	"i", # i: e30
	"j",
	"k",
	"l",
	"m",
	"n",
	"o",
	"p",
	"q",
	"r",
	"s", # s: e60
	"t",
	"u",
	"v",
	"w",
	"x",
	"y",
	"z",
	"aa",
	"ab",
	"ac", # ac: e90
	"ad",
	"ae",
	"af",
	"ag",
	"ah",
	"ai",
	"aj",
	"ak",
	"al",
	"am", # am: e120
	"an",
	"ao",
	"ap",
	"aq",
	"ar",
	"as",
	"at",
	"au",
	"av",
	"aw", # aw: e150
	"ax",
	"ay",
	"az",
	"ba",
	"bb",
	"bc",
	"bd",
	"be",
	"bf",
	"bg", # bg: e180
	"bh",
	"bi",
	"bj",
	"bk",
	"bl",
	"bm",
	"bn",
	"bo",
	"bp",
	"bq", # bq: e210
	"br",
	"bs",
	"bt",
	"bu",
	"bv",
	"bw",
	"bx",
	"by",
	"bz",
	"ca", # ca: e240
	"cb",
	"cc",
	"cd",
	"ce",
	"cf",
	"cg",
	"ch",
	"ci",
	"cj",
	"ck", # ck: e270
	"cl",
	"cm",
	"cn",
	"co",
	"cp",
	"cq",
	"cr",
	"cs",
	"ct",
	"cu", # cu: e300
]

var book: Book:
	get = get_book
var copycat_num: LoudNumber
var initialized := false

var text: String
var text_requires_update := true:
	set = _set_text_requires_update

#region Static

#region Format Number

static func format_number(value: Variant, override_decimals: int = -1) -> String:
	if is_zero_approx(value):
		return "0"

	var _sign: float = signf(value)
	value = abs(value) # not absi() or absf() because value is Variant
	var floored_value: int = floori(value)

	return (
		Big.new(value * _sign).get_text() if floored_value >= 1e6
		else _format_number_gte_1e5(value, _sign) if floored_value >= 1e5
		else _format_number_1000s(value, _sign) if floored_value >= 1000
		else String.num(value * _sign, 0) if value is int
		else _format_small_number(value, _sign, override_decimals) )


static func _format_number_gte_1e5(value: Variant, _sign: float) -> String:
	var output := ""
	var i: int = value
	var sign_text: String = "-" if _sign < 0 else ""

	while i >= 1000:
		output = ",%03d%s" % [i % 1000, output]
		i /= 1000

	return "%s%s%s" % [sign_text, i, output]


static func _format_number_1000s(value: Variant, _sign: float) -> String:
	var output: String = ""
	var i: int = value
	var sign_text: String = "-" if _sign < 0 else ""

	while i >= 1000:
		output = ",%03d%s" % [i % 1000, output]
		i /= 1000

	return "%s%s%s" % [sign_text, i, output]


static func _format_small_number(value: Variant, _sign: float, override_decimals: int) -> String:
	# Log10 of value (floored) (-0.35 -> -1 | 2.82 -> 2)
	var floor_log: int = floori(log(value) / NATURAL_LOG)

	var decimals: int = (
		override_decimals if override_decimals >= 0
		else 0 if (
			floor_log >= 1
			or is_equal_approx(value, int(value))
			or floor_log <= -6 )
		else absi(floor_log) + 2 )

	return String.num(value * _sign, decimals)

#endregion

## Formats a percent float (0.0 to >= 1.0)
static func format_percent(percent: float) -> String:
	if percent < 0.0:
		Log.warn("percent was negative (", percent, ")")
		percent = 0.0

	percent *= 100
	var floor_log: int = floori(log(percent) / NATURAL_LOG)

	# Huge percent
	if floor_log >= 6:
		return Big.new(percent).get_text() + "%"

	# Very small % to 100%
	var decimals: int = (
		0 if (
			floor_log >= 1 # 10.0 to 100+
			or is_equal_approx(percent, int(percent))
			or floor_log <= -6 )
		else absi(floor_log) + 1 )

	return String.num(percent, decimals) + "%"


static func format_distance(distance: int) -> String:
	# Meters
	if distance < 1000:
		return str(distance) + "m"

	# Kilometers
	var kilometers := float(distance) / 1000
	if kilometers < 1000:
		if kilometers < 10:
			return String.num(kilometers, 1) + "km"
		return str(ceilf(kilometers)) + "km"

	# Megameters
	var megameters := kilometers / 1000
	if megameters < 1000:
		if megameters < 10:
			return String.num(megameters, 1) + "Mm"
		return str(ceilf(megameters)) + "Mm"

	return "??? meters"


static func factorial(n: int) -> int:
	if n <= 1:
		return 1

	var result: int = n
	for x in range(n - 1, 1, -1):
		result *= x

	return result


static func binomial_coefficient(n: int, k: int) -> float:
	return float(factorial(n)) / (factorial(k) * factorial(n - k))


static func log10(n: float) -> float:
	return log(n) / NATURAL_LOG

#endregion

#region Init

func loud_number_init() -> void:
	if initialized:
		return
	initialized = true
	if Engine.is_editor_hint():
		print_stack()
	Settings.notation_changed.connect(
		func():
			text_requires_update = true
			changed.emit()
	)
	changed.disconnect(loud_number_init)


## See: BigFloat, LoudFloat, LoudInt
func _create_book() -> void:
	pass

#endregion

#region Setters & Getters

func _set_text_requires_update(val: bool) -> void:
	if text_requires_update == val:
		return
	text_requires_update = val
	if val:
		text_changed.emit()


func get_book() -> Book:
	if book == null:
		_create_book()
	return book

#endregion

#region Public

func update_text(value) -> void:
	text_requires_update = false
	text = format_number(value)


func get_text() -> String:
	return text


func reset() -> void:
	book.reset()


func is_copycat() -> bool:
	return copycat_num != null

#region Book

func edit_change(category: Book.Category, source: Variant, amount) -> void:
	book.edit_change(category, source, amount)


func edit_added(source: Variant, amount: Variant) -> void:
	edit_change(Book.Category.ADDED, source, amount)


func edit_subtracted(source: Variant, amount: Variant) -> void:
	edit_change(Book.Category.SUBTRACTED, source, amount)


func edit_multiplied(source: Variant, amount: Variant) -> void:
	edit_change(Book.Category.MULTIPLIED, source, amount)


func edit_divided(source: Variant, amount: Variant) -> void:
	edit_change(Book.Category.DIVIDED, source, amount)


func edit_pending(source: Variant, _amount) -> void:
	edit_change(Book.Category.PENDING, source, _amount)


func remove_change(category: Book.Category, source) -> void:
	book.remove_change(category, source)


func remove_added(source: Variant) -> void:
	remove_change(Book.Category.ADDED, source)


func remove_subtracted(source: Variant) -> void:
	remove_change(Book.Category.SUBTRACTED, source)


func remove_multiplied(source: Variant) -> void:
	remove_change(Book.Category.MULTIPLIED, source)


func remove_divided(source: Variant) -> void:
	remove_change(Book.Category.DIVIDED, source)


func remove_pending(source: Variant) -> void:
	remove_change(Book.Category.PENDING, source)

#endregion

#endregion

#region Action

func copycat(cat: Resource) -> void:
	copycat_num = cat
	copycat_num.changed.connect(copycat_changed)
	copycat_changed()


func copycat_changed() -> void:
	book.edit_change(Book.Category.ADDED, str(copycat_num), copycat_num.get_value())


func clear_copycat() -> void:
	copycat_num.changed.disconnect(copycat_changed)
	copycat_num = null

#endregion

#region Region

func report() -> void:
	Log.pr("Current:", get_text())
	book.report()

#endregion
