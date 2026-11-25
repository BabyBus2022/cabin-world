extends Control
## 清溪村 HUD in Cabin World's wood-and-paper style (see ui_kit.gd). Everything on screen
## besides the world:
##   top-left     minimap in a wood frame, a hanging plaque with the place name
##   top-right    clock card (pixel sun / dusk / moon, time) and the coin counter
##   top-centre   toasts: paper ribbons that drop in and fade out
##   bottom-right action buttons (bag, map, keys) with their keycaps
##   bottom       an "E" prompt only when something is in reach; build banner; held item
## The game logic stays in center.gd / rural.gd; this node only presents it.
const KIT=preload("res://qingxi-live/village-center/ui_kit.gd")
const INK=KIT.INK
const SOFT=KIT.INK2
const CREAM=KIT.CREAM
const EDGE=KIT.WOOD_D
var world
var font:SystemFont
var mini:Control
var expanded_map:Control
var map_viewport:SubViewport
var map_camera:Camera2D
const Loft=preload("res://qingxi-live/dorm_loft.gd")
var map_bounds=Rect2()
var preview_map_id=""
var preview_timer=0.0
var place_label:Label
var clock_label:Label
var period_label:Label
var clock_icon:TextureRect
var clock_kind=""
var coin_label:Label
var toasts:VBoxContainer
var prompt:PanelContainer
var prompt_key:PanelContainer
var prompt_text:Label
var banner:PanelContainer
var banner_text:Label
var held:PanelContainer
var held_icon:TextureRect
var held_text:Label
var held_key=""
var last_prompt=""
var last_toast=""
var last_toast_time=-10.0
var clock=0.0
var info:HBoxContainer
var actions:HBoxContainer

## Older callers ask for a "card": it is the wood-framed paper window now.
static func card(_radius:=8,_alpha:=.94)->StyleBox:return KIT.frame("window")
func text(t:String,size_:int,color:=INK,bold:=false)->Label:return KIT.label(t,size_,color,bold)

func setup(host):
 world=host;set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT);mouse_filter=Control.MOUSE_FILTER_IGNORE
 texture_filter=CanvasItem.TEXTURE_FILTER_NEAREST;font=KIT.font()
 # --- minimap with the place-name plaque hanging over its lower edge (top-left)
 var left=VBoxContainer.new();left.position=Vector2(6,6);left.add_theme_constant_override("separation",-8);left.mouse_filter=Control.MOUSE_FILTER_IGNORE;add_child(left)
 var mm=KIT.panel("window");var fm=KIT.frame("window").duplicate();fm.content_margin_left=7;fm.content_margin_right=7;fm.content_margin_top=7;fm.content_margin_bottom=9;mm.add_theme_stylebox_override("panel",fm);left.add_child(mm)
 mini=Control.new();mini.custom_minimum_size=Vector2(138,96);mini.draw.connect(draw_minimap);mini.clip_contents=true;mm.add_child(mini)
 make_map_viewport()
 var plaque=KIT.panel("plaque");plaque.size_flags_horizontal=Control.SIZE_SHRINK_CENTER;left.add_child(plaque)
 var pr=HBoxContainer.new();pr.add_theme_constant_override("separation",4);plaque.add_child(pr)
 pr.add_child(KIT.icon("pin",2));place_label=KIT.label("",12,CREAM,true,Color(EDGE,.6));pr.add_child(place_label)
 # --- clock card and coins (top-right)
 info=HBoxContainer.new();info.add_theme_constant_override("separation",4);info.mouse_filter=Control.MOUSE_FILTER_IGNORE;add_child(info)
 var ck=KIT.panel("ribbon");info.add_child(ck)
 var cr=HBoxContainer.new();cr.add_theme_constant_override("separation",5);ck.add_child(cr)
 clock_icon=KIT.icon("sun",2);cr.add_child(clock_icon)
 var cc=VBoxContainer.new();cc.add_theme_constant_override("separation",-4);cr.add_child(cc)
 clock_label=KIT.label("",15,INK,true);cc.add_child(clock_label)
 period_label=KIT.label("",9,SOFT);cc.add_child(period_label)
 var coins=KIT.coin_chip(0);coins.size_flags_vertical=Control.SIZE_SHRINK_CENTER;info.add_child(coins);coin_label=coins.find_child("Amount",true,false)
 # --- action buttons (bottom-right)
 actions=HBoxContainer.new();actions.add_theme_constant_override("separation",8);add_child(actions)
 actions.add_child(action_button("bag","B","背包",func():world.show_bag()))
 actions.add_child(action_button("map","M","地图",func():world.show_map()))
 # 2026-11-19 Claude (Cabin World host): no village chat inside Cabin World, so no chat button there.
 if not get_tree().has_meta("qingxi_world_host"):
  actions.add_child(action_button("chat","Y","聊天",func():
   var chat=get_tree().get_meta("qingxi_chat",false)
   if chat:chat.open_chat()))
 actions.add_child(action_button("help","H","按键",func():world.show_help()))
 # --- toasts (top-centre)
 toasts=VBoxContainer.new();toasts.position=Vector2(224,8);toasts.custom_minimum_size=Vector2(320,0)
 toasts.mouse_filter=Control.MOUSE_FILTER_IGNORE;toasts.add_theme_constant_override("separation",2);add_child(toasts)
 # --- prompt (bottom-centre)
 prompt=KIT.panel("ribbon");prompt.mouse_filter=Control.MOUSE_FILTER_IGNORE;add_child(prompt)
 var row=HBoxContainer.new();row.add_theme_constant_override("separation",6);prompt.add_child(row)
 prompt_key=KIT.keycap("E");row.add_child(prompt_key)
 prompt_text=KIT.label("",12,INK,true);row.add_child(prompt_text)
 prompt.modulate.a=0.0
 # --- build banner and held item
 banner=KIT.panel("plaque");add_child(banner)
 banner_text=KIT.label("",12,CREAM,true,Color(EDGE,.6));banner.add_child(banner_text);banner.hide()
 held=KIT.panel("ribbon");held.position=Vector2(6,388);add_child(held)
 var hr=HBoxContainer.new();hr.add_theme_constant_override("separation",5);held.add_child(hr)
 held_icon=KIT.icon("wheat",2);hr.add_child(held_icon);held_text=KIT.label("",11,INK,true);hr.add_child(held_text);held.hide()

