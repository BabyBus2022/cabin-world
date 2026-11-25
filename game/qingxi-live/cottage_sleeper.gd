extends Node2D
const Stay = preload("res://qingxi-live/cottage_lodging.gd")
var path: String
var bed_id: String
var width: float
var height: float
var cover: Texture2D
var actor := ""
var elapsed := 0.0
static var owner_frames: Array = []

func setup(profile: String, id: String, texture: Texture2D, span: float):
	path=profile
	bed_id=id
	cover=texture
	width=span
	height=width*texture.get_height()/texture.get_width()

func _process(dt):
	var who = Stay.data(path).get("guests",{}).find_key(bed_id)
	var next := "" if who == null else str(who)
	if next=="owner":
		var host=get_tree().get_meta("qingxi_world_host",false)
		if host and host.spectator:next=""
	if actor != next:
		actor=next
		elapsed=0
		queue_redraw()
	elif actor != "":
		elapsed+=dt
		queue_redraw()

func _draw():
	if actor == "" or not cover: return
	var tex: Texture2D
	var region: Rect2
	if actor == "owner":
		if owner_frames.is_empty():
			for i in 16:
				var img:=Image.new()
				if img.load_png_from_buffer(FileAccess.get_file_as_bytes("res://assets/world/vads-player/sleeping/%03d.png"%i))==OK:
					var atlas:=AtlasTexture.new()
					atlas.atlas=ImageTexture.create_from_image(img)
					atlas.region=Rect2(img.get_used_rect())
					owner_frames.append(atlas)
		if owner_frames.is_empty():return
		tex=owner_frames[int(elapsed/0.127)%owner_frames.size()]
		region=Rect2(Vector2.ZERO,tex.get_size())
	elif actor == "xiaojingyu":
		tex=preload("res://assets/seaside/actors/sleep/sleeping.png")
		region=Rect2(Vector2.ZERO,tex.get_size())
	else:
		tex=Poses.sheet("sleeping")
		region=Poses.region("sleeping")
	var span:=width*(0.62 if actor=="xiaojingyu" else 0.44)
	var body:=Vector2(span,span*region.size.y/region.size.x)
	var at:=Vector2(-body.x/2,-height*0.75+sin(elapsed*1.5)*0.5)
	draw_texture_rect_region(tex,Rect2(at,body),region)
	var source_size:=cover.get_size()
	draw_texture_rect_region(cover,Rect2(-width/2,-height*0.49,width,height*0.49),Rect2(0,source_size.y*.51,source_size.x,source_size.y*.49))
