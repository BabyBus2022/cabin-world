extends RefCounted
## Draws a new map (core/map_model.gd, docs/MAP-FORMAT.md) the way the owner's trial editor did, as images at the game's
## 2x art scale (64 px per cell):
##   ground  = floor tiles + soft wall shadows + lamp glow + back walls + things on the back wall
##   inner   = interior walls (their own image, so the game can sort them with people later; the editor stacks it)
##   overlay = side walls, the low front wall and front doors (drawn over people)
## Pieces are placeholders until GPT's piece sets (docs/MAP-PIECES-SPEC.md): the trial's floor tiles and wall patterns
## (assets/map-pieces/), walls coloured from a style, doors and windows cut from the current 小卖部 picture.
## Pure drawing: reads only res:// art, writes nothing.

const MapModel := preload("res://core/map_model.gd")
const CP := MapModel.Grid.ART_CELL ## px per cell
const WALL_H := MapModel.WALL_H
const SHOP := "res://assets/baked/qianxia-shop.ground.png"

## Piece sets drawn by GPT (docs/MAP-PIECES-SPEC.md), imported after the owner's OK into assets/map-pieces/<set>/.
## A wall style or floor with "set" is drawn from that set's images instead of colours.
const SET_DIR := "res://assets/map-pieces/%s/%s.png"
static func piece(set_id: String, name: String) -> Image:
	var path := SET_DIR % [set_id, name]
	return image(path) if ResourceLoader.exists(path) else null
## Same cell, same variant: a fixed pick among a, b, c, d so large floors don't repeat visibly.
static func variant(c: Vector2i, names: Array) -> String: return names[posmod(c.x * 73856093 ^ c.y * 19349663, names.size())]
const FLOORS := {
	"arcade-coast-wood":{"name":"海岸电玩城 · 蜂蜜木地板","file":"res://assets/map-pieces/arcade-coast/floor-wood.png","span":2},
	"arcade-coast-night":{"name":"海岸电玩城 · 星夜地毯","file":"res://assets/map-pieces/arcade-coast/floor-night.png","span":2,"binding":true},
	"shop-cream-tile": {"name":"奶油细砖","set":"shop-cream","file":"res://assets/map-pieces/shop-cream/floor-a.png"},
	# cut from the old shop picture at its real scale (26.5 px squares); "span": 2 = one 128 px tile covers 2 x 2 cells
	"shop-classic-tile": {"name":"小卖部地砖","file":"res://assets/map-pieces/shop-classic-floor.png","span":2},
	"floor-shop-tile": {"name":"小卖部地砖","file":"res://assets/map-pieces/floor-shop-tile.png"},
	"floor-wood": {"name":"木地板","file":"res://assets/map-pieces/floor-arcade-wood-v1.png"},
	"floor-stone": {"name":"石砖","file":"res://assets/map-pieces/floor-arcade-stone-v1.png"},
	"floor-green": {"name":"绿地毯","file":"res://assets/map-pieces/floor-arcade-green-v1.png"},
	# Outdoor ground: tiles cut from the current park picture (handover/map-editor-v2-20261111/make-outdoor-tiles.gd) until GPT draws an outdoor set.
	"ground-grass": {"name":"草地","file":"res://assets/map-pieces/ground-grass.png","outdoor":true},
	"ground-path": {"name":"小路","file":"res://assets/map-pieces/ground-path.png","outdoor":true},
	"ground-sand": {"name":"沙地","file":"res://assets/map-pieces/ground-sand.png","outdoor":true},
	"ground-stone": {"name":"石板路","file":"res://assets/map-pieces/floor-arcade-stone-v1.png","outdoor":true},
	"ground-water": {"name":"水（不能走）","file":"res://assets/map-pieces/ground-water.png","outdoor":true},
}
## Outdoor edges: fences and hedges drawn on cells like interior walls (they block walking).
const EDGES := {
	"hedge": {"name":"树篱","top":"6f9a3a","face":"55702a","dark":"3f5520"},
	"fence-wood": {"name":"木栅栏","top":"c99a5c","face":"8f6239","dark":"5a3b22"},
}
static func floor_ids(m: Dictionary) -> Array:
	var all:=floors(m)
	return all.keys().filter(func(id): return bool(all[id].get("outdoor", false)) == MapModel.outdoor(m))
static func floors(m:Dictionary)->Dictionary:
	var all:=FLOORS.duplicate()
	if m.has("editScene") and MapModel.outdoor(m) and m.get("legacy",{}).has("definition"):
		all["original-ground"]={"name":"保留原有地面","outdoor":true}
	for id in m.get("materials",{}).get("floor",{}):
		var d:Dictionary=m.materials.floor[id].duplicate();d.file="png:"+str(d.png);all[id]=d
	return all
