extends SceneTree
const State=preload("res://qingxi-live/village-center/pasture_state.gd")
var world
var failures=[]
func check(ok:bool,message:String):
 if not ok:failures.append(message);push_error(message)
func _initialize():run.call_deferred()
func use_station(kind:String,extra:="")->bool:
 world.close_menu()
 for t in world.targets:
  if t.kind!=kind or (extra!="" and t.extra!=extra):continue
  world.player.position=t.pos
  world._physics_process(0.0)
  if world.blocked(t.pos) or world.action_target.get("kind","")!=kind or world.selected_cell>=0:continue
  if extra!="" and world.action_target.extra!=extra:continue
  world.interact()
  return true
 check(false,"unreachable interaction "+kind+" "+extra)
 return false
func press(title:String):
 for b in world.overlay_body.find_children("*","Button",true,false):
  if b.text==title and not b.disabled:
   b.pressed.emit()
   return
 check(false,"missing action "+title)
func run():
 change_scene_to_file("res://qingxi-live/village-center/main.tscn")
 await process_frame;await process_frame
 world=current_scene;world.set_physics_process(false)
 var s=world.sim
 s.data.bag.veg=1;s.data.bag.wheat=3
 if use_station("facility","watermill"):
  var old_feed=s.data.bag.pig_feed
  press("白菜 ×1 + 小麦 ×1 → 猪饲料 ×1")
  press("小麦 ×2 → 鱼饲料 ×1")
  check(s.data.bag.veg==0 and s.data.bag.wheat==0 and s.data.bag.pig_feed==old_feed+1,"mill recipe trade")
  s.mill_feed("pig_feed")
  check(s.data.bag.pig_feed==old_feed+1,"no free milling")
 check(not world.targets.any(func(t):return t.kind=="facility" and t.extra=="well"),"village well stays decorative without an action")
 world.travel("field")
 check(use_station("well"),"field well")
 var plot:Rect2=world.fields[0].rect
 world.player.position=plot.get_center()
 var near_count=0
 for i in world.fields.size():
  var r:Rect2=world.fields[i].rect
  var offset=(plot.get_center()-r.get_center()).abs()
  if offset.x<=64 and offset.y<=64:s.data.crops[i].planted=true;near_count+=1
 world.use_bag_item("well_water");world.close_menu()
 var wet=0
 for c in s.data.crops:
  if c.water>0:wet+=1
 check(near_count>=2 and wet==near_count and s.data.bag.well_water==2,"area watering")
 world.use_bag_item("well_water");world.close_menu()
 check(s.data.bag.well_water==2,"no charge for watered ground")
 if use_station("hive"):
  world.interact()
  check(s.data.bag.honey==1,"no repeated hive harvest")
  s.data.energy=80
  world.use_bag_item("honey");world.close_menu()
  check(s.data.bag.honey==0 and s.data.energy==92,"eat honey")
 world.travel("pond");s.data.bag.fish=2
 if use_station("dry_fish"):
  world.interact()
  check(s.data.bag.fish==1,"drying consumes one fish")
  world.advance_hour()
  var path="user://verify-farm-facilities.json"
  check(s.save_to(path),"save facilities")
  var copy=State.new()
  check(copy.load_from(path) and copy.data.farm_timers==s.data.farm_timers,"reload facilities")
  world.interact()
  check(s.data.bag.get("dried_fish",0)==1,"retrieve finished fish")
 world.travel("field")
 if use_station("hive"):check(s.data.bag.honey==1,"honey regrows away from field")
 s.data.bag["milk:q3"]=2
 if use_station("ship"):
  var before=s.data.coins
  # Select one specific lot among the buttons, keeping the remaining units.
  for b in world.overlay_body.find_children("*","Button",true,false):
   var row=b.get_parent();var idx=row.get_index()
   if b.text=="卖 1 件" and idx>0 and world.overlay_body.get_child(idx-1) is Label and "珍品 · 牛奶" in world.overlay_body.get_child(idx-1).text:
    b.pressed.emit();break
  check(s.data.bag["milk:q3"]==1 and s.data.coins==before+27 and s.data.bag.dried_fish==1,"partial graded sale")
 print("FARM_FACILITIES "+("PASS" if failures.is_empty() else "FAIL")+" "+JSON.stringify(failures))
 quit(0 if failures.is_empty() else 1)
