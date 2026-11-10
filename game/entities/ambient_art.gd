class_name AmbientArt
extends Node2D
## Original park-nature.mjs and onsen-effects.mjs parameters. Pure command
## generation is tested against the old renderer; this node only draws them.
var scene := ""
var layer := ""
var clock := 0.0
var commands: Array = []
static var textures := {}
const RiverLife=preload("res://entities/river_life.gd")
const CANOPIES := [[95,61,162,104,true],[923,29,61,55,true],[332,25,68,34,false],[700,31,77,40,false],[46,264,40,67,false]]
const BEDS := [[263,271,60,29],[609,308,75,35],[869,503,55,35],[77,305,35,28],[386,32,54,27]]
const WATERS := [[862,20,30,64],[876,221,56,103],[882,442,25,68],[827,557,32,61]]
const FISH_RECTS := [[94,161,336,216],[573,206,387,132],[1055,125,457,273],[121,712,294,105],[573,612,346,287]]
const FOOD_NAMES := ["草莓软糖","海苔薯片","奶油面包","巧克力棒","小鱼饼干","冰镇橘子汽水","草莓牛奶","乌龙茶","矿泉水","柠檬茶","香草冰淇淋","西瓜冰棍"]
const HOT_IDS := ["hot_milk","hot_coffee","hot_latte","hot_cocoa","ginger_tea","hot_honey_lemon","hot_green_tea","hot_corn_milk"]

static func mount(room: Node2D, id: String) -> void:
	var events := AmbientArt.new()
	events.scene=id
	events.layer="events"
	events.z_index=99
	room.add_child(events)
	if id=="world-onsen":
		var mask := Node2D.new()
		mask.z_index = 0
		mask.clip_children = CanvasItem.CLIP_CHILDREN_ONLY
		var style := StyleBoxFlat.new()
		style.bg_color = Color.WHITE
		style.set_corner_radius_all(16)
		mask.draw.connect(func(): mask.draw_style_box(style,Rect2(165,105,560,204)))
		room.add_child(mask)
		var water := AmbientArt.new()
		water.scene=id
		water.layer="water"
		mask.add_child(water)
		var steam := AmbientArt.new()
		steam.scene=id
		steam.layer="steam"
		steam.z_index=99
		room.add_child(steam)
	elif id=="qianxia-park":
		var nature := AmbientArt.new()
		nature.scene=id
		nature.layer="nature"
		nature.z_index=0
		room.add_child(nature)
		var dimensions: Dictionary=WorldData.scenes[id]
		nature.scale=Vector2(float(dimensions.width)/960,float(dimensions.height)/640)
		var river: Dictionary=WorldPresentation.facts().scenes[id].modules.get("river-middle",{})
		if not river.is_empty():
			var mask := Node2D.new()
			mask.z_index=98
			mask.clip_children=CanvasItem.CLIP_CHILDREN_ONLY
			mask.scale=Vector2(float(dimensions.width)/960,float(dimensions.height)/640)
			mask.draw.connect(func(): mask.draw_texture(RiverLife.mask_texture(),Vector2.ZERO))
			room.add_child(mask)
			var animals := AmbientArt.new()
			animals.scene=id
			animals.layer="river"
			mask.add_child(animals)

static func texture(file: String) -> Texture2D:
	if not textures.has(file): textures[file]=load("res://assets/world/"+file)
	return textures[file]

static func fract(n: float) -> float: return n-floorf(n)
static func noise(n: float) -> float: return fract(sin(n*127.1+31.7)*43758.5453)
static func pixel(out: Array, color: String, x: float, y: float, w: float=2, h: float=1, alpha: float=1) -> void:
	out.append({"kind":"rect","color":color,"rect":[floorf(x+.5),floorf(y+.5),w,h],"alpha":alpha})
static func cell(out: Array, file: String, frame: int, cols: int, rows: int, rect: Array, alpha: float=1) -> void:
	out.append({"kind":"sprite","file":file,"cell":frame,"cols":cols,"rows":rows,"rect":rect,"alpha":alpha})
