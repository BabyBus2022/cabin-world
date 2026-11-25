extends SceneTree
var failures=[]
func check(ok:bool,reason:String):
 if not ok:failures.append(reason);push_error(reason)
func check_tuantuan_walk(neighbors):
 var directions=[Vector2.DOWN,Vector2.LEFT,Vector2.UP,Vector2.RIGHT]
 check(neighbors.walk_sheet.get_size()==Vector2(320,864),"Tuantuan atlas dimensions")
 for role in 3:
  for direction in 4:
   check(neighbors.direction_of(directions[direction],0)==direction,"Tuantuan facing "+str(direction))
   for frame in 5:
    var art:Texture2D=neighbors.walking_texture(role,direction,frame)
    check(art.region==Rect2(frame*64,(role*4+direction)*72,64,72),"Tuantuan atlas cell")
 var actor={"direction":1,"walk_progress":0.0}
 var steps=[]
 for tick in 5:steps.append(neighbors.stride_frame(actor,7.5))
 check(steps==[1,2,3,4,1],"Tuantuan stride follows distance and loops")
 check(neighbors.stride_frame(actor,0.0)==0,"Tuantuan stops on the idle pose")
 check(neighbors.stride_frame(actor,0.2)==1,"Tuantuan restarts on foot contact")
 var live_actor:Dictionary=neighbors.actors[0]
 var start:Vector2=live_actor.node.position
 live_actor.path=PackedVector2Array([start+Vector2.LEFT*80])
 var shown={}
 for step in 40:
  neighbors.tick(.05)
  if live_actor.sprite.texture is AtlasTexture:shown[live_actor.sprite.texture.region.position.x]=true
 check(live_actor.node.position.distance_to(start)>30,"Tuantuan moves along a village street")
 check(shown.has_all([64.0,128.0,192.0,256.0]),"All four Tuantuan stride frames render in the village")
