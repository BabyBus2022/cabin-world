extends Control
## Cabin World MAP editor (docs/MAP-EDITOR-DESIGN.md phase 3; replaces the old roomkit editor, owner D4/D5).
## Redesigned 2026-11-11 after the owner found the first version hard to use and short on guidance:
##  - a step bar (1 参考图 · 2 铺地板 · 3 墙 · 4 门窗 · 5 检查): done steps ticked, locked steps say what unlocks them;
##  - a guide panel per step: what the step is for, numbered how-to, tool tiles that say what they do, swatches;
##  - hints on the map: a label at the mouse saying what a click / release will do, a status line, an empty-map prompt;
##  - "这一步还差": only this step's rules, each with a tip, and a 下一步 button;
##  - 使用说明 (shown the first time) and 快速开始 room shapes, so nobody starts from an empty grid.
## Rules: core/map_model.gd. Drawing: core/map_render.gd. AI / scripted edits: core/map_commands.gd (docs/MAP-AI-COMMANDS.md).
## Saves only to its own folder (user://maps/<id>/map.json, or --maps-dir <dir>), keeping a .bak. Changes no game room.
## If the open map's file is changed by something else (an AI using the command tool) and there are no unsaved edits
## here, the editor reloads it and says so.
## Opened from Settings (embedded=true, emits exit_requested) or standalone with `-- --map-editor [--maps-dir <dir>]`.
## The first roomkit-era editor is kept in handover/map-phase3-20261111/before/map_editor.gd.

signal exit_requested()
const M := preload("res://core/map_model.gd")
const R := preload("res://core/map_render.gd")
const Design := preload("res://core/map_design.gd")
const RoomMaps=preload("res://core/room_maps.gd")
const STEPS := ["template", "floor", "walls", "openings", "links", "check"]
## Indoor and outdoor maps share the steps; names, texts and tools differ (outdoor: no walls, owner 2026-11-11).
const STEP_NAMES := {"template":"参考图", "floor":"铺地板", "walls":"墙", "openings":"门窗", "links":"连接", "check":"检查"}
const OUT_NAMES := {"floor":"铺地面", "walls":"篱笆", "openings":"出入口"}
const STEP_INTRO := {
	"template":"可以先放一张草图（比如让 GPT 画一张），编辑器按颜色帮你找出地面。没有草图就直接跳过。",
	"floor":"先决定房间的形状。墙会沿着地板边自动长出来，所以这一步只管地面。",
	"walls":"外墙已经沿地板边长好了，只要选样式。想把房间分成几间，就画内墙，再开门洞让人走过去。",
	"openings":"把门和窗放到墙上。至少要一扇门，人才走得进来。",
	"links":"每扇门、每个路口都通到另一张地图。在这里选它通到哪里、走过去后出现在哪里，地图之间就连起来了。",
	"check":"所有规则都通过，这张地图就能用了。点一条规则，地图上会标出问题格。",
}
const OUT_INTRO := {
	"floor":"室外地图没有墙。用草地、小路、沙地铺满地面；小路最好一直通到地图边，那里就是去别处的路口。水不能走。",
	"walls":"可选：用树篱或木栅栏围出边界、隔出区域，再开个口子让人过去。",
	"openings":"放出入口：「路口」贴着地图边，是小路通往别的地图的地方；「建筑入口」放在地面上，是走进一栋房子的门。",
}
const STEP_HOW := {
	"template":["点「选一张参考图」，图会铺满整张地图", "拖动滑块调透明度，方便对照", "选一种地面，再点「识别地板」"],
	"floor":["选「矩形」，在地图上按住左键拖出一块", "要换材质：先选材质，再用「填充」点一下那块地", "右键拖动可以擦掉"],
	"walls":["给后墙、侧墙、前墙各选一种样式（或点「三面同样」）", "选「画内墙」，在地板上拖出一道墙", "选「开门洞」，点一下内墙打开通道"],
	"openings":["在下面选一种门窗", "把鼠标移到墙上：绿色能放，红色放不下", "左键放置，右键移除"],
	"links":["每一行是一扇门或一个路口", "选它通到哪张地图", "再选到那边后站在哪个入口"],
	"check":["红色的规则还没通过，点它看问题在哪", "打开「预览」看成品效果", "满意就点「保存」"],
}
const OUT_HOW := {
	"floor":["先选「草地」，用「矩形」铺满整张地图", "再选「小路」，用画笔画出路，一直画到地图边", "水、沙地按需要加；右键擦掉"],
	"walls":["选树篱或木栅栏", "选「画篱笆」，在地面上拖动", "选「开口子」，点一下篱笆让人过去"],
	"openings":["选「路口」，点在地图边的小路上", "选「建筑入口」，点在房子门口的地面上", "左键放置，右键移除"],
}
const TOOLS := {
	"rect":["▢", "矩形", "拖一下铺一片"], "brush":["✎", "画笔", "一格一格画"], "fill":["◩", "填充", "整块换材质"], "erase":["⌫", "擦除", "或者按右键"],
	"wall":["▮", "画内墙", "在地板上拖动"], "unwall":["▯", "擦内墙", "拖过要拆的墙"], "doorway":["⊓", "开门洞", "点一下内墙"],
	"place":["✚", "放置", "点在墙上"], "remove":["✕", "移除", "点一下门窗"],
	"paintwall":["✎","局部刷墙","只换墙面材质"],
}
const OUT_TOOLS := {"wall":["▮", "画篱笆", "在地面上拖动"], "unwall":["▯", "拆篱笆", "拖过要拆的篱笆"], "doorway":["⊓", "开口子", "点一下篱笆"],
	"place":["✚", "放置", "点在地面上"], "remove":["✕", "移除", "点一下出入口"]}
const STEP_TOOLS := {"floor":["rect", "brush", "fill", "erase"], "walls":["wall", "unwall", "doorway"], "openings":["place", "remove"]}
## Which rules (core/map_model.gd checks(), by rule id) belong to which step, and a tip for each.
const STEP_RULES := {"template":[], "floor":["floor", "wallspace", "ground"], "walls":["styled", "reach", "narrow"], "openings":["door", "doorplace", "reach"], "links":["linked"], "check":["*"]}
const RULE_TIPS := {
	"floor":"用「矩形」拖一下；地板要连在一起",
	"wallspace":"红色格子太靠上或贴边：地板上面要空 3 格放后墙，四边别贴地图边",
	"styled":"给后墙、侧墙、前墙选样式，或点「三面同样」",
	"door":"到「门窗」这步，在前墙或后墙上放一扇门",
	"doorplace":"门前两格不能有内墙",
	"reach":"红色格子被内墙隔开了：在内墙上开个门洞",
	"narrow":"红色格子只有 1 格宽，两个人走不开：挪开内墙",
	"linked":"到「连接」这步选它通到哪里；不连也能保存",
	"ground":"用「矩形」铺一片草地或小路",
}
const OUT_TIPS := {
	"door":"到「出入口」这步，在地图边的小路上放一个路口",
	"doorplace":"出入口要在能走的地面上，路口要贴着地图边",
	"reach":"红色格子被篱笆或水隔开了：开个口子，或者铺条路过去",
	"narrow":"红色格子只有 1 格宽：把小路画宽一点",
}
func step_name(s: String) -> String: return OUT_NAMES.get(s, STEP_NAMES[s]) if M.outdoor(map) else STEP_NAMES[s]
func step_intro(s: String) -> String: return OUT_INTRO.get(s, STEP_INTRO[s]) if M.outdoor(map) else STEP_INTRO[s]
func step_how(s: String) -> Array: return OUT_HOW.get(s, STEP_HOW[s]) if M.outdoor(map) else STEP_HOW[s]
func tool_info(n: String) -> Array: return OUT_TOOLS.get(n, TOOLS[n]) if M.outdoor(map) else TOOLS[n]
func rule_tip(id: String) -> String: return OUT_TIPS.get(id, RULE_TIPS.get(id, "")) if M.outdoor(map) else RULE_TIPS.get(id, "")
func wall_name(o: Dictionary) -> String: return {"back":"后墙", "front":"前墙", "edge":"地图边的小路", "ground":"地面"}.get(o.wall, "")
const PARTS := {"back":"后墙", "side":"侧墙", "front":"前墙"}
const BLUE := Color("365a80")
const OK_BG := Color("dcebd0")
const OK_INK := Color("2f6b3f")
const BAD_INK := Color("b23b33")

var embedded := false
var material_picker:=FileDialog.new()
var material_kind:="floor"
var wall_choice:="arcade-coast"
var wall_scope:="all"
var repaint_only:=false
var scene_hint := ""
var furniture_preview:Array=[]
var dir := "" ## old roomkit folder: no longer used
var map: Dictionary = {}
var saved_text := ""
var history: Array = []
var future: Array = []
var step := "floor"
var tool := "rect"
var tile := "floor-shop-tile"
var opening_type := "window"
var template: Image = null
var template_tex: Texture2D = null
var template_alpha := 0.45
var template_skipped := false
var preview := false
var grid_on := true
var marks: Array = []
var pressing := 0
var drag_start := Vector2i(-1, -1)
var hover := Vector2i(-1, -1)
var mouse := Vector2.ZERO
var stroke_base: Dictionary = {}
var render_due := true
var textures := {}
var file_time := 0
var watch_left := 1.0

