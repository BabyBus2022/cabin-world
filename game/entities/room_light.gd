class_name RoomLight
extends RefCounted
## Time of day and weather in a room. Same drawing as lighting.mjs and drawWeather in VADS.
##
## DATA MAPPING:
##   Daylight.reading         tint, darkness, beams, sky
##   SharedFeed.weather       the reading VADS sends in its weather message: rain, cloud, wind, windLevel, windAngle, fog, snow, phase
##   SharedFeed.presence_now  Qianxia's view.lighting and Xiaojingyu's lamps: on, off or auto for each room
##   scene modules            kind, light { x, y, radius }, glass, collision, from world.json
##
## Layers, bottom to top: floor beams, furniture and people, weather, tint and darkness, lamps.
## Lamps and prop glows use the original screen blend through ScreenLight.

const SHOPS := ["qianxia-shop", "world-arcade", "world-onsen"]
const HOMES := ["qianxia-home", "xiaojingyu-home"]
const QIANXIA_HOME := "qianxia-home"
const XJ_HOME := "xiaojingyu-home"

## For tests: draw this moment rather than now.
static var test_now := 0.0


static func now_ms() -> float:
	return test_now if test_now > 0.0 else SharedFeed.now_ms()


static func hash_of(n: float) -> float:
	var x := sin(n * 127.1 + 311.7) * 43758.5453
	return x - floorf(x)


static func lamp_settings(scene_id: String) -> Dictionary:
	var presence: Dictionary = SharedFeed.presence_now
	var q = presence.get("Final01")
	var view = q.get("view") if q is Dictionary else null
	var raw = view.get("lighting") if view is Dictionary else null
	var out: Dictionary = raw.duplicate() if raw is Dictionary else {}
	if not out.has("lamps"):
		out["lamps"] = "auto"
	if scene_id in SHOPS:
		out["lamps"] = "on"
	elif scene_id == XJ_HOME:
		var x = presence.get("xiaojingyu")
		out["lamps"] = str(x.get("lamps", "auto")) if x is Dictionary and x.get("lamps") != null else "auto"
	elif WorldData.scenes[scene_id]["outdoor"] == true:
		out["lamps"] = "off"
		out["lamp-west"] = "auto"
		out["lamp-east"] = "auto"
	for resident in Residents.people():
		if resident.get("home",{}).get("scene")==scene_id:
			var options: Dictionary=Economy.people.get(resident.key,{}).get("options",{})
			if options.has("lamps"):out.lamps=options.lamps
	# Actual committed sleep wins over per-lamp overrides without rewriting preferences.
	if sleeping_in(scene_id):
		out.lamps="off"
		for id in _modules(scene_id):
			if _modules(scene_id)[id].get("light") is Dictionary:out[id]="off"
	return out

static func sleeping_in(scene_id:String)->bool:
	for resident in Residents.people():
		if resident.get("home",{}).get("scene","")!=scene_id:continue
		if not Body.known(resident.key):continue
		if not Body.of(resident.key).bed_snapshot(SharedFeed.now_ms()).asleep:continue
		if Residents.saved(resident.key).get("scene",scene_id)==scene_id:return true
	return false

static func _rgba(c: Array, a: float) -> Color:
	return Color(float(c[0]) / 255.0, float(c[1]) / 255.0, float(c[2]) / 255.0, a)


static func _modules(scene_id: String) -> Dictionary:
	return WorldData.scenes[scene_id]["modules"]


static func _windows(scene_id: String) -> Array:
	var out: Array = []
	for m in _modules(scene_id).values():
		if m.get("kind") == "window":
			out.append(m)
	return out


## On the floor, under furniture.
static func draw_floor(c: CanvasItem, scene_id: String, light: Dictionary, size: Vector2) -> void:
	if not scene_id in HOMES or float(light["beamAlpha"]) <= 0.0:
		return
	var alpha: float = light["beamAlpha"]
	var beam := _rgba(light["beam"], alpha)
	var length: float = light["length"]
	var s: float = light["shift"]
	var bounds := Rect2(16, 52, size.x - 32.0, size.y - 68.0)
	for m in _windows(scene_id):
		var y := float(m["y"]) + float(m["h"])
		for col in 4:
			for row in 3:
				var x := float(m["x"]) + col * float(m["w"]) / 4.0 + 3.0
				var start := row * length / 3.0
				var end := start + length / 3.0 - 7.0
				var w := float(m["w"]) / 4.0 - 9.0
				_poly(c, bounds, [Vector2(x + s * start / length, y + start), Vector2(x + w + s * start / length, y + start), Vector2(x + w + s * end / length, y + end), Vector2(x + s * end / length, y + end)], beam)
	var long_by := clampf(8.0 + (40.0 - maxf(0.0, float(light["elevation"]))) * 0.35, 8.0, 24.0)
	var shadow := Color(29.0 / 255.0, 40.0 / 255.0, 67.0 / 255.0, clampf(alpha * 0.9, 0.0, 0.16))
	for m in _modules(scene_id).values():
		var col = m.get("collision")
		if not col is Dictionary:
			continue
		var x := float(m["x"]) + float(col["x"])
		var y := float(m["y"]) + float(col["y"]) + float(col["h"])
		var w := float(col["w"])
		_poly(c, bounds, [Vector2(x, y - 6.0), Vector2(x + w, y - 6.0), Vector2(x + w + s * 0.16, y + long_by), Vector2(x + s * 0.16, y + long_by)], shadow)


