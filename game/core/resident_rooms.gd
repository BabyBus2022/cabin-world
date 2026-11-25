extends RefCounted
const Village=preload("res://qingxi-live/village-center/qingxi_data.gd")
const Trial=preload("res://qingxi-live/village-center/flat-build/trial.gd")
const Stay=preload("res://qingxi-live/cottage_lodging.gd")
const Paddy=preload("res://qingxi-live/village-center/paddies.gd")
var inside={}
var leisure={}
const SPOTS={"tea_break":["facility","general_store"],"foot_bath":["facility","bathhouse"],"village_mill":["facility","watermill"],"village_well":["facility","well"],"plaza_lamp":["qingxi_lamp","0"],"plaza_bench":["qingxi_bench","0"],"festival_dance":["qingxi_fire",""],"talk_worker":["paddy",""]}
func nearby(scene,action:String,arg:String,start:Vector2):
 if not SPOTS.has(action):return null
 var row=SPOTS[action]
 var tag=str(row[1])
 if action in ["plaza_lamp","plaza_bench"] and arg.is_valid_int():tag=arg
 var closest=null
 for t in scene.targets:
  if str(t.kind)!=row[0] or (tag!="" and str(t.extra)!=tag):continue
  if action=="talk_worker" and str(t.extra)=="sign":continue
  if closest==null or start.distance_squared_to(t.pos)<start.distance_squared_to(closest):closest=t.pos
 return closest

func pose(host,who:String,v,dt:float):
 var action=leisure.get(who,{})
 if action.is_empty():return
 if action.until>0 and Time.get_ticks_msec()>action.until:
  leisure.erase(who);return
 if action.verb in ["farm_bench","swim"] and host.scene.get("map_id")=="ranch":
  v.tag.text=host._resident(who).display_name+(" · 游泳" if action.verb=="swim" else " · 坐在长凳上")
  v.sprite.position.y+=2*v.k if action.verb=="farm_bench" else (3+sin(Time.get_ticks_msec()*.005))*v.k
  return
 if host.scene.get("map_id")!="village":return
 if action.verb=="festival_dance" and host.scene.district.fire.lit:
  var target=host.scene.district.dance_point(action.phase)
  var delta=target-v.node.position
  if delta.length()>1:
   var next=v.node.position+delta.limit_length(95*dt)
   if not host.scene.blocked(next):v.node.position=next
   host.Work.animate(host._resident(who),v.sprite,delta,v.k)
  v.tag.text=host._resident(who).display_name+" · 篝火舞"
 elif action.verb=="plaza_bench":
  v.tag.text=host._resident(who).display_name+" · 坐在长凳上"
  v.sprite.position.y+=2*v.k

func village_act(host,who:String,action:String,arg:String,out:Dictionary)->String:
 var c=host._resident(who)
 if c==null or c.scene_id!=host.PLACE or c.want_zone!="qx_plaza" or c.is_walking():return "请先到清溪村广场。"
 var watching=host.active and is_instance_valid(host.scene) and host.scene.get("map_id")=="village"
 if action=="talk_worker":
  if watching:out.text=host.scene.paddies.talk("worker")
  else:out.text="团团：「%s」"%Paddy.TALK[host.season_index()].pick_random()
 elif action=="plaza_lamp":
  var farm=host._farm_sim()
  var modes=farm.sim.data.get("qingxi_lamps",[-1,-1,-1,-1]).duplicate()
  var i=int(arg)
  if arg!="" and not arg.is_valid_int() or i<0 or i>=modes.size():return "请选择 0 到 3 号灯笼。"
  modes[i]=(int(modes[i])+2)%3-1
  farm.sim.data.qingxi_lamps=modes
  if watching:host.scene.district.lamp_modes=modes.duplicate();host.scene.district.tick()
  host._farm_commit(farm)
  out.text="纸灯笼 %d · %s"%[i,{-1:"自动",0:"关闭",1:"打开"}[modes[i]]]
 else:
  if action=="festival_dance" and host.local_hour()>=5 and host.local_hour()<19:return "篝火庆典在晚上七点至清晨五点开放。"
  var angle=0.
  if watching and host.visitors.has(who):
   var delta=host.visitors[who].node.position-host.scene.qingxi.plaza
   angle=atan2(delta.y/108.,delta.x/125.)-host.scene.elapsed*.34
  leisure[who]={"verb":action,"phase":angle,"until":Time.get_ticks_msec()+30000}
  out.text="已加入篝火舞。" if action=="festival_dance" else "已坐到村口长凳休息。"
 return ""
var village=Village.new()

func names()->Dictionary:
 var list={}
 for h in village.buildings:
  if h.kind=="home":list["resident_"+str(h.id)]=h.name
 return list

func door(scene,arg:String):
 if scene.get("map_id")=="village":
  for h in village.buildings:
   if h.kind=="home" and arg in [str(h.id),str(h.name),"resident_"+str(h.id)]:return h.pos+Vector2(0,45)
 if scene.get("map_id")=="ranch":
  var l=scene.sim.data.get("layout",{})
  if arg.begins_with("barn") and l.has("meadow_barn"):
   var p=l.meadow_barn.base
   return Vector2(p[0],p[1])+Vector2(0,42)
  if l.has("meadow_house"):
   var p=l.meadow_house
   return Vector2(p[0],p[1])+Vector2(0,42)
 return null

func act(host,who:String,act_:String,arg:String,out:Dictionary)->String:
 var c=host._resident(who)
 if c==null or c.scene_id!=host.PLACE or c.is_walking():return "请先到清溪村对应地点。"
 var current=str(inside.get(who,""))
 if act_=="leave_room":
  inside.erase(who);out.text="已走到屋外。";return ""
 if act_=="visit_home":
  if c.want_zone!="qx_plaza":return "请先到村中心。"
  var houses=names()
  if arg=="":
   out.text="可以拜访："+ "、".join(houses.values());return ""
  var id=arg if houses.has(arg) else ("resident_"+arg if houses.has("resident_"+arg) else houses.find_key(arg))
  if id==null:return "没有这户人家。可选："+ "、".join(houses.values())
  inside[who]=id;out.text="已进入"+str(houses[id]);return ""
 if c.want_zone!="qx_farm":return "请先到自家农场。"
 var layout=host._farm_sim().sim.data.get("layout",{})
 if arg in ["room_private","room_private_up",Stay.DORM]:
  if not layout.has("meadow_house"):return "农场还没有私人小屋。"
  if arg==Stay.DORM and not Stay.data(host.profile_path(Stay.FILE)).get("expanded",false):return "宿舍还没有扩建。"
 else:
  var level=Trial.barn_level(arg)
  if level<1 or not layout.has("meadow_barn"):return "请选已建好的私人小屋或牧场屋。"
  if level>1 and (layout.get("barn_stair",[]) if level==2 else layout.get("barn_stairs",{}).get(Trial.barn_map(level-1),[])).is_empty():return "这层还没有楼梯。"
 inside[who]=arg
 out.text="已进入"+({"room_private":"私人小屋一楼","room_private_up":"私人小屋二楼","room_private_dorm":"多人宿舍"}.get(arg,"牧场屋第 %d 层"%Trial.barn_level(arg)))
 return ""
