extends "res://qingxi-live/house/continuous_house.gd"
const State=preload("res://qingxi-live/village-center/pasture_state.gd")
const Session=preload("res://qingxi-live/village3d/session.gd")
const Nav=preload("res://qingxi-live/ranch-life/navigation.gd")
const SAVE="user://village-center-test.json"
const KINDS=["cow","sheep","pig"]
const TITLES={"cow":"奶牛","sheep":"绵羊","pig":"猪"}
const BARN=Rect2(-21,-36,42,28)
const REST_AREA=Rect2(-19,-34,38,17)
const REST_SPACING=3.6
const ANIMAL_RADIUS=.6
var sim=State.new()
var nav=Nav.new()
var edges={}
var fence_nodes={}
var herd={}
var paints=[]
var scenery_sprites=[]
var cutaway_details:Array[Node3D]=[]
var roof_group:Node3D
var barn_facade:Sprite3D
var fence_root:Node3D
var hud_layer:CanvasLayer
var heading_label:Label
var help_label:Label
var message_label:Label
var menu:PanelContainer
var menu_rows:VBoxContainer
var build_mode=false
var fence_type="fence"
var hover_key=""
var ghost:MeshInstance3D
var hour=8.5
var cycle=true
var held_food=""
var rng=RandomNumberGenerator.new()
var tick_clock=0.0
var departing=false
var brush_button=0
var last_brush=""
var cutaway=false
var inspection=false
var daylight=Color.WHITE
var stations=[]
var textures={}
var paint_cache={}
var audio
var checker

func _ready():
 testing="--check-ranch-life" in OS.get_cmdline_user_args() or bool(get_tree().get_meta("center_testing",false))
 rng.seed=72217
 if not Session.consume(get_tree(),sim) and not testing:sim.load_from(SAVE)
 if not testing:sim.settle()
 sim.data.map="ranch"
 hour=float(get_tree().get_meta("center_hour",8.5));cycle=bool(get_tree().get_meta("center_cycle",true))
 make_light();build_land();build_barn();load_fences()
 if testing:print("RANCH_INIT geometry")
 nav.edges=edges;nav.rebuild()
 if testing:print("RANCH_INIT navigation")
 make_player();player.position=Vector3(1,.08,33);player.collision_layer=2;player.collision_mask=1
 contact_shadow(player,Vector2(.8,.55))
 camera.size=28;portrait.texture_filter=BaseMaterial3D.TEXTURE_FILTER_NEAREST
 fence_root=Node3D.new();add_child(fence_root);refresh_fences()
 make_ui();refresh_herd();apply_sky();update_view(1)
 if testing:print("RANCH_INIT herd")
 audio=preload("res://qingxi-live/village-center/audio.gd").new();add_child(audio);audio.place("ranch",is_night())
 get_tree().auto_accept_quit=false
 DisplayServer.window_set_title("清溪村 · 牧场与共用畜舍")
 if "--check-ranch-life" in OS.get_cmdline_user_args():
  checker=preload("res://qingxi-live/ranch-life/checks.gd").new();checker.run.call_deferred(self)

func image_texture(path:String)->Texture2D:
 if not textures.has(path):textures[path]=ImageTexture.create_from_image(Image.load_from_file(path))
 return textures[path]
func paint(color:Color,texture_path="",world_mapping=false,repeat_=1.0,planks_=false)->ShaderMaterial:
 var key=str([color,texture_path,world_mapping,repeat_,planks_])
 if paint_cache.has(key):return paint_cache[key]
 var m=ShaderMaterial.new();m.shader=preload("res://qingxi-live/ranch-life/paint.gdshader")
 m.set_shader_parameter("pigment",color);m.set_shader_parameter("daylight",daylight)
 m.set_shader_parameter("world_uv",world_mapping);m.set_shader_parameter("repeat_scale",repeat_);m.set_shader_parameter("planks",planks_)
 if texture_path!="":m.set_shader_parameter("ink",image_texture(texture_path));m.set_shader_parameter("textured",true)
 paints.append(m);paint_cache[key]=m;return m
func timber(parent:Node3D,p:Vector3,s:Vector3,color:Color,solid=false)->MeshInstance3D:
 var node=box(parent,p,s,color,solid);node.material_override=paint(color,"",false,1,true);return node
func obstacle(p:Vector3,s:Vector3):nav.obstacles.append(Rect2(Vector2(p.x-s.x/2,p.z-s.z/2),Vector2(s.x,s.z)))
func prop(name_:String,p:Vector3,width_:float)->Sprite3D:
 var t=image_texture("res://qingxi-live/village-center/art/regions/props/"+name_+".png")
 var s=Sprite3D.new();s.texture=t;s.billboard=BaseMaterial3D.BILLBOARD_ENABLED;s.alpha_cut=SpriteBase3D.ALPHA_CUT_DISCARD;s.texture_filter=BaseMaterial3D.TEXTURE_FILTER_NEAREST;s.pixel_size=width_/t.get_width();s.offset.y=t.get_height()/2.0;s.position=p;add_child(s);scenery_sprites.append(s);return s
