extends RefCounted
const Plan=preload("res://qingxi-live/classic-outdoor/layout.gd")
var h
var animations=[]
var props
var route_spots=[]
func _init(host):h=host
func terrain()->ArrayMesh:
 var holes=Plan.footprints();var xs=[-100.0,100.0];var zs=[-100.0,100.0]
 for r in holes:xs.append(r.position.x);xs.append(r.end.x);zs.append(r.position.y);zs.append(r.end.y)
 xs.sort();zs.sort();var st=SurfaceTool.new();st.begin(Mesh.PRIMITIVE_TRIANGLES)
 for x in xs.size()-1:
  for z in zs.size()-1:
   if xs[x+1]-xs[x]<0.001 or zs[z+1]-zs[z]<0.001:continue
   var center=Vector2((xs[x]+xs[x+1])/2,(zs[z]+zs[z+1])/2);var covered=false
   for r in holes:covered=covered or r.has_point(center)
   if covered:continue
   var p=[Vector3(xs[x],0,zs[z]),Vector3(xs[x+1],0,zs[z]),Vector3(xs[x+1],0,zs[z+1]),Vector3(xs[x],0,zs[z+1])]
   for j in [0,1,2,0,2,3]:st.set_normal(Vector3.UP);st.set_uv(Vector2(p[j].x,p[j].z));st.add_vertex(p[j])
 return st.commit()
func road_mask()->Texture2D:
 route_spots.clear()
 var image=Image.create(2048,2048,false,Image.FORMAT_R8);image.fill(Color.BLACK)
 for path in Plan.PATHS:
  var curve=Curve2D.new();curve.bake_interval=0.12
  for i in range(1,path.size()):
   var tangent=(path[mini(i+1,path.size()-1)]-path[maxi(1,i-1)])*0.16
   curve.add_point(path[i],-tangent if i>1 else Vector2.ZERO,tangent if i<path.size()-1 else Vector2.ZERO)
  var sample_index=0
  for p in curve.get_baked_points():
   if sample_index%4==0:route_spots.append(Vector3(p.x,path[0],p.y))
   sample_index+=1
   var at=(p+Vector2.ONE*100)*10.24;var radius=path[0]*10.24
   for y in range(maxi(0,int(at.y-radius-5)),mini(2048,int(at.y+radius+6))):
    for x in range(maxi(0,int(at.x-radius-5)),mini(2048,int(at.x+radius+6))):
     var value=clampf((radius-Vector2(x,y).distance_to(at)+4)/8,0,1)
     if value>image.get_pixel(x,y).r:image.set_pixel(x,y,Color(value,0,0))
 return ImageTexture.create_from_image(image)
func on_route(p:Vector2,clearance=.8)->bool:
 for spot in route_spots:
  if p.distance_squared_to(Vector2(spot.x,spot.z))<pow(spot.y+clearance,2):return true
 return false
func fence(a:Vector3,b:Vector3):
 var d=b-a;var length_=d.length();var root=Node3D.new();root.position=a;h.add_child(root);root.rotation.y=-atan2(d.z,d.x)
 var timber=h.architecture.mat("wood").duplicate();timber.set_shader_parameter("tint",Color("b8b0a0"));var count=int(ceil(length_/1.5));var span=length_/count
 for i in count:
  for y in [.34,.72]:
   var rail=h.box(root,Vector3((i+.5)*span,y,0),Vector3(span+.08,.14,.12),Color.WHITE);rail.material_override=timber;rail.rotation.z=sin(i*2.1)*.018
  if i%3==1:
   var brace=h.box(root,Vector3((i+.5)*span,.53,-.08),Vector3(sqrt(span*span+.38*.38),.10,.10),Color.WHITE);brace.rotation.z=atan2(.38,span);brace.material_override=timber
 for i in count+1:
  var post=h.box(root,Vector3(i*span,.48,0),Vector3(.22,.96,.22),Color.WHITE);post.material_override=timber
  var cap=MeshInstance3D.new();var top=CylinderMesh.new();top.top_radius=0;top.bottom_radius=.18;top.height=.18;top.radial_segments=4;cap.mesh=top;cap.material_override=timber;cap.position=Vector3(i*span,1.05,0);cap.rotation.y=PI/4;root.add_child(cap)
 h.box(root,Vector3(length_/2,.5,0),Vector3(length_,1,.12),Color.WHITE,true).hide()
