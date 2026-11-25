extends SceneTree
## 2026-11-19 Claude: checks for the owner's countryside bug list (Qingxi Village).
## Run headless on a COPY of the project with an isolated APPDATA:
##   godot --headless --path . --script res://qingxi-live/village-center/flat-build/check_countryside_20261119.gd -- --verify-center
## --verify-center keeps the real save untouched (no load, no write).
## Prints COUNTRYSIDE_20261119 PASS [] or FAIL [reasons].
var failures=[]
var w
func check(ok:bool,note:String):
 if not ok:failures.append(note);push_error(note)
 else:print("  ok  ",note)
func area(x:int,y:int,width:int,height:int)->Dictionary:
 var cells={}
 for j in range(y,y+height):
  for i in range(x,x+width):cells[Vector2i(i,j)]=true
 return cells
func click_world(p:Vector2,code:=MOUSE_BUTTON_LEFT):
 var at=w.get_global_transform_with_canvas()*p
 var m=InputEventMouseMotion.new();m.position=at;m.global_position=at;root.push_input(m,true)
 for pressed in [true,false]:
  var e=InputEventMouseButton.new();e.position=at;e.global_position=at;e.button_index=code;e.pressed=pressed
  e.button_mask=(MOUSE_BUTTON_MASK_LEFT if code==MOUSE_BUTTON_LEFT else MOUSE_BUTTON_MASK_RIGHT) if pressed else 0
  root.push_input(e,true)
func frames(n:int):
 for i in n:await process_frame
func _initialize():run.call_deferred()

