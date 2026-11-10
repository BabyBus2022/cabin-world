extends RefCounted
## The life rhythm comes from VADS. Decisions and body timelines use one
## resident profile, including for beds with zero transition steps.

static func profiles() -> Dictionary:
	var out := {}
	for resident in Residents.people():
		if resident.get("sleep") is Dictionary:
			out[resident.key] = resident.sleep
	return out

static func decide(profile: Dictionary, facts: Dictionary) -> String:
	if facts.get("night") == true:
		var due: bool = facts.get("wasNight") != true if profile.enterOn == "rhythmEdge" else facts.get("inBed") != true
		if due:
			return "defer" if facts.get("busy") == true else "sleep"
		return "idle"
	if facts.get("inBed") != true or (profile.wakeScheduledOnly and facts.get("scheduled") != true):
		return "idle"
	return "rest" if facts.get("holding") == true else "wake"

static func steps(profile: Dictionary, action: String, bed: Dictionary) -> Array:
	var out := []
	for step in profile.sleepSteps if action == "sleep" else profile.wakeSteps:
		if step[0] == "always" or (step[0] == "unoccupied" and not bed.occupied) or (step[0] == "upright" and not bed.phase in ["lying", "covered", "sleeping"]):
			out.append([step[1], step[2]])
	return out
