extends Node2D

const Lamp=preload("res://qingxi-live/village-center/ranch_hanging_lamp.gd")
# Centres of the glass lenses in the four 150 × 193 frames.
const LENSES=[
 [Vector2(28,46),Vector2(122,46)],
 [Vector2(40,64),Vector2(110,33)],
 [Vector2(29,47),Vector2(122,47)],
 [Vector2(39,36),Vector2(109,65)]
]
var facing=0
var emitters=[]
var world

func mount(host,sprite:Sprite2D):
 world=host
 name="FloodTower"
 sprite.add_child(self)
 for i in 2:
  var lamp=Lamp.new()
  lamp.mount(host,sprite,true)
  emitters.append(lamp)

func face(direction:int):
 facing=posmod(direction,4)
 var sprite=get_parent() as Sprite2D
 sprite.texture=world.placement.cabin_texture("pasture-floodlight",Lamp.VIEWS[facing])
 for i in 2:
  var lens:Vector2=LENSES[facing][i]
  emitters[i].align_glass(lens,Rect2(lens-Vector2(10,5),Vector2(20,10)))

func append_world_lights(lights:Array,tints:Array):
 for emitter in emitters:emitter.append_world_lights(lights,tints)

