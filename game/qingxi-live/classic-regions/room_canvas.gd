extends Node2D
var floor_texture:Texture2D
func _ready():
 floor_texture=ImageTexture.create_from_image(Image.load_from_file("res://qingxi-live/classic-regions/art/floor-wood.png"));queue_redraw()
func _draw():
 draw_rect(Rect2(0,0,1280,900),Color("302d36"))
 draw_rect(Rect2(112,90,1056,580),Color("6e472f"))
 draw_rect(Rect2(120,98,1040,110),Color("ddc296"))
 for x in range(120,1160,64):
  for y in range(208,660,64):draw_texture_rect(floor_texture,Rect2(x,y,minf(64,1160-x),minf(64,660-y)),false)
 for y in [98,192,652]:
  draw_rect(Rect2(112,y,1056,8),Color("784b30"));draw_rect(Rect2(112,y,1056,2),Color("cfa16a"))
 for x in [112,1152]:
  draw_rect(Rect2(x,98,16,562),Color("784b30"));draw_rect(Rect2(x,98,3,562),Color("cfa16a"))
 draw_rect(Rect2(608,652,64,10),Color("c8a270"))
