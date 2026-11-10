class_name SeasideEnvironment
extends RefCounted
## Real city weather comes only from VADS weather.local. The legacy reading is simulated.
static var preview:Dictionary={}
static var geometry:Dictionary={}
static var house:=PackedVector2Array()
static var floors:Array[PackedVector2Array]=[]
static var textures:Dictionary={}

static func prepare() -> void:
	if not geometry.is_empty():return
	geometry=JSON.parse_string(FileAccess.get_file_as_string("res://assets/seaside-weather.json"))
	for p in geometry.house:house.append(Vector2(p[0],p[1]))
	var grid:Dictionary=JSON.parse_string(FileAccess.get_file_as_string("res://assets/home-grid-floor.json"))
	for points in grid.polygons.slice(0,3):
		var poly:=PackedVector2Array()
		for p in points:poly.append(Vector2(p[0],p[1]))
		floors.append(poly)

static func classify(local,now:float) -> Dictionary:
	var out:Dictionary={"kind":"unknown","rain":0.0,"cloud":0.4,"snow":false,"sun":0.0,"wind":0.0,"fresh":false}
	if not local is Dictionary:return out
	var at:=float(local.get("at",0));var fetched:=float(local.get("fetchedAt",0))
	if at<=0 or fetched<=0 or now<at-300000 or now<fetched-300000 or now-at>=5400000:return out
	var condition:=str(local.get("condition",""))
	if condition=="":return out
	out.fresh=true;out.wind=clampf(float(local.get("wind",0))/12.0,0,4)
	if "雪" in condition:out.merge({"kind":"snow","snow":true,"cloud":0.85},true)
	elif "雨" in condition or "雷" in condition:
		var heavy:= "大雨" in condition or "暴雨" in condition or "强" in condition or "雷" in condition or "中雨" in condition
		out.merge({"kind":"heavy_rain" if heavy else "light_rain","rain":0.9 if heavy else 0.3,"cloud":1.0},true)
	elif "云" in condition or "阴" in condition or "雾" in condition:out.merge({"kind":"cloudy","cloud":0.85 if "阴" in condition or "雾" in condition else 0.55,"sun":0.08},true)
	elif "晴" in condition:out.merge({"kind":"clear","cloud":0.05,"sun":1.0},true)
	else:out.fresh=false
	return out

static func state() -> Dictionary:
	return preview if not preview.is_empty() else classify(SharedFeed.local_weather,SharedFeed.now_ms())

static func lighting(base:Dictionary) -> Dictionary:
	var light:=base.duplicate();var w:=state()
	light.beamAlpha=float(base.beamAlpha)*float(w.sun)
	return light

static func texture(kind:String) -> Texture2D:
	if not textures.has(kind):textures[kind]=load("res://assets/seaside/weather-"+kind+".png")
	return textures[kind]

static func outside(p:Vector2) -> bool:
	prepare()
	return Rect2(0,0,960,640).has_point(p) and not Geometry2D.is_point_in_polygon(p,house)

static func draw_ground(c:CanvasItem) -> void:
	var w:=state();var rect:=Rect2(0,0,960,640)
	if w.snow:c.draw_texture_rect(texture("snow"),rect,false)
	elif w.rain>0:c.draw_texture_rect(texture("wet"),rect,false,Color(1,1,1,0.65 if w.kind=="light_rain" else 1.0))
	if w.cloud>0.2:c.draw_texture_rect(texture("outside-mask"),rect,false,Color(0.28,0.36,0.48,float(w.cloud)*0.10))

static func draw_floor(c:CanvasItem,light:Dictionary) -> void:
	prepare()
	if float(light.beamAlpha)<=0:return
	var shift:=clampf(float(light.shift),-65,65)
	for win in [[168.0,92.0,138.0,135.0],[596.0,104.0,166.0,143.0]]:
		for col in 5:
			for row in 3:
				var start:float=row*win[3]/3.0;var end:float=start+win[3]/3.0-7
				var x:float=win[0]+col*win[2]/5.0;var width:float=win[2]/5.0-5
				var beam:=PackedVector2Array([Vector2(x+shift*start/win[3],win[1]+start),Vector2(x+width+shift*start/win[3],win[1]+start),Vector2(x+width+shift*end/win[3],win[1]+end),Vector2(x+shift*end/win[3],win[1]+end)])
				for floor in floors:
					for part in Geometry2D.intersect_polygons(beam,floor):c.draw_colored_polygon(part,Color(1,.93,.66,float(light.beamAlpha)*1.8))

static func draw_top(c:CanvasItem,light:Dictionary,time:float) -> void:
	prepare();var w:=state()
	var night:bool=light.phase=="night"
	var main_on:=Daylight.light_enabled(str(RoomLight.lamp_settings("xiaojingyu-home").lamps),float(light.darkness))
	var interior:float=minf(float(light.darkness),0.10) if main_on else minf(float(light.darkness),0.58 if RoomLight.sleeping_in("xiaojingyu-home") else 0.40)
	c.draw_colored_polygon(house,Color(.10,.16,.29,interior+float(w.cloud)*0.025))
	c.draw_texture_rect(texture("outside-mask"),Rect2(0,0,960,640),false,Color(.055,.10,.22,0.30 if night else minf(float(light.darkness),.16)))
	# Window views are baked into the house artwork. Do not cover that artwork
	# with approximate glass masks or precipitation. Future weather variants must
	# replace the actual exterior picture while preserving the window frame.
	if w.snow:
		for i in 240:
			var p:=Vector2(fposmod(RoomLight.hash_of(i)*960+sin(time*.7+i)*9,960),fposmod(RoomLight.hash_of(i+.4)*640+time*18,640))
			if outside(p):c.draw_rect(Rect2(p.round(),Vector2(2,2)),Color(.94,.97,1,.9))
	elif w.rain>0:
		var heavy:bool=w.kind=="heavy_rain"
		for i in (650 if heavy else 190):
			var p:=Vector2(fposmod(RoomLight.hash_of(i)*960+time*float(w.wind)*12,960),fposmod(RoomLight.hash_of(i+.4)*640+time*(420 if heavy else 240),640))
			var end:=p+Vector2(1+float(w.wind),10 if heavy else 5)
			if outside(p) and outside(end):c.draw_line(p,end,Color(.79,.87,.97,.65 if heavy else .45),1)
		for i in (110 if heavy else 25):
			var p:=Vector2(RoomLight.hash_of(i+80)*960,RoomLight.hash_of(i+90)*640);var phase:=fposmod(time*2+RoomLight.hash_of(i),1)
			if outside(p) and outside(p+Vector2(4,2)) and outside(p-Vector2(4,2)):
				c.draw_arc(p,1+phase*3,0,TAU,8,Color(.75,.85,.95,(1-phase)*.45),1)
