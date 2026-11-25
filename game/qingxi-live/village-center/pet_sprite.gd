extends Node2D
## 2026-11-21 pets: 宠物精灵（猫 / 狗）。
##
## 有美术就切图，没有就 draw_rect 画一只像素小动物（同 critters.gd 画小鸟的做法）——
## 缺图时游戏照常运行、照常可领养可命名，把 PNG 放进目录（下次打开编辑器或导出时 Godot 自动 import）
## 就自动变好，不用改代码、不用改任何列表（ART-REQUIREMENTS 的规则）。
##
## 美术规范（与 art/garden-v3 的动物同一套管线，2× 烘焙）：
##   DIR/<kind>.png          4 列 × 2 行，单元 64×64（整图 256×128）；列 = S/W/E/N；行 = 走的两步
##   DIR/<kind>-pose.png     同样 4 列 × 2 行；列 = 朝向；行 = [趴下/打盹, 蹭人/高兴]
##   DIR/<kind>-<breed>.png  2026-11-21 v2：品种图，同样的格子/朝向/脚锚点
##   DIR/<kind>-<breed>-pose.png
##   脚锚点在单元内 (32,60)：两只脚着地点的中点，每帧不许漂。
##
## v2（品种 + 成长）：
##   * 品种：先找品种图（cat-orange.png），没有再退回种类图（cat.png），再没有就 draw_rect 兜底。
##     所以**只放品种图也能跑**、只放种类图也能跑、什么都没有也能跑。
##   * 幼崽使用 <品种>-baby.png；长大后切换成年图。两套走路图都是四列方向、四行动作。

const DIR := "res://qingxi-live/village-center/art/garden-v3/pets/"
const CELL := 64
const FOOT := Vector2(32.0, 60.0)
const SCREEN_SIZE := {"cat": 40.0, "dog": 52.0}   # 单元里画多大（世界像素，= 文件像素）
const BODY_TOP := {"cat": 28.0, "dog": 38.0}      # 名牌抬高用（品种可以用 pets_rules.plate_lift 覆盖）

static var sheets := {}

var kind := "cat"
var breed := ""          # 品种键（orange/tabby/white/golden/shiba/corgi）；"" = 用种类图
var baby := false
var body_scale := 1.0    # 体型系数（品种 × 成长阶段），只影响画出来多大，不影响脚锚点
var direction := 0       # 0 S, 1 W, 2 E, 3 N
var step := 0
var breath := 0.0
var phase := 0.0
var pose_row := 0        # 0 = 走/站（<file>.png），1 = 打盹/高兴（<file>-pose.png）
var sleepy := false
var moving := false
var heading := Vector2.DOWN

func _init(pet_kind: String = "cat", pet_breed: String = "", pet_scale: float = 1.0, is_baby: bool = false):
	set_identity(pet_kind, pet_breed, pet_scale, is_baby)
	name = "Pet_%s" % kind
	y_sort_enabled = true

## 换品种/换体型时调（表现层刷新用），不用重建节点。
func set_identity(pet_kind: String, pet_breed: String = "", pet_scale: float = 1.0, is_baby: bool = false) -> void:
	kind = pet_kind if pet_kind in SCREEN_SIZE else "cat"
	baby = is_baby
	breed = str(pet_breed).strip_edges()
	body_scale = maxf(0.2, pet_scale)
	queue_redraw()

## 图的名字干："cat-orange" / "cat"（没品种时）
func stem() -> String:
	return "%s-%s" % [kind, breed] if breed != "" else kind

func art_path() -> String:
	return DIR + stem() + ("-baby.png" if baby else ".png")

func pose_art_path() -> String:
	return DIR + stem() + "-pose.png"

func has_art() -> bool:
	return FileAccess.file_exists(art_path())

## 名牌抬高：算上体型（幼崽名牌也低一点）。
func height() -> float:
	return float(BODY_TOP.get(kind, 28.0)) * body_scale

## 切一格（只负责"这个文件的这一格存不存在"）。
func _region(file_name: String, col: int, row: int) -> Texture2D:
	var cache_key := "%s:%d:%d" % [file_name, col, row]
	if sheets.has(cache_key):
		return sheets[cache_key]
	var image := Image.load_from_file(file_name)
	if image == null or image.is_empty():
		return null
	var x := clampi(col, 0, 3) * CELL
	var y := clampi(row, 0, 3) * CELL
	if x + CELL > image.get_width() or y + CELL > image.get_height():
		return null
	var tex: Texture2D = ImageTexture.create_from_image(image.get_region(Rect2i(x, y, CELL, CELL)))
	sheets[cache_key] = tex
	return tex

## 品种图优先 -> 种类图 -> 都没有返回 null（调用方去 draw_rect 兜底）。
func _pick_region(col: int, row: int) -> Texture2D:
	var files := []
	if pose_row > 0 and not moving and pose_row == 1 and sleepy:
		files.append({"path": DIR + stem() + "-sleep.png", "row": 0})
	files.append({"path": art_path(), "row": row if moving else 0})
	files.append({"path": DIR + kind + ".png", "row": row % 2})
	for f in files:
		var p := str(f.path)
		if not FileAccess.file_exists(p):
			continue
		var t := _region(p, col, int(f.row))
		if t != null:
			return t
	return null

