extends Node2D
const Grid=preload("res://qingxi-live/village-center/placement_grid.gd")
const AXES=[Vector2.UP,Vector2.RIGHT,Vector2.DOWN,Vector2.LEFT]
const NAMES=["北","东","南","西"]
const FLIGHT=Rect2(0,0,64,128)
const LANDING=Rect2(0,-64,64,64)
const FOOT=Rect2(0,64,64,64)
var world
var level:int
var origin:=Vector2.ZERO
var rotation_steps=0
var below:=Vector2.ZERO
var below_steps=0
var preview_steps=0
var stairs:=[]

func setup(host):
 world=host;level=world.barn_level(world.map_id)
 z_index=-5
 var current=saved_stair(level)
 var previous=saved_stair(level-1)
 if current.size()>=2:
  origin=Vector2(current[0],current[1]);rotation_steps=stored_rotation(current)
  connect_stair(origin,rotation_steps,false)
 if previous.size()>=2:
  below=Vector2(previous[0],previous[1]);below_steps=stored_rotation(previous)
  connect_stair(below,below_steps,true)

func saved_stair(floor_:int)->Array:
 if floor_<1:return []
 var layout:Dictionary=world.layout_save()
 return layout.get("barn_stair",[]) if floor_==1 else layout.get("barn_stairs",{}).get(world.barn_map(floor_),[])

static func stored_rotation(saved:Array)->int:
 return posmod(int(saved[2]),4) if saved.size()>=3 else 0

static func stair_transform(at:Vector2,steps:int)->Transform2D:
 var axis:Vector2=AXES[steps]
 var across=Vector2(-axis.y,axis.x)
 return Transform2D(across,-axis,at+Vector2(32,32)-(across-axis)*32.0)

func rotate_preview():
 preview_steps=(preview_steps+1)%4

func direction_name()->String:return NAMES[preview_steps]

func arrival(from_below:bool)->Vector2:
 if from_below:return stair_transform(below,below_steps)*LANDING.get_center()
 return stair_transform(origin,rotation_steps)*Vector2(32,100)

func walkable(p:Vector2)->bool:
 if below!=Vector2.ZERO:
  var local=stair_transform(below,below_steps).affine_inverse()*p
  if Rect2(0,-64,64,95).has_point(local):return true
 return origin!=Vector2.ZERO and FLIGHT.has_point(stair_transform(origin,rotation_steps).affine_inverse()*p)

func opening_intersects(r:Rect2)->bool:
 return (origin!=Vector2.ZERO and (stair_transform(origin,rotation_steps)*FLIGHT).intersects(r)) or (below!=Vector2.ZERO and (stair_transform(below,below_steps)*FLIGHT.merge(LANDING)).intersects(r))

func elevation(p:Vector2)->float:
 if origin==Vector2.ZERO:return 0.0
 var local=stair_transform(origin,rotation_steps).affine_inverse()*p
 return clampf((128.0-local.y)*.22,0,26) if FLIGHT.has_point(local) else 0.0

func has_connection(id:String)->bool:
 return stairs.any(func(stair):return stair.portal.extra==id)

func connect_stair(at:Vector2,steps:int,down:bool):
 var frame=stair_transform(at,steps)
 var rails=[frame*Rect2(0,0,5,128),frame*Rect2(59,0,5,128)]
 world.solids.append_array(rails)
 var dst:String=world.barn_map(level-1 if down else level+1)
 world.add_target("portal",frame*Vector2(32,17),("下楼" if down else "上楼"),dst)
 var target:Dictionary=world.targets.back()
 target.merge({"stair_axis":AXES[steps],"down":down,"stairs":true})
 stairs.append({"rails":rails,"portal":target,"down":down})
 queue_redraw()

func edit(p:Vector2,erase:bool)->String:
 var layout:Dictionary=world.layout_save()
 if erase:
  if origin==Vector2.ZERO:return ""
  var steps=stair_transform(origin,rotation_steps)*FLIGHT
  if not steps.grow(4).has_point(p):return ""
  if steps.grow(12).has_point(world.player.position):return "先走下楼梯再收回"
  for i in stairs.size():
   if stairs[i].down:continue
   for solid in stairs[i].rails:world.solids.erase(solid)
   world.targets.erase(stairs[i].portal);stairs.remove_at(i);break
  if level==1:layout.erase("barn_stair")
  else:layout.barn_stairs.erase(world.map_id)
  preview_steps=rotation_steps
  origin=Vector2.ZERO
 else:
  if origin!=Vector2.ZERO:return "这一层已有上行楼梯，可右键收回再改位置"
  var at=Grid.tile(Grid.cell(p)).position
  if not spot_clear(at,preview_steps):return "下端需要楼板，楼梯占两格，上一层出口留一格"
  origin=at;rotation_steps=preview_steps
  var saved=[at.x,at.y,rotation_steps]
  if level==1:layout.barn_stair=saved
  else:layout.get_or_add("barn_stairs",{})[world.map_id]=saved
  connect_stair(origin,rotation_steps,false)
 world.save_progress();queue_redraw();return "ok"

