class_name FurnitureState
extends Node2D
## State-driven overlays over original furniture; one controller for all homes.
const BLUE_ATLAS = preload("res://assets/actors/whale-furniture.png")
var scene := ""
var resident_key := ""
var module := {}
var base: Sprite2D
var visual := {}
var clock := 0.0
var care_at := -2.0
var care: Array = []
var person: Character
var wilted := false

static func mount(room: Node2D,id: String,modules: Dictionary,sprites: Dictionary) -> void:
	var profile := {}
	for resident in Residents.people():
		if resident.get("home",{}).get("scene")==id: profile=resident;break
	if profile.is_empty():return
	for m in modules.values():
		if not sprites.has(m.id):continue
		if m.kind=="speaker":continue
		if not m.kind in ["prop","chair","computer","xh-sofa","xh-tank"] and not m.get("art") in ["plant","book"]:continue
		var state := FurnitureState.new()
		state.scene=id
		state.resident_key=profile.key
		state.module=m
		state.visual=profile.home.get("visual",{})
		state.base=sprites[m.id]
		state.position.y=float(m.depth)+.02
		if m.kind=="xh-sofa":state.position.y=float(m.depth)+2
		room.add_child(state)

func _process(delta: float) -> void:
	clock+=delta
	if person==null:
		for p in get_tree().get_nodes_in_group("world_residents"):
			if p.key==resident_key:person=p;break
	if person==null:return
	var items := person._items()
	var transfer: Dictionary=items.transfer if items.get("transfer") is Dictionary else {}
	if module.kind=="prop":
		var item := "phone" if module.art=="phoneOff" else "headphones"
		base.visible=items.get(item,"dock")=="dock" and transfer.get("item")!=item
	elif module.kind=="chair" and "computer" in str(module.id):
		base.visible=not (person.scene_id==scene and not person.is_walking() and (person.stage.get("front")=="chair" or person.stage.get("registered")=="computer"))
	elif module.get("art")=="book":
		base.visible=not (person.scene_id==scene and not person.is_walking() and module.id in person.stage.get("hide",[]))
	if clock-care_at>1:
		care_at=clock
		care=Economy.reading(resident_key).life.care if Economy.people.has(resident_key) else []
	if module.id==visual.get("plant"):
		wilted=care.any(func(line):return "蔫" in line)
		base.visible=not wilted
	if module.kind=="xh-tank" or (module.get("art")=="plant" and visual.get("screen")=="wood"):base.visible=false
	if is_visible_in_tree():queue_redraw()

static func screen(m: Dictionary,style: String,mode: String,time: float) -> Array:
	var out := []
	var blue := style=="blue"
	var x: float=m.x+m.w*(.28 if blue else .23)
	var y: float=m.y+m.h*(.035 if blue else .055)
	var w: float=m.w*(.44 if blue else .6)
	var h: float=m.h*(.27 if blue else .25)
	if blue:x=floorf(x+.5);y=floorf(y+.5);w=floorf(w+.5);h=floorf(h+.5)
	var pixel=func(c,rx,ry,rw,rh):out.append({"kind":"rect","color":c,"rect":[rx,ry,rw,rh],"alpha":1})
	pixel.call(("#252c46" if mode=="off" else "#91aecf") if blue else ("#252a38" if mode=="off" else "#7c9aaf"),x,y,w,h)
	if blue and mode!="off":
		for n in 3:pixel.call("#ce8b8b" if mode=="error" else "#e5eff7",x+4,y+4+n*6,maxf(3,(w-10)*(.8-n*.14)),2)
		if mode=="video":pixel.call("#b7d3d9",x+3,y+3,w-6,h-9);pixel.call("#fff0ca",x+3,y+h-4,(w-6)*fmod(time,12)/12,1)
	elif not blue:
		if mode=="video":
			pixel.call("#b4c7d2",x+3,y+3,w-6,h-10);pixel.call("#52728b",x+3,y+h*.54,w-6,h*.23);pixel.call("#f4d7a3",x+3,y+h-4,(w-6)*fmod(time,12)/12,2)
		elif mode!="off":
			for n in 3:pixel.call("#ce8b8b" if mode=="error" else "#d8e1df",x+5,y+6+n*6,(w-14)*(.4+fmod(time,3)/8 if n==2 and mode=="typing" else .8-n*.1),2)
	return out

func _draw() -> void:
	if person==null:return
	draw_set_transform(Vector2(0,-position.y))
	var m := module
	if m.kind=="computer":
		var computer: Dictionary=person.body.get("computer",{})
		AmbientArt.paint(self,screen(m,str(visual.get("screen","wood")),str(computer.get("screen","off")),clock))
	elif wilted:
		var r: Array=visual.plant_region
		draw_texture_rect_region(AmbientArt.texture("life/"+str(visual.plant_art)+"-draft.png"),Rect2(m.x,m.y,m.w,m.h),Rect2(r[0],r[1],r[2],r[3]))
	elif m.kind=="xh-tank":
		draw_texture_rect_region(BLUE_ATLAS,Rect2(m.x,m.y,m.w,m.h),Rect2(27,57,281,247))
		var glass := Rect2(m.x+m.w*.08,m.y+m.h*.12,m.w*.84,m.h*.49)
		for k in 5:
			var p := fmod(clock*.16+k/5.0,1)
			var bubble := Rect2(floorf(m.x+m.w*(.2+.15*k)+sin(clock+k)*1.5+.5),floorf(m.y+m.h*(.58-p*.43)+.5),1.5,1.5)
			if glass.encloses(bubble):draw_rect(bubble,Color("e0f5ffa0"),false,.6)
		draw_rect(glass.intersection(Rect2(m.x+7+floorf(fmod(clock*3,m.w-28)+.5),m.y+m.h*.15,14,1)),Color("e7f8ff60"))
		if care.any(func(line):return "鱼" in line):
			var out := []
			AmbientArt.cell(out,"life/care-fish-draft.png",0,1,1,[m.x+12,m.y+14,m.w-24,35])
			AmbientArt.paint(self,out)
	elif m.get("art")=="plant" and visual.get("screen")=="wood":
		var atlas: Texture2D=Poses.texture(str(visual.plant_sheet))
		var sway := floorf(sin(clock*.9+m.x*.37)*1.2+.5)/2
		draw_texture_rect_region(atlas,Rect2(m.x,m.y+m.h*.58,m.w,m.h*.42),Rect2(847,389+268*.58,205,268*.42))
		draw_texture_rect_region(atlas,Rect2(m.x+sway,m.y,m.w,m.h*.58),Rect2(847,389,205,268*.58))
	elif m.kind=="xh-sofa":
		var seated := false
		for actor in get_tree().get_nodes_in_group("world_residents"):
			if actor.scene_id==scene and actor.stage.get("seat",false) and Rect2(m.x,m.y,m.w,m.h).has_point(actor._display):seated=true
		if seated:
			for clip in [Rect2(0,.78,1,.22),Rect2(0,.35,.17,.65),Rect2(.83,.35,.17,.65)]:
				var target := Rect2(Vector2(m.x,m.y)+clip.position*Vector2(m.w,m.h),clip.size*Vector2(m.w,m.h))
				draw_texture_rect_region(base.texture,target,Rect2(clip.position*base.texture.get_size(),clip.size*base.texture.get_size()))
