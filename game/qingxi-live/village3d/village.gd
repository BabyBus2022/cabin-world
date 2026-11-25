extends "res://qingxi-live/house/continuous_house.gd"
const Sim=preload("res://qingxi-live/rural_state.gd")
const Session=preload("res://qingxi-live/village3d/session.gd")
const Trade=preload("res://qingxi-live/village3d/trade.gd")
const Architecture=preload("res://qingxi-live/village3d/architecture.gd")
const ToolModel=preload("res://qingxi-live/village3d/tool_model.gd")
const SAVE="user://rural-test-save.json"
const HOUSES=[
	{"id":"seed","name":"种子农资店","at":Vector3(-12,0,-11),"roof":0},
	{"id":"livestock","name":"畜牧用品店","at":Vector3(9,0,-18),"roof":7},
	{"id":"home","name":"我的小屋","at":Vector3(13,0,13),"roof":0},
	{"id":"resident_a","name":"团团的绿篱小屋","at":Vector3(-16,0,12),"roof":7},
	{"id":"resident_b","name":"团团的溪风小屋","at":Vector3(-3,0,26),"roof":0}]
const GATES={"field":Vector3(-34,0,2),"ranch":Vector3(32,0,22),"pond":Vector3(24,0,-31)}
const AREA_NAMES={"field":"种植田地","ranch":"牧场","pond":"鱼塘"}
const SPAWN_VILLAGE=Vector3(-4,0.05,2)
const PATHS=[
	[1.8,Vector2(-36,2),Vector2(-26,1),Vector2(-18,1),Vector2(-6,2),Vector2(0,0),Vector2(5,-4),Vector2(9,-10),Vector2(19,-9),Vector2(24,-16),Vector2(24,-33)],
	[1.4,Vector2(-12,2),Vector2(-12,-2),Vector2(-12,-6)],
	[1.5,Vector2(9,-10),Vector2(9,-13)],
	[1.5,Vector2(0,0),Vector2(1,9),Vector2(3,20),Vector2(13,21),Vector2(23,23),Vector2(34,22)],
	[1.3,Vector2(13,21),Vector2(13,18)],
	[1.4,Vector2(-18,1),Vector2(-25,4),Vector2(-25,21),Vector2(-16,21),Vector2(-16,17)],
	[1.3,Vector2(3,20),Vector2(5,23),Vector2(5,34),Vector2(-3,34),Vector2(-3,31)]]
var sim=Sim.new()
var buildings={}
var building_kind="seed"
var tiles=[]
var garden_props=[]
var mat_cache={}
var billboards=[]
var notice:Label
var menu:PanelContainer
var menu_rows:VBoxContainer
var time_passed=0.0
var message=""
var message_ttl=0.0
var light_mode=1
var sun:DirectionalLight3D
var ambient:WorldEnvironment
var lamps=[]
var window_materials=[]
var decorative_centers=[]
var transitioning=false
var building_locations={}
var pixel_world

