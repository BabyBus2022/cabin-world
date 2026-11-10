class_name Hud
extends Control
## The whole interface, on a 2-pixel grid in the room art's palette: wood, navy waves, cream paper, sakura.

signal scene_picked(id: String)
signal settings_picked()
signal home_editor_picked()
signal character_picked(index: int)
signal follow_picked(index: int)
signal room_clicked(at: Vector2)

const U := 2.0
const TAB_NAMES := {"qianxia-home": "芊夏家", "qianxia-park": "公园", "qianxia-shop": "小卖部", "xiaojingyu-home": "小鲸鱼家", "world-arcade": "电玩城", "world-onsen": "汤屋", "world-restaurant": "餐厅"}
const WOOD_D := Color("3b2416")
const WOOD := Color("7a4a26")
const WOOD_L := Color("a96f3b")
const WOOD_H := Color("d29a5c")
const WOOD_S := Color("5a341b")
const PAPER := Color("f6e6c8")
const PAPER_D := Color("e2c99f")
const PAPER_H := Color("fff4dc")
const INK := Color("3a2a20")
const INK2 := Color("6e5a48")
const GRASS := Color("7f9a3a")
const GRASS_L := Color("9db64a")
const GRASS_D := Color("55702a")
const DIRT := Color("6b4a2c")
const GOLD := Color("e0b24a")
const CREAM := Color("fdf3dd")
const PINK := Color("f5b7c5")
const RED := Color("c4563f")
const GREEN := Color("8fd6a8")
const AMBER := Color("f0a64a")

const ICONS := {
	"world-restaurant": [["........", ".w.w.w..", ".wwwww..", "..www...", ".bbbbbb.", "bbbbbbbb", ".bbbbbb.", "..cccc.."], {"w":"fff4dc","b":"d57947","c":"e2c99f"}],
	"qianxia-home": [["...rr...", "..rrrr..", ".rrrrrr.", "rrrrrrrr", ".cccccc.", ".cbbcgc.", ".cbbccc.", ".cbbccc."], {"r": "c4563f", "c": "f2dcb2", "b": "6a4023", "g": "7fb6d6"}],
	"qianxia-park": [["..pppp..", ".ppqppp.", "pppppqpp", "ppqppppp", ".pppqpp.", "...tt...", "...tt...", "..tttt.."], {"p": "f5b7c5", "q": "e98ea6", "t": "6a4023"}],
	"qianxia-shop": [["rcrcrcrc", "rcrcrcrc", ".wwwwww.", ".wbbwgw.", ".wbbwgw.", ".wbbwww.", ".wbbwww.", "wwwwwwww"], {"r": "d7584a", "c": "fff4dc", "w": "f2dcb2", "b": "37508c", "g": "7fb6d6"}],
	"xiaojingyu-home": [["......b.", "b...bb.b", "bb.bbbb.", ".bbbbbbb", ".bbbwbbb", "..wwwwww", "...wwww.", "........"], {"b": "4f7fc9", "w": "e6f1fb"}],
	"world-arcade": [["........", ".gggggg.", "ggwggggg", "gwwwgrgg", "ggwggygg", "gggggggg", "gg....gg", "........"], {"g": "8a63c6", "w": "fff4dc", "r": "e0584a", "y": "f2c94c"}],
	"world-onsen": [[".w..w..w", "..w..w..", ".w..w..w", "..w..w..", "b......b", "bbbbbbbb", ".bbbbbb.", "..bbbb.."], {"w": "d6e6f2", "b": "2e6f9e"}],
}
const SUN := [["...y....", ".y.y..y.", "..yyyy..", ".yyyyyy.", "yyyyyyyy", ".yyyyyy.", "..yyyy..", ".y.y..y."], {"y": "e89a2a"}]
const MOON := [["..mmm...", ".mmm....", "mmm.....", "mmm.....", "mmm.....", "mmmm...m", ".mmmmmm.", "..mmmm.."], {"m": "37508c"}]
const PIN := [[".rrr.", "rrwrr", "rrrrr", ".rrr.", "..r.."], {"r": "c4563f", "w": "fff4dc"}]
const LANTERN_ROWS := ["..dd..", ".wwww.", "wggggw", "wgyygw", "wgyygw", "wggggw", ".wwww.", "..dd.."]

const DECOR := {
	"lamp": ["qianxia-park.lamp-west.png", 14.0, 44.0], "plant": ["xiaojingyu-home.xj-plant-west.png", 38.5, 49.0], "whale": ["qianxia-park.rider.png", 66.0, 66.0], "plant2": ["xiaojingyu-home.xj-plant-west.png", 38.0, 49.0],
	"rabbit": ["xiaojingyu-home.xj-rabbit.png", 18.0, 23.0], "rabbit2": ["xiaojingyu-home.xj-rabbit.png", 18.0, 23.0], "shelfplant": ["xiaojingyu-home.xj-plant-shelf.png", 24.0, 31.0],
}

