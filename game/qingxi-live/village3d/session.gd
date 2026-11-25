extends RefCounted
## Scene handoff uses one simulation snapshot; saved data remains the existing v2 format.
static func publish(tree:SceneTree,sim,destination:String):
	sim.settle();sim.data.map=destination
	tree.set_meta("rural_handoff",sim.data.duplicate(true))
static func consume(tree:SceneTree,sim)->bool:
	if not tree.has_meta("rural_handoff"):return false
	sim.bind_snapshot(tree.get_meta("rural_handoff").duplicate(true))
	tree.remove_meta("rural_handoff");return true