## Square wood button with a pixel icon and its keycap pinned to the corner.
func action_button(icon_name:String,key:String,tip:String,fn:Callable)->Control:
 var holder=Control.new();holder.custom_minimum_size=Vector2(42,42)
 var b=Button.new();KIT.style_button(b);b.icon=KIT.icon_texture(icon_name);b.expand_icon=true;b.tooltip_text=tip
 var st=KIT.frame("wood").duplicate();st.content_margin_left=7;st.content_margin_right=7;st.content_margin_top=6;st.content_margin_bottom=9;b.add_theme_stylebox_override("normal",st)
 for k in ["hover","pressed","hover_pressed"]:
  var s2=b.get_theme_stylebox(k).duplicate();s2.content_margin_left=7;s2.content_margin_right=7;s2.content_margin_top=6 if k=="hover" else 8;s2.content_margin_bottom=9 if k=="hover" else 7;b.add_theme_stylebox_override(k,s2)
 b.custom_minimum_size=Vector2(36,36);b.size=Vector2(36,36);b.position=Vector2(0,0);holder.add_child(b)
 b.pressed.connect(fn);b.pressed.connect(func():if world.audio:world.audio.sfx("ui_click",-10))
 var cap=KIT.keycap(key);cap.position=Vector2(23,23);holder.add_child(cap)
 return holder
func pop(node:Control):
 node.pivot_offset=node.size/2
 var t=create_tween();t.tween_property(node,"scale",Vector2(1.3,1.3),.06);t.tween_property(node,"scale",Vector2.ONE,.16).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)

