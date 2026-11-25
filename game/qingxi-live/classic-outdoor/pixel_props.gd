extends RefCounted
## Original generated atlas retained. Runtime atlas regions are separate props.
var h
var textures=[]
func _init(host):
 h=host
 var sheet=Image.load_from_file("res://qingxi-live/village01/art/props-tree-style.png")
 var cell=Vector2i(sheet.get_width()/3,sheet.get_height()/2)
 for i in 6:
  var im=sheet.get_region(Rect2i(Vector2i(i%3,i/3)*cell,cell));var low=cell;var high=Vector2i.ZERO
  for y in cell.y:
   for x in cell.x:
    if im.get_pixel(x,y).a>.55:low=low.min(Vector2i(x,y));high=high.max(Vector2i(x,y))
  textures.append(ImageTexture.create_from_image(im.get_region(Rect2i(low,high-low+Vector2i.ONE))))
func place(index:int,p:Vector3,width_:float,footprint:Vector2)->Sprite3D:
 var tex=textures[index];var sprite=h.billboard(tex,p,width_*float(tex.get_height())/tex.get_width())
 sprite.shaded=true;sprite.alpha_scissor_threshold=.55
 if footprint.length()>0:h.box(h,p+Vector3(0,.5,0),Vector3(footprint.x,1,footprint.y),Color.WHITE,true).hide()
 return sprite