func run():
 set_meta("center_testing",true)
 change_scene_to_file("res://qingxi-live/village-center/main.tscn")
 await frames(3)
 w=current_scene;w.set_physics_process(false);w.testing=true
 # ---- 1. 团团 keep walking while the owner sits on a bench ----
 w.center_hour=10.0;w.light_preset=4;w.center_cycle=false;w.set_light(w.sky_value())
 w.district.sit(0)
 check(w.district.seat==0,"#1 owner sits on a village bench")
 var starts=[]
 for a in w.villagers.actors:starts.append(a.node.position)
 for i in 240:w._physics_process(1.0/60.0)
 var moved=0
 for i in w.villagers.actors.size():
  if w.villagers.actors[i].node.position.distance_to(starts[i])>4.0:moved+=1
 check(w.district.seat==0,"#1 owner is still seated after 4 s")
 check(moved>=3,"#1 团团 walk on while the owner sits (%d of %d moved)"%[moved,w.villagers.actors.size()])
 w.district.stand()
 # ---- 6. village shop door: E, not a thin threshold ----
 w.portal_grace=0;w.player.position=w.SEED_DOOR+Vector2(30,70)
 check(not w.door_in_reach().is_empty(),"#6 seed shop door reachable from 70 px in front and 30 px aside")
 check(w.ui.current_prompt().begins_with("进入"),"#6 HUD shows E 进入 … at the door ("+w.ui.current_prompt()+")")
 # ---- round 3: seasons, rice paddies tended by 团团, map marker, juice, critters ----
 var pd=w.paddies
 check(is_instance_valid(pd) and pd.fields.size()==4 and pd.area().size.x>=1088 and pd.area().size.y>=576,"R3 four big rice paddies in the village")
 check(pd.markers().size()==1 and Rect2(pd.markers()[0].rect)==pd.area() and not pd.markers()[0].has("label"),"R3 the paddy land is outlined on the map, no name")
 check(w.season()==0 and w.Seasons.label(w.calendar_day())=="春 · 第1天","R3 a new save starts on spring day 1")
 check(w.blocked(pd.fields[0].get_center()) and not w.blocked(pd.fields[0].position-Vector2(0,30)),"R3 fields are solid, the dikes are walkable")
 w.center_hour=12.0;w.set_light(w.sky_value())
 w.sim.data.calendar.day=2
 check(pd.planted(0)>0.2 and pd.planted(0)<1.0,"R3 spring: part of the field is planted (%d%%)"%int(pd.planted(0)*100))
 for k in 2400:pd.tick(1.0/30.0)
 var in_water=0
 for a in pd.workers:
  if a.node.visible and pd.in_field(a.node.position)>=0:in_water+=1
 check(in_water>=1,"R3 spring: 团团 work in the paddies (%d in the water)"%in_water)
 var sign_t=w.targets.filter(func(t):return t.kind=="paddy" and t.extra=="sign")
 check(not sign_t.is_empty() and pd.talk("sign").contains("插秧"),"R3 the paddy sign tells the stage: "+pd.talk("sign").replace("
"," / "))
 for t in w.targets.filter(func(t):return t.kind=="paddy"):
  check(not w.blocked(t.pos),"R3 paddy E spot on open ground: "+str(t.name))
 w.next_day(5);check(w.season()==1,"R3 day 8 is summer")
 var p0=pd.fields[0].position+Vector2(40,40);var a0=pd.wind(p0);var b0=pd.wind(p0+Vector2(180,0))
 pd.age+=0.7;var a1=pd.wind(p0)
 check(absf(a0-b0)>.05 and absf(a0-a1)>.05,"R3 wind moves the rice as a travelling wave (%.2f / %.2f / %.2f)"%[a0,b0,a1])
 check(not w.scenery.get_children().any(func(n):return n is Node2D and pd.fields[2].grow(-8).has_point(n.position) and not pd.workers.any(func(a):return a.node==n)),"R3 no bushes or trees left on the fields")
 w.sim.data.calendar.day=17;check(w.season()==2 and pd.harvested(0)>0.0,"R3 autumn: harvest under way (%d%%)"%int(pd.harvested(0)*100))
 var ev=InputEventKey.new();ev.physical_keycode=KEY_F5;ev.pressed=true;w._unhandled_key_input(ev)
 check(w.season()==3,"R3 F5 jumps to the next season (winter)")
 for k in 1800:pd.tick(1.0/30.0)
 var out=0
 for a in pd.workers:if a.node.visible:out+=1
 check(out==1,"R3 winter: fields frozen, only one 团团 out (skating), got %d"%out)
 w.center_hour=22.0;w.set_light(w.sky_value());pd.season_changed()
 for k in 1800:pd.tick(1.0/30.0)
 out=0
 for a in pd.workers:if a.node.visible:out+=1
 check(out==0,"R3 at night all 团团 have gone home")
 w.sim.data.calendar.day=0;w.center_hour=10.0;w.set_light(w.sky_value())
 w.selected_cell=-1;w.perform("收获白菜 ×2、种子 ×1")
 check(w.juice.bits.size()>5 and w.juice.texts.size()==1,"R3 harvesting pops numbers and pixels")
 check(w.map_layer.get_children().any(func(n):return n.get_script()!=null and n.get_script().resource_path.ends_with("critters.gd")),"R3 the village has ambient critters")
 # ---- 9. walk from the village into the farm: arrive on the village lane ----
 w.travel("meadow")
 await frames(8)
 w=current_scene;w.set_physics_process(false);w.testing=true
 check(w.open_meadow and w.map_id=="ranch","#9 village leads to the owner's farm")
 var rg=w.region;var lane:Rect2=rg.MEADOW_EXIT_LANE
 check(w.player.position.distance_to(rg.meadow_gate_arrival())<1.0,"#9 arriving from the village starts on the gate lane")
 check(w.targets.any(func(t):return t.kind=="exit" and t.extra=="village"),"#9 the farm has an exit target to 清溪村")
 var open_lane=true
 for x in range(int(lane.position.x)+8,int(rg.MEADOW_EXIT.x)+40,8):
  if w.blocked(Vector2(x,lane.get_center().y)):open_lane=false
 check(open_lane,"#9 the lane to the east edge is walkable (no trees or fence)")
 check(w.edit_plots(Rect2(lane.position,Vector2(128,64)),false)==0,"#9 plots cannot be dug on the gate lane")
 # ---- round 2 #1: the gate signpost is a normal movable prop ----
 check(rg.prop_nodes.has("gate_sign") and bool(rg.saved().get("gate_sign_seeded",false)),"R2#1 gate signpost is a saved, movable prop")
 check(rg.pick_prop("gate_sign")=="ok" and not rg.prop_nodes.has("gate_sign"),"R2#1 the signpost can be picked up")
 check(rg.put_prop("signpost",Vector2(20*64,6*64))=="ok","R2#1 and set down somewhere else")
 # ---- 10. 3x3 water becomes a fish pond with a depth gradient ----
 var terrain=w.ground_tiles
 w.player.position=Vector2(5.5,10.5)*64
 check(terrain.edit("channel",area(8,8,3,3),false)=="ok","#10 dig 3x3 water")
 check(terrain.deep.size()==9,"#10 3x3 water is a fish pond (deep=%d)"%terrain.deep.size())
 check(w.targets.any(func(t):return t.kind=="meadow_fish"),"#10 the pond can be tended from the bank (E)")
 check(terrain.pond_depth(Vector2i(9,9))>terrain.pond_depth(Vector2i(8,8)) and terrain.pond_depth(Vector2i(8,8))>0.0,"#10 colour gradient: centre deeper than the rim")
 check(terrain.edit("channel",area(14,8,2,2),false)=="ok" and not terrain.deep.has(Vector2i(14,8)),"#10 2x2 stays a swimming hole, not a pond")
 check(w.audio.stream("amb_pond",true)!=null and w.audio.stream("step_water_0")!=null,"#10/#2 pond loop and water steps load")
 # ---- 2. river sound on the farm, splashing steps in it ----
 check(terrain.edit("channel",area(20,14,6,1),false)=="ok","#2 paint a one-cell river")
 w.player.position=Vector2(22.5,15.5)*64
 check(w.painted_water_distance(w.player.position)<40.0,"#2 painted river counts as nearby water")
 for i in 120:w.footsteps(0.0)
 check(w.audio.water.playing and w.audio.water.volume_db>-30.0,"#2 river sound plays beside farm water (%.1f dB)"%w.audio.water.volume_db)
 w.player.position=Vector2(5.5,9.5)*64
 for i in 120:w.footsteps(0.0)
 check(w.audio.pond_water!=null and w.audio.pond_water.volume_db>-30.0,"#10 running-water sound by the fish pond (%.1f dB)"%(w.audio.pond_water.volume_db if w.audio.pond_water else -99.0))
 w.player.position=Vector2(22.5,14.5)*64;w.update_swim(.1,true)
 check(w.water_contact and not w.swimming,"#2 standing in the river = wading")
 var voice=w.audio.next_voice
 w.step_distance=0.0;w.footsteps(41.0)
 var played=w.audio.pool[voice].stream
 check(played!=null and played in [w.audio.stream("step_water_0"),w.audio.stream("step_water_1"),w.audio.stream("step_water_2")],"#2 wading makes a water footstep")
 w.player.position=Vector2(22.5,17.5)*64;w.update_swim(.1,false)
 # ---- round 2 #2: swim in any 2x2+ water, fish ponds included ----
 w.player.position=Vector2(7.5,9.5)*64;var shore=w.player.position
 for i in 70:w.move_actor(Vector2(3,0))
 check(w.player.position.x>shore.x+90 and terrain.deep.has(Vector2i((w.player.position/64).floor())),"R2#2 the player swims into the 3x3 fish pond")
 w.update_swim(.1,true)
 check(w.swimming,"R2#2 swimming pose in the fish pond")
 check(w.blocked(Vector2(9.5,9.5)*64),"R2#2 deep water still blocks animals and placing")
 w.player.position=Vector2(5.5,12.5)*64;w.update_swim(.1,false)
 # ---- round 2b: a river dug out of the pond is fish water too; so is any 9+ cell body ----
 check(terrain.edit("channel",area(11,9,6,2),false)=="ok","R2b dig a 2-wide river out of the 3x3 pond")
 var pond_id=str(terrain.basin[Vector2i(9,9)])
 check(str(terrain.basin.get(Vector2i(16,10),""))==pond_id,"R2b the outflowing river belongs to the pond's fish water")
 check(w.targets.any(func(t):return t.kind=="meadow_fish" and t.extra==pond_id and t.pos.x>11*64+40),"R2b fish can be tended from the river bank")
 w.sim.data.bag.fry=6;for k in 6:terrain.tend(pond_id)
 var reached=false
 for k in 3000:
  terrain.swim_fish(1.0/30.0)
  for f in terrain.fish_marks:
   if f.cell.x>=12:reached=true
  if reached:break
 check(terrain.fish_marks.size()>0 and reached,"R2b stocked fish swim out into the river")
 check(terrain.edit("channel",area(3,26,10,1),false)=="ok" and terrain.basin.has(Vector2i(3,26)) and not terrain.deep.has(Vector2i(3,26)),"R2b a 10-cell river with no 3x3 is fish water (still shallow)")
 check(terrain.edit("channel",area(20,26,8,1),false)=="ok" and not terrain.basin.has(Vector2i(20,26)),"R2b an 8-cell river is not")
 w.player.position=Vector2(15.5,12.5)*64
 for k in 120:w.footsteps(0.0)
 check(w.audio.pond_water.volume_db>-30.0,"R2b running-water sound beside the fish river")
 # ---- 3. mouse farming ----
 check(w.edit_plots(Rect2(Vector2(10,20)*64,Vector2(192,64)),false)==3,"#3 dig three plots")
 w.player.position=Vector2(10.5,21.6)*64;w.update_camera(true);w.sim.data.bag.seed=5
 var far:int=w.region.cell_at(Vector2(12.5,20.5)*64);var near:int=w.region.cell_at(Vector2(10.5,20.5)*64)
 click_world(Vector2(10.5,20.5)*64);await frames(2)
 check(w.sim.data.crops[near].planted,"#3 left click plants the plot under the mouse")
 click_world(Vector2(12.5,20.5)*64);await frames(2)
 check(not w.sim.data.crops[far].planted,"#3 a plot out of reach is not planted by a click")
 w.player.position=Vector2(11.6,21.6)*64
 click_world(Vector2(12.5,20.5)*64);await frames(2)
 check(w.sim.data.crops[far].planted,"#3 after walking closer the click plants it")
 # ---- round 2 #3: Minecraft farmland — water within 4 cells keeps soil wet ----
 check(w.edit_plots(Rect2(Vector2(12,12)*64,Vector2(64,64)),false)==1,"R2#3 dig a plot two cells from the pond")
 var wet_i:int=w.region.cell_at(Vector2(12.5,12.5)*64)
 w.sim.data.crops[wet_i].planted=true;w.sim.data.crops[wet_i].water=0.0;w.sim.data.crops[far].water=0.0
 w.refresh_life()
 check(float(w.sim.data.crops[wet_i].water)>0.0 and w.fields[wet_i].get("hydrated",false),"R2#3 a plot near water is hydrated by itself")
 check(float(w.sim.data.crops[far].water)==0.0 and not w.fields[far].get("hydrated",true),"R2#3 a plot 6 cells from water stays dry")
 check(w.region.beds[wet_i].self_modulate!=Color.WHITE and w.region.beds[far].self_modulate==Color.WHITE,"R2#3 wet soil is drawn darker")
 # ---- 5. animals into the barn ----
 var barn_pos=Vector2(30*64+32,8*64+60)
 w.player.position=barn_pos+Vector2(0,260)
 check(w.change_barn(barn_pos,false)=="ok","#5 build a barn (牧场屋)")
 var key="young_chicken:0:f";w.sim.data.bag[key]=1
 var before=w.sim.livestock.data.herd.size()
 check(w.can_use_bag_item(key),"#5 a chick can be let out on the farm once a barn stands")
 w.use_bag_item(key)
 check(w.sim.livestock.data.herd.size()==before+1,"#5 chick released without a fenced pasture (lives in the barn)")
 w.close_menu()
 w.player.position=w.region.barn_door()+Vector2(-120,30);w.portal_grace=0;w.action_target={}
 check(not w.door_in_reach().is_empty(),"#6 barn door reachable beside the doorway")
 w._physics_process(1.0/60.0)   # refresh the selection like a real frame
 w.interact();await frames(3)
 for i in 60:
  if w.map_id=="barn":break
  await process_frame
 check(w.map_id=="barn","#6 E enters the barn")
 for kind in ["cow","sheep","pig"]:
  var k="young_%s:0:f"%kind;w.sim.data.bag[k]=1
  check(w.can_use_bag_item(k),"#5 %s can be placed inside the barn"%kind)
  var n=w.sim.livestock.data.herd.size();w.use_bag_item(k)
  check(w.sim.livestock.data.herd.size()==n+1,"#5 %s added inside the barn"%kind)
 w.close_menu()
 w.travel("ranch");await frames(2)
 # ---- 7/8. private cottage: E to enter, Cabin World furniture, wall staircase ----
 var hd=Vector2(36*64+32,20*64+60)
 w.player.position=hd+Vector2(0,220)
 check(w.change_house(hd,false)=="ok","#7 place the private cottage")
 # An old save already has the first furniture set: it must be swapped for the new one once.
 var layout_:Dictionary=w.layout_save()
 if not layout_.has("placement_by_map"):layout_.placement_by_map={}
 layout_.placement_by_map["room_private"]={"tiles":{},"furniture":{"room_0":["sofa",450,468,140,[-61,-40,122,40]],"placed_1":["chest",330,640,72]},"room_seeded":true,"serial":1}
 w.player.position=Vector2(w.region.saved().meadow_house[0],w.region.saved().meadow_house[1])+Vector2(6,64);w.portal_grace=0;w.action_target={}
 w._physics_process(1.0/60.0)
 check(not w.door_in_reach().is_empty(),"#6 cottage door reachable from 64 px in front")
 w.interact()
 for i in 90:
  if w.map_id=="room_private":break
  await process_frame
 check(w.map_id=="room_private","#6 E enters the cottage")
 var pieces=[]
 for row in w.placement.plan.furniture.values():pieces.append(str(row[0]))
 check(pieces.count("cw_table")==1 and pieces.has("cw_stove") and pieces.has("cw_sofa") and not pieces.has("sofa"),"#7 ground floor uses the Cabin World furniture set "+str(pieces))
 check(pieces.has("chest"),"#7 a piece the owner placed is kept when the set is swapped")
 check(int(w.placement.plan.get("room_design",0))==3,"#7 room remembers the new design")
 var Rooms_=preload("res://qingxi-live/village_rooms.gd")
 var run_:Rect2=Rooms_.STAIR_RUN
 var walk_ok=true
 for y in range(int(run_.end.y)+30,int(run_.position.y)+40,-6):
  if w.blocked(Vector2(run_.get_center().x,y)):walk_ok=false
 check(walk_ok,"#8 the wall staircase can be walked from its foot")
 check(w.floor_height(Vector2(run_.get_center().x,run_.position.y+50))>w.floor_height(Vector2(run_.get_center().x,run_.end.y-4)),"#8 the player rises along the stairs")
 w.player.position=Vector2(run_.get_center().x,run_.position.y+110);w.portal_grace=0
 var from_=w.player.position;w.move_actor(Vector2(0,-60));w.check_portals(from_)
 for i in 90:
  if w.map_id=="room_private_up":break
  await process_frame
 check(w.map_id=="room_private_up","#8 walking up the wall staircase reaches the upper floor")
 check(w.player.position.distance_to(Rooms_.STAIR_UPPER_ARRIVAL)<2,"#8 arrive on the landing")
 check(not w.blocked(w.player.position) and w.blocked(Vector2(run_.get_center().x,run_.end.y-20)),"#8 landing is floor, the stairwell is not")
 var up_pieces=[]
 for row in w.placement.plan.furniture.values():up_pieces.append(str(row[0]))
 check(up_pieces.has("cw_bed") and up_pieces.has("cw_writing_desk"),"#7 bedroom uses the Cabin World bed and desk")
 w.portal_grace=0;from_=w.player.position;w.move_actor(Vector2(0,70));w.check_portals(from_)
 for i in 90:
  if w.map_id=="room_private":break
  await process_frame
 check(w.map_id=="room_private" and w.player.position.distance_to(Rooms_.STAIR_GROUND_ARRIVAL)<2,"#8 walking into the stairwell goes back down")
 w.travel("home")
 for i in 90:
  if w.map_id=="ranch":break
  await process_frame
 # ---- 9. walk off the lane end -> village ----
 w=current_scene
 w.player.position=rg.MEADOW_EXIT+Vector2(30,0) if is_instance_valid(rg) else w.region.MEADOW_EXIT+Vector2(30,0)
 w._physics_process(1.0/60.0)
 check(w.transition_pending,"#9 walking off the lane end leaves for the village")
 await frames(10)
 check(current_scene.get("map_id")=="village","#9 back in 清溪村")
 print("COUNTRYSIDE_20261119 ","PASS" if failures.is_empty() else "FAIL"," ",failures)
 quit(0 if failures.is_empty() else 1)
