extends RefCounted
var h
var a
func _init(host):h=host;a=preload("res://qingxi-live/village3d/architecture.gd").new(h)
func fence(origin:Vector3,length_:float,along_z=false):
	var axis=Vector3.FORWARD if along_z else Vector3.RIGHT
	for y in [0.38,0.76]:a.beam(h,origin+Vector3(0,y,0),origin+axis*length_+Vector3(0,y,0),0.08,a.wood)
	for i in int(ceil(length_/1.4))+1:
		var p=origin+axis*minf(i*1.4,length_)
		a.cube(h,p+Vector3(0,0.5,0),Vector3(0.13,1,0.13),a.trim,true)
	var center=origin+axis*length_/2
	h.box(h,center+Vector3(0,0.5,0),Vector3(0.12,1,length_) if along_z else Vector3(length_,1,0.12),Color("8b6b49"),true).visible=false
func patch(points:Array,index:int):
	var mat=StandardMaterial3D.new();mat.albedo_texture=h.tiles[index];mat.texture_filter=BaseMaterial3D.TEXTURE_FILTER_NEAREST;mat.albedo_color=Color(0.69,0.72,0.69);mat.roughness=1;mat.metallic_specular=0;mat.uv1_triplanar=true;mat.uv1_scale=Vector3.ONE*0.38
	var vertices=[]
	for p in points:vertices.append(Vector3(p.x,0.012,p.y))
	a.surface(h,vertices,mat)
func crate(p:Vector3,hay=false):
	var mat=a.plain("c4b66e") if hay else a.wood
	a.cube(h,p+Vector3(0,0.4,0),Vector3(0.95,0.8,0.8),mat,true)
	for y in [0.08,0.7]:a.cube(h,p+Vector3(0,y,0.42),Vector3(1,0.08,0.06),a.trim)
	for x in [-0.35,0.35]:a.cube(h,p+Vector3(x,0.41,0.44),Vector3(0.07,0.7,0.07),a.trim)
func planting(p:Vector3,flowers=false,height_=0.9):
	h.billboard(h.garden_props[1 if flowers else 0],p,height_)
func build():
	# Market square sits between the two shops; paths feed its edges, not a random cross.
	patch([Vector2(-15,-3),Vector2(-10,-5),Vector2(-5,-5),Vector2(0,-2),Vector2(2,1),Vector2(-2,4),Vector2(-9,4),Vector2(-15,2)],8)
	var well=Vector3(-5,0,-3)
	a.cube(h,well+Vector3(0,0.38,0),Vector3(1.6,0.76,1.4),h.material(Color("c7baa0")),true)
	a.cube(h,well+Vector3(0,0.77,0),Vector3(1.15,0.04,0.95),a.plain("435a61"))
	for x in [-0.9,0.9]:a.cube(h,well+Vector3(x,1.2,0),Vector3(0.12,2.4,0.12),a.wood,true)
	a.pitched(h,well,2.5,1.9,2.2,0.6,h.material(Color("647778")))
	h.billboard(h.garden_props[3],Vector3(-8,0,-3.8),0.9)
	for p in [Vector3(-16.8,0,-3.8),Vector3(-16,0,-3.8),Vector3(13.7,0,-10.9),Vector3(14.8,0,-10.8)]:crate(p,p.x>0)
	for spec in h.HOUSES:
		var p:Vector3=spec.at
		if spec.id in ["home","resident_a","resident_b"]:
			# Side gates remain open where the lane enters each yard.
			fence(p+Vector3(-7.6,0,6),2.0,true);fence(p+Vector3(7.6,0,6),2.0,true)
			fence(p+Vector3(-7.6,0,10.5),4.5);fence(p+Vector3(3.1,0,10.5),4.5)
			patch([Vector2(p.x-6,p.z+5.4),Vector2(p.x+6,p.z+5.4),Vector2(p.x+6.2,p.z+8.1),Vector2(p.x+2.0,p.z+8.8),Vector2(p.x-5.6,p.z+8.3)],6)
			for side in [-1,1]:
				for j in 3:planting(p+Vector3(side*(4.2+j*0.7),0,8.5),j%2==0,0.7)
			crate(p+Vector3(-6.8,0,1.0))
		else:
			for x in [-5.8,5.7]:planting(p+Vector3(x,0,6.5),true,0.9)
	# Vegetation frames yards and the clearing. Keep the travel lane open.
	for center in [Vector2(-23,-19),Vector2(0,-26),Vector2(20,-25),Vector2(28,-7),Vector2(26,30),Vector2(-14,33),Vector2(-30,25),Vector2(-30,-6),Vector2(-5,9)]:
		for i in 5:
			var p=Vector3(center.x+sin(i*2.4)*1.9,0,center.y+cos(i*1.7)*1.5)
			planting(p,i==2,1.1 if i==2 else 1.35)
	# Linear shelter belts make the edge read as woodland rather than unused grass.
	for i in 24:
		var t=i*TAU/24;var p=Vector3(cos(t)*39,0,sin(t)*40)
		if p.distance_to(h.GATES.field)<5 or p.distance_to(h.GATES.ranch)<5 or p.distance_to(h.GATES.pond)<5:continue
		planting(p,false,2.6)
