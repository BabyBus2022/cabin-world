extends Node
## Operation executor only: all choices and autobiographical memory belong to the host resident.
const SCENE="world-restaurant"
var host:Control
var menu={}
var furniture={}
var dishes={}
var jobs={}
var reservations={}
var completed={}
var plates={}
var journal=""
var serial=0
var time_scale=1.0
func setup(main:Control):
 host=main
 menu=JSON.parse_string(FileAccess.get_file_as_string("res://assets/restaurant/menu.json"))
 furniture=JSON.parse_string(FileAccess.get_file_as_string("res://assets/restaurant/furniture.json"))
 for d in menu.dishes:
  dishes[d.id]=d
  Economy.catalog[d.id]={"id":d.id,"name":d.name,"price":d.price,"shelf":"restaurant","kind":"eat","satiety":d.get("satiety",40),"taste":d.get("sensory",d.name)}
 journal=Economy.save_path.get_base_dir().path_join("restaurant-operations.json")
 if FileAccess.file_exists(journal):
  var saved=JSON.parse_string(FileAccess.get_file_as_string(journal))
  if saved is Dictionary:
   completed=saved.get("completed",{})
   for actor in saved.get("pending",{}):
    var j:Dictionary=saved.pending[actor]
    var committed:bool=(j.id+"-commit") in Economy._seen
    completed[j.id]={"id":j.id,"actor":actor,"mode":j.mode,"dish":j.dish,"ok":committed,"finished":true,"status":"complete" if committed else "interrupted","at":SharedFeed.now_ms(),"recovered":true,"facts":facts(j) if committed else {},"error":"" if committed else "重启前操作未完成，不算已经吃饭或做菜"}
   _save()
 VadsLink.restaurant_requested.connect(handle)
func _save()->bool:
 var f=FileAccess.open(journal+".tmp",FileAccess.WRITE)
 if f==null:return false
 f.store_string(JSON.stringify({"pending":jobs,"completed":completed}));f.close()
 return DirAccess.rename_absolute(ProjectSettings.globalize_path(journal+".tmp"),ProjectSettings.globalize_path(journal))==OK
func resident(key:String):
 for c in host.characters:
  if c.key==key:return c
 return null
func room()->Dictionary:return WorldData.scenes.get(SCENE,{})
func zone_exists(zone:String)->bool:return room().get("zones",{}).has(zone)
func seat_candidates()->Array:return furniture.seats.filter(func(s):return room().modules.has(s.id) and zone_exists(s.zone) and room().modules.has(s.table))
func seat_occupied(seat:Dictionary,actor:String)->bool:
 if reservations.has(seat.id) and reservations[seat.id]!=actor:return true
 var point=WorldData.point(room().zones[seat.zone])
 for c in host.characters:
  if c.key==actor or c.scene_id!=SCENE:continue
  # Finishing a meal releases the operation, not the physical space. Keep
  # avoiding the chair while its previous diner is still actually there.
  if c.feet.distance_to(point)<24 or (not c.is_walking() and c.want_zone==seat.zone):return true
 return false
func reserve_seat(actor:String)->String:
 var seats=seat_candidates();var c=resident(actor);var occupied_tables={}
 for s in seats:
  if seat_occupied(s,actor):occupied_tables[s.table]=true
 var available=seats.filter(func(s):return not seat_occupied(s,actor))
 # Use the other tables before crowding an occupied one; then take a nearby
 # reachable chair. The metadata also follows furniture moved in the editor.
 available.sort_custom(func(a,b):
  var sa=(100000 if occupied_tables.has(a.table) else 0)+c.feet.distance_squared_to(WorldData.point(room().zones[a.zone]))
  var sb=(100000 if occupied_tables.has(b.table) else 0)+c.feet.distance_squared_to(WorldData.point(room().zones[b.zone]))
  return sa<sb)
 for s in available:
  if c.scene_id==SCENE and WorldData.nav(SCENE).route(c.feet,WorldData.point(room().zones[s.zone])).is_empty():continue
  reservations[s.id]=actor;return s.id
 return ""
