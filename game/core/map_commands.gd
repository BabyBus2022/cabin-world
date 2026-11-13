extends RefCounted
## Map commands: lets an AI (Codex, a DeepSeek harness, any script) build and edit maps in the background with exactly
## the rules of the map editor (core/map_model.gd). Owner request 2026-11-11. Full description: docs/MAP-AI-COMMANDS.md.
##
## A command list is JSON: [{"op": "...", ...}, ...]. It is applied ALL OR NOTHING: if one command fails, the map is left
## as it was and the result says which command failed and why. Coordinates are cells [x, y] from the top-left of the
## 30 x 20 map; a rect is [x1, y1, x2, y2] inclusive.
##
## Run from a shell (Godot with the project, or the exported game, which is the same entry point):
##   CabinWorld.exe -- --map-cli --map <dir>/<id>/map.json --commands <file.json> [--render <out.png>] [--result <out.json>]
##   CabinWorld.exe -- --map-cli --catalog --result <out.json>      (lists tile, wall style and door/window ids)
## The map file is written only when every command succeeded (previous version kept as map.json.bak); the editor, if it
## has that map open with no unsaved edits, reloads it within a second. Nothing here touches game rooms or saves.

const M := preload("res://core/map_model.gd")
const R := preload("res://core/map_render.gd")
const Design:=preload("res://core/map_design.gd")
const OPS := ["new", "rename", "floor", "erase", "walls", "inner", "doorway", "opening", "remove_opening", "link", "theme", "wall_material", "import_material"]

## Cells of a command: "rect": [x1,y1,x2,y2] and/or "cells": [[x,y],...]. Returns [] and sets err[0] when malformed.
static func cells_of(c: Dictionary, err: Array) -> Array:
	var out: Array = []
	if c.has("rect"):
		var r = c.rect
		if not r is Array or r.size() != 4: err.append("rect 要写成 [x1, y1, x2, y2]"); return []
		for y in range(mini(int(r[1]), int(r[3])), maxi(int(r[1]), int(r[3])) + 1):
			for x in range(mini(int(r[0]), int(r[2])), maxi(int(r[0]), int(r[2])) + 1): out.append(Vector2i(x, y))
	if c.has("cells"):
		if not c.cells is Array: err.append("cells 要写成 [[x, y], ...]"); return []
		for p in c.cells:
			if not p is Array or p.size() != 2: err.append("cells 里每一格要写成 [x, y]"); return []
			out.append(Vector2i(int(p[0]), int(p[1])))
	if out.is_empty() and err.is_empty(): err.append("要给 rect 或 cells")
	return out

static func at_of(c: Dictionary, key: String, err: Array):
	var p = c.get(key)
	if not p is Array or p.size() != 2: err.append("%s 要写成 [x, y]" % key); return null
	return Vector2i(int(p[0]), int(p[1]))

