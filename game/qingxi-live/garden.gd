extends Node2D
## Independent visual prototype. No VADS, saves, network or live resident data.
const WORLD=Rect2(0,0,1280,900)
const SPAWN=Vector2(620,579)
const CELL=32
const FARM_ORIGIN=Vector2(850,520)
const BODY_UNIT_ON_SCREEN=18.0
const CHARACTER_ROOT="res://qingxi-live/assets/studio-whale/"
const HOUSE_WIDTH=280.0
const HOUSE_BASE=Vector2(700,492)
const PORCH=Rect2(590,482,54,6)
const STAIRS=Rect2(584,488,60,12)
const DOOR=Vector2(620,486)
var scenery:Node2D
var shadow_root:Node2D
var player:Node2D
var portrait:Sprite2D
var contact_shadow:Polygon2D
var camera:Camera2D
var ground_material:ShaderMaterial
var tree_texture:Array[Texture2D]=[]
var prop_texture:Array[Texture2D]=[]
var detail_texture:Array[Texture2D]=[]
var crop_texture:Array[Texture2D]=[]
var surfaces:Array[ShaderMaterial]=[]
var cast_shadows:Array[Dictionary]=[]
var trees:Array[Dictionary]=[]
var solids:Array[Rect2]=[]
var fields:Array[Dictionary]=[]
var clips={}
var character_pack={}
var character_source=CHARACTER_ROOT
var idle_texture:Texture2D
var clip_cache={}
var active_action=""
var action_elapsed=0.0
var idle_elapsed=0.0
var terrain_parts:Array[Texture2D]=[]
var status:Label
var subtitle:Label
var clock_label:Label
var time_slider:HSlider
var selected_cell=-1
var facing=0
var elapsed=0.0
var daylight=0.48
var auto_light=false
var paused_for_capture=false
var harvested=0
var current_seed=17
var sun_tip:Label
var message_until=0.0
var last_message=""
var contact_ink=Color(0.19,0.25,0.25,0.22)
var lighting_label="晴昼"
var night_level=0.0
var ground_tint=Color.WHITE
var roof:Sprite2D
var tree_placements:Array[Vector2]=[]

func _ready():
	texture_filter=CanvasItem.TEXTURE_FILTER_NEAREST
	load_assets()
	make_ground()
	shadow_root=Node2D.new();add_child(shadow_root)
	scenery=Node2D.new();scenery.y_sort_enabled=true;add_child(scenery)
	make_scene()
	make_actor()
	make_ui()
	set_light(0.48)
	update_camera(true)
	print("PIXEL_GARDEN_READY trees=",trees.size()," tree_types=4 cells=",fields.size()," no_live_data=true")
	if "--check" in OS.get_cmdline_user_args():run_checks.call_deferred()
	if "--capture" in OS.get_cmdline_user_args():capture.call_deferred()
	if "--check-actor-size" in OS.get_cmdline_user_args():check_actor_size.call_deferred()
	if "--check-display" in OS.get_cmdline_user_args():check_display.call_deferred()

func check_display():
	await get_tree().process_frame;await RenderingServer.frame_post_draw
	var rendered=get_viewport().get_texture().get_size()
	var window_size=DisplayServer.window_get_size()
	var okay=rendered.x>=window_size.x and rendered.y>=window_size.y
	print("CHARACTER_DISPLAY rendered=",rendered," window=",window_size," full_resolution=",okay)
	get_tree().quit(0 if okay else 1)

func visible_height()->float:
	return portrait.texture.get_image().get_used_rect().size.y*portrait.scale.y

func check_actor_size():
	paused_for_capture=true
	show_idle();var idle_height=visible_height();var failed=false
	for direction in 4:
		facing=direction;var at=0.0;var ratios:Array[float]=[]
		for duration in clips["walk-%d"%direction].durationsMs:
			elapsed=at+float(duration)/2000.0;animate_walk()
			var ratio=visible_height()/idle_height;ratios.append(ratio)
			if ratio<0.80 or ratio>1.20:failed=true
			at+=float(duration)/1000.0
		print("ACTOR_SIZE direction=",direction," frames=",ratios.size()," idle=",idle_height," min_ratio=",ratios.min()," max_ratio=",ratios.max())
	print("ACTOR_SIZE_FAIL" if failed else "ACTOR_SIZE_PASS")
	get_tree().quit(1 if failed else 0)

func full_image(file:String)->Image:
	return Image.load_from_file("res://qingxi-live/assets/"+file)

func trim_image(img:Image)->Image:
	var lo=img.get_size();var hi=Vector2i.ZERO
	for y in img.get_height():
		for x in img.get_width():
			if img.get_pixel(x,y).a>0.5:
				lo=lo.min(Vector2i(x,y));hi=hi.max(Vector2i(x,y))
	return img.get_region(Rect2i(lo,hi-lo+Vector2i.ONE))