var canvas := Control.new()
var title := Label.new()
var message := Label.new()
var status := Label.new()
var tip := Label.new()
var empty_card := PanelContainer.new()
var step_bar := HBoxContainer.new()
var guide := VBoxContainer.new()
var rules_box := VBoxContainer.new()
var next_button := Button.new()
var help := Control.new()
var shapes := Control.new()
var close_dialog := ConfirmationDialog.new()
var new_dialog := ConfirmationDialog.new()
var name_edit := LineEdit.new()
var kind_pick := OptionButton.new()
var open_dialog := AcceptDialog.new()
var open_list := ItemList.new()
var template_dialog := FileDialog.new()

static func maps_dir() -> String:
	return load("res://core/resident_registry.gd").maps_dir()

# ---------- building the screen ----------
func box(fill: Color, border: Color, width := 2, pad := 12, radius := 10) -> StyleBoxFlat:
	var s := StyleBoxFlat.new(); s.bg_color = fill; s.border_color = border; s.set_border_width_all(width)
	s.set_content_margin_all(pad); s.set_corner_radius_all(radius); return s
func label(text: String, size := 18, color := Hud.INK, wrap := true) -> Label:
	var l := Label.new(); l.text = text; l.add_theme_font_size_override("font_size", size); l.add_theme_color_override("font_color", color)
	if wrap: l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	return l
func card(parent: Node, fill := Hud.PAPER, border := Hud.WOOD_L) -> VBoxContainer:
	var p := PanelContainer.new(); p.add_theme_stylebox_override("panel", box(fill, border, 2, 14)); parent.add_child(p)
	var v := VBoxContainer.new(); v.add_theme_constant_override("separation", 10); p.add_child(v); return v
func button(parent: Node, text: String, fn: Callable, primary := false) -> Button:
	var b := Button.new(); b.text = text; b.custom_minimum_size = Vector2(0, 42); b.pressed.connect(fn); parent.add_child(b)
	if primary:
		for state in ["normal", "hover", "pressed"]: b.add_theme_stylebox_override(state, box(BLUE if state == "normal" else Color("47749c"), Color("253e5a"), 2, 10, 8))
		for state in ["font_color", "font_hover_color", "font_pressed_color"]: b.add_theme_color_override(state, Hud.CREAM)
	return b

func _ready() -> void:
	add_child(material_picker);material_picker.access=FileDialog.ACCESS_FILESYSTEM
	material_picker.file_mode=FileDialog.FILE_MODE_OPEN_FILE;material_picker.filters=PackedStringArray(["*.png ; PNG 平铺材质"])
	material_picker.file_selected.connect(import_material)
	if not embedded: get_window().title = "小屋世界 · 地图编辑器"; get_tree().auto_accept_quit = false
	theme = load("res://ui/home_editor.gd").editor_theme()
	var symbols := SystemFont.new(); symbols.font_names = PackedStringArray(["Microsoft YaHei UI", "Microsoft YaHei", "Segoe UI Symbol", "SimHei"]); theme.default_font = symbols
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	var bg := ColorRect.new(); bg.color = Color("293d39"); bg.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT); add_child(bg)
	var root := VBoxContainer.new(); root.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT);root.offset_left=14;root.offset_top=14;root.offset_right=-14;root.offset_bottom=-14
	root.add_theme_constant_override("separation", 10); add_child(root)
	# header
	var header := PanelContainer.new(); header.add_theme_stylebox_override("panel", box(Hud.PAPER, Hud.WOOD, 3, 10)); root.add_child(header)
	var head := HFlowContainer.new(); head.add_theme_constant_override("separation", 10); header.add_child(head)
	title.add_theme_font_size_override("font_size", 22); title.custom_minimum_size.x=240; title.clip_text=true; title.text_overrun_behavior=TextServer.OVERRUN_TRIM_ELLIPSIS;title.size_flags_horizontal = Control.SIZE_EXPAND_FILL; head.add_child(title)
	button(head, "  ? 使用说明  ", func(): help.show())
	button(head, "  快速开始  ", func(): show_shapes())
	button(head, "  新建  ", ask_new); button(head, "  打开  ", ask_open)
	button(head, "  ↶ 撤销  ", undo); button(head, "  ↷ 重做  ", redo)
	button(head, "  保存  ", save_map, true)
	if embedded: button(head, "  返回游戏 · F6  ", request_exit)
	var existing_bar:=HFlowContainer.new();existing_bar.size_flags_vertical=Control.SIZE_SHRINK_BEGIN;root.add_child(existing_bar)
	button(existing_bar,"改建现有房间",ask_existing)
	button(existing_bar,"应用房间",publish_room,true)
	button(existing_bar,"恢复原房间",restore_room)
	var notice:=label("应用后重启生效",16,Hud.CREAM,false);existing_bar.add_child(notice)
	# step bar
	step_bar.add_theme_constant_override("separation", 8); root.add_child(step_bar)
	# body: guide | map | checklist
	var body := HBoxContainer.new(); body.size_flags_vertical = Control.SIZE_EXPAND_FILL; body.add_theme_constant_override("separation", 10); root.add_child(body)
	var left := ScrollContainer.new(); left.custom_minimum_size = Vector2(260, 0); left.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED; body.add_child(left)
	guide.size_flags_horizontal = Control.SIZE_EXPAND_FILL; guide.add_theme_constant_override("separation", 10); left.add_child(guide)
	var middle := VBoxContainer.new(); middle.size_flags_horizontal = Control.SIZE_EXPAND_FILL; middle.add_theme_constant_override("separation", 6); body.add_child(middle)
	var frame := PanelContainer.new(); frame.size_flags_vertical = Control.SIZE_EXPAND_FILL; frame.add_theme_stylebox_override("panel", box(Hud.WOOD, Hud.WOOD_D, 4, 0, 8)); middle.add_child(frame)
	canvas.clip_contents = true; canvas.mouse_filter = Control.MOUSE_FILTER_STOP; canvas.draw.connect(draw_map); canvas.gui_input.connect(map_input)
	canvas.mouse_exited.connect(func(): hover = Vector2i(-1, -1); tip.hide(); canvas.queue_redraw()); frame.add_child(canvas)
	tip.add_theme_font_size_override("font_size", 17); tip.add_theme_color_override("font_color", Hud.INK)
	var tip_bg := box(Hud.PAPER_H, Hud.WOOD_L, 1, 6, 6); tip.add_theme_stylebox_override("normal", tip_bg); tip.mouse_filter = Control.MOUSE_FILTER_IGNORE; tip.hide(); canvas.add_child(tip)
	build_empty_card()
	status.add_theme_font_size_override("font_size", 16); status.add_theme_color_override("font_color", Hud.PAPER_D); middle.add_child(status)
	var right := ScrollContainer.new(); right.custom_minimum_size = Vector2(240, 0); right.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED; body.add_child(right)
	var right_col := VBoxContainer.new(); right_col.size_flags_horizontal = Control.SIZE_EXPAND_FILL; right_col.add_theme_constant_override("separation", 10); right.add_child(right_col)
	var rc := card(right_col)
	rules_box.add_theme_constant_override("separation", 8); rc.add_child(rules_box)
	next_button.custom_minimum_size = Vector2(0, 46); next_button.pressed.connect(go_next); rc.add_child(next_button)
	for state in ["normal", "hover", "pressed"]: next_button.add_theme_stylebox_override(state, box(BLUE if state == "normal" else Color("47749c"), Color("253e5a"), 2, 10, 8))
	for state in ["font_color", "font_hover_color", "font_pressed_color"]: next_button.add_theme_color_override(state, Hud.CREAM)
	var mc := card(right_col, Hud.PAPER_H)
	mc.add_child(label("刚才", 16, Hud.INK2)); message.add_theme_font_size_override("font_size", 18); message.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART; mc.add_child(message)
	build_help(); build_shapes(); build_dialogs()
	start(M.new_map(new_id(), "新地图"), "新地图。先铺地板：用「矩形」在地图上拖一块，或者点「快速开始」挑一个房间形状。")
	if not FileAccess.file_exists(maps_dir().path_join(".guide-seen")):
		help.show(); DirAccess.make_dir_recursive_absolute(maps_dir())
		var f := FileAccess.open(maps_dir().path_join(".guide-seen"), FileAccess.WRITE)
		if f != null: f.store_string("1"); f.close()

func build_empty_card() -> void:
	empty_card.add_theme_stylebox_override("panel", box(Hud.PAPER_H, Hud.WOOD, 3, 22, 12)); empty_card.mouse_filter = Control.MOUSE_FILTER_STOP
	var v := VBoxContainer.new(); v.add_theme_constant_override("separation", 12); empty_card.add_child(v)
	v.add_child(label("从这里开始", 26, Hud.INK, false))
	var l := label("按住左键，在地图上拖出一个长方形，那就是房间的地板。\n墙、阴影都会自动加上。", 19, Hud.INK2); l.custom_minimum_size = Vector2(420, 0); v.add_child(l)
	var row := HBoxContainer.new(); row.add_theme_constant_override("separation", 10); v.add_child(row)
	button(row, "  挑一个房间形状  ", func(): show_shapes(), true)
	button(row, "  看使用说明  ", func(): help.show())
	canvas.add_child(empty_card)