static func onsen_sprite(out: Array,row: int,x: float,y: float,w: float,h: float,t: float,alpha: float) -> void:
	var phase := t*.9
	var step := int(floorf(phase))
	var blend := phase-step
	var sequence := [0,1,2,3,2,1]
	for pair in [[sequence[posmod(step,6)],1-blend],[sequence[posmod(step+1,6)],blend]]:
		out.append({"kind":"region","file":"onsen/steam-water-frames.png","source":[pair[0]*160,256 if row else 0,160,128 if row else 256],"rect":[x-w/2,y-h,w,h],"alpha":alpha*pair[1]})

static func onsen(time: float, part: String, reduced: bool=false) -> Array:
	var out := []
	var t := 0.0 if reduced else time
	if part=="water":
		for i in 10: onsen_sprite(out,1,220+(i%4)*144+sin(t*.45+i)*7,166+floori(i/4.0)*61,158,68,t+i*.73,.48)
	else:
		var points := [[210,194,116,133],[350,212,134,155],[503,187,136,150],[651,214,124,156],[275,292,128,139],[465,300,131,149],[646,294,124,139]]
		for i in points.size():
			var p: Array=points[i]
			onsen_sprite(out,0,p[0]+sin(t*.35+i)*8,p[1],p[2],p[3],t+i*.8,.36)
		for i in 3: onsen_sprite(out,0,868,123+i*98,53,67,t+i,.20)
	return out

static func park(weather: Dictionary, light: Dictionary, time: float, reduced: bool=false) -> Array:
	var out := []
	var wind := clampf(float(weather.get("wind",.3)),.3,2)
	var t := time*.45 if reduced else time
	for j in WATERS.size():
		var r: Array=WATERS[j]
		for k in 7:
			var x: float=r[0]+(noise(k+j*21)-.5)*r[2]+sin(t*.6+k)*2
			var y: float=r[1]+fmod(noise(k+73)*r[3]+t*(2+wind),r[3])
			var alpha := .12+.12*(.5+.5*sin(t*1.7+k))
			pixel(out,"#bacff1" if light.phase=="night" else "#e2f8fc",x,y,4+k%4,1,alpha)
			pixel(out,"#6daabd",x-2,y+2,4,1,alpha)
	for j in CANOPIES.size():
		var c: Array=CANOPIES[j]
		for k in 12:
			var a := noise(k+j*31)*TAU
			var r := sqrt(noise(k+52+j))
			var x: float=c[0]+cos(a)*c[2]*.43*r
			var y: float=c[1]+sin(a)*c[3]*.4*r
			var dx := floorf(sin(t*1.3+k*.8)*wind+.5)
			var dy := floorf(sin(t*.9+k)*.7+.5)
			pixel(out,"#efb3c5" if c[4] else "#80934b",x+dx,y+dy,3,2,.55)
			pixel(out,"#ffe1dc" if c[4] else "#b4bd6a",x+dx+1,y+dy-1,2,1,.55)
			if light.phase=="day": pixel(out,"#fff0bb",x+12+float(light.get("shift",0))*.12,y+63,7,3,.035+.025*sin(t*.8+k))
	for k in (4 if reduced else 9):
		var p := fract(t*(.025+noise(k)*.013)+noise(k+10))
		pixel(out,"#edafc5" if k%2 else "#ffe1d5",35+noise(k+20)*115+p*23+sin(t*.8+k)*5,35+p*158,3 if sin(t*3+k)>0 else 1,2,sin(p*PI)*.7)
	for j in BEDS.size():
		var b: Array=BEDS[j]
		for k in 7:
			var x: float=b[0]+(noise(k+81*j)-.5)*b[2]
			var y: float=b[1]+(noise(k+19+j*29)-.5)*b[3]
			var sway := floorf(sin(t*1.6+j+k)*wind+.5)
			pixel(out,"#526d3a",x,y,1,4,.75)
			pixel(out,"#e6dcca" if k%3 else "#d4afd3",x+sway-1,y-1,3,2,.75)
			pixel(out,"#d9be7c",x+sway,y,1,1,.75)
	if float(weather.get("rain",0))<=0 and light.phase=="day":
		var b: Array=BEDS[1]
		for k in (2 if reduced else 3): cell(out,"life/event-butterflies-draft.png",(int(floorf(t*4))%2)*3+k,6,1,[b[0]+sin(t*.6+k*2)*34-10,b[1]-18+sin(t*.9+k)*12-10,20,20])
	if light.phase=="night" and float(weather.get("rain",0))<=0:
		for k in (3 if reduced else 6):
			var b: Array=BEDS[k%BEDS.size()]
			pixel(out,"#edebad",b[0]+sin(t*.3+k)*24,b[1]-8+cos(t*.4+k)*12,2,2,maxf(0,sin(t*1.2+k*2))*.7)
	return out

