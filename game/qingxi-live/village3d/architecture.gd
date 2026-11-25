extends RefCounted
## Exterior construction is independent of the tested interior floor/stair solids.
var host
var trim:StandardMaterial3D
var wood:StandardMaterial3D
var ivory:StandardMaterial3D
var glass:StandardMaterial3D
var slate:StandardMaterial3D
func _init(h):
	host=h
	trim=plain("514b46");wood=plain("89745d");ivory=plain("ded8b5");glass=plain("536f72")
	slate=host.material(Color("647778"))
func plain(hex:String)->StandardMaterial3D:
	var m=StandardMaterial3D.new();m.albedo_color=Color(hex);m.roughness=1;m.metallic_specular=0;m.diffuse_mode=BaseMaterial3D.DIFFUSE_LAMBERT
	return m
func cube(parent,p:Vector3,size_:Vector3,mat:Material,solid=false):
	var n=host.box(parent,p,size_,Color("8b6b49"),solid);n.material_override=mat;return n
func beam(parent,a:Vector3,b:Vector3,width:float,mat:Material):
	var n=cube(parent,(a+b)*0.5,Vector3(width,a.distance_to(b),width),mat)
	n.quaternion=Quaternion(Vector3.UP,(b-a).normalized());return n
func surface(parent,vertices:Array,mat:Material):
	var st=SurfaceTool.new();st.begin(Mesh.PRIMITIVE_TRIANGLES)
	for i in range(1,vertices.size()-1):
		for p in [vertices[0],vertices[i],vertices[i+1]]:st.add_vertex(p)
	st.generate_normals();var n=MeshInstance3D.new();n.mesh=st.commit();var m=mat.duplicate();m.cull_mode=BaseMaterial3D.CULL_DISABLED;n.material_override=m;parent.add_child(n);return n
func pitched(parent,center:Vector3,width_:float,depth:float,eave:float,rise:float,roof_mat:Material,hipped=false):
	var w=width_*0.5;var d=depth*0.5;var end=d-2.1 if hipped else d
	var a=center+Vector3(-w,eave,-d);var b=center+Vector3(w,eave,-d);var c=center+Vector3(w,eave,d);var d_=center+Vector3(-w,eave,d)
	var back=center+Vector3(0,eave+rise,-end);var front=center+Vector3(0,eave+rise,end)
	surface(parent,[a,d_,front,back],roof_mat);surface(parent,[c,b,back,front],roof_mat)
	surface(parent,[b,a,back],roof_mat if hipped else ivory);surface(parent,[d_,c,front],roof_mat if hipped else ivory)
	for line in [[a,d_],[b,c],[a,b],[c,d_],[back,front]]:beam(parent,line[0],line[1],0.16,trim)
	if not hipped:
		for line in [[a,back],[b,back],[d_,front],[c,front]]:beam(parent,line[0],line[1],0.14,trim)
func roof(kind:String,parent:Node3D)->Node3D:
	var root=Node3D.new();parent.add_child(root)
	var roof_mat=host.material(Color("647778"))
	if kind=="livestock":
		# A barn has a steeper central ridge, lower side skirts, a loft vent and a chimney.
		pitched(root,Vector3.ZERO,13.5,11.1,6.65,2.0,roof_mat)
		cube(root,Vector3(0,7.1,5.16),Vector3(1.4,0.85,0.08),trim)
		for x in [-0.45,-0.15,0.15,0.45]:cube(root,Vector3(x,7.1,5.23),Vector3(0.08,0.75,0.1),wood)
	elif kind=="seed":
		pitched(root,Vector3.ZERO,13.6,11.4,6.65,1.5,roof_mat,true)
		# Offset front gable breaks the long facade without changing the room footprint.
		pitched(root,Vector3(-2.9,0,4.4),4.4,3.1,6.64,1.6,roof_mat)
		cube(root,Vector3(-2.9,7.2,6.0),Vector3(0.75,0.65,0.09),trim)
	elif kind=="home":
		pitched(root,Vector3.ZERO,13.6,11.5,6.65,1.8,roof_mat,true)
		pitched(root,Vector3(2.8,0,4.3),4.6,3.2,6.65,1.5,roof_mat)
		cube(root,Vector3(-4.0,7.5,-2.8),Vector3(0.85,2.0,0.8),host.material(Color("c7baa0")))
		cube(root,Vector3(-4.0,8.55,-2.8),Vector3(1.05,0.18,1.0),trim)
	else:
		pitched(root,Vector3.ZERO,13.4,11.2,6.65,1.4 if kind=="resident_a" else 1.8,roof_mat,kind=="resident_a")
		cube(root,Vector3(-3.9,7.5,-2.5),Vector3(0.7,1.8,0.75),host.material(Color("c7baa0")))
	return root