func animate(dt: float, is_moving: bool, mode: String, face: Vector2) -> void:
	breath=fmod(breath+dt*(2.0 if sleepy else 3.0),TAU)
	moving = is_moving
	sleepy = mode in ["打盹","睡觉"]
	pose_row = 1 if mode in ["打盹", "睡觉", "高兴", "蹭蹭", "看家"] else 0
	if moving:
		direction = (2 if face.x > 0.0 else 1) if absf(face.x) > absf(face.y) else (0 if face.y > 0.0 else 3)
		phase += dt * 7.0
		step = int(phase) % 4
	else:
		phase = 0.0
		step = 0
		if face.length() > 0.01:
			direction = (2 if face.x > 0.0 else 1) if absf(face.x) > absf(face.y) else (0 if face.y > 0.0 else 3)
	heading = face
	queue_redraw()

func _draw() -> void:
	# 体型缩放绕脚锚点做：脚仍在 (32,60)，幼崽只是整体变小、不会浮空。
	draw_set_transform(Vector2.ZERO, 0.0, Vector2(body_scale, body_scale*(1.0 if moving else 1.0+sin(breath)*0.022)))
	var tex := _pick_region(direction, step)
	if tex != null:
		draw_texture_rect(tex, Rect2(-FOOT.x, -FOOT.y, CELL, CELL), false)
		draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
		return
	# ---- 缺图兜底：一只 2 色像素小动物 ----
	var flip := -1.0 if direction == 1 else 1.0
	var bob := 1.0 if moving and step == 1 else 0.0
	if kind == "cat":
		_fallback_cat(flip, bob)
	else:
		_fallback_dog(flip, bob)
	draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)

func _fallback_cat(flip: float, bob: float) -> void:
	var body := Color("e8c98f")
	var dark := Color("b98f52")
	var ink := Color("3a2a20")
	if pose_row == 1:
		# 趴着打盹：一团
		draw_rect(Rect2(-11 + bob, -12, 22, 11), body)
		draw_rect(Rect2(-11 + bob, -13, 22, 2), dark)
		draw_rect(Rect2(9 * flip, -15, 8, 8), body)
		draw_rect(Rect2(10 * flip, -17, 2, 4), body)
		draw_rect(Rect2(14 * flip, -17, 2, 4), body)
		draw_rect(Rect2(13 * flip, -13, 3, 2), ink)
		draw_rect(Rect2(-11, -3, 22, 2), body.darkened(0.15))
		return
	draw_rect(Rect2(-9 + bob, -10, 18, 9), body)
	draw_rect(Rect2(-9 + bob, -10, 18, 2), dark)
	draw_rect(Rect2(7 * flip, -15, 8, 8), body)
	draw_rect(Rect2(8 * flip, -17, 2, 4), body)
	draw_rect(Rect2(12 * flip, -17, 2, 4), body)
	draw_rect(Rect2(11 * flip, -13, 3, 2), ink)
	draw_rect(Rect2(-10 + bob, -2, 2, 3), body.darkened(0.1))
	draw_rect(Rect2(7 + bob, -2, 2, 3), body.darkened(0.1))
	# 尾巴
	draw_rect(Rect2(-12 + bob, -10, 2, 2), dark)
	draw_rect(Rect2(-14 + bob, -13, 2, 4), dark)

func _fallback_dog(flip: float, bob: float) -> void:
	var body := Color("d9a86a")
	var dark := Color("a97b3f")
	var cream := Color("f3e2c2")
	var ink := Color("3a2a20")
	if pose_row == 1:
		# 坐着
		draw_rect(Rect2(-9 + bob, -16, 16, 15), body)
		draw_rect(Rect2(-9 + bob, -16, 16, 2), dark)
		draw_rect(Rect2(6 * flip, -24, 10, 10), body)
		draw_rect(Rect2(5 * flip, -26, 3, 6), dark)
		draw_rect(Rect2(13 * flip, -26, 3, 6), dark)
		draw_rect(Rect2(9 * flip, -20, 5, 2), cream)
		draw_rect(Rect2(11 * flip, -23, 3, 2), ink)
		draw_rect(Rect2(-9, -2, 16, 2), body.darkened(0.15))
		return
	draw_rect(Rect2(-11 + bob, -15, 22, 12), body)
	draw_rect(Rect2(-11 + bob, -15, 22, 2), dark)
	draw_rect(Rect2(-4 + bob, -11, 9, 6), cream)
	draw_rect(Rect2(7 * flip, -23, 10, 10), body)
	draw_rect(Rect2(6 * flip, -25, 3, 6), dark)
	draw_rect(Rect2(14 * flip, -25, 3, 6), dark)
	draw_rect(Rect2(10 * flip, -19, 5, 3), cream)
	draw_rect(Rect2(12 * flip, -21, 3, 2), ink)
	draw_rect(Rect2(-12 + bob, -3, 3, 4), body.darkened(0.1))
	draw_rect(Rect2(-5 + bob, -3, 3, 4), body.darkened(0.1))
	draw_rect(Rect2(4 + bob, -3, 3, 4), body.darkened(0.1))
	draw_rect(Rect2(10 + bob, -3, 3, 4), body.darkened(0.1))
	# 尾巴（走起来时翘着）
	if moving:
		draw_rect(Rect2(-14 + bob, -20, 3, 7), dark)
	else:
		draw_rect(Rect2(-14 + bob, -14, 4, 3), dark)
