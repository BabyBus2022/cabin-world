extends SceneTree
var failures=[]
var world
func _initialize():run.call_deferred()
func check(ok:bool,reason:String):
 if not ok:failures.append(reason);push_error(reason)
func find_pond_site()->Rect2:
 for y in range(4,26):
  for x in range(4,39):
   var r=Rect2(x*64,y*64,192,128)
   if world.water_error(r)=="":return r
 return Rect2()
func run():
 change_scene_to_file("res://qingxi-live/village-center/flat-build/main.tscn")
 await process_frame;await process_frame
 world=current_scene
 check(world.map_id=="field" and world.build_mode,"trial starts at farm worksite")
 var origin=world.player.position-Vector2(96,145)
 var cottage=world.cottage
 for y in 2:
  for x in 3:
   check(cottage.change("floor",origin+Vector2(x*64+32,y*64+32),false)=="ok","lay wooden floor")
 for x in 3:
  for dy in [0,128]:
   var tool="door" if x==1 and dy==128 else "wall"
   check(cottage.change(tool,origin+Vector2(x*64+32,dy),false)=="ok","build perimeter")
 for y in 2:
  for dx in [0,192]:
   check(cottage.change("wall",origin+Vector2(dx,y*64+32),false)=="ok","build side wall")
 check(cottage.roofs.size()==1,"complete cottage gains roof")
 var door=origin+Vector2(96,128)
 check(not world.blocked(door) and world.blocked(origin+Vector2(32,128)),"door passage and wall collision")
 world.toggle_build()
 world.player.position=door+Vector2(0,12)
 for i in 8:world.move_actor(Vector2(0,-3))
 cottage.follow()
 check(world.player.position.y<door.y and cottage.inside==cottage.key(cottage.cell_of(world.player.position)),"walk into cottage")
 if "--picture" in OS.get_cmdline_user_args():
  world.player.position=door+Vector2(0,42);cottage.follow()
  world.update_camera(true);world.ui.refresh(.2)
  await create_timer(.8).timeout
  await RenderingServer.frame_post_draw
  root.get_texture().get_image().save_png(ProjectSettings.globalize_path("res://qingxi-live/.test-appdata/built-house.png"))
 check(cottage.change("wall",origin+Vector2(32,0),true)=="ok" and cottage.roofs.is_empty(),"opening wall removes roof")
 world.travel("pond")
 check(world.build_tools()[0][0]=="water","pond dig tool")
 var natural=world.sim.data.pond.duplicate(true)
 var r=find_pond_site();check(r.has_area(),"fish pond has buildable land")
 if r.has_area():
  check(world.change_water(r)=="ok" and world.waters.size()==1,"dig a pond")
  var pond=world.waters.values()[0]
  check(world.blocked(r.get_center()) and not world.blocked(pond.interaction),"swimmable surface separated from accessible bank")
  world.player.position=pond.interaction
  world.action_target=world.targets.filter(func(t):return t.kind=="built_pond")[0];world.interact();world.interact()
  check(pond.stock.count>0 and pond.stock.feed>0 and world.sim.data.pond==natural,"stock and feed pond independently")
  check(world.fill_water(r.get_center())!="ok","fish stay safe during demolition")
  world.sim.advance_farm(world.sim.FISH_SECONDS);pond.tick(.1)
  var before=int(world.sim.data.bag.fish)
  world.interact()
  check(world.sim.data.bag.fish>before and pond.stock.count==0,"harvest own fish")
  world.travel("field");check(world.cottage.plan.floors.size()==6,"return to saved cottage")
  world.travel("pond");check(world.waters.size()==1,"return to dug pond")
  check(world.fill_water(r.get_center())=="ok" and not world.blocked(r.get_center()),"refill empty pond")
 world.travel("ranch")
 var ranch_pool=find_pond_site();check(ranch_pool.has_area(),"pasture has diggable land")
 if ranch_pool.has_area():
  check(world.change_water(ranch_pool)=="ok","pasture watering hole")
  var c=world.region.cell_of(ranch_pool.get_center())
  check(world.region.cell_water(c) and world.blocked(ranch_pool.get_center()),"enclosure sees dug water")
  check(world.fill_water(ranch_pool.get_center())=="ok" and not world.region.cell_water(c),"reclaimed pasture returns to dry ground")
 var path="user://flat-build-check.json"
 check(world.sim.save_to(path),"save trial snapshot")
 var restored=world.PastureState.new();check(restored.load_from(path) and restored.data.layout.built_cottage.floors.size()==6,"reload trial snapshot")
 print("FLAT_BUILD ", "PASS" if failures.is_empty() else "FAIL"," ",JSON.stringify(failures))
 quit(0 if failures.is_empty() else 1)