func window(parent,x:float,y:float,width_:float,shutter:Material,flowers:bool):
	var root=Node3D.new();root.position=Vector3(x,y,5.18);parent.add_child(root)
	cube(root,Vector3.ZERO,Vector3(width_+0.2,1.5,0.14),trim)
	var m=glass.duplicate();m.emission_enabled=true;m.emission=Color("ffd394");host.window_materials.append(m)
	cube(root,Vector3(0,0,0.08),Vector3(width_-0.08,1.26,0.04),m)
	for dy in [-0.69,0.69]:cube(root,Vector3(0,dy,0.15),Vector3(width_+0.3,0.11,0.24),wood)
	for dx in [-width_/2,0,width_/2]:cube(root,Vector3(dx,0,0.15),Vector3(0.08,1.4,0.16),wood)
	cube(root,Vector3(0,0,0.15),Vector3(width_,0.07,0.12),wood)
	for side in [-1,1]:
		var flap=cube(root,Vector3(side*(width_/2+0.32),0,0.06),Vector3(0.46,1.35,0.12),shutter);flap.rotation.y=side*0.18
		for j in [-0.4,0.0,0.4]:cube(root,Vector3(side*(width_/2+0.32),j,0.17),Vector3(0.43,0.045,0.08),wood)
	if flowers:
		cube(root,Vector3(0,-0.88,0.28),Vector3(width_+0.35,0.28,0.5),wood)
		for j in 5:
			var n=Sprite3D.new();n.texture=host.garden_props[1];n.billboard=BaseMaterial3D.BILLBOARD_ENABLED;n.alpha_cut=SpriteBase3D.ALPHA_CUT_DISCARD;n.texture_filter=BaseMaterial3D.TEXTURE_FILTER_NEAREST;n.pixel_size=0.48/n.texture.get_height();n.position=Vector3(-width_/2+j*width_/4,-0.64,0.33);root.add_child(n)
	return root
func facade(house:Dictionary):
	var kind:String=house.spec.id;var parent:Node3D=house.root
	var front=Node3D.new();parent.add_child(front);house.walls[0].append(front)
	var colored=plain({"seed":"809575","livestock":"a66e58","home":"637d85","resident_a":"89916d","resident_b":"a38a72"}[kind])
	var foundation=host.material(Color("c7baa0"))
	cube(parent,Vector3(0,-0.08,0),Vector3(12.2,0.16,10.2),foundation)
	# A stone plinth and timber dado ground the building. The doorway remains open.
	for side in [-1,1]:
		cube(front,Vector3(side*3.5,0.28,5.13),Vector3(4.9,0.5,0.16),foundation)
		cube(front,Vector3(side*3.5,0.78,5.12),Vector3(4.9,0.52,0.14),colored if kind=="livestock" else wood)
	for x in [-5.9,-0.95,0.95,5.9]:cube(front,Vector3(x,3.25,5.15),Vector3(0.15,6.5,0.22),trim)
	for y in [1.05,3.3,6.5]:cube(front,Vector3(0,y,5.18),Vector3(12.15,0.13,0.22),trim)
	# Lower shop windows are broader than residential windows.
	for x in [-3.5,3.5]:window(front,x,1.96,2.45 if kind=="seed" else 1.85,colored,kind!="livestock")
	for x in [-3.5,3.4]:window(front,x,4.85,1.65,colored,kind=="home")
	# A porch/engawa roof gives depth and a usable sheltered entrance.
	var canopy=Node3D.new();front.add_child(canopy)
	var awning=host.material(Color("647778"))
	var x0=-1.5 if kind=="seed" else 0.0
	var width_=8.8 if kind=="seed" else (5.0 if kind=="livestock" else 6.4)
	var slope=cube(canopy,Vector3(x0,3.0,6.0),Vector3(width_,0.16,2.15),awning);slope.rotation.x=0.18
	for x in [x0-width_/2+0.18,x0+width_/2-0.18]:
		cube(canopy,Vector3(x,1.35,6.7),Vector3(0.15,2.7,0.15),trim,true)
		beam(canopy,Vector3(x,2.25,6.7),Vector3(x+(-0.55 if x>x0 else 0.55),2.8,6.7),0.1,wood)
	cube(canopy,Vector3(x0,2.8,7.02),Vector3(width_+0.1,0.16,0.18),trim)
	# A shallow flush apron avoids a new step/collider at the doorway.
	cube(parent,Vector3(0,-0.02,6),Vector3(width_+0.3,0.03,2.2),foundation)
	var sign=cube(front,Vector3(0,2.62,5.4),Vector3(2.5,0.42,0.16),wood)
	var label=host.sign_at(house.spec.name,Vector3(0,2.64,5.51),front);label.font_size=30;label.pixel_size=0.007
	for x in [-1.4,1.4]:
		cube(front,Vector3(x,1.95,5.45),Vector3(0.20,0.35,0.20),ivory)
	var light=OmniLight3D.new();light.position=Vector3(0,2,5.4);light.omni_range=8;light.light_color=Color("ffd8a0");parent.add_child(light);host.lamps.append(light)
	# Wood siding on the barn and a low side extension diversify silhouettes.
	if kind=="livestock":
		for x in [-6.02,6.02]:cube(front,Vector3(x,1.5,0),Vector3(0.12,2.8,10),colored)
		for x in [-4.8,4.8]:beam(front,Vector3(x-0.5,3.5,5.22),Vector3(x+0.5,4.3,5.22),0.10,trim)
	elif kind=="home":
		var balcony=cube(front,Vector3(3.1,3.35,5.8),Vector3(4.1,0.14,1.2),wood)
		for x in [1.15,2.1,3.1,4.1,5.05]:cube(front,Vector3(x,3.85,6.4),Vector3(0.08,0.9,0.08),wood)
		cube(front,Vector3(3.1,4.33,6.4),Vector3(4.05,0.09,0.12),trim)
	# Sidewall timber bands are physically attached, not floating planar stickers.
	for x in [-6.07,6.07]:
		for y in [0.3,3.3,6.5]:cube(front,Vector3(x,y,0),Vector3(0.14,0.12,10.1),trim)