func reserve(actor:String,slots:Array)->String:
 for slot in slots:
  if not reservations.has(slot):reservations[slot]=actor;return slot
 return ""
func release(actor:String):
 for slot in reservations.keys():
  if reservations[slot]==actor:reservations.erase(slot)
func busy(c)->bool:
 var b:Dictionary=Body.of(c.key).view(SharedFeed.now_ms())
 var body_action:bool=c.action not in ["","idle","chat","talk","think","thinking"]
 return c.sleeping or c.is_walking() or c.order_id!="" or (c.state==Character.State.DOING and body_action) or not Actions.current(c.key).get("id","").is_empty() or b.get("bed",{}).get("engaged",false) or b.get("computer",{}).get("chairOccupied",false) or (not c.effect.is_empty() and c._effect_seconds()<float(c.effect.get("seconds",0)) and c.effect.get("kind","") not in ["chat","talk","think","thinking"]) or body_action
func start(actor:String,mode:String,dish_id:String,request_id:String="")->Dictionary:
 if completed.has(request_id):return completed[request_id] if completed[request_id].actor==actor else {"ok":false,"error":"请求编号属于另一位住户"}
 var c=resident(actor)
 if c==null:return {"ok":false,"error":"没有这位住户"}
 if jobs.has(actor):return {"ok":false,"status":"busy","error":"正在完成已选择的操作"}
 if mode not in ["order","cook","eat","sit"]:return {"ok":false,"error":"未知操作"}
 if mode!="sit" and not dishes.has(dish_id):return {"ok":false,"error":"菜单没有这道菜"}
 if busy(c):return {"ok":false,"status":"busy","error":"正在做其他事情，餐厅操作没有打断它"}
 if mode in ["order","cook"] and Economy._bag_count(Economy._clean(Economy.people.get(actor,{})))>=int(Economy.limits.bagSlots):return {"ok":false,"error":"背包已满"}
 if mode=="eat" and int(Economy.people.get(actor,{}).get("bag",{}).get(dish_id,0))<1:return {"ok":false,"error":"尚未拿到这道菜"}
 var station="";var seat="";var steps=[]
 if mode in ["eat","sit"]:
  seat=reserve_seat(actor)
  if seat=="":return {"ok":false,"error":"暂时没有空座位"}
  var row:Dictionary=seat_candidates().filter(func(s):return s.id==seat)[0]
  if mode=="eat":steps.append({"zone":row.zone,"action":"place","seconds":1.5})
  steps.append({"zone":row.zone,"action":mode,"seconds":12.0 if mode=="sit" else float(dishes[dish_id].eat_seconds)})
 else:
  var slots=["order_a","order_b"]
  if mode=="cook":
   var method:String=dishes[dish_id].method
   slots=["oven"] if method=="oven" else ["fryer"] if dish_id=="restaurant-fried-chicken" else ["sushi"] if method=="prep" else ["cook_a","cook_b"]
  station=reserve(actor,slots.filter(zone_exists))
  if station=="":return {"ok":false,"error":"对应操作台被占用或已收起"}
  steps.append({"zone":station,"action":mode,"seconds":float(dishes[dish_id].cook_seconds) if mode=="cook" else float(dishes[dish_id].order_seconds)})
 serial+=1
 var id=request_id if request_id!="" else "restaurant-"+actor+"-"+str(Time.get_ticks_usec())+"-"+str(serial)
 jobs[actor]={"id":id,"actor":actor,"mode":mode,"dish":dish_id,"seat":seat,"station":station,"steps":steps,"index":-1,"phase":"accepted","left":0.0,"age":0.0,"at":SharedFeed.now_ms()}
 if not _save():release(actor);jobs.erase(actor);return {"ok":false,"error":"操作记录保存失败，未开始"}
 c.restaurant_owner=id;_next(actor)
 return completed.get(id,{"ok":true,"id":id,"status":"accepted","mode":mode,"dish":dish_id})
