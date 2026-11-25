extends SceneTree
var failures=[]
var w
const HerdRules=preload("res://qingxi-live/village-center/pasture_herd.gd")
func _initialize():run.call_deferred()
func check(ok:bool,note:String):
 if not ok:failures.append(note);push_error(note)
func area(x:int,y:int,width:int,height:int)->Dictionary:
 var cells={}
 for j in range(y,y+height):
  for i in range(x,x+width):cells[Vector2i(i,j)]=true
 return cells
func mouse_button(point:Vector2,pressed:bool,code:=MOUSE_BUTTON_LEFT):
 var e=InputEventMouseButton.new();e.position=point;e.global_position=point
 e.button_index=code;e.pressed=pressed
 e.button_mask=(MOUSE_BUTTON_MASK_LEFT if code==MOUSE_BUTTON_LEFT else MOUSE_BUTTON_MASK_RIGHT) if pressed else 0
 root.push_input(e,true)

func mouse_move(from:Vector2,to:Vector2,held:bool):
 var e=InputEventMouseMotion.new();e.position=to;e.global_position=to;e.relative=to-from
 e.button_mask=MOUSE_BUTTON_MASK_LEFT if held else 0;root.push_input(e,true)

func picture(path:String,overview:bool):
 var old_zoom=w.camera.zoom;var pos=w.player.position
 if overview:
  w.hud.hide();w.camera.zoom=Vector2.ONE*.21
 else:
  w.camera.zoom=Vector2.ONE*.48;w.player.position=Vector2(1090,990)
  w.hotbar.select(w.hotbar.slots.find("channel"));w.ui.toasts.hide()
 w.update_camera(true);w.ui.refresh(.1)
 await create_timer(.45).timeout
 await RenderingServer.frame_post_draw
 root.get_texture().get_image().save_png(ProjectSettings.globalize_path("res://qingxi-live/village-center/reports/"+path+".png"))
 w.hud.show();w.player.position=pos;w.camera.zoom=old_zoom;w.update_camera(true)
func key_press(code:int):
 var e=InputEventKey.new()
 e.physical_keycode=code;e.pressed=true
 root.push_input(e,true)

func click_world(p:Vector2,code:=MOUSE_BUTTON_LEFT):
 var at=w.get_global_transform_with_canvas()*p
 mouse_move(at,at,false)
 mouse_button(at,true,code)
 mouse_button(at,false,code)

func check_building_input():
 w.player.position=Vector2(1440,894);w.update_camera(true)
 var original_player=w.player.position
 var original_camera=w.camera
 key_press(KEY_G);key_press(KEY_6)
 # The cursor is over open grass in the upper part of the initial build view.
 var barn_pos=Vector2(1440,508)
 click_world(barn_pos)
 await process_frame;await process_frame
 check(not w.region.layout.barn.is_empty(),"barn placement from the upper part of the open meadow")
 check(w.camera==original_camera and root.get_camera_2d()==w.camera,"placing the barn preserves the active camera")
 if not w.region.layout.barn.is_empty():
  var duplicate=w.change_barn(barn_pos+Vector2(0,128),false)
  check(duplicate.begins_with("已放置"),"duplicate barn explains existing placement")
  w.change_barn(barn_pos-Vector2(0,32),true)
  check(w.camera==original_camera and not w.blocked(barn_pos-Vector2(0,100)),"removing the barn preserves camera and clears collision")
 key_press(KEY_7)
 var door=Vector2(1568,508)
 click_world(door)
 await process_frame;await process_frame
 check(w.region.saved().get("meadow_house",[])==[door.x,door.y],"mouse click places the cottage")
 check(root.get_camera_2d()==w.camera and w.camera==original_camera,"placing the cottage preserves the active camera")
 check(w.region.set_edge("h:24:8","fence")!="ok","fence cannot block cottage threshold")
 check(w.region.place_feeder("cow",Vector2i(24,8))!="ok","feeder cannot block cottage landing")
 check(w.terrain_cell_free(Vector2i(24,8),"path"),"a road can meet the cottage door")
 check(w.player.position==original_player and w.player.get_global_transform_with_canvas().origin.distance_to(root.get_visible_rect().get_center())<120,"player stays in view after placing the cottage")
 var key=InputEventKey.new();key.keycode=KEY_D;key.physical_keycode=KEY_D;key.pressed=true
 Input.parse_input_event(key);Input.flush_buffered_events()
 for i in 75:w._physics_process(1.0/60)
 var up=InputEventKey.new();up.keycode=KEY_D;up.physical_keycode=KEY_D;Input.parse_input_event(up);Input.flush_buffered_events()
 check(w.player.position.x>original_player.x+70 and w.camera.get_screen_center_position().x>original_player.x+60,"keyboard movement and camera follow after placement")
 w.change_house(door-Vector2(0,20),true)
 key_press(KEY_G)
 w.player.position=original_player;w.update_camera(true)

