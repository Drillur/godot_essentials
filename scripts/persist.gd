class_name Persist
extends RefCounted


var tier: int


#region Init


func _init(_tier: int = 0) -> void:
	tier = _tier


#endregion


#region Get


func get_highest_tier_can_persist_through() -> int:
	return tier


func _should_fail_at_tier(_tier: int) -> bool:
	return get_highest_tier_can_persist_through() < _tier


#endregion
