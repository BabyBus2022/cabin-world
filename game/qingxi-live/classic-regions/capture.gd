extends SceneTree
func _initialize():
 create_timer(45).timeout.connect(func():quit(2))
 call_deferred("run")
func run():
 set_meta("classic_regions_test",true)
 var image=Image.load_from_file("res://qingxi-live/classic-regions/art/buildings.png")
 print("ATLAS_ALPHA corner=",image.get_pixel(0,0).a," gap=",image.get_pixel(image.get_width()/3,500).a)
 var game=load("res://qingxi-live/classic-regions/main.tscn").instantiate();root.add_child(game);current_scene=game;game.paused_for_capture=true;game.light_preset=1
 for id in game.MAP_NAMES:
  game.build_map(id)
  if id=="village":game.player.position=Vector2(850,650)
  if id=="seedshop" or id=="stockshop":game.player.position=Vector2(640,420)
  if id=="home":game.player.position=Vector2(640,420)
  game.update_camera(true)
  for i in 6:await process_frame
  await RenderingServer.frame_post_draw
  root.get_texture().get_image().save_png(ProjectSettings.globalize_path("res://qingxi-live/classic-regions/reports/"+id+".png"))
 print("CLASSIC_REGIONS_CAPTURE_PASS");quit()