## A modal page over the editor: title, body rows, a close button.
func overlay(node: Control, heading: String) -> VBoxContainer:
	node.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT); node.mouse_filter = Control.MOUSE_FILTER_STOP; add_child(node)
	var shade := ColorRect.new(); shade.color = Color(0.08, 0.12, 0.11, 0.72); shade.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT); node.add_child(shade)
	var center := CenterContainer.new(); center.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT); node.add_child(center)
	var p := PanelContainer.new(); p.add_theme_stylebox_override("panel", box(Hud.PAPER, Hud.WOOD, 4, 26, 14)); p.custom_minimum_size = Vector2(860, 0); center.add_child(p)
	var v := VBoxContainer.new(); v.add_theme_constant_override("separation", 14); p.add_child(v)
	var top := HBoxContainer.new(); v.add_child(top)
	var t := label(heading, 28, Hud.INK, false); t.size_flags_horizontal = Control.SIZE_EXPAND_FILL; top.add_child(t)
	button(top, "  关闭  ", func(): node.hide())
	node.hide(); return v

func build_help() -> void:
	var v := overlay(help, "地图编辑器怎么用")
	v.add_child(label("做一个房间分 5 步，从左到右。上一步通过了，下一步才会打开。", 19, Hud.INK2))
	var grid := GridContainer.new(); grid.columns = 2; grid.add_theme_constant_override("h_separation", 14); grid.add_theme_constant_override("v_separation", 10); v.add_child(grid)
	for i in STEPS.size():
		var s: String = STEPS[i]
		var c := card(grid, Hud.PAPER_H); c.custom_minimum_size = Vector2(400, 0)
		c.add_child(label("%d  %s" % [i + 1, step_name(s)], 21))
		c.add_child(label(step_intro(s), 17, Hud.INK2))
	var keys := card(grid, Hud.PAPER_H); keys.custom_minimum_size = Vector2(400, 0)
	keys.add_child(label("常用按键", 21))
	v.add_child(label("室外地图（比如公园）没有墙：第 3 步是可选的篱笆，第 4 步放「路口」和「建筑入口」。第 5 步「连接」选每扇门、每个路口通到哪张地图。", 17, Hud.INK2))
	keys.add_child(label("左键：用当前工具　右键：擦除 / 移除\nCtrl+Z 撤销　Ctrl+Y 重做　Ctrl+S 保存\nG 显示/隐藏格子　P 预览成品", 17, Hud.INK2))
	v.add_child(label("不想从空白开始？点「快速开始」挑一个房间形状，再慢慢改。地图只保存在编辑器自己的文件夹里，不会改动游戏里的房间。", 17, Hud.INK2))

const SHAPES := [
	["one", "一间大房", "20 × 12 格的长方形，最简单"],
	["two", "两间房", "中间一道内墙，开了门洞"],
	["ell", "L 形房间", "一大一小，转个角"],
	["shop", "带门窗的小店", "地板、墙、门、窗都放好了"],
	["park", "室外 · 公园草地", "草地加十字小路，四条路通到地图外"],
	["plaza", "室外 · 小广场", "石板广场、树篱，一个建筑入口和两个路口"],
]
## 快速开始 is a preview sheet (owner: "a preview sheet showing everything"): every shape drawn as a real thumbnail.
var shape_grid := GridContainer.new()
func build_shapes() -> void:
	var v := overlay(shapes, "快速开始：挑一个开头")
	v.add_child(label("点一张图就用它开始。会替换现在这张地图的内容（可以撤销）。墙的样式、地板材质之后都能改。", 18, Hud.INK2))
	shape_grid.columns = 3; shape_grid.add_theme_constant_override("h_separation", 14); shape_grid.add_theme_constant_override("v_separation", 14); v.add_child(shape_grid)
## Draws the thumbnails the first time the sheet opens (about 50 ms each).
func show_shapes() -> void:
	if shape_grid.get_child_count() == 0:
		for s in SHAPES:
			var kind: String = s[0]; var preview_map := shape_map(kind, "")
			if not M.outdoor(preview_map): # show finished-looking walls in the thumbnail even before a style is chosen
				for p in PARTS:
					if str(preview_map.walls.style.get(p, "")) == "": preview_map = M.set_wall_style(preview_map, p, "shop-cream")
			var img: Image = R.flat(preview_map, Color("38483f")); img.resize(300, 200, Image.INTERPOLATE_BILINEAR)
			# a card that sizes itself to its picture and text; the whole card is clickable and lights up under the mouse
			var card_box := PanelContainer.new(); card_box.mouse_filter = Control.MOUSE_FILTER_STOP; card_box.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
			var calm := box(Hud.PAPER_H, Hud.WOOD_L, 1, 10, 10); var lit := box(Hud.PAPER_H, BLUE, 3, 8, 10)
			card_box.add_theme_stylebox_override("panel", calm)
			card_box.mouse_entered.connect(func(): card_box.add_theme_stylebox_override("panel", lit))
			card_box.mouse_exited.connect(func(): card_box.add_theme_stylebox_override("panel", calm))
			card_box.gui_input.connect(func(e): if e is InputEventMouseButton and e.pressed and e.button_index == MOUSE_BUTTON_LEFT: use_shape(kind); shapes.hide())
			var v := VBoxContainer.new(); v.mouse_filter = Control.MOUSE_FILTER_IGNORE; v.add_theme_constant_override("separation", 6); card_box.add_child(v)
			var pic := TextureRect.new(); pic.texture = ImageTexture.create_from_image(img); pic.mouse_filter = Control.MOUSE_FILTER_IGNORE; v.add_child(pic)
			var t := label(s[1], 20); t.mouse_filter = Control.MOUSE_FILTER_IGNORE; v.add_child(t)
			var d := label(s[2], 16, Hud.INK2); d.mouse_filter = Control.MOUSE_FILTER_IGNORE; d.custom_minimum_size = Vector2(240, 0); v.add_child(d)
			shape_grid.add_child(card_box)
	shapes.show()

func rect_cells(a: Vector2i, b: Vector2i) -> Array:
	var out: Array = []
	for y in range(a.y, b.y + 1):
		for x in range(a.x, b.x + 1): out.append(Vector2i(x, y))
	return out
## The quick-start shapes (also used by the tests). Keeps the map's id and name.
func use_shape(kind: String) -> void:
	var out := kind in ["park", "plaza"]
	var t := tile if R.floors(map).has(tile) and bool(R.floors(map)[tile].get("outdoor", false)) == out else ("ground-grass" if out else "floor-shop-tile")
	tile = t
	var m := shape_map(kind, t)
	change(m, "已用「%s」开始。%s" % [SHAPES.filter(func(x): return x[0] == kind)[0][1], "墙和门窗也放好了，可以直接去「检查」。" if kind == "shop" else ("路口已经放好，到「连接」这步选它们通到哪里。" if out else "接着去「墙」这步选样式。")])
	if kind != "shop": step = "floor"
	refresh()
## The map of a quick-start shape, keeping this map's id and name. t = floor tile for indoor shapes ("" = default).
func shape_map(kind: String, t: String) -> Dictionary:
	var out := kind in ["park", "plaza"]
	if t == "": t = "ground-grass" if out else "floor-shop-tile"
	var m := M.new_map(str(map.id), str(map.name), "outdoor" if out else "indoor")
	match kind:
		"one": m = M.paint_floor(m, rect_cells(Vector2i(5, 4), Vector2i(24, 15)), t)
		"two":
			m = M.paint_floor(m, rect_cells(Vector2i(4, 4), Vector2i(25, 15)), t)
			m = M.set_inner(m, rect_cells(Vector2i(15, 4), Vector2i(15, 15)), true); m = M.toggle_doorway(m, Vector2i(15, 10))
		"ell":
			m = M.paint_floor(m, rect_cells(Vector2i(4, 4), Vector2i(14, 15)), t)
			m = M.paint_floor(m, rect_cells(Vector2i(15, 9), Vector2i(25, 15)), t)
		"shop":
			m = M.paint_floor(m, rect_cells(Vector2i(4, 4), Vector2i(25, 15)), t)
			for p in PARTS: m = M.set_wall_style(m, p, "shop-cream")
			m = M.add_opening(m, "front_door", 12, 15); m = M.add_opening(m, "window", 6, 4); m = M.add_opening(m, "window", 19, 4)
			m = M.add_opening(m, "sign", 11, 4); m = M.add_opening(m, "lamp", 13, 4)
		"park":
			m = M.paint_floor(m, rect_cells(Vector2i(0, 0), Vector2i(29, 19)), "ground-grass")
			m = M.paint_floor(m, rect_cells(Vector2i(14, 0), Vector2i(15, 19)), "ground-path")
			m = M.paint_floor(m, rect_cells(Vector2i(0, 9), Vector2i(29, 10)), "ground-path")
			m = M.paint_floor(m, rect_cells(Vector2i(4, 3), Vector2i(8, 6)), "ground-water")
			m = M.add_opening(m, "edge_exit", 14, 0, "N"); m = M.add_opening(m, "edge_exit", 14, 19, "S")
			m = M.add_opening(m, "edge_exit", 0, 9, "W"); m = M.add_opening(m, "edge_exit", 29, 9, "E")
		"plaza":
			m = M.paint_floor(m, rect_cells(Vector2i(0, 0), Vector2i(29, 19)), "ground-grass")
			m = M.paint_floor(m, rect_cells(Vector2i(8, 5), Vector2i(21, 15)), "ground-stone")
			m = M.paint_floor(m, rect_cells(Vector2i(14, 16), Vector2i(15, 19)), "ground-path")
			m = M.paint_floor(m, rect_cells(Vector2i(0, 9), Vector2i(7, 10)), "ground-path")
			m = M.set_inner(m, rect_cells(Vector2i(8, 4), Vector2i(21, 4)), true)
			m = M.add_opening(m, "entrance", 14, 5); m = M.add_opening(m, "edge_exit", 14, 19, "S"); m = M.add_opening(m, "edge_exit", 0, 9, "W")
	return m