func parts(file:String,trim:bool)->Array[Texture2D]:
	var img=full_image(file)
	var result:Array[Texture2D]=[]
	var size_=Vector2i(img.get_width()/2,img.get_height()/2)
	for i in 4:
		var piece=img.get_region(Rect2i(Vector2i(i%2,i/2)*size_,size_))
		if trim:
			var bound=Rect2i()
			var lo=size_;var hi=Vector2i.ZERO
			for y in piece.get_height():
				for x in piece.get_width():
					if piece.get_pixel(x,y).a>0.5:
						lo=lo.min(Vector2i(x,y));hi=hi.max(Vector2i(x,y))
			bound=Rect2i(lo,hi-lo+Vector2i.ONE)
			piece=piece.get_region(bound)
		result.append(ImageTexture.create_from_image(piece))
	return result

func load_assets():
	tree_texture=parts("trees.png",true)
	prop_texture=parts("props-simple.png",true)
	detail_texture=parts("detail-props.png",true)
	crop_texture=parts("cabbage.png",false)
	terrain_parts=parts("terrain.png",false)
	load_character_assets()

func load_character_assets():
	var host=get_tree().get_meta("qingxi_world_host",false)
	character_source=host.owner_art_root() if host else CHARACTER_ROOT
	character_pack=JSON.parse_string(FileAccess.get_file_as_string(character_source+"character.json"))
	clips=character_pack.actions
	idle_texture=character_texture(character_source+character_pack.idle.file)

## 2026-11-19 Claude (Cabin World host): inside Cabin World the player's frames are Cabin World's own
## imported textures (always the live art, no raw copies); standalone reads the files as before.
func character_texture(path:String)->Texture2D:
	if get_tree().has_meta("qingxi_world_host") and ResourceLoader.exists(path):return load(path)
	return ImageTexture.create_from_image(Image.load_from_file(path))

func clip_frames(key:String)->Array[Texture2D]:
	if clip_cache.has(key):return clip_cache[key]
	var frames:Array[Texture2D]=[]
	# 2026-11-19 Claude (Cabin World host): Cabin World's newer player packs keep an action as one
	# strip ("strip": "<key>/motion.png", "columns": n, frames left to right, top to bottom).
	if clips[key].has("strip"):
		var sheet:Texture2D=character_texture(character_source+str(clips[key].strip))
		var count:=int(clips[key].count);var columns:=maxi(1,int(clips[key].get("columns",count)))
		var rows:=ceili(float(count)/columns)
		var cell:=Vector2(sheet.get_width()/float(columns),sheet.get_height()/float(rows))
		for i in count:
			var frame:=AtlasTexture.new();frame.atlas=sheet;frame.filter_clip=true
			frame.region=Rect2(Vector2(i%columns,i/columns)*cell,cell)
			frames.append(frame)
		clip_cache[key]=frames
		return frames
	for i in int(clips[key].count):
		frames.append(character_texture(character_source+"%s/%03d.png"%[key,i]))
	clip_cache[key]=frames
	return frames

func light_material()->ShaderMaterial:
	var m=ShaderMaterial.new();m.shader=load("res://qingxi-live/foliage.gdshader");surfaces.append(m);return m

func make_ground():
	var floor_=Polygon2D.new();floor_.polygon=PackedVector2Array([Vector2.ZERO,Vector2(1280,0),Vector2(1280,900),Vector2(0,900)])
	ground_material=ShaderMaterial.new();ground_material.shader=load("res://qingxi-live/ground.gdshader")
	var grasses=parts("grass-variants.png",false)
	for i in 4:ground_material.set_shader_parameter(["grass_tex","grass_b","grass_c","grass_d"][i],grasses[i])
	ground_material.set_shader_parameter("dirt_tex",terrain_parts[1])
	floor_.material=ground_material;floor_.z_index=-10;add_child(floor_)

func object(tex:Texture2D,p:Vector2,width_:float,collision:Rect2=Rect2(),shadow=true,kind="prop")->Sprite2D:
	var holder=Node2D.new();holder.position=p;scenery.add_child(holder)
	var s=Sprite2D.new();s.texture=tex;s.centered=false;s.scale=Vector2.ONE*width_/tex.get_width();s.position=Vector2(-width_/2,-tex.get_height()*s.scale.y)
	s.material=light_material();holder.add_child(s)
	if collision.size!=Vector2.ZERO:solids.append(Rect2(p+collision.position,collision.size))
	if kind!="tree" and width_>=36 and (collision.size!=Vector2.ZERO or kind=="house"):
		add_foot_contact(tex,p,width_)
	if shadow:
		var sh=Polygon2D.new();shadow_root.add_child(sh)
		var height=tex.get_height()*s.scale.y
		var outline:PackedVector2Array
		if kind=="tree":
			outline=PackedVector2Array([Vector2(-0.06,0),Vector2(-0.07,-0.25),Vector2(-0.36,-0.34),Vector2(-0.49,-0.52),Vector2(-0.45,-0.74),Vector2(-0.25,-0.91),Vector2(0.03,-1),Vector2(0.34,-0.88),Vector2(0.49,-0.64),Vector2(0.39,-0.4),Vector2(0.07,-0.24),Vector2(0.06,0)])
		elif kind=="house":
			outline=PackedVector2Array([Vector2(-0.42,0),Vector2(-0.5,-0.52),Vector2(-0.22,-0.88),Vector2(0.22,-0.88),Vector2(0.5,-0.52),Vector2(0.42,0)])
		else:
			outline=PackedVector2Array([Vector2(-0.35,0),Vector2(-0.5,-0.38),Vector2(-0.34,-0.82),Vector2(0.3,-0.82),Vector2(0.5,-0.38),Vector2(0.34,0)])
		cast_shadows.append({"polygon":sh,"base":p,"outline":outline,"width":width_,"height":height})
	return s

