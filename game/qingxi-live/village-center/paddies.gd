extends Node2D
## 2026-11-19 Claude: 清溪稻田, four big rice paddies in the open land south-east of the
## east road (east of the creek and the south road), tended by 团团 through the seasons
## (seasons.gd):
##   spring  flooded fields; 团团 plant seedlings row by row (the planted part grows)
##   summer  the rice grows tall and green; 团团 walk the dikes and weed
##   autumn  golden ears; 团团 harvest, cut rows become stubble, sheaves dry on racks
##   winter  the fields freeze over, snow on the dikes; one 团团 skates, the others stay in
## 团团 work from 6:30 to 18:00 and walk home to the rest spot at night. The fields are
## solid (you walk the dikes). E next to a working 团团 or the sign tells you what is going
## on. Shown on the minimap and the M map (center.gd map_markers). Pixel art on a 2 px grid.
const Seasons=preload("res://qingxi-live/village-center/seasons.gd")
const FIELD_SIZE=Vector2(512,256)
const DIKE=64.0
const ORIGIN=Vector2(3456,1856)              # top-left of the first field
const HOME=Vector2(3392,1792)                # where 团团 rest (north-west corner of the dikes)
const SIGN=Vector2(3372,1900)              # west of the dikes, by the road side
const WORKERS=3
const WALK=32.0
var world
var surfaces:Dictionary={}
var fields:Array[Rect2]=[]
var workers=[]
var rice_nodes:Array[MeshInstance2D]=[]
var weather_timer=0.0
var wind_force=.65
var cloud_cover=.20
var age=0.0
var redraw_timer=0.0
var rng=RandomNumberGenerator.new()

func setup(host):
 world=host;z_index=-3;rng.seed=1119
 texture_filter=CanvasItem.TEXTURE_FILTER_NEAREST
 for key in ["stubble","banks","flooded"]:
  var im=Image.new()
  if im.load_png_from_buffer(FileAccess.get_file_as_bytes("res://qingxi-live/village-center/art/paddies/"+key+".png"))==OK:surfaces[key]=ImageTexture.create_from_image(im)
 for j in 2:
  for i in 2:
   fields.append(Rect2(ORIGIN+Vector2(i*(FIELD_SIZE.x+DIKE),j*(FIELD_SIZE.y+DIKE)),FIELD_SIZE))
 var shader=Shader.new()
 shader.code=FileAccess.get_file_as_string("res://qingxi-live/village-center/rice.gdshader")
 for i in fields.size():
  var f=fields[i]
  world.solids.append(f.grow(-2))
  var layer=MeshInstance2D.new()
  layer.position=f.position
  layer.mesh=preload("res://qingxi-live/village-center/rice_mesh.gd").make(917+i)
  var m=ShaderMaterial.new()
  m.shader=shader;m.set_shader_parameter("field_origin",f.position)
  layer.material=m;add_child(layer);rice_nodes.append(layer)
 var group=area()
 # Trees on the land, and trees just south whose crowns would hang over the fields.
 clear_trees(Rect2(group.position-Vector2(48,48),group.size+Vector2(96,48+230)))
 # Scarecrows on the dikes and the field sign.
 for p in [Vector2(group.get_center().x,group.get_center().y+8),Vector2(group.end.x-20,group.position.y+30)]:
  prop("scarecrow",p,Rect2(-8,-6,16,8))
 prop("signpost",SIGN,Rect2(-8,-6,16,8))
 world.add_target("paddy",SIGN+Vector2(0,24),"清溪稻田 · 看看稻子","sign")
 for i in WORKERS:
  var node=Node2D.new();node.position=HOME+Vector2(40+i*36,40);world.scenery.add_child(node)
  var shadow=Polygon2D.new();world.shadow_root.add_child(shadow)
  var sprite=Sprite2D.new();sprite.centered=false;sprite.material=world.light_material();node.add_child(sprite)
  var tag=world.world_label("团团",Vector2.ZERO);tag.reparent(node);tag.position=Vector2(-64,-65)
  workers.append({"node":node,"sprite":sprite,"shadow":shadow,"tag":tag,"goal":node.position,"mode":"start","route":[],"resting":false,"timer":float(i)*1.8+.3,"field":i%4,"direction":0,"walk_progress":0.0,"phase":i*.7,"seed":i*31+7})
  world.add_target("paddy",HOME+Vector2(30+i*30,30),"团团 · 在休息",str(i))

