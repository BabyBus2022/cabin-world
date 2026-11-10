extends Node
## Camera-only zoom: world coordinates, actor sizes and collisions stay unchanged.
var host:Control
var view:Control
var stage:Node2D
var controls:HBoxContainer
var hint:Label
var room_size=Vector2.ZERO
var base_scale=1.0
var zoom=1.0
var center=Vector2.ZERO
var scene=""
var enabled=false
var pressed=false
var dragging=false
var press_at=Vector2.ZERO
var last_at=Vector2.ZERO
var states={}
func setup(main:Control):
 host=main;view=main._view;stage=main._stage
 controls=HBoxContainer.new();controls.z_index=200;controls.add_theme_constant_override("separation",6)
 host.add_child(controls)
 for spec in [["－",0],["＋",1],["全景",2],["近景",3]]:
  var b=Button.new();b.text=spec[0];b.custom_minimum_size=Vector2(48,32)
  for mode in ["normal","hover","pressed"]:
   var skin=StyleBoxFlat.new();skin.bg_color=Color("f6e6c8") if mode=="normal" else Color("e2c99f")
   skin.border_color=Color("a96f3b");skin.set_border_width_all(2);skin.set_content_margin_all(5)
   b.add_theme_stylebox_override(mode,skin)
  b.add_theme_color_override("font_color",Color("3a2a20"))
  b.pressed.connect(_button.bind(spec[1]));controls.add_child(b)
 hint=Label.new();hint.text="  拖动查看 · 滚轮缩放";hint.add_theme_color_override("font_color",Color("fff4dc"))
 controls.add_child(hint)
func configure(id:String,size:Vector2,k:float,settings:Dictionary):
 if enabled:states[scene]={"zoom":zoom,"center":center}
 var changed=id!=scene
 scene=id;room_size=size;base_scale=k;enabled=settings.get("camera",{}).get("enabled",false)
 controls.visible=enabled
 if not enabled:
  stage.position=Vector2.ZERO;stage.scale=Vector2.ONE*k
  pressed=false;dragging=false;return
 if changed:
  var saved=states.get(id,{})
  zoom=float(saved.get("zoom",maxf(1.0,size.y/640.0)))
  var focus=settings.get("camera",{}).get("focus",[size.x/2,size.y/2])
  center=saved.get("center",Vector2(focus[0],focus[1]))
 controls.position=view.position+Vector2(12,12)
 _apply()
func world_at(at:Vector2)->Vector2:
 return (at-stage.position)/stage.scale.x
func _apply():
 var scale_of=base_scale*zoom
 var half=view.size/(2.0*scale_of)
 for axis in 2:
  center[axis]=room_size[axis]/2.0 if half[axis]*2>=room_size[axis] else clampf(center[axis],half[axis],room_size[axis]-half[axis])
 stage.scale=Vector2.ONE*scale_of
 stage.position=view.size/2.0-center*scale_of
func set_zoom(value:float,anchor:Vector2):
 var world=world_at(anchor)
 zoom=clampf(value,1.0,2.5)
 center=world-(anchor-view.size/2.0)/(base_scale*zoom)
 _apply()
func _button(kind:int):
 if kind==2:zoom=1.0;center=room_size/2.0;_apply()
 elif kind==3:zoom=maxf(1.0,room_size.y/640.0);_apply()
 else:set_zoom(zoom*(1.15 if kind==1 else 1/1.15),view.size/2.0)
func _process(_dt:float):
 controls.visible=enabled and view.is_visible_in_tree()
 if not enabled or not view.is_visible_in_tree() or dragging or host.follow<0:return
 var c=host.characters[host.follow]
 if c.placed and c.scene_id==scene:
  center=c.feet;_apply()
func _input(event:InputEvent):
 if not enabled or not view.is_visible_in_tree():return
 if event is InputEventMouseButton:
  var inside=Rect2(view.position,view.size).has_point(event.position)
  if controls.get_global_rect().has_point(event.position):return
  if event.button_index in [MOUSE_BUTTON_WHEEL_UP,MOUSE_BUTTON_WHEEL_DOWN] and event.pressed and inside:
   host.follow=-1
   set_zoom(zoom*(1.1 if event.button_index==MOUSE_BUTTON_WHEEL_UP else 1/1.1),event.position-view.position)
   get_viewport().set_input_as_handled()
  elif event.button_index in [MOUSE_BUTTON_LEFT,MOUSE_BUTTON_MIDDLE]:
   if event.pressed and inside:
    pressed=true;dragging=false;press_at=event.position;last_at=event.position
   elif not event.pressed:
    if dragging:get_viewport().set_input_as_handled()
    pressed=false;dragging=false
 elif event is InputEventMouseMotion and pressed:
  if not dragging and event.position.distance_to(press_at)>5:
   dragging=true;host.follow=-1;host._hud.follow=-1;host._hud.queue_redraw()
  if dragging:
   center-=(event.position-last_at)/stage.scale.x;_apply()
   get_viewport().set_input_as_handled()
  last_at=event.position
