extends RefCounted
## Replaces pixels inside registered glass panes in the original texture itself.
## No covering CanvasItem, dark tint plate, or old colour-threshold glass mask.
static var atlas:Image
static var originals:Dictionary={}
static var cache:Dictionary={}
static var _geometry:Dictionary={}
static func geometry()->Dictionary:
	if _geometry.is_empty():_geometry=JSON.parse_string(FileAccess.get_file_as_string("res://assets/window-scenery/geometry.json"))
	return _geometry
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
	var out:Array=[]
	for raw in geometry().get("ground" if kind=="ground" else "window",[]):
		var b:Array=raw.bounds
		out.append({"bounds":Rect2i(b[0],b[1],b[2],b[3]),"panes":rectangles(raw.xs,raw.ys),"corners":raw.get("corners",[])})
	return out
static func picture(kind:String,key:String)->Texture2D:
	var id:=kind+":"+key
	if cache.has(id):return cache[id]
	if atlas==null:atlas=load("res://assets/window-scenery/atlas.png").get_image()
	if not originals.has(kind):originals[kind]=load("res://assets/seaside/"+("ground-dynamic" if kind=="ground" else "xj-window")+".png").get_image()
	var image:Image=originals[kind].duplicate()
	var parts:=key.split(":");var col:=int(parts[0]);var row:=int(parts[1])
	var xs:Array=geometry().atlas.columns;var ys:Array=geometry().atlas.rows
	var tile:=Rect2i(xs[col]+2,ys[row]+2,xs[col+1]-xs[col]-4,ys[row+1]-ys[row]-4)
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