func _ready():
	testing="--check-village" in OS.get_cmdline_user_args() or "--capture-village" in OS.get_cmdline_user_args() or "--check-handoff" in OS.get_cmdline_user_args()
	get_tree().set_meta("continuous_rural",true)
	if not Session.consume(get_tree(),sim) and not testing:sim.load_from(SAVE)
	if not testing:sim.settle()
	load_materials();make_light()
	for child in get_children():
		if child is DirectionalLight3D:sun=child
		if child is WorldEnvironment:ambient=child
	make_landscape()
	for spec in HOUSES:
		building_kind=spec.id
		var house=build_building(spec.at);house.spec=spec;buildings[spec.id]=house
		decorate_house(house)
	make_decorations()
	make_player();make_residents()
	residents[0].name="团团 · 种子店主";residents[0].body.position=HOUSES[0].at+Vector3(-2,0.03,2)
	residents[0].route=[Vector2(-14,-9),Vector2(-14,-7.2)]
	residents[1].name="团团 · 畜牧店主";residents[1].body.position=HOUSES[1].at+Vector3(-2,0.03,2)
	residents[1].route=[Vector2(7,-16),Vector2(7,-14.2)]
	add_home_resident("resident_a","团团 · 绿篱住户",0)
	add_home_resident("resident_b","团团 · 溪风住户",1)
	for a in residents:
		for node in a.visual.get_children():
			if node is Label3D:node.text=a.name.trim_prefix("团团 · ")
	player.position=SPAWN_VILLAGE
	var entry=str(get_tree().get_meta("village_entry",""));get_tree().remove_meta("village_entry")
	if GATES.has(entry):player.position=GATES[entry]+(Vector3.ZERO-GATES[entry]).normalized()*2.3+Vector3(0,0.03,0)
	elif entry=="home":player.position=buildings.home.origin+Vector3(0,0.03,7)
	elif sim.data.has("village_position") and int(sim.data.get("village_layout_version",0))==2:
		var p=sim.data.village_position
		if p is Array and p.size()==3:player.position=Vector3(clampf(p[0],-44,44),clampf(p[1],0,LEVEL),clampf(p[2],-44,44))+Vector3(0,0.04,0)
	sim.data.map="village";view.pan_extent=Vector2(48,48)
	scene_title="小屋世界 · 乡村街区";compact_observers=true
	make_ui();make_village_ui();set_daylight();previous_position=player.position;update_view(1)
	pixel_world=preload("res://qingxi-live/village3d/pixel_world.gd").new();add_child(pixel_world);pixel_world.setup(self)
	get_tree().auto_accept_quit=false
	if "--check-village" in OS.get_cmdline_user_args():run_village_checks.call_deferred()
	if "--capture-village" in OS.get_cmdline_user_args():capture_village.call_deferred()

func load_materials():
	var atlas=Image.load_from_file("res://qingxi-live/assets/village-materials/atlas-v2.png")
	garden_props=atlas_parts("props-simple.png",2,2)
	var cell=Vector2i(atlas.get_width()/3,atlas.get_height()/3)
	var names=["slate","plaster","timber","floor","foundation","grass","dirt","terracotta","paving"]
	for i in 9:
		var piece=atlas.get_region(Rect2i(Vector2i(i%3,i/3)*cell,cell));piece.resize(128,128,Image.INTERPOLATE_NEAREST)
		tiles.append(ImageTexture.create_from_image(piece))
		if "--export-materials" in OS.get_cmdline_user_args():piece.save_png(ProjectSettings.globalize_path("res://qingxi-live/assets/village-materials/"+names[i]+".png"))

func material(color:Color)->StandardMaterial3D:
	if tiles.is_empty():return super.material(color)
	var key=color.to_html(false);var index=2
	if key=="647778":index=7 if building_kind in ["livestock","resident_a"] else 0
	elif key=="eee1c6":index=1
	elif key in ["cbb48c","bda77f"]:index=3
	elif key in ["594a37","c7baa0"]:index=8
	elif key=="8d9e70":index=5
	elif key in ["b8ced0","8fa5a1","a5b3b9","efe9d7","f1ecdc","e9e8d7","d9ddd4","9baf9a","81977e"]:
		return super.material(color.darkened(0.25))
	var cache_key=str(index)+key+building_kind
	if mat_cache.has(cache_key):return mat_cache[cache_key]
	var m=StandardMaterial3D.new();m.albedo_texture=tiles[index];m.albedo_color=Color(0.70,0.72,0.72)
	if index==1:m.albedo_color={"seed":Color(0.79,0.83,0.76),"livestock":Color(0.74,0.66,0.55),"home":Color(0.83,0.85,0.82),"resident_a":Color(0.80,0.76,0.67),"resident_b":Color(0.78,0.81,0.72)}.get(building_kind,Color.WHITE)
	m.texture_filter=BaseMaterial3D.TEXTURE_FILTER_NEAREST;m.roughness=1;m.metallic_specular=0;m.diffuse_mode=BaseMaterial3D.DIFFUSE_LAMBERT
	m.uv1_triplanar=true;m.uv1_scale=Vector3.ONE*(0.23 if index in [0,7] else (0.65 if index==3 else 0.35))
	mat_cache[cache_key]=m;return m