var view_scene := ""
var follow := 0
var characters: Array[Character] = []
var frame_rect := Rect2()
var card_rects: Array[Rect2] = []
var decor_area := Rect2()
var tabs_bottom := 58.0
var grass_height := 28.0

var _hits: Array = []
var _mouse := Vector2(-1, -1)
var _font: SystemFont
var _bold: SystemFont
var _decor := {}
var _weather: WeatherBadge


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_STOP
	_font = SystemFont.new()
	_font.font_names = PackedStringArray(["Microsoft YaHei UI", "Microsoft YaHei", "SimHei"])
	_bold = SystemFont.new()
	_bold.font_names = _font.font_names
	_bold.font_weight = 700
	for k in DECOR:
		var file: String = "res://assets/baked/" + DECOR[k][0]
		if ResourceLoader.exists(file): _decor[k] = load(file)
	_weather = WeatherBadge.new()
	add_child(_weather)
	var refresh := Timer.new()
	refresh.wait_time = 0.25
	refresh.autostart = true
	refresh.timeout.connect(queue_redraw)
	add_child(refresh)


func _gui_input(event: InputEvent) -> void:
	if event is InputEventMouseMotion:
		# A tooltip belongs to the current hover, never the last navigation item.
		tooltip_text = ""
		_mouse = event.position
		var hot := false
		for h in _hits:
			hot = hot or h[0].has_point(_mouse)
		mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND if hot else Control.CURSOR_ARROW
		queue_redraw()
	elif event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT and not event.pressed:
		for h in _hits:
			if h[0].has_point(event.position):
				if h[1] >= 0:
					if h[2] == "@follow": follow_picked.emit(h[1])
					else: character_picked.emit(h[1])
				elif h[2] == "@settings":
					settings_picked.emit()
				elif h[2] == "@home-editor":
					home_editor_picked.emit()
				else:
					scene_picked.emit(h[2])
				return
		if frame_rect.has_point(event.position):
			room_clicked.emit(event.position - frame_rect.position)


func _notification(what: int) -> void:
	if what == NOTIFICATION_MOUSE_EXIT:
		tooltip_text = ""
		_mouse = Vector2(-1, -1)
		queue_redraw()


func _box(x: float, y: float, w: float, h: float, c: Color) -> void:
	draw_rect(Rect2(x, y, w, h), c)


func _notched(x: float, y: float, w: float, h: float, c: Color, n := U) -> void:
	_box(x + n, y, w - 2 * n, h, c)
	_box(x, y + n, w, h - 2 * n, c)


func _wood(x: float, y: float, w: float, h: float, band := 3 * U) -> void:
	_notched(x, y, w, h, WOOD_D)
	_notched(x + U, y + U, w - 2 * U, h - 2 * U, WOOD)
	_box(x + 2 * U, y + U, w - 4 * U, U, WOOD_H)
	_box(x + U, y + 2 * U, U, h - 4 * U, WOOD_L)
	_box(x + 2 * U, y + h - 2 * U, w - 4 * U, U, WOOD_S)
	_box(x + band, y + band, w - 2 * band, h - 2 * band, WOOD_D)
	for p in [Vector2(x + U * 1.5, y + U * 1.5), Vector2(x + w - U * 2.5, y + U * 1.5), Vector2(x + U * 1.5, y + h - U * 2.5), Vector2(x + w - U * 2.5, y + h - U * 2.5)]:
		_box(p.x, p.y, U, U, GOLD)


func _paper(x: float, y: float, w: float, h: float, lit := false) -> void:
	_wood(x, y, w, h)
	_box(x + 4 * U, y + 4 * U, w - 8 * U, h - 8 * U, PAPER_H if lit else PAPER)
	_box(x + 4 * U, y + h - 5 * U, w - 8 * U, U, PAPER_D)
	_box(x + w - 5 * U, y + 4 * U, U, h - 8 * U, PAPER_D)


func _icon(def: Array, x: float, y: float) -> void:
	var rows: Array = def[0]
	var pal: Dictionary = def[1]
	for r in rows.size():
		var line: String = rows[r]
		for i in line.length():
			var ch := line[i]
			if ch != ".":
				_box(x + i * U, y + r * U, U, U, Color(pal[ch]))


func _text(s: String, x: float, baseline: float, width: float, size: int, c: Color, font: Font = null, center := false) -> void:
	draw_string(font if font else _font, Vector2(x, baseline), s, HORIZONTAL_ALIGNMENT_CENTER if center else HORIZONTAL_ALIGNMENT_LEFT, width, size, c)


