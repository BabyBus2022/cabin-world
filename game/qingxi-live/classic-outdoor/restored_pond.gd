extends RefCounted
const Original=preload("res://qingxi-live/living_pond.gd")
var h
var shore=PackedVector2Array()
var water_material:ShaderMaterial
var fish=[]
var clock=0.0
var fed_at=-100.0
var rng=RandomNumberGenerator.new()
func world(p:Vector2)->Vector2:return (p-Vector2(744,447))*Vector2(.03,.04)+Vector2(30,-40)
func mesh(poly:PackedVector2Array,y:float,material_:Material)->MeshInstance3D:
 var triangles=Geometry2D.triangulate_polygon(poly);var st=SurfaceTool.new();st.begin(Mesh.PRIMITIVE_TRIANGLES)
 for i in triangles:
  st.set_normal(Vector3.UP);st.add_vertex(Vector3(poly[i].x,y,poly[i].y))
 var n=MeshInstance3D.new();n.mesh=st.commit();n.material_override=material_;h.add_child(n);return n
func flat(color:Color)->StandardMaterial3D:
 var m=StandardMaterial3D.new();m.albedo_color=color;m.cull_mode=BaseMaterial3D.CULL_DISABLED;m.roughness=1;m.metallic_specular=0;return m
func build(host):
 h=host;rng.seed=55312
 for p in Original.SHORE:shore.append(world(p))
 for layer in [[.42,.012,Color("78865b")],[.18,.020,Color("4e7060")]]:
  var outline=PackedVector2Array()
  for p in shore:outline.append(p+(p-Vector2(30,-40)).normalized()*layer[0])
  mesh(outline,layer[1],flat(layer[2]))
 water_material=ShaderMaterial.new();water_material.shader=preload("res://qingxi-live/classic-outdoor/restored_water.gdshader")
 var points=PackedVector2Array(Original.SHORE)
 while points.size()<32:points.append(Vector2.ZERO)
 water_material.set_shader_parameter("shore",points);water_material.set_shader_parameter("shore_count",Original.SHORE.size())
 mesh(shore,.035,water_material)
 # Carve the walkable dock out of the exact visible-water collision outline.
 var dock=PackedVector2Array([Vector2(26.85,-34),Vector2(29.15,-34),Vector2(29.15,-30),Vector2(26.85,-30)])
 for polygon in Geometry2D.clip_polygons(shore,dock):
  var body=StaticBody3D.new();body.position.y=.8;h.add_child(body)
  var collider=CollisionPolygon3D.new();collider.polygon=polygon;collider.depth=1.6;collider.rotation.x=PI/2;body.add_child(collider)
 for i in 7:
  var board=h.box(h,Vector3(28,-.07,-31.8-i*.30),Vector3(2.2,.16,.27),Color.WHITE,true);board.material_override=h.architecture.mat("wood")
 for x in [26.95,29.05]:
  for z in [-31.8,-33.6]:
   var post=h.box(h,Vector3(x,.27,z),Vector3(.14,.54,.14),Color.WHITE);post.material_override=h.architecture.mat("wood")
 for i in [0,3,7,10,12,16,19,22]:
  var p=shore[i]+(shore[i]-Vector2(30,-40)).normalized()*.3
  if p.distance_to(Vector2(28,-33))<1.9:continue
  for j in 4:
   var stem=h.box(h,Vector3(p.x+j*.08,.22+float(j%2)*.07,p.y),Vector3(.045,.45+float(j%2)*.14,.045),Color("758b50"));stem.rotation.z=(j-1.5)*.15
func random_water()->Vector2:
 for attempt in 100:
  var p=Vector2(rng.randf_range(23,37),rng.randf_range(-45,-35))
  if Geometry2D.is_point_in_polygon(p,shore):return p
 return Vector2(30,-40)
func splash():fed_at=clock
func tick(dt:float):
 clock+=dt;water_material.set_shader_parameter("clock",clock);water_material.set_shader_parameter("feed_age",clock-fed_at)
 var count=int(h.sim.data.pond.count)
 while fish.size()<count:
  var poly=PackedVector2Array([Vector2(.3,0),Vector2(.08,-.09),Vector2(-.15,-.06),Vector2(-.32,-.12),Vector2(-.24,0),Vector2(-.32,.12),Vector2(-.15,.06),Vector2(.08,.09)])
  var n=mesh(poly,.045,flat(Color("315f59")));var p=random_water();n.position=Vector3(p.x,0,p.y)
  fish.append({"node":n,"pos":p,"goal":random_water()})
 while fish.size()>count:fish.pop_back().node.queue_free()
 for f in fish:
  if clock-fed_at<12:f.goal=Vector2(28,-34.4)
  elif f.pos.distance_to(f.goal)<.3:f.goal=random_water()
  var delta=f.goal-f.pos
  if delta.length()>.1:
   var next=f.pos+delta.normalized()*dt*(.9 if clock-fed_at<12 else .45)
   if Geometry2D.is_point_in_polygon(next,shore):f.pos=next
   else:f.goal=random_water()
   f.node.position=Vector3(f.pos.x,0,f.pos.y);f.node.rotation.y=-delta.angle()

