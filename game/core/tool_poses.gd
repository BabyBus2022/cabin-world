extends RefCounted
## A tool's name selects the first matching pose in the resident's ordered profile.
## Missing room means the tool can be used where she already is.

static func profiles() -> Dictionary:
	var out := {}
	for resident in Residents.people():
		if resident.get("tool_poses") is Dictionary:
			out[resident.key] = resident.tool_poses
	return out


static func matches(rule: Dictionary, tool: String) -> bool:
	for prefix in rule.get("exceptPrefix", []):
		if tool.begins_with(prefix):
			return false
	if rule.get("always", false) or tool in rule.get("exact", []):
		return true
	for prefix in rule.get("prefix", []):
		if tool.begins_with(prefix):
			return true
	for part in rule.get("contains", []):
		if part in tool:
			return true
	return false


static func resolve(actor: String, tool: String, location: String) -> Dictionary:
	var profile: Dictionary = Residents.person(actor).get("tool_poses", {})
	for rule in profile.get("rules", []):
		if matches(rule, tool):
			var visual: Dictionary = profile.poses[rule.pose].duplicate()
			if not visual.has("room"):
				visual.room = location
			if visual.action == "idle":
				visual.label = "在" + str(profile.idlePlaces.get(location, "小屋"))
			return visual
	return {}
