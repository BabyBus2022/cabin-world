extends "res://qingxi-live/material-lab/country_house.gd"
const State=preload("res://qingxi-live/village-center/pasture_state.gd")
const Session=preload("res://qingxi-live/village3d/session.gd")
const SAVE="user://village-center-test.json"
var sim=State.new()
var home_layer:CanvasLayer
var home_menu:PanelContainer
var home_rows:VBoxContainer
var home_title:Label
var home_message:Label
var leave_pending=false
var check_home=false
var home_clock=0.0
var hour=8.5
var cycle=true
var matte_materials=[]
var audio
var garden_sprites=[]

func _ready():
 check_home="--check-connected-cottage" in OS.get_cmdline_user_args() or bool(get_tree().get_meta("center_testing",false))
 if not Session.consume(get_tree(),sim) and not check_home:sim.load_from(SAVE)
 sim.data.map="field"
 hour=float(get_tree().get_meta("center_hour",8.5));cycle=bool(get_tree().get_meta("center_cycle",true))
 super._ready()
 testing=check_home;player.position=Vector3(-3.5,.05,14);previous_position=player.position
 relief_enabled=false;camera.size=25;portrait.texture_filter=BaseMaterial3D.TEXTURE_FILTER_NEAREST
 # Existing model, stairs, holes and collision remain the source of architectural truth.
 for m in materials.values():m.shader=preload("res://qingxi-live/ranch-life/house_paint.gdshader")
 for node in find_children("*","MeshInstance3D",true,false):
  var m=node.material_override
  if m is StandardMaterial3D:
   var flat=ShaderMaterial.new();flat.shader=preload("res://qingxi-live/ranch-life/paint.gdshader");flat.set_shader_parameter("pigment",m.albedo_color)
   if m.albedo_texture:flat.set_shader_parameter("ink",m.albedo_texture);flat.set_shader_parameter("textured",true);flat.set_shader_parameter("repeat_scale",m.uv1_scale.x)
   node.material_override=flat;matte_materials.append(flat)
 dress_courtyard();apply_home_light();get_tree().auto_accept_quit=false
 audio=preload("res://qingxi-live/village-center/audio.gd").new();add_child(audio);audio.place("field",hour>=19 or hour<6)
 DisplayServer.window_set_title("清溪村 · 我的小屋与转角小院")
 if "--check-connected-cottage" in OS.get_cmdline_user_args():home_checks.call_deferred()
func make_ui():
 super.make_ui()
 for child in get_children():
  if child is CanvasLayer:child.hide()
 home_layer=CanvasLayer.new();home_layer.layer=3;add_child(home_layer)
 var root=Control.new();root.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT);root.mouse_filter=Control.MOUSE_FILTER_IGNORE;home_layer.add_child(root)
 var f=SystemFont.new();f.font_names=PackedStringArray(["Microsoft YaHei","SimHei"]);root.add_theme_font_override("font",f)
 root.add_theme_color_override("font_color",Color("4c3540"))
 for rect in [Rect2(8,6,430,34),Rect2(8,382,752,48)]:
  var panel=Panel.new();panel.position=rect.position;panel.size=rect.size;panel.mouse_filter=Control.MOUSE_FILTER_IGNORE
  var style=StyleBoxFlat.new();style.bg_color=Color("f2dfb8");style.border_color=Color("956b4d");style.set_border_width_all(2);style.set_corner_radius_all(3);panel.add_theme_stylebox_override("panel",style);root.add_child(panel)
 home_title=Label.new();home_title.position=Vector2(16,12);home_title.add_theme_font_size_override("font_size",15);root.add_child(home_title)
 home_title.add_theme_color_override("font_color",Color("4c3540"))
 var help=Label.new();help.position=Vector2(16,390);help.text="WASD 行走 · Shift 快走 · 直接进屋 / 上楼 · E 生活菜单 · Esc 返回农场\nF5 白天 / F6 夜晚 · T 日夜流转 · 滚轮缩放";help.add_theme_font_size_override("font_size",12);root.add_child(help)
 help.add_theme_color_override("font_color",Color("4c3540"))
 home_message=Label.new();home_message.position=Vector2(16,360);home_message.add_theme_font_size_override("font_size",13);root.add_child(home_message)
 home_menu=PanelContainer.new();home_menu.position=Vector2(225,75);home_menu.custom_minimum_size.x=320;root.add_child(home_menu);home_menu.hide();home_rows=VBoxContainer.new();home_menu.add_child(home_rows)
