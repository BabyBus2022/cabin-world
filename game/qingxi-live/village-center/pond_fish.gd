extends RefCounted
const DIR = "res://qingxi-live/village-center/"
const HOURS = 28800.0
static var catalog:Dictionary = {}
static var textures := {}

static func kinds() -> Dictionary:
	if catalog.is_empty(): catalog = JSON.parse_string(FileAccess.get_file_as_string(DIR+"pond_species.json"))
	return catalog

static func new_fish() -> Dictionary:
	var total := 0
	for spec in kinds().values(): total += int(spec.weight)
	var roll := randi_range(1,total)
	for key in kinds():
		var spec:Dictionary=catalog[key]
		roll -= int(spec.weight)
		if roll <= 0:
			return {"kind":key,"cm":snappedf(randf_range(spec.min,spec.max),0.1),"age":0.0}
	return {}

static func stock(p:Dictionary) -> Array:
	# A legacy pond has one age for its entire batch. Give every surviving fish that age.
	if not p.has("fish") or p.fish.size() != int(p.count):
		var fish:Array=p.get("fish",[])
		while fish.size() > int(p.count): fish.pop_back()
		while fish.size() < int(p.count):
			var f := new_fish()
			f.age = float(p.progress)
			fish.append(f)
		p.fish=fish
	return p.fish

static func grow(p:Dictionary, seconds:float):
	if int(p.count)==0: return
	var fed := minf(seconds,float(p.feed))
	var max_age := 0.0
	for f in stock(p):
		f.age=minf(HOURS,float(f.age)+fed)
		max_age=maxf(max_age,float(f.age))
	p.progress=max_age
	p.feed=maxf(0.0,float(p.feed)-fed)

static func growth(f:Dictionary) -> float:
	return lerpf(0.25,1.0,clampf(float(f.age)/HOURS,0,1))

static func length_cm(f:Dictionary) -> float:
	return snappedf(float(f.cm)*growth(f),0.1)

static func pixels(f:Dictionary) -> float:
	var spec:Dictionary=kinds()[f.kind]
	var adult=float(spec.pixels)*float(f.cm)/((spec.min+spec.max)*0.5)
	return lerpf(17.0+adult*.20,26.0+adult*.80,clampf(float(f.age)/HOURS,0,1))

static func draw_fish(canvas:CanvasItem,f:Dictionary,pos:Vector2,angle:float,t:float,tint:Color):
	var key:String=f.kind
	if not textures.has(key):
		var im:=Image.load_from_file(DIR+"art/swimming-fish/"+key+".png")
		if im==null or im.is_empty():return
		textures[key]=ImageTexture.create_from_image(im)
	var tex:Texture2D=textures[key]
	var size:=Vector2(pixels(f),pixels(f)*tex.get_height()/float(tex.get_width()))
	var vertices:=PackedVector2Array()
	var uv:=PackedVector2Array()
	var indices:=PackedInt32Array()
	for i in 9:
		var u=i/8.0
		var tail=1.-u
		var beat=sin(t+u*4.5)
		var x=(u-.5)*size.x + beat*tail*tail*size.x*.017
		var y=beat*tail*tail*size.x*.072 + sin(t+u*2.)*tail*size.y*.022
		for v in 2:
			vertices.append(Vector2(x,y+(v-.5)*size.y))
			uv.append(Vector2(u,v))
		if i<8:
			var j=i*2
			indices.append_array(PackedInt32Array([j,j+1,j+2,j+2,j+1,j+3]))
	canvas.draw_set_transform(pos+Vector2(1.8,3.2),angle,Vector2.ONE)
	RenderingServer.canvas_item_add_triangle_array(canvas.get_canvas_item(),indices,vertices,PackedColorArray([Color(.06,.19,.23,.27)]),uv,PackedInt32Array(),PackedFloat32Array(),tex.get_rid())
	canvas.draw_set_transform(pos,angle,Vector2.ONE)
	RenderingServer.canvas_item_add_triangle_array(canvas.get_canvas_item(),indices,vertices,PackedColorArray([tint]),uv,PackedInt32Array(),PackedFloat32Array(),tex.get_rid())
	canvas.draw_set_transform(Vector2.ZERO,0,Vector2.ONE)

static func key_for(f:Dictionary) -> String:
	return "catch:"+str(f.kind)+":"+str(roundi(length_cm(f)*10.0))
static func label(key:String) -> String:
	return "%s · %.1f 厘米" % [kinds()[key.get_slice(":",1)].name,float(key.get_slice(":",2))/10.0]
static func price(key:String) -> int:
	var spec:Dictionary=kinds()[key.get_slice(":",1)]
	return maxi(2,roundi(float(key.get_slice(":",2))*0.045*(1.8 if int(spec.weight)<=2 else 1.0)))
static func bite_delay() -> float: return randf_range(1.5,4.0)
const BITE_WINDOW=2.0
static func hooked(elapsed:float,delay:float) -> bool:
	return elapsed>=delay and elapsed<=delay+BITE_WINDOW

