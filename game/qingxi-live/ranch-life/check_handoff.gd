extends SceneTree
var failures=[]
func _initialize():run.call_deferred()
func check(okay:bool,message:String):
 if not okay:failures.append(message);push_error(message)
func wait_scene(path:String):
 for i in 600:
  await process_frame
  if current_scene!=null and current_scene.get_script().resource_path==path:
   for j in 8:await physics_frame
   return current_scene
 check(false,"Scene transition failed "+path);return null
func run():
 set_meta("center_testing",true)
 set_meta("legacy_split_maps",true)
 change_scene_to_file("res://qingxi-live/village-center/main.tscn")
 var center=await wait_scene("res://qingxi-live/village-center/center.gd")
 center.sim.data.coins=137;center.sim.data.bag.milk=7
 center.travel("ranch")
 check(current_scene==center and center.map_id=="ranch","Original ranch did not open")
 check(center.sim.data.coins==137 and center.sim.data.bag.milk==7,"Ranch lost shared inventory")
 var pens=center.region.pen_cells().duplicate(true)
 center.travel("field")
 var expected=center.region_arrival("field","room_private")
 for step in [["room_private",-1],["home",1]]:
  var portal=center.targets.filter(func(t):return t.kind=="portal" and t.extra==step[0])
  check(portal.size()==1,"Missing cottage threshold "+step[0])
  if portal.size()!=1:quit(1);return
  var offset=Vector2(0,step[1]*3)
  center.portal_grace=0
  center.player.position=portal[0].pos+offset
  center.check_portals(portal[0].pos-offset)
  await process_frame
  await process_frame
  if step[0]=="room_private":
   check(center.map_id=="room_private","Door did not lead into farm cottage")
   check(center.sim.data.coins==137 and center.sim.data.bag.milk==7,"Cottage lost shared inventory")
   center.sim.data.bag.wool=9
 check(center.map_id=="field" and center.player.position.distance_to(expected)<1,"Cottage exit missed the farm doorstep")
 check(center.sim.data.bag.wool==9,"Cottage handoff lost inventory")
 if "--picture" in OS.get_cmdline_user_args():
  center.player.position=Vector2(1190,986);center.camera.zoom=Vector2(.52,.52)
  center.update_camera(true)
  await create_timer(3.5).timeout
  await RenderingServer.frame_post_draw
  root.get_texture().get_image().save_png(ProjectSettings.globalize_path("res://qingxi-live/.test-appdata/farm-cottage-restored.png"))
 center.travel("ranch")
 check(center.region.pen_cells()==pens,"Original pasture layout changed after the trip")
 print("RANCH_HOME_HANDOFF ","PASS" if failures.is_empty() else "FAIL"," ",JSON.stringify(failures))
 quit(0 if failures.is_empty() else 1)
