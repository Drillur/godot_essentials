class_name Calendar
extends Resource


signal day_changed(new_day: Day, previous_day: Day)
signal month_changed(new_month: Month, previous_month: Month)
signal year_changed(new_year: int)

enum Day { MONDAY, TUESDAY, WEDNESDAY, THURSDAY, FRIDAY, SATURDAY, SUNDAY }
enum Month {
		JANUARY, FEBRUARY, MARCH, APRIL, MAY, JUNE,
		JULY, AUGUST, SEPTEMBER, OCTOBER, NOVEMBER, DECEMBER }

const DAYS_PER_MONTH: Array[int] = [
		31, 28, 31, 30, 31, 30, 31, 31, 30, 31, 30, 31]

@export var year_count: int = 1: set = _set_year_count
@export var month_count: int = 1 ## Human-readable month number, like Jan = 1
@export var day_count: int = 1 ## Human-readable day, such as Jan [code]1[/code]

var day: Day: set = _set_day
var month: Month: set = _set_month

var day_progress: float = 0.0
var day_duration: LoudFloat


#region Static


static func are_dates_equal(a: Date, b: Date) -> bool:
	if a.year != b.year:
		return false
	if a.month != b.month:
		return false
	return a.day == b.day


#region - Easter Calculator


## Returns the year, month, and day of Easter depending on [code]_year[/code]
static func get_easter_date(_year: int) -> Dictionary[StringName, int]:
	var a: int = _year % 19
	var b: int = floori(_year / 100.0)
	var c: int = _year % 100
	var d: int = floori(b / 4.0)
	var e: int = b % 4
	var f: int = floori((b + 8) / 25.0)
	var g: int = floori((b - f + 1) / 3.0)
	var h: int = (19 * a + b - d - g + 15) % 30
	var i: int = floori(c / 4.0)
	var k: int = c % 4
	var l: int = (32 + 2 * e + 2 * i - h - k) % 7
	var m: int = floori((a + 11 * h + 22 * l) / 451.0)
	var _month: int = floori((h + l - 7 * m + 114) / 31.0)
	var _day: int = ((h + l - 7 * m + 114) % 31) + 1
	
	var result: Dictionary[StringName, int] = {
			&"year": _year, &"month": _month, &"day": _day}
	return result


## Returns a proper English-formatted date for Easter
static func get_easter_string(_year: int) -> String:
	var easter: Dictionary[StringName, int] = get_easter_date(_year)
	var month_name: String = "March" if easter.month == 3 else "April"
	return "%s %d, %d" % [month_name, easter.day, easter.year]


static func get_easter_datetime(_year: int) -> Dictionary:
	var easter: Dictionary[StringName, int] = get_easter_date(_year)
	return {
		"year": easter._year,
		"month": easter._month,
		"day": easter._day,
		"hour": 0,
		"minute": 0,
		"second": 0
	}


#endregion


#endregion


#region Init


func _init(
		_day_duration: float, _year: int = 1, _month: int = 1,
		_day: int = 1) -> void:
	
	day_duration = LoudFloat.new(_day_duration)
	day_duration.custom_minimum_limit = 1.0 / 60.0
	year_count = _year
	month_count = _month
	day_count = _day
	
	_connect_signals()


func _connect_signals() -> void:
	await Cacher.done
	SaveManager.loading_ended.connect(recalc_day_and_month)


#endregion


#region Setters


func _set_year_count(new_year: int) -> void:
	if year_count == new_year:
		return
	year_count = new_year
	year_changed.emit(year_count)


func _set_day(new_day: Day) -> void:
	if day == new_day:
		return
	var previous: Day = day
	day = new_day
	day_changed.emit(day, previous)


func _set_month(new_month: Month) -> void:
	if month == new_month:
		return
	var previous: Month = month
	month = new_month
	month_changed.emit(month, previous)


#endregion


#region Time


func _process(delta: float) -> void:
	day_progress += delta
	
	if day_progress >= day_duration.val():
		day_progress -= day_duration.val()
		_add_day()


func _add_day(n: int = 1) -> void:
	assert(n == 1, "If you want n >= 7, change the wrapping code below")
	
	day_count = wrapi(day_count + n, 1, DAYS_PER_MONTH[month_count - 1] + 1)
	if day_count == 1:
		_add_month()
	day = wrapi(day + n, 0, 7) as Day


func _add_month(n: int = 1) -> void:
	assert(n == 1)
	month_count = wrapi(month_count + n, 1, 13)
	month = wrapi(month + n, 0, 12) as Month
	if month_count == 1:
		_add_year()


func _add_year(n: int = 1) -> void:
	year_count += n


func recalc_day_and_month() -> void:
	const DAYS_BEFORE_MONTH: Array[int] = [
			0, 31, 59, 90, 120, 151, 181, 212, 243, 273, 304, 334]
	
	#var prev_month: Month = month
	#var prev_day: Day = day
	
	month = month_count - 1 as Month
	
	var total_days: int = (year_count - 1) * 365
	total_days += DAYS_BEFORE_MONTH[month_count - 1]
	total_days += day_count - 1
	
	day = total_days % 7 as Day
	
	#Log.pr("Recalculated day and month!")
	#Log.pr(" - ", "Day: %s -> %s" % [Day.keys()[prev_day], Day.keys()[day]])
	#Log.pr(" - ", "Month: %s -> %s" % [Month.keys()[prev_month], Month.keys()[month]])


#endregion


#region Control


func start() -> void:
	if not Utility.process_frame.is_connected(_process):
		Utility.process_frame.connect(_process)


func stop() -> void:
	if Utility.process_frame.is_connected(_process):
		Utility.process_frame.disconnect(_process)


#endregion


#region Get


func is_date(date: Date) -> bool:
	return (
			year_count == date.year
			and month_count == date.month
			and day_count == date.day)


func get_date_text() -> String:
	return "%s, %s %s, %s" % [
			Day.keys()[day].capitalize(), Month.keys()[month].capitalize(),
			day_count, year_count]


#endregion



class Date:
	var year: int
	var month: int
	var day: int
	
	
	func _init(_month: Month, _day: int, _year: int) -> void:
		month = _month
		day = _day
		year = _year
	
	
	func get_date_text() -> String:
		return "%s, %s %s, %s" % [
				Day.keys()[day % 7].capitalize(), Month.keys()[month].capitalize(),
				day, year]
