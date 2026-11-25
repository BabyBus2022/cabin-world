extends RefCounted
const DIR="res://qingxi-live/village-center/harvest/"
static var catalog:Dictionary={}
static var textures:Dictionary={}

static func book()->Dictionary:
	if catalog.is_empty():catalog=JSON.parse_string(FileAccess.get_file_as_string(DIR+"catalog.json"))
	return catalog

static func texture(key:String)->Texture2D:
	if not textures.has(key):
		var image=Image.new()
		if image.load_png_from_buffer(FileAccess.get_file_as_bytes(DIR+key+".png"))!=OK:return null
		textures[key]=ImageTexture.create_from_image(image)
	return textures[key]

static func seed_count(bag:Dictionary)->int:
	var count=0
	for key in book().produce:count+=int(bag.get(key,0))
	return count

static func seed_for(bag:Dictionary,index:int)->String:
	var types=book().produce.keys()
	for offset in types.size():
		var key=types[(index+offset)%types.size()]
		if bag.get(key,0)>0:return key
	return ""

static func recipe_id(value:String)->String:
	for key in book().recipes:
		if key==value or book().recipes[key].name==value:return key
	return ""

static func ingredients(recipe:Dictionary)->String:
	var parts=PackedStringArray()
	for item in recipe["items"]:parts.append("%s ×%d"%[book().names[item],recipe["items"][item]])
	return "、".join(parts)

static func portions(bag:Dictionary,recipe:Dictionary)->Dictionary:
	var used={}
	var keys=bag.keys()
	keys.sort()
	for item in recipe["items"]:
		var need=int(recipe["items"][item])
		for k in keys:
			if k!=item and not str(k).begins_with(item+":q") and not (item=="fish" and str(k).begins_with("catch:")):continue
			var amount=mini(need,int(bag[k]))
			if amount<=0:continue
			used[k]=amount
			need-=amount
			if need==0:break
		if need>0:return {}
	return used

static func cook(sim,key:String)->String:
	var recipe:Dictionary=book().recipes.get(key,{})
	if recipe.is_empty():return "请从食谱中选一道菜。"
	var used=portions(sim.data.bag,recipe)
	if used.is_empty():return "食材不足，需要"+ingredients(recipe)
	for item in used:sim.data.bag[item]-=used[item]
	sim.data.bag[key]=int(sim.data.bag.get(key,0))+1
	return "做好了%s ×1。"%recipe.name

static func edible(key:String)->bool:
	return book().fruitEnergy.has(key) or book().recipes.has(key)

static func eat(sim,key:String)->String:
	if not edible(key) or sim.data.bag.get(key,0)<=0:return "背包里没有这份食物。"
	var energy=sim.data.energy
	if energy>=100:return "精力已满，可以留到稍后再吃。"
	var gain=int(book().fruitEnergy[key]) if book().fruitEnergy.has(key) else int(book().recipes[key].energy)
	sim.data.bag[key]-=1
	sim.data.energy=mini(100,energy+gain)
	return "吃了%s，恢复 %d 点精力。"%[sim.ITEM_NAMES[key],sim.data.energy-energy]

static func shelf(world,group:String):
	world.open_menu="recipes"
	world.clear_menu("农家灶台 · "+group)
	var tabs=HBoxContainer.new()
	world.overlay_body.add_child(tabs)
	for g in book().groups:
		var b=world.button(g,shelf.bind(world,g))
		b.disabled=g==group
		tabs.add_child(b)
	var available=[]
	var missing=[]
	var recipes:Dictionary=book().recipes.duplicate()
	if group=="蔬菜":
		recipes["meal"]={"name":"传统家常菜","group":group,"items":{"veg":2}}
	for key in recipes:
		var candidate=recipes[key]
		if candidate.group!=group:continue
		if portions(world.sim.data.bag,candidate).is_empty():missing.append(key)
		else:available.append(key)
	var grid=GridContainer.new()
	grid.columns=3
	grid.add_theme_constant_override("h_separation",6)
	grid.add_theme_constant_override("v_separation",6)
	world.overlay_body.add_child(grid)
	for key in available+missing:
		var recipe=recipes[key]
		var card=world.button("",prepare.bind(world,key,group))
		card.custom_minimum_size=Vector2(128,100)
		card.size_flags_horizontal=Control.SIZE_EXPAND_FILL
		card.disabled=key in missing
		card.accessibility_name=recipe.name
		card.tooltip_text=recipe.name+" · "+ingredients(recipe)+("（食材不足）" if card.disabled else "")
		card.add_theme_stylebox_override("normal",world.KIT.frame("slot"))
		card.add_theme_stylebox_override("hover",world.KIT.frame("slot_hi"))
		card.add_theme_stylebox_override("pressed",world.KIT.frame("slot_hi"))
		card.add_theme_stylebox_override("disabled",world.KIT.frame("slot_off"))
		grid.add_child(card)
		var stack=VBoxContainer.new()
		card.add_child(stack)
		stack.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
		stack.mouse_filter=Control.MOUSE_FILTER_IGNORE
		stack.alignment=BoxContainer.ALIGNMENT_CENTER
		stack.add_theme_constant_override("separation",1)
		var pic=TextureRect.new()
		pic.custom_minimum_size=Vector2(0,48)
		pic.expand_mode=TextureRect.EXPAND_IGNORE_SIZE
		pic.stretch_mode=TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		pic.texture=world.KIT.icon_texture("meal") if key=="meal" else texture(key)
		pic.mouse_filter=Control.MOUSE_FILTER_IGNORE
		stack.add_child(pic)
		var title=world.KIT.label(recipe.name,14,world.KIT.INK,true)
		title.horizontal_alignment=HORIZONTAL_ALIGNMENT_CENTER
		title.mouse_filter=Control.MOUSE_FILTER_IGNORE
		stack.add_child(title)
		var items=world.KIT.label(ingredients(recipe).replace("、","  ").replace(" ×","×"),11,world.KIT.INK2)
		items.horizontal_alignment=HORIZONTAL_ALIGNMENT_CENTER
		items.mouse_filter=Control.MOUSE_FILTER_IGNORE
		stack.add_child(items)

static func prepare(world,key:String,group:String):
	world.perform(world.sim.cook() if key=="meal" else cook(world.sim,key))
	shelf(world,group)

static func recipe_list()->Dictionary:
	var result={}
	for group in book().groups:result[group]=[]
	for row in book().recipes.values():result[row.group].append(row.name)
	return result

