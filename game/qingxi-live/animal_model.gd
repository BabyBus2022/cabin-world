extends RefCounted
# Real articulated 3D geometry rendered orthographically into a pixel sprite.
var viewport:SubViewport
var root:Node3D
var rig:Node3D
var torso:Node3D
var head:Node3D
var legs=[]
var ears=[]
var eyes=[]
var wool=[]
var tail:Node3D
var kind:String
var phase=0.0
var age_phase=0.0
var materials={}
var foot_baseline=0.0
func material(hex:String)->StandardMaterial3D:
	if materials.has(hex):return materials[hex]
	var m=StandardMaterial3D.new();m.albedo_color=Color(hex);m.roughness=1.0;m.metallic_specular=0.0;m.diffuse_mode=BaseMaterial3D.DIFFUSE_TOON
	materials[hex]=m;return m
func ball(parent:Node3D,p:Vector3,size_:Vector3,color:String)->MeshInstance3D:
	var mesh=SphereMesh.new();mesh.radius=0.5;mesh.height=1;mesh.radial_segments=12;mesh.rings=6
	var node=MeshInstance3D.new();node.mesh=mesh;node.material_override=material(color);node.position=p;node.scale=size_;parent.add_child(node);return node
func box(parent:Node3D,p:Vector3,size_:Vector3,color:String)->MeshInstance3D:
	var mesh=BoxMesh.new();mesh.size=size_
	var node=MeshInstance3D.new();node.mesh=mesh;node.material_override=material(color);node.position=p;parent.add_child(node);return node
func horn(parent:Node3D,p:Vector3,size_:Vector3,color:String):
	var mesh=CylinderMesh.new();mesh.top_radius=0.015;mesh.bottom_radius=0.07;mesh.height=0.25;mesh.radial_segments=6
	var node=MeshInstance3D.new();node.mesh=mesh;node.position=p;node.scale=size_;node.material_override=material(color);parent.add_child(node)
func pivot(parent:Node3D,p:Vector3)->Node3D:
	var node=Node3D.new();node.position=p;parent.add_child(node);return node