# ---------------- per-frame refresh ----------------
func refresh(dt:float):
 clock+=dt
 var vw=get_viewport_rect().size
 info.position=Vector2(vw.x-6-info.size.x,6)
 actions.position=Vector2(vw.x-6-actions.size.x,vw.y-48)
 var hours=world.sky_value()*24.0
 clock_label.text="%02d:%02d"%[int(hours),int(fmod(hours,1)*60)]
 period_label.text=str(world.lighting_label)
 if world.has_method("season_label"):period_label.text=world.season_label()+" · "+period_label.text   # 2026-11-19 Claude
 if is_instance_valid(world.weather_view) and world.weather_view.visible:
  var label_:String=world.weather_view.NAMES.get(world.weather_view.kind(),"")
  if label_!="":period_label.text+=" · "+label_
 var kind="moon" if world.night_level>.5 else ("sun" if hours>7 and hours<17 else "dusk")
 if kind!=clock_kind:clock_kind=kind;clock_icon.texture=KIT.icon_texture(kind)
 var coins=str(int(world.sim.data.coins))
 if coin_label.text!=coins and coin_label.text!="":pop(coin_label)
 coin_label.text=coins
 place_label.text=str(world.MAP_NAMES.get(world.map_id,world.map_id))
 refresh_map_preview(dt)
 mini.queue_redraw()
 if is_instance_valid(expanded_map) and expanded_map.is_visible_in_tree():expanded_map.queue_redraw()
 # held food (Q)
 held.visible=world.held_food!=""
 if held.visible:
  if held_key!=world.held_food:held_key=world.held_food;held_icon.texture=KIT.icon_texture(held_key)
  held_text.text="%s ×%d"%[world.StateModel.ITEM_NAMES[world.held_food],world.sim.data.bag[world.held_food]]
 # build banner
 banner.visible=world.build_mode
 if world.build_mode:
  banner_text.text="%s · %s · G 完成"%[world.tool_name(world.build_tool),world.editor_hint()]
  banner.reset_size()
  banner.position=Vector2((vw.x-banner.size.x)/2,vw.y-88)
 set_prompt(current_prompt())

func current_prompt()->String:
 if world.overlay.visible or world.build_mode:return ""
 var doorway:Dictionary=world.stair_in_reach()
 if not doorway.is_empty():return str(doorway.name)
 # 2026-11-19 Claude: every door shows "E 进入 …" when the player stands in front of it.
 if world.has_method("door_in_reach") and world.selected_cell<0:
  var door:Dictionary=world.door_in_reach()
  if not door.is_empty() and world.door_wins(door):return world.door_label(door)
 if world.selected_cell>=0 and world.selected_cell<world.sim.data.crops.size():
  var c:Dictionary=world.sim.data.crops[world.selected_cell]
  if not c.planted:return "选择种子"
  if c.progress>=world.StateModel.CROP_SECONDS:return "收获"+str(world.sim.ITEM_NAMES[world.sim.Garden.book().produce.get(c.get("seed_key","seed"),"veg")])
  return "浇水 · 还需 "+world.remaining(world.StateModel.CROP_SECONDS-c.progress)+(" · 缺水" if c.water<=0 else " · 湿润")
 if world.action_target.is_empty():return ""
 var name=str(world.action_target.name).replace(" · E","")
 if str(world.action_target.kind)=="portal":return "" if world.action_target.has("approach") else "↑ "+name
 return name
func set_prompt(t:String):
 if t==last_prompt:return
 last_prompt=t
 if t=="":
  create_tween().tween_property(prompt,"modulate:a",0.0,.12);return
 prompt_text.text=t
 prompt_key.visible=not t.begins_with("↑ ")
 prompt.reset_size()
 var vw=get_viewport_rect().size
 var y=vw.y-40
 prompt.position=Vector2(roundf((vw.x-prompt.get_combined_minimum_size().x)/2),y+6)
 var tw=create_tween().set_parallel(true)
 tw.tween_property(prompt,"modulate:a",1.0,.12)
 tw.tween_property(prompt,"position:y",y,.18).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)

# ---------------- toasts ----------------
## Messages show what happened, not how to play: keep the first clause and drop any
## part that tells the player which key to press.
static func quiet(message:String)->String:
 var parts=[]
 var keys=RegEx.create_from_string("(按\\s*[A-Za-z0-9]|WASD|再按|左键|右键|方向键)")
 for part in message.replace("；",";").split(";"):
  var p=part.strip_edges()
  if p=="" or keys.search(p)!=null:continue
  parts.append(p)
 return parts[0] if parts.size()>0 else ""
func toast(message:String):
 message=quiet(message)
 if message=="" or (message==last_toast and clock-last_toast_time<1.5):return
 for p in toasts.get_children():
  if p.has_meta("text") and p.get_meta("text")==message:return   # already on screen
 last_toast=message;last_toast_time=clock
 var p=KIT.panel("ribbon");p.mouse_filter=Control.MOUSE_FILTER_IGNORE;p.set_meta("text",message);p.size_flags_horizontal=Control.SIZE_SHRINK_CENTER
 var l=KIT.label(message,12,INK,true);l.autowrap_mode=TextServer.AUTOWRAP_WORD_SMART;l.horizontal_alignment=HORIZONTAL_ALIGNMENT_CENTER
 l.custom_minimum_size=Vector2(minf(300,KIT.font(true).get_string_size(message,HORIZONTAL_ALIGNMENT_LEFT,-1,12).x+4),0);p.add_child(l)
 toasts.add_child(p)
 while toasts.get_child_count()>3:var old=toasts.get_child(0);toasts.remove_child(old);old.queue_free()
 p.modulate.a=0.0;p.position.y-=10
 var t=create_tween();t.tween_property(p,"modulate:a",1.0,.16)
 t.tween_interval(3.0);t.tween_property(p,"modulate:a",0.0,.35);t.tween_callback(p.queue_free)