func build_dialogs() -> void:
	add_child(close_dialog); close_dialog.title = "地图还没保存"; close_dialog.dialog_text = "返回游戏会丢掉还没保存的改动。"
	close_dialog.ok_button_text = "返回，不保存"; close_dialog.cancel_button_text = "继续编辑"; close_dialog.confirmed.connect(finish_exit)
	add_child(new_dialog); new_dialog.title = "新建地图"; new_dialog.ok_button_text = "新建"
	var v := VBoxContainer.new(); new_dialog.add_child(v)
	v.add_child(label("大小固定 30 × 20 格。先选地图类型：", 18))
	kind_pick.add_item("室内：房间，墙沿地板边自动长出来"); kind_pick.add_item("室外：没有墙，用小路和路口连到别的地图"); v.add_child(kind_pick)
	v.add_child(label("给它起个名字：", 18))
	name_edit.custom_minimum_size = Vector2(420, 0); name_edit.placeholder_text = "海边书店"; v.add_child(name_edit)
	new_dialog.confirmed.connect(func(): if_saved_then(func():
		var kind := "outdoor" if kind_pick.selected == 1 else "indoor"
		start(M.new_map(new_id(), name_edit.text.strip_edges() if name_edit.text.strip_edges() != "" else ("新室外地图" if kind == "outdoor" else "新地图"), kind), "新的%s地图。先铺%s，或者点「快速开始」。" % ["室外" if kind == "outdoor" else "室内", "地面" if kind == "outdoor" else "地板"])))
	add_child(open_dialog); open_dialog.title = "打开地图"; open_dialog.ok_button_text = "打开"
	open_list.custom_minimum_size = Vector2(480, 320); open_dialog.add_child(open_list)
	open_dialog.confirmed.connect(open_selected); open_list.item_activated.connect(func(_i): open_dialog.hide(); open_selected())
	add_child(template_dialog); template_dialog.access = FileDialog.ACCESS_FILESYSTEM; template_dialog.file_mode = FileDialog.FILE_MODE_OPEN_FILE
	template_dialog.filters = PackedStringArray(["*.png, *.jpg, *.jpeg, *.webp ; 图片"]); template_dialog.title = "选一张参考图"
	template_dialog.file_selected.connect(load_template)
func new_id() -> String: return "map-" + Time.get_datetime_string_from_system().replace(":", "").replace("-", "").replace("T", "-")

# ---------- map state ----------
func start(m: Dictionary, text: String) -> void:
	var issue:=Design.materials_issue(m)
	if issue!="":message.text=issue;return
	map = m; saved_text = text_of(m) if has_file(m) else ""; history.clear(); future.clear(); marks.clear()
	template = null; template_tex = null; template_skipped = false; step = "floor"; tool = "rect"; file_time = file_stamp()
	refresh(); message.text = text
func text_of(m: Dictionary) -> String: return JSON.stringify(m, " ", false, true)
func dirty() -> bool: return text_of(map) != saved_text
func file_of(m: Dictionary) -> String: return maps_dir().path_join(str(m.id)).path_join("map.json")
func has_file(m: Dictionary) -> bool: return FileAccess.file_exists(file_of(m))
func file_stamp() -> int: return FileAccess.get_modified_time(file_of(map)) if not map.is_empty() and has_file(map) else 0

func change(m: Dictionary, text := "") -> void:
	if text_of(m) == text_of(map): return
	history.append(map); if history.size() > 200: history.pop_front()
	future.clear(); map = m; refresh()
	if text != "": message.text = text
func undo() -> void:
	if history.is_empty(): message.text = "没有可以撤销的操作"; return
	future.append(map); map = history.pop_back(); refresh(); message.text = "已撤销"
func redo() -> void:
	if future.is_empty(): message.text = "没有可以重做的操作"; return
	history.append(map); map = future.pop_back(); refresh(); message.text = "已重做"

func refresh() -> void:
	if tile not in R.floor_ids(map):tile=R.floor_ids(map)[0]
	if not R.walls(map).has(wall_choice):wall_choice="arcade-coast"
	title.text = "%s　·　地图编辑%s" % [map.name, "　（未保存）" if dirty() else ""]
	build_steps(); build_guide(); build_rules(); render_due = true; canvas.queue_redraw()

func _process(delta: float) -> void:
	if render_due:
		render_due = false
		var r: Dictionary = R.render(map)
		for k in r: textures[k] = ImageTexture.create_from_image(r[k])
		furniture_preview=[]
		if map.has("editScene"):
			var resolved:Dictionary=RoomMaps.layout_result(map).get("resolved",{})
			for layer in resolved.get("manifest",{}).get("layers",[]):
				if not str(layer.get("id","")).begins_with("map-"):furniture_preview.append(layer)
		canvas.queue_redraw()
	empty_card.visible = empty_state()
	if empty_card.visible: empty_card.position = (canvas.size - empty_card.size) / 2.0
	watch_left -= delta
	if watch_left <= 0.0: watch_left = 1.0; watch_file()

## An AI (core/map_commands.gd) or another program changed the saved file: reload it when it is safe to.
func watch_file() -> void:
	var t := file_stamp()
	if t == 0 or t == file_time: return
	file_time = t
	var m = JSON.parse_string(FileAccess.get_file_as_string(file_of(map)))
	if not m is Dictionary or text_of(m) == saved_text: return
	var issue:=Design.materials_issue(m)
	if issue!="":message.text="外部修改未载入："+issue;return
	if dirty(): message.text = "这张地图的文件被别的程序（比如 AI）改过了。你这里有没保存的改动，所以没有重新载入；保存会覆盖它的改动。"; return
	var keep := step; history.append(map); future.clear(); map = m; saved_text = text_of(m); step = keep
	refresh(); message.text = "文件被别的程序（比如 AI）改过了，已重新载入。可以撤销回到之前的样子。"

# ---------- steps ----------
func gate(s: String) -> String:
	var at := STEPS.find(s)
	if at >= 2 and not M.floor_ok(map): return "先把地面铺好" if M.outdoor(map) else "先把地板铺好"
	if at >= 3 and not M.walls_ok(map): return "先选好三面墙的样式"
	if s == "links" and M.doors(map).is_empty(): return "先放一个出入口" if M.outdoor(map) else "先放一扇门"
	return ""
func step_done(s: String) -> bool:
	match s:
		"template": return template != null or template_skipped or not M.floor_cells(map).is_empty()
		"floor": return M.floor_ok(map)
		"walls": return M.walls_ok(map) and M.rule(map, "reach")[1] and M.rule(map, "narrow")[1]
		"openings": return M.walls_ok(map) and M.rule(map, "door")[1] and M.rule(map, "doorplace")[1]
		"links": return not M.doors(map).is_empty() and M.rule(map, "linked")[1]
		"check": return M.usable(map)
	return false
func go_step(s: String) -> void:
	var why := gate(s)
	if why != "": message.text = "「%s」还没打开：%s。" % [step_name(s), why]; refresh(); return
	if step == "template" and s != "template" and template == null: template_skipped = true
	step = s; tool = STEP_TOOLS.get(s, [""])[0]; marks.clear(); refresh()
	message.text = step_intro(s)
func go_next() -> void:
	var at := STEPS.find(step)
	if at == STEPS.size() - 1: save_map(); return
	go_step(STEPS[at + 1])

func build_steps() -> void:
	for c in step_bar.get_children(): c.queue_free()
	for i in STEPS.size():
		var s: String = STEPS[i]; var why := gate(s); var done := step_done(s); var here := s == step
		var b := Button.new(); b.size_flags_horizontal = Control.SIZE_EXPAND_FILL; b.custom_minimum_size = Vector2(0, 62); b.alignment = HORIZONTAL_ALIGNMENT_LEFT
		var sub: String = "正在做" if here else ("可跳过" if s == "template" and not done else ("完成" if done else ({"先把地板铺好":"铺完地板解锁", "先把地面铺好":"铺完地面解锁", "先放一扇门":"放了门解锁", "先放一个出入口":"放了出入口解锁"}.get(why, "选好墙样式解锁") if why != "" else "还没做")))
		b.text = "  %s %d  %s\n  %s" % ["✓" if done and not here else ("○" if why != "" else "●"), i + 1, step_name(s), sub]
		var fill: Color = Hud.PAPER_H if here else (OK_BG if done else (Hud.PAPER_D if why != "" else Hud.PAPER))
		var border: Color = BLUE if here else (Hud.WOOD_L if why == "" else Hud.WOOD)
		for state in ["normal", "hover", "pressed", "focus"]: b.add_theme_stylebox_override(state, box(fill, border, 3 if here else 1, 8, 10))
		var ink: Color = Hud.INK if why == "" else Hud.INK2
		if done and not here: ink = OK_INK
		for state in ["font_color", "font_hover_color", "font_pressed_color", "font_focus_color"]: b.add_theme_color_override(state, ink)
		b.add_theme_font_size_override("font_size", 19)
		b.pressed.connect(func(): go_step(s)); step_bar.add_child(b)

