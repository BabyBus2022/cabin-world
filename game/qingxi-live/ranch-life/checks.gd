extends RefCounted
var failures=[]
func check(value:bool,message:String):
 if not value:failures.append(message);push_error(message)
func walk(world,goal:Vector2,limit=2400)->bool:
 for i in limit:
  var at=Vector2(world.player.position.x,world.player.position.z)
  if at.distance_to(goal)<.18:world.test_motion=Vector2.ZERO;return true
  world.test_motion=(goal-at).normalized()
  await world.get_tree().physics_frame
 world.test_motion=Vector2.ZERO;return false
func shot(world,name_:String):
 if DisplayServer.get_name()=="headless":return
 world.hud_layer.hide()
 for i in 3:await world.get_tree().process_frame
 await RenderingServer.frame_post_draw
 world.get_viewport().get_texture().get_image().save_png("res://qingxi-live/ranch-life/reports/"+name_+".png")
 world.hud_layer.show()
func run(world):
 Engine.physics_ticks_per_second=240;Engine.time_scale=4
 for i in 10:await world.get_tree().physics_frame
 print("RANCH_CHECK ready")
 check(world.herd.size()==6,"Initial shared herd not restored")
 check(world.nav.graph.get_point_count()>1000,"Expanded ranch navigation missing")
 var ids=[]
 for a in world.herd.values():ids.append(a.body.get_instance_id())
 check(await walk(world,Vector2(1,-5)),"Approach through exterior gate blocked")
 print("RANCH_CHECK approached ",world.player.position)
 await shot(world,"barn-exterior")
 check(await walk(world,Vector2(1,-11)),"Cannot walk through actual barn door")
 check(world.cutaway and not world.roof_group.visible,"Barn does not open with player inside")
 check(world.player.is_on_floor(),"Barn floor has a gap")
 print("RANCH_CHECK inside")
 world.hour=21;world.apply_sky()
 for i in 4400:
  await world.get_tree().physics_frame
  if world.herd.values().all(func(a):return a.mode=="睡觉"):break
 for a in world.herd.values():
  check(a.mode=="睡觉" and world.REST_AREA.has_point(world.animal_point(a)),"Animal failed to reach the shared straw area: "+str(a.body.position))
  check(a.distance>4,"Animal was teleported to the straw area instead of walking")
 print("RANCH_CHECK night settled")
 await shot(world,"barn-night-interior")
 world.hour=9;world.apply_sky()
 for i in 3300:
  await world.get_tree().physics_frame
  if world.herd.values().all(func(a):return not world.BARN.has_point(world.animal_point(a))):break
 for a in world.herd.values():check(not world.BARN.has_point(Vector2(a.body.position.x,a.body.position.z)),"Animal did not leave barn in daylight")
 print("RANCH_CHECK day resumed")
 var before_ids=[]
 for a in world.herd.values():before_ids.append(a.body.get_instance_id())
 check(ids==before_ids,"Day/night replaced animal instances")
 var edge=world.nav.edge_key(Vector2i(-12,2),Vector2i(-11,2))
 check(world.edit_edge(edge,"fence")=="已安装围栏","Individual fence placement failed")
 check(not world.nav.clear_segment(Vector2(-23,3),Vector2(-23,5)),"Fence missing from pathfinding")
 check(world.fence_nodes.has(edge) and world.fence_nodes[edge].find_children("*","StaticBody3D",true,false).size()==1,"Fence missing physical collision")
 check(world.edit_edge(edge,"")=="已拆除这一段","Individual fence removal failed")
 check(world.nav.clear_segment(Vector2(-23,3),Vector2(-23,5)),"Removed fence still blocks pathfinding")
 check(world.edit_edge(edge,"open")=="通门已打开","Gate installation failed")
 check(world.edit_edge(edge,"closed")=="通门已关闭","Gate closing failed")
 check(world.edit_edge(edge,"open")=="通门已打开","Gate reopening failed")
 world.save_progress()
 var coins=world.sim.data.coins;check(world.sim.save_to("user://ranch-life-verification.json"),"Verification save failed")
 var loaded=world.State.new();check(loaded.load_from("user://ranch-life-verification.json"),"Save reload failed")
 check(loaded.data.layout.ranch_edges_v1==world.edges,"Edge layout failed to persist")
 check(loaded.data.coins==coins and loaded.livestock.data.herd.size()==6,"Shared economy or herd lost")
 world.sim.livestock.grow_all();world.sim.livestock.produce_all()
 var sheep=world.sim.livestock.members("sheep")[0];var wool=world.sim.data.bag.wool
 world.sim.animal_action(sheep.id);check(sheep.shorn and world.sim.data.bag.wool==wool+2,"Shearing regression")
 var cow=world.sim.livestock.members("cow")[0];var milk=world.sim.data.bag.milk
 world.sim.animal_action(cow.id);check(world.sim.data.bag.milk==milk+2,"Milking regression")
 world.sim.data.bag.young_pig=1;world.sim.release_young("pig");world.refresh_herd();check(world.herd.size()==7,"Bag animal release missing")
 check(await walk(world,Vector2(1,-5)),"Barn exit blocked")
 check(await walk(world,Vector2(1,20)),"Exterior feeding yard blocked")
 await shot(world,"pasture-day")
 check(world.stations.size()==2,"Expected one shared feed trough and one shared water trough")
 var hay=int(world.sim.data.bag.hay)
 var cow_feed=float(world.sim.livestock.data.pens.cow.feed)
 var sheep_feed=float(world.sim.livestock.data.pens.sheep.feed)
 world.add_shared_feed("hay")
 check(world.sim.data.bag.hay==hay-1 and world.sim.livestock.data.pens.cow.feed>cow_feed and world.sim.livestock.data.pens.sheep.feed>sheep_feed,"Common feed did not serve both hay-eating species")
 for kind in world.KINDS:
  while world.sim.livestock.members(kind).size()<world.sim.livestock.CAPACITY:world.sim.livestock.add(kind)
 world.sim.livestock.grow_all()
 world.refresh_herd()
 world.hour=21;world.apply_sky()
 var closest=INF
 for tick in 6500:
  await world.get_tree().physics_frame
  if tick%5==0:
   var animals=world.herd.values()
   for i in animals.size():
    for j in range(i+1,animals.size()):
     closest=minf(closest,world.animal_point(animals[i]).distance_to(world.animal_point(animals[j])))
  if world.herd.values().all(func(a):return a.mode=="睡觉"):break
 check(world.herd.size()==18 and world.herd.values().all(func(a):return a.mode=="睡觉" and world.REST_AREA.has_point(world.animal_point(a))),"Full herd did not settle in the common straw area")
 for a in world.herd.values():
  if a.mode!="睡觉":print("UNSETTLED ",world.animal_point(a)," goal=",a.goal," path=",a.path," stuck=",a.stuck)
 check(closest>=2.0*world.ANIMAL_RADIUS-.08,"Animals interpenetrated while moving: "+str(closest))
 var sleeping=world.herd.values()
 for i in sleeping.size():
  for j in range(i+1,sleeping.size()):
   if sleeping[i].mode!="睡觉" or sleeping[j].mode!="睡觉":continue
   check(world.animal_point(sleeping[i]).distance_to(world.animal_point(sleeping[j]))>=2.5,"Sleeping animals overlap")
 if DisplayServer.get_name()!="headless":
  check(await walk(world,Vector2(1,-5)) and await walk(world,Vector2(1,-13)),"Full herd blocked player access to the barn")
  await shot(world,"barn-shared-full")
 for animal in world.sim.livestock.data.herd.duplicate():
  if animal.kind!="pig":world.sim.livestock.data.herd.erase(animal)
 world.refresh_herd()
 world.show_station_menu()
 var labels=[]
 for child in world.menu_rows.get_children():
  if child is Button:labels.append(child.text)
 check("添加猪饲料" in labels and "添加干草" not in labels and "加满共用水槽" in labels,"Common trough menu did not adapt to a pig-only herd")
 print("RANCH_LIFE ","PASS" if failures.is_empty() else "FAIL"," ",JSON.stringify(failures))
 world.get_tree().quit(0 if failures.is_empty() else 1)