# ---------------- minimap ----------------
func make_map_viewport():
 # A second camera sees the same terrain, art and placed objects. The HUD lives
 # in its own CanvasLayer on the main viewport.
 map_viewport=SubViewport.new()
 map_viewport.world_2d=world.get_world_2d()
 map_viewport.disable_3d=true
 map_viewport.gui_disable_input=true
 map_viewport.canvas_cull_mask=1
 map_viewport.render_target_update_mode=SubViewport.UPDATE_DISABLED
 add_child(map_viewport)
 map_camera=Camera2D.new()
 map_viewport.add_child(map_camera);map_camera.make_current()
 refresh_map_preview(0)

func refresh_map_preview(dt:float):
 var changed=preview_map_id!=world.map_id or map_bounds.size==Vector2.ZERO
 if changed:
  preview_map_id=world.map_id
  map_bounds=world.Rooms.FLOOR.grow(20) if world.rooms.contains(world.map_id) else world.world_bounds()
  if world.map_id=="room_private_dorm":map_bounds=Loft.SHELL
  var zoom=640.0/maxf(map_bounds.size.x,map_bounds.size.y)
  map_viewport.size=Vector2i((map_bounds.size*zoom).round())
  map_camera.position=map_bounds.get_center()
  map_camera.zoom=Vector2.ONE*zoom
  map_camera.force_update_scroll()
 preview_timer-=dt
 if changed or preview_timer<=0.0:
  preview_timer=.12 if is_instance_valid(expanded_map) and expanded_map.is_visible_in_tree() else .25
  map_viewport.render_target_update_mode=SubViewport.UPDATE_ONCE

func add_expanded_map(parent:Control):
 var frame=KIT.panel("window");parent.add_child(frame)
 frame.size_flags_horizontal=Control.SIZE_SHRINK_CENTER
 expanded_map=Control.new()
 var height_=172.0
 expanded_map.custom_minimum_size=Vector2(roundf(height_*map_bounds.size.x/map_bounds.size.y),height_)
 expanded_map.clip_contents=true;expanded_map.mouse_filter=Control.MOUSE_FILTER_IGNORE
 frame.add_child(expanded_map)
 var canvas=expanded_map
 canvas.draw.connect(func():draw_live_map(canvas,false))
 preview_timer=0

func draw_minimap():draw_live_map(mini,true)

func draw_live_map(canvas:Control,show_camera:bool):
 if not is_instance_valid(world.player) or map_bounds.size==Vector2.ZERO:return
 var factor=minf(canvas.size.x/map_bounds.size.x,canvas.size.y/map_bounds.size.y)
 var inner=(canvas.size-map_bounds.size*factor)/2.0
 var offset=inner-map_bounds.position*factor
 var project=Transform2D(Vector2(factor,0),Vector2(0,factor),offset)
 var frame=Rect2(inner,map_bounds.size*factor)
 canvas.draw_rect(Rect2(Vector2.ZERO,canvas.size),KIT.PAPER_D)
 canvas.draw_texture_rect(map_viewport.get_texture(),frame,false)
 var cam=world.camera
 # 2026-11-19 Claude: map markers (the rice paddies): the patch of land is outlined in its
 # season colour, no text (owner's wish).
 if world.has_method("map_markers"):
  for m in world.map_markers():
   var box:Rect2=project*Rect2(m.rect)
   canvas.draw_rect(box.grow(1),Color("3b2416"),false,1.0)
   canvas.draw_rect(box,m.get("color",Color("e6b84a")),false,1.5)
 if show_camera and is_instance_valid(cam):
  var view=world.get_viewport_rect().size/cam.zoom
  var visible=Rect2(cam.get_screen_center_position()-view/2,view).intersection(map_bounds)
  canvas.draw_rect(project*visible,Color(1,1,1,.65),false,1.0)


