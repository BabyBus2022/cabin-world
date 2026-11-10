class_name RoomNav
extends RefCounted
## Walkable area and pathfinding for one room, on the engine's A* grid.

const STEP := 8
var step:=STEP

var walk: Rect2
var clearance: float
var blocks: Array[Rect2] = []
var dynamic_circles: Array = []
var walk_regions:Array[PackedVector2Array]=[]
var grid := AStarGrid2D.new()


## `base` (optional): reuse an existing grid of the same room and only add scene.dynamicCircles (people) on top.
## Rebuilding a room grid tests every cell against every obstacle and polygon (~10-400 ms); copying is ~1 ms.
func _init(scene: Dictionary, base: RoomNav = null) -> void:
	if base != null:
		_copy_from(base, scene.get("dynamicCircles", []))
		return
	step=int(scene.get("navigationStep",STEP))
	var w: Dictionary = scene["walk"]
	walk = Rect2(w["x"], w["y"], w["w"], w["h"])
	clearance = scene["clearance"]
	dynamic_circles = scene.get("dynamicCircles",[])
	for points in scene.get("walkRegions",[]):
		var polygon:=PackedVector2Array()
		for p in points:polygon.append(Vector2(p[0],p[1]))
		walk_regions.append(polygon)
	for o in scene["obstacles"]:
		blocks.append(Rect2(o["x"], o["y"], o["w"], o["h"]).grow(clearance))
	grid.region = Rect2i(0, 0, ceili(walk.size.x / step) + 1, ceili(walk.size.y / step) + 1)
	grid.cell_size = Vector2(step, step)
	grid.offset = walk.position
	grid.diagonal_mode = AStarGrid2D.DIAGONAL_MODE_ONLY_IF_NO_OBSTACLES
	grid.update()
	for y in grid.region.size.y:
		for x in grid.region.size.x:
			if not walkable(walk.position + Vector2(x, y) * step):
				grid.set_point_solid(Vector2i(x, y))


func _copy_from(base: RoomNav, circles: Array) -> void:
	step = base.step; walk = base.walk; clearance = base.clearance
	blocks = base.blocks; walk_regions = base.walk_regions
	dynamic_circles = base.dynamic_circles.duplicate()
	dynamic_circles.append_array(circles)
	grid.region = base.grid.region; grid.cell_size = base.grid.cell_size; grid.offset = base.grid.offset
	grid.diagonal_mode = base.grid.diagonal_mode
	grid.update()
	for y in grid.region.size.y:
		for x in grid.region.size.x:
			if base.grid.is_point_solid(Vector2i(x, y)): grid.set_point_solid(Vector2i(x, y))
	# Only the cells under the added circles need testing.
	for circle in circles:
		var r := float(circle.radius); var c: Vector2 = circle.center
		var lo := Vector2i(((c - Vector2(r, r) - walk.position) / step).floor())
		var hi := Vector2i(((c + Vector2(r, r) - walk.position) / step).ceil())
		for y in range(maxi(0, lo.y), mini(grid.region.size.y, hi.y + 1)):
			for x in range(maxi(0, lo.x), mini(grid.region.size.x, hi.x + 1)):
				if (walk.position + Vector2(x, y) * step).distance_to(c) < r:
					grid.set_point_solid(Vector2i(x, y))


func walkable(p: Vector2) -> bool:
	if p.x < walk.position.x or p.y < walk.position.y or p.x > walk.end.x or p.y > walk.end.y:
		return false
	if not walk_regions.is_empty() and not walk_regions.any(func(region):return Geometry2D.is_point_in_polygon(p,region)):
		return false
	for b in blocks:
		if p.x > b.position.x and p.x < b.end.x and p.y > b.position.y and p.y < b.end.y:
			return false
	for circle in dynamic_circles:
		if p.distance_to(circle.center)<float(circle.radius):return false
	return true


func clear_line(a: Vector2, b: Vector2) -> bool:
	var n := ceili(a.distance_to(b) / 3.0)
	for i in range(1, n + 1):
		if not walkable(a.lerp(b, float(i) / n)):
			return false
	return true


## Nearest open cell with a clear straight line to p. Same answer as scanning every cell, but searched in rings
## outward from p and stopped once no farther ring can hold a closer cell (the full scan cost up to ~400 ms per route).
func _nearest_cell(p: Vector2) -> Vector2i:
	var best := Vector2i(-1, -1)
	var best_d := INF
	var size := grid.region.size
	var center := Vector2i(((p - walk.position) / step).round())
	var max_r := maxi(size.x, size.y) + absi(center.x) + absi(center.y)
	for r in range(0, max_r + 1):
		# every cell in ring r is at least (r-1)*step from p, since p lies within half a step of the centre cell
		var ring_min := maxf(0.0, (float(r) - 1.0) * step)
		if ring_min * ring_min > best_d:
			break
		for y in range(center.y - r, center.y + r + 1):
			for x in range(center.x - r, center.x + r + 1):
				if absi(x - center.x) != r and absi(y - center.y) != r: continue
				if x < 0 or y < 0 or x >= size.x or y >= size.y: continue
				var c := Vector2i(x, y)
				if grid.is_point_solid(c): continue
				var q := walk.position + Vector2(c) * step
				var d := p.distance_squared_to(q)
				if d < best_d and clear_line(q, p):
					best_d = d
					best = c
	return best


## Waypoints from start to end. Empty when there is no way through.
func route(start: Vector2, end: Vector2) -> Array[Vector2]:
	var out: Array[Vector2] = []
	if start.distance_to(end) < 0.01:
		out.append(end)
		return out
	if not walkable(end):
		return out
	if clear_line(start, end):
		out.append(end)
		return out
	var from := _nearest_cell(start)
	var to := _nearest_cell(end)
	if from.x < 0 or to.x < 0:
		return out
	var path: Array[Vector2] = []
	for p in grid.get_point_path(from, to):
		path.append(p)
	if path.is_empty():
		return out
	path.append(end)
	# Pull the string: skip every waypoint a straight clear walk can cut out.
	var at := start
	var i := 0
	while i < path.size():
		var far := path.size() - 1
		while far > i and not clear_line(at, path[far]):
			far -= 1
		at = path[far]
		out.append(at)
		i = far + 1
	return out