func build_land():
 var floor_=box(self,Vector3(0,-.22,4),Vector3(104,.4,112),Color.WHITE,true)
 floor_.material_override=paint(Color.WHITE,"res://qingxi-live/village-center/art/garden-v3/sprites/grass.png",true,.12)
 floor_.material_override.set_shader_parameter("grass",true)
 var lane=box(self,Vector3(0,-.008,15),Vector3(4,.016,46),Color.WHITE)
 lane.material_override=paint(Color.WHITE,"res://qingxi-live/village-center/art/garden-v3/sprites/earth.png",true,.2)
 for r in [Rect2(-49,-50,98,.4),Rect2(-49,58,98,.4),Rect2(-49,-50,.4,108),Rect2(48.6,-50,.4,108)]:
  var p=Vector3(r.get_center().x,1,r.get_center().y);var s=Vector3(r.size.x,2,r.size.y);box(self,p,s,Color("82985b"),true);obstacle(p,s)
 for i in 48:
  var side=i%4;var p=Vector3.ZERO
  if side<2:p=Vector3(-42+i/4*7,0,-46 if side==0 else 52)
  else:p=Vector3(-44 if side==2 else 44,0,-41+i/4*8)
  if p.z>33 and absf(p.x)<7:continue
  var path="res://qingxi-live/village-center/art/jp/trees/tree_"+("deep" if i%3==0 else "green")+"_"+str(i%3)+".png"
  if not FileAccess.file_exists(path):path="res://qingxi-live/village-center/art/jp/trees/deep.png"
  if FileAccess.file_exists(path):
   var tree=Sprite3D.new();tree.texture=image_texture(path);tree.pixel_size=7.0/tree.texture.get_height();tree.offset.y=tree.texture.get_height()/2.0;tree.billboard=BaseMaterial3D.BILLBOARD_ENABLED;tree.alpha_cut=SpriteBase3D.ALPHA_CUT_DISCARD;tree.texture_filter=BaseMaterial3D.TEXTURE_FILTER_NEAREST;tree.position=p;add_child(tree);scenery_sprites.append(tree)
 prop("signpost",Vector3(4,0,32),2.8)
 prop("windmill",Vector3(-27,0,-20),5.0);prop("silo",Vector3(27,0,-22),4)
 for p in [Vector3(-25,0,-9),Vector3(-28,0,-9),Vector3(26,0,-12)]:prop("haystack",p,3)
 prop("cart",Vector3(-21,0,-4),3.5);prop("milk_cans",Vector3(-18,0,-6),2)
 label3("← 清溪村 / 自家农场",Vector3(0,.3,35),.014)

func label3(text_:String,p:Vector3,pixels=.014)->Label3D:
 var l=Label3D.new();l.text=text_;l.font_size=28;l.pixel_size=maxf(pixels,.024);l.outline_size=5;l.modulate=Color("fff2cf");l.billboard=BaseMaterial3D.BILLBOARD_ENABLED;l.position=p;add_child(l);return l
func wall_piece(p:Vector3,s:Vector3,cut_height=.36):
 var node=timber(self,p,s,Color("a65f47"),true)
 node.hide()
 obstacle(p,s)
 var base=box(self,Vector3(p.x,.18,p.z),Vector3(s.x,.36,s.z+.04),Color("8c8073"));base.material_override=paint(Color("8c8073"))
 cutaway_details.append(base)
 if cut_height>.36:
  var boards=timber(self,Vector3(p.x,cut_height*.5+.18,p.z),Vector3(s.x,cut_height-.36,s.z),Color("a65f47"))
  var cap=timber(self,Vector3(p.x,cut_height,p.z),Vector3(s.x+.07,.13,s.z+.07),Color("624339"))
  cutaway_details.append_array([boards,cap])
func build_barn():
 var straw_source=Image.load_from_file("res://qingxi-live/village-center/art/regions/props/haybale.png")
 var straw_texture=ImageTexture.create_from_image(straw_source.get_region(Rect2i(8,3,8,8)))
 var floor_=box(self,Vector3(0,-.005,-22),Vector3(42,.02,28),Color.WHITE)
 floor_.material_override=paint(Color("d7be88"),"res://qingxi-live/village-center/art/garden-v3/sprites/earth.png",true,.25)
 wall_piece(Vector3(0,1.7,-36),Vector3(42,3.4,.3),2.1)
 wall_piece(Vector3(-21,1.7,-22),Vector3(.3,3.4,28),1.0)
 wall_piece(Vector3(21,1.7,-22),Vector3(.3,3.4,28),1.0)
 wall_piece(Vector3(-12,1.7,-8),Vector3(18,3.4,.3));wall_piece(Vector3(12,1.7,-8),Vector3(18,3.4,.3))
 var straw=box(self,Vector3(0,.016,REST_AREA.get_center().y),Vector3(REST_AREA.size.x,.032,REST_AREA.size.y),Color("d9bd78"))
 var straw_mat=ShaderMaterial.new()
 straw_mat.shader=preload("res://qingxi-live/ranch-life/straw.gdshader")
 straw_mat.set_shader_parameter("grain",straw_texture)
 straw.material_override=straw_mat
 paints.append(straw_mat)
 make_station(Vector2(8,7))
 var aisle=box(self,Vector3(0,.018,-12),Vector3(41,.036,6),Color.WHITE);aisle.material_override=paint(Color("d7c8ab"),"res://qingxi-live/village-center/art/garden-v3/sprites/paving.png",true,.4)
 cutaway_details.append_array([floor_,straw,aisle])
 for p in [Vector3(-19,.025,-34.6),Vector3(19,.025,-34.6)]:
  cutaway_details.append(prop("haybale",p,2.0))
 build_barn_depth()
 var apron=box(self,Vector3(0,.012,-7),Vector3(7,.024,6),Color.WHITE);apron.material_override=paint(Color.WHITE,"res://qingxi-live/village-center/art/garden-v3/sprites/paving.png",true,.3)
 # Pig wallow stays outside the dry sleeping stalls.
 var mud=MeshInstance3D.new();var mud_plane=PlaneMesh.new();mud_plane.size=Vector2(7,5);mud.mesh=mud_plane;mud.position=Vector3(17,.025,13);add_child(mud)
 var mud_mat=ShaderMaterial.new();mud_mat.shader=preload("res://qingxi-live/ranch-life/decal.gdshader");mud_mat.set_shader_parameter("art",image_texture("res://qingxi-live/village-center/art/regions/props/mud.png"));mud.material_override=mud_mat;paints.append(mud_mat)
 # Fixed-camera illustrated exterior over the same physical barn. Its central
 # opening aligns with the real door; entering reveals the actual 3D stalls.
 barn_facade=Sprite3D.new();barn_facade.texture=image_texture("res://qingxi-live/ranch-life/art/barn-exterior.png")
 barn_facade.billboard=BaseMaterial3D.BILLBOARD_ENABLED;barn_facade.alpha_cut=SpriteBase3D.ALPHA_CUT_DISCARD;barn_facade.texture_filter=BaseMaterial3D.TEXTURE_FILTER_NEAREST
 barn_facade.pixel_size=44.0/544;barn_facade.offset.y=barn_facade.texture.get_height()/2.0;barn_facade.position=Vector3(0,.025,-7.65);add_child(barn_facade);scenery_sprites.append(barn_facade)

