extends Node2D

# Coordinates in the trimmed 84 x 184 sprite, measured at the incandescent coil.
const FILAMENT=Vector2(65.28,73.97)
const VIEWS=["S","F","W","N"]
const OFFSETS=[0.,-28.,-56.,-28.]
const COILS=[FILAMENT,Vector2(56.28,91.97),Vector2(18.72,73.97),Vector2(28.28,60.97)]
var facing=0
var original_position:Vector2
const WARM_WHITE=Color(1.,.89,.71)
static var falloff:Texture2D
static var emission:CanvasItemMaterial
var world
var light=PointLight2D.new()
var spill=Sprite2D.new()
var glass=Sprite2D.new()
var previous=-1.
var flood=false

func mount(host,sprite:Sprite2D,is_flood:=false):
 world=host
 flood=is_flood
 name="FloodFilament" if flood else "Filament"
 sprite.add_child(self)
 original_position=sprite.position
 position=sprite.get_rect().position+FILAMENT
 if not falloff:
  # Shared downward-weighted falloff. Its maximum is the texel at the filament.
  var image=Image.create_empty(257,257,false,Image.FORMAT_RGBA8)
  for y in 257:
   for x in 257:
    var offset=Vector2(x-128,y-128)/128.
    var radius=offset.length()
    var below=smoothstep(-.55,.34,offset.y/maxf(.008,radius))
    var attenuation=pow(maxf(0.,1.-radius*radius),2.)/(1.+4.6*radius*radius)
    var value=attenuation*lerpf(1.,.12+.88*below,smoothstep(.01,.31,radius))
    image.set_pixel(x,y,Color(value,value,value,1.))
  falloff=ImageTexture.create_from_image(image)
  emission=CanvasItemMaterial.new()
  emission.blend_mode=CanvasItemMaterial.BLEND_MODE_ADD
  emission.light_mode=CanvasItemMaterial.LIGHT_MODE_UNSHADED
 light.texture=falloff
 light.texture_scale=6.5 if flood else 3.75
 light.color=WARM_WHITE
 add_child(light)
 # Terrain uses unshaded canvas shaders, so it also receives the same incident light here.
 spill.texture=falloff
 spill.texture_filter=CanvasItem.TEXTURE_FILTER_LINEAR
 spill.material=emission
 spill.scale=Vector2.ONE*light.texture_scale
 spill.show_behind_parent=true
 add_child(spill)
 # Relight just the glass using its own alpha, preserving the enamel shade and socket.
 var section=AtlasTexture.new()
 section.atlas=sprite.texture
 section.region=Rect2(55,65,20,20)
 glass.texture=section
 glass.position=section.region.get_center()-FILAMENT
 glass.material=emission
 add_child(glass)
 update_light()

func face(direction:int):
 facing=posmod(direction,4)
 var sprite=get_parent() as Sprite2D
 sprite.texture=world.placement.cabin_texture("ranch-incandescent",VIEWS[facing])
 sprite.position=original_position+Vector2(OFFSETS[facing]*sprite.scale.x,0)
 align_glass(COILS[facing],Rect2((COILS[facing]-Vector2(10,9)).round(),Vector2(20,20)))

func align_glass(pixel:Vector2,region:Rect2):
 var sprite=get_parent() as Sprite2D
 position=sprite.get_rect().position+pixel
 var section=glass.texture as AtlasTexture
 section.atlas=sprite.texture
 section.region=region
 glass.position=region.get_center()-pixel

func append_world_lights(lights:Array,tints:Array):
 if not is_visible_in_tree() or not light.enabled:return
 var bulb=global_position
 lights.append(Vector4(bulb.x,bulb.y,960. if flood else 360.,previous*(.79 if flood else 1.)))
 tints.append(Vector4(1.,.91,.76,.24 if flood else 1.))

func update_light():
 var strength=smoothstep(.08,.82,world.night_level)
 if is_equal_approx(previous,strength):return
 previous=strength
 visible=strength>.001
 light.enabled=visible
 light.energy=strength*(.64 if flood else 1.25)
 spill.self_modulate=Color(1.,.86,.66,strength*(.055 if flood else .19))
 glass.self_modulate=Color(1.,.96,.81,strength*(.75 if flood else 1.85))

func _process(_dt):update_light()

