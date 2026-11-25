extends RefCounted
## Real triangles from the user's parametric architecture tool, not billboard PNGs.
const ROOT="res://qingxi-live/assets/parametric-village/clean/"
static var cached={}
var host
func _init(h):host=h
func clip(poly:Array,axis:int,edge:float,positive:bool)->Array:
	var result=[]
	if poly.is_empty():return result
	var prev=poly[-1];var pd=(prev.p[axis]-edge)*(1 if positive else -1)
	for cur in poly:
		var cd=(cur.p[axis]-edge)*(1 if positive else -1)
		if (cd>=0)!=(pd>=0):
			var t=pd/(pd-cd)
			result.append({"p":prev.p.lerp(cur.p,t),"uv":prev.uv.lerp(cur.uv,t),"n":prev.n.lerp(cur.n,t).normalized()})
		if cd>=0:result.append(cur)
		prev=cur;pd=cd
	return result
func outside_door(poly:Array)->Array:
	var pieces=[];var remaining=poly
	# Cut a walk-through doorway, including any decorative closed door and steps.
	for plane in [[0,-0.88,true],[0,0.88,false],[1,-2.0,true],[1,2.4,false],[2,4.82,true],[2,10.0,false]]:
		var outside=clip(remaining,plane[0],plane[1],not plane[2])
		if outside.size()>=3:pieces.append(outside)
		remaining=clip(remaining,plane[0],plane[1],plane[2])
		if remaining.is_empty():break
	return pieces
func geometry(kind:String)->Dictionary:
	if cached.has(kind):return cached[kind]
	var data=JSON.parse_string(FileAccess.get_file_as_string(ROOT+kind+"/model.json"))
	var result={};var small=kind=="shed"
	var scale_=Vector3(3.2/3.5,1.0,1.0) if small else Vector3(1.2,3.4/2.8,10.0/8.25)
	for role in data.roles:
		var bucket:Dictionary=data.roles[role];var positions:Array=bucket.pos
		var st=SurfaceTool.new();st.begin(Mesh.PRIMITIVE_TRIANGLES);var count=0
		for i in range(0,positions.size(),9):
			var poly=[]
			for j in 3:
				var k=i+j*3;var v=k/3
				var p=(Vector3(positions[k],positions[k+1]-0.36,positions[k+2]))*scale_
				var n=(Vector3(bucket.nrm[k],bucket.nrm[k+1],bucket.nrm[k+2])/scale_).normalized()
				var uv=Vector2(bucket.uv[v*2],bucket.uv[v*2+1])
				if role=="roof":uv=Vector2(uv.y,uv.x)*0.42
				poly.append({"p":p,"n":n,"uv":uv})
			poly=clip(poly,1,-0.12,true)
			var pieces=[poly] if small else outside_door(poly)
			for piece in pieces:
				for j in range(1,piece.size()-1):
					for v in [piece[0],piece[j],piece[j+1]]:
						st.set_normal(v.n);st.set_uv(v.uv);st.add_vertex(v.p);count+=1
		if count>0:result[role]=st.commit()
	cached[kind]=result;return result
func build(kind:String,parent:Node3D)->Node3D:
	var root=Node3D.new();root.name="ParametricArchitecture_"+kind;parent.add_child(root)
	var meshes=geometry(kind)
	for role in meshes:
		var node=MeshInstance3D.new();node.name=role;node.mesh=meshes[role];root.add_child(node)
		var m=StandardMaterial3D.new();m.albedo_texture=ImageTexture.create_from_image(Image.load_from_file(ROOT+kind+"/"+role+".png"))
		m.texture_filter=BaseMaterial3D.TEXTURE_FILTER_NEAREST;m.cull_mode=BaseMaterial3D.CULL_DISABLED;m.roughness=1;m.metallic_specular=0;m.diffuse_mode=BaseMaterial3D.DIFFUSE_LAMBERT
		m.albedo_color=Color(0.58,0.62,0.65) if role in ["wood","wall_base","door"] else Color(0.70,0.73,0.75)
		if role=="wall":m.albedo_color=Color(0.75,0.78,0.8)
		if role not in ["glass","window","shadow"]:
			var outline=ShaderMaterial.new();outline.shader=preload("res://qingxi-live/village3d/building_outline.gdshader");m.next_pass=outline
		if role in ["glass","window"]:
			m.emission_enabled=true;m.emission=Color("ffcd87");host.window_materials.append(m)
		node.material_override=m
	return root