func add_foot_contact(tex:Texture2D,base:Vector2,width_:float):
	# Contact follows the actual opaque foot/stair pixels, rather than a detached
	# generic cast-shadow triangle. Raised porch gaps keep their original shape.
	var image=tex.get_image();var factor=width_/image.get_width()
	var step_=maxi(1,int(2.0/factor))
	var points=PackedVector2Array()
	for x in range(0,image.get_width(),step_):
		var bottom=-1
		for y in range(image.get_height()-1,int(image.get_height()*0.82),-1):
			if image.get_pixel(x,y).a>0.5:bottom=y;break
		if bottom<0:continue
		var foot=base+Vector2(x*factor-width_/2,(bottom-image.get_height())*factor)
		points.append(foot+Vector2(0,0));points.append(foot+Vector2(step_*factor,0))
	var contact=Node2D.new();contact.set_script(load("res://qingxi-live/foot_contact.gd"));contact.points=points;shadow_root.add_child(contact)

func make_scene():
	roof=object(ImageTexture.create_from_image(trim_image(full_image("house-modern-japanese.png"))),HOUSE_BASE,HOUSE_WIDTH,Rect2(),true,"house")
	# The recessed entrance and the main facade have different ground footprints.
	solids.append(Rect2(578,410,72,66))
	solids.append(Rect2(650,410,174,73))
	# Sort at the facade, so a resident on the raised porch remains in front.
	roof.get_parent().position.y=476;roof.position.y+=16
	roof.material.set_shader_parameter("emissive_mode",3.0)
	# Forecourt decor leaves a generous, tested door-to-road route.
	object(prop_texture[1],Vector2(476,500),58,Rect2(-24,-11,48,17))
	object(prop_texture[1],Vector2(757,501),51,Rect2(-22,-10,44,16))
	var lantern=object(prop_texture[2],Vector2(443,545),43,Rect2(-15,-9,30,14))
	lantern.material.set_shader_parameter("emissive_mode",2.0)
	object(prop_texture[3],Vector2(365,592),63,Rect2(-26,-11,52,18))
	# Stable seeded placements: species/shape changes, not per-frame random jitter.
	var rng=RandomNumberGenerator.new();rng.seed=17011
	var locations=[Vector2(345,484),Vector2(966,487),Vector2(1075,550),Vector2(1047,322),Vector2(885,275),Vector2(340,281),Vector2(202,385),Vector2(177,570),Vector2(232,755),Vector2(405,788),Vector2(870,792),Vector2(1072,754),Vector2(1180,184),Vector2(108,160),Vector2(530,164)]
	for i in locations.size():
		var p:Vector2=locations[i]+Vector2(rng.randi_range(-12,12),rng.randi_range(-8,8))
		var kind=i%4
		var width_=rng.randi_range(107,137) if kind!=2 else rng.randi_range(136,158)
		var tree=object(tree_texture[kind],p,width_,Rect2(-8,-6,16,12),true,"tree")
		trees.append({"sprite":tree,"base":p,"width":width_,"kind":kind})
		tree_placements.append(p)
	for y in 3:
		for x in 4:
			var p=FARM_ORIGIN+Vector2(x,y)*CELL
			var plant=object(crop_texture[3],p+Vector2(16,28),29,Rect2(),false)
			plant.visible=false
			fields.append({"rect":Rect2(p,Vector2(CELL,CELL)),"state":-1,"timer":0.0,"sprite":plant})
	# Two initial examples show that a mature plant stays inside its own 32px cell.
	fields[0].state=3;fields[0].sprite.visible=true
	fields[5].state=1;fields[5].timer=0.01;refresh_crop(5)
	make_details()