## Village trees that happen to stand on the paddy land are taken away (sprite, shadow,
## collision), so the fields are open. Other trees are untouched.
func clear_trees(r:Rect2):
 for i in range(world.trees.size()-1,-1,-1):
  var t:Dictionary=world.trees[i]
  if not r.has_point(t.base):continue
  var holder=t.sprite.get_parent()
  for k in range(world.cast_shadows.size()-1,-1,-1):
   if world.cast_shadows[k].base==t.base:world.cast_shadows[k].polygon.queue_free();world.cast_shadows.remove_at(k)
  world.solids.erase(Rect2(t.base+Vector2(-10,-8),Vector2(20,16)))
  world.surfaces.erase(t.sprite.material)
  holder.queue_free();world.trees.remove_at(i)
 # Bushes and other small scenery on the fields themselves.
 for n in world.scenery.get_children():
  if n is Node2D and area().grow(-8).has_point(n.position):
   for k in range(world.cast_shadows.size()-1,-1,-1):
    if world.cast_shadows[k].base==n.position:world.cast_shadows[k].polygon.queue_free();world.cast_shadows.remove_at(k)
   n.queue_free()
func prop(name:String,p:Vector2,collision:Rect2):
 var path="res://qingxi-live/village-center/art/regions/props/%s.png"%name
 if name=="scarecrow":path="res://qingxi-live/village-center/art/refined/scarecrow.png"
 if not FileAccess.file_exists(path) and not FileAccess.file_exists(ProjectSettings.globalize_path(path)):return
 var t=ImageTexture.create_from_image(Image.load_from_file(path))
 var s=world.object(t,p,t.get_width()*(.5 if name=="scarecrow" else 2.0),collision,true)
 s.texture_filter=CanvasItem.TEXTURE_FILTER_NEAREST

func area()->Rect2:
 var r=fields[0]
 for f in fields:r=r.merge(f)
 return r.grow(DIKE/2)

func markers()->Array:
 # The owner: the map only needs to show the patch of land, no names.
 return [{"rect":area(),"color":stage_color()}]
func stage_color()->Color:
 return [Color("8fd86a"),Color("4f9e3a"),Color("e2b84a"),Color("dcebf2")][world.season()]

# ---------------- season stages per field ----------------
func hour()->float:return world.sky_value()*24.0
func planted(f:int)->float:   # spring: share of the field already planted
 if world.season()!=0:return 1.0 if world.season() in [1,2] else 0.0
 return clampf((world.season_progress()-f*.08)/.6,0,1)
func harvested(f:int)->float:   # autumn: share already cut
 if world.season()!=2:return 1.0 if world.season()==3 else 0.0
 return clampf((world.season_progress()-.3-f*.06)/.5,0,1)
func stage_text()->String:
 match world.season():
  0:return "插秧中 · 已插 %d%%"%int(planted(0)*100)
  1:return "稻子在长 · %d%%"%int(world.season_progress()*100)
  2:return "收割中 · 已割 %d%%"%int(harvested(0)*100) if harvested(0)>0 else "稻穗金黄，快要收割了"
 return "田里结冰了，等来年开春"
const TALK=[
 ["春天插秧啦！一行一行要插直哦。","水要没过脚背，秧苗才长得好。","秧苗小小的，过几天就绿成一片啦。"],
 ["夏天稻子长得飞快，要记得除草。","田里有青蛙在叫，今年准是好收成。","太阳好大，喝口水再干活。"],
 ["金灿灿的！割下来挂在稻架上晒干。","新米煮饭最香了，等你来尝。","今年稻穗沉甸甸的。"],
 ["田里结冰了，我们回屋里搓草绳。","冰上滑一圈好好玩！","明年开春再一起插秧吧。"]]
func talk(extra:String)->String:
 if extra=="sign":return "清溪稻田 · %s\n%s"%[Seasons.label(world.calendar_day()),stage_text()]
 var lines:Array=TALK[world.season()]
 return "团团：「%s」"%lines[rng.randi()%lines.size()]
func season_changed():
 for a in workers:a.mode="start";a.route.clear();a.timer=workers.find(a)*.8

# ---------------- 团团 ----------------
func working()->bool:
 var h=hour()
 return h>=6.5 and h<18.0
