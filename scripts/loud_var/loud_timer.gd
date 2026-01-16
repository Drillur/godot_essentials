class_name LoudTimer
extends LoudVar


signal timeout
signal started
signal stopped

const MINIMUM_DURATION: float = 0.05

const ONE_MINUTE: int = 60
const ONE_HOUR: int = 3600
const ONE_DAY: int = 86400
const ONE_YEAR: int = 31_536_000

var random: bool
var running := LoudBool.new(false)
var timer: SceneTreeTimer
var timer_wait_time: float ## The wait_time when the timer was started.
var wait_time: LoudFloat
var wait_time_range: LoudFloatPair


#region Init


func _init(_wait_time := 0.0, optional_maximum_duration := 0.0) -> void:
	if optional_maximum_duration > 0.0:
		wait_time_range = LoudFloatPair.new(_wait_time, optional_maximum_duration)
		wait_time = LoudFloat.new(0.0)
		random = true
	else:
		wait_time = LoudFloat.new(_wait_time)
	wait_time.custom_minimum_limit = LoudTimer.MINIMUM_DURATION


#endregion


#region Static


class TimeUnit:
	enum Type {
		SECOND,
		MINUTE,
		HOUR,
		DAY,
		YEAR,
		DECADE,
		CENTURY,
		MILLENIUM,
		EON,
		QUETTASECOND,
		BLACK_HOLE,
	}
	const DIVISION := {
		Type.SECOND: 60,
		Type.MINUTE: 60,
		Type.HOUR: 24,
		Type.DAY: 365,
		Type.YEAR: 10,
		Type.DECADE: 10,
		Type.CENTURY: 10,
		Type.MILLENIUM: "1e6",
		Type.EON: "3.1e13",
		Type.QUETTASECOND: "6e43",
		Type.BLACK_HOLE: 1,
	}
	const WORD := {
		Type.SECOND: {"SINGULAR": "second", "PLURAL": "seconds", "SHORT": "s"},
		Type.MINUTE: {"SINGULAR": "minute", "PLURAL": "minutes", "SHORT": "m"},
		Type.HOUR: {"SINGULAR": "hour", "PLURAL": "hours", "SHORT": "h"},
		Type.DAY: {"SINGULAR": "day", "PLURAL": "days", "SHORT": "d"},
		Type.YEAR: {"SINGULAR": "year", "PLURAL": "years", "SHORT": "y"},
		Type.DECADE: {"SINGULAR": "decade", "PLURAL": "decades", "SHORT": "dec"},
		Type.CENTURY: {"SINGULAR": "century", "PLURAL": "centuries", "SHORT": "cen"},
		Type.MILLENIUM: {"SINGULAR": "millenium", "PLURAL": "millenia", "SHORT": "mil"},
		Type.EON: {"SINGULAR": "eon", "PLURAL": "eons", "SHORT": "eon"},
		Type.QUETTASECOND: {"SINGULAR": "quettasecond", "PLURAL": "quettaseconds", "SHORT": "qs"},
		Type.BLACK_HOLE: {"SINGULAR": "black hole life span", "PLURAL": "consecutive black hole life spans", "SHORT": "bh"},
	}
	
	static func get_text(amount: Big, brief: bool) -> String:
		var type = Type.SECOND
		while type < Type.size() - 1:
			var division = Big.new(DIVISION[type])
			if amount.is_less_than(division):
				break
			amount.divided_by_equals(division)
			type = Type.values()[type + 1]
		var result: String = Big.round_down(amount).get_text()
		if brief:
			return result + " " + WORD[type]["SHORT"]
		return result + " " + unit_text(type, amount)
	
	static func unit_text(type: int, amount: Big) -> String:
		if amount.is_equal_to(1):
			return WORD[type]["SINGULAR"]
		return WORD[type]["PLURAL"]


static func format_time(seconds: float) -> String:
	if is_zero_approx(seconds):
		return "0s"
	if seconds >= ONE_HOUR:
		# for really long times
		var time_dict = get_time_dict(int(seconds))
		return get_time_text_from_dict(time_dict)
	
	if seconds < ONE_MINUTE:
		if seconds < 10:
			return String.num(seconds, 2) + "s"
		return String.num(seconds, 0) + "s"
	seconds /= ONE_MINUTE
	return LoudNumber.format_number(seconds) + "m"