static func fish(out: Array, frame: int, x: float, y: float, width: float, alpha: float=1, flip: bool=false, angle: float=0) -> void:
	var rect: Array=FISH_RECTS[frame]
	var height: float=width*rect[3]/rect[2]
	out.append({"kind":"region","file":"life/fish-log-draft.png","source":rect,"rect":[-width/2,-height/2,width,height],"alpha":alpha,"at":[x,y],"flip":flip,"angle":angle})

static func river(m: Dictionary, weather: Dictionary, time: float, fish_day: bool) -> Array:
	var out := []
	if m.is_empty(): return out
	var storm:bool=float(weather.get("rain",0))>.5
	# Continuous independent journeys, with a full-river excursion for each animal.
	var duck:Vector2=RiverLife.position(time)
	var heading:Vector2=RiverLife.direction(time)
	cell(out,"life/event-ducklings-draft.png",int(floorf(time*3))%2,1,2,[-27,-10,54,27])
	out[-1].merge({"at":[duck.x,duck.y],"flip":heading.x>0,"angle":0})
	for k in 4:
		var p:Vector2=RiverLife.position(time,k+1)
		var d:Vector2=RiverLife.direction(time,k+1)
		fish(out,k%4,p.x,p.y,18,.35 if storm else .55,false,d.angle())
	var jump:=fmod(time,9 if fish_day else 19)
	var jumper:Vector2=RiverLife.position(time,2)
	if not storm and jump<1.6 and RiverLife.visible_water(jumper):
		cell(out,"life/event-fish-draft.png",mini(3,int(floorf(jump*2.5))),4,1,[jumper.x-16,jumper.y-22,33,33])
	for k in 5:
		var p:Vector2=RiverLife.position(time,k)
		out.append({"kind":"line","rect":[p.x-4,p.y+10,p.x+4,p.y+10],"color":"#ccebfa","alpha":.2})
	return out

static func food(effect: Dictionary, now: float) -> Array:
	var out := []
	if effect.is_empty() or now-float(effect.get("at",0))>float(effect.get("seconds",7))*1000: return out
	var item: Dictionary=effect.item if effect.get("item") is Dictionary else {}
	var hot := HOT_IDS.find(item.get("id"))
	var normal := FOOD_NAMES.find(item.get("name"))
	if hot>=0: cell(out,"life/hot-drinks-draft.png",hot,4,2,[10,-45,20,20])
	elif normal>=0: cell(out,"life/food-icons-draft.png",normal,4,4,[10,-45,20,20])
	elif effect.get("kind")=="hearts": cell(out,"life/food-icons-draft.png",12,4,4,[10,-45,18,18])
	return out

static func caught(outcome: Dictionary, x: float, y: float, time: float) -> Array:
	var out := []
	if float(outcome.get("sizeCm",0))<=0:return out
	var name := str(outcome.get("catch",""))
	var frame := 2 if "鲤" in name else 1 if "泥鳅" in name or "虾虎" in name or "鳅" in name else 4 if "虾" in name else 3 if "白条" in name or "麦穗" in name else 0
	fish(out,frame,x,y,clampf(float(outcome.sizeCm)*.7,18,32),1,false,sin(time*9)*.13)
	return out

