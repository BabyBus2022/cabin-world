extends Node2D
## Baked ground for 清溪村 (village-center/tools/bake_ground.py): grass, earth roads,
## creek, canal, bridges, plaza paving and building footings in one 2400x1680
## texel image drawn at 2 world px per texel. The water highlights cycle on top.
var data
var world
var frames=[]
var water
var clock=0.0
var frame=0
## Folder with ground.png / water_0..3.png (village or an outer map in art/regions/).
var folder="res://qingxi-live/village-center/art/jp/"
func setup(host):
 world=host;data=world.qingxi;z_index=-8
 if world.has_meta("route_geometry"):
  rails(bridge_list());set_process(false);return
 var ground=Sprite2D.new();ground.centered=false;ground.scale=Vector2(2,2);ground.texture_filter=CanvasItem.TEXTURE_FILTER_NEAREST
 ground.texture=load_tex("ground");add_child(ground)
 var material_=ShaderMaterial.new();material_.shader=preload("res://qingxi-live/village-center/garden_ground.gdshader")
 for name in ["grass","earth","paving","water"]:
  material_.set_shader_parameter(name+"_art",preload("res://qingxi-live/village-center/garden_details.gd").tex(name))
 ground.material=material_
 material_.set_shader_parameter("village",folder=="res://qingxi-live/village-center/art/jp/")
 water=Sprite2D.new();water.centered=false;water.scale=Vector2(2,2);water.texture_filter=CanvasItem.TEXTURE_FILTER_NEAREST
 if folder=="res://qingxi-live/village-center/art/jp/":
  water.texture=ImageTexture.create_from_image(Image.load_from_file("res://qingxi-live/village-center/art/refined/river-flow.png"))
  var river=ShaderMaterial.new()
  river.shader=preload("res://qingxi-live/village-center/village_river.gdshader")
  river.set_shader_parameter("gravel",ImageTexture.create_from_image(Image.load_from_file("res://qingxi-live/village-center/flat-build/pond-art/streambed.png")))
  river.set_shader_parameter("stones",ImageTexture.create_from_image(Image.load_from_file("res://qingxi-live/village-center/flat-build/pond-art/moss.png")))
  water.material=river
  set_process(false)
 else:
  for i in 4:frames.append(load_tex("water_%d"%i))
  water.texture=frames[0];water.modulate.a=.48
 add_child(water)
 var details=preload("res://qingxi-live/village-center/garden_details.gd")
 var bridge_rects=[];var bridge_shifts=[]
 if folder=="res://qingxi-live/village-center/art/jp/":
  for b in world.qingxi.bridges:
   details.bridge(self,b.pos,b.size,str(b.style),bool(b.vertical),float(b.get("slope",0.0)))
   var r=Rect2((b.pos-b.size/2)/2,b.size/2).grow(6)
   bridge_rects.append(Vector4(r.position.x,r.position.y,r.size.x,r.size.y))
   var line=world.qingxi.canal if str(b.id).ends_with("_canal") else world.qingxi.creek
   var nearest=INF;var tangent=Vector2.DOWN
   for i in range(line.size()-1):
    var dist=b.pos.distance_to(Geometry2D.get_closest_point_to_segment(b.pos,line[i],line[i+1]))
    if dist<nearest:nearest=dist;tangent=(line[i+1]-line[i]).normalized()
   bridge_shifts.append(tangent*(maxf(r.size.x,r.size.y)*.7+18))
 elif folder.ends_with("/farm/"):
  details.bridge(self,Vector2(2210,992),Vector2(160,104),"wood",false)
  bridge_rects.append(Vector4(1061,466,88,60));bridge_shifts.append(Vector2(-14,70))
 elif folder.ends_with("/pond/"):
  details.bridge(self,Vector2(515,1200),Vector2(150,100),"wood",false)
  details.bridge(self,Vector2(1152,988),Vector2(64,176),"wood",true)
  bridge_rects.append(Vector4(216,571,83,58));bridge_shifts.append(Vector2(-34,65))
 # The ground no longer paints bridges, so nothing needs patching under the art.
 material_.set_shader_parameter("bridge_count",0)
 rails(bridge_list())
 while bridge_rects.size()<5:bridge_rects.append(Vector4.ZERO);bridge_shifts.append(Vector2.ZERO)
 material_.set_shader_parameter("bridge_bounds",bridge_rects)
 material_.set_shader_parameter("bridge_sample_shift",PackedVector2Array(bridge_shifts))
## Every bridge in this map: [centre, span, vertical].
func bridge_list()->Array:
 var out=[]
 if folder=="res://qingxi-live/village-center/art/jp/":
  for b in world.qingxi.bridges:out.append([b.pos,b.size,bool(b.vertical)])
 elif folder.ends_with("/farm/"):out.append([Vector2(2210,992),Vector2(160,104),false])
 elif folder.ends_with("/pond/"):out.append([Vector2(515,1200),Vector2(150,100),false]);out.append([Vector2(1152,988),Vector2(64,176),true])
 return out
## Railings are solid along the whole length of the bridge art, banks included.
func rails(list:Array):
 for b in list:
  var c:Vector2=b[0];var s:Vector2=b[1]
  if b[2]:
   var half=s.y/2+26
   world.solids.append(Rect2(c.x-s.x/2-2,c.y-half,10,half*2));world.solids.append(Rect2(c.x+s.x/2-8,c.y-half,10,half*2))
  else:
   var half=s.x/2+26
   world.solids.append(Rect2(c.x-half,c.y-s.y/2-4,half*2,10));world.solids.append(Rect2(c.x-half,c.y+s.y/2-6,half*2,10))
func load_tex(name:String)->Texture2D:
 return ImageTexture.create_from_image(Image.load_from_file(folder+name+".png"))
func _process(dt):
 if frames.is_empty():return
 clock+=dt
 if clock>.28:clock=0;frame=(frame+1)%frames.size();water.texture=frames[frame]