static func walls(m:Dictionary)->Dictionary:
	var all:=WALLS.duplicate()
	for id in m.get("materials",{}).get("wall",{}):
		var d:Dictionary=WALLS["arcade-coast"].duplicate()
		d.name=m.materials.wall[id].name;d.pattern="png:"+str(m.materials.wall[id].png);all[id]=d
	return all
const WALLS := {
	"arcade-coast":{"name":"海岸电玩城 · 奶油墙与胡桃木","pattern":"res://assets/map-pieces/arcade-coast/wall-cream.png","wainsPattern":"res://assets/map-pieces/arcade-coast/wall-walnut.png","plaster":"f3dcc0","shade":"e7c9a6","wains":"6e4631","line":"523222","trim":"9f7544","cap":"523b2d","side":"f0dbba"},
	"arcade-coast-rich":{"name":"星光电玩城 · 雕花副墙","innerSet":"arcade-coast-rich","pattern":"res://assets/map-pieces/arcade-coast/wall-cream.png","wainsPattern":"res://assets/map-pieces/arcade-coast/wall-walnut.png","plaster":"f3dcc0","shade":"e7c9a6","wains":"6e4631","line":"523222","trim":"9f7544","cap":"523b2d","side":"f0dbba"},
	"shop-cream": {"name":"奶油墙 · 木护墙","set":"shop-cream","plaster":"f3dcc0","shade":"e7c9a6","wains":"6e4631","line":"523222","trim":"5c3b29","cap":"2b2321","side":"efd3b1"},
	"whale-blue": {"name":"浅蓝墙 · 白护墙","plaster":"e6eef6","shade":"d3dfec","wains":"9fb5ce","line":"7d93ae","trim":"53647f","cap":"3d4762","side":"dde7f1"},
	"brick": {"name":"砖墙","pattern":"res://assets/map-pieces/wall-arcade-brick-v1.png","plaster":"b4674e","shade":"9a5641","wains":"4b3b35","line":"332824","trim":"3a2e2a","cap":"231c1a","side":"a96350"},
	"plank": {"name":"木板墙","pattern":"res://assets/map-pieces/wall-shop-wood.png","plaster":"a57a55","shade":"8f6847","wains":"5b3b2a","line":"432a1d","trim":"4a3022","cap":"271e1b","side":"9c7350"},
}
## Cut from the 小卖部 picture (2x baked px): crop, where it sits. back: top = px below the wall top (or a door's bottom on
## the floor line); front: floor_at = the crop's floor line.
const CROPS := {
	"back_door": {"crop":[1066,76,108,128]},
	"window": {"crop":[814,79,228,40],"top":62},
	"sign": {"crop":[503,84,272,60],"top":54},
	"lamp": {"crop":[206,20,218,28],"top":8},
	"front_door": {"crop":[441,708,400,146],"floor_at":780},
}
static var _images := {}

## A generated placeholder ground tile: base colour plus a fixed sprinkle of lighter and darker marks.
static func generated(kind: String) -> Image:
	var spec: Array = {"grass":["8fb24a","a6c65a","6f9236"], "path":["d2bc8c","e2d0a6","b39b6c"], "sand":["ead9a8","f6e8c2","d3bf8a"],
		"stone":["a9a59a","c3beb2","86827a"], "water":["5fa8cc","8cc8e2","4a8fb2"]}[kind]
	var img := Image.create(CP, CP, false, Image.FORMAT_RGBA8); img.fill(Color(spec[0]))
	var rng := RandomNumberGenerator.new(); rng.seed = hash(kind)
	if kind == "stone":
		for r in [Rect2i(1,1,30,30), Rect2i(33,1,30,30), Rect2i(1,33,30,30), Rect2i(33,33,30,30)]:
			img.fill_rect(r, Color(spec[1])); img.fill_rect(Rect2i(r.position.x, r.end.y - 3, r.size.x, 3), Color(spec[2]))
		return img
	for i in 70:
		var p := Vector2i(rng.randi_range(0, CP - 3), rng.randi_range(0, CP - 3))
		var c := Color(spec[1] if i % 2 == 0 else spec[2])
		if kind == "grass": img.fill_rect(Rect2i(p, Vector2i(2, 4)), c)
		elif kind == "water": img.fill_rect(Rect2i(p, Vector2i(8, 2)), Color(spec[1]))
		else: img.fill_rect(Rect2i(p, Vector2i(2, 2)), c)
	return img

