class_name ItemIcons
extends RefCounted
## Reuse the original inventory art; no emoji/font dependency.
const FOODS := ["草莓软糖", "海苔薯片", "奶油面包", "巧克力棒", "小鱼饼干", "冰镇橘子汽水", "草莓牛奶", "乌龙茶", "矿泉水", "柠檬茶", "香草冰淇淋", "西瓜冰棍"]
const HOT := ["hot_milk", "hot_coffee", "hot_latte", "hot_cocoa", "ginger_tea", "hot_honey_lemon", "hot_green_tea", "hot_corn_milk"]
const FARM_NAMES := {"seed":"白菜种子","hay":"干草","pig_feed":"猪饲料","fish_feed":"鱼饲料","wheat":"小麦","carrot":"胡萝卜","fry":"鱼苗","veg":"白菜","milk":"牛奶","wool":"羊毛","fish":"鲜鱼","meal":"家常菜","feeder_cow":"牛草槽","feeder_sheep":"羊草架","feeder_chicken":"鸡食盘","feeder_pig":"猪食槽"}
static var cache := {}

static func texture(id: String, name_of := "", space := "") -> Texture2D:
	var key := id + ":" + space
	if cache.has(key): return cache[key]
	if FARM_NAMES.has(id):
		var file := "res://assets/ui/farm-items/"+id+".png"
		if FileAccess.file_exists(file):
			var image := Image.new()
			if image.load_png_from_buffer(FileAccess.get_file_as_bytes(file))==OK:
				cache[key] = ImageTexture.create_from_image(image)
				return cache[key]
	var own:="res://assets/ui/items/"+id+".png"
	if ResourceLoader.exists(own):cache[key]=load(own);return cache[key]
	var tex: Texture2D
	var cell := HOT.find(id)
	if cell >= 0:
		tex = atlas("hot-drinks.png", cell, 4, 2)
	elif FOODS.has(name_of):
		tex = atlas("food-icons.png", FOODS.find(name_of), 4, 4)
	else:
		var scene: String = WorldData.SPACE_SCENE.get(space, "qianxia-shop")
		var aliases := {"plants":"plant-west", "lamps":"main-light", "whale_bed":"xj-bed", "xj_computer":"xj-desk", "fish_tank":"xj-tank", "beanbag":"xj-sofa", "xj_corner":"xj-writing_desk", "round_window":"xj-window", "wave_rug":"xj-ocean-rug", "xj_plant":"xj-plant-west", "xj_lamp":"xj-main-light", "xj_notes":"xj-writing_desk", "xj_accessories":"xj-accessory_table", "flower_bed":"flowers", "meadow":"flowers", "river":"river-middle", "park_lamps":"lamp-west", "produce_shelf":"produce", "magazine_shelf":"magazines", "onsen_soak":"onsen-pool", "onsen_shower":"booth-a", "onsen_bench":"onsen-bench-w", "onsen_locker":"onsen-basket-w", "floor":"tea-rug"}
		var modules: Dictionary = WorldData.scenes.get(scene, {}).get("modules", {})
		var module: String = id if modules.has(id) else aliases.get(id, id.replace("_", "-"))
		if id.begins_with("home_chess_"):
			scene = "world-arcade"
			module = "arcade_xiangqi"
		var file := "res://assets/baked/" + scene + "." + module + ".png"
		if ResourceLoader.exists(file): tex = load(file)
		elif modules.has(module):
			var part: Dictionary = modules[module]
			var ground: Texture2D = load("res://assets/baked/" + scene + ".ground.png")
			var k: float = float(WorldData.layers[scene].get("scale", 2))
			var cropped := AtlasTexture.new()
			cropped.atlas = ground
			cropped.region = Rect2(float(part.x)*k, float(part.y)*k, float(part.w)*k, float(part.h)*k)
			tex = cropped
		else: tex = load("res://assets/baked/qianxia-shop.shopping-bag.png")
	cache[key] = tex
	return tex

static func atlas(file: String, cell: int, cols: int, rows: int) -> AtlasTexture:
	var sheet: Texture2D = load("res://assets/ui/" + file)
	var size := Vector2(sheet.get_width() / float(cols), sheet.get_height() / float(rows))
	var tex := AtlasTexture.new()
	tex.atlas = sheet
	tex.region = Rect2(Vector2(cell % cols, cell / cols) * size, size)
	return tex