func refresh_materials():
 super.refresh_materials()
 var colors={"roof":"748394","wood":"bc9265","wall":"e2d6b5","stone":"a49889","trim":"a27b57","door":"b18a63","window":"8da39c","wall_base":"aa9980"}
 for role in materials:
  materials[role].set_shader_parameter("soft_base",Color(colors.get(role,"c1a585")))
  materials[role].set_shader_parameter("relief",0.0)
func replay(_slow:bool):
 busy=true;await load_stage(2);busy=false;refresh_status();apply_home_light()
func apply_home_light():
 light_mode=3 if hour>=19 or hour<6 else 2 if hour>=17 else 1
 set_daylight()
 var tint_=Color("8e95b5") if light_mode==3 else Color("ffe8d3") if light_mode==2 else Color.WHITE
 for m in materials.values():m.set_shader_parameter("daylight",tint_)
 for m in matte_materials:m.set_shader_parameter("daylight",tint_)
 for s in garden_sprites:s.modulate=tint_
 if is_instance_valid(portrait):portrait.modulate=tint_
 if audio:audio.place("field",light_mode==3)
func ground_material(name_:String,scale_:float)->ShaderMaterial:
 var m=ShaderMaterial.new();m.shader=preload("res://qingxi-live/ranch-life/paint.gdshader")
 m.set_shader_parameter("pigment",Color.WHITE);m.set_shader_parameter("textured",true);m.set_shader_parameter("world_uv",true);m.set_shader_parameter("repeat_scale",scale_)
 m.set_shader_parameter("ink",ImageTexture.create_from_image(Image.load_from_file("res://qingxi-live/village-center/art/garden-v3/sprites/"+name_+".png")))
 matte_materials.append(m);return m
func garden_prop(path:String,p:Vector3,height_:float):
 var s=Sprite3D.new();s.texture=ImageTexture.create_from_image(Image.load_from_file(path));s.pixel_size=height_/s.texture.get_height();s.offset.y=s.texture.get_height()/2.0;s.position=p;s.billboard=BaseMaterial3D.BILLBOARD_ENABLED;s.alpha_cut=SpriteBase3D.ALPHA_CUT_DISCARD;s.texture_filter=BaseMaterial3D.TEXTURE_FILTER_NEAREST;add_child(s);garden_sprites.append(s)
func dress_courtyard():
 var grass=ground_material("grass",.2);var stone=ground_material("paving",.65);var dirt=ground_material("earth",.3)
 grass.set_shader_parameter("grass",true)
 for node in get_children():
  if node is MeshInstance3D:
   if node.name=="CourtyardGround":node.material_override=grass
   elif node.mesh is PlaneMesh:node.material_override=stone
  if node is Sprite3D and node.shaded:node.hide()
 for p in [Vector3(-10,0,-3),Vector3(10,0,-3),Vector3(-11,0,8),Vector3(12,0,12)]:
  garden_prop("res://qingxi-live/village-center/art/jp/trees/tree_green_1.png",p,5.5)
 var path=box(self,Vector3(-3.5,.008,15),Vector3(2.2,.016,8),Color.WHITE);path.material_override=dirt
 var doorstep=box(self,Vector3(-3.5,.014,11.7),Vector3(3,.028,1.2),Color.WHITE);doorstep.material_override=stone
 for item in [["bench",Vector3(7.8,.02,8),.7],["mailbox",Vector3(-5,.02,12.5),1.15],["well",Vector3(8.5,.02,13),2.1]]:
  garden_prop("res://qingxi-live/village-center/art/regions/props/"+item[0]+".png",item[1],item[2])
 for p in [Vector3(-6.4,.02,10),Vector3(-6.4,.02,6),Vector3(6.6,.02,4.5)]:garden_prop("res://qingxi-live/village-center/art/jp/trees/bush_flower_1.png",p,1.2)
func _physics_process(dt):
 if leave_pending:return
 movement_blocked=is_instance_valid(home_menu) and home_menu.visible
 super._physics_process(dt)
 if cycle and not testing:hour=fposmod(hour+dt*.025,24)
 home_clock+=dt
 if home_clock>=1:
  home_clock=0
  if not testing:sim.settle()
  apply_home_light()
 if is_instance_valid(home_title):home_title.text="我的小屋  ·  "+("二楼" if on_upper else "一楼" if in_house else "转角小院")+"    %02d:%02d    %d 币"%[int(hour),int(fmod(hour,1)*60),sim.data.coins]
 if not testing and player.position.z>18:leave_home()