func slab(parent:Node3D,rect:Rect2):
	box(parent,Vector3(rect.get_center().x,-0.11,rect.get_center().y),Vector3(rect.size.x,0.22,rect.size.y),Color("cbb48c"),true)

func make_roof():
	roofs=ToolModel.new(self).build(building_kind,building_parent)

func make_furnishings():
	if building_kind not in ["seed","livestock"]:super.make_furnishings();return
	var g=levels[0]
	# A shop retains circulation and stairs, with a customer-side counter and wall storage.
	box(g,Vector3(-4.5,0.5,2.0),Vector3(1.0,1.0,2.2),Color("a9865d"),true)
	box(g,Vector3(-5.5,0.85,-2.5),Vector3(0.6,1.7,3.3),Color("a9865d"),true)
	for z in [-3.5,-2.5,-1.5]:
		box(g,Vector3(-5.25,1.75,z),Vector3(0.45,0.4,0.6),Color("d1be9c"),false)
	box(g,Vector3(4.3,0.4,-4),Vector3(1.8,0.8,0.8),Color("d1be9c"),true)
	box(levels[1],Vector3(-4.8,0.6,-2),Vector3(1.2,1.2,2.0),Color("a9865d"),true)
	box(levels[1],Vector3(-4.8,0.6,2),Vector3(1.2,1.2,2.0),Color("a9865d"),true)
	box(levels[1],Vector3(-2.5,0.4,-3.7),Vector3(1.8,0.8,0.8),Color("a9865d"),true)

func sign_at(text_:String,p:Vector3,parent:Node3D=self):
	var l=Label3D.new();l.text=text_;l.font_size=40;l.pixel_size=0.009;l.position=p;l.billboard=BaseMaterial3D.BILLBOARD_ENABLED;l.modulate=Color("fff2d2");l.outline_modulate=Color("493b2c");l.outline_size=8;parent.add_child(l);return l

func decorate_house(house:Dictionary):
	var light=OmniLight3D.new();light.position=Vector3(0,2,4.5);light.omni_range=8;light.light_color=Color("ffd8a0");house.root.add_child(light);lamps.append(light)
	var label=sign_at(house.spec.name,Vector3(0,2.5,6.3),house.roof);label.font_size=30;label.pixel_size=0.007

func route_mask()->Texture2D:
	var image_=Image.create(768,768,false,Image.FORMAT_R8);image_.fill(Color.BLACK)
	for path in PATHS:
		var curve=Curve2D.new();curve.bake_interval=0.35
		for i in range(1,path.size()):
			var tangent:Vector2=(path[mini(i+1,path.size()-1)]-path[maxi(i-1,1)])*0.18
			curve.add_point(path[i],-tangent if i>1 else Vector2.ZERO,tangent if i<path.size()-1 else Vector2.ZERO)
		for p in curve.get_baked_points():
			var center=(p+Vector2.ONE*48)*8;var radius=float(path[0])*8
			for y in range(maxi(0,int(center.y-radius-2)),mini(768,int(center.y+radius+3))):
				for x in range(maxi(0,int(center.x-radius-2)),mini(768,int(center.x+radius+3))):
					var jitter=sin(x*0.7+y*0.3)*0.7
					var value=clampf((radius+jitter-Vector2(x,y).distance_to(center)+1.5)/3.0,0,1)
					if value>image_.get_pixel(x,y).r:image_.set_pixel(x,y,Color(value,0,0))
	return ImageTexture.create_from_image(image_)