func save_view(name_:String):
 await create_timer(.2).timeout
 await RenderingServer.frame_post_draw
 root.get_texture().get_image().save_png(ProjectSettings.globalize_path("res://qingxi-live/village-center/reports/"+name_+".png"))

func fence_sample():
 var layer=CanvasLayer.new();layer.layer=100;root.add_child(layer)
 var panel=ColorRect.new();panel.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
 panel.color=Color("a3b771");layer.add_child(panel)
 var script=preload("res://qingxi-live/village-center/fence_joint.gd")
 var size_=root.get_visible_rect().size
 for mask in 16:
  var joint=script.new();joint.connections=mask
  joint.position=Vector2((mask%4+.5)*size_.x/4,(floori(mask/4.0)+.65)*size_.y/4)
  panel.add_child(joint)
 await save_view("fence-connections");layer.queue_free()

func rotated_stair_check(bar):
 for turn in 4:
  w.player.position=Vector2(640,720);w.update_camera(true)
  if not w.build_mode:key_press(KEY_G)
  bar.equip(1,"stairs")
  # Layout rebuilds restore the default selection. Exercise the real R input.
  for i in turn:key_press(KEY_R)
  check(w.barn_stairs.preview_steps==turn,"R selects stair direction "+str(turn))
  var at=Vector2.ZERO
  for y in range(384,640,64):
   for x in range(192,1100,64):
    var candidate=Vector2(x,y)
    if w.barn_stairs.spot_clear(candidate,turn):at=candidate;break
   if at!=Vector2.ZERO:break
  if at==Vector2.ZERO:check(false,"find an empty staircase footprint");return
  check(w.barn_stairs.edit(at+Vector2(32,32),false)=="ok","place rotated stair "+str(turn))
  if w.barn_stairs.origin!=at:return
  var frame:Transform2D=w.barn_stairs.stair_transform(at,turn)
  var up:Vector2=w.barn_stairs.AXES[turn]
  key_press(KEY_G)
  w.player.position=frame*Vector2(32,126);w.portal_grace=0
  var previous=w.player.position
  w.move_actor(up*118);w.check_portals(previous)
  await process_frame;await process_frame
  check(w.map_id=="barn_up" and w.player.position==frame*Vector2(32,-32),"upstairs arrival points to chosen direction")
  if w.map_id!="barn_up":return
  w.portal_grace=0;previous=w.player.position
  w.move_actor(-up*63);w.check_portals(previous)
  await process_frame;await process_frame
  check(w.map_id=="barn" and w.player.position==frame*Vector2(32,100),"downstairs return points to chosen direction")
  if w.map_id!="barn":return
  w.player.position=Vector2(640,720)
  check(w.barn_stairs.edit(at+Vector2(32,32),true)=="ok","reclaim rotated staircase")
  w.barn_stairs.preview_steps=0

