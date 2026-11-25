extends RefCounted
## A volumetric art study; the concept PNG is deliberately not loaded here.
## Wall geometry remains exported by the user-supplied architecture tool.
const Assembly=preload("res://qingxi-live/material-lab/house_assembly.gd")
const Windows=preload("res://qingxi-live/material-lab/window_details.gd")
const ROLES=preload("res://qingxi-live/material-lab/lab.gd").ROLES
var h
var textures={}
var materials={}
func _init(host):
 h=host
 var im=Image.load_from_file("res://qingxi-live/material-lab/assets/pixel-atlas-1024.png")
 for role in ["wood","wall","trim","stone","wall_base"]:
  var i=ROLES.find(role);textures[role]=ImageTexture.create_from_image(im.get_region(Rect2i((i%4)*256,(i/4)*256,256,256)))
func painted(color:Color)->StandardMaterial3D:
 var key=color.to_html()
 if materials.has(key):return materials[key]
 var m=StandardMaterial3D.new();m.albedo_color=color;m.roughness=1;m.metallic_specular=0;m.diffuse_mode=BaseMaterial3D.DIFFUSE_LAMBERT;materials[key]=m;return m
func timber()->StandardMaterial3D:
 if materials.has("timber"):return materials.timber
 var m=painted(Color("bba992")).duplicate();m.albedo_texture=textures.wood;m.texture_filter=BaseMaterial3D.TEXTURE_FILTER_NEAREST;m.uv1_triplanar=true;m.uv1_scale=Vector3(.45,.30,.45);materials.timber=m;return m
func box(root:Node3D,p:Vector3,size_:Vector3,m:Material):
 var mesh=MeshInstance3D.new();var shape=BoxMesh.new();shape.size=size_;mesh.mesh=shape;mesh.material_override=m;mesh.position=p;root.add_child(mesh);return mesh
func beam(root:Node3D,a:Vector3,b:Vector3,width:float,m:Material):
 var mesh=box(root,(a+b)*.5,Vector3(width,a.distance_to(b),width),m)
 mesh.quaternion=Quaternion(Vector3.UP,(b-a).normalized());return mesh
func tile(root:Node3D,x:float,z0:float,z1:float,half_width:float,ridge:float,slope:float,color:Color):
 var st=SurfaceTool.new();st.begin(Mesh.PRIMITIVE_TRIANGLES)
 var verts=[]
 for row in 2:
  var z=lerpf(z0,z1,row);var base=ridge-absf(z)*slope+pow(absf(z)/4.0,3)*.13
  for col in 5:
   var u=float(col)/4
   verts.append(Vector3(x+(u-.5)*half_width*2,base+sin(u*PI)*.08,z))
 for j in 4:
  for i in [j,j+5,j+1,j+1,j+5,j+6]:st.add_vertex(verts[i])
  var a=verts[5+j];var b=verts[6+j]
  for v in [a,a-Vector3(0,.075,0),b,b,a-Vector3(0,.075,0),b-Vector3(0,.075,0)]:st.add_vertex(v)
 st.generate_normals();var n=MeshInstance3D.new();n.mesh=st.commit();var m=painted(color).duplicate();m.cull_mode=BaseMaterial3D.CULL_DISABLED;n.material_override=m;root.add_child(n)