func _draw() -> void:
	_hits.clear()
	var W := size.x
	var H := size.y
	_draw_beam_and_tabs(W)
	_wood(frame_rect.position.x - 4 * U, frame_rect.position.y - 4 * U, frame_rect.size.x + 8 * U, frame_rect.size.y + 8 * U)
	for i in card_rects.size():
		var r := card_rects[i]
		_draw_card(i, r.position.x, r.position.y, r.size.x, r.size.y)
	if decor_area.size.y > 0.0:
		_draw_decor(decor_area.position.x, decor_area.position.y, decor_area.size.x, decor_area.end.y)

func _draw_beam_and_tabs(W: float) -> void:
	var beam := 7 * U
	_box(0, 0, W, beam, WOOD_D)
	_box(0, 0, W, beam - U, WOOD)
	_box(0, U, W, U, WOOD_H)
	var i := 0
	while i * 37 * U < W:
		_box(i * 37 * U + 4 * U, 3 * U, 11 * U, U, WOOD_L)
		i += 1
	var x := 12.0
	if W >= 1040.0:
		_paper(x, 11, 118, 40)
		_text("小屋世界", x + 4, 37, 110, 15, INK, _bold, true)
		_box(x + 20, beam, U, 11 - beam, WOOD_D)
		_box(x + 96, beam, U, 11 - beam, WOOD_D)
		x += 132.0
	for entry in navigation_layout(W):
		var id: String = entry.id
		var name_of: String = entry.label
		var area: Rect2 = entry.area
		x = area.position.x
		var w := area.size.x
		var y := area.position.y + (3.0 if area.has_point(_mouse) else 1.0)
		var on: bool = view_scene == id
		_notched(x, y, w, 38, WOOD_D)
		_notched(x + U, y + U, w - 2 * U, 38 - 2 * U, PAPER if on else WOOD)
		_box(x + 2 * U, y + U, w - 4 * U, U, PAPER_H if on else WOOD_H)
		_box(x + 2 * U, y + 38 - 2 * U, w - 4 * U, U, PAPER_D if on else WOOD_S)
		if id == "@settings":
			_icon([["..wwww..", ".ww..ww.", "ww.ww.ww", "w.w..w.w", "w.w..w.w", "ww.ww.ww", ".ww..ww.", "..wwww.."], {"w":"fdf3dd"}], x+6, y+11)
		elif id == "@home-editor":
			_icon([["ww....ww","ww....ww","wwwwwwww","wwwwwwww","..wwww..","..wwww..","..w..w..","..w..w.."],{"w":"fdf3dd"}],x+6,y+11)
		else: _icon(ICONS.get(id,ICONS["qianxia-home"]), x + 3 * U, y + 11)
		_text(name_of, x + 27, y + 25, w-27, 14, INK if on else CREAM)
		_hits.append([area, -1, id])
		var present := occupants(id)
		for j in present.size():
			var index: int = present[j]
			var portrait := Rect2(area.end.x-8-(present.size()-j)*24,y+7,24,24)
			_draw_avatar(characters[index],portrait)
		if area.has_point(_mouse):
			tooltip_text = name_of + (" · " + "、".join(PackedStringArray(present.map(func(k): return characters[k].display_name))) if not present.is_empty() else "")
	_weather.position = Vector2(W-422,8)
	_weather.size = Vector2(410,46)

## Settings follows the supplied room list, including rooms added in the future.
func navigation_layout(width: float, order: Array = []) -> Array:
	var result := []
	var x := 144.0 if width >= 1040 else 12.0
	var y := 10.0
	var limit := width-438.0
	var ids := WorldData.available_order() if order.is_empty() else order.duplicate()
	ids.append("@settings")
	for id in ids:
		var label := "布置家具 F6" if id=="@home-editor" else "设置" if id=="@settings" else str(TAB_NAMES.get(id,WorldData.scenes.get(id,{}).get("name",id)))
		var w := 48.0+label.length()*14.0+(0.0 if str(id).begins_with("@") else maxf(2,characters.size())*24.0)
		if x+w>limit and x>12:
			x = 12
			y += 46
		result.append({"id":id,"label":label,"area":Rect2(x,y,w,42)})
		x += w+8
	tabs_bottom = y+48
	return result

func occupants(id: String) -> Array:
	var present := []
	for i in characters.size():
		if characters[i].placed and characters[i].scene_id == id: present.append(i)
	return present

func _draw_avatar(c: Character, area: Rect2) -> void:
	draw_circle(area.get_center(),13,PAPER_D)
	var f := c.portrait_frame()
	var r: Array = f.rect
	var anchor: Array = f.anchor
	var source := Rect2(float(r[0])+float(anchor[0])-92.5,float(r[1])+float(anchor[1])-278.0,185,185)
	draw_texture_rect_region(f.texture,area,source)