static func image(path: String) -> Image:
	if path.begins_with("png:"):
		var key:=path.sha256_text()
		if not _images.has(key):
			var img:=Image.new()
			if img.load_png_from_buffer(Marshalls.base64_to_raw(path.substr(4)))!=OK:return Image.create(CP,CP,false,Image.FORMAT_RGBA8)
			img.convert(Image.FORMAT_RGBA8);_images[key]=img
		return _images[key]
	if path.begins_with("gen:"):
		if not _images.has(path): _images[path] = generated(path.trim_prefix("gen:"))
		return _images[path]
	if not _images.has(path):
		var tex = load(path)
		var img: Image = tex.get_image() if tex is Texture2D else Image.create(CP, CP, false, Image.FORMAT_RGBA8)
		if img.is_compressed(): img.decompress()
		img.convert(Image.FORMAT_RGBA8)
		_images[path] = img
	return _images[path]

static func blank(m: Dictionary) -> Image:
	var s := MapModel.size_of(m)
	return Image.create(s.x * CP, s.y * CP, false, Image.FORMAT_RGBA8)

## Fills a rect; colours with alpha < 1 are blended over what is there.
static func fill(img: Image, r: Rect2i, c: Color) -> void:
	r = r.intersection(Rect2i(Vector2i.ZERO, img.get_size()))
	if r.size.x <= 0 or r.size.y <= 0: return
	if c.a >= 0.999: img.fill_rect(r, c); return
	var src := Image.create(r.size.x, r.size.y, false, Image.FORMAT_RGBA8); src.fill(c)
	img.blend_rect(src, Rect2i(Vector2i.ZERO, r.size), r.position)

## A shade fading from alpha a to 0 across the rect (vertical when down, else horizontal; from_end flips it).
static func fade(img: Image, r: Rect2i, c: Color, a: float, down: bool, from_end := false) -> void:
	var n := r.size.y if down else r.size.x
	for i in range(0, n, 2):
		var t := float(i) / float(n); var k := (1.0 - t) * a
		var j := n - i - 2 if from_end else i
		fill(img, Rect2i(r.position + (Vector2i(0, j) if down else Vector2i(j, 0)), Vector2i(r.size.x, 2) if down else Vector2i(2, r.size.y)), Color(c, k))

static func tile(img: Image, r: Rect2i, src: Image) -> void:
	# Use one texture origin across neighboring cells; a 128px wallpaper spans
	# two 64px art cells instead of restarting its left half at every wall seam.
	var begin:=Vector2i(floori(float(r.position.x)/src.get_width())*src.get_width(),floori(float(r.position.y)/src.get_height())*src.get_height())
	for y in range(begin.y,r.end.y,src.get_height()):
		for x in range(begin.x,r.end.x,src.get_width()):
			var visible:=Rect2i(Vector2i(x,y),src.get_size()).intersection(r)
			img.blend_rect(src,Rect2i(visible.position-Vector2i(x,y),visible.size),visible.position)

static func style(m: Dictionary, part: String, c:=Vector2i(-1,-1)) -> Dictionary:
	var fallback:=str(m.walls.style.get("back" if part=="inner" else part,""))
	var id:=str(m.walls.get("segments",{}).get("%s:%d:%d" % [part,c.x,c.y],fallback))
	return walls(m).get(id,{})
static func col(st: Dictionary, key: String) -> Color: return Color(str(st[key]))

## Red-white hatching: a wall with no style yet ("no white walls" rule).
static func hatch(img: Image, r: Rect2i) -> void:
	fill(img, r, Color.WHITE)
	for y in range(r.position.y, r.end.y):
		for x in range(r.position.x, r.end.x, 2):
			if posmod(x + y, 22) < 6: fill(img, Rect2i(x, y, 2, 1), Color("e0574a"))

static func wainscot(img: Image, st: Dictionary, left: int, top: int, w: int, h: int) -> void:
	if st.has("wainsPattern"):
		tile(img,Rect2i(left,top,w,h),image(st.wainsPattern));return
	fill(img, Rect2i(left, top, w, h), col(st, "wains")); fill(img, Rect2i(left, top, w, 2), Color(1, 1, 1, 0.1))
	for k in range(0, w, 16): fill(img, Rect2i(left + k, top + 2, 2, h - 2), col(st, "line"))