func staircase_check(bar):
 if not w.build_mode:key_press(KEY_G)
 bar.equip(1,"stairs")
 w.player.position=Vector2(672,633);w.update_camera(true)
 var stair_origin=Vector2(704,384)
 click_world(stair_origin+Vector2(31,31))
 check(w.barn_stairs.origin==stair_origin,"player places a two-cell stair")
 if w.barn_stairs.origin!=stair_origin:return
 if "--picture" in OS.get_cmdline_user_args():await save_view("meadow-build-stairs")
 key_press(KEY_G)
 w.player.position=stair_origin+Vector2(32,130);w.portal_grace=0
 var from=w.player.position
 w.move_actor(Vector2(0,-119))
 w.check_portals(from);await process_frame;await process_frame
 check(w.map_id=="barn_up" and w.player.position==Vector2(736,352),"walk up constructed stair to matching loft landing")
 if w.map_id!="barn_up":return
 check(w.placement.plan.tiles.is_empty() and w.blocked(Vector2(800,352)),"loft starts without floor")
 key_press(KEY_G)
 bar.equip(2,"wood_tile")
 click_world(Vector2(800,352))
 check(w.placement.supports(Vector2i(12,5)) and not w.blocked(Vector2(800,352)),"new wood square supports walking")
 check(w.placement.paint("stone_tile",Vector2(864,352),false)=="ok","place stone tile next to wood")
 check(w.placement.paint("wood_tile",Vector2(800,416),false)=="ok","extend the upper floor")
 check(w.placement.paint("wood_tile",Vector2(864,416),false)=="ok","support a furniture footprint")
 check(w.placement.edit_furniture("furn:chest",Vector2(800,416),false)=="ok","place a furniture item from the shared catalogue")
 check(w.placement.paint("wood_tile",Vector2(864,416),true)!="ok","cannot remove a floor supporting furniture")
 var to_third=Vector2(896,384)
 check(w.barn_stairs.edit(to_third,false)!="ok","upper stair requires a supporting floor")
 check(w.placement.paint("wood_tile",to_third+Vector2(32,96),false)=="ok","place the stair's supporting tile")
 check(w.barn_stairs.edit(to_third,false)=="ok","second floor can build its own stairs")
 check(w.placement.paint("wood_tile",to_third+Vector2(32,96),true)!="ok","support cannot be removed under stairs")
 w.travel("barn_floor_3")
 check(w.map_id=="barn_floor_3" and w.player.position==Vector2(928,352) and w.placement.plan.tiles.is_empty(),"third floor has its own landing and floor plan")
 var to_fourth=Vector2(1024,384)
 check(w.placement.paint("wood_tile",to_fourth+Vector2(32,96),false)=="ok","third floor can lay a supporting tile")
 check(w.barn_stairs.edit(to_fourth,false)=="ok","third floor can build stairs to a fourth floor")
 w.travel("barn_floor_4")
 check(w.map_id=="barn_floor_4" and not w.blocked(w.player.position),"fourth floor is reachable")
 w.travel("barn_floor_3")
 check(w.player.position==to_fourth+Vector2(32,100),"return from fourth floor to matching stair foot")
 w.travel("barn_up")
 w.player.position=stair_origin+Vector2(32,-32)
 if "--picture" in OS.get_cmdline_user_args():await save_view("meadow-build-loft")
 if w.build_mode:key_press(KEY_G)
 key_press(KEY_E);await process_frame;await process_frame
 check(w.map_id=="barn" and w.player.position.distance_to(stair_origin+Vector2(32,100))<1,"downstairs returns to stair foot")
 if w.map_id=="barn":
  check(not w.placement.plan.tiles.has("12:5") or w.placement.plan.tiles["12:5"]!="wood_tile","loft construction does not affect the lower floor")
  w.travel("barn_up")
  check(w.placement.supports(Vector2i(12,5)) and w.placement.nodes.size()==1 and bar.slots[1]=="stairs","re-enter to saved loft and toolbar")
  w.travel("barn")

func test_feeders():
 var kinds=["cow","sheep","pig","chicken"]
 for i in kinds.size():
  var kind:String=kinds[i]
  var pos=Vector2([288,480,800,992][i],672)
  check(w.barn_editor.edit("feeder_"+kind,pos,false)=="ok","place "+kind+" feeder inside")
  var targets=w.targets.filter(func(t):return t.kind=="pen" and t.extra==kind)
  if targets.is_empty():
   check(false,"feeder keeps its own species");continue
  w.action_target=targets.back();w.selected_cell=-1
  w.player.position=Vector2(targets.back().pos)   # 2026-11-19 Claude: stand at the feeder (the exit door is nearer otherwise)
  var food:String={"cow":"hay","sheep":"hay","pig":"pig_feed","chicken":"wheat"}[kind]
  w.sim.data.bag[food]=1;w.sim.livestock.data.pens[kind].feed=0.0
  key_press(KEY_E)
  check(w.open_menu=="pen" and w.overlay_body.get_child_count()==3,"feeder panel has just stock and add for "+kind)
  if w.overlay_body.get_child_count()!=3:w.close_menu();continue
  var add=w.overlay_body.get_child(2)
  check(add.text.contains(w.StateModel.ITEM_NAMES[food]),"matching feed label for "+kind)
  add.pressed.emit()
  check(w.sim.data.bag[food]==0 and w.sim.livestock.data.pens[kind].feed==86400.0,"deposit one portion for "+kind)
  check(w.overlay_body.get_child(1).text.contains("1.00") and w.overlay_body.get_child(2).disabled,"display new stock and empty backpack")
  w.close_menu()

