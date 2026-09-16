class_name Stock
extends Resource

static var list: Dictionary[StringName, Stock]

@export var amount: LoudBig

var key: StringName
var average_rate := StockRate.new()

#region Static

static func has(_key: StringName) -> bool:
	return list.has(_key)


static func fetch(_key: StringName) -> Stock:
	return list[_key]


static func get_amount(_key: StringName) -> LoudBig:
	return fetch(_key).amount


static func get_value(_key: StringName) -> Big:
	if not has(_key):
		return Big.new(Big.ZERO)
	return get_amount(_key).get_value()


static func add(_key: StringName, _amount: Variant) -> void:
	get_amount(_key).plus_equals(_amount)


static func subtract(_key: StringName, _amount: Variant) -> void:
	get_amount(_key).minus_equals(_amount)
	if not get_value(_key).is_positive():
		get_amount(_key).set_to(Big.ZERO)


static func can_afford(_key: StringName, _amount: Variant) -> bool:
	return get_value(_key).is_greater_than_or_equal_to(_amount)

#endregion

#region Init

func _init(_key: StringName, starting_amount: Variant = 0.0) -> void:
	key = _key
	list[key] = self
	amount = LoudBig.new(starting_amount)

#endregion

#region Action

func reset() -> void:
	amount.reset()

#endregion

#region Class

class StockRate:
	extends RefCounted

	var net := Big.new(0)
	var gain := LoudBig.new(0)
	var loss := LoudBig.new(0)
	var queue := Queueable.new_resource_queueable(Queueable.CooldownType.DURATION, 1.0)
	var positive := LoudBool.new(true)


	func _init() -> void:
		queue.method = sync_rate
		queue.connect_signals([gain.changed, loss.changed])


	func reset_rates() -> void:
		gain.book.reset()
		loss.book.reset()
		sync_rate()


	func sync_rate() -> void:
		net.set_to(gain.minus(loss.val()))
		positive.set_to(net.is_positive())

#endregion