static func _poly(c: CanvasItem, bounds: Rect2, points: Array, color: Color) -> void:
	var clipped := Geometry2D.intersect_polygons(PackedVector2Array(points), PackedVector2Array([bounds.position, Vector2(bounds.end.x, bounds.position.y), bounds.end, Vector2(bounds.position.x, bounds.end.y)]))
	for p in clipped:
		if p.size() >= 3:
			c.draw_colored_polygon(p, color)


static func _panes(m: Dictionary) -> Array:
	var out: Array = []
	var x := float(m["x"])
	var y := float(m["y"])
	var w := float(m["w"])
	var h := float(m["h"])
	var glass = m.get("glass")
	if glass is Array:
		for g in glass:
			out.append(Rect2(x + float(g[0]) * w, y + float(g[1]) * h, float(g[2]) * w, float(g[3]) * h))
	else:
		for row in 4:
			for col in 4:
				out.append(Rect2(x + w * 0.085 + col * w * 0.213, y + h * 0.11 + row * h * 0.195, w * 0.194, h * 0.17))
	return out


static func _fill_panes(c: CanvasItem, panes: Array, r: Rect2, color: Color) -> void:
	for p in panes:
		var cut: Rect2 = p.intersection(r)
		if cut.has_area():
			c.draw_rect(cut, color)


## What's outside the window. Drawn just over the window itself.
static func draw_window(c: CanvasItem, m: Dictionary, light: Dictionary, weather, time: float) -> void:
	var colors := Daylight.sky(light)
	var e: float = light["elevation"]
	var panes := _panes(m)
	var x := float(m["x"])
	var y := float(m["y"])
	var w := float(m["w"])
	var h := float(m["h"])
	_fill_panes(c, panes, Rect2(x, y, w, h), _rgba(colors[0], 1.0))
	_fill_panes(c, panes, Rect2(x, y + h * 0.48, w, h * 0.52), _rgba(colors[1], 1.0))
	if e < -4.0:
		_fill_panes(c, panes, Rect2(x + w * 0.72, y + 9.0, 7, 9), Color("e3dfbf"))
		_fill_panes(c, panes, Rect2(x + w * 0.72 + 3.0, y + 8.0, 6, 7), _rgba(colors[0], 1.0))
		var star := Color("d4dfeb")
		star.a = clampf((-4.0 - e) / 6.0, 0.0, 1.0)
		for s in [[0.16, 0.28], [0.39, 0.43], [0.55, 0.2], [0.85, 0.52], [0.27, 0.12], [0.66, 0.36]]:
			_fill_panes(c, panes, Rect2(x + w * s[0], y + h * s[1], 1, 1), star)
	else:
		var drift := time * 1.6
		var cloud := Color("f6dcc4") if e < 10.0 else Color("f3eada")
		for d in [[22.0, 16.0, 30.0, 4.0, 1.0], [30.0, 12.0, 14.0, 4.0, 1.0], [w * 0.55, 26.0, 36.0, 3.0, 0.6], [w * 0.3, 34.0, 22.0, 2.0, 0.8]]:
			var cx := x + fposmod(d[0] + drift * d[4], w) - 20.0
			_fill_panes(c, panes, Rect2(roundf(cx), y + d[1], d[2], d[3]), cloud)
		var sx := x + w * clampf((float(light["azimuth"]) - 90.0) / 180.0, 0.05, 0.92)
		var sy := y + h * clampf(0.62 - e / 90.0, 0.08, 0.62)
		_fill_panes(c, panes, Rect2(sx, sy, 7, 7), Color("ffc98a") if e < 10.0 else Color("f8dd9c"))
	# The hills: a zigzag along the bottom, drawn column by column so they stay inside the glass.
	var hills := _rgba(colors[2], 1.0)
	for px in int(w):
		var step := float(px) / (w / 7.0)
		var i := int(floorf(step))
		var a := 0.76 if i % 2 == 1 else 0.66
		var b := 0.76 if (i + 1) % 2 == 1 else 0.66
		var top := y + h * lerpf(a, b, step - float(i))
		_fill_panes(c, panes, Rect2(x + px, top, 1, y + h - top), hills)
	if weather is Dictionary and float(weather.get("rain", 0)) > 0.0:
		var rain := Color(225.0 / 255.0, 236.0 / 255.0, 250.0 / 255.0, 0.6)
		var box := Rect2(x + w * 0.08, y + h * 0.1, w * 0.84, h * 0.75)
		for k in 40:
			var dx := x + hash_of(k) * w
			var dy := y + fposmod(hash_of(k + 0.5) * h + time * 70.0, h)
			if box.has_point(Vector2(dx, dy)):
				c.draw_line(Vector2(dx, dy), Vector2(dx - 1.0, dy + 4.0), rain, 1.0)