func make_details():
	var rng=RandomNumberGenerator.new();rng.seed=170113
	# Small accents, not a second carpet of noise. Keep the travel lane clear.
	for i in 32:
		var p=Vector2(rng.randi_range(200,1110),rng.randi_range(300,740))
		if blocked(p) or Rect2(FARM_ORIGIN-Vector2(22,22),Vector2(172,140)).has_point(p):continue
		var lane=621+sin(p.x*0.008)*13+sin(p.x*0.019)*4
		if absf(p.y-lane)<28 or (absf(p.x-620)<32 and p.y>470 and p.y<630):continue
		var kind=0 if i%6==0 else (2 if i%5==0 else 1)
		object(detail_texture[kind],p,rng.randi_range(7,12) if kind!=2 else 12,Rect2(),false)
	for p in [Vector2(476,523),Vector2(764,527),Vector2(480,579),Vector2(567,602),Vector2(670,582)]:
		object(detail_texture[0],p,9,Rect2(),false)
	var rim=farm_outline(Vector2(81,65))
	for i in [3,12,21,30,39,48,57]:
		object(detail_texture[3 if i%2==1 else 1],rim[i],7,Rect2(),false)

func make_actor():
	player=Node2D.new();player.position=SPAWN;scenery.add_child(player)
	contact_shadow=Polygon2D.new();var contact_points=PackedVector2Array()
	for i in 12:contact_points.append(Vector2(cos(i*TAU/12)*10,sin(i*TAU/12)*3))
	contact_shadow.polygon=contact_points;contact_shadow.color=contact_ink;player.add_child(contact_shadow)
	portrait=Sprite2D.new();portrait.centered=false
	portrait.texture_filter=CanvasItem.TEXTURE_FILTER_LINEAR
	var actor_material=ShaderMaterial.new();actor_material.shader=load("res://qingxi-live/character.gdshader")
	var host=get_tree().get_meta("qingxi_world_host",false)
	if host and host.owner_uses_travel_outfit():actor_material.set_shader_parameter("owner_palette",true)
	portrait.material=actor_material;surfaces.append(actor_material)
	player.add_child(portrait);show_idle()
	camera=Camera2D.new();camera.position=SPAWN+Vector2(0,-150);camera.position_smoothing_enabled=false;add_child(camera)

func show_idle():
	var meta:Dictionary=character_pack.idle
	var factor=BODY_UNIT_ON_SCREEN/float(meta.unitPixels)
	portrait.texture=idle_texture;portrait.scale=Vector2.ONE*factor;portrait.position=-Vector2(meta.anchor[0],meta.anchor[1])*factor
	apply_elevation()

func qingxi_save_path(file:String)->String:
	var host=get_tree().get_meta("qingxi_world_host",false)
	return host.profile_path(file.get_file()) if host else file

func animate_walk():
	show_action("walk-%d"%facing,elapsed)

func show_action(key:String,time_:float)->bool:
	if not clips.has(key):
		show_idle()
		return false
	var c:Dictionary=clips[key]
	var frames=clip_frames(key)
	var total=0.0
	for d in c.durationsMs:total+=float(d)/1000.0
	var t=fmod(time_,total) if c.loop else minf(time_,total-0.001)
	var index=0
	for d in c.durationsMs:
		if t<float(d)/1000.0:break
		t-=float(d)/1000.0;index+=1
	var calibration:Dictionary=c.sizeCalibration
	var factor=BODY_UNIT_ON_SCREEN/float(calibration.unitPixels)
	portrait.texture=frames[mini(index,frames.size()-1)];portrait.scale=Vector2.ONE*factor
	portrait.position=-Vector2(calibration.anchor[0],calibration.anchor[1])*factor
	apply_elevation()
	return time_<total

func floor_height(p:Vector2)->float:
	if PORCH.has_point(p):return 12.0
	if STAIRS.has_point(p):
		if p.y>=496:return 3.0
		if p.y>=492:return 7.0
		return 12.0
	return 0.0

func apply_elevation():
	var height=floor_height(player.position)
	portrait.position.y-=height
	contact_shadow.position.y=-height
	contact_shadow.color=contact_ink

func can_step(from:Vector2,to:Vector2)->bool:
	return not blocked(to) and absf(floor_height(to)-floor_height(from))<=5.1

func play_action(key:String):
	if clips.has(key):active_action=key;action_elapsed=0.0

func blocked(p:Vector2)->bool:
	if not WORLD.grow(-20).has_point(p):return true
	for box in solids:
		if box.grow(6).has_point(p):return true
	return false

func move_actor(delta:Vector2):
	var steps=maxi(1,int(ceil(delta.length()/3.0)))
	var step=delta/steps
	for i in steps:
		var p=player.position+Vector2(step.x,0)
		if can_step(player.position,p):player.position=p
		p=player.position+Vector2(0,step.y)
		if can_step(player.position,p):player.position=p

func update_camera(instant=false):
	var target=player.position+Vector2(0,-150)
	target.x=clampf(target.x,384,896);target.y=clampf(target.y,216,684)
	camera.position=target.round() if instant else camera.position.lerp(target,0.16).round()

func refresh_crop(index:int):
	var f:Dictionary=fields[index]
	f.sprite.visible=f.state>=0
	if f.state>=0:f.sprite.texture=crop_texture[mini(f.state,3)]

