extends RefCounted

const GAP := 32.0
const DIRECTIONS := [Vector2.RIGHT,Vector2.LEFT,Vector2.DOWN,Vector2.UP,Vector2(.707,.707),Vector2(-.707,.707),Vector2(.707,-.707),Vector2(-.707,-.707)]

## A standing spot needs a little more room than the walking gap: a spot exactly GAP from someone can only be
## approached by passing closer than GAP, which the walking rule refuses, so she would edge there forever.
const SPOT_MARGIN := 4.0

static func clear(p: Vector2, others: Array, gap := GAP) -> bool:
	return others.all(func(other): return p.distance_to(other)>=gap)

static func standing(nav: RoomNav, wanted: Vector2, others: Array, origin: Variant = null) -> Variant:
	if nav.walkable(wanted) and clear(wanted,others,GAP+SPOT_MARGIN) and (origin==null or not nav.route(origin,wanted).is_empty()):
		return wanted
	for radius in [36,48,64,88]:
		for direction in DIRECTIONS:
			var p: Vector2 = wanted + direction*radius
			if nav.walkable(p) and clear(p,others,GAP+SPOT_MARGIN) and (origin==null or not nav.route(origin,p).is_empty()):
				return p
	return null

static func detour(scene: Dictionary, start: Vector2, end: Vector2, others: Array) -> Array[Vector2]:
	return navigation(scene,others,start).route(start,end)

## `origin` is where the walker stands. A circle that already contains her (two bodies restored or arriving on the
## same spot) is left out: otherwise her start is inside an obstacle, no route exists and she can never walk away.
static func navigation(scene: Dictionary, others: Array, origin: Variant = null) -> RoomNav:
	var copy := scene.duplicate()
	# Match the actual round body clearance. Treating another resident as a
	# wall inflated her twice and made a valid touching start impossible to route.
	copy.dynamicCircles = []
	for p in others:
		if origin is Vector2 and origin.distance_to(p) < GAP: continue
		copy.dynamicCircles.append({"center":p,"radius":GAP})
	# Start from the room's cached grid and only add the people (a full fine-grained rebuild cost 50-450 ms per call,
	# several times a second while two residents walk together). Falls back to a full build for unknown scenes.
	var id := str(scene.get("id", ""))
	if id != "" and WorldData.scenes.has(id):
		return RoomNav.new(copy, WorldData.nav(id))
	copy.navigationStep=4
	return RoomNav.new(copy)