func loop_track(root:Node3D,path:NodePath,values:Array,length_:float):
 var animation=Animation.new();animation.length=length_;animation.loop_mode=Animation.LOOP_LINEAR
 var track=animation.add_track(Animation.TYPE_VALUE);animation.track_set_path(track,path)
 for value in values:animation.track_insert_key(track,value[0],value[1])
 var lib=AnimationLibrary.new();lib.add_animation("loop",animation);var p=AnimationPlayer.new();root.add_child(p);p.add_animation_library("",lib);p.play("loop");animations.append(p)
func build():
 var solid=h.box(h,Vector3(0,-.2,0),Vector3(200,.4,200),Color.WHITE,true);solid.hide()
 var ground=MeshInstance3D.new();ground.mesh=terrain();h.add_child(ground)
 var source=Image.load_from_file("res://qingxi-live/classic-outdoor/art/ground-story-v1.png")
 var cell=Vector2i(source.get_width()/2,source.get_height()/2);var tiles=[]
 for i in 4:tiles.append(ImageTexture.create_from_image(source.get_region(Rect2i(Vector2i(i%2,i/2)*cell,cell))))
 var m=ShaderMaterial.new();m.shader=preload("res://qingxi-live/classic-outdoor/ground.gdshader");m.set_shader_parameter("grass_tex",tiles[0]);m.set_shader_parameter("grass_alt",tiles[2]);m.set_shader_parameter("stone_tex",tiles[3]);m.set_shader_parameter("dirt_tex",tiles[1]);m.set_shader_parameter("route_mask",road_mask());ground.material_override=m
 for p in [Vector3(-88,1,0),Vector3(88,1,0),Vector3(0,1,-88),Vector3(0,1,88)]:h.box(h,p,Vector3(.2,3,176) if p.x!=0 else Vector3(176,3,.2),Color.WHITE,true).hide()
 var trees=h.atlas_parts("trees.png",2,2);var rng=RandomNumberGenerator.new();rng.seed=45192
 var clusters=[Vector2(-34,-16),Vector2(-25,-25),Vector2(0,-28),Vector2(22,-21),Vector2(36,-10),Vector2(-36,32),Vector2(-13,42),Vector2(25,45),Vector2(40,36),Vector2(-76,0),Vector2(-73,25),Vector2(-48,-12),Vector2(43,-56),Vector2(16,-60),Vector2(44,-33),Vector2(84,0),Vector2(82,31),Vector2(51,43),Vector2(-8,-20),Vector2(-20,8),Vector2(2,11),Vector2(26,12)]
 for center in clusters:
  for i in 5:
   var p=center+Vector2(rng.randf_range(-4,4),rng.randf_range(-4,4))
   if on_route(p):continue
   var tree=h.billboard(trees[rng.randi_range(0,3)],Vector3(p.x,0,p.y),rng.randf_range(4.7,6.3));tree.shaded=true
   h.box(h,Vector3(p.x,.5,p.y),Vector3(.4,1,.4),Color.WHITE,true).hide()
 for i in 44:
  var a=i*TAU/44;var p=Vector3(cos(a)*90,0,sin(a)*90);var tree=h.billboard(trees[i%4],p,6.5);tree.shaded=true
 props=preload("res://qingxi-live/classic-outdoor/pixel_props.gd").new(h)
 props.place(0,Vector3(-3,0,-2),2.8,Vector2(2,1.6))
 for p in [Vector3(-6,0,-.5),Vector3(1,0,-5)]:h.architecture.furniture.place(h,"qianxia-park--bench",p,2.2,Vector2(2,.65))
 props.place(2,Vector3(-7,0,-4),2.0,Vector2(1.9,.3))
 for s in Plan.HOUSES:
  var p=s.at
  if s.id.begins_with("resident"):
   fence(p+Vector3(-4.8,0,4.8),p+Vector3(-1.5,0,4.8));fence(p+Vector3(1.5,0,4.8),p+Vector3(4.8,0,4.8))
  for side in [-1,1]:
   var plant=h.billboard(h.garden_props[1],p+Vector3(side*(s.width/2+0.5),0,s.depth/2+0.5),.9);plant.shaded=true
 for key in Plan.AREAS:
  if key in ["village","home"]:continue
  var p=Plan.AREAS[key].at+Vector3(3,0,2);h.box(h,p+Vector3(0,.65,0),Vector3(.12,1.3,.12),Color("9e845b"),true);h.sign_at(Plan.AREAS[key].name,p+Vector3(0,1.6,0))
 # Garden props fill edges in clusters, instead of evenly spaced decoration rows.
 for center in [Vector2(-25,-7),Vector2(11,-8),Vector2(-29,21),Vector2(4,33),Vector2(25,32),Vector2(-44,16),Vector2(44,22),Vector2(18,-35)]:
  for i in 3:
   var flower=h.billboard(h.garden_props[i%2],Vector3(center.x+cos(i*2.1),0,center.y+sin(i*2.1)),.8);flower.shaded=true
 neighbourhood()