func cell_at(p:Vector2)->int:
	var local=p-FARM_ORIGIN
	if local.x<0 or local.y<0 or local.x>=4*CELL or local.y>=3*CELL:return -1
	return int(local.y/CELL)*4+int(local.x/CELL)

func facing_vector()->Vector2:
	return [Vector2.DOWN,Vector2.LEFT,Vector2.RIGHT,Vector2.UP][facing]

func interact():
	if selected_cell>=0:
		var f:Dictionary=fields[selected_cell]
		if f.state<0:
			f.state=0;notify("播种成功 · 每格只种一株，按 E 浇水")
		elif f.state==0:
			f.state=1;f.timer=0.01;notify("已浇水 · 演示中约 12 秒成熟")
		elif f.state==3:
			harvested+=1;f.state=-1;f.timer=0.0;notify("收获白菜 × 1 · 这一格可以重新播种")
		else:notify("正在生长 · 稍等一会儿")
		refresh_crop(selected_cell)
		play_action("pick_up-%d"%facing)
	elif player.position.distance_to(DOOR)<48:notify("沿左侧台阶可登上入口平台 · 房门关闭，室内与二楼暂未开放")
	else:notify("到田边面向田格，按 E 播种、浇水或收获")

func notify(message:String):
	last_message=message;message_until=elapsed+4.5

func _physics_process(dt):
	if paused_for_capture:return
	elapsed+=dt
	var v=Vector2(float(Input.is_physical_key_pressed(KEY_D) or Input.is_physical_key_pressed(KEY_RIGHT))-float(Input.is_physical_key_pressed(KEY_A) or Input.is_physical_key_pressed(KEY_LEFT)),float(Input.is_physical_key_pressed(KEY_S) or Input.is_physical_key_pressed(KEY_DOWN))-float(Input.is_physical_key_pressed(KEY_W) or Input.is_physical_key_pressed(KEY_UP)))
	if v!=Vector2.ZERO:
		active_action="";idle_elapsed=0.0
		facing=(2 if v.x>0 else 1) if absf(v.x)>absf(v.y) else (0 if v.y>0 else 3)
		move_actor(v.normalized()*dt*(120 if Input.is_physical_key_pressed(KEY_SHIFT) else 77));animate_walk()
	else:
		idle_elapsed+=dt
		if active_action!="":
			action_elapsed+=dt
			if not show_action(active_action,action_elapsed):active_action="";idle_elapsed=0.0
		elif idle_elapsed>7.0:play_action("idle_look-%d"%facing)
		else:show_idle()
	update_camera()
	selected_cell=cell_at(player.position+facing_vector()*23)
	if selected_cell<0:selected_cell=cell_at(player.position)
	for i in fields.size():
		var f:Dictionary=fields[i]
		if f.timer>0 and f.state>0 and f.state<3:
			f.timer+=dt
			var next=2 if f.timer<12 else 3
			if f.timer<5:next=1
			if next!=f.state:f.state=next;refresh_crop(i)
	for t in trees:
		var rect=t.sprite.get_rect()
		var target=0.50 if player.position.y<t.base.y and player.position.y>t.base.y-150 and absf(player.position.x-t.base.x)<t.width*0.45 else 1.0
		t.sprite.self_modulate.a=move_toward(t.sprite.self_modulate.a,target,dt*3)
	if auto_light:
		set_light(fmod(daylight+dt*0.018,1.0))
		if is_instance_valid(time_slider):time_slider.set_value_no_signal(daylight)
	if is_instance_valid(status):
		status.text=last_message if elapsed<message_until else ("E · 播种 / 浇水 / 收获   |   已收获 %d 株"%harvested if selected_cell>=0 else "WASD / 方向键 行走   Shift 快走   E 互动   R 回到门前   Tab 看田地")
	queue_redraw()

func _draw():
	if terrain_parts.is_empty():return
	# Continuous soil bed, with only a selected planting cell indicated on top.
	# The logical 32px grid is unchanged; art does not create separate square trays.
	var outer=farm_outline(Vector2(80,64))
	var rim_shadow=PackedVector2Array()
	for p in outer:rim_shadow.append(p+Vector2(0,2))
	draw_colored_polygon(rim_shadow,Color("76804e")*ground_tint)
	draw_colored_polygon(outer,Color("a38558")*ground_tint)
	var ground_points=farm_outline(Vector2(77,61));var tex_uv=PackedVector2Array()
	for p in ground_points:tex_uv.append((p-FARM_ORIGIN+Vector2(16,16))/Vector2(160,128))
	draw_polygon(ground_points,PackedColorArray([ground_tint*Color(1.06,1.03,0.97)]),tex_uv,terrain_parts[3])
	for i in fields.size():
		var f:Dictionary=fields[i]
		if f.state==1 or f.state==2:
			var wet=PackedVector2Array()
			for j in 8:wet.append((f.rect.get_center()+Vector2(cos(j*TAU/8)*12,sin(j*TAU/8)*8)).snapped(Vector2(2,2)))
			draw_colored_polygon(wet,Color(0.16,0.20,0.21,0.19))
		if i==selected_cell:
			var r:Rect2=f.rect.grow(-2)
			for c in [Vector2(0,0),Vector2(1,0),Vector2(1,1),Vector2(0,1)]:
				var p=r.position+r.size*c;var inward=Vector2(1,1)-c*2
				draw_line(p,p+Vector2(inward.x*5,0),Color("ffefad"),1)
				draw_line(p,p+Vector2(0,inward.y*5),Color("ffefad"),1)

