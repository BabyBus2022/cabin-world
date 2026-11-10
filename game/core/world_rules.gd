extends RefCounted
## rules.ask is a pure query on VADS-supplied observations. The caller
## commits only after rechecking its active session.

static func resolve(rule: String, args: Dictionary) -> Variant:
	match rule:
		"idleChoice":return load("res://core/resident_plan.gd").resolve(args)
		"meet":
			var space := "shop" if args.rain else "park"
			for current in args.spaces:
				if current in ["shop", "park"]:
					space = current
					break
			return {"space":space,"zone":"snacks" if space == "shop" else "bench"}
		"approach":
			var targets: Array = args.targets
			return targets[int(floor(float(args.roll) * targets.size())) % targets.size()] if not targets.is_empty() else null
		"objectZone":
			for object in WorldData.objects:
				if object.id==args.object:
					return object.get("zone")
			return null
		"homeZone":
			var home: Dictionary = Residents.person(str(args.actor)).get("home", {})
			for row in home.get("placeNames", []):
				for word in row.words:
					if str(word) in str(args.place):
						return row.zone
			return home.get("defaultZone")
	return null
