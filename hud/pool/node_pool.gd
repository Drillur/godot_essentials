class_name NodePool
extends Node

static var pool: Dictionary[StringName, Array] = { }


static func fetch_node(key: StringName, parent: Node = Utility) -> Node:
	if key not in pool:
		pool[key] = []
	var node: Node
	if pool[key].is_empty():
		node = ResourceBag.instantiate(key)
	else:
		node = pool[key].pop_back()
	node.process_mode = Node.PROCESS_MODE_INHERIT
	parent.add_child(node)
	return node


static func return_node(key: StringName, node: Node) -> void:
	if key not in pool:
		pool[key] = []
	# TODO node.break_down() or something like that
	node.process_mode = Node.PROCESS_MODE_DISABLED
	pool[key].append(node)