func build_guide() -> void:
	for c in guide.get_children(): c.queue_free()
	var top := card(guide)
	top.add_child(label("第 %d 步：%s" % [STEPS.find(step) + 1, step_name(step)], 24))
	top.tooltip_text=step_intro(step)
	var how:=Button.new();how.text="操作提示";how.flat=true;top.add_child(how)
	var details:=label(step_intro(step)+"\n"+"\n".join(step_how(step)),16,Hud.INK2);details.visible=false;top.add_child(details)
	how.pressed.connect(func():details.visible=not details.visible)
	if STEP_TOOLS.has(step):
		var tc := card(guide); tc.add_child(label("工具", 18, Hud.INK2))
		var grid := GridContainer.new(); grid.columns = 2; grid.add_theme_constant_override("h_separation", 8); grid.add_theme_constant_override("v_separation", 8); tc.add_child(grid)
		for n in STEP_TOOLS[step]: tool_tile(grid, n)
	match step:
		"template": template_panel()
		"floor": floor_panel()
		"walls": walls_panel()
		"openings": openings_panel()
		"links": links_panel()
		"check": check_panel()

func tool_tile(parent: Node, n: String) -> void:
	var b := Button.new(); b.custom_minimum_size = Vector2(126, 38); b.alignment = HORIZONTAL_ALIGNMENT_LEFT
	b.text = " %s %s" % [tool_info(n)[0], tool_info(n)[1]];b.tooltip_text=tool_info(n)[2]; b.add_theme_font_size_override("font_size", 17)
	var on := tool == n
	for state in ["normal", "hover", "pressed", "focus"]: b.add_theme_stylebox_override(state, box(Hud.PAPER_H if on else Hud.PAPER, BLUE if on else Hud.WOOD_L, 3 if on else 1, 6, 8))
	b.pressed.connect(func(): tool = n; refresh(); message.text = "工具：%s。%s" % [tool_info(n)[1], tool_info(n)[2]]); parent.add_child(b)

## A picture button (material, wall style, door or window): picture, name, selected outline.
func swatch(parent: Node, tex: Texture2D, name: String, on: bool, fn: Callable, width := 92) -> void:
	var v := VBoxContainer.new(); v.add_theme_constant_override("separation", 2); parent.add_child(v)
	var b := Button.new(); b.custom_minimum_size = Vector2(width, 64); b.icon = tex; b.expand_icon = true; b.icon_alignment = HORIZONTAL_ALIGNMENT_CENTER
	for state in ["normal", "hover", "pressed", "focus"]: b.add_theme_stylebox_override(state, box(Hud.PAPER_H, BLUE if on else Hud.WOOD_L, 4 if on else 1, 4, 8))
	b.tooltip_text = name; b.pressed.connect(fn); v.add_child(b)
	var l := label(name, 15, Hud.INK if on else Hud.INK2); l.custom_minimum_size = Vector2(width, 0); l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER; v.add_child(l)
static var _icons := {}
func floor_icon(id: String) -> Texture2D:
	if not _icons.has(id): _icons[id] = ImageTexture.create_from_image(R.image(R.floors(map)[id].file))
	return _icons[id]
func wall_icon(id: String) -> Texture2D:
	var key := "wall:" + id
	if not _icons.has(key):
		var st: Dictionary = R.walls(map)[id]; var img := Image.create(64, 64, false, Image.FORMAT_RGBA8)
		if st.has("pattern"): R.tile(img, Rect2i(0, 0, 64, 40), R.image(st.pattern))
		else: img.fill_rect(Rect2i(0, 0, 64, 40), Color(str(st.plaster)))
		img.fill_rect(Rect2i(0, 0, 64, 6), Color(str(st.trim))); R.wainscot(img, st, 0, 40, 64, 20); img.fill_rect(Rect2i(0, 60, 64, 4), Color(str(st.cap)))
		_icons[key] = ImageTexture.create_from_image(img)
	return _icons[key]
func edge_icon(id: String) -> Texture2D:
	var key := "edge:" + id
	if not _icons.has(key):
		var st: Dictionary = R.EDGES[id]; var img := Image.create(64, 64, false, Image.FORMAT_RGBA8); img.fill(Color("9db64a"))
		img.fill_rect(Rect2i(0, 8, 64, 32), Color(str(st.top))); img.fill_rect(Rect2i(0, 40, 64, 24), Color(str(st.face))); img.fill_rect(Rect2i(0, 60, 64, 4), Color(str(st.dark)))
		_icons[key] = ImageTexture.create_from_image(img)
	return _icons[key]
func opening_icon(type: String) -> Texture2D:
	var key := "open:" + type
	if not _icons.has(key) and not R.CROPS.has(type): # outdoor ways in/out: drawn by the renderer on a scrap of ground
		var m := M.new_map("icon", "icon", "outdoor"); m = M.paint_floor(m, rect_cells(Vector2i(0, 0), Vector2i(3, 2)), "ground-path")
		m = M.add_opening(m, type, 1, 0 if type == "edge_exit" else 1, "N" if type == "edge_exit" else "")
		var r: Dictionary = R.render(m); var img: Image = r.ground; img.blend_rect(r.overlay, Rect2i(0, 0, img.get_width(), img.get_height()), Vector2i.ZERO)
		_icons[key] = ImageTexture.create_from_image(img.get_region(Rect2i(0, 0, 4 * R.CP, 2 * R.CP)))
	if not _icons.has(key):
		var cr: Array = R.CROPS[type].crop
		_icons[key] = ImageTexture.create_from_image(R.image(R.SHOP).get_region(Rect2i(cr[0], cr[1], cr[2], cr[3])))
	return _icons[key]
func flow(parent: Node) -> HFlowContainer:
	var f := HFlowContainer.new(); f.add_theme_constant_override("h_separation", 8); f.add_theme_constant_override("v_separation", 8); parent.add_child(f); return f

func template_panel() -> void:
	var c := card(guide)
	button(c, "  选一张参考图…  ", func(): template_dialog.popup_centered_ratio(0.7), true)
	if template != null:
		c.add_child(label("透明度", 16, Hud.INK2))
		var s := HSlider.new(); s.min_value = 0.1; s.max_value = 0.9; s.step = 0.05; s.value = template_alpha
		s.value_changed.connect(func(v): template_alpha = v; canvas.queue_redraw()); c.add_child(s)
		c.add_child(label("用哪种地板去认：", 16, Hud.INK2))
		var f := flow(c)
		for id in R.floor_ids(map): swatch(f, floor_icon(id), R.floors(map)[id].name, tile == id, func(): tile = id; refresh(), 70)
		button(c, "  识别地板  ", detect_floor, true)
		button(c, "  去掉参考图  ", func(): template = null; template_tex = null; refresh())
	button(c, "  跳过这一步 →  ", func(): template_skipped = true; go_step("floor"))
func floor_panel() -> void:
	if not M.outdoor(map):
		var themes:=card(guide);themes.add_child(label("房间配色",18,Hud.INK2));var choices:=flow(themes)
		for id in Design.THEMES:button(choices,Design.THEMES[id].name,func():change(Design.apply_theme(map,id),"已更换主地板与墙面；分区、家具和门保留，可撤销"))
	var c := card(guide); c.add_child(label(("地面材质" if M.outdoor(map) else "地板材质") + "（点一下选中）", 18, Hud.INK2))
	var lock_shape:=CheckButton.new();lock_shape.text="只换材质，保留房间形状";lock_shape.button_pressed=repaint_only;c.add_child(lock_shape)
	lock_shape.toggled.connect(func(on):repaint_only=on)
	button(c,"＋ 导入地板 PNG",func():choose_material("floor"))
	var f := flow(c)
	for id in R.floor_ids(map): swatch(f, floor_icon(id), R.floors(map)[id].name, tile == id, func(): tile = id; tool = "brush" if tool == "erase" else tool; refresh(); message.text = "材质：" + R.floors(map)[id].name, 70)
func walls_panel() -> void:
	var c := card(guide)
	if M.outdoor(map):
		c.add_child(label("篱笆样式", 18, Hud.INK2)); var ef := flow(c)
		for id in R.EDGES: swatch(ef, edge_icon(id), R.EDGES[id].name, str(map.walls.style.get("edge", "hedge")) == id, func(): change(M.set_wall_style(map, "edge", id), "篱笆：" + R.EDGES[id].name), 70)
		c.add_child(label("篱笆是可选的；不画也行。", 16, Hud.INK2))
		return
	c.add_child(label("墙面材质",18,Hud.INK2))
	var scope:=OptionButton.new()
	for entry in [["all","全部外墙"],["back","后墙"],["side","侧墙"],["front","前墙"],["local","局部刷墙 · 点击或拖过墙面"]]:
		scope.add_item(entry[1]);scope.set_item_metadata(scope.item_count-1,entry[0])
		if wall_scope==entry[0]:scope.select(scope.item_count-1)
	c.add_child(scope);scope.item_selected.connect(func(i):wall_scope=scope.get_item_metadata(i))
	button(c,"＋ 导入墙纸 PNG",func():choose_material("wall"))
	var f:=flow(c)
	for id in R.walls(map):swatch(f,wall_icon(id),R.walls(map)[id].name.split(" · ")[0],wall_choice==id,func():select_wall(id),80)
	c.add_child(label("局部刷墙不改变墙体；右键恢复该段原样。",16,Hud.INK2))

func select_wall(id:String)->void:
	wall_choice=id
	if wall_scope=="local":tool="paintwall";refresh();message.text="拖过要换材质的墙面，右键恢复";return
	var m:=map
	for part in (PARTS.keys() if wall_scope=="all" else [wall_scope]):m=M.set_wall_style(m,part,id)
	change(m,"墙面已更新；局部样式保留，可撤销")
