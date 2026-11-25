extends Node2D
# Geometry, visible bank, collision and fish movement share the same shoreline.
const SHORE= [Vector2(473,316),Vector2(524,288),Vector2(608,294),Vector2(669,320),Vector2(730,307),Vector2(793,277),Vector2(861,288),Vector2(910,326),Vector2(986,343),Vector2(1039,389),Vector2(1055,447),Vector2(1022,494),Vector2(970,522),Vector2(936,571),Vector2(881,602),Vector2(825,589),Vector2(768,615),Vector2(697,622),Vector2(629,599),Vector2(574,579),Vector2(539,533),Vector2(475,510),Vector2(439,463),Vector2(444,408),Vector2(461,364)]
const DOCK=Rect2(863,537,43,104)
const INTERACTION=Vector2(884,584)
var world
## Overridable geometry (village-center pond map bakes its own water and passes these in).
var shore:PackedVector2Array=PackedVector2Array(SHORE)
var dock:Rect2=DOCK
var interaction:Vector2=INTERACTION
var baked:=false
var stock:Dictionary={}
var bank_center:=Vector2(744,447)
var water_material:ShaderMaterial
var clock=0.0
var food_time=0.0
var ripples=[]
var fish=[]
var rng=RandomNumberGenerator.new()
func setup(host):
	world=host;rng.seed=55312;z_index=-5
	if stock.is_empty():stock=world.sim.data.pond
	var points=shore
	var bank=Polygon2D.new();var outline=PackedVector2Array()
	for p in points:outline.append((p+(p-bank_center).normalized()*14).snapped(Vector2(2,2)))
	bank.polygon=outline;bank.color=Color("9caa73");add_child(bank)
	var wet=Polygon2D.new();outline=PackedVector2Array()
	for p in points:outline.append((p+(p-bank_center).normalized()*6).snapped(Vector2(2,2)))
	wet.polygon=outline;wet.color=Color("657e64");add_child(wet)
	var water=Polygon2D.new();water.polygon=points
	water_material=ShaderMaterial.new();water_material.shader=load("res://qingxi-live/pond_water.gdshader")
	var padded=points.duplicate() if not baked else PackedVector2Array(SHORE)
	while padded.size()<32:padded.append(Vector2.ZERO)
	water_material.set_shader_parameter("shore",padded);water_material.set_shader_parameter("shore_count",mini(points.size(),32) if not baked else SHORE.size());water.material=water_material;add_child(water)
	# Fish and details are drawn on a later sibling, above the shader surface.
	var details=Node2D.new();details.set_script(load("res://qingxi-live/pond_details.gd"));details.pond=self;add_child(details)
	for i in 3:get_child(i).visible=not baked
func blocks(p:Vector2)->bool:
	if dock.has_area() and dock.grow(-5).has_point(p):return false
	return Geometry2D.is_point_in_polygon(p,shore)
func random_water()->Vector2:
	for i in 50:
		var box=Rect2(shore[0],Vector2.ZERO)
		for q in shore:box=box.expand(q)
		var p=Vector2(rng.randf_range(box.position.x,box.end.x),rng.randf_range(box.position.y,box.end.y))
		if Geometry2D.is_point_in_polygon(p,shore):return p
	return Vector2(700,450)
func splash():
	food_time=14
	for i in 3:ripples.append({"pos":interaction+Vector2(0,-57)+Vector2(rng.randf_range(-18,18),rng.randf_range(-9,3)),"age":-i*0.35})
func tick(dt:float):
	clock+=dt;food_time=maxf(0,food_time-dt)
	water_material.set_shader_parameter("clock",clock);water_material.set_shader_parameter("tint",world.ground_tint);water_material.set_shader_parameter("night_level",world.night_level)
	# Tint shore layers as well; water has its own time-of-day shader.
	get_child(0).modulate=world.ground_tint;get_child(1).modulate=world.ground_tint
	# Baked maps paint their own banks and water; only fish and ripples are drawn here.
	for i in 3:get_child(i).visible=not baked
	var count=int(stock.count)
	while fish.size()<count:fish.append({"pos":random_water(),"goal":random_water(),"phase":rng.randf()*6,"angle":0.0})
	while fish.size()>count:fish.pop_back()
	for f in fish:
		f.phase+=dt*5
		if food_time>0:f.goal=interaction+Vector2(0,-65)+Vector2(sin(f.phase*0.13)*20,cos(f.phase*0.19)*12)
		elif f.pos.distance_to(f.goal)<10:f.goal=random_water()
		var delta:Vector2=f.goal-f.pos
		if delta.length()>4:
			var next:Vector2=f.pos+delta.normalized()*minf(delta.length(),dt*(35 if food_time>0 else 19))
			if Geometry2D.is_point_in_polygon(next,shore):f.pos=next
			else:f.goal=random_water()
			f.angle=delta.angle()
	for r in ripples:r.age+=dt
	ripples=ripples.filter(func(r):return r.age<3)
	get_child(3).queue_redraw()