func farm_outline(radius:Vector2)->PackedVector2Array:
	var points=PackedVector2Array()
	for i in 64:
		var angle=i*TAU/64
		var c=cos(angle);var s=sin(angle)
		var edge=Vector2(signf(c)*pow(absf(c),0.57),signf(s)*pow(absf(s),0.57))
		var organic=1.0+0.014*sin(angle*5.0+0.8)+0.008*cos(angle*9.0)
		points.append((FARM_ORIGIN+Vector2(64,48)+edge*radius*organic).round())
	return points

func set_light(value:float):
	daylight=clampf(value,0,1)
	var keys=[
		{"t":0.0,"tint":Color(0.30,0.39,0.64),"shade":Color(0.8,0.85,1.0),"sun":Color(0.9,0.97,1.08),"strength":0.25,"dir":Vector2(0.4,0.55),"length":0.35,"night":1.0},
		{"t":0.16,"tint":Color(0.62,0.76,0.94),"shade":Color(0.72,0.85,1.08),"sun":Color(1.04,1.07,1.10),"strength":0.55,"dir":Vector2(0.9,0.35),"length":0.68,"night":0.4},
		{"t":0.25,"tint":Color(0.91,0.99,1.04),"shade":Color(0.65,0.83,1.10),"sun":Color(1.05,1.12,1.10),"strength":0.68,"dir":Vector2(0.85,0.34),"length":0.62,"night":0.0},
		{"t":0.50,"tint":Color.WHITE,"shade":Color(0.72,0.84,1.02),"sun":Color(1.12,1.08,0.96),"strength":0.64,"dir":Vector2(0.40,0.55),"length":0.27,"night":0.0},
		{"t":0.73,"tint":Color(1.04,0.77,0.63),"shade":Color(0.62,0.65,1.05),"sun":Color(1.30,1.05,0.73),"strength":0.93,"dir":Vector2(-0.95,0.32),"length":0.82,"night":0.16},
		{"t":0.84,"tint":Color(0.42,0.43,0.68),"shade":Color(0.74,0.8,1.1),"sun":Color(1.05,0.95,1.08),"strength":0.32,"dir":Vector2(-0.3,0.52),"length":0.40,"night":0.95},
		{"t":1.0,"tint":Color(0.30,0.39,0.64),"shade":Color(0.8,0.85,1.0),"sun":Color(0.9,0.97,1.08),"strength":0.25,"dir":Vector2(0.4,0.55),"length":0.35,"night":1.0}]
	var index=0
	while index<keys.size()-2 and daylight>float(keys[index+1].t):index+=1
	var a:Dictionary=keys[index];var b:Dictionary=keys[index+1]
	var t=inverse_lerp(float(a.t),float(b.t),daylight)
	var tint:Color=a.tint.lerp(b.tint,t);var shade:Color=a.shade.lerp(b.shade,t);var sunny:Color=a.sun.lerp(b.sun,t)
	var strength=lerpf(a.strength,b.strength,t);var direction:Vector2=a.dir.lerp(b.dir,t);var length_=lerpf(a.length,b.length,t)
	night_level=lerpf(a.night,b.night,t)
	lighting_label="夜色" if night_level>0.8 else ("清晨" if daylight<0.35 else ("晴昼" if daylight<0.65 else "黄昏"))
	ground_tint=tint
	ground_material.set_shader_parameter("tint",tint)
	ground_material.set_shader_parameter("night_level",night_level)
	for m in surfaces:
		m.set_shader_parameter("sky_tint",tint);m.set_shader_parameter("shade_tint",shade);m.set_shader_parameter("sun_tint",sunny);m.set_shader_parameter("sun_side",-direction.x);m.set_shader_parameter("light_strength",strength)
		m.set_shader_parameter("night_level",night_level)
	for item in cast_shadows:
		var points=PackedVector2Array()
		for p in item.outline:
			points.append((item.base+Vector2(p.x*item.width,0)-direction*length_*p.y*item.height).snapped(Vector2(4,4)))
		item.polygon.polygon=points
		item.polygon.color=Color(0.12,0.18,0.28,lerpf(lerpf(0.24,0.34,absf(daylight-0.5)*2),0.14,night_level))
	contact_ink=Color(0.19,0.23,0.25,0.25)
	if is_instance_valid(clock_label):clock_label.text=lighting_label
	queue_redraw()