func make_landscape():
	var ground=box(self,Vector3(0,-0.12,0),Vector3(96,0.2,96),Color("8d9e70"),true)
	var m=ShaderMaterial.new();m.shader=load("res://qingxi-live/village3d/ground.gdshader");m.set_shader_parameter("grass_tex",tiles[5]);m.set_shader_parameter("dirt_tex",tiles[6]);m.set_shader_parameter("route_mask",route_mask());ground.material_override=m
	for p in [Vector3(-47,1,0),Vector3(47,1,0),Vector3(0,1,-47),Vector3(0,1,47)]:box(self,p,Vector3(0.2,3,96) if p.x!=0 else Vector3(96,3,0.2),Color("8d9e70"),true).visible=false
	var tree_images=atlas_parts("trees.png",2,2)
	var rng=RandomNumberGenerator.new();rng.seed=92817
	var clusters=[Vector2(-30,-25),Vector2(-12,-28),Vector2(5,-32),Vector2(30,-25),Vector2(33,0),Vector2(32,33),Vector2(16,37),Vector2(-13,37),Vector2(-31,31),Vector2(-34,12),Vector2(-3,-10),Vector2(23,3)]
	for cluster in clusters:
		for i in 4:
			var p=cluster+Vector2(rng.randf_range(-3,3),rng.randf_range(-3,3))
			var tree=billboard(tree_images[(i+int(absf(cluster.x)))%4],Vector3(p.x,0,p.y),rng.randf_range(4.8,6.5));tree.shaded=false
			var body=StaticBody3D.new();body.position=Vector3(p.x,0.6,p.y);add_child(body);var c=CollisionShape3D.new();var shape=CylinderShape3D.new();shape.radius=0.35;shape.height=1.2;c.shape=shape;body.add_child(c)
	for key in GATES:
		var p:Vector3=GATES[key]+Vector3(2.2,0,0) if key=="pond" else GATES[key]+Vector3(0,0,2.6)
		box(self,p+Vector3(0,0.7,0),Vector3(0.12,1.4,0.12),Color("a9865d"),true)
		sign_at(AREA_NAMES[key]+" →",p+Vector3(0,1.8,0))

func atlas_parts(file:String,cols:int,rows:int)->Array:
	var image_=Image.load_from_file("res://qingxi-live/assets/"+file);var cell=Vector2i(image_.get_width()/cols,image_.get_height()/rows);var result=[]
	for i in cols*rows:
		var part=image_.get_region(Rect2i(Vector2i(i%cols,i/cols)*cell,cell));part=part.get_region(part.get_used_rect());result.append(ImageTexture.create_from_image(part))
	return result

func billboard(texture:Texture2D,p:Vector3,height_:float)->Sprite3D:
	var sprite=Sprite3D.new();sprite.texture=texture;sprite.billboard=BaseMaterial3D.BILLBOARD_ENABLED;sprite.alpha_cut=SpriteBase3D.ALPHA_CUT_DISCARD;sprite.pixel_size=height_/texture.get_height();sprite.offset.y=texture.get_height()*0.5;sprite.texture_filter=BaseMaterial3D.TEXTURE_FILTER_NEAREST;sprite.position=p;add_child(sprite);billboards.append(sprite);return sprite

func make_decorations():
	for entry in [[Vector3(-22,0,-11),"柴棚"],[Vector3(-1,0,-21),"种子仓棚"],[Vector3(22,0,-21),"饲料仓棚"],[Vector3(24,0,15),"工具房"],[Vector3(-28,0,12),"柴房"],[Vector3(8,0,29),"小仓棚"]]:
		var p:Vector3=entry[0];building_kind="resident_a"
		decorative_centers.append(p)
		box(self,p+Vector3(0,1.2,0),Vector3(3.2,2.4,3),Color("a9865d"),true).visible=false
		var model=ToolModel.new(self).build("shed",self);model.position=p
		sign_at(entry[1],p+Vector3(0,2.2,1.6))

	preload("res://qingxi-live/village3d/landscape.gd").new(self).build()

func which_house(p:Vector3)->String:
	for id in buildings:
		var q:Vector3=p-buildings[id].origin
		if absf(q.x)<6.4 and q.z> -5.4 and q.z<5.5:return id
	return ""

func track_actor(id:String,p:Vector3):
	var building=which_house(p);building_locations[id]=building
	view.track(id,p-buildings[building].origin if building!="" else Vector3(1000,0,1000),building)