static func back_wall(img: Image, m: Dictionary, c: Vector2i) -> void:
	var height:=MapModel.back_height(m,c)
	if height<=0:return
	var left := c.x * CP; var top := (c.y - height) * CP; var h := height * CP; var st := style(m, "back", c)
	if st.is_empty(): hatch(img, Rect2i(left, top - 12, CP, h + 12)); return
	if st.has("set"): # GPT pieces: ends where the wall run stops, middles (a/b) in between
		var run_left := MapModel.north_edge(m, c + Vector2i.LEFT); var run_right := MapModel.north_edge(m, c + Vector2i.RIGHT)
		var name := "back-left" if not run_left else ("back-right" if not run_right else variant(c, ["back-mid-a", "back-mid-b"]))
		var p := piece(st.set, name)
		if p != null:
			var visible:=mini(p.get_height(),h+12)
			img.blend_rect(p,Rect2i(0,p.get_height()-visible,p.get_width(),visible),Vector2i(left,c.y*CP-visible));return
	var wains := 54; var rail := 6
	if st.has("pattern"): tile(img, Rect2i(left, top, CP, h - wains), image(st.pattern))
	else: fill(img, Rect2i(left, top, CP, h - wains), col(st, "plaster"))
	fade(img, Rect2i(left, top, CP, h - wains), col(st, "shade"), 0.53, true, true)
	fill(img, Rect2i(left, top, CP, 12), col(st, "trim")); fill(img, Rect2i(left, top + 12, CP, 2), Color(1, 1, 1, 0.13))
	fill(img, Rect2i(left, top + h - wains - rail, CP, rail), col(st, "trim"))
	wainscot(img, st, left, top + h - wains, CP, wains)
	fill(img, Rect2i(left, top + h - 6, CP, 6), col(st, "cap")); fill(img, Rect2i(left, top - 12, CP, 12), col(st, "cap"))

static func inner_wall(img: Image, m: Dictionary, c: Vector2i) -> void:
	var st := style(m, "inner", c); var left := c.x * CP; var top := c.y * CP
	if st.is_empty(): hatch(img, Rect2i(left, top, CP, CP)); return
	if st.has("innerSet") and not MapModel.is_doorway(m,c):
		var horizontal:=MapModel.is_inner(m,c+Vector2i.LEFT) or MapModel.is_inner(m,c+Vector2i.RIGHT)
		var start:=c
		if horizontal:
			while MapModel.solid_inner(m,start+Vector2i.LEFT):start+=Vector2i.LEFT
		var name:="inner-h-"+str(posmod(c.x-start.x,3)) if horizontal else "inner-v-"+("top" if not MapModel.solid_inner(m,c+Vector2i.UP) else "bottom" if not MapModel.solid_inner(m,c+Vector2i.DOWN) else "mid")
		var p:=piece(st.innerSet,name)
		if p!=null:
			img.blend_rect(p,Rect2i(Vector2i.ZERO,p.get_size()),Vector2i(left,top+CP-p.get_height()))
			if (horizontal and not MapModel.solid_inner(m,c+Vector2i.RIGHT)) or (not horizontal and not MapModel.solid_inner(m,c+Vector2i.DOWN)):
				var post:=piece(st.innerSet,"post")
				if post!=null:img.blend_rect(post,Rect2i(Vector2i.ZERO,post.get_size()),Vector2i(left+(CP-post.get_width())/2,top+CP-post.get_height()))
			return
	if st.has("set"):
		var name := "inner-door" if MapModel.is_doorway(m, c) else ("inner-top" if MapModel.solid_inner(m, c + Vector2i.DOWN) else "inner-face")
		var p := piece(st.set, name)
		if p != null: img.blend_rect(p, Rect2i(Vector2i.ZERO, p.get_size()), Vector2i(left, top + CP - p.get_height())); return
	var horizontal := MapModel.is_inner(m, c + Vector2i.LEFT) or MapModel.is_inner(m, c + Vector2i.RIGHT)
	if MapModel.is_doorway(m, c): # posts and lintel; the floor shows through
		if horizontal:
			fill(img, Rect2i(left, top, 8, CP), col(st, "cap")); fill(img, Rect2i(left + CP - 8, top, 8, CP), col(st, "cap"))
			fill(img, Rect2i(left, top, CP, 12), col(st, "cap")); fill(img, Rect2i(left + 8, top + 12, CP - 16, 4), col(st, "trim"))
		else:
			fill(img, Rect2i(left, top, CP, 8), col(st, "cap")); fill(img, Rect2i(left, top + CP - 8, CP, 8), col(st, "cap"))
		return
	if MapModel.solid_inner(m, c + Vector2i.DOWN): # inside a north-south run: the wall top
		fill(img, Rect2i(left, top, CP, CP), col(st, "cap")); fill(img, Rect2i(left + 6, top, CP - 12, CP), Color(1, 1, 1, 0.08)); return
	fill(img, Rect2i(left, top, CP, 14), col(st, "cap"))
	if st.has("pattern"): tile(img, Rect2i(left, top + 14, CP, CP - 44), image(st.pattern))
	else: fill(img, Rect2i(left, top + 14, CP, CP - 44), col(st, "plaster"))
	fill(img, Rect2i(left, top + CP - 34, CP, 4), col(st, "trim"))
	wainscot(img, st, left, top + CP - 30, CP, 24); fill(img, Rect2i(left, top + CP - 6, CP, 6), col(st, "cap"))