## Applies one command. Returns [new map, error ("" = ok)].
static func apply(m: Dictionary, c: Dictionary) -> Array:
	var op := str(c.get("op", "")); var err: Array = []
	if not op in OPS: return [m, "不认识的 op「%s」，可用：%s" % [op, ", ".join(OPS)]]
	match op:
		"theme":
			var id:=str(c.get("id",""))
			if not Design.THEMES.has(id) or M.outdoor(m):return [m,"请选择有效的室内主题"]
			return [Design.apply_theme(m,id),""]
		"import_material":
			var path:=str(c.get("path",""));var f:=FileAccess.open(path,FileAccess.READ)
			if f==null or f.get_length()>1048576:return [m,"PNG 无法读取或超过 1 MB"]
			var result:=Design.import_png(m,str(c.get("kind","floor")),str(c.get("name",path.get_file().get_basename())),f.get_buffer(f.get_length()))
			return [result.get("map",m),result.error]
		"wall_material":
			var style:=str(c.get("style",""))
			if style!="" and not R.walls(m).has(style):return [m,"未知墙面材质"]
			var cells:=cells_of(c,err)
			if not err.is_empty():return [m,err[0]]
			var out:=m
			for p in cells:
				if Design.wall_target(m,p).is_empty():return [m,"格子不在墙面上："+str(p)]
				out=Design.paint_wall(out,p,style)
			return [out,""]
		"new":
			if str(c.get("id", "")) == "": return [m, "new 要给 id"]
			var kind := str(c.get("kind", "indoor"))
			if not kind in ["indoor", "outdoor"]: return [m, "kind 只能是 indoor 或 outdoor"]
			return [M.new_map(str(c.id), str(c.get("name", c.id)), kind), ""]
		"rename":
			var out := m.duplicate(true); out.name = str(c.get("name", m.name)); return [out, ""]
		"floor":
			var tile := str(c.get("tile", ""))
			if not tile in R.floor_ids(m): return [m, "这张%s地图没有地面「%s」，可用：%s" % ["室外" if M.outdoor(m) else "室内", tile, ", ".join(R.floor_ids(m))]]
			var cells := cells_of(c, err)
			if not err.is_empty(): return [m, err[0]]
			for p in cells:
				if not M.inb(m, p): return [m, "格子 %s 在地图外（地图是 %d × %d）" % [p, M.size_of(m).x, M.size_of(m).y]]
			return [M.paint_floor(m, cells, tile), ""]
		"erase":
			var cells := cells_of(c, err)
			if not err.is_empty(): return [m, err[0]]
			return [M.paint_floor(m, cells, ""), ""]
		"walls":
			var style := str(c.get("style", ""))
			if M.outdoor(m):
				if not R.EDGES.has(style): return [m, "室外地图的篱笆样式只有：%s" % ", ".join(R.EDGES.keys())]
				return [M.set_wall_style(m, "edge", style), ""]
			if not R.walls(m).has(style): return [m, "没有墙样式「%s」，可用：%s" % [style, ", ".join(R.walls(m).keys())]]
			var out := m
			for part in c.get("parts", ["back", "side", "front"]):
				if not part in ["back", "side", "front"]: return [m, "parts 只能是 back / side / front"]
				out = M.set_wall_style(out, part, style)
			return [out, ""]
		"inner":
			var cells := cells_of(c, err)
			if not err.is_empty(): return [m, err[0]]
			var on := bool(c.get("on", true))
			if on:
				for p in cells:
					if not M.is_floor(m, p): return [m, "%s只能画在%s上：%s 不是" % ["篱笆" if M.outdoor(m) else "内墙", "地面" if M.outdoor(m) else "地板", p]]
			return [M.set_inner(m, cells, on), ""]
		"doorway":
			var p = at_of(c, "at", err)
			if p == null: return [m, err[0]]
			var why := M.doorway_issue(m, p)
			if why != "": return [m, why + "：%s 不是内墙" % p]
			var open := bool(c.get("open", true))
			if M.is_doorway(m, p) == open: return [m, ""]
			return [M.toggle_doorway(m, p), ""]
		"opening":
			var type := str(c.get("type", ""))
			if not type in M.openings_for(m): return [m, "这张%s地图没有「%s」，可用：%s" % ["室外" if M.outdoor(m) else "室内", type, ", ".join(M.openings_for(m))]]
			var x: int; var y: int; var side := str(c.get("side", ""))
			if c.has("near"):
				var p = at_of(c, "near", err)
				if p == null: return [m, err[0]]
				var t = M.opening_target(m, type, p)
				if t == null: return [m, "%s 附近放不了%s" % [p, M.OPENINGS[type].name]]
				x = t[0]; y = t[1]
				if t.size() > 2: side = str(t[2])
			else:
				if not (c.has("x") and c.has("y")): return [m, "opening 要给 x 和 y（或 near）"]
				x = int(c.x); y = int(c.y)
			if M.OPENINGS[type].wall == "edge" and not side in ["N", "S", "E", "W"]: return [m, "路口要给 side（N/S/E/W，贴着哪条地图边），或者用 near"]
			var why := M.opening_issue(m, type, x, y, -1, side)
			if why != "": return [m, "%s 放不到 (%d, %d)：%s" % [M.OPENINGS[type].name, x, y, why]]
			return [M.add_opening(m, type, x, y, side), ""]
		"remove_opening":
			var index := -1
			if c.has("id"):
				for i in m.openings.size():
					if m.openings[i].id == str(c.id): index = i
			elif c.has("at"):
				var p = at_of(c, "at", err)
				if p == null: return [m, err[0]]
				index = M.opening_at(m, p)
			if index < 0: return [m, "找不到要移除的门窗"]
			return [M.remove_opening(m, index), ""]
		"link":
			var id := str(c.get("exit", ""))
			if not m.exits.has(id): return [m, "没有出口「%s」；门的出口名就是门的 id，比如 front_door_1" % id]
			var out := m.duplicate(true); out.exits[id] = {"to": str(c.get("to", "")), "entry": str(c.get("entry", ""))}; return [out, ""]
	return [m, "?"]