func build_barn_depth():
 roof_group=Node3D.new()
 add_child(roof_group)
 # The rear eave sits on the same wall that becomes visible in the cutaway.
 var rear_z=BARN.position.y-.35
 var ridge_z=BARN.get_center().y
 var half_width=BARN.size.x*.47
 var corners=[Vector3(-half_width,2.8,rear_z),Vector3(half_width,2.8,rear_z),Vector3(half_width-1,8.45,ridge_z),Vector3(-half_width+1,8.45,ridge_z)]
 var uvs=[Vector2.ZERO,Vector2.RIGHT,Vector2.ONE,Vector2.DOWN]
 var surface=SurfaceTool.new()
 surface.begin(Mesh.PRIMITIVE_TRIANGLES)
 for i in [0,1,2,0,2,3]:
  surface.set_uv(uvs[i])
  surface.add_vertex(corners[i])
 surface.generate_normals()
 var rear=MeshInstance3D.new()
 rear.mesh=surface.commit()
 var material_=ShaderMaterial.new()
 material_.shader=preload("res://qingxi-live/ranch-life/paint.gdshader")
 var front=image_texture("res://qingxi-live/ranch-life/art/barn-exterior.png").get_image()
 material_.set_shader_parameter("ink",ImageTexture.create_from_image(front.get_region(Rect2i(54,35,435,35))))
 material_.set_shader_parameter("textured",true)
 material_.set_shader_parameter("pigment",Color("b2b4c6"))
 rear.material_override=material_
 roof_group.add_child(rear)
 paints.append(material_)
 timber(roof_group,Vector3(0,2.75,rear_z),Vector3(half_width*2,.15,.16),Color("594854"))
 # The image's transparent opening looks into real shaded paving and timber.
 var threshold=box(roof_group,Vector3(0,.022,-16.5),Vector3(6.05,.044,17.0),Color.WHITE)
 var threshold_mat=ShaderMaterial.new()
 threshold_mat.shader=preload("res://qingxi-live/ranch-life/threshold.gdshader")
 threshold_mat.set_shader_parameter("paving",image_texture("res://qingxi-live/village-center/art/garden-v3/sprites/paving.png"))
 threshold.material_override=threshold_mat
 paints.append(threshold_mat)
 for side in [-1.0,1.0]:
  timber(roof_group,Vector3(3.03*side,1.35,-10.2),Vector3(.24,2.7,4.9),Color("614033"))

func make_station(p:Vector2):
 for n in 2:
  var at=p+Vector2(n*7,0)
  var size_=Vector3(5,.6,1)
  var frame=box(self,Vector3(at.x,.3,at.y),size_,Color("8e684e"),true)
  obstacle(frame.position,size_)
  frame.hide()
  var trough=Sprite3D.new();trough.texture=image_texture("res://qingxi-live/village-center/art/garden-v3/sprites/trough_"+("water" if n else "feed")+".png")
  trough.billboard=BaseMaterial3D.BILLBOARD_ENABLED;trough.alpha_cut=SpriteBase3D.ALPHA_CUT_DISCARD;trough.texture_filter=BaseMaterial3D.TEXTURE_FILTER_NEAREST;trough.pixel_size=5.0/trough.texture.get_width();trough.offset.y=trough.texture.get_height()/2.0;trough.position=Vector3(at.x,.02,at.y+.5);add_child(trough);scenery_sprites.append(trough)
  stations.append(at+Vector2(0,2))

func saved_layout()->Dictionary:
 if not sim.data.has("layout"):sim.data.layout={}
 return sim.data.layout