static func opening_rect(o: Dictionary) -> Rect2i:
	var d: Dictionary = MapModel.OPENINGS[o.type]; var c: Dictionary = CROPS[o.type]; var cr: Array = c.crop
	var w := int(d.w) * CP; var k := float(w) / float(cr[2]); var h := int(round(cr[3] * k)); var left := int(o.x) * CP
	var top: int
	if d.wall == "back": top = int(o.y) * CP - h if d.get("door", false) else (int(o.y) - WALL_H) * CP + int(c.top)
	else: top = (int(o.y) + 1) * CP - int(round((float(c.floor_at) - cr[1]) * k))
	return Rect2i(left, top, w, h)

const SET_OPENINGS := {"back_door": "door-back", "front_door": "door-front", "window": "window", "sign": "sign", "lamp": "lamp"}
## The piece image of an opening on a map whose back wall comes from a set, and where it goes (or {}).
static func set_opening(m: Dictionary, o: Dictionary) -> Dictionary:
	var st := style(m, "back")
	var set_id:String=str(st.get("set",""))
	if str(m.walls.style.get("back",""))=="arcade-coast-rich" and o.type=="front_door":set_id="arcade-coast-rich"
	if set_id=="" or not SET_OPENINGS.has(o.type): return {}
	var p := piece(set_id, SET_OPENINGS[o.type])
	if p == null: return {}
	var d: Dictionary = MapModel.OPENINGS[o.type]; var span := int(d.w) * CP
	var left := int(o.x) * CP + (span - p.get_width()) / 2 # a piece narrower than the opening sits centred in it
	var top: int
	match o.type:
		"back_door": top = int(o.y) * CP - p.get_height()
		"front_door": top = (int(o.y) + 1) * CP + 44 - p.get_height() # bottom on the front wall's bottom
		"lamp": top = (int(o.y) - WALL_H) * CP + 8
		_: top = (int(o.y) - WALL_H) * CP + 50
	return {"image": p, "at": Vector2i(left, top)}
static func opening(img: Image, o: Dictionary) -> void:
	if not CROPS.has(o.type): return
	var cr: Array = CROPS[o.type].crop; var r := opening_rect(o)
	var part := image(SHOP).get_region(Rect2i(cr[0], cr[1], cr[2], cr[3]))
	part.resize(r.size.x, r.size.y, Image.INTERPOLATE_NEAREST)
	img.blend_rect(part, Rect2i(Vector2i.ZERO, r.size), r.position)

## Outdoor: ground, soft shade at hedges/fences, the edges themselves (inner layer), and ways in/out on top.
static func render_outdoor(m: Dictionary) -> Dictionary:
	var ground := blank(m); var inner := blank(m); var overlay := blank(m)
	var original:Image=null
	if m.has("editScene") and m.get("legacy",{}).has("definition"):
		original=imported_outdoor_ground(m)
		ground.blit_rect(original,Rect2i(Vector2i.ZERO,original.get_size()),Vector2i.ZERO)
		# The background owns scenery; editable original floor is cleared first,
		# including deleted cells, then repainted using the selected material.
		for points in m.legacy.get("floorPolygons",[]):
			var bounds:=Rect2(Vector2(points[0][0],points[0][1]),Vector2.ZERO)
			for p in points:bounds=bounds.expand(Vector2(p[0],p[1]))
			ground.fill_rect(Rect2i(bounds.position*2,bounds.size*2),Color.TRANSPARENT)
	for c in MapModel.floor_cells(m):
		if MapModel.tile_of(m,c)=="original-ground" and original!=null:
			ground.blit_rect(original,Rect2i(c*CP,Vector2i(CP,CP)),c*CP);continue
		var fl:Dictionary=floors(m).get(MapModel.tile_of(m,c),{})
		var path: String = fl.get("file", "")
		var span:=int(fl.get("span",1));var from:=Vector2i(posmod(c.x,span),posmod(c.y,span))*CP
		if path != "": ground.blit_rect(image(path), Rect2i(from,Vector2i(CP,CP)), c * CP)
		else: fill(ground, Rect2i(c * CP, Vector2i(CP, CP)), Color("9db64a"))
	var st: Dictionary = EDGES.get(str(m.walls.style.get("edge", "hedge")), EDGES.hedge)
	for p in m.walls.inner:
		var c := Vector2i(int(p[0]), int(p[1])); var r := Rect2i(c * CP, Vector2i(CP, CP))
		fade(ground, Rect2i(r.position + Vector2i(0, CP), Vector2i(CP, 18)), Color("1d2a12"), 0.35, true)
		if MapModel.is_doorway(m, c): # a gap: two posts
			fill(inner, Rect2i(r.position.x, r.position.y + 20, 10, 44), Color(str(st.face))); fill(inner, Rect2i(r.end.x - 10, r.position.y + 20, 10, 44), Color(str(st.face)))
			continue
		fill(inner, Rect2i(r.position.x, r.position.y + 8, CP, 32), Color(str(st.top)))
		fill(inner, Rect2i(r.position.x, r.position.y + 40, CP, 24), Color(str(st.face)))
		fill(inner, Rect2i(r.position.x, r.position.y + 60, CP, 4), Color(str(st.dark)))
		if st == EDGES["fence-wood"]:
			for k in range(4, CP, 16): fill(inner, Rect2i(r.position.x + k, r.position.y + 8, 6, 56), Color(str(st.top)).lightened(0.1))
	for o in m.openings:
		var d: Dictionary = MapModel.OPENINGS.get(o.type, {})
		for c in MapModel.opening_cells(o):
			var r := Rect2i(c * CP, Vector2i(CP, CP))
			if d.get("wall") == "edge": # the path runs on off the map: a darker trodden patch and an arrow toward the edge
				fill(overlay, r.grow(-6), Color("b39b6c", 0.55))
				var dir: Vector2i = {"N": Vector2i.UP, "S": Vector2i.DOWN, "W": Vector2i.LEFT, "E": Vector2i.RIGHT}.get(str(o.get("side", "S")), Vector2i.DOWN)
				var mid := r.get_center()
				for k in 3: fill(overlay, Rect2i(mid + dir * (k * 8 - 8) - Vector2i(4, 4), Vector2i(8, 8)), Color("fff4dc", 0.9 - k * 0.25))
			else: # building entrance: doorstep and mat
				fill(overlay, Rect2i(r.position + Vector2i(2, 34), Vector2i(CP - 4, 26)), Color("8f6239"))
				fill(overlay, Rect2i(r.position + Vector2i(8, 40), Vector2i(CP - 16, 14)), Color("365a80"))
	return {"ground": ground, "inner": inner, "overlay": overlay}

