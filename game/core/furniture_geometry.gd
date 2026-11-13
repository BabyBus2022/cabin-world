extends RefCounted
## Geometry inspection is shared by the maker and regression checks. Art height
## includes the object's elevation; it must never be forced into floor depth.
const Grid=preload("res://core/world_grid.gd")
const Library=preload("res://core/furniture_library.gd")
const FACES=["S","W","N","E"]
static var textures:Dictionary={}
static func texture(file:String)->Texture2D:
	if not textures.has(file):textures[file]=Library.icon(file if file.begins_with("res://") or file.begins_with("made:") else "res://assets/baked/"+file)
	return textures[file]
static func view(asset:Dictionary,face:String)->Dictionary:
	if asset.get("facings",{}).has(face):return asset.facings[face]
	if face!="S" or asset.get("layers",[]).is_empty():return {}
	var l:Dictionary=asset.layers[0]
	return {"file":l.file,"footprint":asset.footprint,"art":{"x":l.x,"y":l.y,"w":l.w,"h":l.h},"scale":l.get("scale",.5),"region":l.get("region",[])}
static func inspect(asset:Dictionary,face:String)->Dictionary:
	var expected:=Grid.footprint(int(asset.footprint.w),int(asset.footprint.h),face)
	var v:=view(asset,face);var issues:=[]
	if v.is_empty():return {"ok":false,"issues":["缺少该方向素材"],"footprint":expected,"view":v}
	if v.get("mirror",false):issues.append("此方向仍是镜像占位")
	var f:Dictionary=v.get("footprint",{})
	if f.get("w")!=expected.x or f.get("h")!=expected.y:issues.append("占格不符：应为 %d×%d 格" % [expected.x,expected.y])
	var tex:=texture(str(v.get("file","")))
	if tex==null:issues.append("图片无法读取")
	else:
		var sz:=tex.get_size();var region=v.get("region",[])
		if region is Array and region.size()==4:sz=Vector2(region[2],region[3])
		var art:Dictionary=v.art;var scale:float=float(v.get("scale",1.0/Grid.ART_SCALE))
		if absf(sz.x*scale-float(art.w))>.001 or absf(sz.y*scale-float(art.h))>.001:issues.append("图片尺寸与游戏绘制比例不一致")
	return {"ok":issues.is_empty(),"issues":issues,"footprint":expected,"view":v}
