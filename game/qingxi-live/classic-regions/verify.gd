extends SceneTree
var game
var failures=[]
func _initialize():
 create_timer(90).timeout.connect(func():print("VERIFY_TIMEOUT");quit(2))
 call_deferred("run")
func check(ok:bool,message:String):
 if not ok:failures.append(message);push_error(message)
func run():
 set_meta("classic_regions_test",true)
 game=load("res://qingxi-live/classic-regions/main.tscn").instantiate();root.add_child(game);current_scene=game;game.paused_for_capture=true
 for id in game.MAP_NAMES:
  game.build_map(id)
  check(not game.blocked(game.player.position),id+" spawn")
  var bounds:Rect2=game.world_bounds()
  var grid=AStarGrid2D.new();grid.region=Rect2i(0,0,int(bounds.size.x/8),int(bounds.size.y/8));grid.cell_size=Vector2(8,8);grid.offset=Vector2(4,4);grid.diagonal_mode=AStarGrid2D.DIAGONAL_MODE_NEVER;grid.update()
  for y in grid.region.size.y:
   for x in grid.region.size.x:grid.set_point_solid(Vector2i(x,y),game.blocked(Vector2(x*8+4,y*8+4)))
  var start=Vector2i(((game.player.position-Vector2(4,4))/8).round())
  for target in game.targets:
   var end=Vector2i(((target.pos-Vector2(4,4))/8).round())
   check(not grid.get_id_path(start,end).is_empty(),id+" unreachable "+target.name)
  for edge in [Vector2(25,25),bounds.end-Vector2(25,25)]:
   game.player.position=edge;game.update_camera(true)
   var half=game.get_viewport_rect().size/game.camera.zoom/2
   check(bounds.encloses(Rect2(game.camera.position-half,half*2)),id+" camera bounds")
 for id in ["home","seedshop","stockshop"]:
  for repeat in 2:
   game.build_map("village")
   for target in game.targets:
    if target.extra==id:game.player.position=target.pos+Vector2(0,40);break
   game.portal_grace=0
   await walk(Vector2.UP,90)
   check(game.map_id==id,id+" walking entry")
   if game.map_id!=id:continue
   game.player.position=game.rooms.ENTRY-Vector2(0,40);game.portal_grace=0
   await walk(Vector2.DOWN,90)
   check(game.map_id=="village",id+" walking exit")
 game.sim.reset()
 game.build_map("seedshop");game.show_shop("seed")
 var seed=game.sim.data.bag.seed
 for button in game.overlay_body.get_children():
  if button is Button and button.text.begins_with("白菜种子"):
   button.pressed.emit();break
 check(game.sim.data.bag.seed==seed+1,"seed shop purchase")
 game.close_menu();game.travel("field");game.sim.crop_action(0);game.sim.crop_action(0);game.sim.advance(400)
 game.travel("ranch");game.sim.advance(800);game.travel("field")
 check(game.sim.data.crops[0].progress==1200,"cross-map crop progress")
 game.sim.crop_action(0);check(game.sim.data.bag.veg==2,"harvest")
 game.travel("home");game.sim.cook();check(game.sim.data.bag.meal==1,"cooking")
 game.sim.store_items(false);check(game.sim.data.storage.meal==1,"storage")
 game.sim.store_items(true);check(game.sim.data.bag.meal==1,"storage retrieval")
 var cows=game.sim.livestock.members("cow").size()
 game.travel("stockshop");game.sim.buy_animal("cow");game.travel("ranch")
 check(game.sim.livestock.members("cow").size()==cows+1,"livestock purchase and transfer")
 var before={}
 for id in game.herd_ai.actors:before[id]=game.herd_ai.actors[id].node.position
 for i in 600:game.herd_ai.tick(0.05)
 var moving=0
 for id in before:
  if game.herd_ai.actors[id].node.position.distance_to(before[id])>4:moving+=1
 check(moving>0,"animals move")
 game.travel("pond");game.sim.pond_action();game.sim.pond_action();game.sim.quick_grow("pond");game.sim.pond_action()
 check(game.sim.data.bag.fish>0,"fish production")
 game.sim.data.pond.count=2;game.living_pond.tick(0);game.living_pond.splash();var pos=game.living_pond.fish[0].pos;game.living_pond.tick(1)
 check(game.living_pond.fish[0].pos!=pos and not game.living_pond.ripples.is_empty(),"pond animation")
 check(game.sim.save_to("user://classic-verify.json"),"save")
 var restored=game.StateModel.new();check(restored.load_from("user://classic-verify.json"),"load")
 check(restored.data.bag.fish==game.sim.data.bag.fish,"persistent inventory")
 print("CLASSIC_VERIFY ","PASS" if failures.is_empty() else "FAIL", " ",JSON.stringify(failures));quit(0 if failures.is_empty() else 1)
func walk(direction:Vector2,frames:int):
 var previous_map=game.map_id
 for i in frames:
  var previous=game.player.position;game.move_actor(direction*2);game.check_portals(previous)
  await process_frame
  if game.map_id!=previous_map:break