func _initialize():run.call_deferred()
func run():
 set_meta("center_testing",true)
 set_meta("legacy_split_maps",true)
 change_scene_to_file("res://qingxi-live/village-center/main.tscn")
 await process_frame;await process_frame
 var world=current_scene
 world.set_physics_process(false);world.testing=true
 check(world.map_id=="village","boot village")
 check(not world.blocked(world.player.position),"village spawn blocked")
 check(world.world_bounds().size==Vector2(4800,3360),"expanded village bounds")
 # Every place has loadable, looping music (free tracks in village-center/audio/music/).
 for key in ["music/village_day","music/village_night","music/farm","music/ranch","music/pond","music/shop"]:
  var s=world.audio.stream(key,true)
  check(s!=null and s.get_length()>10.0,"music loads: "+key)
 check(world.qingxi.buildings.size()==15,"all plan buildings installed")
 check_tuantuan_walk(world.villagers)
 var grid=world.villagers.grid
 var start=Vector2i(((world.CENTER_START-Vector2(8,8))/16).round())
 for target in world.targets:
  if target.kind=="villager" or (target.kind=="qingxi_fire" and not world.world_bounds().has_point(target.pos)):continue
  var end=Vector2i(((target.pos-Vector2(8,8))/16).round())
  check(not world.blocked(target.pos),"blocked interaction: "+str(target.name))
  check(not grid.get_point_path(start,end).is_empty(),"unreachable interaction: "+str(target.name))
 for bridge in world.qingxi.bridges:
  check(not world.blocked(bridge.pos),"bridge center "+str(bridge.id))
  var vertical=bool(bridge.vertical)
  for side in [-1,1]:
   var p=bridge.pos+(Vector2(0,side*(bridge.size.y/2+12)) if vertical else Vector2(side*(bridge.size.x/2+12),0))
   check(not world.blocked(p),"bridge approach "+str(bridge.id)+" "+str(side))
  for step in 25:
   var t=float(step)/24-.5
   var p=bridge.pos+(Vector2(0,t*(bridge.size.y+24)) if vertical else Vector2(t*(bridge.size.x+24),0))
   check(not world.blocked(p),"continuous bridge crossing "+str(bridge.id))
   var aligned=p
   aligned.y+=float(bridge.get("slope",0.0))*(aligned.x-bridge.pos.x)
   check(not world.blocked(aligned),"aligned bridge crossing "+str(bridge.id))
 check(world.qingxi.water_blocks(world.qingxi.creek[world.qingxi.creek.size()/2]),"creek collision")
 for i in 4:
  var p=world.district.benches[i]
  check(p.distance_to(world.qingxi.plaza)+62<world.qingxi.radius,"bench inside plaza")
  world.player.position=p+Vector2(0,36);var stand=world.player.position
  world.district.sit(i);check(world.district.seat==i,"bench can sit")
  world.district.stand();check(world.player.position==stand and not world.blocked(stand),"bench safe stand")
  world.district.interact("qingxi_lamp",str(i));check(world.district.lamp_modes[i]==0,"lamp manual off")
  world.district.interact("qingxi_lamp",str(i));check(world.district.lamp_modes[i]==1,"lamp manual on")
  world.district.interact("qingxi_lamp",str(i));check(world.district.lamp_modes[i]==-1,"lamp auto")
 var idle_scale=world.portrait.scale.x
 for face in 4:
  world.show_action("walk-%d"%face,.2)
  check(world.portrait.scale.x>0,"valid walk scale")
 world.show_idle();check(is_equal_approx(idle_scale,world.portrait.scale.x),"idle scale accumulated")
 world.light_preset=4;world.center_cycle=false;world.center_hour=21;world.set_light(world.sky_value())
 for i in 120:world.villagers.tick(.05)
 for actor in world.villagers.actors:
  check(actor.mode=="gather","new night gathering schedule")
 world.center_hour=8;world.set_light(world.sky_value())
 var seed_count=world.sim.data.bag.seed;var coins=world.sim.data.coins
 world.portal_grace=0;world.player.position=world.SEED_DOOR+Vector2(0,25)
 world.move_actor(Vector2(0,-30));world.check_portals(world.SEED_DOOR+Vector2(0,25))
 # 2026-11-19 Claude: shop doors open with E; walking up to them alone does not enter.
 check(not world.transition_pending,"walking to the seed shop door does not enter by itself")
 check(not world.door_in_reach().is_empty(),"seed shop door is in reach (E prompt)")
 world.interact()
 await process_frame;await process_frame;await process_frame
 var shop=current_scene
 check(shop.get_script().resource_path.ends_with("connected_shop.gd"),"walking into seed shop")
 if not shop.get_script().resource_path.ends_with("connected_shop.gd"):finish();return
 shop.set_physics_process(false)
 check(shop.sim.data.coins==coins,"seed shop wallet handoff")
 check(is_equal_approx(shop.portrait.scale.x,idle_scale),"indoor outdoor body scale")
 shop.open_shop()
 for child in shop.menu_body.find_children("*","Button",true,false):
  if child.get_meta("item","")=="seed":child.pressed.emit();break
 check(shop.sim.data.bag.seed==seed_count+1 and shop.sim.data.coins==coins-2,"seed shop real buy button")
 shop.menu.hide();shop.exit_grace=0;shop.player.position=Vector2(432,732)
 var key=InputEventKey.new();key.physical_keycode=KEY_S;key.pressed=true;Input.parse_input_event(key)
 await process_frame
 shop._physics_process(.05)
 key=InputEventKey.new();key.physical_keycode=KEY_S;key.pressed=false;Input.parse_input_event(key)
 await process_frame;await process_frame;await process_frame
 world=current_scene
 check(world.get_script().resource_path.ends_with("center.gd"),"walking out of seed shop")
 if not world.get_script().resource_path.ends_with("center.gd"):finish();return
 world.set_physics_process(false);world.testing=true
 check(not world.blocked(world.player.position),"shop return feet blocked")
 check(world.sim.data.bag.seed==seed_count+1 and world.sim.data.coins==coins-2,"seed purchase retained")
 # "home" (the village south road) now lands on the farm: cottage and field are one map.
 for id in ["ranch","pond","field","home"]:
  world.travel(id);check(world.map_id==("field" if id=="home" else id),"travel "+id)
  check(not world.blocked(world.player.position),"arrival blocked "+id)
  if id=="ranch":
   check(current_scene==world and world.region.id=="ranch","original continuous 2D ranch entry")
   check(world.world_bounds().size==Vector2(2880,2016),"original ranch bounds")
   check(world.herd_ai.actors.size()==world.sim.livestock.data.herd.size(),"original ranch herd count")
   # Grid ranch: the starting paddock is a closed enclosure with every kind's feeder,
   # reaching the creek and the barn passage.
   var r=world.region
   for k in ["cow","sheep","pig","chicken"]:check(r.home.has(k),"feeder enclosure for "+k)
   check(r.enclosure_of("cow").get("creek",false) and r.enclosure_of("cow").get("barn",false),"starting paddock reaches creek and barn")
   check(r.troughs.has("cow") and not world.blocked(r.troughs.cow.drink),"creek drinking spot reachable")
   # Open one fence: the paddock leaks, animals lose their home; put it back.
   var edge="v:%d:%d"%[r.layout.default_ranch.paddock[0],r.layout.default_ranch.paddock[1]+1]
   check(r.set_edge(edge,"")=="ok" and not r.home.has("cow"),"opening a fence opens the paddock")
   check(r.set_edge(edge,"fence")=="ok" and r.home.has("cow"),"closing the fence restores it")
   check(r.set_edge("v:20:8","fence")!="ok","no fence inside the barn")
   check(r.set_edge("v:28:19","fence")=="ok" and r.set_edge("v:28:19","")=="ok","fences may cross the creek")
   check(not world.blocked(Vector2(1910,1060)),"wade across the shallow creek")
   # Feeders: take one up into the bag, place it back.
   var fc=Vector2i(int(r.ranch().feeders[0][1]),int(r.ranch().feeders[0][2]))
   var fk=str(r.ranch().feeders[0][0])
   check(r.take_feeder(fc)=="ok" and int(world.sim.data.bag["feeder_"+fk])==1 and not r.home.has(fk),"pick a feeder up")
   check(r.place_feeder(fk,fc)=="ok" and r.home.has(fk) and int(world.sim.data.bag["feeder_"+fk])==0,"place a feeder")
   check(r.place_feeder(fk,fc)!="ok","no feeder without one in the bag")
   # Night: animals walk into the barn and are hidden; morning brings them out.
   world.center_hour=21.0;world.light_preset=4
   for step in 1200:world.herd_ai.tick(.1)
   var inside=0
   for aid in world.herd_ai.actors:
    if not world.herd_ai.actors[aid].node.visible:inside+=1
   check(inside==world.herd_ai.actors.size(),"herd sleeps in the barn at night (%d/%d)"%[inside,world.herd_ai.actors.size()])
   world.center_hour=9.0
   for step in 600:world.herd_ai.tick(.1)
   var out=0
   for aid in world.herd_ai.actors:
    if world.herd_ai.actors[aid].node.visible:out+=1
   check(out==world.herd_ai.actors.size(),"herd back out in the morning")
   # The barn door leads inside; at night the herd sleeps in its bays there.
   world.center_hour=22.0
   world.travel("barn");check(world.map_id=="barn" and not world.blocked(world.player.position),"walk into the barn")
   world.herd_ai.tick(.1)
   var sleeping=0
   for aid in world.herd_ai.actors:
    if world.herd_ai.actors[aid].node.visible:sleeping+=1
   check(sleeping>0 and sleeping==world.sim.livestock.data.herd.size(),"herd asleep in the barn bays (%d/%d)"%[sleeping,world.herd_ai.actors.size()])
   world.travel("ranch");check(world.map_id=="ranch" and not world.blocked(world.player.position),"back out to the ranch")
   world.center_hour=9.0
  if id=="field":
   check(world.fields.size()==48,"48 farm plots")
   var plot:Rect2=world.fields[20].rect
   check(world.cell_at(plot.get_center())==20,"plot lookup")
   world.player.position=plot.get_center()+Vector2(0,40);world.selected_cell=20
   var seeds=int(world.sim.data.bag.seed);world.interact()
   check(world.sim.data.crops[20].planted and int(world.sim.data.bag.seed)==seeds-1,"plant on a new plot")
   world.sim.data.bag.seed+=1   # keep the later inventory checks' bookkeeping unchanged
   var door=Vector2.ZERO
   for t in world.targets:
    if t.kind=="portal" and str(t.extra)=="room_private":door=t.pos
   check(door!=Vector2.ZERO and not world.blocked(door+Vector2(0,20)),"cottage door reachable")
   # Layout mode: till a plot on open ground, then take it back.
   var count=world.fields.size();var tilled=Vector2.ZERO
   for gx in range(4,40):
    for gy in range(4,28):
     var c=world.PLOT_ORIGIN+Vector2(gx,gy)*64
     if tilled==Vector2.ZERO and world.region.plot_free(c):tilled=c
   check(tilled!=Vector2.ZERO,"free ground for a new plot")
   world.region.add_plot(tilled);check(world.fields.size()==count+1 and world.sim.data.layout.plots.size()==count+1,"till a plot")
   world.region.remove_plot(world.fields.size()-1);check(world.fields.size()==count,"take a plot back")
   check(not world.region.plot_free(world.fields[0].rect.position),"no plot on top of a plot")
   # Movable props: pick the shipping bin up, set it down elsewhere, it still sells there.
   var rg=world.region;var bin=""
   for uid in rg.prop_nodes:
    if rg.prop_nodes[uid].name=="shipping_bin":bin=uid
   check(bin!="" and rg.pick_prop(bin)=="ok" and int(world.sim.data.bag.get("decor_shipping_bin",0))==1,"pick up the shipping bin")
   var has_ship=false
   for tg in world.targets:
    if tg.kind=="ship":has_ship=true
   check(not has_ship,"picked-up bin no longer sells")
   var spot=Vector2.ZERO
   for gx in range(6,40):
    for gy in range(6,28):
     var c=Vector2(gx,gy)*64
     if spot==Vector2.ZERO and rg.prop_spot_ok("shipping_bin",c):spot=c
   check(spot!=Vector2.ZERO and rg.put_prop("shipping_bin",spot)=="ok","set the bin down elsewhere")
   var moved=false
   for tg in world.targets:
    if tg.kind=="ship" and tg.pos.distance_to(spot)<40:moved=true
   check(moved and int(world.sim.data.bag.decor_shipping_bin)==0,"moved bin sells at its new spot")
   check(rg.put_prop("shipping_bin",spot)!="ok","no prop without one in the bag")
   world.portal_grace=0;world.player.position=door+Vector2(0,2)
   world.move_actor(Vector2(0,-4));world.check_portals(door+Vector2(0,2))
   if not world.transition_pending:world.interact() # 2026-11-19 Claude: doors open with E
   await process_frame;await process_frame
   check(world.map_id=="room_private","farm cottage door enters original room")
   world.travel("home")
   check(world.map_id=="field" and world.fields.size()==48,"private room returns to combined farm")
  if id=="pond":
   world.sim.pond_action();world.sim.pond_action();world.living_pond.tick(.1);world.living_pond.splash()
   check(world.sim.data.pond.count>0,"pond stocking retained")
   check(not world.living_pond.ripples.is_empty(),"pond live ripples")
   check(world.blocked(Vector2(1150,700)),"water collision")
   check(not world.blocked(world.living_pond.interaction),"dock walkable")
  world.travel("village");check(not world.blocked(world.player.position),"return blocked from "+id)
 check(world.sim.data.bag.seed==seed_count+1,"cross map inventory retained")
 var fish_count=world.sim.data.pond.count
 world.travel("pond");check(world.sim.data.pond.count==fish_count,"fish state across round trip")
 check(world.sim.save_to("user://center-verification-save.json"),"test save")
 var loaded=world.StateModel.new();check(loaded.load_from("user://center-verification-save.json"),"test reload")
 check(loaded.data.bag.seed==seed_count+1 and loaded.data.pond.count==fish_count,"reload inventory and fish")
 finish()
func finish():
 # Young animals: bought into the bag, released into their pen at the ranch.
 var s=preload("res://qingxi-live/rural_state.gd").new();var cows=s.livestock.members("cow").size();var coins=s.data.coins
 s.buy_young("cow");check(int(s.data.bag.get("young_cow",0))==1 and s.data.coins==coins-60 and s.livestock.members("cow").size()==cows,"young cow goes to bag")
 s.release_young("cow");check(int(s.data.bag.young_cow)==0 and s.livestock.members("cow").size()==cows+1,"young cow released into pen")
 print("CENTER_VERIFY "+("PASS" if failures.is_empty() else "FAIL")+" "+JSON.stringify(failures))
 quit(0 if failures.is_empty() else 1)
