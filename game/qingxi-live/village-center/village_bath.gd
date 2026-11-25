extends RefCounted

# Walkable floor and fixtures use the same coordinates as the 640-wide art layout.
const SCALE=1.5
const BOUNDS=Rect2(0,0,960,640)
const EXIT=Vector2(320,397)*SCALE
const ENTRY=Vector2(320,363)*SCALE
const FIXTURES=[
 Rect2(36,49,465,180),Rect2(190,13,69,39),Rect2(541,8,95,235),
 Rect2(5,256,204,39),Rect2(264,256,108,39),Rect2(426,256,210,39),
 Rect2(18,277,140,72),Rect2(274,281,91,53),Rect2(478,277,137,72),
 Rect2(190,347,70,25),Rect2(379,347,69,25),Rect2(169,297,30,26),Rect2(433,297,29,26)
]

# Lamp centres in the reference artwork, before its 1.5x world scale.
const LAMPS=[Vector2(126,23),Vector2(240,23),Vector2(382,23),Vector2(495,23),
 Vector2(541,49),Vector2(541,115),Vector2(541,181),Vector2(20,105),
 Vector2(208,220),Vector2(353,220),Vector2(278,396),Vector2(360,396)]
static func lights(night:float)->Array:
 var sources=[];var tints=[]
 for point in LAMPS:
  var bulb:Vector2=point*SCALE
  sources.append(Vector4(bulb.x,bulb.y,130.,lerpf(.17,.7,night)))
  tints.append(Vector4(1.,.83,.54,.75))
 return [sources,tints]

static func blocks(p:Vector2)->bool:
 var q=p/SCALE
 if not Rect2(18,38,604,351).has_point(q) and not Rect2(289,375,62,30).has_point(q):return true
 for fixture in FIXTURES:
  if fixture.grow(2).has_point(q):return true
 return false

static func build(world,arrival:Vector2):
 var interior=Sprite2D.new()
 interior.texture=preload("res://assets/baked/world-onsen.ground.png")
 interior.centered=false
 interior.scale=BOUNDS.size/interior.texture.get_size()
 interior.texture_filter=CanvasItem.TEXTURE_FILTER_NEAREST
 interior.z_index=-8
 var surface=ShaderMaterial.new()
 surface.shader=preload("res://qingxi-live/village-center/bath_surface.gdshader")
 interior.material=surface
 world.map_layer.add_child(interior)
 world.add_target("portal",EXIT,"走出暖汤屋","village")
 world.add_target("furniture",Vector2(287,237)*SCALE,"池边 · 泡足汤","warm_soak")
 world.add_target("furniture",Vector2(220,377)*SCALE,"木长凳 · 休息","rest")
 world.add_target("furniture",Vector2(415,377)*SCALE,"木长凳 · 休息","rest")
 world.make_actor()
 world.player.position=arrival if arrival!=Vector2.ZERO and not blocks(arrival) else ENTRY
 world.show_idle()
 world.update_camera(true)
 world.set_light(world.sky_value())
 world.update_hud()
 world.queue_redraw()
