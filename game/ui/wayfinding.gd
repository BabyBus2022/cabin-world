class_name Wayfinding
extends RefCounted
## Presentation only. Read the same resolved exits used by resident navigation.
static var font: SystemFont

static func placement(scene: String, door: Dictionary, bounds: Vector2) -> Dictionary:
	var p := Vector2(door.x, door.y)
	var distances := [p.x, bounds.x-p.x, p.y, bounds.y-p.y]
	var edge := distances.find(distances.min())
	# The shop's bathhouse door is internal to the north wall, not the east edge.
	if scene == "qianxia-shop" and door.to == "world-onsen": edge = 2
	var directions := [Vector2.LEFT,Vector2.RIGHT,Vector2.UP,Vector2.DOWN]
	var offsets := [Vector2(46,-22),Vector2(-46,10),Vector2(54,20),Vector2(54,-20)]
	var center: Vector2 = p+offsets[edge]*(bounds.x/960.0)
	center = center.clamp(Vector2(43,15)*(bounds.x/960.0),bounds-Vector2(43,15)*(bounds.x/960.0))
	return {"center":center,"direction":directions[edge],"exit":p,"target":door.to}

static func draw(c: CanvasItem, scene: String, bounds: Vector2) -> void:
	if font == null:
		font = SystemFont.new()
		font.font_names = PackedStringArray(["Microsoft YaHei","SimHei"])
	for door in WorldData.scenes[scene].get("exits",[]):
		if not WorldData.scenes.has(door.to): continue
		var spec := placement(scene,door,bounds)
		var scale_of := bounds.x/960.0
		var pos: Vector2 = spec.center-Vector2(40,11)*scale_of
		c.draw_set_transform(pos,0,Vector2.ONE*scale_of)
		# Compact indigo enamel on a thin cedar mount, sized consistently across maps.
		c.draw_rect(Rect2(1,2,80,22),Color(0,0,0,.22))
		c.draw_rect(Rect2(0,0,80,22),Hud.WOOD_D)
		c.draw_rect(Rect2(1,1,78,20),Hud.WOOD_H)
		c.draw_rect(Rect2(2,2,76,18),Color("29394e"))
		c.draw_line(Vector2(3,3),Vector2(77,3),Color("536276"))
		c.draw_rect(Rect2(4,10,1,2),Hud.GOLD)
		c.draw_rect(Rect2(75,10,1,2),Hud.GOLD)
		var icon: Array = Hud.ICONS.get(door.to,Hud.ICONS["qianxia-park"])
		for y in 8:
			for x in 8:
				var key: String = icon[0][y][x]
				if key != ".": c.draw_rect(Rect2(Vector2(8+x*1.25,6+y*1.25),Vector2.ONE*1.25),Color(icon[1][key]))
		var title: String = Hud.TAB_NAMES.get(door.to,WorldData.scenes[door.to].get("name","出口"))
		c.draw_string(font,Vector2(21,14.5),title,HORIZONTAL_ALIGNMENT_CENTER,43,9,Hud.PAPER_H)
		var direction: Vector2 = spec.direction
		var a := Vector2(69,11)
		var side := direction.orthogonal()
		c.draw_line(a-direction*3,a+direction*3,Hud.PAPER_D,1)
		c.draw_polyline(PackedVector2Array([a-side*3,a+direction*3,a+side*3]),Hud.PAPER_D,1)
		c.draw_set_transform(Vector2.ZERO)
