extends CanvasLayer
## 2026-11-19 Claude: small feedback that makes actions feel alive (Stardew-style "juice"):
## floating "+2 白菜" / "+15 币" numbers, pixel bursts (dirt when planting, drops when
## watering, gold when harvesting, splashes at ponds), and harvested items flying into the
## bag button. Drawn on its own layer above the world and below the HUD, in screen space.
## center.gd perform() calls react(message, world_position).
const KIT=preload("res://qingxi-live/village-center/ui_kit.gd")
var world
var bits=[]      # {"p","v","life","max","color","size"}
var texts=[]     # {"p","text","life","color"}
var flyers=[]    # {"from","to","t","tex"}
func setup(host):
 world=host;layer=9
 var canvas=Node2D.new();canvas.name="Juice";add_child(canvas)
 canvas.draw.connect(func():_paint(canvas))
 set_meta("canvas",canvas)
func screen(p:Vector2)->Vector2:return world.get_global_transform_with_canvas()*p
func burst(p:Vector2,color:Color,count:int,speed:=60.0,up:=true):
 var s=screen(p)
 for i in count:
  var a=randf_range(-PI,0.0) if up else randf()*TAU
  bits.append({"p":s,"v":Vector2(cos(a),sin(a))*randf_range(.4,1.0)*speed,"life":0.0,"max":randf_range(.35,.7),"color":color,"size":2.0+float(randi()%2)*2.0})
func pop_text(p:Vector2,text:String,color:=Color("fff3d6")):
 texts.append({"p":screen(p)+Vector2(0,-30),"text":text,"life":0.0,"color":color})
func fly_to_bag(p:Vector2,icon:String):
 var to=Vector2.ZERO
 if world.ui!=null and is_instance_valid(world.ui.actions) and world.ui.actions.get_child_count()>0:
  to=world.ui.actions.get_child(0).get_global_rect().get_center()
 if to==Vector2.ZERO:return
 flyers.append({"from":screen(p),"to":to,"t":0.0,"tex":KIT.icon_texture(icon)})
## Reacts to the same messages center.gd already turns into sounds.
func react(message:String,p:Vector2):
 if message.begins_with("收获"):
  burst(p,Color("f2d36b"),14,80);pop_text(p,"+2 白菜",Color("c9f28a"));fly_to_bag(p,"veg")
 elif "播种" in message:burst(p+Vector2(0,10),Color("9a6b45"),10,45)
 elif message.begins_with("浇水"):burst(p,Color("8fd0ff"),12,55)
 elif "币" in message:
  var m=RegEx.create_from_string("(\\d+)\\s*币").search(message)
  if m!=null:pop_text(p,"+"+m.get_string(1)+" 币",Color("ffd75e"))
  burst(p,Color("ffd75e"),8,50)
 elif "鱼苗" in message or "投喂" in message or "捕捞" in message:burst(p,Color("bfe8ff"),16,70)
 elif message.begins_with("放养"):burst(p,Color("ffb6c8"),12,50)
func _process(dt):
 for b in bits:
  b.life+=dt;b.v.y+=140.0*dt;b.p+=b.v*dt
 bits=bits.filter(func(b):return b.life<b.max)
 for t in texts:t.life+=dt;t.p.y-=28.0*dt
 texts=texts.filter(func(t):return t.life<1.1)
 for f in flyers:f.t+=dt/.6
 var done=flyers.filter(func(f):return f.t>=1.0)
 if not done.is_empty() and world.ui!=null and is_instance_valid(world.ui.actions):world.ui.pop(world.ui.actions.get_child(0))
 flyers=flyers.filter(func(f):return f.t<1.0)
 get_meta("canvas").queue_redraw()
func _paint(c:Node2D):
 for b in bits:
  var a=1.0-b.life/b.max
  c.draw_rect(Rect2(b.p.round(),Vector2(b.size,b.size)),Color(b.color,a))
 var font=ThemeDB.fallback_font
 for t in texts:
  var a=1.0-clampf((t.life-.6)/.5,0,1)
  c.draw_string_outline(font,t.p.round()-Vector2(24,0),t.text,HORIZONTAL_ALIGNMENT_CENTER,48,13,4,Color(.23,.16,.1,a))
  c.draw_string(font,t.p.round()-Vector2(24,0),t.text,HORIZONTAL_ALIGNMENT_CENTER,48,13,Color(t.color,a))
 for f in flyers:
  var e=f.t*f.t*(3.0-2.0*f.t)
  var mid=(f.from+f.to)/2.0+Vector2(0,-80)
  var p=f.from.lerp(mid,e).lerp(mid.lerp(f.to,e),e)
  if f.tex!=null:c.draw_texture_rect(f.tex,Rect2(p-Vector2(10,10),Vector2(20,20)),false)