## Weather outdoors, under the tint.
static func draw_weather(c: CanvasItem, o: Dictionary, size: Vector2, time: float) -> void:
	var w := size.x
	var h := size.y
	var night: bool = o.get("phase") == "night"
	var cloud := float(o.get("cloud", 0))
	var rain := float(o.get("rain", 0))
	var wind := float(o.get("wind", 0))
	var level := int(o.get("windLevel", 0))
	if o.get("snow") == true:
		c.draw_rect(Rect2(0, 0, w, h), Color(220.0 / 255.0, 235.0 / 255.0, 244.0 / 255.0, 0.16))
		for i in 90:
			var x := fposmod(hash_of(i) * w + sin(time * 0.7 + i) * 7.0 + w, w)
			var y := fposmod(hash_of(i + 0.4) * h + time * 17.0, h)
			c.draw_rect(Rect2(roundf(x), roundf(y), 2, 2), Color("f1f6ff"))
	if not night and cloud > 0.15:
		for k in 4:
			var x := fposmod(k * 190.0 + time * (6.0 + wind * 6.0), w + 260.0) - 130.0
			var y := 40.0 + k * 90.0 + sin(k * 2.1) * 30.0
			c.draw_set_transform(Vector2(x, y), 0.0, Vector2(1.0, 46.0 / 110.0))
			c.draw_circle(Vector2.ZERO, 110.0, Color(40.0 / 255.0, 60.0 / 255.0, 70.0 / 255.0, 0.07 * cloud))
		c.draw_set_transform(Vector2.ZERO)
	if cloud > 0.6 or rain > 0.0:
		c.draw_rect(Rect2(0, 0, w, h), Color(70.0 / 255.0, 80.0 / 255.0, 100.0 / 255.0, 0.1 * cloud + 0.1 * rain))
	if o.get("fog") == true:
		var fog := Color(236.0 / 255.0, 240.0 / 255.0, 244.0 / 255.0, 0.22)
		for k in 3:
			c.draw_rect(Rect2(fposmod(time * 8.0 + k * 200.0, w + 300.0) - 300.0, 80.0 + k * 110.0, 300, 60), fog)
		c.draw_rect(Rect2(0, 0, w, h), Color(fog.r, fog.g, fog.b, 0.18))
	if level >= 2:
		for i in level * 4:
			var t := fposmod(time * (0.15 + wind * 0.04) + hash_of(i), 1.0)
			var x := t * (w + 40.0) - 20.0
			var y := hash_of(i + 0.3) * h + sin(time * 3.0 + i) * 10.0
			c.draw_rect(Rect2(roundf(x), roundf(y), 3, 2), Color("d4a33a") if i % 2 == 0 else Color("7fb35c"))
	if rain > 0.0:
		var angle := float(o.get("windAngle", 0))
		var slant := (-1.0 if angle > 90.0 and angle < 270.0 else 1.0) * minf(6.0, 1.0 + wind * 1.2)
		var line := Color(215.0 / 255.0, 230.0 / 255.0, 250.0 / 255.0, 0.55)
		for i in int(roundf(60.0 + rain * 160.0)):
			var x := fposmod(hash_of(i) * w + time * slant * 30.0, w)
			var y := fposmod(hash_of(i + 0.5) * h + time * (380.0 + hash_of(i + 0.2) * 120.0), h)
			c.draw_line(Vector2(x, y), Vector2(x + slant, y + 7.0), line, 1.0)
		for i in int(roundf(rain * 30.0)):
			var t := fposmod(time * 2.0 + hash_of(i * 5.0), 1.0)
			var at := Vector2(hash_of(i * 11.0) * w, 90.0 + hash_of(i * 13.0) * (h - 100.0))
			c.draw_set_transform(at, 0.0, Vector2(1.0, 0.4))
			c.draw_arc(Vector2.ZERO, maxf(0.5, t * 3.0), 0.0, TAU, 10, Color(225.0 / 255.0, 236.0 / 255.0, 250.0 / 255.0, 0.5 * (1.0 - t)), 1.0)
		c.draw_set_transform(Vector2.ZERO)