func label(text_:String,size_:int,color=Color("554a38"))->Label:
	var l=Label.new();l.text=text_;l.add_theme_font_size_override("font_size",size_);l.add_theme_color_override("font_color",color);return l

func panel()->StyleBoxFlat:
	var s=StyleBoxFlat.new();s.bg_color=Color(0.98,0.95,0.85,0.95);s.border_color=Color("a68d60");s.set_border_width_all(1);s.set_content_margin_all(7);return s

func button(text_:String,fn:Callable)->Button:
	var b=Button.new();b.text=text_;b.add_theme_font_size_override("font_size",11);b.add_theme_color_override("font_color",Color("594831"));b.add_theme_stylebox_override("normal",panel());b.add_theme_stylebox_override("hover",panel());b.pressed.connect(fn);return b

func make_ui():
	var layer=CanvasLayer.new();add_child(layer)
	var root=Control.new();root.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT);root.mouse_filter=Control.MOUSE_FILTER_IGNORE;layer.add_child(root)
	var f=SystemFont.new();f.font_names=PackedStringArray(["Microsoft YaHei UI","Microsoft YaHei","SimHei"]);root.add_theme_font_override("font",f)
	var title_box=PanelContainer.new();title_box.position=Vector2(10,10);title_box.add_theme_stylebox_override("panel",panel());root.add_child(title_box)
	var col=VBoxContainer.new();title_box.add_child(col);col.add_child(label("木漏日 · 像素庭院",15));col.add_child(label("现代日式两层 · 庭院试玩",10))
	var light_box=PanelContainer.new();light_box.position=Vector2(498,10);light_box.custom_minimum_size=Vector2(260,72);light_box.add_theme_stylebox_override("panel",panel());root.add_child(light_box)
	var light_col=VBoxContainer.new();light_box.add_child(light_col)
	var top=HBoxContainer.new();light_col.add_child(top);top.add_child(label("光照时刻",11));clock_label=label("晴昼",11);clock_label.size_flags_horizontal=Control.SIZE_EXPAND_FILL;clock_label.horizontal_alignment=HORIZONTAL_ALIGNMENT_RIGHT;top.add_child(clock_label)
	time_slider=HSlider.new();time_slider.min_value=0;time_slider.max_value=1;time_slider.step=0.005;time_slider.value=daylight;time_slider.value_changed.connect(func(v):auto_light=false;set_light(v));light_col.add_child(time_slider)
	var row=HBoxContainer.new();light_col.add_child(row)
	row.add_child(button("1 清晨",func():choose_light(0.25)))
	row.add_child(button("2 晴昼",func():choose_light(0.50)))
	row.add_child(button("3 黄昏",func():choose_light(0.73)))
	row.add_child(button("4 夜色",func():choose_light(0.94)))
	row.add_child(button("循环",func():auto_light=not auto_light))
	var bottom=PanelContainer.new();bottom.position=Vector2(10,401);bottom.custom_minimum_size=Vector2(748,23);bottom.add_theme_stylebox_override("panel",panel());root.add_child(bottom)
	status=label("",10);bottom.add_child(status)

func choose_light(v:float):
	auto_light=false;time_slider.set_value_no_signal(v);set_light(v)

func _unhandled_key_input(event):
	if not event is InputEventKey or not event.pressed or event.echo:return
	match event.physical_keycode:
		KEY_ESCAPE:get_tree().quit()
		KEY_1:choose_light(0.25)
		KEY_2:choose_light(0.50)
		KEY_3:choose_light(0.73)
		KEY_4:choose_light(0.94)
		KEY_L:auto_light=not auto_light
		KEY_E:interact()
		KEY_R:player.position=SPAWN;update_camera(true)
		KEY_TAB:player.position=FARM_ORIGIN+Vector2(16,116);facing=3;update_camera(true)
		KEY_F5:
			current_seed+=1;ground_material.set_shader_parameter("seed",float(current_seed));notify("地面纹理已换一个固定种子 · 田格和作物位置不变")

