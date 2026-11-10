class_name RoomKitItems
extends RefCounted
## Adds roomkit placements that are NOT in the built-in catalog to a HomeGrid definition (opt-in, `--roomkit <dir>`).
## Each new item becomes a catalog entry + scene module + art layer + zones, exactly the shapes home-grid.json uses,
## so the editor, collision, depth sorting and save format treat it like any other furniture.
##
## Asset art fields (all optional; no art => a visible placeholder block, i.e. the white model):
##   art.S / art.N / art.E / art.W  image path relative to the roomkit folder (falls back to S)
##   art.px_per_unit  image pixels per world pixel (default 2, like the baked room art)
##   art.origin       [x,y] world px of the image's top-left relative to the footprint's top-left
##                    (default: image bottom edge on the footprint's bottom edge, left edges aligned)
## World pixels = cells * room.cell (32). Depth (sorting line) = footprint bottom edge for solid items, top edge otherwise.

const RK := preload("res://core/roomkit.gd")
static var textures: Dictionary = {}

## Mutates `def` (a HomeGrid definition). Returns ids of the items it added.
static func augment(def: Dictionary, dir: String, scene: String) -> Array:
	var room_file := dir.path_join("rooms").path_join(scene).path_join("room.json")
	if def.get("_roomkit", false) or not FileAccess.file_exists(room_file): return []
	var kit: Dictionary = RK.load_room(dir, scene)
	if kit.error != "": return []
	def["_roomkit"] = true
	var shape: Dictionary = RK.shape(kit) ## empty unless room.shape.drive is true
	if not shape.is_empty(): def["_shape"] = shape
	var known := {}
	for item in def.catalog: known[item.id] = true
	var added: Array = []
	var cell := float(kit.room.cell)
	for p in kit.room.placements:
		if known.has(p.id): continue
		var a: Dictionary = kit.assets[p.asset]
		var d: String = p.get("dir", "S")
		var s: Vector2i = RK.size_for(a, d)
		var foot := Rect2(float(p.cell[0]) * cell, float(p.cell[1]) * cell, s.x * cell, s.y * cell)
		var art: Dictionary = a.get("art", {}) if typeof(a.get("art", {})) == TYPE_DICTIONARY else {}
		var file: String = art.get(d, art.get("S", ""))
		var ppu := float(art.get("px_per_unit", 2.0))
		var tex: Texture2D = null
		if file != "": tex = external_texture(dir.path_join(file))
		var size: Vector2 = foot.size if tex == null else tex.get_size() / ppu
		var origin: Array = art.get("origin", [0.0, foot.size.y - size.y])
		var pos := foot.position + Vector2(float(origin[0]), float(origin[1]))
		var solid: bool = a.layer == "solid"
		var depth := foot.end.y if solid else foot.position.y
		var zone_ids: Array = []
		for n in a.get("anchors", {}):
			var zid := "rk_%s_%s" % [p.id, n]
			var ap := RK.anchor_px(kit.room, p, a, n)
			def.sceneData.zones[zid] = {"x": ap.x, "y": ap.y}
			zone_ids.append(zid)
		var module := {"x": pos.x, "y": pos.y, "w": size.x, "h": size.y, "id": p.id, "depth": depth, "kind": "decoration"}
		if solid: module["collision"] = {"x": foot.position.x - pos.x, "y": foot.position.y - pos.y, "w": foot.size.x, "h": foot.size.y}
		def.sceneData.modules[p.id] = module
		var layer := {"id": p.id, "file": "roomkit:" + (dir.path_join(file) if tex != null else "block:%d:%d:%s" % [int(size.x), int(size.y), a.kind]), "x": pos.x, "y": pos.y, "w": size.x, "h": size.y, "depth": depth, "scale": 1.0 / ppu if tex != null else 1.0}
		def.manifest.layers.append(layer)
		def.catalog.append({"id": p.id, "name": a.get("name", p.id), "cell": [float(p.cell[0]), float(p.cell[1])], "layer": a.layer, "box": [pos.x, pos.y, size.x, size.y], "foot": [foot.position.x, foot.position.y, foot.size.x, foot.size.y], "zoneIds": zone_ids})
		added.append(p.id)
	return added

## Texture for a layer file starting with "roomkit:". Real file => image; "block:W:H:kind" => placeholder rectangle.
static func texture_for(spec: String) -> Texture2D:
	if textures.has(spec): return textures[spec]
	var tex: Texture2D = null
	if spec.begins_with("block:"):
		var bits := spec.split(":")
		var img := Image.create(max(1, int(bits[1])), max(1, int(bits[2])), false, Image.FORMAT_RGBA8)
		img.fill(Color(0.93, 0.93, 0.95, 0.92))
		for x in img.get_width():
			for y in img.get_height():
				if x == 0 or y == 0 or x == img.get_width() - 1 or y == img.get_height() - 1: img.set_pixel(x, y, Color(0.35, 0.4, 0.5))
		tex = ImageTexture.create_from_image(img)
	else:
		tex = external_texture(spec)
	textures[spec] = tex
	return tex

static func external_texture(path: String) -> Texture2D:
	if not FileAccess.file_exists(path): return null
	var img := Image.load_from_file(path)
	return null if img == null else ImageTexture.create_from_image(img)