func choose_material(kind:String)->void:
	material_kind=kind;material_picker.title="导入地板（正方形，64像素整倍数）" if kind=="floor" else "导入墙纸（宽高为64像素整倍数）"
	material_picker.popup_centered_ratio(.7)
func import_material(path:String)->void:
	var file:=FileAccess.open(path,FileAccess.READ)
	if file==null or file.get_length()>1048576:message.text="图片无法读取或超过 1 MB";return
	var result:=Design.import_png(map,material_kind,path.get_file().get_basename(),file.get_buffer(file.get_length()))
	if result.error!="":message.text=result.error;return
	if material_kind=="floor":tile=result.id
	else:wall_choice=result.id
	change(result.map,"材质已加入此地图；原尺寸平铺，保存地图时一同保存")
func paint_floor_cells(cells:Array,value:String)->Dictionary:
	if repaint_only and value=="":return map
	if repaint_only:cells=cells.filter(func(c):return M.is_floor(map,c))
	return M.paint_floor(map,cells,value)
func openings_panel() -> void:
	var c := card(guide); c.add_child(label(("出入口（选一种，再点地面）" if M.outdoor(map) else "门窗（选一种，再点墙）"), 18, Hud.INK2))
	var f := flow(c)
	if not opening_type in M.openings_for(map): opening_type = M.openings_for(map)[0]
	for id in M.openings_for(map):
		var d: Dictionary = M.OPENINGS[id]
		swatch(f, opening_icon(id), "%s\n%s · %d 格" % [d.name, wall_name(d), d.w], opening_type == id and tool == "place", func(): opening_type = id; tool = "place"; refresh(); message.text = "把鼠标移到%s上：绿色能放。" % wall_name(d), 132)

## Where each door / path leads: a room of the game world (assets/world.json) or another map in the editor's folder,
## and where you arrive there. Stored in map.exits; the game uses it when new maps join the world.
static var _world := {}
func world_rooms() -> Dictionary:
	if _world.is_empty():
		var w = JSON.parse_string(FileAccess.get_file_as_string("res://assets/world.json"))
		if w is Dictionary:
			for id in w.scenes: _world[id] = {"name": str(w.scenes[id].get("name", id)), "entries": w.scenes[id].get("entries", {}).keys()}
	var out := _world.duplicate(true)
	var d := DirAccess.open(maps_dir())
	if d != null:
		for id in d.get_directories():
			if id == str(map.id): continue
			var p := maps_dir().path_join(id).path_join("map.json")
			var m = JSON.parse_string(FileAccess.get_file_as_string(p)) if FileAccess.file_exists(p) else null
			if m is Dictionary and m.get("format") == "cabin-map/1": out[id] = {"name": "%s（编辑器里的地图）" % m.name, "entries": m.get("exits", {}).keys()}
	return out
func links_panel() -> void:
	var rooms := world_rooms()
	for o in M.doors(map):
		var c := card(guide); var ex: Dictionary = map.exits.get(o.get("exit", o.id), {"to": "", "entry": ""})
		c.add_child(label("%s（%s）" % [M.OPENINGS[o.type].name, o.id], 18))
		c.add_child(label("通到", 16, Hud.INK2))
		var to := OptionButton.new(); to.add_item("（还没选）"); to.set_item_metadata(0, "")
		for id in rooms:
			to.add_item(rooms[id].name); to.set_item_metadata(to.item_count - 1, id)
			if id == str(ex.get("to", "")): to.select(to.item_count - 1)
		to.item_selected.connect(func(i): link(o, str(to.get_item_metadata(i)), "")); c.add_child(to)
		if str(ex.get("to", "")) != "" and rooms.has(str(ex.to)):
			c.add_child(label("到那边后出现在", 16, Hud.INK2))
			var at := OptionButton.new(); at.add_item("（还没选）"); at.set_item_metadata(0, "")
			for e in rooms[str(ex.to)].entries:
				at.add_item(str(e)); at.set_item_metadata(at.item_count - 1, str(e))
				if str(e) == str(ex.get("entry", "")): at.select(at.item_count - 1)
			at.item_selected.connect(func(i): link(o, str(ex.to), str(at.get_item_metadata(i)))); c.add_child(at)
	if M.doors(map).is_empty(): card(guide).add_child(label("还没有门或路口。先到上一步放一个。", 17, Hud.INK2))
func link(o: Dictionary, to: String, entry: String) -> void:
	var m := map.duplicate(true); m.exits[o.get("exit", o.id)] = {"to": to, "entry": entry}
	change(m, "%s 通到：%s%s" % [o.id, world_rooms().get(to, {"name": "（不通）"}).name if to != "" else "（不通）", ("，出现在 " + entry) if entry != "" else ""])
func check_panel() -> void:
	var c := card(guide)
	var p := CheckButton.new(); p.text = "预览成品（隐藏格子和提示）"; p.button_pressed = preview; p.toggled.connect(func(on): preview = on; canvas.queue_redraw()); c.add_child(p)
	c.add_child(label("保存后，在设置 → 机器人管理中将室内地图分配给新增住户，再进入房间布置家具。", 16, Hud.INK2))
	button(c, "  保存这张地图  ", save_map, true)

func same_walls() -> void:
	var st := str(map.walls.style.back) if str(map.walls.style.back) != "" else str(R.walls(map).keys()[0])
	var m := map
	for p in PARTS: m = M.set_wall_style(m, p, st)
	change(m, "三面墙都用了「%s」" % R.walls(map)[st].name)

func build_rules() -> void:
	for c in rules_box.get_children(): c.queue_free()
	var all := M.checks(map); var ids: Array = STEP_RULES[step]
	rules_box.add_child(label("这一步还差" if step != "check" else "全部规则", 21))
	var shown := all.filter(func(r): return "*" in ids or r[4] in ids)
	if shown.is_empty(): rules_box.add_child(label("这一步没有必须做的事，可以跳过。", 17, Hud.INK2))
	var left := 0
	for r in shown:
		var i: String = r[4]; if not r[1] and i != "linked": left += 1
		var b := Button.new(); b.flat = true; b.alignment = HORIZONTAL_ALIGNMENT_LEFT; b.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		b.text = ("✓ " if r[1] else "✗ ") + r[0] + (("（" + r[2] + "）") if r[2] != "" else "") + ("" if r[1] else "\n    " + rule_tip(i))
		var ink := OK_INK if r[1] else (Hud.INK2 if i == "linked" else BAD_INK)
		for state in ["font_color", "font_hover_color", "font_pressed_color", "font_focus_color"]: b.add_theme_color_override(state, ink)
		b.add_theme_font_size_override("font_size", 17)
		var cells: Array = r[3]
		b.pressed.connect(func(): marks = cells; canvas.queue_redraw(); message.text = r[0] + ("：通过" if r[1] else "：" + rule_tip(i)))
		rules_box.add_child(b)
	var at := STEPS.find(step)
	if at == STEPS.size() - 1: next_button.text = "保存地图" if left == 0 else "先保存（还有 %d 条没过）" % left
	else: next_button.text = "下一步：%s  →" % step_name(STEPS[at + 1])

# ---------- the map view ----------
func map_px() -> Vector2: return Vector2(M.size_of(map) * R.CP)
func view_scale() -> float: return minf((canvas.size.x - 16) / map_px().x, (canvas.size.y - 16) / map_px().y)
func view_origin() -> Vector2: return (canvas.size - map_px() * view_scale()) / 2.0
func cell_at(p: Vector2) -> Vector2i: return Vector2i(((p - view_origin()) / (view_scale() * R.CP)).floor())
func cell_rect(c: Vector2i) -> Rect2:
	var k := view_scale() * R.CP; return Rect2(view_origin() + Vector2(c) * k, Vector2(k, k))

