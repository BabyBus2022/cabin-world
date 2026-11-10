extends RefCounted
## Replaces pixels inside registered glass panes in the original texture itself.
## No covering CanvasItem, dark tint plate, or old colour-threshold glass mask.
static var atlas:Image
static var originals:Dictionary={}
static var cache:Dictionary={}
const ROWS=[0,211,421,632,838,992]
const COLS=[0,397,793,1190,1586]
static func state_key(now:float,weather:Dictionary)->String:
	var phase:String=Daylight.reading(now).phase
	var column:int={"dawn":0,"day":1,"dusk":2,"night":3}.get(phase,1)
	var row:int={"clear":0,"light_rain":1,"heavy_rain":2,"cloudy":3,"snow":4}.get(weather.get("kind","unknown"),3)
	return str(column)+":"+str(row)
static func rectangles(xs:Array,ys:Array)->Array:
	var out:Array=[]
	for x in xs:
		for y in ys:out.append(Rect2i(x[0],y[0],x[1]-x[0]+1,y[1]-y[0]+1))
	return out
static func banks(kind:String)->Array:
	if kind=="ground":
		return [
			{"bounds":Rect2i(338,69,270,94),"panes":rectangles([[339,359],[365,389],[396,418],[424,449],[455,479],[495,518],[525,546],[554,576],[583,605]],[[71,89],[95,112],[119,136],[143,160]])},
			{"bounds":Rect2i(1196,61,329,126),"panes":rectangles([[1198,1229],[1236,1264],[1271,1300],[1310,1338],[1345,1374],[1381,1408],[1424,1452],[1459,1487],[1494,1523]],[[65,87],[95,119],[127,151],[160,184]])},
			{"bounds":Rect2i(329,558,69,86),"panes":rectangles([[330,348],[355,372],[379,397]],[[559,576],[582,598],[605,621],[627,642]])},
			{"bounds":Rect2i(626,558,72,86),"panes":rectangles([[628,646],[653,672],[679,696]],[[559,576],[582,598],[605,621],[627,642]])},
			{"bounds":Rect2i(1043,558,69,86),"panes":rectangles([[1044,1062],[1068,1086],[1093,1110]],[[559,576],[582,598],[605,621],[627,642]])},
			{"bounds":Rect2i(1336,558,72,86),"panes":rectangles([[1338,1356],[1362,1380],[1387,1405]],[[559,576],[582,598],[605,621],[627,642]])}
		]
	return [{"bounds":Rect2i(33,19,99,85),"panes":rectangles([[57,77],[86,106]],[[20,33],[40,55],[64,79],[88,102]]),"corners":[[[51,41],[53,41],[53,55],[43,55]],[[34,64],[53,64],[53,79],[37,79]],[[39,88],[53,88],[53,102],[42,102]],[[113,41],[111,41],[111,55],[121,55]],[[130,64],[111,64],[111,79],[127,79]],[[125,88],[111,88],[111,102],[122,102]]]}]
static func picture(kind:String,key:String)->Texture2D:
	var id:=kind+":"+key
	if cache.has(id):return cache[id]
	if atlas==null:atlas=load("res://assets/window-scenery/atlas.png").get_image()
	if not originals.has(kind):originals[kind]=load("res://assets/seaside/"+("ground-dynamic" if kind=="ground" else "xj-window")+".png").get_image()
	var image:Image=originals[kind].duplicate()
	var parts:=key.split(":");var col:=int(parts[0]);var row:=int(parts[1])
	var tile:=Rect2i(COLS[col]+2,ROWS[row]+2,COLS[col+1]-COLS[col]-4,ROWS[row+1]-ROWS[row]-4)
	for bank in banks(kind):
		var points:Dictionary={}
		for pane in bank.panes:
			for y in range(pane.position.y,pane.end.y):
				for x in range(pane.position.x,pane.end.x):points[Vector2i(x,y)]=true
		for shape in bank.get("corners",[]):
			var polygon:=PackedVector2Array()
			for p in shape:polygon.append(Vector2(p[0],p[1]))
			for y in range(bank.bounds.position.y,bank.bounds.end.y):
				for x in range(bank.bounds.position.x,bank.bounds.end.x):
					if Geometry2D.is_point_in_polygon(Vector2(x+.5,y+.5),polygon):points[Vector2i(x,y)]=true
		for p in points:
			var uv:Vector2=(Vector2(p)-Vector2(bank.bounds.position))/Vector2(bank.bounds.size)
			var sample:=tile.position+Vector2i(uv*Vector2(tile.size))
			image.set_pixelv(p,atlas.get_pixelv(sample))
	var result:=ImageTexture.create_from_image(image)
	if cache.size()>=4:cache.erase(cache.keys()[0])
	cache[id]=result
	return result
static func update(sprite:Sprite2D,kind:String,now:float,weather:Dictionary)->void:
	var key:=state_key(now,weather)
	if sprite.get_meta("window_state","")==key:return
	sprite.texture=picture(kind,key)
	sprite.set_meta("window_state",key)