func neighbourhood():
 # Courtyard edges and small workspaces create inhabited pockets off the roads.
 for rect in [Rect2(-15,-18,7,4),Rect2(-27,9,9,3),Rect2(-10,17,5,3),Rect2(26,27,5,3)]:
  fence(Vector3(rect.position.x,0,rect.position.y),Vector3(rect.end.x,0,rect.position.y))
  fence(Vector3(rect.position.x,0,rect.position.y),Vector3(rect.position.x,0,rect.end.y))
  fence(Vector3(rect.end.x,0,rect.position.y),Vector3(rect.end.x,0,rect.end.y))
  for i in 5:
   var p=Vector3(rect.position.x+.9+i*(rect.size.x-1.8)/4,0,rect.position.y+1)
   props.place(3,p,1.1,Vector2.ZERO)
 # Crates and sacks are grouped beside shops, not across doorways.
 for p in [Vector3(-15.5,0,-4.5),Vector3(10,0,-5),Vector3(31.8,0,-51.5),Vector3(-27,0,21),Vector3(25,0,30.5)]:
  props.place(4,p,1.6,Vector2(1.2,.65))
 # Smaller foreground trees frame the square while preserving its through-route.
 var trees=h.atlas_parts("trees.png",2,2)
 for p in [Vector3(-18,0,-4),Vector3(-1,0,-8),Vector3(-10,0,8),Vector3(12,0,4)]:
  if on_route(Vector2(p.x,p.z)):continue
  var tree=h.billboard(trees[1],p,4.4);tree.shaded=true;h.box(h,p+Vector3(0,.5,0),Vector3(.4,1,.4),Color.WHITE,true).hide()
func waterwheel(p:Vector3):
 var root=Node3D.new();root.position=p;h.add_child(root)
 var wheel=Node3D.new();root.add_child(wheel);wheel.name="Wheel"
 for i in 10:
  var a=i*TAU/10;var plank=h.box(wheel,Vector3(cos(a),sin(a),0),Vector3(.15,.65,.3),Color("aa8c62"));plank.rotation.z=a-PI/2
  var spoke=h.box(wheel,Vector3(cos(a)*.5,sin(a)*.5,0),Vector3(.08,1,.08),Color("987d57"));spoke.rotation.z=a-PI/2
  for z in [-.24,.24]:
   var rim=h.box(wheel,Vector3(cos(a)*.94,sin(a)*.94,z),Vector3(.13,.64,.10),Color("987d57"));rim.rotation.z=a
 h.box(root,Vector3(0,0,0),Vector3(.22,.22,.8),Color("917751"))
 loop_track(root,NodePath("Wheel:rotation:z"),[[0.0,0.0],[14.0,TAU]],14.0)


