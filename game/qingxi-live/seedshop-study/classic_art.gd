extends RefCounted
## Existing CabinWorld artwork and its orientation geometry stay together.
const ROOT="res://qingxi-live/seedshop-study/art/classic/"
var catalog:Dictionary
var images={}
var textures={}

func _init():
 catalog=JSON.parse_string(FileAccess.get_file_as_string(ROOT+"furniture.json"))
 catalog.merge(JSON.parse_string(FileAccess.get_file_as_string("res://qingxi-live/seedshop-study/art/specialized/furniture.json")),true)
 catalog.merge(JSON.parse_string(FileAccess.get_file_as_string("res://qingxi-live/seedshop-study/art/seedshop-collection/furniture.json")),true)

func texture(file:String,region:Rect2i=Rect2i())->Texture2D:
 var key=file+str(region)
 if not textures.has(key):
  if not images.has(file):images[file]=Image.load_from_file(ROOT+file)
  var im:Image=images[file]
  if region.has_area():im=im.get_region(region)
  textures[key]=ImageTexture.create_from_image(im)
 return textures[key]

func sprite(file:String,parent:Node,p:Vector2,region:Rect2i=Rect2i(),factor:float=.5)->Sprite2D:
 var s=Sprite2D.new();s.texture=texture(file,region);s.centered=false;s.position=p;s.scale=Vector2.ONE*factor;parent.add_child(s);return s

func furniture(id:String,face:String,p:Vector2,parent:Node)->Dictionary:
 var def:Dictionary=catalog[id]
 var v:Dictionary=def.facings[face]
 var holder=Node2D.new();holder.position=p+Vector2(0,v.depth);parent.add_child(holder)
 var s=sprite(v.file,holder,Vector2(v.art.x,v.art.y-v.depth))
 var c:Dictionary=v.collision
 return {"node":holder,"sprite":s,"origin":p,"view":v,"collision":Rect2(p+Vector2(c.x,c.y),Vector2(c.w,c.h))}