func update_view(dt:float):
	if not is_instance_valid(info):return
	track_actor("player",player.position)
	var p=player.position;var observed_name="玩家"
	for a in residents:
		track_actor(a.id,a.body.position)
		if view.mode==view.Mode.RESIDENT and view.resident_id==a.id:p=a.body.position;observed_name=a.name
	var selected=view.snapshot();var chosen=str(selected.get("building",""))
	if view.mode==view.Mode.FREE and chosen=="":chosen="home";view.free_house=chosen
	in_house=selected.inside;on_upper=selected.upper
	for id in buildings:
		var b:Dictionary=buildings[id];var cut=id==chosen and (in_house or view.mode==view.Mode.FREE)
		b.roof.visible=not cut;b.levels[0].visible=cut;b.levels[1].visible=cut and on_upper
		for ws in b.walls:
			for mesh in ws:mesh.visible=not cut
	portrait.visible=view.actor_visible("player",in_house)
	for i in residents.size():
		var a=residents[i];a.visual.visible=view.actor_visible(a.id,in_house)
		resident_buttons[i].text=("跟随 · " if view.mode==view.Mode.RESIDENT and view.resident_id==a.id else "观察 · ")+a.name+" · "+("二楼" if view.states[a.id].upper else "一楼")
	var focus=p+Vector3(0,2.5,-6.2)
	var desired_zoom=18.0 if in_house or view.mode==view.Mode.FREE else 22.0
	camera.size=desired_zoom if testing else lerpf(camera.size,desired_zoom,minf(1,dt*5))
	if chosen!="" and buildings.has(chosen):
		focus=buildings[chosen].origin+Vector3(0,2.7 if on_upper else 0.6,0.8)
		if view.mode==view.Mode.FREE:focus+=Vector3(view.free_focus.x,0,view.free_focus.y)
	elif view.mode==view.Mode.FREE:focus=Vector3(view.free_focus.x,1,view.free_focus.y)
	camera_focus=focus if testing else camera_focus.lerp(focus,minf(1,dt*5));camera.position=camera_focus+Vector3(0,17,19);camera.look_at(camera_focus)
	info.text=("自由观察" if view.mode==view.Mode.FREE else "跟随 "+observed_name)+" · "+(buildings[chosen].spec.name+(" / 二楼" if on_upper else " / 一楼") if chosen!="" else "村路")
	view_buttons.player.disabled=view.mode==view.Mode.PLAYER;view_buttons.free.disabled=view.mode==view.Mode.FREE
	view_buttons.floor0.disabled=view.mode==view.Mode.FREE and not on_upper;view_buttons.floor1.disabled=view.mode==view.Mode.FREE and on_upper
	for sprite in billboards:
		var delta=player.position-sprite.position;sprite.modulate.a=0.4 if delta.z<0 and delta.z> -4 and absf(delta.x)<1.8 else 1

func _physics_process(dt:float):
	if not is_instance_valid(player):return
	movement_blocked=is_instance_valid(menu) and menu.visible
	super._physics_process(dt)
	time_passed+=dt;message_ttl=maxf(0,message_ttl-dt)
	if time_passed>10:time_passed=0;sim.settle();save_village()
	if is_instance_valid(notice):notice.text=message if message_ttl>0 else interaction_hint()

func interaction_hint()->String:
	if view.mode!=view.Mode.PLAYER:return "P 返回玩家 · 自由观察可用 WASD 移动镜头"
	for key in GATES:
		if player.position.distance_to(GATES[key])<2.8:return "E 前往"+AREA_NAMES[key]
	var id=which_house(player.position)
	if id in ["seed","livestock"]:return "E 与店主交易 · "+Trade.SHOPS[id].name+"（买入 / 收购）"
	if id=="home":return "E 小屋生活 · 做饭 / 休息 / 储物"
	return "WASD 行走 · 房门直接走入 · M 地图 · B 背包 · F9 测试补给"