func _next(actor:String):
 var j:Dictionary=jobs[actor];j.index+=1
 if j.index>=j.steps.size():finish(actor);return
 var step:Dictionary=j.steps[j.index];var c=resident(actor)
 if not zone_exists(step.zone):cancel(actor,"对应家具已收起");return
 var p=WorldData.point(room().zones[step.zone])
 if c.scene_id==SCENE and WorldData.nav(SCENE).route(c.feet,p).is_empty():cancel(actor,"操作位置不可到达");return
 j.phase="walk";j.left=step.seconds
 c.walk_order({"id":j.id+"-walk-"+str(j.index),"actor":actor,"scene":SCENE,"zone":step.zone,"restaurantOwner":j.id})
 c.restaurant_effect={"kind":"restaurant_carry","dish":j.dish,"at":SharedFeed.now_ms(),"seconds":180} if j.mode=="eat" and j.index==0 else {}
 _save();_progress(actor)
func _arrived(actor:String):
 var j:Dictionary=jobs[actor];var step:Dictionary=j.steps[j.index];var c=resident(actor)
 j.phase=step.action
 c.restaurant_effect={"kind":"sit" if step.action=="sit" else "restaurant_"+step.action,"seconds":step.seconds+5,"at":SharedFeed.now_ms(),"facing":room().get("actionFacings",{}).get(step.zone,"north"),"seat":j.seat,"dish":j.dish}
 if step.action in ["place","eat","sit"]:
  var chair:Dictionary=room().modules[j.seat]
  c.restaurant_effect.facing=chair.get("sitting",{}).get("slots",{}).get("only",{}).get("facing",seat_candidates().filter(func(s):return s.id==j.seat)[0].facing)
 if step.action=="order":_npc("greet",actor)
 _save();_progress(actor)
func _step_done(actor:String):
 var j:Dictionary=jobs[actor];var step:Dictionary=j.steps[j.index]
 if step.action=="place":_plate(actor,j)
 if step.action in ["order","cook","eat"]:
  var result=Economy._answer({"id":j.id+"-commit","actor":actor,"op":"buy" if step.action=="order" else "gift_in" if step.action=="cook" else "consume","product":j.dish,"kind":"eaten","space":"restaurant","who":Residents.person(actor).get("flavor","unknown")})
  if not result.ok:cancel(actor,result.get("error","保存失败"));return
  if step.action=="order":_npc("give",actor)
 _next(actor)
func facts(j:Dictionary)->Dictionary:
 var d:Dictionary=dishes.get(j.dish,{})
 return {"operation":j.mode,"energyKcal":d.get("energyKcal",0),"portion":d.get("portion","一份"),"dishName":d.get("name",""),"ingredients":d.get("ingredients",[]),"process":d.get("process",[]),"simulatedSensory":d.get("sensory",""),"foodInBag":j.mode in ["cook","order"],"consumed":j.mode=="eat","note":"食物特性是游戏模拟资料；好恶由原住户自己表达，没吃过不能算已用餐"}
func finish(actor:String):
 var j:Dictionary=jobs[actor]
 var r={"ok":true,"actor":actor,"id":j.id,"mode":j.mode,"dish":j.dish,"status":"complete","finished":true,"at":SharedFeed.now_ms(),"facts":facts(j)}
 completed[j.id]=r;_clear(actor);_save();VadsLink.send(r.merged({"type":"restaurant.result"}))
func cancel(actor:String,reason:String="操作中止，未吃掉的菜仍在背包"):
 if not jobs.has(actor):return
 var j:Dictionary=jobs[actor]
 completed[j.id]={"ok":false,"actor":actor,"id":j.id,"mode":j.mode,"dish":j.dish,"status":"interrupted","finished":true,"at":SharedFeed.now_ms(),"error":reason}
 _clear(actor);_save();VadsLink.send(completed[j.id].merged({"type":"restaurant.result"}))