func load_fences():
 var saved=saved_layout()
 if saved.has("ranch_edges_v1"):
  edges=saved.ranch_edges_v1.duplicate(true)
  # The older north fence crossed land now occupied by the enlarged barn.
  for key in edges.keys():
   if BARN.grow(.8).intersects(nav.fence_rect(key)):edges.erase(key)
  return
 # Keep Claude's former cell-paint layout in the save. New edge layout has its own schema.
 for x in range(-14,14):
  edges[nav.edge_key(Vector2i(x,-21),Vector2i(x+1,-21))]="fence"
  edges[nav.edge_key(Vector2i(x,14),Vector2i(x+1,14))]="open" if x in [-1,0] else "fence"
 for y in range(-21,14):
  for x in [-14,14]:edges[nav.edge_key(Vector2i(x,y),Vector2i(x,y+1))]="fence"
 saved.ranch_edges_v1=edges.duplicate(true)
func refresh_fences():
 for child in fence_root.get_children():child.free()
 fence_nodes.clear()
 for key in edges:draw_fence(key)
 for a in herd.values():a.path=PackedVector2Array();a.repath=0.0
func draw_fence(key:String):
 var ends=nav.endpoints(key);var p=Vector2(ends[0])*2;var q=Vector2(ends[1])*2;var c=(p+q)/2;var horizontal=absf(q.x-p.x)>0
 var root=Node3D.new();fence_root.add_child(root);fence_nodes[key]=root
 for end in [p,q]:timber(root,Vector3(end.x,.65,end.y),Vector3(.22,1.3,.22),Color("9b6e45"))
 var opened=edges[key]=="open"
 var size_=Vector3(2,.22,.17) if horizontal else Vector3(.17,.22,2)
 if opened:
  size_=Vector3(.13,.15,1.7) if horizontal else Vector3(1.7,.15,.13);c=p+(Vector2(0,.85) if horizontal else Vector2(.85,0))
 for height in [.38,.86]:timber(root,Vector3(c.x,height,c.y),size_,Color("c99d63") if edges[key]=="fence" else Color("e2bf7c"))
 if not opened:
  var body=StaticBody3D.new();var shape=CollisionShape3D.new();var box_=BoxShape3D.new();box_.size=Vector3(2,1.1,.18) if horizontal else Vector3(.18,1.1,2);shape.shape=box_;body.position=Vector3(c.x,.55,c.y);root.add_child(body);body.add_child(shape)
func edit_edge(key:String,value:String)->String:
 var r=nav.fence_rect(key)
 if not Rect2(-44,-46,88,94).encloses(r):return "围栏请放在牧场草地内"
 if BARN.grow(.8).intersects(r):return "畜舍墙体、入口和室内通道不能放围栏"
 if r.grow(.55).has_point(Vector2(player.position.x,player.position.z)) and value!="":return "先离开这一段，再安装围栏"
 for a in herd.values():
  if r.grow(.75).has_point(Vector2(a.body.position.x,a.body.position.z)) and value!="":return "这段有动物经过，稍等它走开"
 for box_ in nav.obstacles:
  if box_.intersects(r):return "这里有固定设施"
 var previous=edges.get(key,"")
 if previous==value:return ""
 if value=="":edges.erase(key)
 else:edges[key]=value
 nav.edges=edges;nav.rebuild()
 var valid=true
 for a in herd.values():
  var p=Vector2(a.body.position.x,a.body.position.z)
  if nav.path(p,REST_AREA.get_center()).is_empty():valid=false;break
 for station in stations:
  if nav.path(REST_AREA.get_center(),station).is_empty():valid=false
 if not valid:
  if previous=="":edges.erase(key)
  else:edges[key]=previous
  nav.edges=edges;nav.rebuild();return "这段会封住回舍或食水通道，请留一扇通门"
 refresh_fences();save_progress()
 return "已拆除这一段" if value=="" else ("已安装围栏" if value=="fence" else "通门已打开" if value=="open" else "通门已关闭")

func animal_point(a:Dictionary)->Vector2:
 var p:Vector3=a.body.position
 return Vector2(p.x,p.z)

func clear_of_herd(p:Vector2,spacing:float)->bool:
 for a in herd.values():
  if p.distance_to(animal_point(a))<spacing:return false
 return true

func spawn_point(preferred:Vector2)->Vector2:
 var access=REST_AREA.get_center()
 if clear_of_herd(preferred,2.0) and not nav.path(preferred,access).is_empty():return preferred
 for point in nav.graph.get_point_ids():
  var p=nav.graph.get_point_position(point)
  if p.y<1 or p.y>24 or not clear_of_herd(p,2.0):continue
  if not nav.path(p,access).is_empty():return p
 return access

func choose_rest_goal(a:Dictionary)->Vector2:
 var here=animal_point(a)
 var candidates:Array[Vector2]=[]
 for point in nav.graph.get_point_ids():
  var p=nav.graph.get_point_position(point)
  if REST_AREA.grow(-.9).has_point(p):candidates.append(p)
 # Pick a region within the straw, leaving the entrance side free for traffic.
 var preferred=Vector2(rng.randf_range(-15.0,15.0),rng.randf_range(-32.0,-22.0))
 candidates.sort_custom(func(left:Vector2,right:Vector2):
  return left.distance_squared_to(preferred)<right.distance_squared_to(preferred))
 for p in candidates:
  var occupied=false
  for other in herd.values():
   if other.body==a.body:continue
   var rest:Vector2=other.rest
   if (rest!=Vector2.INF and rest.distance_to(p)<REST_SPACING) or animal_point(other).distance_to(p)<1.4:
    occupied=true
    break
  if not occupied and not nav.path(here,p).is_empty():return p
 return Vector2.INF

