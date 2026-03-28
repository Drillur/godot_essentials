class_name Persist
extends RefCounted


var tier: int


#region Init


func _init(_tier: int = 0) -> void:
	tier = _tier


#endregion


#region Get


func should_fail_at_tier(_tier: int) -> bool:
	return tier < _tier


#endregion
