extends SceneTree
func _initialize():run.call_deferred()
func shot(world,name_:String):
 for i in 4:await process_frame
 await RenderingServer.frame_post_draw
 world.get_viewport().get_texture().get_image().save_png("res://qingxi-live/ranch-life/reports/"+name_+".png")
func run():
 set_meta("center_testing",true)
 change_scene_to_file("res://qingxi-live/ranch-life/main.tscn")
 for i in 12:await physics_frame
 var world=current_scene;world.set_physics_process(false);world.hud_layer.hide()
 world.player.position=Vector3(1,.02,-5);world.update_view(1);world.hour=9;world.apply_sky()
 await shot(world,"barn-exterior")
 var exterior_camera:Transform3D=world.camera.global_transform
 world.inspection=true;world.update_view(1)
 world.camera.global_transform=exterior_camera
 await shot(world,"barn-cutaway-aligned")
 world.inspection=false
 world.player.position=Vector3(1,.02,-11);world.update_view(1)
 await shot(world,"barn-day-interior")
 world.player.position=Vector3(1,.02,17);world.update_view(1);world.build_mode=true;world.hud_layer.show();world._physics_process(.016)
 await shot(world,"fence-controls")
 print("RANCH_VISUAL_CAPTURE PASS");quit()