func test_health():
 var herd=HerdRules.new()
 herd.visible_pasture=true
 var cow:Dictionary=herd.members("cow")[0]
 var sheep:Dictionary=herd.members("sheep")[0]
 var pig:Dictionary=herd.members("pig")[0]
 var chicken=herd.add("chicken")
 check([cow.hp,sheep.hp,pig.hp,chicken.hp]==[140.0,90.0,110.0,55.0],"distinct health per species")
 chicken.food=32;chicken.drink=100
 check(herd.care_status(chicken)=="饥饿","hunger warning before damage")
 herd.advance_step(600)
 check(chicken.hp==55.0,"moderate hunger does not damage health")
 chicken.food=100;chicken.drink=0
 check(herd.care_status(chicken)=="缺水","separate thirst warning")
 herd.advance_step(1800)
 var thirsty_loss=55.0-float(chicken.hp)
 chicken.hp=55.0;chicken.food=0
 check(herd.care_status(chicken)=="饥饿 · 缺水","combined warning")
 herd.advance_step(1800)
 check(55.0-chicken.hp>thirsty_loss,"combined deprivation deals more damage")
 chicken.food=95;chicken.drink=95
 var injured=float(chicken.hp)
 herd.advance_step(1800)
 check(chicken.hp>injured,"adequate food and water restore health")
 chicken.food=0;chicken.drink=0;chicken.hp=1
 herd.advance_health=false;herd.advance_step(1800)
 check(herd.animal(chicken.id).hp==1,"offline health protected")
 herd.advance_health=true;herd.advance_step(1800)
 check(herd.animal(chicken.id).is_empty() and herd.take_deaths().size()==1,"severe deprivation kills and removes animal")