## Applies a whole list, all or nothing. {"ok", "map" (the new map, or the old one on failure), "results": [...]}.
static func run(m: Dictionary, commands: Array) -> Dictionary:
	var issue:=Design.materials_issue(m)
	if issue!="":return {"ok":false,"map":m,"results":[{"ok":false,"error":issue}]}
	var results: Array = []; var current := m
	for i in commands.size():
		var c = commands[i]
		if not c is Dictionary: results.append({"i": i, "ok": false, "error": "每条命令要是一个对象，比如 {\"op\": \"floor\", ...}"}); return {"ok": false, "map": m, "results": results}
		var r := apply(current, c)
		if r[1] != "":
			results.append({"i": i, "op": c.get("op", ""), "ok": false, "error": r[1]})
			return {"ok": false, "map": m, "results": results}
		current = r[0]; results.append({"i": i, "op": c.op, "ok": true})
	return {"ok": true, "map": current, "results": results}

## What an AI needs to see the map: rule results and a text plan.
## Plan legend: '.' outside, floor = its palette letter, '#' interior wall, '+' doorway, 'W' window/sign/lamp/back door
## on the wall row above the floor edge, 'D' a front door on the bottom edge row.
static func describe(m: Dictionary) -> Dictionary:
	var s := M.size_of(m); var rows: Array = []
	for y in s.y:
		var line := ""
		for x in s.x:
			var c := Vector2i(x, y)
			line += "+" if M.is_doorway(m, c) else ("#" if M.is_inner(m, c) else M.floor_char(m, c))
		rows.append(line)
	for o in m.openings:
		var d: Dictionary = M.OPENINGS.get(o.type, {})
		if d.is_empty(): continue
		if d.wall in ["edge", "ground"]: # outdoor: E = path exit at the edge, I = building entrance
			for c in M.opening_cells(o):
				if M.inb(m, c): rows[c.y] = rows[c.y].substr(0, c.x) + ("E" if d.wall == "edge" else "I") + rows[c.y].substr(c.x + 1)
			continue
		var y: int = int(o.y) - 1 if d.wall == "back" else int(o.y)
		if y < 0 or y >= s.y: continue
		var ch := "D" if d.get("door", false) else "W"
		for dx in int(d.w):
			var x := int(o.x) + dx
			if x < s.x: rows[y] = rows[y].substr(0, x) + ch + rows[y].substr(x + 1)
	var checks: Array = []
	for c in M.checks(m): checks.append({"id": c[4], "rule": c[0], "ok": c[1], "detail": c[2], "cells": (c[3] as Array).slice(0, 20).map(func(v): return [v.x, v.y])})
	return {"id": m.id, "name": m.name, "kind": m.get("kind", "indoor"), "size": m.size, "palette": m.floor.palette, "walls": m.walls.style, "materials":m.get("materials",{}).keys(), "wallSegments":m.walls.get("segments",{}), "openings": m.openings,
		"exits": m.exits, "plan": rows, "checks": checks, "usable": M.usable(m), "floorCells": M.floor_cells(m).size()}

static func catalog() -> Dictionary:
	var out := {"size": [M.SIZE.x, M.SIZE.y], "wallHeight": M.WALL_H, "ops": OPS, "blockingTiles": M.BLOCKING_TILES}
	for kind in ["indoor", "outdoor"]:
		var probe := M.new_map("probe", "probe", kind); var floors := {}; var openings := {}
		for id in R.floor_ids(probe): floors[id] = R.FLOORS[id].name
		for id in M.openings_for(probe): openings[id] = {"name": M.OPENINGS[id].name, "wall": M.OPENINGS[id].wall, "width": M.OPENINGS[id].w, "door": M.OPENINGS[id].get("door", false)}
		var styles := {}
		for id in (R.WALLS if kind == "indoor" else R.EDGES): styles[id] = (R.WALLS if kind == "indoor" else R.EDGES)[id].name
		out[kind] = {"floors": floors, "wallStyles": styles, "openings": openings}
	var w = JSON.parse_string(FileAccess.get_file_as_string("res://assets/world.json"))
	var rooms := {}
	if w is Dictionary:
		for id in w.scenes: rooms[id] = {"name": w.scenes[id].get("name", id), "entries": w.scenes[id].get("entries", {}).keys()}
	out.worldRooms = rooms # link targets: "to" = a room id, "entry" = one of its entries
	return out