func _init(parent:Node,animal_kind:String):
	kind=animal_kind
	viewport=SubViewport.new();viewport.size=Vector2i(112,96);viewport.transparent_bg=true;viewport.own_world_3d=true
	viewport.render_target_update_mode=SubViewport.UPDATE_ALWAYS;viewport.msaa_3d=Viewport.MSAA_DISABLED;parent.add_child(viewport)
	root=Node3D.new();viewport.add_child(root)
	var environment=WorldEnvironment.new();var settings=Environment.new()
	settings.background_mode=Environment.BG_COLOR;settings.background_color=Color(0,0,0,0)
	settings.ambient_light_source=Environment.AMBIENT_SOURCE_COLOR;settings.ambient_light_color=Color("d5dfc2");settings.ambient_light_energy=0.52
	settings.tonemap_mode=Environment.TONE_MAPPER_LINEAR;environment.environment=settings;root.add_child(environment)
	var light=DirectionalLight3D.new();light.rotation_degrees=Vector3(-48,-35,0);light.light_color=Color("fff1d2");light.light_energy=0.65;root.add_child(light)
	var camera=Camera3D.new();camera.projection=Camera3D.PROJECTION_ORTHOGONAL;camera.size=3.5;camera.position=Vector3(-3.5,2.7,5)
	root.add_child(camera);camera.look_at(Vector3(0,0.75,0));camera.current=true
	for x in [-0.62,0.62]:
		for z in [-0.40,0.40]:foot_baseline=maxf(foot_baseline,camera.unproject_position(Vector3(x,0.085,z)).y)
	rig=pivot(root,Vector3.ZERO)
	torso=pivot(rig,Vector3(0,0.78,0))
	var coat="f0e8cc" if kind!="pig" else "dba092"
	ball(torso,Vector3.ZERO,Vector3(1.38,0.96,0.96) if kind!="pig" else Vector3(1.38,1.02,1.04),coat)
	if kind=="cow":
		for p in [Vector3(-0.27,0.15,0.36),Vector3(0.36,0.04,0.38),Vector3(0.21,0.39,0.04),Vector3(-0.1,0.04,-0.38)]:
			ball(torso,p,Vector3(0.52,0.43,0.13) if absf(p.z)>0.3 else Vector3(0.5,0.11,0.48),"4d5145")
		ball(torso,Vector3(0.34,-0.4,0),Vector3(0.43,0.24,0.4),"c69c91")
	if kind=="sheep":
		for p in [Vector3(-0.48,0.17,0.0),Vector3(-0.17,0.37,0),Vector3(0.23,0.37,0),Vector3(0.56,0.17,0),Vector3(-0.29,0.06,0.34),Vector3(0.13,0.07,0.38),Vector3(0.48,0.04,0.3),Vector3(-0.20,0.05,-0.34),Vector3(0.24,0.08,-0.32)]:
			wool.append(ball(torso,p,Vector3(0.67,0.62,0.64),"eee5c9"))
	head=pivot(torso,Vector3(-0.72,0.17,0))
	ball(head,Vector3(-0.10,0.0,0),Vector3(0.79,0.82,0.79),"e6d9bb" if kind=="sheep" else coat)
	var muzzle="bc9487" if kind=="cow" else ("bf887f" if kind=="pig" else "ac977c")
	ball(head,Vector3(-0.43,-0.16,0),Vector3(0.30,0.32,0.52),muzzle)
	for z in [-0.13,0.13]:ball(head,Vector3(-0.573,-0.11,z),Vector3(0.035,0.055,0.060),"665548")
	for z in [-0.34,0.34]:
		ball(head,Vector3(-0.28,0.10,z),Vector3(0.17,0.19,0.07),"f2e9d4")
		var eye=ball(head,Vector3(-0.30,0.11,z*1.09),Vector3(0.12,0.15,0.055),"353d37");eyes.append(eye)
		ball(head,Vector3(-0.323,0.15,z*1.14),Vector3(0.036,0.036,0.022),"fff0d4")
		ball(head,Vector3(-0.32,-0.055,z*1.05),Vector3(0.17,0.08,0.035),"d8a698")
		var ear=pivot(head,Vector3(0.03,0.31,z));ears.append(ear)
		ball(ear,Vector3(0,0.045,z*0.40),Vector3(0.32,0.16,0.28),coat)
		ball(ear,Vector3(-0.015,0.12,z*0.40),Vector3(0.19,0.035,0.18),"bf978b")
	if kind=="cow":
		for z in [-0.23,0.23]:horn(head,Vector3(0,0.50,z),Vector3(0.8,0.75,0.8),"c6b78f")
	if kind=="sheep":
		for z in [-0.23,0.0,0.23]:wool.append(ball(head,Vector3(-0.06,0.34,z),Vector3(0.45,0.30,0.35),"f4ebd1"))
	for x in [-0.49,0.50]:
		for z in [-0.27,0.27]:
			var leg=pivot(rig,Vector3(x,0.64,z));legs.append(leg)
			ball(leg,Vector3(0,-0.22,0),Vector3(0.23,0.55,0.23),coat if kind!="sheep" else "a9977a")
			ball(leg,Vector3(-0.025,-0.48,0),Vector3(0.28,0.18,0.26),"5c5b4b" if kind!="pig" else "9f7568")
	tail=pivot(torso,Vector3(0.72,0.18,0))
	if kind=="pig":
		for i in 8:
			var t=i*0.7;ball(tail,Vector3(0.05+i*0.023,sin(t)*0.085,cos(t)*0.085),Vector3.ONE*0.08,"c4897e")
	else:
		ball(tail,Vector3(0.13,-0.13,0),Vector3(0.10,0.4,0.10),coat)
		ball(tail,Vector3(0.15,-0.34,0),Vector3(0.16,0.19,0.15),"655e47" if kind=="cow" else "e8dbba")
func texture()->Texture2D:return viewport.get_texture()
func animate(dt:float,moving:bool,mode:String,shorn:bool,direction=Vector2.ZERO):
	age_phase+=dt
	if moving and direction.length()>0.1:
		var heading=Vector2(direction.x*0.819-direction.y*0.573,direction.x*0.573+direction.y*0.819)
		rig.rotation.y=lerp_angle(rig.rotation.y,atan2(heading.y,-heading.x),minf(1,dt*4))
	phase+=dt*(7.3 if moving else 1.1)
	var amplitude=0.42 if moving else 0.015
	for i in legs.size():
		var stride=sin(phase+([0.0,PI,PI,0.0][i]))
		legs[i].rotation.z=stride*amplitude
		legs[i].position.y=0.64-(1.0-cos(legs[i].rotation.z))*0.50+(maxf(0,stride)*0.06 if moving else 0.0)
	torso.position.y=0.78+(absf(sin(phase))*0.035 if moving else sin(age_phase*1.6)*0.012)
	var eating=mode=="吃草" or mode=="拱地"
	head.rotation.z=0.47+sin(age_phase*2)*0.07 if eating else sin(age_phase*1.3)*0.06
	head.rotation.y=sin(age_phase*0.8)*0.09
	for i in ears.size():ears[i].rotation.x=sin(age_phase*3.1+i)*0.13
	tail.rotation.x=sin(age_phase*2.3)*0.40
	for eye in eyes:eye.scale.y=0.025 if fmod(age_phase,4.7)>4.52 else 0.15
	for tuft in wool:tuft.visible=not shorn