func make_village_ui():
	var layer=CanvasLayer.new();add_child(layer)
	var bar=PanelContainer.new();bar.position=Vector2(8,389);bar.size=Vector2(752,35);layer.add_child(bar)
	notice=Label.new();notice.add_theme_font_size_override("font_size",11);bar.add_child(notice)
	menu=PanelContainer.new();menu.position=Vector2(254,65);menu.custom_minimum_size=Vector2(440,280);menu.hide();layer.add_child(menu)
	var scroll=ScrollContainer.new();scroll.custom_minimum_size=Vector2(440,280);menu.add_child(scroll);menu_rows=VBoxContainer.new();menu_rows.size_flags_horizontal=Control.SIZE_EXPAND_FILL;scroll.add_child(menu_rows)
	var actions=HBoxContainer.new();actions.position=Vector2(390,8);layer.add_child(actions)
	for entry in [["地图",show_map],["背包",show_bag],["光照",func():light_mode=(light_mode+1)%4;set_daylight()]]:
		var b=Button.new();b.text=entry[0];b.add_theme_font_size_override("font_size",11);b.pressed.connect(entry[1]);actions.add_child(b)

func open_menu(title:String):
	for child in menu_rows.get_children():menu_rows.remove_child(child);child.queue_free()
	menu.show();var l=Label.new();l.text=title;l.add_theme_font_size_override("font_size",14);menu_rows.add_child(l)
	menu_button("关闭",func():menu.hide())
func menu_button(text_:String,fn:Callable):
	var b=Button.new();b.text=text_;b.add_theme_font_size_override("font_size",11);b.pressed.connect(fn);menu_rows.add_child(b)
func say(text_:String):message=text_;message_ttl=5;save_village()
func show_shop(kind:String):
	open_menu(Trade.SHOPS[kind].name+" · %d 币"%sim.data.coins)
	for item in Trade.SHOPS[kind].buy:
		menu_button(Sim.ITEM_NAMES[item]+" · %d 币"%Sim.PRICES[item],func():say(sim.buy(item));show_shop(kind))
	if kind=="livestock":
		for animal in Sim.NAMES:menu_button("幼"+Sim.NAMES[animal]+" · %d 币"%Sim.ANIMAL_PRICE[animal],func():say(sim.buy_animal(animal));show_shop(kind))
	var items=[]
	for item in Trade.SHOPS[kind].sell:items.append(Sim.ITEM_NAMES[item])
	menu_button("出售本店收购的产物："+"、".join(items),func():say(Trade.sell(sim,kind));show_shop(kind))
	if kind=="livestock":menu_button("出售成年猪 · 90 币",func():say(sim.sell_pig());show_shop(kind))
func show_bag():
	open_menu("背包 · %d 币"%sim.data.coins)
	for item in Sim.ITEM_NAMES:
		var l=Label.new();l.text=Sim.ITEM_NAMES[item]+" ×%d"%sim.data.bag[item];l.add_theme_font_size_override("font_size",11);menu_rows.add_child(l)
func show_home():
	open_menu("我的小屋")
	for entry in [["做家常菜（白菜 ×2）",func():say(sim.cook())],["吃饭",func():say(sim.eat())],["休息",func():say(sim.rest())],["存入全部物品",func():say(sim.store_items(false))],["取回全部物品",func():say(sim.store_items(true))]]:menu_button(entry[0],entry[1])
func show_map():
	open_menu("乡村地图 · 快速前往")
	for id in GATES:menu_button(AREA_NAMES[id],func():travel_region(id))
	for spec in HOUSES:menu_button(spec.name,func():set_view("player");player.position=spec.at+Vector3(0,0.05,7);player.velocity=Vector3.ZERO;menu.hide())
func travel_region(id:String):
	if transitioning:return
	transitioning=true;Session.publish(get_tree(),sim,id);save_village();get_tree().change_scene_to_file("res://qingxi-live/main.tscn")
func save_village():
	if not testing:
		sim.data.village_position=[player.position.x,player.position.y,player.position.z];sim.data.village_layout_version=2;sim.save_to(SAVE)