func draw_map() -> void:
	var o := view_origin(); var full := Rect2(o, map_px() * view_scale()); var k := view_scale() * R.CP
	canvas.draw_rect(Rect2(Vector2.ZERO, canvas.size), Color("2f3b39"))
	canvas.draw_rect(full, Color("38483f"))
	if template_tex != null and not preview: canvas.draw_texture_rect(template_tex, full, false, Color(1, 1, 1, template_alpha))
	for layer in ["ground", "inner", "overlay"]:
		if layer=="inner":draw_existing_furniture(o)
		if textures.has(layer): canvas.draw_texture_rect(textures[layer], full, false, Color(1, 1, 1, 0.8 if template_tex != null and not preview else 1.0))
	if preview: return
	if grid_on:
		var s := M.size_of(map)
		for x in s.x + 1: canvas.draw_line(o + Vector2(x * k, 0), o + Vector2(x * k, s.y * k), Color(1, 1, 1, 0.13))
		for y in s.y + 1: canvas.draw_line(o + Vector2(0, y * k), o + Vector2(s.x * k, y * k), Color(1, 1, 1, 0.13))
	canvas.draw_rect(full, Hud.WOOD_D, false, 2.0)
	if step == "floor":
		for c in M.wall_space_problems(map): canvas.draw_rect(cell_rect(c), Color(0.9, 0.2, 0.2, 0.38))
	for c in marks: canvas.draw_rect(cell_rect(c), Color(0.95, 0.25, 0.2, 0.45))
	if pressing == MOUSE_BUTTON_LEFT and tool == "rect" and drag_start.x >= 0 and hover.x >= 0:
		var a := Vector2i(mini(drag_start.x, hover.x), mini(drag_start.y, hover.y)); var b := Vector2i(maxi(drag_start.x, hover.x), maxi(drag_start.y, hover.y))
		var r := Rect2(cell_rect(a).position, Vector2(b - a + Vector2i.ONE) * k)
		canvas.draw_rect(r, Color(0.4, 0.75, 1.0, 0.28)); canvas.draw_rect(r, Color(0.55, 0.85, 1.0), false, 3.0)
	if hover.x >= 0 and M.inb(map, hover):
		if step == "openings" and tool == "place":
			var t = M.opening_target(map, opening_type, hover)
			if t != null:
				var side := str(t[2]) if t.size() > 2 else ""
				var issue := M.opening_issue(map, opening_type, t[0], t[1], -1, side); var col := Color(0.3, 0.9, 0.5, 0.42) if issue == "" else Color(0.95, 0.3, 0.3, 0.42)
				if R.CROPS.has(opening_type):
					var rr := R.opening_rect({"type": opening_type, "x": t[0], "y": t[1]})
					canvas.draw_rect(Rect2(o + Vector2(rr.position) * view_scale(), Vector2(rr.size) * view_scale()), col)
				else:
					for c in M.opening_cells({"type": opening_type, "x": t[0], "y": t[1], "side": side}): canvas.draw_rect(cell_rect(c), col)
	if not preview: # where each way in/out leads, written next to it
		for od in M.doors(map):
			var to := str(map.exits.get(od.get("exit", od.id), {}).get("to", ""))
			if to == "": continue
			var cells:Array = M.opening_cells(od) if not R.CROPS.has(od.type) else [Vector2i(int(od.x), int(od.y))]
			canvas.draw_string(get_theme_default_font(), cell_rect(cells[0]).position + Vector2(2, -4), "→ " + str(world_rooms().get(to, {"name": to}).name), HORIZONTAL_ALIGNMENT_LEFT, -1, 16, Hud.CREAM)
		canvas.draw_rect(cell_rect(hover), Color(1, 1, 1, 0.95), false, 2.0)

## What a click / release would do here: shown next to the mouse and in the status line.
func hint() -> Array:
	if not M.inb(map, hover): return ["", "把鼠标移到地图上"]
	var keys := "Ctrl+Z 撤销 · G 格子 · P 预览"
	match step:
		"floor":
			if pressing == MOUSE_BUTTON_LEFT and tool == "rect" and drag_start.x >= 0:
				return ["松开鼠标：铺 %d × %d 格" % [absi(hover.x - drag_start.x) + 1, absi(hover.y - drag_start.y) + 1], "松开鼠标完成 · 右键取消不了，可以撤销"]
			var name: String = R.floors(map)[tile].name
			var t: String = {"rect":"按住拖动：铺一块%s" % name, "brush":"左键：画%s" % name, "fill":"点击：这一整块换成%s" % name, "erase":"左键：擦掉地板"}[tool]
			return [t, "左键 %s · 右键 擦除 · %s" % [tool_info(tool)[1], keys]]
		"walls":
			if tool=="paintwall":return ["局部刷墙 · "+R.walls(map).get(wall_choice,{}).get("name",""),"左键换墙纸 · 右键恢复该段 · "+keys]
			if tool == "doorway":
				if M.is_inner(map, hover): return ["点击：%s门洞" % ("关上" if M.is_doorway(map, hover) else "打开"), "点内墙开关门洞 · " + keys]
				return ["门洞要开在内墙上", "点内墙开关门洞 · " + keys]
			if not M.is_floor(map, hover): return [("篱笆只能画在地面上" if M.outdoor(map) else "内墙只能画在地板上"), "左键 %s · 右键 擦内墙 · %s" % [tool_info(tool)[1], keys]]
			return ["拖动：%s" % tool_info(tool)[1], "左键 %s · 右键 擦内墙 · %s" % [tool_info(tool)[1], keys]]
		"openings":
			var at := M.opening_at(map, hover)
			if at >= 0: return ["右键：移除%s" % M.OPENINGS[map.openings[at].type].name, "左键 放置 · 右键 移除 · " + keys]
			if tool == "remove": return ["这里没有门窗", "左键 放置 · 右键 移除 · " + keys]
			var d: Dictionary = M.OPENINGS[opening_type]; var t = M.opening_target(map, opening_type, hover)
			if t == null: return ["%s要放在%s上" % [d.name, wall_name(d)], "左键 放置 · 右键 移除 · " + keys]
			var why := M.opening_issue(map, opening_type, t[0], t[1], -1, str(t[2]) if t.size() > 2 else "")
			return ["点击：放置%s" % d.name if why == "" else "放不下：" + why, "左键 放置 · 右键 移除 · " + keys]
	return ["", keys]

func update_tip() -> void:
	var h := hint()
	status.text = ("格子 (%d, %d)　·　" % [hover.x, hover.y] if M.inb(map, hover) else "") + h[1]
	tip.visible = h[0] != "" and not preview and M.inb(map, hover) and not empty_state()
	if tip.visible:
		tip.text = h[0]; tip.reset_size()
		tip.position = (mouse + Vector2(18, 22)).clamp(Vector2.ZERO, canvas.size - tip.size - Vector2(4, 4))

func map_input(e: InputEvent) -> void:
	if e is InputEventMouseMotion:
		mouse = e.position; var c := cell_at(e.position)
		if c != hover:
			hover = c
			if pressing != 0: drag_cell(c)
			canvas.queue_redraw()
		update_tip()
	elif e is InputEventMouseButton and e.button_index in [MOUSE_BUTTON_LEFT, MOUSE_BUTTON_RIGHT]:
		if e.pressed and pressing == 0: press_cell(cell_at(e.position), e.button_index)
		elif not e.pressed and e.button_index == pressing: release_cell(cell_at(e.position))
		update_tip()

## Mouse actions as functions (also used by the tests).
func press_cell(c: Vector2i, which := MOUSE_BUTTON_LEFT) -> void:
	if not M.inb(map, c): return
	if step == "template": message.text = "这一步不在地图上画：用左边的按钮放参考图，或者跳过。"; return
	if step in ["check", "links"]: message.text = "这一步不在地图上画。要改地图，就点上面对应的步骤。"; return
	pressing = which; drag_start = c; stroke_base = map.duplicate(true); hover = c
	if step == "openings": pressing = 0; click_opening(c, which == MOUSE_BUTTON_RIGHT or tool == "remove"); return
	if step == "walls" and tool == "doorway":
		pressing = 0
		var why := M.doorway_issue(map, c)
		if why != "": message.text = why
		else:
			var m := M.toggle_doorway(map, c)
			change(m, "门洞已打开" if M.is_doorway(m, c) else "门洞已关上")
		return
	if step == "floor" and tool == "fill" and which == MOUSE_BUTTON_LEFT: pressing = 0; change(paint_floor_cells(flood(c), tile), "已把这一块换成" + R.floors(map)[tile].name); return
	drag_cell(c)
func drag_cell(c: Vector2i) -> void:
	if pressing == 0 or not M.inb(map, c) or (tool == "rect" and pressing == MOUSE_BUTTON_LEFT) or tool == "fill": return
	var erase := pressing == MOUSE_BUTTON_RIGHT
	if step == "floor": live(paint_floor_cells([c], "" if erase or tool == "erase" else tile))
	elif step=="walls" and tool=="paintwall":live(Design.paint_wall(map,c,"" if erase else wall_choice))
	elif step == "walls" and tool in ["wall", "unwall"]: live(M.set_inner(map, [c], not erase and tool == "wall"))
func release_cell(c: Vector2i) -> void:
	if pressing == 0: return
	var which := pressing; pressing = 0
	if tool == "rect" and step == "floor" and which == MOUSE_BUTTON_LEFT and M.inb(map, c):
		map = paint_floor_cells(rect_cells(Vector2i(mini(drag_start.x, c.x), mini(drag_start.y, c.y)), Vector2i(maxi(drag_start.x, c.x), maxi(drag_start.y, c.y))), tile)
	if text_of(map) != text_of(stroke_base):
		var done := map; map = stroke_base
		var what: String = {"floor":"地板已更新", "walls":"内墙已更新"}.get(step, "已更新")
		if step == "floor" and not M.floor_ok(done) and M.floor_cells(done).size() > 0: what += "。还有规则没过，看右边"
		change(done, what)
	drag_start = Vector2i(-1, -1); canvas.queue_redraw()
func live(m: Dictionary) -> void:
	if text_of(m) == text_of(map): return
	map = m; render_due = true
func flood(c: Vector2i) -> Array:
	var ch := M.floor_char(map, c); var seen := {c: true}; var q: Array[Vector2i] = [c]
	while not q.is_empty():
		var j: Vector2i = q.pop_back()
		for d in M.DIRS:
			var n: Vector2i = j + d
			if M.inb(map, n) and not seen.has(n) and M.floor_char(map, n) == ch: seen[n] = true; q.append(n)
	return seen.keys()