func refresh_herd():
 var ids=[]
 for animal in sim.livestock.data.herd:
  if animal.kind not in KINDS:continue
  ids.append(animal.id)
  if herd.has(animal.id):continue
  var index=sim.livestock.members(animal.kind).find(animal)
  var body=CharacterBody3D.new();body.collision_layer=4;body.collision_mask=5;body.floor_snap_length=.35;add_child(body)
  var c=CollisionShape3D.new();var shape=CapsuleShape3D.new();shape.radius=ANIMAL_RADIUS;shape.height=1.45;c.shape=shape;c.position.y=.725;body.add_child(c)
  var shadow=contact_shadow(body,Vector2(1.3,.8))
  var p=Vector2(-17+KINDS.find(animal.kind)*14+(index%3)*3,16+(index/3)*3)
  if animal.has("ranch_position"):p=Vector2(animal.ranch_position[0],animal.ranch_position[1])
  p=spawn_point(p)
  body.position=Vector3(p.x,.04,p.y)
  var sprite=Sprite3D.new();sprite.billboard=BaseMaterial3D.BILLBOARD_ENABLED;sprite.alpha_cut=SpriteBase3D.ALPHA_CUT_DISCARD;sprite.texture_filter=BaseMaterial3D.TEXTURE_FILTER_NEAREST;body.add_child(sprite)
  var model=preload("res://qingxi-live/village-center/garden_animal.gd").new(self,animal.kind)
  var tag=Label3D.new();tag.font_size=24;tag.pixel_size=.018;tag.position.y=1.9;tag.billboard=BaseMaterial3D.BILLBOARD_ENABLED;body.add_child(tag)
  herd[animal.id]={"body":body,"sprite":sprite,"shadow":shadow,"model":model,"tag":tag,"rest":Vector2.INF,"goal":p,"path":PackedVector2Array(),"wait":rng.randf_range(.1,2),"repath":0.0,"mode":"闲逛","heading":Vector2.DOWN,"moving":false,"night":false,"distance":0.0,"stuck":0.0}
 for id_ in herd.keys():
  if id_ not in ids:herd[id_].body.queue_free();herd.erase(id_)
func is_night()->bool:return hour>=19.0 or hour<6.0
func choose_day_goal(a:Dictionary):
 var here=Vector2(a.body.position.x,a.body.position.z)
 var option=rng.randi_range(0,4)
 if option<2:
  # Approach either shared trough from several sides and along its length.
  for offset in [Vector2(-2,0),Vector2.ZERO,Vector2(2,0),Vector2(2,-4),Vector2(0,-4),Vector2(-2,-4)]:
   var p:Vector2=stations[option]+offset
   var claimed=false
   for other in herd.values():
    if other.body!=a.body and other.goal.distance_to(p)<1.7:
     claimed=true
     break
   if claimed or not clear_of_herd(p,1.35) or nav.path(here,p).is_empty():continue
   a.goal=p
   a.mode="去吃食" if option==0 else "去喝水"
   return
 for attempt in 24:
  var origin=Vector2(0,3) if BARN.has_point(here) else here
  var p=origin+Vector2(rng.randf_range(-9,9),rng.randf_range(-8,8))
  p=nav.center(nav.cell(p));p=p.clamp(Vector2(-43,-5),Vector2(43,46))
  if not nav.walkable(p) or BARN.has_point(p):continue
  var route=nav.path(here,p)
  if not route.is_empty():a.goal=p;a.mode="闲逛";return
 a.goal=here;a.mode="休息"