func _draw_card(index: int, x: float, y: float, w: float, h: float) -> void:
	if index >= characters.size():
		return
	var c: Character = characters[index]
	var area := Rect2(x, y, w, h)
	_paper(x, y, w, h, area.has_point(_mouse))
	var ps := h - 12 * U
	var px := x + 6 * U
	var py := y + 6 * U
	_notched(px - U, py - U, ps + 2 * U, ps + 2 * U, WOOD_D)
	_box(px, py, ps, ps, Color("232f55") if index == 0 else Color("6f9ed8"))
	_box(px, py + ps - 3 * U, ps, 3 * U, Color("1f2a4d") if index == 0 else Color("5586c0"))
	var f := c.portrait_frame()
	var r: Array = f["rect"]
	var an: Array = f["anchor"]
	# The head and shoulders of her standing frame.
	var src := Rect2(float(r[0]) + float(an[0]) - 92.5, float(r[1]) + float(an[1]) - 278.0, 185.0, 185.0)
	var tint := Color(1, 1, 1, 0.55) if c.sleeping else Color.WHITE
	draw_texture_rect_region(f["texture"], Rect2(px, py, ps, ps), src, tint)
	var tx := px + ps + 5 * U
	var tw := x + w - tx - 5 * U
	_text(c.display_name, tx, y + 5 * U + 18, tw, 17, INK, _bold)
	# Only this explicit button toggles follow. The rest of the card selects a view.
	var following := follow == index
	var tag_w := 58.0 if following else 44.0
	var fx := x + w - 5 * U - tag_w
	var fy := y + 5 * U + 1
	_box(fx, fy, tag_w, 20, RED if following else PAPER_D)
	_box(fx, fy + 18, tag_w, 2, Color("8f3a2a") if following else WOOD_L)
	_text("跟随中" if following else "跟随", fx, fy + 15, tag_w, 13, CREAM if following else INK2, _bold, true)
	_hits.append([Rect2(fx, fy, tag_w, 20), index, "@follow"])
	_hits.append([area, index, ""])
	var ly := y + 5 * U + 28
	_icon(PIN, tx, ly + 3)
	var where: String = "还没有数据"
	if c.placed:
		where = str(WorldData.scenes[c.scene_id]["name"]) + ("·走动中" if c.is_walking() else "")
	_text(where, tx + 14, ly + 15, tw - 14, 14, INK)
	# Pocket money and mood: from the game's own save when it has moved here, otherwise as VADS reports them.
	var saved: Dictionary = Economy.people.get(c.key, {})
	var purse = saved.get("wallet")
	var money = purse["coins"] if purse is Dictionary else c.coins
	var word := c.mood_word
	if saved.has("feeling") or saved.has("life"):
		var at: float = SharedFeed.now_ms()
		word = str(Life.mood_of(c.art, Life.feeling_now(saved.get("feeling"), at), saved.get("life"), {}, at, c.sleeping)["word"])
	var parts := PackedStringArray()
	if money != null:
		parts.append("零花钱 %d" % int(money))
	if word != "":
		parts.append(word)
	if not parts.is_empty():
		_text(" · ".join(parts), tx, y + h - 5 * U - 3, tw, 12, INK2)
	_box(tx, ly + 22, tw, 2, PAPER_D)
	var doing: String = c.action_label if c.action_label != "" else ("正在睡觉" if c.sleeping else (c.label if c.label != "" else c.place))
	draw_multiline_string(_font, Vector2(tx, ly + 42), doing, HORIZONTAL_ALIGNMENT_LEFT, tw, 13, 2, INK2)


func _stand(key: String, x: float, base: float, k := 1.5) -> void:
	if not _decor.has(key): return
	var d: Array = DECOR[key]
	var dw: float = float(d[1]) * k
	var dh: float = float(d[2]) * k
	draw_texture_rect(_decor[key], Rect2(x, base - dh, dw, dh), false)


func _draw_decor(x: float, top: float, w: float, ground: float) -> void:
	if ground - top < 90.0:
		return
	if ground - top >= 240.0:
		var sy := ground - 130.0
		_box(x + 14, sy, w - 40, 3 * U, WOOD_D)
		_box(x + 14, sy, w - 40, U, WOOD_H)
		_box(x + 14 + 2 * U, sy + 3 * U, w - 40 - 4 * U, U, WOOD)
		for bx in [x + 30, x + w - 56]:
			_box(bx, sy + 3 * U, 2 * U, 6 * U, WOOD_D)
			_box(bx, sy + 9 * U, 6 * U, U, WOOD_D)
		_stand("rabbit", x + 26, sy)
		_stand("tea", x + 72, sy + 2)
		_stand("rabbit2", x + 158, sy)
		_stand("shelfplant", x + 198, sy)
	_stand("lamp", x + 4, ground)
	_stand("plant", x + 34, ground + 4)
	_stand("whale", x + 104, ground + 4)
	_stand("plant2", x + w - 74, ground + 4)