## Returns a dict of years, days, hours, minutes, and seconds based on `time`.
static func get_time_dict(time: int) -> Dictionary[StringName, float]:
	const BASE: Dictionary[StringName, float] = {
		&"years": 0,
		&"days": 0,
		&"hours": 0,
		&"minutes": 0,
		&"seconds": 0,
	}
	
	var result: Dictionary[StringName, float] = BASE.duplicate()
	if time >= ONE_YEAR:
		result[&"years"] = float(time) / ONE_YEAR
		time = time % ONE_YEAR
	if time >= ONE_DAY:
		result[&"days"] = float(time) / ONE_DAY
		time = time % ONE_DAY
	if time >= ONE_HOUR:
		result[&"hours"] = float(time) / ONE_HOUR
		time = time % ONE_HOUR
	if time >= ONE_MINUTE:
		result[&"minutes"] = float(time) / ONE_MINUTE
		time = time % ONE_MINUTE
	result[&"seconds"] = float(time)
	
	return result


static func get_time_text_from_dict(dict: Dictionary) -> String:
	var years: int = dict.get(&"years", 0)
	var days: int = dict.get(&"days", 0)
	var hours: int = dict.get(&"hours", 0)
	var minutes: int = dict.get(&"minutes", 0)
	var seconds: int = dict.get(&"seconds", 0)
	
	var texts := []
	if years > 0:
		texts.append("%sy" % years)
	if days > 0:
		texts.append("%sd" % days)
	if hours > 0:
		texts.append("%sh" % hours)
	if minutes > 0:
		texts.append("%sm" % minutes)
	if seconds > 0:
		texts.append("%ss" % seconds)
	return ", ".join(texts)


static func format_big_time(time: Big) -> String:
	time = Big.new(time)
	if time.is_less_than(Big.SIXTY):
		return format_time(time.to_float())
	return TimeUnit.get_text(time, false)


#endregion


#region Signals


func timer_timeout() -> void:
	if timer:
		timer.timeout.disconnect(timer_timeout)
		timer = null
	
	if is_stopped():
		return
	
	stopped.emit()
	timeout.emit()


#endregion


#region Action


func start() -> void:
	stop()
	if random:
		wait_time.edit_change(Book.Category.ADDED, wait_time_range, wait_time_range.get_random_point())
	timer_wait_time = wait_time.get_value()
	timer = Main.instance.get_tree().create_timer(timer_wait_time)
	timer.timeout.connect(timer_timeout)
	
	running.set_true()
	started.emit()


func stop() -> void:
	if timer:
		timer.timeout.disconnect(timer_timeout)
	timer = null
	
	if is_stopped():
		return
	
	running.set_false()
	stopped.emit()


func set_wait_time(value: float) -> void:
	wait_time.set_to(maxf(value, MINIMUM_DURATION))


func enable_looping() -> void:
	if not timeout.is_connected(start):
		timeout.connect(start)


func disable_looping() -> void:
	if timeout.is_connected(start):
		timeout.disconnect(start)


#endregion


#region Get


func get_wait_time() -> float:
	return wait_time.get_value()


func get_time_left() -> float:
	if running.is_false() or not timer:
		return 0.0
	return timer.time_left


func get_time_elapsed() -> float:
	if is_running():
		return timer_wait_time - get_time_left()
	return 0.0


func get_percent() -> float:
	return 1.0 - (get_time_left() / timer_wait_time)


func get_inverted_percent() -> float:
	return get_time_left() / timer_wait_time


func is_stopped() -> bool:
	return running.is_false()


func is_running() -> bool:
	return running.is_true()


func get_wait_time_text() -> String:
	return LoudTimer.format_time(get_wait_time())


func get_time_left_text() -> String:
	return LoudTimer.format_time(get_time_left())


func get_time_elapsed_text() -> String:
	return LoudTimer.format_time(get_time_elapsed())


func get_text() -> String:
	return "%s/%s" % [
		LoudNumber.format_number(get_time_elapsed()),
		get_wait_time_text()
	]


func get_average_duration() -> float:
	if random:
		return wait_time_range.get_midpoint() * wait_time.get_value()
	return wait_time.get_value()


func get_maximum_duration() -> float:
	if random:
		return wait_time_range.get_total() * wait_time.get_value()
	return wait_time.get_value()


#endregion