func tick_herd(dt:float):
 for animal in sim.livestock.data.herd:
  if not herd.has(animal.id):continue
  var a:Dictionary=herd[animal.id];var body:CharacterBody3D=a.body;var p=Vector2(body.position.x,body.position.z)
  var night=is_night()
  if night!=a.night:
   a.night=night;a.wait=0.0;a.path=PackedVector2Array();a.repath=0.0
   a.rest=Vector2.INF
   if not night:choose_day_goal(a)
  var following=not night and held_food==sim.livestock.TREAT[animal.kind] and int(sim.data.bag.get(held_food,0))>0 and body.position.distance_to(player.position)<7
  if night:
   if a.rest==Vector2.INF and a.repath<=0:
    a.rest=choose_rest_goal(a)
    if a.rest==Vector2.INF:a.repath=1.0
   a.goal=a.rest if a.rest!=Vector2.INF else p
   a.mode="回舍"
  elif following:a.goal=Vector2(player.position.x,player.position.z);a.mode="跟随食物";a.wait=0
  elif animal.love>0:
   for other in sim.livestock.members(animal.kind):
    if other.id!=animal.id and other.love>0 and herd.has(other.id):a.goal=Vector2(herd[other.id].body.position.x,herd[other.id].body.position.z);a.mode="靠近同伴";a.wait=0;break
  elif a.mode in ["靠近同伴","跟随食物"]:choose_day_goal(a)
  var close=p.distance_to(a.goal)<(1.3 if following or a.mode=="靠近同伴" else .42)
  var velocity2=Vector2.ZERO
  a.repath-=dt
  if close:
   a.path=PackedVector2Array()
   if night:
    if a.rest!=Vector2.INF:a.mode="睡觉"
   elif not following and a.mode!="靠近同伴":
    if a.wait<=0:
     a.wait=rng.randf_range(3,7);a.mode="吃食" if a.mode=="去吃食" else "喝水" if a.mode=="去喝水" else "拱地" if animal.kind=="pig" else "吃草"
    else:
     a.wait-=dt
     if a.wait<=0:choose_day_goal(a);a.repath=0
  else:
   if a.path.is_empty() or ((following or a.mode=="靠近同伴") and a.repath<=0):
    a.path=nav.path(p,a.goal);a.repath=2.5
   var route:PackedVector2Array=a.path
   while not route.is_empty() and p.distance_to(route[0])<.2:route.remove_at(0)
   # Once through the doorway, spread out instead of converging on the same
   # navigation point just inside it.
   if route.size()>1 and p.distance_squared_to(route[0])<6.25 and nav.clear_segment(p,route[1]):
    route.remove_at(0)
   a.path=route
   if not route.is_empty():
    velocity2=(route[0]-p).normalized()*(2.0 if night else 1.5)
    for id_ in herd:
     if id_==animal.id:continue
     var other=herd[id_].body.position;var apart=p-Vector2(other.x,other.z)
     if apart.length()<2.0 and apart.length()>.02:
      var ahead=velocity2.normalized().dot(-apart.normalized())
      if ahead>.25:
       var sideways=Vector2(-velocity2.y,velocity2.x).normalized()
       velocity2+=sideways*(2.0-apart.length())*1.5
      else:velocity2+=apart.normalized()*(2.0-apart.length())*.6
  var before=body.position;body.velocity=Vector3(velocity2.x,body.velocity.y-18*dt,velocity2.y);body.move_and_slide()
  var moved=Vector2(body.position.x-before.x,body.position.z-before.z);a.moving=moved.length()>.001;a.distance+=moved.length()
  if a.moving:a.heading=moved.normalized();a.stuck=0.0
  elif not close:
   a.stuck+=dt
   if a.stuck>1.0:
    a.path=PackedVector2Array()
    a.repath=0
    if night and a.stuck>3.0:a.rest=Vector2.INF;a.stuck=0.0
    elif not night and not following and a.stuck>3.0:choose_day_goal(a);a.stuck=0.0
  a.model.animate(dt,a.moving,a.mode,animal.shorn,a.heading)
  a.sprite.texture=a.model.texture();a.sprite.pixel_size=(2.5 if sim.livestock.adult(animal) else 1.6)/112.0;a.sprite.offset.y=44
  a.sprite.modulate=daylight;a.sprite.scale.y=.85 if a.mode=="睡觉" else 1.0
  a.tag.text="Z z" if a.mode=="睡觉" else TITLES[animal.kind]+" · "+a.mode
  a.tag.visible=cutaway or body.position.distance_to(player.position)<5
  animal.ranch_position=[body.position.x,body.position.z]
  # Existing breeding uses distances in 2D art pixels; preserve its scale.
  animal.pos=[body.position.x*32+1440,body.position.z*32+1000]

func make_ui():
 hud_layer=CanvasLayer.new();hud_layer.layer=3;add_child(hud_layer)
 var root=Control.new();root.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT);root.mouse_filter=Control.MOUSE_FILTER_IGNORE;hud_layer.add_child(root)
 var font=SystemFont.new();font.font_names=PackedStringArray(["Microsoft YaHei","SimHei"]);root.add_theme_font_override("font",font)
 root.add_theme_color_override("font_color",Color("4c3540"))
 for rect in [Rect2(8,6,358,34),Rect2(8,376,752,50)]:
  var panel=Panel.new();panel.position=rect.position;panel.size=rect.size;panel.mouse_filter=Control.MOUSE_FILTER_IGNORE
  var style=StyleBoxFlat.new();style.bg_color=Color("f2dfb8");style.border_color=Color("956b4d");style.set_border_width_all(2);style.set_corner_radius_all(3);panel.add_theme_stylebox_override("panel",style);root.add_child(panel)
 heading_label=Label.new();heading_label.position=Vector2(16,12);heading_label.add_theme_font_size_override("font_size",16);root.add_child(heading_label)
 heading_label.add_theme_color_override("font_color",Color("4c3540"))
 help_label=Label.new();help_label.position=Vector2(16,382);help_label.add_theme_font_size_override("font_size",12);root.add_child(help_label)
 help_label.add_theme_color_override("font_color",Color("4c3540"))
 message_label=Label.new();message_label.position=Vector2(16,350);message_label.add_theme_font_size_override("font_size",13);message_label.add_theme_color_override("font_color",Color("ffe7ab"));root.add_child(message_label)
 menu=PanelContainer.new();menu.position=Vector2(225,70);menu.custom_minimum_size=Vector2(320,0);root.add_child(menu);menu.hide();menu_rows=VBoxContainer.new();menu.add_child(menu_rows)
 ghost=box(self,Vector3.ZERO,Vector3(2,.1,.15),Color("ffe7a0"));ghost.material_override=paint(Color("ffe7a0"));ghost.hide()
func tell(text_:String):message_label.text=text_
func menu_button(text_:String,callback:Callable):
 var b=Button.new();b.text=text_;b.focus_mode=Control.FOCUS_NONE;b.pressed.connect(func():callback.call();save_progress();refresh_herd());menu_rows.add_child(b)
func clear_menu(title:String):
 for child in menu_rows.get_children():child.queue_free()
 var l=Label.new();l.text=title;menu_rows.add_child(l);menu.show()