## The shell entry point (main.gd calls it for `-- --map-cli`). Returns the process exit code: 0 ok, 1 a command
## failed (map unchanged), 2 bad arguments or files.
static func cli(args: PackedStringArray) -> int:
	var arg := func(name: String) -> String:
		var i := args.find(name); return args[i + 1] if i >= 0 and i + 1 < args.size() else ""
	var out := {}
	var code := 0
	if "--restore-room" in args:
		var why:String=load("res://core/room_maps.gd").restore_original(arg.call("--restore-room"))
		return report({"ok":why=="","error":why,"nextLaunch":true},arg.call("--result"),0 if why=="" else 1)
	if "--catalog" in args: out = catalog()
	else:
		var path: String = arg.call("--map")
		if path == "": return report({"ok": false, "error": "要给 --map <map.json 的路径>"}, arg.call("--result"), 2)
		var m = JSON.parse_string(FileAccess.get_file_as_string(path)) if FileAccess.file_exists(path) else {}
		if "--room" in args:
			m=load("res://core/room_maps.gd").draft(arg.call("--room"))
			if m.is_empty():return report({"ok":false,"error":"未知现有房间"},arg.call("--result"),2)
		if not m is Dictionary: return report({"ok": false, "error": "读不了地图文件 " + path}, arg.call("--result"), 2)
		if m.has("legacy") and not m.has("editScene"): return report({"ok": false, "error": "请用 --room 房间编号创建可编辑草稿，勿直接覆盖内置文件"}, arg.call("--result"), 2)
		if path.begins_with("res://"):return report({"ok":false,"error":"请把草稿保存到自己的文件夹"},arg.call("--result"),2)
		var commands: Array = []
		var cpath: String = arg.call("--commands")
		if cpath != "":
			var parsed = JSON.parse_string(FileAccess.get_file_as_string(cpath))
			if not parsed is Array: return report({"ok": false, "error": "命令文件要是一个 JSON 数组：" + cpath}, arg.call("--result"), 2)
			commands = parsed
		if m.is_empty() and (commands.is_empty() or not commands[0] is Dictionary or commands[0].get("op") != "new"):
			return report({"ok": false, "error": "地图文件不存在；第一条命令要是 {\"op\": \"new\", \"id\": ..., \"name\": ...}"}, arg.call("--result"), 2)
		var r := run(m, commands)
		out = {"ok": r.ok, "results": r.results}
		if r.ok and (not commands.is_empty() or "--room" in args):
			DirAccess.make_dir_recursive_absolute(path.get_base_dir())
			if FileAccess.file_exists(path): DirAccess.copy_absolute(path, path + ".bak")
			var f := FileAccess.open(path + ".tmp", FileAccess.WRITE)
			if f == null: return report({"ok": false, "error": "写不了 " + path}, arg.call("--result"), 2)
			f.store_string(JSON.stringify(r.map, " ", false, true) + "\n"); f.close()
			DirAccess.rename_absolute(path + ".tmp", path); out.saved = path
		if not r.ok: code = 1
		if r.ok and "--publish" in args:
			var why:String=load("res://core/room_maps.gd").publish(r.map)
			out.ok=why=="";out.error=why;out.nextLaunch=why==""
			if why!="":code=1
		out.map = describe(r.map)
		var png: String = arg.call("--render")
		if png != "": R.flat(r.map).save_png(png); out.render = png
	return report(out, arg.call("--result"), code)

static func report(out: Dictionary, result_file: String, code: int) -> int:
	var text := JSON.stringify(out, " ")
	print("MAPCLI " + JSON.stringify(out))
	if result_file != "":
		var f := FileAccess.open(result_file, FileAccess.WRITE)
		if f != null: f.store_string(text + "\n"); f.close()
	return code
