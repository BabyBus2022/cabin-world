extends RefCounted
## Art overlays. Tilted bridge navigation is aligned separately in qingxi_data.gd.
const DIR="res://qingxi-live/village-center/art/garden-v3/sprites/"
static var cache={}
static func tex(name:String)->Texture2D:
 if not cache.has(name):
  cache[name]=ImageTexture.create_from_image(Image.load_from_file(DIR+name+".png"))
 return cache[name]
static func apron(world,base:Vector2,width_:float,door:Vector2):
 var s=Sprite2D.new();s.texture=tex("paving");s.centered=false
 s.position=base+Vector2(-width_*.46,-2);s.scale=Vector2(width_*.92/128.0,24.0/128.0)
 s.texture_filter=CanvasItem.TEXTURE_FILTER_NEAREST;s.z_index=-6
 var m=ShaderMaterial.new();m.shader=preload("res://qingxi-live/village-center/garden_apron.gdshader")
 m.set_shader_parameter("extent",Vector2(width_*.46,12))
 s.material=m;world.map_layer.add_child(s)
 var path=Sprite2D.new();path.texture=tex("paving");path.centered=false
 path.position=door+Vector2(-24,12);path.scale=Vector2(48.0/128,34.0/128)
 path.texture_filter=CanvasItem.TEXTURE_FILTER_NEAREST;path.z_index=-6
 var pm=ShaderMaterial.new();pm.shader=preload("res://qingxi-live/village-center/garden_apron.gdshader")
 pm.set_shader_parameter("extent",Vector2(24,17));path.material=pm;world.map_layer.add_child(path)
static func bridge_foreground(vertical:bool,stone:bool)->ShaderMaterial:
 var mat=ShaderMaterial.new()
 mat.shader=preload("res://qingxi-live/village-center/bridge_foreground.gdshader")
 mat.set_shader_parameter("vertical",vertical)
 mat.set_shader_parameter("stone",stone)
 return mat

static func bridge(parent:Node2D,center:Vector2,span:Vector2,style:String,vertical:bool,slope:float=0.0):
 if not vertical and style=="stone":
  for side in [-1,1]:
   var ramp=Sprite2D.new();ramp.texture=tex("paving")
   var extent=Vector2(100,span.y*.48)
   var reach=span.x*.5+41.
   var offset=Vector2(side*reach,side*reach*slope-13.)
   var unit=extent/Vector2(ramp.texture.get_size())
   ramp.transform=Transform2D(Vector2(side*unit.x,side*unit.x*slope),Vector2(0,unit.y),center+offset)
   ramp.texture_filter=CanvasItem.TEXTURE_FILTER_NEAREST
   var m=ShaderMaterial.new();m.shader=preload("res://qingxi-live/village-center/bridge_landing.gdshader")
   m.set_shader_parameter("extent",extent/2);m.set_shader_parameter("bank_seed",float(side)*7.)
   m.set_shader_parameter("deck",tex("stone_h"))
   ramp.material=m;parent.add_child(ramp)
 var s=Sprite2D.new();s.texture=tex(style+("_v" if vertical else "_h"))
 # Long enough to land on the path at both banks (the ground keeps the water running underneath).
 var size_=Vector2(span.x+8,span.y+52) if vertical else Vector2(span.x+52,span.y+42)
 s.position=center+(Vector2.ZERO if vertical else Vector2(0,12))
 var factor=size_/Vector2(s.texture.get_size())
 # Shear the deck's ground axis, retaining upright posts and masonry supports.
 s.transform=Transform2D(Vector2(factor.x,factor.x*slope),Vector2(0,factor.y),s.position)
 s.texture_filter=CanvasItem.TEXTURE_FILTER_NEAREST
 parent.add_child(s)
 var holder=Node2D.new()
 var scenery:Node2D=parent.world.scenery
 holder.position=center+Vector2(0,span.y*.5-4)
 scenery.add_child(holder)
 var front=s.duplicate()
 holder.add_child(front)
 front.global_transform=s.global_transform
 front.material=bridge_foreground(vertical,style=="stone")