func run_checks():
	assert(trees.size()==15 and tree_texture.size()==4)
	assert(fields.size()==12 and CELL==32)
	assert(not blocked(SPAWN))
	for y in range(500,630,4):assert(not blocked(Vector2(620,y)))
	assert(blocked(Vector2(620,430)))
	for i in fields.size():
		assert(cell_at(fields[i].rect.get_center())==i)
		assert(Geometry2D.is_point_in_polygon(fields[i].rect.get_center(),farm_outline(Vector2(77,61))))
		for j in range(i+1,fields.size()):assert(not fields[i].rect.intersects(fields[j].rect))
	for key in clips:assert(float(clips[key].sizeCalibration.unitPixels)>0)
	var prior=player.position
	var key=InputEventKey.new();key.physical_keycode=KEY_D;key.pressed=true;Input.parse_input_event(key)
	await get_tree().create_timer(0.35).timeout
	key.pressed=false;Input.parse_input_event(key)
	assert(player.position.x>prior.x+15)
	player.position=SPAWN
	# Traverse the actual movement path: climb three risers, stand on the porch,
	# stop at the closed facade, and return down the stairs at unchanged scale.
	player.position=Vector2(620,520);show_idle();var normal_scale=portrait.scale
	move_actor(Vector2(0,-80));show_idle()
	assert(floor_height(player.position)==12.0 and player.position.y>=482)
	assert(portrait.scale==normal_scale and contact_shadow.position.y==-12.0)
	var anchor:Vector2=Vector2(character_pack.idle.anchor[0],character_pack.idle.anchor[1])
	assert(is_equal_approx((portrait.position+anchor*portrait.scale).y,-12.0))
	move_actor(Vector2(0,80));show_idle();assert(floor_height(player.position)==0)
	player.position=Vector2(580,486);move_actor(Vector2(60,0));assert(floor_height(player.position)==0)
	player.position=DOOR;move_actor(Vector2(-180,0));assert(player.position.x>=590)
	player.position=Vector2(730,520);move_actor(Vector2(0,-120));assert(player.position.y>=489)
	player.position=SPAWN
	selected_cell=2;interact();assert(fields[2].state==0);interact();assert(fields[2].state==1)
	fields[2].timer=12.1;await get_tree().physics_frame;await get_tree().physics_frame
	assert(fields[2].state==3)
	selected_cell=2;interact();assert(fields[2].state==-1 and harvested==1)
	var grid_origin=fields[0].rect.position
	current_seed=99;ground_material.set_shader_parameter("seed",99.0);assert(fields[0].rect.position==grid_origin)
	set_light(0.25);var morning:Vector2=cast_shadows[0].polygon.polygon[2]
	assert(ground_tint.b>ground_tint.r)
	set_light(0.73);var evening:Vector2=cast_shadows[0].polygon.polygon[2]
	assert(ground_tint.r>ground_tint.b+0.3)
	assert(morning.x>evening.x+50)
	set_light(0.94);assert(night_level>0.9 and ground_tint.r<0.4)
	print("PIXEL_GARDEN_CHECK_PASS input_walk=true house_collision=true door_route=true fixed_character_scale=true 12_unique_32px_cells=true crop_cycle=true seeded_terrain_preserves_farm=true moving_shadows=true porch_stairs=true no_side_climb=true distinct_dawn_dusk=true night_lamps=true")
	get_tree().quit()

func capture():
	await get_tree().process_frame;await get_tree().process_frame
	paused_for_capture=true;player.position=SPAWN;show_idle();update_camera(true)
	for shot in [{"name":"day","light":0.50},{"name":"morning","light":0.25},{"name":"evening","light":0.73},{"name":"night","light":0.94}]:
		choose_light(shot.light);await get_tree().process_frame;await RenderingServer.frame_post_draw
		get_viewport().get_texture().get_image().save_png(ProjectSettings.globalize_path("res://qingxi-live/preview-"+shot.name+".png"))
	player.position=FARM_ORIGIN+Vector2(16,116);facing=3;show_idle();update_camera(true);choose_light(0.48);queue_redraw()
	await get_tree().process_frame;await RenderingServer.frame_post_draw
	get_viewport().get_texture().get_image().save_png(ProjectSettings.globalize_path("res://qingxi-live/preview-farm.png"))
	player.position=SPAWN;update_camera(true);player.visible=false
	var checks:Array[Node2D]=[]
	for i in 5:
		if i==0:show_idle()
		else:facing=i-1;elapsed=0.1;animate_walk()
		var holder=Node2D.new();holder.position=SPAWN+Vector2((i-2)*62,0);scenery.add_child(holder)
		holder.add_child(portrait.duplicate());checks.append(holder)
	status.text="同一脚点基线：待机 / 正面行走 / 左侧 / 右侧 / 背面 · 使用工坊原动作与尺寸规则"
	queue_redraw();await get_tree().process_frame;await RenderingServer.frame_post_draw
	get_viewport().get_texture().get_image().save_png(ProjectSettings.globalize_path("res://qingxi-live/preview-actor-scale.png"))
	for n in checks:n.queue_free()
	player.visible=true
	await get_tree().process_frame
	player.position=DOOR;show_idle();update_camera(true);choose_light(0.50)
	status.text="左侧台阶可登上入口平台 · 室内与二楼暂未开放"
	queue_redraw();await get_tree().process_frame;await RenderingServer.frame_post_draw
	get_viewport().get_texture().get_image().save_png(ProjectSettings.globalize_path("res://qingxi-live/preview-porch.png"))
	print("PIXEL_GARDEN_CAPTURE_PASS seven_views=true studio_actor_lineup=true night=true porch=true")
	get_tree().quit()