func set_daylight():
	if not is_instance_valid(sun):return
	sun.rotation_degrees=Vector3([-25,-58,-18,-48][light_mode],[-60,-35,65,-40][light_mode],0)
	sun.light_color=[Color("ffe7c2"),Color("fff6e6"),Color("ffb37b"),Color("a4b6de")][light_mode];sun.light_energy=[0.7,0.75,0.65,0.1][light_mode]
	ambient.environment.ambient_light_energy=[0.28,0.36,0.24,0.1][light_mode]
	for lamp in lamps:lamp.light_energy=1.0 if light_mode==3 else 0.12
	for glass in window_materials:glass.emission_energy_multiplier=0.7 if light_mode==3 else 0.0
	for sprite in billboards:sprite.modulate=[Color(0.95,0.94,0.88),Color.WHITE,Color(0.9,0.75,0.66),Color(0.27,0.34,0.48)][light_mode]

func add_home_resident(house:String,title:String,floor_:int):
	var source:Dictionary=residents[0];var a=source.duplicate();var body=source.body.duplicate()
	add_child(body);a.body=body;a.visual=body.get_node(source.body.get_path_to(source.visual));a.sprite=body.get_node(source.body.get_path_to(source.sprite))
	a.id="resident%d"%residents.size();a.name=title;a.phase=0.0;a.pause=0.3;a.distance=0.0;a.next=1
	var origin:Vector3=buildings[house].origin;var z=2.0 if floor_==0 else -1.0
	body.position=origin+Vector3(-2,floor_*LEVEL+0.03,z)
	a.route=[Vector2(origin.x-2,origin.z+z),Vector2(origin.x-3,origin.z+z)]
	residents.append(a)
func _unhandled_key_input(event:InputEvent):
	if not event.is_pressed() or event.is_echo():return
	if event.keycode==KEY_ESCAPE:
		if menu.visible:menu.hide()
		else:save_village();get_tree().quit()
		return
	if event.keycode==KEY_M:show_map();return
	if event.keycode==KEY_B:show_bag();return
	if event.keycode==KEY_F4:pixel_world.active=not pixel_world.active;return
	if event.keycode==KEY_F9:say(sim.supplies());return
	if event.keycode==KEY_F8:sim.advance(3600);say("测试：生产推进 1 小时");return
	if event.keycode==KEY_R:player.position=SPAWN_VILLAGE;player.velocity=Vector3.ZERO;set_view("player");return
	if event.keycode==KEY_O and not menu.visible:
		var next=0
		for i in residents.size():
			if view.mode==view.Mode.RESIDENT and view.resident_id==residents[i].id:next=(i+1)%residents.size()
		set_view(residents[next].id);return
	if event.keycode==KEY_E and view.mode==view.Mode.PLAYER and not menu.visible:
		for id in GATES:
			if player.position.distance_to(GATES[id])<2.8:travel_region(id);return
		var house=which_house(player.position)
		if house in ["seed","livestock"]:show_shop(house)
		elif house=="home":show_home()
		return
	if not menu.visible:super._unhandled_key_input(event)
func _notification(what):
	if what==NOTIFICATION_WM_CLOSE_REQUEST:save_village();get_tree().quit()