func add_shared_feed(food:String)->String:
 var eligible:Dictionary={}
 var total=0
 for kind in KINDS:
  var count=sim.livestock.members(kind).size()
  if count>0 and sim.livestock.FOOD[kind]==food and sim.livestock.data.pens[kind].feed<count*172800+86400:
   eligible[kind]=count
   total+=count
 if total==0:return "食槽里的这类饲料已经够了"
 var name_:String=State.ITEM_NAMES[food]
 if sim.data.bag[food]<1:return "背包里没有"+name_
 sim.data.bag[food]-=1
 for kind in eligible:sim.livestock.data.pens[kind].feed+=86400.0*eligible[kind]/total
 return "已向共用食槽添加"+name_

func refill_shared_water():
 for kind in KINDS:
  if not sim.livestock.members(kind).is_empty():sim.livestock.water_pen(kind)
 tell("已加满共用水槽")

func show_station_menu():
 clear_menu("共用食槽与水槽")
 if not sim.livestock.members("cow").is_empty() or not sim.livestock.members("sheep").is_empty():
  menu_button("添加干草",func():tell(add_shared_feed("hay")))
 if not sim.livestock.members("pig").is_empty():
  menu_button("添加猪饲料",func():tell(add_shared_feed("pig_feed")))
 if not herd.is_empty():menu_button("加满共用水槽",refill_shared_water)
 menu_button("清理畜舍",func():
  for kind in KINDS:sim.livestock.clean_pen(kind)
  tell("已清理共用畜舍"))
 menu_button("关闭",func():menu.hide())

func interact():
 for key in edges:
  if edges[key]=="fence":continue
  var c=nav.fence_rect(key).get_center()
  if c.distance_to(Vector2(player.position.x,player.position.z))<2.3:tell(edit_edge(key,"closed" if edges[key]=="open" else "open"));return
 var nearest="";var distance=3.0
 for id_ in herd:
  var d=herd[id_].body.position.distance_to(player.position)
  if d<distance:nearest=id_;distance=d
 if nearest!="":
  var animal=sim.livestock.animal(nearest);clear_menu(TITLES[animal.kind]+" #"+nearest)
  menu_button("挤奶 / 剪毛",func():tell(sim.animal_action(nearest)))
  menu_button("喂小麦 / 胡萝卜",func():tell(sim.livestock.treat(nearest,sim.data.bag)))
  if animal.kind=="pig":menu_button("出售成年猪",func():tell(sim.sell_pig(nearest));menu.hide())
  menu_button("关闭",func():menu.hide());return
 for station in stations:
  if Vector2(player.position.x,player.position.z).distance_to(station)<4:
   show_station_menu()
   return
 tell("靠近动物、食水槽或通门按 E；南边小路可返回村庄")
func show_bag():
 clear_menu("背包 · %d 币"%sim.data.coins)
 var l=Label.new();l.text="干草 %d · 猪饲料 %d · 小麦 %d · 胡萝卜 %d\n牛奶 %d · 羊毛 %d"%[sim.data.bag.hay,sim.data.bag.pig_feed,sim.data.bag.wheat,sim.data.bag.carrot,sim.data.bag.milk,sim.data.bag.wool];menu_rows.add_child(l)
 menu_button("拿小麦引导",func():held_food="wheat";menu.hide())
 menu_button("拿胡萝卜引导",func():held_food="carrot";menu.hide())
 menu_button("收起手中食物",func():held_food="";menu.hide())
 for k in KINDS:
  var kind=str(k);menu_button("放出幼"+TITLES[kind],func():tell(sim.release_young(kind)))
 menu_button("关闭",func():menu.hide())
func mouse_ground()->Vector2:
 var mouse=get_viewport().get_mouse_position();var origin=camera.project_ray_origin(mouse);var direction=camera.project_ray_normal(mouse)
 var point=Plane(Vector3.UP,0).intersects_ray(origin,direction)
 return Vector2(point.x,point.z) if point!=null else Vector2.ZERO
func brush():
 if hover_key==last_brush:return
 last_brush=hover_key;tell(edit_edge(hover_key,"" if brush_button==MOUSE_BUTTON_RIGHT else fence_type))
func _unhandled_input(event):
 if event is InputEventMouseButton:
  if event.pressed and event.button_index in [MOUSE_BUTTON_WHEEL_UP,MOUSE_BUTTON_WHEEL_DOWN]:camera.size=clampf(camera.size+(-2 if event.button_index==MOUSE_BUTTON_WHEEL_UP else 2),22,60)
  if build_mode and event.button_index in [MOUSE_BUTTON_LEFT,MOUSE_BUTTON_RIGHT]:
   brush_button=event.button_index if event.pressed else 0;last_brush=""
   if event.pressed:hover_key=nav.pick(mouse_ground());brush()
 if event is InputEventMouseMotion and build_mode:
  hover_key=nav.pick(mouse_ground())
  if brush_button!=0:brush()