func _clear(actor:String):
 var j:Dictionary=jobs[actor];var c=resident(actor)
 if c!=null:
  if c.restaurant_owner==j.id:c.restaurant_owner="";c.restaurant_effect={}
  if c.order_id.begins_with(j.id+"-walk-"):
   c.route.clear();c.state=Character.State.IDLE;c.order_id="";c.want_scene=c.scene_id;c.want_zone="";c.next_scene="";c.target=c.feet
 if plates.has(actor):
  if is_instance_valid(plates[actor]):plates[actor].queue_free()
  plates.erase(actor)
 release(actor);jobs.erase(actor)
func _progress(actor:String):VadsLink.send({"type":"restaurant.progress","actor":actor,"job":jobs[actor]})
func _npc(pose:String,actor:String):
 for n in host.rooms[SCENE].get_children():
  if n.get_script()!=null and n.get_script().resource_path.ends_with("service_npc.gd"):
   n.jobs.append({"pose":pose,"actor":actor})
func _plate(actor:String,job:Dictionary):
 if plates.has(actor) and is_instance_valid(plates[actor]):plates[actor].queue_free()
 var s=seat_candidates().filter(func(row):return row.id==job.seat)[0]
 var t:Dictionary=room().modules.get(s.table,{})
 if t.is_empty():return
 var sprite=Sprite2D.new();sprite.centered=false;sprite.region_enabled=true
 var r:Array=dishes[job.dish].region;sprite.texture=load(menu.sheet);sprite.region_rect=Rect2(r[0],r[1],r[2],r[3])
 sprite.scale=Vector2(26/r[2],22/r[3])
 var at=Vector2(t.x+t.w*.5-13,t.y+6)
 var direction:String=s.facing
 if direction=="east":at.x=t.x+8
 elif direction=="west":at.x=t.x+t.w-34
 elif direction=="north":at.y=t.y+minf(t.h*.45,32)
 sprite.position=Vector2(at.x,t.depth+0.1)
 sprite.offset=Vector2(0,(at.y-sprite.position.y)/sprite.scale.y)
 host.rooms[SCENE].add_child(sprite);plates[actor]=sprite
func _physics_process(delta:float):
 for actor in jobs.keys():
  var c=resident(actor);var j:Dictionary=jobs[actor]
  if c==null or c.restaurant_owner!=j.id:cancel(actor,"已开始其他行动，未清除新行动");continue
  if c.sleeping or not Actions.current(actor).get("id","").is_empty():c.restaurant_owner="";c.restaurant_effect={};cancel(actor,"正在响应其他活动");continue
  j.age+=delta
  if j.age>180:cancel(actor,"未能完成操作，停止等待");continue
  var step:Dictionary=j.steps[j.index]
  if not zone_exists(step.zone):cancel(actor,"操作位置已收起");continue
  if c.want_scene!=SCENE or c.want_zone!=step.zone:cancel(actor,"位置或行动已改变");continue
  if j.phase=="walk":
   if c.scene_id==SCENE and not c.is_walking() and c.feet.distance_to(WorldData.point(room().zones[step.zone]))<20:_arrived(actor)
  else:
   if c.scene_id!=SCENE or c.is_walking():cancel(actor,"操作位置已改变");continue
   j.left-=delta*time_scale
   if j.left<=0:_step_done(actor)
func handle(frame:Dictionary):
 var action:String=frame.get("action","menu");var actor:String=frame.get("actor","");var reply:Dictionary
 if action=="menu":reply={"ok":true,"dishes":menu.dishes,"seats":seat_candidates(),"scene":SCENE,"description":room().description,"zones":room().zones,"modules":room().modules}
 elif action=="status":reply={"ok":true,"job":jobs.get(actor,{}),"completed":completed.values().filter(func(r):return r.actor==actor)}
 elif action=="cancel":cancel(actor);reply={"ok":true}
 else:reply=start(actor,action,str(frame.get("dish","")),str(frame.get("id","")))
 VadsLink.send(reply.merged({"type":"restaurant.result","id":frame.get("id",""),"actor":actor}))
