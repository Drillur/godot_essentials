class_name Rate
extends RefCounted


const SMOOTHING_THRESHOLD: int = 30

static var list: Dictionary[Variant, Rate]

var production: Dictionary[StringName, Array]
var consumption: Dictionary[StringName, Array]


#region Static


## Logging production at most once per second is recommended
static func log_production(source: Variant, key: StringName, value: Big) -> void:
	if not list.has(source):
		printerr(source, " not found in Rate.list")
		return
	
	var rate: Rate = list[source]
	rate.production.get_or_add(key, []).append(Big.new(value))
	while rate.production[key].size() > SMOOTHING_THRESHOLD:
		rate.production[key].remove_at(0)
	rate._apply()


## Logging consumption at most once per second is recommended
static func log_consumption(source: Variant, key: StringName, value: Big) -> void:
	if not list.has(source):
		printerr(source, " not found in Rate.list")
		return
	
	var rate: Rate = list[source]
	rate.consumption.get_or_add(key, []).append(Big.new(value))
	while rate.consumption[key].size() > SMOOTHING_THRESHOLD:
		rate.consumption[key].remove_at(0)
	rate._apply()


static func reset(source: Variant) -> void:
	if not list.has(source):
		printerr(source, " not found in Rate.list")
		return
	
	var rate: Rate = list[source]
	for rates: Array in rate.production.values():
		rates.clear()
		rates.append(Big.new(0.0))
	for rates: Array in rate.consumption.values():
		rates.clear()
		rates.append(Big.new(0.0))
	rate._apply()


#endregion


#region Init


func _init(source: Variant, _production_keys: Array[StringName],
		_consumption_keys: Array[StringName] = []) -> void:
	
	for key: StringName in _production_keys:
		production[key] = []
	for key: StringName in _consumption_keys:
		consumption[key] = []
	
	list[source] = self


#endregion


#region Log


func _apply() -> void:
	for key: StringName in production.keys():
		var rate: Currency.CurrencyRate = Currency.fetch(key).average_rate
		
		var rates: Array = production[key]
		if rates.size() == 0:
			rate.gain.remove_added(self)
			continue
		
		var sum: Big = rates.reduce(Big.sum, Big.ZERO)
		var avg: Big = sum.divided_by(rates.size())
		rate.gain.edit_added(self, avg)
	
	for key: StringName in consumption:
		var rate: Currency.CurrencyRate = Currency.fetch(key).average_rate
		
		var rates: Array = consumption[key]
		if rates.size() == 0:
			rate.loss.remove_added(self)
			continue
		
		var sum: Big = rates.reduce(Big.sum, Big.ZERO)
		var avg: Big = sum.divided_by(rates.size())
		rate.loss.edit_added(self, avg)


#endregion