func _unhandled_key_input(event):
 if not event is InputEventKey or not event.pressed or event.echo:return
 match event.physical_keycode:
  KEY_G:build_mode=not build_mode;brush_button=0;menu.hide();save_progress()
  KEY_1:
   if build_mode:fence_type="fence"
  KEY_2:
   if build_mode:fence_type="open"
  KEY_E:interact()
  KEY_B:show_bag()
  KEY_M:
   clear_menu("前往")
   menu_button("清溪村",func():leave("village"))
   menu_button("自家农场",func():leave("field"))
   menu_button("关闭",func():menu.hide())
  KEY_T:cycle=not cycle;tell("日夜自动流转" if cycle else "日夜已暂停")
  KEY_F5:hour=8.5;apply_sky()
  KEY_F6:hour=20.0;apply_sky()
  KEY_TAB:inspection=not inspection
  KEY_ESCAPE:
   if menu.visible:menu.hide()
   elif build_mode:build_mode=false;save_progress()
   else:leave("village")
func _physics_process(dt):
 if departing:return
 elapsed+=dt;tick_clock+=dt
 if cycle and not testing:hour=fposmod(hour+dt*.025,24)
 if tick_clock>=1:
  tick_clock=0
  if not testing:sim.settle()
  sim.livestock.breed();refresh_herd();apply_sky()
 var v=test_motion if testing else Vector2(float(Input.is_physical_key_pressed(KEY_D) or Input.is_physical_key_pressed(KEY_RIGHT))-float(Input.is_physical_key_pressed(KEY_A) or Input.is_physical_key_pressed(KEY_LEFT)),float(Input.is_physical_key_pressed(KEY_S) or Input.is_physical_key_pressed(KEY_DOWN))-float(Input.is_physical_key_pressed(KEY_W) or Input.is_physical_key_pressed(KEY_UP)))
 if menu.visible:v=Vector2.ZERO
 v=v.limit_length();var speed=5.5 if Input.is_physical_key_pressed(KEY_SHIFT) else 3.8
 player.velocity=Vector3(v.x*speed,player.velocity.y-18*dt,v.y*speed);player.move_and_slide()
 if v.length()>.01:facing=(2 if v.x>0 else 1) if absf(v.x)>absf(v.y) else (0 if v.y>0 else 3)
 animate(v.length()>.01);tick_herd(dt);update_view(dt)
 if not testing and player.position.z>36 and absf(player.position.x)<5:leave("village")
 heading_label.text="牧铃牧场    %02d:%02d    %d 币"%[int(hour),int(fmod(hour,1)*60),sim.data.coins]
 help_label.text="围栏：左键安装 / 拖动 · 右键拆除 · 1 木栏 / 2 通门 · G 完成" if build_mode else "WASD 行走 · Shift 快走 · E 照料 / 开门 · G 围栏 · B 背包 · M 地图\n日落回舍 / 清晨出舍 · F5 白天 / F6 夜晚 · Tab 查看畜舍 · 滚轮缩放"
 if build_mode:
  hover_key=nav.pick(mouse_ground());var rect=nav.fence_rect(hover_key);ghost.position=Vector3(rect.get_center().x,.12,rect.get_center().y);ghost.scale=Vector3(rect.size.x/2,1,rect.size.y/.15);ghost.show()
 else:ghost.hide()
func update_view(dt):
 cutaway=BARN.grow(.1).has_point(Vector2(player.position.x,player.position.z)) or inspection
 roof_group.visible=not cutaway
 barn_facade.visible=not cutaway
 for node in cutaway_details:node.visible=cutaway
 for a in herd.values():
  var p=animal_point(a)
  var visible_from_door=absf(p.x)<2.1 and p.y>-11.0
  a.sprite.visible=cutaway or not BARN.has_point(p) or visible_from_door
  a.shadow.visible=a.sprite.visible
  a.tag.visible=a.tag.visible and a.sprite.visible
 var near_barn=absf(player.position.x)<22 and player.position.z<4 and player.position.z>-8
 var target=Vector3(player.position.x*.45,1,-22) if cutaway else player.position+Vector3(0,1,-6 if near_barn else -3)
 camera_focus=target if testing else camera_focus.lerp(target,minf(1,dt*5))
 camera.position=camera_focus+Vector3(0,17,38);camera.look_at(camera_focus)
func apply_sky():
 daylight=Color("8c91b4") if is_night() else Color("ffe6cd") if hour>17 else Color.WHITE
 for m in paints:m.set_shader_parameter("daylight",daylight)
 for s in scenery_sprites:s.modulate=daylight
 if is_instance_valid(portrait):portrait.modulate=daylight
 if audio:audio.place("ranch",is_night())
func contact_shadow(parent:Node3D,size_:Vector2)->MeshInstance3D:
 var mesh=MeshInstance3D.new();var plane=PlaneMesh.new();plane.size=size_;mesh.mesh=plane;mesh.position.y=.055
 var m=ShaderMaterial.new();m.shader=preload("res://qingxi-live/ranch-life/contact.gdshader");mesh.material_override=m;parent.add_child(mesh)
 return mesh
func save_progress():
 saved_layout().ranch_edges_v1=edges.duplicate(true)
 get_tree().set_meta("center_hour",hour);get_tree().set_meta("center_cycle",cycle)
 if not testing:
  sim.settle()
  if not sim.save_to(SAVE):tell("保存失败，请暂时不要关闭窗口")
func leave(destination:String):
 if departing:return
 save_progress();departing=true
 Session.publish(get_tree(),sim,destination)
 get_tree().set_meta("ranch_return",destination)
 get_tree().change_scene_to_file.call_deferred("res://qingxi-live/village-center/main.tscn")
func _notification(what):
 if what==NOTIFICATION_WM_CLOSE_REQUEST:save_progress();get_tree().quit()
