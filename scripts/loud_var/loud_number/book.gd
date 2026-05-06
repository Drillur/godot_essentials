class_name Book
extends Resource


signal pending_changed

enum Category {
	NONE,
	ADDED,
	SUBTRACTED,
	MULTIPLIED,
	DIVIDED,
	PENDING,
}
enum Type {
	INT,
	FLOAT,
	BIG,
}

## Turn off before making massive changes. Turn on afterwards.
var sync_allowed := LoudBool.new(true)
var sync_required: bool = true ## A change was made, syncing is required

var type: Type
var sync: Callable
var adders: Array[Resource] ## As of Stage 3, the highest adders.size() I saw was 24
var subtracters: Array[Resource]
var multipliers: Array[Resource] ## As of Stage 3, the highest adders.size() I saw was 18
var conditional_multipliers: Dictionary[Variant, ConditionalEntry]
var dividers: Array[Resource]
var powerers: Array[Resource]

var book: Dictionary[Category, LoudDict] = {}


#region Static


static func is_category_multiplicative(_category: Book.Category) -> bool:
	return _category in [Book.Category.MULTIPLIED, Book.Category.DIVIDED]


static func is_category_additive(_category: Book.Category) -> bool:
	return _category in [Book.Category.ADDED, Book.Category.SUBTRACTED]


#endregion


#region Init


func _init(_type: Type):
	type = _type
	match type:
		Type.INT:
			book = {
				Book.Category.ADDED: LoudDict.Int.new(),
				Book.Category.SUBTRACTED: LoudDict.Int.new(),
				Book.Category.MULTIPLIED: LoudDict.Int.new({"multiplicative": true}),
				Book.Category.DIVIDED: LoudDict.Int.new({"multiplicative": true}),
				Book.Category.PENDING: LoudDict.Int.new(),
			}
			sync = func(base) -> int:
				return (base + get_added() - get_subtracted()) * get_multiplied() / get_divided()
		Type.FLOAT:
			book = {
				Book.Category.ADDED: LoudDict.Float.new(),
				Book.Category.SUBTRACTED: LoudDict.Float.new(),
				Book.Category.MULTIPLIED: LoudDict.Float.new({"multiplicative": true}),
				Book.Category.DIVIDED: LoudDict.Float.new({"multiplicative": true}),
				Book.Category.PENDING: LoudDict.Float.new(),
			}
			sync = func(base) -> float:
				return (base + get_added() - get_subtracted()) * get_multiplied() / get_divided()
		Type.BIG:
			book = {
				Book.Category.ADDED: LoudDict._Big.new(),
				Book.Category.SUBTRACTED: LoudDict._Big.new(),
				Book.Category.MULTIPLIED: LoudDict._Big.new({"multiplicative": true}),
				Book.Category.DIVIDED: LoudDict._Big.new({"multiplicative": true}),
				Book.Category.PENDING: LoudDict._Big.new(),
			}
			sync = func(base) -> Big:
				var result: Big = Big.new(base)
				var added: Big = get_added()
				result.plus_equals(added)
				result.minus_equals(get_subtracted())
				result.times_equals(get_multiplied())
				result.divided_by_equals(get_divided())
				return result


#endregion


#region Action


func reset() -> void:
	book[Category.ADDED].reset()
	book[Category.SUBTRACTED].reset()
	book[Category.MULTIPLIED].reset()
	book[Category.DIVIDED].reset()
	book[Category.PENDING].reset()
	sync_required = true


func erase_all() -> void:
	book[Category.ADDED].erase_all()
	book[Category.SUBTRACTED].erase_all()
	book[Category.MULTIPLIED].erase_all()
	book[Category.DIVIDED].erase_all()
	book[Category.PENDING].erase_all()
	sync_required = true


func reset_pending() -> void:
	book[Book.Category.PENDING].reset()
	pending_changed.emit()


func edit_change(category: Book.Category, source: Variant, amount: Variant) -> void:
	var no_change: bool = not book[category].edit(source, amount)
	if no_change:
		return
	if category == Book.Category.PENDING:
		pending_changed.emit()
	else:
		if not sync_required:
			sync_required = true
			changed.emit()


func remove_change(category: Book.Category, source: Variant) -> void:
	book[category].erase(source)
	if category == Book.Category.PENDING:
		pending_changed.emit()
	else:
		if not sync_required:
			sync_required = true
			changed.emit()


func add_adder(object: Resource) -> void:
	if adders.has(object) or object.changed.is_connected(adder_changed):
		return
	adders.append(object)
	object.changed.connect(adder_changed.bind(object))
	adder_changed(object)


func remove_adder(object: Resource) -> void:
	if not adders.has(object) or not object.changed.is_connected(adder_changed):
		return
	edit_change(Book.Category.ADDED, object, 0.0)
	object.changed.disconnect(adder_changed)
	adders.erase(object)


func adder_changed(object: Resource) -> void:
	edit_change(Book.Category.ADDED, object, object.get_value())


func add_subtracter(object: Resource) -> void:
	if subtracters.has(object) or object.changed.is_connected(subtracter_changed):
		return
	subtracters.append(object)
	object.changed.connect(subtracter_changed.bind(object))
	subtracter_changed(object)


