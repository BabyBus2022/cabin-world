extends RefCounted
const DIRECTORY="res://qingxi-live/village-center/art/pond-shore/"
static var textures={}
static func paint(canvas:CanvasItem,kind:String,at:Vector2,size:float,tint:Color):
	if not textures.has(kind):
		var image=Image.new()
		if image.load_png_from_buffer(FileAccess.get_file_as_bytes(DIRECTORY+kind+".png"))!=OK:return
		textures[kind]=ImageTexture.create_from_image(image)
	var tex:Texture2D=textures[kind]
	var extent=tex.get_size()*size
	canvas.draw_texture_rect(tex,Rect2((at-Vector2(extent.x*.5,extent.y*.8)).round(),extent),false,tint)
static func ring(canvas:CanvasItem,at:Vector2,radius:float,phase:float,tint:Color):
	var line=PackedVector2Array()
	for span in [Vector2(.08,2.63),Vector2(3.45,5.92)]:
		line.clear()
		for j in 14:
			var a=lerpf(span.x,span.y,j/13.0)
			line.append((at+Vector2(cos(a),sin(a)*.35)*radius).round())
		canvas.draw_polyline(line,Color(.76,.91,.82,(1.-phase)*.42)*tint,1.6)

