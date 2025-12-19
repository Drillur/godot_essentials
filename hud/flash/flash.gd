class_name Flash
extends MarginContainer


static var available_nodes: Array[Flash]

var tween: Tween


#region Init


static func cache() -> void:
	LORED.signals.lored_killed.connect(validate_flashes)


func _ready() -> void:
	hide()
	tree_exiting.connect(kill_tween)


#endregion


#region Static


static func cannot_flash(_spawn_node: Node) -> bool:
	return (
			Settings.flashes_allowed.is_false()
			or not _spawn_node.can_process()
			or Engine.get_frames_per_second() < Main.MINIMUM_FPS)


static func flash(_spawn_node: Node, _color := Color.WHITE) -> void:
	if cannot_flash(_spawn_node):
		return
	
	var prefab: Flash = get_scene(_spawn_node)
	prefab._go(_color)


static func get_scene(_spawn_node: Node) -> Flash:
	const SCENE_NAME: StringName = &"flash"
	
	var prefab: Flash
	if available_nodes.is_empty() or not is_instance_valid(available_nodes.back()):
		prefab = ResourceBag.instantiate(SCENE_NAME)
	else:
		prefab = available_nodes.pop_back()
	# Reparents the node only if the previous parent was a different node
	if prefab.get_parent():
		if prefab.get_parent() != _spawn_node:
			prefab.get_parent().remove_child(prefab)
			_spawn_node.add_child(prefab)
			prefab.owner = Main.instance
	else:
		_spawn_node.add_child(prefab)
	prefab.process_mode = PROCESS_MODE_INHERIT
	return prefab


static func validate_flashes() -> void:
	var invalid: Array[Flash] = []
	for _flash: Flash in available_nodes:
		if not is_instance_valid(_flash):
			invalid.append(_flash)
	for _flash: Flash in invalid:
		available_nodes.erase(_flash)


#endregion


#region Local


func _go(color: Color) -> void:
	const DEFAULT_ALPHA: float = 0.25
	const DURATION: float = 0.15
	
	if not is_node_ready():
		await ready
	
	size = get_parent().size
	
	modulate = Color(color.r, color.g, color.b, DEFAULT_ALPHA)
	var end_color: Color = Color(color.r, color.g, color.b, 0)
	tween = create_tween()
	tween.tween_property(self, "modulate", end_color, DURATION).set_trans(
			Tween.TRANS_SINE).set_ease(Tween.EASE_IN)
	tween.finished.connect(_become_available)
	show()


func _become_available() -> void:
	hide()
	position = Vector2.ZERO
	tween.kill()
	process_mode = PROCESS_MODE_DISABLED
	available_nodes.append(self)



func kill_tween() -> void:
	Utility.kill_tween(tween)


#endregion
