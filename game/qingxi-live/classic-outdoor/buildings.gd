extends RefCounted
const Assembly=preload("res://qingxi-live/material-lab/house_assembly.gd")
const Windows=preload("res://qingxi-live/material-lab/window_details.gd")
const Palette=preload("res://qingxi-live/material-lab/country_house.gd")
const ROLES=preload("res://qingxi-live/material-lab/lab.gd").ROLES
var host
var atlas:Texture2D
var cache={}
var furniture
func _init(h):
 host=h
 furniture=preload("res://qingxi-live/classic-outdoor/classic_furniture.gd").new(h)
 atlas=ImageTexture.create_from_image(Image.load_from_file("res://qingxi-live/material-gallery/assets/01-pixel-story.png"))
func mat(role:String)->ShaderMaterial:
 if cache.has(role):return cache[role]
 var m=ShaderMaterial.new();m.shader=preload("res://qingxi-live/classic-outdoor/selected_material.gdshader")
 var i=1
 if role in ["roof","roof_edge"]:i=0
 elif role=="wall":i=2
 elif role in ["stone","wall_base"]:i=3
 m.set_shader_parameter("cell",Vector2(i%2,i/2));m.set_shader_parameter("atlas",atlas)
 m.set_shader_parameter("roof",role in ["roof","roof_edge"]);m.set_shader_parameter("window",role in ["window","glass"])
 cache[role]=m;return m
func exterior(spec:Dictionary,parent:Node3D)->Node3D:
 var root=Node3D.new();root.name="Exterior";parent.add_child(root)
 var source=Assembly.new();var parts=[]
 if spec.model=="home":parts=source.build()
 else:
  var depth=float(spec.depth)/2
  var doors=[] if spec.get("decorative",false) else [AABB(Vector3(-0.90,-1,depth-0.25),Vector3(1.8,3.4,1))]
  parts=[source.part(spec.model,Vector3.ZERO,0,-0.12,3.25,doors,false,"res://qingxi-live/village01/models/")]
 for meshes in parts:
  for role in meshes:
   if role in ["sign","cloth"]:continue
   if spec.model!="home" and role in ["roof","roof_edge","wood"]:continue
   var n=MeshInstance3D.new();n.mesh=meshes[role];n.material_override=mat(role);root.add_child(n)
  if meshes.has("window"):Windows.new().build(host,meshes.window,root)
 if spec.model!="home":
  preload("res://qingxi-live/classic-outdoor/roof_forms.gd").new().build(spec,root)
  var w=float(spec.get("width",3.12))/2;var d=float(spec.depth)/2
  for x in [-w,w]:
   for z in [-d,d]:
    var post=host.box(root,Vector3(x,1.55,z),Vector3(.16,3.1,.16),Color.WHITE);post.material_override=mat("wood")
 return root
func wing(parent:Node3D)->Node3D:
 var inside=Node3D.new();inside.name="SideWing";parent.add_child(inside)
 host.slab(inside,Rect2(-6.05,5,5.1,6.06))
 host.wall(inside,Vector2(-6.05,5),Vector2(-6.05,11.06),0);host.wall(inside,Vector2(-0.95,5),Vector2(-0.95,11.06),0)
 host.door_wall(inside,Vector2(-6.05,11.06),Vector2(-0.95,11.06),-3.5,1.6,0)
 host.box(inside,Vector3(-5.5,0.4,8),Vector3(0.8,0.8,2.2),Color("ad8b62"),true)
 host.box(parent,Vector3(2.75,-0.1,6.1),Vector3(7.3,0.2,2.2),Color("a47c52"),true)
 for x in [1.0,3.7,6.1]:host.box(parent,Vector3(x,1.5,7.1),Vector3(0.13,3.0,0.13),Color("947852"),true)
 for z in [5.4,5.8,6.2,6.6,7.0]:host.box(parent,Vector3(2.75,0.008,z),Vector3(7.3,0.012,0.02),Color("896d4e"))
 return inside
func shop_furniture(spec:Dictionary,group:Node3D):
 furniture.shop(spec,group)
func cottage_furniture(group:Node3D):
 furniture.cottage(group)
func awning(house:Dictionary):
 var root=house.roof;var spec=house.spec
 if spec.id not in ["seed","livestock","fish"]:return
 var d=float(spec.depth)/2
 var front=d+(1.55 if spec.id in ["seed","fish"] else .28)
 # Framed wooden sign fixed to the facade; no floating green placeholder.
 var board=host.box(root,Vector3(0,2.35,front),Vector3(3.4,.62,.12),Color("b9a27c"))
 for y in [2.01,2.69]:
  var rail=host.box(root,Vector3(0,y,front+.08),Vector3(3.6,.10,.1),Color("705239"));rail.material_override=mat("wood")
 for x in [-1.75,1.75]:
  var rail=host.box(root,Vector3(x,2.35,front+.08),Vector3(.12,.76,.1),Color("705239"));rail.material_override=mat("wood")
 var title=Label3D.new();title.text=spec.name;title.font_size=72;title.pixel_size=.007;title.position=Vector3(0,2.35,front+.09);title.outline_size=2;title.modulate=Color("413126");title.outline_modulate=Color("e0c495");root.add_child(title)
 # Visible wind movement uses a looping AnimationPlayer, as in the tutorial.
 var pivot=Node3D.new();pivot.position=Vector3(1.5,2.0,d+0.4);root.add_child(pivot)
 var tag=host.box(pivot,Vector3(0,-0.25,0),Vector3(0.45,0.4,0.10),Color("b99c70"));tag.material_override=mat("wood")
 var animation=Animation.new();animation.length=4;animation.loop_mode=Animation.LOOP_LINEAR
 var t=animation.add_track(Animation.TYPE_VALUE);animation.track_set_path(t,NodePath(".:rotation:z"))
 for pair in [[0.0,-0.035],[1.0,0.035],[2.0,0.02],[3.0,-0.02],[4.0,-0.035]]:animation.track_insert_key(t,pair[0],pair[1])
 var library=AnimationLibrary.new();library.add_animation("sway",animation)
 var player=AnimationPlayer.new();pivot.add_child(player);player.add_animation_library("",library);player.play("sway")

