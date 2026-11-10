class_name ScreenLight
extends Node2D
## Canvas screen blend, including overlapping lamps. One captured room frame,
## then all gradients in original order; no additive rings or clipped highlights.
const SHADER = preload("res://entities/screen_light.gdshader")
const MAX_LIGHTS := 64
var bounds := Vector2.ZERO

func _init() -> void:
	material = ShaderMaterial.new()
	material.shader = SHADER

func update_lights(size: Vector2, sources: Array) -> void:
	bounds = size
	assert(sources.size() <= MAX_LIGHTS, "Room exceeds screen-light capacity")
	var geometry := PackedVector4Array()
	var clips := PackedVector4Array()
	var first := PackedColorArray()
	var middle := PackedColorArray()
	var last := PackedColorArray()
	var stops := PackedFloat32Array()
	for i in MAX_LIGHTS:
		var s: Dictionary = sources[i] if i < sources.size() else {}
		geometry.append(s.get("geometry", Vector4.ZERO))
		clips.append(s.get("clip", Vector4.ZERO))
		first.append(s.get("first", Color.TRANSPARENT))
		middle.append(s.get("middle", Color.TRANSPARENT))
		last.append(s.get("last", Color.TRANSPARENT))
		stops.append(s.get("stop", 0.35))
	material.set_shader_parameter("count", sources.size())
	for pair in [["geometry",geometry],["clips",clips],["first_color",first],["middle_color",middle],["last_color",last],["middle_stop",stops]]:
		material.set_shader_parameter(pair[0],pair[1])
	visible = not sources.is_empty()
	queue_redraw()

func _draw() -> void:
	draw_rect(Rect2(Vector2.ZERO,bounds),Color.WHITE)

## Reference drawLighting gradients; time is host epoch milliseconds.
static func lamps(modules: Array, settings: Dictionary, darkness: float, size: Vector2, time: float) -> Array:
	var out := []
	for m in modules:
		if not m.get("light") is Dictionary:continue
		if not Daylight.light_enabled(str(settings.get(m.id,settings.get("lamps","auto"))),darkness):continue
		var x: float=m.x+m.light.x
		var y: float=m.y+m.light.y
		var r: float=m.light.radius
		if m.kind=="ceiling-light":
			var color:=Color(1,240.0/255,214.0/255,0.06+darkness*0.12)
			out.append({"geometry":Vector4(x,y+150,r,10),"clip":Vector4(16,16,size.x-32,size.y-32),"first":color,"middle":Color(color.r,color.g,color.b,0),"last":Color(color.r,color.g,color.b,0),"stop":1.0})
		else:
			var flicker:=1.0+0.05*sin(time/1000*7.1+float(m.x))*sin(time/1000*2.3+float(m.y))
			var strength:=floorf((0.25+darkness*0.4)*flicker*1000+0.5)/1000
			out.append({"geometry":Vector4(x,y,r*flicker,0),"clip":Vector4(x-r*1.1,y-r*1.1,r*2.2,r*2.2),"first":Color(1,199.0/255,113.0/255,strength),"middle":Color(240.0/255,174.0/255,85.0/255,0.12),"last":Color(231.0/255,164.0/255,83.0/255,0),"stop":0.35})
	return out

static func prop(at: Vector2,radius: float,color: Color,strength: float) -> Dictionary:
	return {"geometry":Vector4(at.x,at.y,radius,0),"clip":Vector4(at.x-radius,at.y-radius,radius*2,radius*2),"first":Color(color.r,color.g,color.b,strength),"middle":Color(color.r,color.g,color.b,0),"last":Color(color.r,color.g,color.b,0),"stop":1.0}

static func sample(background: Color,at: Vector2,sources: Array) -> Color:
	var result:=background
	for source in sources:
		var clip: Vector4=source.clip
		if not Rect2(clip.x,clip.y,clip.z,clip.w).has_point(at):continue
		var g: Vector4=source.geometry
		var t:=clampf((at.distance_to(Vector2(g.x,g.y))-g.w)/maxf(0.001,g.z-g.w),0,1)
		var mid: float=source.stop
		var color: Color=source.first.lerp(source.middle,t/mid) if t<=mid else source.middle.lerp(source.last,(t-mid)/(1-mid))
		result=Color(1-(1-result.r)*(1-color.r*color.a),1-(1-result.g)*(1-color.g*color.a),1-(1-result.b)*(1-color.b*color.a),background.a)
	return result