func build(parent:Node3D,spec:Dictionary)->Node3D:
 var root=Node3D.new();root.name="CraftedVolumetricExterior";parent.add_child(root)
 var depth=float(spec.depth)/2
 var parts=Assembly.new().part("seed",Vector3.ZERO,0,-.12,3.32,[AABB(Vector3(-.9,-1,depth-.25),Vector3(1.8,3.4,1))],false,"res://qingxi-live/village01/models/")
 for role in parts:
  if role in ["roof","roof_edge","shadow","window"]:continue
  var n=MeshInstance3D.new();n.mesh=parts[role]
  if role in ["wood","trim","door","wall_base"]:n.material_override=timber()
  elif role=="wall":
   var m=painted(Color("ded3b3")).duplicate();m.albedo_texture=textures.wall;m.texture_filter=BaseMaterial3D.TEXTURE_FILTER_NEAREST;n.material_override=m
  else:n.material_override=painted(Color("a7a18b"))
  root.add_child(n)
 # Real, raised tile courses. The roof has a front AND rear sloping surface.
 var ridge=4.85;var end=depth+.52;var rows=6;var columns=13;var width=float(spec.width)+1.1;var step_=width/columns
 var colors=[Color("647a7d"),Color("6e8384"),Color("728989"),Color("5d7379")]
 for side in [-1,1]:
  for row in rows:
   var z0=side*float(row)*end/rows;var z1=side*(float(row+1)*end/rows+.08)
   for col in columns:
    var x=-width/2+(col+.5)*step_
    tile(root,x,z0,z1,step_*.5,ridge,.38,colors[(col/3+row*2)%colors.size()])
  # The beam follows the eave; its dark underside reads as material thickness.
  box(root,Vector3(0,ridge-end*.38-.04,side*end),Vector3(width+.12,.20,.20),timber())
  for col in range(0,columns,2):box(root,Vector3(-width/2+(col+.5)*step_,3.18,side*(depth+.20)),Vector3(.15,.27,.60),timber())
 for i in columns:
  var c=CylinderMesh.new();c.top_radius=.15;c.bottom_radius=.15;c.height=step_;c.radial_segments=8
  var n=MeshInstance3D.new();n.mesh=c;n.material_override=painted(colors[i%3]);n.rotation.z=PI/2;n.position=Vector3(-width/2+(i+.5)*step_,ridge+.08,0);root.add_child(n)
 # Side gables close the volume; not a front-facing card.
 for side in [-1,1]:
  var st=SurfaceTool.new();st.begin(Mesh.PRIMITIVE_TRIANGLES)
  var v=[Vector3(side*spec.width/2,3.2,-depth),Vector3(side*spec.width/2,ridge-.08,0),Vector3(side*spec.width/2,3.2,depth)]
  for p in v:st.add_vertex(p)
  st.generate_normals();var n=MeshInstance3D.new();n.mesh=st.commit();var m=painted(Color("d6c5a5")).duplicate();m.cull_mode=BaseMaterial3D.CULL_DISABLED;n.material_override=m;root.add_child(n)
  for z in [-depth,depth]:beam(root,Vector3(side*spec.width/2,3.2,z),Vector3(side*spec.width/2,ridge-.05,0),.16,timber())
 # Window openings are backed by inset glazing, then actual frames and displays.
 for x in [-2.25,2.25]:
  var z=depth+.13
  box(root,Vector3(x,1.65,z),Vector3(1.6,1.40,.12),painted(Color("394d51")))
  for dx in [-.84,.84]:box(root,Vector3(x+dx,1.65,z+.10),Vector3(.14,1.65,.20),timber())
  for y in [.86,1.58,2.44]:box(root,Vector3(x,y,z+.13),Vector3(1.85,.13,.25),timber())
  box(root,Vector3(x,1.65,z+.11),Vector3(.09,1.4,.18),timber())
  for dx in [-.5,0,.5]:
   box(root,Vector3(x+dx,1.10,z+.22),Vector3(.27,.35,.22),painted(Color("cfbc8e")))
   box(root,Vector3(x+dx,1.17,z+.34),Vector3(.13,.09,.012),painted(Color("8a9b67")))
 for x in [-spec.width/2,-1.04,1.04,spec.width/2]:box(root,Vector3(x,1.6,depth+.16),Vector3(.18,3.2,.24),timber())
 # A shallow porch roof has real thickness and side brackets.
 var canopy=Node3D.new();root.add_child(canopy)
 for col in 5:tile(canopy,(col-2)*.54,depth+.2,depth+1.02,.27,4.22,.38,colors[col%3])
 for x in [-1.1,1.1]:beam(root,Vector3(x,2.3,depth+.17),Vector3(x,2.75,depth+.85),.13,timber())
 for x in [-.42,.42]:box(root,Vector3(x,2.50,depth+.55),Vector3(.76,.5,.035),painted(Color("9eac78")))
 return root