func run():
 test_health()
 change_scene_to_file("res://qingxi-live/village-center/flat-build/meadow.tscn");await process_frame;await process_frame
 w=current_scene
 var rg=w.region;var terrain=w.ground_tiles
 check(w.open_meadow and not w.build_mode and w.edit_button.visible,"open land starts in walking mode")
 check(rg.ranch().edges.is_empty() and rg.layout.barn.is_empty() and w.fields.is_empty() and rg.props().size()==1 and str(rg.props()[0][3])=="gate_sign","no preset facilities (only the movable gate signpost, 2026-11-19)")
 check(not w.trees.is_empty() and w.herd_ai.actors.is_empty() and terrain.cells.is_empty(),"grass and trees only")
 check(not rg.data.on_road(Vector2(440,732)) and rg.data.creek_clearance(Vector2(1910,1060))>20,"old road and creek removed")
 if "--picture" in OS.get_cmdline_user_args():await picture("meadow-empty",true)
 await check_building_input()
 rg=w.region;terrain=w.ground_tiles
 w.edit_button.pressed.emit();check(w.build_mode,"edit button enters grid")
 var bar=w.hotbar
 check(bar.buttons.size()==9 and bar.entries.size()>30,"fixed hotbar with a larger catalog")
 bar.toggle_library();bar.filter_library("生活")
 check(bar.entries["prop:lantern"].visible and not bar.entries["barn_unit"].visible,"catalog categories")
 check(bar.accept_drop(Vector2.ZERO,{"meadow_item":"prop:lantern"}),"accept inventory drag")
 if "--picture" in OS.get_cmdline_user_args():
  for i in 5:await process_frame
  var from=bar.entries["prop:lantern"].get_global_rect().get_center()
  var to=bar.buttons[7].get_global_rect().get_center()
  mouse_move(from,from,false);mouse_button(from,true);mouse_move(from,from+Vector2(18,0),true)
  await process_frame
  mouse_move(from+Vector2(18,0),to,true);await process_frame;mouse_button(to,false);await process_frame
 else:bar.drop_on(Vector2.ZERO,{"meadow_item":"prop:lantern"},7)
 check(bar.slots.size()==9 and bar.slots[7]=="prop:lantern" and w.build_tool=="prop:lantern","drop replaces slot")
 bar.equip(8,"prop:bench");bar.close_library()
 var lamp=Vector2(1144,868);var bench=Vector2(1072,868)
 check(rg.put_prop("lantern",lamp)=="ok" and rg.lamps.has(lamp),"place functioning lantern")
 check(rg.put_prop("bench",bench)=="ok","place bench from catalog")
 w.player.position=lamp+Vector2(0,120);w.update_camera(true)
 bar.select(bar.slots.find("channel"))
 click_world(lamp-Vector2(0,28),MOUSE_BUTTON_RIGHT)
 check(not rg.lamps.has(lamp) and w.build_tool=="channel","right-click picks up another item with the river tool")
 w.toggle_build();w.action_target=w.targets.filter(func(t):return t.kind=="meadow_seat")[0];w.interact()
 check(w.seated,"bench supports sitting");w.interact();check(not w.seated,"stand up");w.toggle_build()
 var farm=Rect2(768,832,192,128)
 check(w.edit_plots(farm,false)==6 and w.fields.size()==6,"free-size field")
 w.player.position=w.fields[0].rect.get_center()
 w._physics_process(.016);w.toggle_build();w.interact()
 check(w.sim.data.crops[0].planted,"plant on the new meadow")
 w.toggle_build()
 check(w.edit_plots(farm,true)==5,"planted soil preserved during demolition")
 var oldfield=Rect2(832,832,64,64)
 check(w.edit_plots(oldfield,false)==1,"can reuse space")
 var long_line=area(8,17,16,1)
 check(terrain.edit("channel",long_line,false)=="ok" and terrain.deep.is_empty(),"sixteen canal cells stay shallow")
 var before_swim=w.player.position;w.player.position=Vector2(15.5,17.5)*64
 w.update_swim(.12,true)
 check(w.water_contact and not w.swimming and not w.swim_surface.moving,"one-cell channel uses wading")
 check(terrain.edit("channel",area(15,16,2,1),false)=="ok","widen the channel to two by two")
 w.update_swim(.12,true)
 check(w.swimming and not w.contact_shadow.visible and w.swim_surface.visible and w.portrait.texture is AtlasTexture,"two-by-two water uses dedicated swim frames")
 var front=w.portrait.texture
 w.facing=1;w.update_swim(.24,true)
 check(w.portrait.flip_h and w.portrait.texture!=front,"swim sheet turns and advances")
 if "--picture" in OS.get_cmdline_user_args():
  w.toggle_build();w.facing=2;w.update_swim(.18,true);w.update_camera(true)
  await save_view("meadow-swim")
  w.facing=0;w.update_swim(.16,true)
  await save_view("meadow-swim-front")
  w.toggle_build()
 w.player.position=before_swim;w.update_swim(.1,false)
 check(not w.swimming and w.contact_shadow.visible,"land restores walking stance")
 check(terrain.edit("channel",area(19,15,4,4),false)=="ok" and terrain.deep.size()==16,"four by four forms connected pond")
 check(w.blocked(Vector2(20.5,16.5)*64) and not w.blocked(Vector2(15.5,17.5)*64),"deep water blocks, creek is wadeable")
 check(terrain.edit("path",area(12,14,7,1),false)=="ok","player path alongside pond")
 check(terrain.edit("path",area(20,16,1,1),false)!="ok","no road over water")
 var id=str(terrain.basin[Vector2i(20,16)])
 terrain.tend(id);terrain.tend(id)
 check(terrain.state.stocks[id].count>0 and terrain.state.stocks[id].feed>0,"pond stocking and feeding")
 # 2026-11-19 Claude: the pond is joined to the 16-cell canal, and any connected water of 9+ cells
 # is fish water (round 2b), so only draining all of it may be refused while fish are in it.
 var all_water=area(19,15,4,4);all_water.merge(long_line)
 check(terrain.edit("channel",all_water,true)!="ok","stock survives attempted shallowing")
 var bp=Vector2(20.5,16.5)*64
 check(w.bridges.change(bp,false,1)=="ok" and not w.blocked(bp) and not w.water_at(bp),"bridge spans deep water with a dry deck")
 check(terrain.edit("channel",area(19,16,1,1),true)!="ok","cannot strand a bridge by filling its water")
 if "--picture" in OS.get_cmdline_user_args():
  w.edit_plots(Rect2(768,768,256,128),false)
  terrain.edit("channel",area(10,15,1,3),false)
  terrain.edit("path",area(11,13,1,2),false)
  await picture("meadow-grid",false)
  bar.toggle_library();bar.filter_library("生活");await picture("meadow-library",false);bar.close_library()
 check(w.bridges.change(bp,true,1)=="ok" and w.blocked(bp),"dismantled bridge restores water collision")
 var diagonal=terrain.topology({Vector2i(1,1):"channel",Vector2i(2,2):"channel"})
 check(diagonal.deep.is_empty(),"corner-touching channels stay shallow")
 var isolated=area(25,15,4,4)
 check(terrain.edit("channel",isolated,false)=="ok","second independent pond")
 var second=str(terrain.basin[Vector2i(25,15)])
 w.sim.data.bag.fry=2;terrain.tend(second)
 var link=area(23,16,2,1)
 check(terrain.edit("channel",link,false)!="ok","two stocked ponds cannot lose or mix fish")
 w.sim.data.bag.fish_feed+=1;terrain.tend(second);w.sim.advance_farm(w.sim.FISH_SECONDS);terrain.tend(second)
 check(terrain.edit("channel",link,false)=="ok" and terrain.state.stocks.size()==1,"join empty pond without duplicating fish")
 check(terrain.edit("channel",link,true)=="ok" and terrain.state.stocks.size()==1,"separate ponds retain one stock")
 check(terrain.edit("channel",isolated,true)=="ok","remove empty basin")
 var before=w.sim.data.bag.fish;w.sim.advance_farm(w.sim.FISH_SECONDS);terrain.tend(id)
 check(w.sim.data.bag.fish>before,"harvest")
 check(terrain.edit("channel",area(19,15,4,2),true)=="ok" and terrain.deep.is_empty(),"pond becomes creek after narrowing")
 check(terrain.edit("channel",long_line,true)=="ok","refill creek")
 check(w.edit_plots(Rect2(12*64,17*64,64,64),false)==1,"reclaimed creek becomes field")
 for x in range(23,28):
  rg.set_edge("h:%d:8"%x,"fence");rg.set_edge("h:%d:11"%x,"fence")
 for y in range(8,11):
  rg.set_edge("v:23:%d"%y,"fence");rg.set_edge("v:28:%d"%y,"fence")
 check(rg.place_feeder("cow",Vector2i(25,9))=="ok" and rg.enclosure_of("cow").cells.size()==15,"fences define pasture area")
 check(terrain.edit("channel",area(27,10,1,1),false)=="ok","make a watering spot in enclosure")
 var cow=w.sim.livestock.add("cow")
 check(w.sim.livestock.available(cow,"drink")==INF and rg.troughs.cow.drink!=Vector2.INF,"livestock use a reachable river bank")
 w.center_hour=12.0;w.light_preset=4
 cow.food=100; cow.drink=20
 w.refresh_life()
 w.herd_ai.finish_frame()
 var animal_target:Dictionary=w.targets.filter(func(t):return t.kind=="animal" and t.extra==cow.id)[0]
 check(animal_target.name.contains("缺水"),"nearby interaction identifies thirst")
 for i in 120:w.herd_ai.tick(.15)
 check(cow.drink>75 and w.herd_ai.drinking_spots.cow.size()>0,"thirsty cow walks to the bank and drinks")
 cow.food=20; cow.drink=95
 var unused=float(w.sim.livestock.data.pens.cow.feed)
 w.herd_ai.finish_frame()
 check(animal_target.name.contains("饥饿"),"nearby interaction identifies hunger")
 for i in 120:w.herd_ai.tick(.15)
 check(cow.food>70 and w.sim.livestock.data.pens.cow.feed<unused,"hungry cow walks to the feeder and consumes stock")
 w.sim.livestock.forget(cow);w.refresh_life()
 check(terrain.edit("channel",area(27,10,1,1),true)=="ok","remove watering spot")
 check(not w.sim.livestock.data.pens.cow.creek,"removing the river removes the drinking source")
 rg.set_edge("v:28:9","");check(not rg.home.has("cow"),"open fence changes pasture")
 var barn_pos=Vector2(12*64+32,9*64+60)
 check(w.change_barn(barn_pos,false)=="ok","place own barn")
 if w.region.layout.barn.is_empty():quit(1);return

 check(w.region.layout.barn.door==[barn_pos.x,barn_pos.y],"placed door follows barn")
 check(w.ui.map_viewport.world_2d==w.get_world_2d() and w.ui.map_bounds==w.world_bounds(),"live farm map shares the current scene")
 w.toggle_build()
 w.player.position=barn_pos+Vector2(-206,72);w.update_camera(true)
 w.portal_grace=0
 var outside=w.player.position
 w.move_actor(Vector2(60,0));w.check_portals(outside)
 check(not w.transition_pending,"walking across the yard outside the barn entrance stays outside")
 w.player.position=barn_pos+Vector2(-206,18)
 outside=w.player.position
 w.move_actor(Vector2(60,0));w.check_portals(outside)
 # 2026-11-19 Claude: doors are "press E" now; walking along the front must not enter.
 check(not w.transition_pending and w.map_id=="ranch","walking along the barn front does not enter by itself")
 check(not w.door_in_reach().is_empty(),"barn door is in reach from the front")
 w.interact()
 await process_frame;await process_frame
 check(w.map_id=="barn","E at the barn front enters the barn")
 if w.map_id!="barn":quit(1);return
 key_press(KEY_G);await process_frame
 check(w.build_mode and bar.visible and bar.slots[7]=="prop:lantern","barn uses shared slots")
 key_press(KEY_TAB);await process_frame
 check(bar.library.visible and bar.entries.has("furn:bed") and bar.entries.has("stairs"),"barn can open the shared library")
 bar.equip(0,"bedding");bar.close_library();key_press(KEY_1)
 w.player.position=Vector2(688,660);w.update_camera(true)
 var bed=w.barn_editor
 var cell=Vector2i(8,10);var bed_pos=w.region.cell_rect(cell).get_center();var key=bed.cell_key(cell)
 w.placement.plan.tiles.erase(key)
 click_world(bed_pos)
 check(w.placement.plan.tiles.get(key)=="bedding","mouse places a square of straw")
 check(bed.edit("fence",Vector2(640,576),false)!="ok","main aisle stays open")
 check(bed.edit("fence",Vector2(480,704),false)=="ok","place a barn partition")
 check(bed.edit("gate",Vector2(480,704),false)=="ok","replace partition with a gate")
 if "--picture" in OS.get_cmdline_user_args():await save_view("meadow-barn-editor")
 key_press(KEY_G);w.player.position=Vector2(677,762);w.portal_grace=0
 var inside=w.player.position
 w.move_actor(Vector2(0,26));w.check_portals(inside)
 await process_frame;await process_frame
 check(w.map_id=="ranch" and w.player.position.distance_to(barn_pos+Vector2(0,64))<1,"walk out at placed barn")
 w.player.position=barn_pos+Vector2(206,0);w.portal_grace=0
 var before_threshold=w.player.position;w.move_actor(Vector2(-60,0));w.check_portals(before_threshold)
 if not w.transition_pending:w.interact() # 2026-11-19 Claude: doors open with E
 await process_frame;await process_frame
 check(w.map_id=="barn" and w.barn_editor.plan.edges.get("h:7:11")=="gate" and w.placement.plan.tiles.get(key)=="bedding","wide walking entrance and persisted interior")
 w.set_light(21.0/24)
 check(w.lighting.flies==null,"no fireflies inside barn at night")
 check(w.audio.music_name=="music/meadow-quiet" and w.audio.stream(w.audio.music_name,true)!=null,"barn stays on calm farm music")
 test_feeders()
 await rotated_stair_check(bar)
 await staircase_check(bar)
 w.travel("ranch")
 check(w.change_barn(barn_pos-Vector2(0,32),true)=="ok" and w.region.layout.barn.is_empty(),"take barn back")
 var hd=Vector2(34*64+32,10*64+60)
 check(w.change_house(hd,false)=="ok","place cottage separately")
 if not w.region.saved().has("meadow_house"):quit(1);return
 for step in [["room_private",-1],["home",1]]:
  var portals=w.targets.filter(func(t):return t.kind=="portal" and t.extra==step[0])
  if portals.is_empty():check(false,"placed cottage has actual threshold");quit(1);return
  var offset=Vector2(0,step[1]*3);w.player.position=portals[0].pos-offset;w.portal_grace=0
  var previous=w.player.position;w.move_actor(offset*2);w.check_portals(previous)
  if not w.transition_pending:w.interact() # 2026-11-19 Claude: doors open with E
  await process_frame;await process_frame
  if step[0]=="room_private":
   check(w.map_id=="room_private" and w.placement.nodes.size()>1,"walk into placed cottage and load its existing furniture")
   key_press(KEY_G);await process_frame
   check(bar.visible and bar.slots[7]=="prop:lantern","private house keeps the same toolbar")
   key_press(KEY_TAB);await process_frame
   check(bar.library.visible and bar.entries.has("furn:stove"),"private house can open furniture library")
   if "--picture" in OS.get_cmdline_user_args():
    bar.filter_library("家具");await save_view("meadow-shared-furniture")
   bar.close_library()
   var placed=false
   for y in range(320,640,64):
    for x in range(320,960,64):
     if w.placement.edit_furniture("prop:lantern",Vector2(x+32,y+32),false)=="ok":
      placed=true;break
    if placed:break
   check(placed,"same outdoor lantern can be placed inside")
   if placed:
    var furniture_id=w.placement.plan.furniture.keys().back()
    var lamp_rect:Rect2=w.placement.nodes[furniture_id].draw
    bar.select(bar.slots.find("wood_tile"))
    w.player.position=Vector2(640,540);w.update_camera(true)
    click_world(lamp_rect.get_center(),MOUSE_BUTTON_RIGHT)
    check(not w.placement.nodes.has(furniture_id),"right-click removes furniture while using a floor tool indoors")
   key_press(KEY_G)
 check(w.map_id=="ranch" and w.player.position.distance_to(hd+Vector2(0,54))<1,"walk out at own cottage door")
 check(w.sim.save_to("user://meadow-check.json"),"save edits")
 var state=w.PastureState.new()
 check(state.load_from("user://meadow-check.json") and state.data.layout.meadow_ground.cells.has("12:14") and state.data.crops[0].planted,"layout and crops reload")
 check(state.data.layout.meadow_hotbar[7]=="prop:lantern" and state.data.layout.meadow_house==[hd.x,hd.y],"hotbar and buildings survive reload")
 w.show_map()
 var supplier=w.overlay_body.find_children("*","Button",true,false).filter(func(b):return b.text=="牧铃畜牧铺")
 check(supplier.size()==1,"farm map offers livestock supply store")
 if not supplier.is_empty():
  var hay=int(w.sim.data.bag.hay)
  var coins=int(w.sim.data.coins)
  supplier[0].pressed.emit();await process_frame;await process_frame;await process_frame
  var shop=current_scene
  check(shop.shop_title=="牧铃畜牧铺" and shop.from_meadow,"farm map opens shop against farm inventory")
  shop.transact("hay");shop.return_to_center();await process_frame;await process_frame;await process_frame
  w=current_scene
  check(w.sim.data.bag.hay==hay+1 and w.sim.data.coins==coins-3 and w.region.saved().has("meadow_house"),"feed purchase returns to existing farm bag and layout")
 w.show_map();var back=w.overlay_body.find_children("*","Button",true,false).filter(func(b):return b.text=="清溪村")
 check(back.size()==1,"return from meadow map")
 if back.size()>0:
  back[0].pressed.emit();await process_frame;await process_frame
  var city=current_scene;city.show_map()
  var enter=city.overlay_body.find_children("*","Button",true,false).filter(func(b):return b.text=="自家农场")
  check(enter.size()==1,"village map offers one farm destination")
  if enter.size()>0:
   enter[0].pressed.emit();await process_frame;await process_frame;await process_frame
   check(current_scene.get_meta("open_meadow",false) and current_scene.MAP_NAMES.ranch=="自家农场","normal map button opens the existing meadow scene")
 if "--picture" in OS.get_cmdline_user_args():await fence_sample()
 print("MEADOW_EDIT ", "PASS" if failures.is_empty() else "FAIL"," ",failures)
 quit(0 if failures.is_empty() else 1)