func _unhandled_key_input(event):
 if not event is InputEventKey or not event.pressed or event.echo:return
 match event.physical_keycode:
  KEY_ESCAPE:
   if home_menu.visible:home_menu.hide()
   else:leave_home()
  KEY_E:
   if in_house:open_home_menu()
   else:home_message.text="从玄关或檐廊直接走进屋内；向南沿小路返回农场"
  KEY_F5:hour=8.5;apply_home_light()
  KEY_F6:hour=21;apply_home_light()
  KEY_T:cycle=not cycle
func open_home_menu():
 for child in home_rows.get_children():child.queue_free()
 home_menu.show()
 for item in [["做饭（白菜 ×2）",sim.cook],["吃饭",sim.eat],["休息",sim.rest]]:
  var callback:Callable=item[1];home_button(item[0],func():home_message.text=callback.call();save_home())
 home_button("把背包物品存入家中",func():home_message.text=sim.store_items(false);save_home())
 home_button("取回家中物品",func():home_message.text=sim.store_items(true);save_home())
 home_button("关闭",func():home_menu.hide())
func home_button(text_:String,action:Callable):
 var b=Button.new();b.text=text_;b.focus_mode=Control.FOCUS_NONE;b.pressed.connect(action);home_rows.add_child(b)
func save_home():
 get_tree().set_meta("center_hour",hour);get_tree().set_meta("center_cycle",cycle)
 if testing:return
 sim.settle()
 if not sim.save_to(SAVE):home_message.text="保存失败，请暂时不要关闭窗口"
func leave_home():
 if leave_pending:return
 save_home();leave_pending=true
 Session.publish(get_tree(),sim,"field");get_tree().set_meta("cottage_return",true)
 get_tree().change_scene_to_file.call_deferred("res://qingxi-live/village-center/main.tscn")
func _notification(what):
 if what==NOTIFICATION_WM_CLOSE_REQUEST:save_home();get_tree().quit()
func home_shot(name_:String):
 if DisplayServer.get_name()=="headless":return
 home_layer.hide()
 for i in 3:await get_tree().process_frame
 await RenderingServer.frame_post_draw
 get_viewport().get_texture().get_image().save_png("res://qingxi-live/ranch-life/reports/"+name_+".png")
 home_layer.show()
func home_checks():
 Engine.physics_ticks_per_second=240;Engine.time_scale=4
 while busy or stage<2:await get_tree().process_frame
 for i in 12:await get_tree().physics_frame
 await home_shot("cottage-painted-exterior")
 var identity=player.get_instance_id();var colliders=collision_ids()
 for p in [Vector2(-3.5,10),Vector2(-3.5,7),Vector2(-3.5,4.3),Vector2(-2.6,4.3),Vector2(-2.6,2.7),Vector2(0,2.7)]:verify(await walk_to(p),"Connected cottage entry blocked "+str(p))
 verify(in_house,"Cutaway did not follow direct entry");await home_shot("cottage-ground-floor")
 for p in [Vector2(2.3,2.7),Vector2(2.3,4.35),Vector2(4.3,4.35),Vector2(4.3,-3.35)]:verify(await walk_to(p),"Cottage stairs blocked "+str(p))
 verify(on_upper and absf(player.position.y-LEVEL)<.15,"Second floor not reached")
 await home_shot("cottage-upper-floor")
 verify(player.get_instance_id()==identity and collision_ids()==colliders,"Door/stair traversal replaced physics")
 var before=sim.data.bag.veg;sim.data.bag.veg+=2;sim.cook();verify(sim.data.bag.veg==before,"Shared cooking failed")
 var meal=sim.data.bag.meal;sim.store_items(false);verify(sim.data.storage.meal>=meal,"Shared home storage failed")
 sim.store_items(true);verify(sim.data.bag.meal>=meal,"Storage retrieval failed")
 for p in [Vector2(4.3,4.35),Vector2(2.3,4.35),Vector2(2.3,2.7),Vector2(0,2.7),Vector2(0,8.8)]:verify(await walk_to(p),"Cottage return blocked "+str(p))
 hour=21;apply_home_light();await home_shot("cottage-night")
 print("CONNECTED_COTTAGE ","PASS" if failures.is_empty() else "FAIL"," ",JSON.stringify(failures))
 get_tree().quit(0 if failures.is_empty() else 1)
