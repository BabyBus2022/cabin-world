extends RefCounted
## Portable materials and cosmetic edits. Never changes the grid, furniture or exits.
const M = preload("res://core/map_model.gd")
const THEMES = {
	"coast":{"name":"海岸木屋","floor":"arcade-coast-wood","wall":"arcade-coast"},
	"blue":{"name":"蓝调小屋","floor":"floor-wood","wall":"whale-blue"},
	"brick":{"name":"复古砖屋","floor":"floor-stone","wall":"brick"},
	"cream":{"name":"奶油小店","floor":"shop-classic-tile","wall":"shop-cream"},
}

static func apply_theme(m:Dictionary, id:String)->Dictionary:
	if not THEMES.has(id) or M.outdoor(m):return m
	var out:=m.duplicate(true)
	# Replace the dominant floor only: carpets and other deliberate zones survive.
	var counts:={}
	for c in M.floor_cells(m):
		var t:=M.tile_of(m,c);counts[t]=int(counts.get(t,0))+1
	var dominant:="";var most:=0
	for t in counts:
		if int(counts[t])>most:dominant=t;most=int(counts[t])
	var cells:Array=[]
	for c in M.floor_cells(m):
		if M.tile_of(m,c)==dominant:cells.append(c)
	out=M.paint_floor(out,cells,THEMES[id].floor)
	for part in ["back","side","front"]:out=M.set_wall_style(out,part,THEMES[id].wall)
	return out

static func wall_key(part:String,c:Vector2i)->String:return "%s:%d:%d" % [part,c.x,c.y]
static func wall_target(m:Dictionary,c:Vector2i)->Dictionary:
	if M.is_inner(m,c):return {"part":"inner","cell":c}
	# Back wall is above its floor anchor, not a new row of collision cells.
	for dy in range(M.WALL_H+1):
		var p:=c+Vector2i(0,dy)
		if M.north_edge(m,p):return {"part":"back","cell":p}
	if M.south_edge(m,c):return {"part":"front","cell":c}
	if M.is_floor(m,c) and (not M.is_floor(m,c+Vector2i.LEFT) or not M.is_floor(m,c+Vector2i.RIGHT)):return {"part":"side","cell":c}
	return {}
static func paint_wall(m:Dictionary,c:Vector2i,style:String)->Dictionary:
	var at:=wall_target(m,c)
	if at.is_empty():return m
	var out:=m.duplicate(true)
	if not out.walls.has("segments"):out.walls.segments={}
	var key:=wall_key(at.part,at.cell)
	if style=="":out.walls.segments.erase(key)
	else:out.walls.segments[key]=style
	return out

static func import_png(m:Dictionary,kind:String,name:String,bytes:PackedByteArray)->Dictionary:
	if kind not in ["floor","wall"]:return {"error":"请选择地板或墙纸"}
	if bytes.size()<24 or bytes.size()>1024*1024:return {"error":"请选择 1 MB 以内的 PNG 材质"}
	if bytes.slice(0,8)!=PackedByteArray([137,80,78,71,13,10,26,10]):return {"error":"文件不是 PNG"}
	var w:=bytes.decode_u32(16);var h:=bytes.decode_u32(20)
	w=((w&255)<<24)|((w&65280)<<8)|((w>>8)&65280)|((w>>24)&255)
	h=((h&255)<<24)|((h&65280)<<8)|((h>>8)&65280)|((h>>24)&255)
	if w<64 or h<64 or w>512 or h>512 or w%M.Grid.ART_CELL!=0 or h%M.Grid.ART_CELL!=0:return {"error":"材质宽高须为 64 的整倍数，范围 64–512 像素；不会拉伸图片"}
	if kind=="floor" and w!=h:return {"error":"地板请提供正方形平铺材质（64、128…512 像素）"}
	var img:=Image.new()
	if img.load_png_from_buffer(bytes)!=OK:return {"error":"PNG 无法读取"}
	var out:=m.duplicate(true)
	if not out.has("materials"):out.materials={}
	if not out.materials.has(kind):out.materials[kind]={}
	var canonical:=img.save_png_to_buffer()
	var id:="custom-"+kind+"-"+str(canonical.hex_encode().sha256_text()).left(16)
	if out.materials[kind].size()>=24 and not out.materials[kind].has(id):return {"error":"每张地图每类最多 24 种自定义材质"}
	# Embedded PNG survives moving/sharing the draft; no absolute user file paths.
	out.materials[kind][id]={"name":name.left(32),"png":Marshalls.raw_to_base64(canonical),"span":w/M.Grid.ART_CELL,"outdoor":M.outdoor(m)}
	return {"map":out,"id":id,"error":""}

static func materials_issue(m:Dictionary)->String:
	var segments=m.get("walls",{}).get("segments",{})
	if not segments is Dictionary:return "局部墙面数据错误"
	for key in segments:
		if not key is String or not segments[key] is String:return "局部墙面编号错误"
		var parts:=str(key).split(":")
		if parts.size()!=3 or parts[0] not in ["back","front","side","inner"] or not parts[1].is_valid_int() or not parts[2].is_valid_int():return "局部墙面坐标错误"
		if not M.inb(m,Vector2i(int(parts[1]),int(parts[2]))):return "局部墙面超出地图"
	var materials=m.get("materials",{})
	if not materials is Dictionary:return "材质数据错误"
	for kind in materials:
		if kind not in ["floor","wall"] or not materials[kind] is Dictionary or materials[kind].size()>24:return "材质分类或数量错误"
		for id in materials[kind]:
			var d=materials[kind][id]
			if not d is Dictionary or not d.get("png") is String or d.png.length()>1400000:return "材质图片数据错误"
			var check:=import_png(M.new_map("check","check"),kind,str(d.get("name","材质")),Marshalls.base64_to_raw(d.png))
			if check.error!="":return check.error
			if id!=check.id or int(d.get("span",0))!=int(check.map.materials[kind][id].span):return "材质编号或格子比例不匹配"
	return ""