func next_spot(a:Dictionary)->Vector2:
 a.seed=(int(a.seed)*1103515245+12345)&0x7fffffff
 var s=int(a.seed)
 var season_=world.season()
 if not working() or (season_==3 and a!=workers[0]):return HOME+Vector2(30+workers.find(a)*30,30)
 if s%4==0:
  var free=(int(a.field)+1)%fields.size()
  if not workers.any(func(other):return other!=a and other.field==free):a.field=free
 var r:Rect2=fields[a.field]
 var row_y=r.position.y+24+float(s/7%9)*24
 match season_:
  0:return Vector2(r.position.x+clampf(r.size.x*planted(a.field),14,r.size.x-14),row_y)   # the planting front
  2:return Vector2(r.position.x+clampf(r.size.x*harvested(a.field),14,r.size.x-14),row_y)  # the harvest front
  3:return r.position+Vector2(40+s%int(r.size.x-80),30+(s/13)%int(r.size.y-60))   # skating
 # Summer: walk the dikes around the field, looking for weeds.
 var side=s%4
 match side:
  0:return Vector2(r.position.x+float(s%int(r.size.x)),r.position.y-DIKE/2)
  1:return Vector2(r.end.x+DIKE/2,r.position.y+float(s%int(r.size.y)))
  2:return Vector2(r.position.x+float(s%int(r.size.x)),r.end.y+DIKE/2)
 return Vector2(r.position.x-DIKE/2,r.position.y+float(s%int(r.size.y)))
func in_field(p:Vector2)->int:
 for i in fields.size():
  if fields[i].has_point(p):return i
 return -1
## Where E reaches a 团团 standing in a field: the nearest point of the dike.
func dike_point(p:Vector2)->Vector2:
 var i=in_field(p)
 if i<0:return p
 var r:Rect2=fields[i]
 var d=[p.x-r.position.x,r.end.x-p.x,p.y-r.position.y,r.end.y-p.y]
 var k=d.find(d.min())
 return [Vector2(r.position.x-20,p.y),Vector2(r.end.x+20,p.y),Vector2(p.x,r.position.y-20),Vector2(p.x,r.end.y+20)][k]
func start_walk(a:Dictionary,dest:Vector2,home:bool):
 var pos:Vector2=a.node.position
 var lane=(workers.find(a)-1)*12.0
 var origin_field=in_field(pos)
 var end_field=in_field(dest)
 var points:Array=[]
 # Stay in the same working row when possible. Travel between plots on the dikes.
 if origin_field!=end_field or origin_field<0:
  var top_y=fields[origin_field].position.y-DIKE/2+lane if origin_field>=0 else nearest_dike_y(pos.y,lane)
  var end_y=fields[end_field].position.y-DIKE/2+lane if end_field>=0 else nearest_dike_y(dest.y,lane)
  points.append(Vector2(pos.x,top_y))
  if absf(top_y-end_y)>2:
   var cross_x=ORIGIN.x+FIELD_SIZE.x+DIKE/2+lane
   points.append(Vector2(cross_x,top_y));points.append(Vector2(cross_x,end_y))
  points.append(Vector2(dest.x,end_y))
 points.append(dest)
 a.goal=dest;a.route=points;a.mode="walk";a.resting=home

func nearest_dike_y(y:float,lane:float)->float:
 var first=ORIGIN.y-DIKE/2
 return first+clampf(roundf((y-first)/(FIELD_SIZE.y+DIKE)),0,2)*(FIELD_SIZE.y+DIKE)+lane

func tick(dt:float):
 age+=dt
 if not is_instance_valid(world.player):return
 var villagers=world.villagers
 for i in workers.size():
  var a:Dictionary=workers[i];var node:Node2D=a.node
  a.phase+=dt
  var start=node.position
  var home=not working() or (world.season()==3 and i!=0)
  var bend=false
  if home!=a.resting:
   start_walk(a,next_spot(a),home)
  if a.mode in ["start","work"]:
   a.timer-=dt;bend=a.mode=="work" and world.season() in [0,2]
   if a.timer<=0:start_walk(a,next_spot(a),home)
  if a.mode=="walk":
   var speed=WALK*(.65 if in_field(start)>=0 and world.season()!=3 else (1.8 if world.season()==3 and not home else 1.0))
   if not a.route.is_empty():
    var candidate=start.move_toward(a.route[0],dt*speed)
    var clear=true
    for other in workers:
     if other==a or not other.node.visible:continue
     var gap=candidate.distance_to(other.node.position)
     if gap<21 and gap+.001<start.distance_to(other.node.position):
      clear=false;break
    if clear:node.position=candidate;a["yield_time"]=0.0
    else:
     a["yield_time"]=float(a.get("yield_time",0))+dt
     if a.yield_time>1.0+i*.35:
      var side=start.direction_to(a.route[0]).orthogonal()
      a.route.push_front(start+side*23);a.yield_time=0.0
    if node.position.distance_to(a.route[0])<1:a.route.pop_front()
   if a.route.is_empty():
    a.mode="home" if home else "work";a.timer=2.5+float(int(a.seed)%40)/10.0
  node.visible=not (a.mode=="home")
  var step=node.position-start
  if villagers!=null:
   a.direction=villagers.direction_of(step,int(a.direction))
   var frame=villagers.stride_frame(a,step.length())
   if bend:frame=1+int(a.phase*2.5)%2
   if world.season()==3 and not home:frame=1   # gliding on the ice
   var factor=60.0/villagers.FRAME_SIZE.x
   a.sprite.texture=villagers.walking_texture(i%3,int(a.direction),frame)
   a.sprite.scale=Vector2.ONE*factor
   var dip=(2.0+roundf(sin(a.phase*5.0))*2.0) if bend else 0.0
   a.sprite.position=Vector2(-villagers.FRAME_SIZE.x*.5*factor,-villagers.GROUND*factor+dip)
  a.tag.visible=node.visible and node.position.distance_to(world.player.position)<110
  a.tag.text="团团 · "+["插秧","除草","收割","滑冰"][world.season()] if node.visible and a.mode=="work" or world.season()==3 else "团团"
  var tip=world.sun_dir*world.sun_len*58.0
  a.shadow.visible=node.visible
  a.shadow.polygon=PackedVector2Array([node.position+Vector2(-11,0),node.position+Vector2(11,0),node.position+tip+Vector2(8,0),node.position+tip+Vector2(-8,0)])
  a.shadow.color=world.shadow_ink
  for t in world.targets:
   if t.kind=="paddy" and t.extra==str(i):
    t.pos=dike_point(node.position) if node.visible else HOME+Vector2(30+i*30,30)
    t.name="团团 · "+["插秧","除草","收割","滑冰"][world.season()]+"中" if node.visible else "团团 · 在休息"