## Tint and darkness, over everything in the room.
static func draw_tint(c: CanvasItem, scene_id: String, light: Dictionary, size: Vector2) -> void:
	var darkness: float = light["darkness"]
	var outdoor: bool = WorldData.scenes[scene_id]["outdoor"] == true
	var main_on: bool = not outdoor and Daylight.light_enabled(str(lamp_settings(scene_id)["lamps"]), darkness)
	if float(light["tintAlpha"]) > 0.0:
		c.draw_rect(Rect2(Vector2.ZERO, size), _rgba(light["tint"], light["tintAlpha"]))
	var a := minf(darkness, 0.15) if main_on else (minf(darkness, 0.38) if outdoor else darkness)
	c.draw_rect(Rect2(Vector2.ZERO, size), Color(17.0 / 255.0, 26.0 / 255.0, 54.0 / 255.0, a))


## Dust in the sunbeams at Qianxia's, and fireflies by the plants at night.
static func draw_air(c: CanvasItem, scene_id: String, light: Dictionary, time: float) -> void:
	var beam_alpha: float = light["beamAlpha"]
	if scene_id == QIANXIA_HOME and beam_alpha > 0.0:
		var windows := _windows(scene_id)
		if not windows.is_empty():
			var win: Dictionary = windows[0]
			for i in 22:
				var h1 := fmod(sin(i * 12.9898) * 43758.5453, 1.0)
				var h2 := fmod(sin(i * 78.233) * 12345.678, 1.0)
				var depth := fmod(absf(h1) + time * 0.02 * (0.5 + absf(h2)), 1.0)
				var y := float(win["y"]) + float(win["h"]) + depth * float(light["length"])
				var x := float(win["x"]) + 8.0 + absf(h1) * (float(win["w"]) - 16.0) + float(light["shift"]) * depth + sin(time * 0.7 + i) * 3.0
				var a := beam_alpha * 2.2 * sin(depth * PI) * (0.6 + 0.4 * sin(time * 1.3 + i * 2.0))
				if a > 0.02:
					c.draw_rect(Rect2(roundf(x), roundf(y), 1, 1), _rgba(light["beam"], a))
	var darkness: float = light["darkness"]
	if darkness < 0.45:
		return
	var plants: Array = []
	for id in _modules(scene_id):
		if id.begins_with("plant"):
			plants.append(_modules(scene_id)[id])
	if plants.is_empty():
		return
	for k in 9:
		var m: Dictionary = plants[k % plants.size()]
		var x := float(m["x"]) + float(m["w"]) / 2.0 + sin(time * 0.6 + k * 1.9) * (10.0 + (k % 3) * 4.0)
		var y := float(m["y"]) + float(m["h"]) * 0.3 + cos(time * 0.45 + k * 2.7) * 8.0
		var a := (darkness - 0.4) * 1.6 * (sin(time * 2.2 + k * 1.3) + 1.0) / 2.0
		var at := Vector2(roundf(x), roundf(y))
		c.draw_rect(Rect2(at, Vector2.ONE), Color(1.0, 247.0 / 255.0, 168.0 / 255.0, a))
		c.draw_rect(Rect2(at - Vector2.ONE, Vector2(3, 3)), Color(1.0, 247.0 / 255.0, 168.0 / 255.0, a * 0.35))


## The lamps that are on: [centre, radius, strength, is the main ceiling light].
static func lamps_on(scene_id: String, darkness: float) -> Array:
	var settings := lamp_settings(scene_id)
	var out: Array = []
	var modules := _modules(scene_id)
	for id in modules:
		var m: Dictionary = modules[id]
		var l = m.get("light")
		if not l is Dictionary:
			continue
		var mode := str(settings.get(id, settings["lamps"]))
		if not Daylight.light_enabled(mode, darkness):
			continue
		var ceiling: bool = m.get("kind") == "ceiling-light"
		var at := Vector2(float(m["x"]) + float(l["x"]), float(m["y"]) + float(l["y"]) + (150.0 if ceiling else 0.0))
		out.append([at, float(l["radius"]), 0.06 + darkness * 0.12 if ceiling else 0.25 + darkness * 0.4, ceiling])
	return out