## Existing parks keep painted rivers, planted borders and registered branch
## paths. Floor cells can still be removed or painted with another material.
static func imported_outdoor_ground(m:Dictionary)->Image:
	var spec:Dictionary=m.legacy.definition.manifest.ground
	var original:=image("res://assets/baked/"+str(spec.file)).duplicate() as Image
	for patch in spec.get("patches",[]):
		var source:=image("res://assets/baked/"+str(patch.file))
		var xs:Array=patch.registration.x;var ys:Array=patch.registration.y
		for ix in range(xs.size()-1):
			for iy in range(ys.size()-1):
				var cut:=source.get_region(Rect2i(xs[ix][0],ys[iy][0],xs[ix+1][0]-xs[ix][0],ys[iy+1][0]-ys[iy][0]))
				cut.resize(roundi((xs[ix+1][1]-xs[ix][1])*2),roundi((ys[iy+1][1]-ys[iy][1])*2),Image.INTERPOLATE_NEAREST)
				original.blend_rect(cut,Rect2i(Vector2i.ZERO,cut.get_size()),Vector2i(xs[ix][1]*2,ys[iy][1]*2))
	return original

## Woven edging belongs to the floor surface, never to collision or furniture.
## Compare material IDs rather than palette letters: joins within one carpet stay invisible.
static func floor_material(m:Dictionary,c:Vector2i)->String:
	return str(m.floor.palette.get(MapModel.floor_char(m,c),"")) if MapModel.is_floor(m,c) else ""

static func carpet_binding(img:Image,m:Dictionary)->void:
	for cell in MapModel.floor_cells(m):
		var material:=floor_material(m,cell)
		if not floors(m).get(material,{}).get("binding",false):continue
		var outside:Array[Vector2i]=[]
		for dy in range(-1,2):
			for dx in range(-1,2):
				if dx==0 and dy==0:continue
				if floor_material(m,cell+Vector2i(dx,dy))!=material:outside.append(Vector2i(dx,dy))
		if outside.is_empty():continue
		for y in CP:
			for x in CP:
				var distance:=CP
				for offset in outside:
					var dx:=x+1 if offset.x<0 else CP-x if offset.x>0 else 0
					var dy:=y+1 if offset.y<0 else CP-y if offset.y>0 else 0
					distance=mini(distance,maxi(dx,dy))
				if distance>12:continue
				var color:=Color("102c35")
				if distance in [3,4]:color=Color("b38b52")
				elif distance in [5,6]:color=Color("dec28b")
				elif distance in [7,8,9]:color=Color("35606a")
				elif distance in [10,11]:color=Color("a38552") if posmod(cell.x*CP+x+cell.y*CP+y,8)<4 else Color("1d424b")
				img.set_pixelv(cell*CP+Vector2i(x,y),color)