func run_village_checks():
	await get_tree().physics_frame
	verify(buildings.size()==5,"Missing functional houses")
	verify(decorative_centers.size()==6,"Missing clustered outbuildings")
	# Follow the actual road bends; decorations must not obstruct the main route or door branches.
	for path in PATHS:
		player.position=Vector3(path[1].x,0.05,path[1].y);player.velocity=Vector3.ZERO
		for i in range(2,path.size()):verify(await walk_to(path[i],900),"Road obstructed at %s, player %s"%[path[i],player.position])
	for p in decorative_centers:
		verify(which_house(p)=="","Decorative hut mistakenly enterable")
		var ray=PhysicsRayQueryParameters3D.create(p+Vector3(0,1,3),p+Vector3(0,1,0))
		verify(not get_world_3d().direct_space_state.intersect_ray(ray).is_empty(),"Decorative hut missing collision")
	# Walk from the road into every actual doorway and out again, without room loading.
	for spec in HOUSES:
		player.position=spec.at+Vector3(0,0.03,7);player.velocity=Vector3.ZERO
		verify(await walk_to(Vector2(spec.at.x,spec.at.z+3)),"Door blocked: "+spec.id)
		verify(which_house(player.position)==spec.id,"Wrong building selected")
		verify(not buildings[spec.id].roof.visible,"Entered building roof still covers interior")
		for other in buildings:
			if other!=spec.id:verify(buildings[other].roof.visible,"Unrelated house roof hidden")
		verify(await walk_to(Vector2(spec.at.x,spec.at.z+7)),"Exit blocked: "+spec.id)
	player.position=buildings.home.origin+Vector3(0,0.03,3)
	for p in [Vector2(2.3,3),Vector2(2.3,4.35),Vector2(4.3,4.35),Vector2(4.3,-3.35)]:verify(await walk_to(Vector2(buildings.home.origin.x,buildings.home.origin.z)+p),"Home staircase blocked")
	verify(on_upper and absf(player.position.y-LEVEL)<0.15,"Home upstairs view incorrect")
	for p in [Vector2(4.3,4.35),Vector2(2.3,4.35),Vector2(2.3,3),Vector2(0,3),Vector2(0,7)]:verify(await walk_to(Vector2(buildings.home.origin.x,buildings.home.origin.z)+p),"Home stairs return blocked")
	verify(not on_upper and not in_house,"Home return retained upper-floor view")
	set_view(residents[3].id);update_view(1)
	verify(on_upper and not buildings.resident_b.roof.visible and buildings.home.roof.visible,"Resident view cut wrong house/floor")
	set_view(residents[0].id);update_view(1)
	verify(not on_upper and not buildings.seed.roof.visible and buildings.resident_b.roof.visible,"Shopkeeper view did not restore former house")
	set_view("player");update_view(1)
	var at=player.position;var before_coins=int(sim.data.coins);var before_seed=int(sim.data.bag.seed)
	show_shop("seed");test_motion=Vector2.RIGHT
	for i in 20:await get_tree().physics_frame
	test_motion=Vector2.ZERO
	verify(player.position.distance_to(at)<0.1 and view.mode==view.Mode.PLAYER,"Shop menu moved player or changed observer")
	for button in menu_rows.get_children():
		if button is Button and button.text.begins_with("白菜种子"):button.pressed.emit();break
	verify(sim.data.bag.seed==before_seed+1 and sim.data.coins==before_coins-Sim.PRICES.seed,"Shop purchase button failed")
	menu.hide()
	var state=Sim.new();state.data.bag.veg=2;state.data.bag.milk=2;state.data.bag.fish=2
	Trade.sell(state,"seed");verify(state.data.bag.veg==0 and state.data.bag.milk==2 and state.data.bag.fish==2,"Seed shop sold unrelated produce")
	Trade.sell(state,"fish");verify(state.data.bag.fish==0 and state.data.bag.milk==2,"Fish shop sold unrelated produce")
	Trade.sell(state,"livestock");verify(state.data.bag.milk==0,"Livestock collection failed")
	Session.publish(get_tree(),state,"field");var restored=Sim.new();verify(Session.consume(get_tree(),restored),"Missing region handoff")
	verify(restored.data.coins==state.data.coins and restored.livestock.data==restored.data.livestock,"Simulation changed during scene handoff")
	print("VILLAGE_CHECK ","PASS" if failures.is_empty() else "FAIL"," failures=",JSON.stringify(failures));get_tree().quit(0 if failures.is_empty() else 1)

func capture_village():
	await shot("village-street")
	player.position=buildings.seed.origin+Vector3(0,0.03,10);update_view(1);await shot("village-seed-exterior")
	verify(await walk_to(Vector2(buildings.seed.origin.x,buildings.seed.origin.z+3)),"Shop capture door blocked");await shot("village-seed-interior")
	player.position=buildings.home.origin+Vector3(0,0.03,7);update_view(1);await shot("village-home")
	light_mode=3;set_daylight();await shot("village-night")
	print("VILLAGE_CAPTURE ","PASS" if failures.is_empty() else "FAIL");get_tree().quit(0 if failures.is_empty() else 1)
