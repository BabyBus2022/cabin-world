extends "res://qingxi-live/classic-outdoor/village.gd"
var orbit=0.0
func _ready():
 super._ready()
 var house=buildings.seed
 house.roof.queue_free();house.roof=preload("res://qingxi-live/classic-outdoor/crafted_house.gd").new(self).build(house.root,house.spec)
 set_style(0);player.position=Vector3(-10,.04,-2);player.velocity=Vector3.ZERO;set_view("player")
 style_button.hide();scene_title="小屋世界 · 立体像素街角"
 say("J / K 转动镜头查看房屋体积 · WASD 行走 · 直接走门进屋 · E 买卖")
 DisplayServer.window_set_title("小屋世界 · 立体像素街角 · 美术重做")
func update_view(dt:float):
 super.update_view(dt)
 if not is_instance_valid(camera):return
 if not in_house:
  var focus=player.position+Vector3(0,1.6,-3.2);camera.size=17.5
  var arm=Vector3(0,17,19).rotated(Vector3.UP,orbit);camera.position=focus+arm;camera.look_at(focus)
func _unhandled_key_input(e:InputEvent):
 if e.is_pressed() and e.keycode==KEY_J:orbit-=PI/8;update_view(1);return
 if e.is_pressed() and e.keycode==KEY_K:orbit+=PI/8;update_view(1);return
 super._unhandled_key_input(e)