func _process(dt):
 if world==null or world.map_id!="village" or not is_instance_valid(world.player):return
 if not world.is_physics_processing():tick(dt) # checks drive the world by hand
 redraw_timer-=dt
 if redraw_timer<=0:
  redraw_timer=.08
  update_rice(.08)
  queue_redraw()
func update_rice(dt:float):
 weather_timer-=dt
 if weather_timer<=0:
  weather_timer=4.0
  var host=world.time_host()
  if host:
   var weather=host.rural_weather()
   wind_force=.54+clampf(float(weather.get("wind",1)),0,4)*.22
   cloud_cover=clampf(float(weather.get("cloud",.2)),0,1)
 var s=world.season()
 var growth=world.season_progress()
 var direction=Vector2(cos(age*.039),.46*sin(age*.051-.7)).normalized()
 var sun=clampf(sin((world.sky_value()-.25)*TAU)*1.5,0,1)*(1.0-.65*cloud_cover)
 for i in rice_nodes.size():
  var layer=rice_nodes[i]
  layer.visible=s!=3 and (s!=2 or harvested(i)<1)
  if not layer.visible:continue
  var m=layer.material
  m.set_shader_parameter("age",age);m.set_shader_parameter("season",s)
  m.set_shader_parameter("growth",growth);m.set_shader_parameter("breeze",direction)
  m.set_shader_parameter("wind_strength",wind_force);m.set_shader_parameter("sun_side",-world.sun_dir.normalized())
  m.set_shader_parameter("sunlight",sun);m.set_shader_parameter("ground_light",world.ground_tint)
  m.set_shader_parameter("standing",Vector2(harvested(i)*FIELD_SIZE.x,planted(i)*FIELD_SIZE.x))
func _physics_process(dt):
 if world!=null and world.map_id=="village" and world.is_physics_processing() and is_instance_valid(world.player):tick(dt)

# ---------------- drawing ----------------
func _draw():
 var tint:Color=world.ground_tint
 var season_=world.season()
 var g=area()
 if surfaces.has("banks"):draw_texture_rect(surfaces.banks,g,false,tint)
 if season_==3:
  for f in fields:draw_rect(f.grow(5),Color("dfe8da")*tint,false,4)
 # Irrigation inlet from the creek side, west of the dikes.
 draw_rect(Rect2(g.position.x-96,g.get_center().y-8,96,16),(Color("cfe2ea") if season_==3 else Color("6fb8b0"))*tint)
 for i in fields.size():draw_field(i,fields[i],season_,tint)
 # Ripples around 团团 standing in the water.
 if season_ in [0,1]:
  for a in workers:
   if a.node.visible and in_field(a.node.position)>=0:
    var ph=fmod(age*.8+a.phase,1.0)
    draw_arc(a.node.position+Vector2(0,2),6.0+ph*10.0,0,TAU,14,Color(1,1,1,.5*(1.0-ph))*tint,2.0)