func remove_subtracter(object: Resource) -> void:
	if not subtracters.has(object) or not object.changed.is_connected(subtracter_changed):
		return
	edit_change(Book.Category.SUBTRACTED, object, 0.0)
	object.changed.disconnect(subtracter_changed)
	subtracters.erase(object)


func subtracter_changed(object: Resource) -> void:
	edit_change(Book.Category.SUBTRACTED, object, object.get_value())


#region Multipliers


func add_multiplier(object: Resource) -> void:
	if multipliers.has(object) or object.changed.is_connected(multiplier_changed):
		return
	multipliers.append(object)
	object.changed.connect(multiplier_changed.bind(object))
	multiplier_changed(object)


func remove_multiplier(object: Resource) -> void:
	if not multipliers.has(object) or not object.changed.is_connected(multiplier_changed):
		return
	edit_change(Book.Category.MULTIPLIED, object, 1.0)
	object.changed.disconnect(multiplier_changed)
	multipliers.erase(object)


## Receives a ConditionalEntry. Based on the triggers, will call the attached
## function to get a value to applied multiplicatively
func add_conditional_multiplier(conditional_entry: ConditionalEntry) -> void:
	assert(not conditional_multipliers.has(conditional_entry.source),
			"This source was already added.")
	conditional_multipliers[conditional_entry.source] = conditional_entry
	for trigger: Signal in conditional_entry.triggers:
		trigger.connect(conditional_multiplier_changed.bind(conditional_entry))
	conditional_multiplier_changed(conditional_entry)


func remove_conditional_multiplier(source: Variant) -> void:
	assert(conditional_multipliers.has(source), "%s was not added" % source)
	var conditional_entry: ConditionalEntry = conditional_multipliers[source]
	for trigger: Signal in conditional_entry.triggers:
		trigger.disconnect(conditional_multiplier_changed)
	conditional_multipliers.erase(source)
	edit_change(Book.Category.MULTIPLIED, conditional_entry.source, 1.0)


func multiplier_changed(object: Resource) -> void:
	edit_change(Book.Category.MULTIPLIED, object, object.get_value())


func conditional_multiplier_changed(conditional_entry: ConditionalEntry) -> void:
	var source: Variant = conditional_entry.source
	var amount: Variant = conditional_entry.get_value.call()
	edit_change(Book.Category.MULTIPLIED, source, amount)


#endregion


func add_divider(object: Resource) -> void:
	dividers.append(object)
	object.changed.connect(divider_changed.bind(object))
	divider_changed(object)


func remove_divider(object: Resource) -> void:
	if not dividers.has(object):
		return
	edit_change(Book.Category.DIVIDED, object, 1.0)
	object.changed.disconnect(divider_changed)
	dividers.erase(object)


func divider_changed(object: Resource) -> void:
	edit_change(Book.Category.DIVIDED, object, object.get_value())


func add_powerer(base: Resource, exponent: Resource, offset := 0) -> void:
	var power_up: Callable = func() -> void:
		var offset_amount: float = offset
		if exponent is BigFloat:
			offset_amount += exponent.val().to_float()
		else:
			offset_amount += exponent.val()
		offset_amount = max(0, offset_amount)
		
		edit_change(Book.Category.MULTIPLIED, base,
				Big.power(base.val(), offset_amount))
	
	power_up.call()
	base.changed.connect(power_up)
	exponent.changed.connect(power_up)


#endregion


#region Get


func get_added():
	return book[Book.Category.ADDED].sum


func get_added_text() -> String:
	var sum: Variant = get_added()
	if type == Type.INT or type == Type.FLOAT:
		return LoudNumber.format_number(sum)
	return sum.get_text()


func get_subtracted():
	return book[Book.Category.SUBTRACTED].sum


func get_subtracted_text() -> String:
	var sum: Variant = get_subtracted()
	if type == Type.INT or type == Type.FLOAT:
		return LoudNumber.format_number(sum)
	return sum.get_text()


func get_multiplied():
	return book[Book.Category.MULTIPLIED].sum


func get_multiplied_text() -> String:
	var sum: Variant = get_multiplied()
	if type == Type.INT or type == Type.FLOAT:
		return LoudNumber.format_number(sum)
	return sum.get_text()


func get_divided():
	return book[Book.Category.DIVIDED].sum


func get_divided_text() -> String:
	var sum: Variant = get_divided()
	if type == Type.INT or type == Type.FLOAT:
		return LoudNumber.format_number(sum)
	return sum.get_text()


func get_pending():
	return book[Book.Category.PENDING].sum


func get_added_from_source(_source: Variant) -> Variant:
	return book[Book.Category.ADDED].get_value(_source)


#func report() -> void:
	#Log.prn("Added:", get_added_text(), book[Book.Category.ADDED].data,
		#"\nMultiplied:", get_multiplied_text(), book[Book.Category.MULTIPLIED].data
	#)
	#Log.prn(
		#"Subtracted:", get_subtracted_text(), book[Book.Category.SUBTRACTED].data,
		#"\nDivided:", get_divided_text(), book[Book.Category.DIVIDED].data,
	#)


#endregion


#region Classes


class ConditionalEntry:
	var source: Variant
	var get_value: Callable
	var triggers: Array[Signal]
	
	
	func _init(_source: Variant, _get_value: Callable, _triggers: Array[Signal]) -> void:
		source = _source
		get_value = _get_value
		triggers = _triggers


#endregion
