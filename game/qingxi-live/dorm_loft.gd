extends RefCounted
const SHELL=Rect2(0,0,1280,853)
const DOOR=Vector2(640,247)
# Coordinates follow the inside edge of the walls on the 1536 x 1024 painted map.
const EDGE=[Vector2(42,419),Vector2(102,393),Vector2(366,393),Vector2(366,278),Vector2(1165,278),Vector2(1165,631),Vector2(1364,631),Vector2(1491,694),Vector2(1491,737),Vector2(1057,737),Vector2(974,823),Vector2(488,823),Vector2(400,737),Vector2(310,737),Vector2(310,537),Vector2(42,537)]
static var polygon:=PackedVector2Array()
static var shell_texture:Texture2D
static func inside(point:Vector2)->bool:
	if polygon.is_empty():
		for vertex in EDGE:polygon.append(vertex*5.0/6)
	return Geometry2D.is_point_in_polygon(point,polygon)
static func contains_rect(rect:Rect2)->bool:
	for point in [rect.position,Vector2(rect.end.x,rect.position.y),rect.end,Vector2(rect.position.x,rect.end.y),rect.get_center()]:
		if not inside(point):return false
	# A rectangle spanning a re-entrant corner crosses a wall even if its four corners fit.
	for vertex in polygon:
		if rect.grow(-0.5).has_point(vertex):return false
	return true
static func texture()->Texture2D:
	if not shell_texture:
		var img:=Image.new()
		if img.load_png_from_buffer(FileAccess.get_file_as_bytes("res://qingxi-live/dorm-loft.png"))==OK:
			shell_texture=ImageTexture.create_from_image(img)
	return shell_texture

# Stable bed IDs keep sleepers attached to the same bed through the renovation.
const POSITIONS={
	"room_0":Vector2(159,418),"room_1":Vector2(384,340),"room_2":Vector2(854,365),
	"room_3":Vector2(232,401),"room_4":Vector2(926,342),"room_5":Vector2(475,269),
	"detail_house_fern_958":Vector2(945,279),"detail_cw_bookshelf_761":Vector2(1075,538),
	"detail_house_lamp_309":Vector2(444,593),"detail_cw_sofa_402":Vector2(523,608),
	"detail_cw_side_table_406":Vector2(515,659),"detail_house_cushions_504":Vector2(608,651),
	"detail_cw_writing_desk_819":Vector2(1104,570),"detail_cw_chair_n_820":Vector2(1104,602),
	"detail_house_easel_935":Vector2(1193,595),"detail_house_basket_555":Vector2(317,302)
}
const ORIGINAL={
	"room_0":Vector2(400,475),"room_1":Vector2(632,475),"room_2":Vector2(864,475),
	"room_3":Vector2(510,432),"room_4":Vector2(752,432),"room_5":Vector2(327,340),
	"detail_house_fern_958":Vector2(958,327),"detail_cw_bookshelf_761":Vector2(761,341),
	"detail_house_lamp_309":Vector2(309,584),"detail_cw_sofa_402":Vector2(402,612),
	"detail_cw_side_table_406":Vector2(406,675),"detail_house_cushions_504":Vector2(504,665),
	"detail_cw_writing_desk_819":Vector2(819,585),"detail_cw_chair_n_820":Vector2(820,622),
	"detail_house_easel_935":Vector2(935,640),"detail_house_basket_555":Vector2(555,340)
}
static func bounds_for(grid,row:Array,at:Vector2)->Rect2:
	if row.size()<5:return grid.footprint(row[0],at)
	var b=row[4]
	return Rect2(at+Vector2(b[0],b[1]),Vector2(b[2],b[3]))
static func relocate(grid)->void:
	if grid.plan.get("loft_design",0)>=1:return
	var rows:Dictionary=grid.plan.furniture
	var reserved:Array[Rect2]=[Rect2(DOOR-Vector2(30,10),Vector2(60,65))]
	var pending:Array=[]
	# Reserve manually placed pieces first. Preserve every existing inventory/bed key.
	for id in rows:
		var row:Array=rows[id]
		var at:=Vector2(row[1],row[2])
		if ORIGINAL.has(id) and at==ORIGINAL[id]:
			pending.append([id,POSITIONS[id]])
		elif contains_rect(bounds_for(grid,row,at)) and not reserved[0].intersects(bounds_for(grid,row,at)):
			reserved.append(bounds_for(grid,row,at))
		else:pending.push_front([id,at])
	for slot in pending:
		var row:Array=rows[slot[0]]
		var goal:Vector2=slot[1]
		var at:=free_point(grid,row,goal,reserved)
		row[1]=at.x;row[2]=at.y
		reserved.append(bounds_for(grid,row,at))
	for piece in [["loft_common_table","cw_table",490,472,104],["loft_west_seat","cw_chair_e",422,464,32],["loft_east_seat","cw_chair_w",557,464,32],["loft_fern","house_leaf",738,628,38]]:
		var row=[piece[1],piece[2],piece[3],piece[4],[-piece[4]*.39,-18,piece[4]*.78,18]]
		var box:=bounds_for(grid,row,Vector2(row[1],row[2]))
		if contains_rect(box) and not overlaps(box,reserved):
			rows[piece[0]]=row;reserved.append(box)
	grid.plan.loft_design=1
static func overlaps(box:Rect2,reserved:Array[Rect2])->bool:
	for other in reserved:
		if other.intersects(box.grow(3)):return true
	return false
static func free_point(grid,row:Array,goal:Vector2,reserved:Array[Rect2])->Vector2:
	var box:=bounds_for(grid,row,goal)
	if contains_rect(box) and not overlaps(box,reserved):return goal
	var best:=Vector2.INF
	var distance:=INF
	for y in range(247,685,12):
		for x in range(44,1250,12):
			var p:=Vector2(x,y)
			var score:=p.distance_squared_to(goal)
			if score>=distance:continue
			box=bounds_for(grid,row,p)
			if contains_rect(box) and not overlaps(box,reserved):
				best=p;distance=score
	return best if best!=Vector2.INF else goal