func _process(delta: float) -> void:
	clock+=delta
	if is_visible_in_tree(): queue_redraw()

func _draw() -> void:
	var weather: Dictionary=SharedFeed.weather if SharedFeed.weather is Dictionary else {}
	if layer=="events": commands=event_art(scene,WorldPresentation.facts().scenes[scene],Life.world_events(Economy.today(),weather),clock)
	elif layer=="nature": commands=park(weather,Daylight.reading(SharedFeed.now_ms()),clock)
	elif layer=="river": commands=river(WorldPresentation.facts().scenes[scene].modules.get("river-middle",{}),weather,clock,Life.world_events(Economy.today(),weather).any(func(e):return e.id=="fish_day"))
	else: commands=onsen(clock,layer)
	paint(self,commands)

static func event_art(id: String, room: Dictionary, events: Array, time: float) -> Array:
	var out := []
	var modules: Dictionary=room.modules
	var frame := int(floorf(time*2))%2
	var outdoor := id=="qianxia-park"
	for event in events:
		if id=="qianxia-shop" and event.has("sale"):
			var shelf: String={"snack":"snack-shelf","drink":"drink-fridge","icecream":"freezer"}.get(event.sale,"")
			var m: Dictionary=modules.get(shelf,{})
			if not m.is_empty():cell(out,"life/event-sale-draft.png",0,1,1,[m.x+m.w-24,m.y+8,24,24])
		if event.id=="stars" and not outdoor:
			for m in modules.values():
				if m.get("kind")=="window" or "window" in m.id or "shoji" in m.id:
					cell(out,"life/event-stars-draft.png",frame,2,1,[m.x+4,m.y+4,maxf(0,m.w-8),maxf(0,m.h*.55)],.55)
					break
		if not outdoor:continue
		var width := float(room.get("width",960))
		if event.id=="rainbow":cell(out,"life/event-rainbow-draft.png",0,1,1,[width*.3,10,width*.4,100],.5)
		if event.id=="stars":
			for i in 5:cell(out,"life/event-stars-draft.png",frame,2,1,[width*(.12+i*.17),12+(i%2)*18,60,40],.6)
		if event.id=="butterflies" and modules.has("flowers"):
			var m: Dictionary=modules.flowers
			for i in 3:cell(out,"life/event-butterflies-draft.png",frame*3+i,6,1,[m.x+i*m.w/3,m.y-10+sin(time+i)*4,20,30])
	return out

static func paint(canvas: CanvasItem, rows: Array) -> void:
	for row in rows:
		if row.has("at"): canvas.draw_set_transform(Vector2(row.at[0],row.at[1]),float(row.get("angle",0)),Vector2(-1 if row.get("flip",false) else 1,1))
		var r: Array=row.rect
		var dest := Rect2(r[0],r[1],r[2],r[3])
		var color := Color.WHITE
		color.a=row.alpha
		if row.kind=="line":
			color=Color(row.color)
			color.a=row.alpha
			canvas.draw_line(Vector2(r[0],r[1]),Vector2(r[2],r[3]),color,1)
		elif row.kind=="rect":
			color=Color(row.color)
			color.a=row.alpha
			canvas.draw_rect(dest,color)
		else:
			var tex := texture(row.file)
			var source: Rect2
			if row.kind=="region": source=Rect2(row.source[0],row.source[1],row.source[2],row.source[3])
			else:
				var size := tex.get_size()/Vector2(row.cols,row.rows)
				source=Rect2(Vector2(int(row.cell)%int(row.cols),floorf(float(row.cell)/row.cols))*size,size)
			canvas.draw_texture_rect_region(tex,dest,source,color)
		if row.has("at"): canvas.draw_set_transform(Vector2.ZERO)
