extends RefCounted
## Registered to the original 960x640 park. Full-river route, banks and occluders.
const BANK=[Vector2(840,0),Vector2(837,20),Vector2(815,40),Vector2(804,60),Vector2(795,85),Vector2(785,110),Vector2(783,185),Vector2(800,208),Vector2(798,245),Vector2(817,267),Vector2(814,286),Vector2(792,308),Vector2(781,332),Vector2(780,418),Vector2(755,445),Vector2(737,470),Vector2(725,515),Vector2(740,546),Vector2(754,575),Vector2(752,609),Vector2(742,640),Vector2(848,640),Vector2(857,610),Vector2(840,580),Vector2(853,565),Vector2(861,540),Vector2(886,510),Vector2(903,489),Vector2(918,460),Vector2(937,428),Vector2(940,395),Vector2(923,375),Vector2(927,349),Vector2(939,324),Vector2(947,290),Vector2(940,260),Vector2(932,230),Vector2(907,205),Vector2(899,188),Vector2(904,110),Vector2(890,85),Vector2(908,55),Vector2(924,25),Vector2(908,0)]
const ROUTE=[Vector2(870,20),Vector2(851,48),Vector2(844,82),Vector2(842,120),Vector2(842,160),Vector2(848,193),Vector2(873,221),Vector2(888,249),Vector2(880,283),Vector2(867,311),Vector2(906,345),Vector2(908,385),Vector2(884,430),Vector2(876,454),Vector2(866,483),Vector2(823,515),Vector2(794,542),Vector2(793,578),Vector2(809,617)]
const ROCKS=[Vector3(840,245,23),Vector3(792,489,18),Vector3(825,478,23),Vector3(836,554,24)]
const BRIDGE=Rect2(767,109,155,82)
const PIER=Rect2(737,330,151,102)
static var curve:Curve2D
static var mask:Texture2D
static func water(p:Vector2)->bool:
	if not Geometry2D.is_point_in_polygon(p,PackedVector2Array(BANK)):return false
	for r in ROCKS:
		if p.distance_to(Vector2(r.x,r.y))<r.z:return false
	return true
static func visible_water(p:Vector2)->bool:
	return water(p) and not BRIDGE.has_point(p) and not PIER.has_point(p)
static func path()->Curve2D:
	if curve==null:
		curve=Curve2D.new();curve.bake_interval=2
		for p in ROUTE:curve.add_point(p)
	return curve
static func position(time:float,actor:int=0)->Vector2:
	var period:float=170.0 if actor==0 else 95.0+actor*19.0
	var progress:float=(1.0-cos(TAU*(time/period+actor*.193)))*.5
	var p:=path().sample_baked(progress*path().get_baked_length())
	if actor>0:
		var offset:=sin(time*.07+actor*1.7)*10
		# Clamp continuously at the shore, never jump back ten pixels on rejection.
		var original:=p
		for step in 10:
			var shifted:=original+Vector2(signf(offset)*minf(absf(offset),step+1),0)
			if not water(shifted):break
			p=shifted
	return p
static func direction(time:float,actor:int=0)->Vector2:
	return (position(time+.3,actor)-position(time-.3,actor)).normalized()
static func mask_texture()->Texture2D:
	if mask!=null:return mask
	var img:=Image.create(960,640,false,Image.FORMAT_RGBA8)
	for y in 640:
		for x in range(720,960):
			if visible_water(Vector2(x+.5,y+.5)):img.set_pixel(x,y,Color.WHITE)
	mask=ImageTexture.create_from_image(img)
	return mask
