extends RefCounted
## Tabletop objects keep their own image scale and logical grid. Only their
## presentation anchor/depth changes when the supporting artwork changes.
const DEFAULTS={"xj-desk-book":"xj-writing_desk","xj-plant-desk":"xj-writing_desk","xj-album":"xj-album-cabinet","xj-phone":"xj-accessory_table","xj-rabbit":"xj-bookshelf","xj-lamp-shelf":"xj-bookshelf","xj-plant-shelf":"xj-bookshelf"}
const OLD={"xj-writing_desk":[580,160,88,25],"xj-album-cabinet":[379,289,96,28],"xj-accessory_table":[614,376,58,20],"xj-bookshelf":[464,48,87,10]}
## Insets relative to the logical footprint; front/back top height and depth
## are measured from the actual sprites, not from the collision box.
const TOP={"xj-writing_desk":[5,8,86,24],"xj-album-cabinet":[4,-30,88,16],"xj-accessory_table":[4,-13,56,18],"xj-bookshelf":[4,-11,88,8]}
static func surface(item:Dictionary)->Rect2:
	var id:String=str(item.get("asset","")).get_slice("--",1) if item.has("asset") else str(item.id)
	if not TOP.has(id):return Rect2()
	var p:Array=TOP[id];var foot:Array=item.foot
	var side:bool=str(item.get("facing","S")) in ["E","W"]
	return Rect2(foot[0]+p[0],foot[1]+p[1],float(foot[2])-2*float(p[0]),float(p[3])+(float(foot[3])-float(foot[2]) if side else 0))
static func anchor(m:Dictionary)->Vector2:return Vector2(m.x+m.w*.5,m.y+m.h)
static func apply(grid,layout:Dictionary,scene:Dictionary,manifest:Dictionary)->void:
	var supports:Dictionary={}
	for item in grid.data().catalog:
		if grid.hidden(layout,item.id):continue
		var rect:=surface(item)
		if rect.size.x<=0 or rect.size.y<=0:continue
		rect.position+=grid.delta(layout,item.id);supports[item.id]=rect
	for item in grid.data().catalog:
		if item.layer!="surface" or grid.hidden(layout,item.id):continue
		var m:Dictionary=scene.modules[item.id];var from:=anchor(m);var target:=from;var parent:=""
		var normal:String=DEFAULTS.get(item.id,"")
		if supports.has(normal):
			var raw:Array=OLD[normal];var old:=Rect2(raw[0],raw[1],raw[2],raw[3]);old.position+=grid.delta(layout,normal)
			# Only migrate old tabletop coordinates while they still belong to
			# that tabletop. A player can move the item onto a different support.
			if old.grow(2).has_point(from):
				var uv:Vector2=(from-old.position)/old.size
				var face:String=grid.facing_of(layout,normal)
				uv=grid.FacingBindings.turn(uv,Vector2.ONE,face)
				var top:Rect2=supports[normal];target=top.position+uv*top.size;parent=normal
		if parent=="":
			for id in supports:
				if supports[id].grow(2).has_point(from):parent=id;break
		if parent=="":continue
		var top:Rect2=supports[parent]
		var half:float=minf(float(m.w)*.5,top.size.x*.5)
		target.x=clampf(target.x,top.position.x+half,top.end.x-half)
		target.y=clampf(target.y,top.position.y+1,top.end.y-1)
		var shift:=target-from;m.x+=shift.x;m.y+=shift.y;m.depth=float(scene.modules[parent].depth)+.1
		m.supportId=parent;m.supportRect=[top.position.x,top.position.y,top.size.x,top.size.y]
		for layer in manifest.layers:
			if str(layer.get("owner",layer.id))==str(item.id):layer.x+=shift.x;layer.y+=shift.y;layer.depth=m.depth