static func render(m: Dictionary) -> Dictionary:
	if MapModel.outdoor(m): return render_outdoor(m)
	var ground := blank(m); var inner := blank(m); var overlay := blank(m); var s := MapModel.size_of(m)
	var shadow := Color("2a1810")
	for c in MapModel.floor_cells(m):
		var fl: Dictionary = floors(m).get(m.floor.palette.get(MapModel.floor_char(m, c), ""), {})
		var path: String = fl.get("file", "")
		if fl.has("set"): path = SET_DIR % [fl.set, variant(c, ["floor-a", "floor-b", "floor-c", "floor-d"].filter(func(n): return ResourceLoader.exists(SET_DIR % [fl.set, n])))]
		var span := int(fl.get("span", 1)) # a tile bigger than one cell: each cell takes its part of it
		var from := Vector2i(posmod(c.x, span), posmod(c.y, span)) * CP
		if path != "": ground.blit_rect(image(path), Rect2i(from, Vector2i(CP, CP)), c * CP)
		else: fill(ground, Rect2i(c * CP, Vector2i(CP, CP)), Color("d8c0a0"))
	carpet_binding(ground, m)
	for o in m.openings: # outside the front doors: a strip of pavement shows through the glass
		if o.type == "front_door":
			for dx in int(MapModel.OPENINGS[o.type].w): ground.blit_rect(image(FLOORS["ground-path"].file), Rect2i(0, 0, CP, CP), Vector2i((int(o.x) + dx) * CP, (int(o.y) + 1) * CP))
	for c in MapModel.floor_cells(m): # soft shadows along walls: what makes it read as a room, not a grid
		if MapModel.solid_inner(m, c): continue
		if MapModel.north_edge(m, c) or MapModel.solid_inner(m, c + Vector2i.UP): fade(ground, Rect2i(c.x * CP, c.y * CP, CP, 46), shadow, 0.3, true)
		if not MapModel.is_floor(m, c + Vector2i.LEFT) or MapModel.solid_inner(m, c + Vector2i.LEFT): fade(ground, Rect2i(c.x * CP, c.y * CP, 22, CP), shadow, 0.22, false)
		if not MapModel.is_floor(m, c + Vector2i.RIGHT) or MapModel.solid_inner(m, c + Vector2i.RIGHT): fade(ground, Rect2i((c.x + 1) * CP - 22, c.y * CP, 22, CP), shadow, 0.22, false, true)
	for o in m.openings: # lamp glow on the floor, in 16 px blocks
		if not MapModel.OPENINGS.get(o.type, {}).get("light", false): continue
		var centre := Vector2((float(o.x) + MapModel.OPENINGS[o.type].w / 2.0) * CP, float(o.y) * CP + 90)
		for c in MapModel.floor_cells(m):
			for by in range(0, CP, 16):
				for bx in range(0, CP, 16):
					var p := Vector2(c * CP + Vector2i(bx + 8, by + 8)); var dist := p.distance_to(centre)
					if dist < 300: fill(ground, Rect2i(c * CP + Vector2i(bx, by), Vector2i(16, 16)), Color("ffe2a8", 0.22 * (1.0 - dist / 300.0)))
	for c in MapModel.floor_cells(m):
		if MapModel.north_edge(m, c): back_wall(ground, m, c)
	for o in m.openings:
		if MapModel.OPENINGS.get(o.type, {}).get("wall") != "back": continue
		var sp := set_opening(m, o)
		if sp.is_empty(): opening(ground, o)
		else: ground.blend_rect(sp.image, Rect2i(Vector2i.ZERO, sp.image.get_size()), sp.at)
	for decoration in m.get("decor",[]):
		var file:String=str(decoration.get("file",""))
		if not file.begins_with("res://assets/map-pieces/") or not ResourceLoader.exists(file):continue
		var art:=image(file)
		ground.blend_rect(art,Rect2i(Vector2i.ZERO,art.get_size()),Vector2i(Vector2(decoration.x,decoration.y)*CP))
	for p in m.walls.inner: inner_wall(inner, m, Vector2i(int(p[0]), int(p[1])))
	# side walls: thin strips along the left/right floor edge, from the back wall top to just below the front edge
	for c in MapModel.floor_cells(m):
		var side:=style(m,"side",c);var T:=40 if side.has("set") else 20
		for dir in [-1, 1]:
			if MapModel.is_floor(m, c + Vector2i(dir, 0)): continue
			var top := c.y * CP; var bottom := (c.y + 1) * CP
			if MapModel.north_edge(m, c): top = (c.y - MapModel.back_height(m,c)) * CP - 12
			if MapModel.south_edge(m, c): bottom = (c.y + 1) * CP + 30
			var left := c.x * CP - T if dir < 0 else (c.x + 1) * CP
			var r := Rect2i(left, top, T, bottom - top)
			if side.is_empty(): hatch(overlay, r); continue
			if side.has("set"):
				var p := piece(side.set, "side-left" if dir < 0 else "side-right")
				if p != null:
					var px := c.x * CP - p.get_width() if dir < 0 else (c.x + 1) * CP
					for y in range(top, bottom, p.get_height()): overlay.blend_rect(p, Rect2i(0, 0, p.get_width(), mini(p.get_height(), bottom - y)), Vector2i(px, y))
					continue
			fill(overlay, r, col(side, "side"))
			fill(overlay, Rect2i(left if dir < 0 else left + 13, top, 7, r.size.y), col(side, "cap"))
			fade(overlay, Rect2i(left + 7 if dir < 0 else left, top, 13, r.size.y), col(side, "shade"), 0.9, false, dir < 0)
	var skip := {}
	for o in m.openings:
		var d: Dictionary = MapModel.OPENINGS.get(o.type, {})
		if d.get("wall") == "front":
			for dx in int(d.w): skip[Vector2i(int(o.x) + dx, int(o.y))] = true
	for c in MapModel.floor_cells(m):
		if not MapModel.south_edge(m, c) or skip.has(c): continue
		var front:=style(m,"front",c)
		var left := c.x * CP; var top := (c.y + 1) * CP - 10; var h := 40
		if front.is_empty(): hatch(overlay, Rect2i(left, top, CP, h)); continue
		if front.has("set"):
			var l_end := not MapModel.south_edge(m, c + Vector2i.LEFT) or skip.has(c + Vector2i.LEFT)
			var r_end := not MapModel.south_edge(m, c + Vector2i.RIGHT) or skip.has(c + Vector2i.RIGHT)
			var p := piece(front.set, "front-left" if l_end else ("front-right" if r_end else "front-mid"))
			if p != null: overlay.blend_rect(p, Rect2i(Vector2i.ZERO, p.get_size()), Vector2i(left, (c.y + 1) * CP - 36)); continue # half over the floor, like the current front walls
		fill(overlay, Rect2i(left, top, CP, 7), col(front, "cap")); wainscot(overlay, front, left, top + 7, CP, h - 13)
		fill(overlay, Rect2i(left, top + h - 6, CP, 6), col(front, "cap"))
	for o in m.openings:
		if MapModel.OPENINGS.get(o.type, {}).get("wall") != "front": continue
		var sp := set_opening(m, o)
		if sp.is_empty(): opening(overlay, o)
		else: overlay.blend_rect(sp.image, Rect2i(Vector2i.ZERO, sp.image.get_size()), sp.at)
	# Remodeling owns the house, not its attached seaside path and scenery.
	# Erase the old architectural silhouette before compositing the new building,
	# so removing floor cannot reveal an obsolete floor underneath it.
	if m.get("editScene","")=="xiaojingyu-home":
		var legacy:Dictionary=m.legacy
		var old:Dictionary=legacy.definition.manifest.ground
		var exterior:=image("res://assets/baked/"+str(old.file)).duplicate() as Image
		for points in legacy.floorPolygons:
			var bounds:=Rect2(Vector2(points[0][0],points[0][1]),Vector2.ZERO)
			for p in points:bounds=bounds.expand(Vector2(p[0],p[1]))
			bounds=bounds.grow_individual(24,96,24,32)
			exterior.fill_rect(Rect2i(bounds.position*2,bounds.size*2),Color.TRANSPARENT)
		var combined:=blank(m)
		var at:Array=m.get("gridOrigin",legacy.get("gridOrigin",[0,0]))
		combined.blit_rect(exterior,Rect2i(Vector2i.ZERO,exterior.get_size()),Vector2i((float(old.x)-float(at[0]))*2,(float(old.y)-float(at[1]))*2))
		combined.blend_rect(ground,Rect2i(Vector2i.ZERO,ground.get_size()),Vector2i.ZERO)
		ground=combined
	return {"ground": ground, "inner": inner, "overlay": overlay}

## One flat picture of the whole room (ground, then interior walls, then the overlay): for previews and screenshots.
## Each interior row sorts with people at its ground baseline, so a foreground
## person is not painted over by a lantern on a wall behind them.
static func inner_stripes(m:Dictionary)->Array:
	var rows:Dictionary={};var result:=[]
	for p in m.walls.inner:rows[int(p[1])]=true
	for y in rows:
		var layer:=blank(m)
		for p in m.walls.inner:
			if int(p[1])==y:inner_wall(layer,m,Vector2i(int(p[0]),y))
		var box:=layer.get_used_rect()
		if box.has_area():result.append({"image":layer.get_region(box),"at":box.position,"row":y,"depth":(y+1)*MapModel.Grid.CELL})
	return result

static func flat(m: Dictionary, background := Color("2f3b39")) -> Image:
	var r := render(m); var out := blank(m); out.fill(background)
	for k in ["ground", "inner", "overlay"]: out.blend_rect(r[k], Rect2i(Vector2i.ZERO, out.get_size()), Vector2i.ZERO)
	return out