func click_opening(c: Vector2i, remove: bool) -> void:
	var at := M.opening_at(map, c)
	if at >= 0:
		var name: String = M.OPENINGS[map.openings[at].type].name
		if remove: change(M.remove_opening(map, at), "已移除" + name)
		else: message.text = "这里已经有%s。右键或者用「移除」可以删掉。" % name
		return
	if remove: message.text = "这里没有门窗"; return
	var t = M.opening_target(map, opening_type, c)
	if t == null: message.text = "%s要放在%s上。" % [M.OPENINGS[opening_type].name, wall_name(M.OPENINGS[opening_type])]; return
	var side := str(t[2]) if t.size() > 2 else ""
	var why := M.opening_issue(map, opening_type, t[0], t[1], -1, side)
	if why != "": message.text = "放不下：" + why; return
	change(M.add_opening(map, opening_type, t[0], t[1], side), "已放置" + M.OPENINGS[opening_type].name + "。到「连接」这步选它通到哪里。")

# ---------- template ----------
func load_template(path: String) -> void:
	var img := Image.load_from_file(path)
	if img == null or img.is_empty(): message.text = "读不了这张图"; return
	img.convert(Image.FORMAT_RGBA8); template = img; template_tex = ImageTexture.create_from_image(img); step = "template"
	refresh(); message.text = "参考图已经铺满整张地图。选一种地板，再点「识别地板」。"
## Each cell's average colour of the reference picture is compared with the floor tiles and the wall colours;
## a cell is floor only when a floor tile is the closest match.
func detect_floor() -> void:
	if template == null: return
	var s := M.size_of(map); var small := template.duplicate(); small.resize(s.x * 4, s.y * 4, Image.INTERPOLATE_BILINEAR)
	var tiles := {}
	for id in R.floor_ids(map): tiles[id] = average(R.image(R.floors(map)[id].file), Rect2i(0, 0, R.CP, R.CP))
	for id in R.walls(map):
		for key in ["plaster", "shade", "wains", "trim", "cap", "side"]: tiles["wall:%s:%s" % [id, key]] = Color(str(R.walls(map)[id][key]))
	var count := 0; var by_tile := {}
	for y in s.y:
		for x in s.x:
			var c := average(small, Rect2i(x * 4, y * 4, 4, 4)); var best := ""; var dist := 0.2
			for id in tiles:
				var d: float = Vector3(c.r - tiles[id].r, c.g - tiles[id].g, c.b - tiles[id].b).length()
				if d < dist: dist = d; best = id
			if best != "" and not best.begins_with("wall:"):
				if not by_tile.has(best): by_tile[best] = []
				by_tile[best].append(Vector2i(x, y)); count += 1
	var m := M.paint_floor(map, M.floor_cells(map), "")
	for id in by_tile: m = M.paint_floor(m, by_tile[id], id)
	change(m, "认出了 %d 格地板。这只是起点：不对的格子到「铺地板」这步改。" % count)
static func average(img: Image, r: Rect2i) -> Color:
	var sum := Vector4.ZERO; var n := 0
	for y in range(r.position.y, r.end.y):
		for x in range(r.position.x, r.end.x):
			var c := img.get_pixel(x, y); sum += Vector4(c.r, c.g, c.b, c.a); n += 1
	sum /= maxf(n, 1)
	return Color(sum.x, sum.y, sum.z, sum.w)

# ---------- files ----------
var furniture_texture_refs:Dictionary={}
func draw_existing_furniture(origin:Vector2)->void:
	var grid_origin:Array=map.get("gridOrigin",map.get("legacy",{}).get("gridOrigin",[0,0]))
	for layer in furniture_preview:
		var file:String=str(layer.get("file",""))
		if file=="" or file.begins_with("runtime:") or file.begins_with("made:"):continue
		var path:=file if file.begins_with("res://") else "res://assets/baked/"+file
		if not ResourceLoader.exists(path):continue
		# Canvas drawing commands do not retain the temporary Resource reference.
		if not furniture_texture_refs.has(path):furniture_texture_refs[path]=load(path)
		var tex=furniture_texture_refs[path]
		if not tex is Texture2D:continue
		var rect:=Rect2(origin+Vector2(float(layer.x)-float(grid_origin[0]),float(layer.y)-float(grid_origin[1]))*2.0*view_scale(),Vector2(layer.w,layer.h)*2.0*view_scale())
		if layer.has("region"):
			var a:Array=layer.region;canvas.draw_texture_rect_region(tex,rect,Rect2(a[0],a[1],a[2],a[3]))
		else:canvas.draw_texture_rect(tex,rect,false)
func ask_existing()->void:
	open_list.clear()
	for id in RoomMaps.ROOMS:
		var name:String=WorldData.scenes.get(id,{}).get("name",id)
		open_list.add_item(("当前 · " if id==scene_hint else "")+name)
		open_list.set_item_metadata(open_list.item_count-1,"existing:"+id)
	open_dialog.popup_centered()
func publish_room()->void:
	if not map.has("editScene"):message.text="先用「改建现有房间」选择要修改的房间。";return
	var issue:=RoomMaps.publish(map)
	message.text=issue if issue!="" else "房间改建已保存。下次启动游戏时生效；当前住户的活动继续，原版可随时恢复。"
func restore_room()->void:
	if not map.has("editScene"):message.text="请先选择要恢复的现有房间。";return
	var issue:=RoomMaps.restore_original(map.editScene)
	message.text=issue if issue!="" else "下次启动恢复内置房间；改建草稿和上一版备份仍保留。"
func save_map() -> void:
	if map.get("cell")!=M.Grid.CELL:message.text="格子尺寸不一致，不能保存：须与游戏共用每格 %d 像素。" % M.Grid.CELL;return
	var path := file_of(map); DirAccess.make_dir_recursive_absolute(path.get_base_dir())
	if FileAccess.file_exists(path): DirAccess.copy_absolute(path, path + ".bak")
	var f := FileAccess.open(path, FileAccess.WRITE)
	if f == null: message.text = "保存失败：" + error_string(FileAccess.get_open_error()); return
	f.store_string(text_of(map) + "\n"); f.close()
	saved_text = text_of(map); file_time = file_stamp(); refresh()
	message.text = "已保存到 %s。%s" % [ProjectSettings.globalize_path(path), "所有规则都通过了。" if M.usable(map) else "还有规则没过，看右边。"]
func ask_new() -> void: name_edit.text = ""; new_dialog.popup_centered()
func ask_open() -> void:
	open_list.clear()
	var d := DirAccess.open(maps_dir())
	if d != null:
		for id in d.get_directories():
			var p := maps_dir().path_join(id).path_join("map.json")
			var m = JSON.parse_string(FileAccess.get_file_as_string(p)) if FileAccess.file_exists(p) else null
			if m is Dictionary and m.get("format") == "cabin-map/1" and (not m.has("legacy") or m.get("structure")=="modular"):
				open_list.add_item("%s　（%s）" % [m.name, id]); open_list.set_item_metadata(open_list.item_count - 1, p)
	if open_list.item_count == 0: message.text = "还没有保存过地图。"; return
	open_dialog.popup_centered()
func open_selected() -> void:
	var sel := open_list.get_selected_items()
	if sel.is_empty(): return
	var p: String = open_list.get_item_metadata(sel[0])
	if_saved_then(func():
		if p.begins_with("existing:"):
			var draft:=RoomMaps.draft(p.trim_prefix("existing:"))
			if not draft.is_empty():start(draft,"已载入房间改建草稿，家具位置保留。旧版背景转换为可编辑地板和墙；预览检查后再应用，游戏中的房间暂不改变。")
			return
		var m = JSON.parse_string(FileAccess.get_file_as_string(p))
		if m is Dictionary: start(m, "已打开「%s」。" % m.name))
func if_saved_then(fn: Callable) -> void:
	if not dirty() or history.is_empty(): fn.call(); return
	var ask := ConfirmationDialog.new(); ask.dialog_text = "当前地图还没保存，要丢掉改动吗？"; ask.ok_button_text = "丢掉改动"; ask.cancel_button_text = "取消"
	add_child(ask); ask.confirmed.connect(fn); ask.confirmed.connect(ask.queue_free); ask.canceled.connect(ask.queue_free); ask.popup_centered()

# ---------- keys and leaving ----------
func _input(e: InputEvent) -> void:
	if not (e is InputEventKey and e.pressed and not e.echo): return
	var typing := get_viewport().gui_get_focus_owner() is LineEdit
	if (help.visible or shapes.visible) and e.keycode == KEY_ESCAPE: help.hide(); shapes.hide()
	elif e.ctrl_pressed and e.keycode == KEY_Z and not e.shift_pressed: undo()
	elif e.ctrl_pressed and (e.keycode == KEY_Y or (e.keycode == KEY_Z and e.shift_pressed)): redo()
	elif e.ctrl_pressed and e.keycode == KEY_S: save_map()
	elif e.keycode == KEY_G and not typing: grid_on = not grid_on; canvas.queue_redraw()
	elif e.keycode == KEY_P and not typing: preview = not preview; canvas.queue_redraw(); update_tip()
	elif embedded and e.keycode in [KEY_F6, KEY_ESCAPE]: request_exit()
	else: return
	get_viewport().set_input_as_handled()
func request_exit() -> void:
	if dirty() and not history.is_empty(): close_dialog.popup_centered(); return
	finish_exit()
func finish_exit() -> void:
	if embedded: exit_requested.emit()
	else: get_tree().quit()
func _notification(what: int) -> void:
	if what == NOTIFICATION_WM_CLOSE_REQUEST and not embedded: request_exit()
## The empty-map card shows while nothing is laid yet (checked directly, not from last frame's visibility).
func empty_state() -> bool:
	return M.floor_cells(map).is_empty() and step in ["floor", "template"] and template == null and not help.visible and not shapes.visible
