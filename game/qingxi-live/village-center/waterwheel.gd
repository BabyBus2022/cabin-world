extends Sprite2D
var time:=0.0

func _ready():
 texture=ImageTexture.create_from_image(Image.load_from_file("res://qingxi-live/village-center/art/jp/houses/waterwheel.png"))
 centered=false
 scale=Vector2(2,2)
 texture_filter=CanvasItem.TEXTURE_FILTER_NEAREST
 hframes=12

func _process(delta:float):
 time+=delta
 frame=floori(time*10.0)%hframes

