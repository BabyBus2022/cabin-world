extends RefCounted

const GAP := 32.0
const DIRECTIONS := [Vector2.RIGHT,Vector2.LEFT,Vector2.DOWN,Vector2.UP,Vector2(.707,.707),Vector2(-.707,.707),Vector2(.707,-.707),Vector2(-.707,-.707)]

## A standing spot needs a little more room than the walking gap: a spot exactly GAP from someone can only be
## approached by passing closer than GAP, which the walking rule refuses, so she would edge there forever.
const SPOT_MARGIN := 4.0

static func clear(p: Vector2, others: Array, gap := GAP) -> bool:
	return others.all(func(other): return p.distance_to(other)>=gap)

## Small local steps avoid rebuilding a navigation grid for passing pedestrians.
## Both the segment and each person's clearance must be safe, including when a
## save restores two people on top of one another (only separation is allowed).
static func local_step(nav:RoomNav, start:Vector2, toward:Vector2, budget:float, others:Array, yield_side:int)->Variant:
	var forward:Vector2=(toward-start).normalized()
	if budget<=0 or forward==Vector2.ZERO:return null
	var side:=Vector2(-forward.y,forward.x)*yield_side
	for direction in [(forward+side*1.5).normalized(),side,(forward-side*1.5).normalized(),-side]:
		var next:Vector2=start+direction*budget
		if not nav.walkable(next) or not nav.clear_line(start,next):continue
		var safe:bool=true
		for other in others:
			var old_distance:float=start.distance_to(other)
			if next.distance_to(other)<GAP and next.distance_to(other)<=old_distance+.001:safe=false;break
		if safe:return next
	return null

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

## Find an actual reachable waiting place for an idle resident blocking a one-person aisle.
## Moving there must leave the requester's whole route open; a tiny sidestep can still seal the aisle.
static func yield_spot(scene:Dictionary, origin:Vector2, walker:Vector2, goal:Vector2, others:Array)->Variant:
	var peer_nav:=navigation(scene,others+[walker],origin)
	for radius in [36,48,64,88,128,192,256,320,384]:
		for direction in DIRECTIONS:
			var spot:Vector2=origin+direction*radius
			if not peer_nav.walkable(spot) or not clear(spot,others+[walker],GAP+SPOT_MARGIN):continue
			if peer_nav.route(origin,spot).is_empty():continue
			if navigation(scene,others+[spot],walker).route(walker,goal).is_empty():continue
			return spot
	return null

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