func spot_clear(at:Vector2,steps:int)->bool:
 var frame=stair_transform(at,steps)
 var flight=frame*FLIGHT
 var landing=frame*LANDING
 if world.placement.occupied(flight,true) or opening_intersects(flight):return false
 if not world.placement.bounds.encloses(landing):return false
 if not world.placement.has_support(frame*FOOT):return false
 var next_id:String=world.barn_map(level+1)
 var opening=flight.merge(landing)
 var next_plan:Dictionary=world.layout_save().get("placement_by_map",{}).get(next_id,{})
 for key in next_plan.get("tiles",{}):
  if Grid.tile(Grid.coord(key)).intersects(opening):return false
 for furniture in next_plan.get("furniture",{}).values():
  if world.placement.footprint(str(furniture[0]),Vector2(furniture[1],furniture[2])).intersects(opening):return false
 var next_stair=saved_stair(level+1)
 return next_stair.is_empty() or not (stair_transform(Vector2(next_stair[0],next_stair[1]),stored_rotation(next_stair))*FLIGHT).intersects(opening)

func draw_preview(canvas:Node2D,p:Vector2):
 if origin!=Vector2.ZERO:
  var flight=stair_transform(origin,rotation_steps)*FLIGHT
  if flight.has_point(p):canvas.draw_rect(flight,Color("f6d592"),false,2)
  return
 var at=Grid.tile(Grid.cell(p)).position
 var frame=stair_transform(at,preview_steps)
 var tint=Color("b4e386") if spot_clear(at,preview_steps) else Color("db795f")
 canvas.draw_rect(frame*FLIGHT,Color(tint,.30))
 canvas.draw_rect(frame*FLIGHT,tint,false,2)
 canvas.draw_rect(frame*LANDING,tint,false,2)
 canvas.draw_line(frame*Vector2(18,28),frame*Vector2(32,12),tint,3)
 canvas.draw_line(frame*Vector2(32,12),frame*Vector2(46,28),tint,3)

func _draw():
 if below!=Vector2.ZERO:
  var top=stair_transform(below,below_steps)*LANDING
  draw_texture_rect(world.placement.materials.wood_tile,top,false)
  draw_rect(top.grow(-2),Color("664630"),false,3)
  draw_flight(below,below_steps,true)
 if origin!=Vector2.ZERO:draw_flight(origin,rotation_steps,false)

## 2026-11-19 Claude: redrawn barn staircase (same footprint, rails and portals).
## Going up (this floor): a soft shadow, eight treads with a nosing highlight over a dark
## riser and a little grain, side strings with balusters and a handrail, newel posts top
## and bottom. Going down (seen from the loft): a dark well, the first treads fading
## into it, and railings on the two long sides and the far end so it reads as an opening.
## In the stair's own frame x = across (0..64), y = along the flight (0 = top, 128 = foot).
const STAIR_DARK=Color("4a2e20")
const STAIR_POST=Color("6b4330")
const STAIR_RAIL=Color("c99258")
const STAIR_BALUSTER=Color("e3c08b")
func draw_flight(at:Vector2,steps:int,down:bool):
 draw_set_transform_matrix(stair_transform(at,steps))
 if down:
  draw_rect(FLIGHT,Color("1c1411"))
  for step in 4:
   var tone=Color("b98754").darkened(.16+step*.18)
   var r=Rect2(7,step*16+2,50,12)
   draw_rect(r,tone);draw_rect(Rect2(r.position,Vector2(50,2)),tone.lightened(.12))
  draw_rect(Rect2(6,0,52,3),Color("e2b27c"))   # lip of the loft floor
  for x in [0,58]:
   draw_rect(Rect2(x,0,6,128),STAIR_DARK)
   for y in range(8,124,14):draw_rect(Rect2(x+1,y,4,6),STAIR_BALUSTER)
   draw_rect(Rect2(x+(4 if x==0 else 0),0,2,128),STAIR_RAIL)
  draw_rect(Rect2(0,122,64,6),STAIR_DARK)
  for x in range(8,58,14):draw_rect(Rect2(x,123,6,4),STAIR_BALUSTER)
  draw_rect(Rect2(0,122,64,2),STAIR_RAIL)
  for p in [Vector2(3,3),Vector2(61,3),Vector2(3,125),Vector2(61,125)]:stair_post(p)
 else:
  draw_rect(Rect2(6,8,62,124),Color(0,0,0,.18))   # shadow on the floor
  draw_rect(FLIGHT,STAIR_DARK)
  for step in 8:
   var y=step*16
   var tone=Color("c49058").darkened(step*.035)
   draw_rect(Rect2(6,y,52,16),Color("5c3a28"))        # riser
   draw_rect(Rect2(6,y,52,11),tone)                    # tread
   draw_rect(Rect2(6,y,52,2),tone.lightened(.18))      # nosing
   draw_rect(Rect2(12+(step*19)%30,y+5,9,2),tone.darkened(.12))   # grain
  for x in [0,58]:
   draw_rect(Rect2(x,0,6,128),STAIR_POST)
   for y in range(6,122,16):draw_rect(Rect2(x+1,y,4,7),STAIR_BALUSTER)
   draw_rect(Rect2(x+(4 if x==0 else 0),0,2,128),STAIR_RAIL)
  for p in [Vector2(3,3),Vector2(61,3),Vector2(3,124),Vector2(61,124)]:stair_post(p)
 draw_set_transform_matrix(Transform2D.IDENTITY)
func stair_post(c:Vector2):
 draw_rect(Rect2(c-Vector2(6,6),Vector2(12,12)),Color("4a2e20"))
 draw_rect(Rect2(c-Vector2(4,4),Vector2(8,8)),Color("8f603d"))
 draw_rect(Rect2(c-Vector2(4,4),Vector2(8,2)),STAIR_RAIL)