## Wind (the owner: let the engine move the rice, swaying as the wind passes). Gusts come
## and go (strength 0..1 over ~10 s) and roll across the paddies from the south-west as a
## travelling wave; each tuft bends by the wave at its own position, and bent tips catch
## the light. Returns -1..1.
func gust()->float:return .35+.65*pow(maxf(0,sin(age*.55)*sin(age*.23+1.0)),.6)
func wind(p:Vector2)->float:
 var wave=sin((p.x*.9-p.y*.45)*.014-age*2.4)+.35*sin(p.x*.05+age*3.1)
 return clampf(wave*gust(),-1,1)
func draw_field(i:int,r:Rect2,season_:int,tint:Color):
 var water=Color("6fb8b0");var shine=Color("a4dcd2")
 if season_==3:
  draw_rect(r,Color("d6e8f0")*tint)
  for k in 9:
   var h=absi(hash(Vector2i(i,k)))
   var p=r.position+Vector2(h%int(r.size.x-60),(h/97)%int(r.size.y-30))
   draw_rect(Rect2(p,Vector2(40+h%40,6)),Color("eef6fa")*tint)
   draw_line(p+Vector2(10,14),p+Vector2(34,22),Color("a9c3d2")*tint,2)
  for y in range(int(r.position.y)+16,int(r.end.y)-8,24):
   for x in range(int(r.position.x)+12,int(r.end.x)-8,20):draw_rect(Rect2(x,y-3,2,3),Color("c2b08a")*tint)
  if fmod(age,2.0)<1.0:   # frost sparkle
   var h2=absi(hash(Vector2i(i,int(age/2.0))))
   draw_rect(Rect2(r.position+Vector2(h2%int(r.size.x),(h2/7)%int(r.size.y)),Vector2(2,2)),Color.WHITE)
  return
 var cut=harvested(i) if season_==2 else 0.0
 var front=r.position.x+r.size.x*cut
 # Water (or drained mud behind the harvest front).
 draw_rect(r,water*tint)
 if surfaces.has("flooded"):draw_texture_rect(surfaces.flooded,r,false,tint)
 if season_==2:
  draw_rect(r,Color("97834a9f")*tint)
 if cut>0:
  var bed=Rect2(r.position,Vector2(front-r.position.x,r.size.y))
  if surfaces.has("stubble"):draw_texture_rect_region(surfaces.stubble,bed,Rect2(Vector2.ZERO,Vector2(256*cut,128)),tint)
  else:draw_rect(bed,Color("a08560")*tint)
 for y in range(int(r.position.y)+6,int(r.end.y) if season_!=2 else 0,24):   # ripples in flooded fields
  var off=fmod(age*7.0+y+9*sin(y*.18),64.0)
  for x in range(int(maxf(r.position.x,front))+int(off),int(r.end.x)-20,64):draw_rect(Rect2(x,y,9+4*sin(y*.09),1),Color(shine,.52)*tint)
 if cut>0:
  for y in range(int(r.position.y)+16,int(r.end.y)-2,18):
   for x in range(int(r.position.x)+10,int(front)-4,16):
    var j=absi(hash(Vector2i(x,y)))
    var p=Vector2(x+j%7-3,y+(j/13)%7-3)
    var lean=wind(p)*1.35
    draw_line(p+Vector2(-3,1),p+Vector2(3,1),Color("806744")*tint,1.5)
    draw_line(p,p+Vector2(-2+lean,-4-j%4),Color("c59e5b")*tint,1.5)
    draw_line(p+Vector2(1,0),p+Vector2(3+lean,-4),Color("d1b472")*tint,1.2)
 if season_==2 and cut>0:   # sheaves drying on racks (稲架) along the south dike
  var racks=int(cut*7.0)
  for k in racks:
   var p=Vector2(r.position.x+30+k*68,r.end.y+28)
   draw_rect(Rect2(p+Vector2(-2,-26),Vector2(4,28)),Color("6b4430")*tint);draw_rect(Rect2(p+Vector2(48,-26),Vector2(4,28)),Color("6b4430")*tint)
   draw_rect(Rect2(p+Vector2(-2,-24),Vector2(54,3)),Color("8a5a38")*tint)
   for b in 5:
    var knot=p+Vector2(5+b*9,-23)
    var swing=wind(knot)*2.6
    var length=15+(b+k)%3
    draw_colored_polygon(PackedVector2Array([knot+Vector2(-1,0),knot+Vector2(1,0),knot+Vector2(5+swing,length),knot+Vector2(-5+swing,length-1)]),Color("c19a50")*tint)
    draw_line(knot+Vector2(0,3),knot+Vector2(-3+swing,length-2),Color("efd083")*tint,2)
    draw_line(knot+Vector2(-2,4),knot+Vector2(2,4),Color("896846")*tint,2)
