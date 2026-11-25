extends Node2D
const TOOLS=[["bedding","铺草"],["fence","围栏"],["gate","栅门"],["feeder_cow","牧场食槽"]]
const NORTH_AISLE=Rect2(576,250,128,582)
var world
var region
var plan:Dictionary
var feeders=[]
var bed_revision=0
var rest_cells:Array[Vector2i]=[]

func setup(host,inside_region):
 world=host;region=inside_region;z_index=-6
 var layout=region.saved()
 var level:int=world.barn_level(world.map_id)
 var plan_key="barn_interior" if level==1 else ("barn_interior_upper" if level==2 else "barn_interior_%d"%level)
 if level>1 and not layout.has(plan_key):
  layout[plan_key]={"straw":{},"edges":{},"feeders":{}}
 if not layout.has(plan_key):
  var straw={};var edges={};var feed={}
  for kind in region.layout.bays:
   var bay=region.layout.bays[kind]
   var x0=ceili(bay[0]/64.0);var y0=ceili(bay[1]/64.0)
   for y in range(y0,floori((bay[1]+bay[3])/64.0)):
    for x in range(x0,floori((bay[0]+bay[2])/64.0)):straw[cell_key(Vector2i(x,y))]=true
   var cell=Vector2i(floori((bay[0]+bay[2]*.5)/64),floori((bay[1]+28)/64))
   feed[cell_key(cell)]=kind
  for x in [2,3,4,5,6,7,12,13,14,15,16,17]:edges["h:%d:8"%x]="fence"
  layout[plan_key]={"straw":straw,"edges":edges,"feeders":feed}
 plan=layout[plan_key]
 rebuild()

func cell_key(c:Vector2i)->String:return "%d:%d"%[c.x,c.y]

func parse_cell(key:String)->Vector2i:return Vector2i(int(key.get_slice(":",0)),int(key.get_slice(":",1)))

func permitted(rect:Rect2)->bool:
 return Rect2(40,256,1200,542).encloses(rect) and not NORTH_AISLE.intersects(rect)

func floor_open(cell:Vector2i)->bool:
 if not permitted(region.cell_rect(cell)):return false
 var p=region.cell_rect(cell).get_center()
 for solid in world.solids:
  if solid.grow(8).has_point(p):return false
 return true

func edit(tool:String,p:Vector2,erase:bool)->String:
 if tool in ["fence","gate"]:
  var key=str(world.nearest_edge(p)[1])
  var r=region.fence_collision(key)
  if erase:
   if not plan.edges.erase(key):return ""
  else:
   if not permitted(r) or world.is_stair_opening(r):return "走道、门口和楼梯要留空"
   if world.barn_level(world.map_id)>1 and not world.placement.has_support(r):return "请先在围栏两侧铺好楼板"
   if plan.edges.get(key,"")==tool:return ""
   if tool=="fence" and r.grow(8).has_point(world.player.position):return "请先移出围栏位置"
   for item in feeders:
    if r.intersects(item.solid):return "请先移开食槽"
   plan.edges[key]=tool
 else:
  var cell=region.cell_of(p)
  var key=cell_key(cell)
  var group:Dictionary=plan.straw if tool=="bedding" else plan.feeders
  var bag:Dictionary=world.sim.data.bag
  if erase:
   if not group.has(key):return ""
   if tool!="bedding":
    var returned="feeder_cow"
    bag[returned]=int(bag.get(returned,0))+1
   group.erase(key)
  else:
   var r=region.cell_rect(cell)
   if not floor_open(cell) or world.is_stair_opening(r) or not world.placement.has_support(r):return "这里需要一格空的室内地面"
   if tool.begins_with("feeder_"):
    if region.cell_rect(cell).grow(10).has_point(world.player.position):return "请先走开再摆食槽"
    if int(bag.get(tool,0))==0:return "背包里没有可放的食槽"
    bag[tool]-=1
   group[key]=true if tool=="bedding" else tool.substr(7)
 rebuild()
 world.save_progress()
 return "ok"

func rebuild():
 region.clear_fence_nodes()
 region.draw_fences(plan.edges)
 for item in feeders:
  item.node.queue_free();world.solids.erase(item.solid);world.targets.erase(item.target)
 feeders.clear()
 for key in plan.feeders:
  var kind=str(plan.feeders[key])
  var pos=region.cell_rect(parse_cell(key)).get_center()+Vector2(0,11)
  var tex=region.tex("res://qingxi-live/village-center/art/regions/props/feeders/feeder_%s.png"%kind)
  var art=world.object(tex,pos,region.FEEDER_SIZE[kind],Rect2(),false)
  art.texture_filter=CanvasItem.TEXTURE_FILTER_NEAREST
  var solid=Rect2(pos-Vector2(24,15),Vector2(48,15));world.solids.append(solid)
  world.add_target("pen",pos+Vector2(0,24),world.sim.FEEDERS[kind],kind)
  feeders.append({"node":art.get_parent(),"solid":solid,"target":world.targets.back()})
 refresh_beds()

func refresh_beds():
 bed_revision+=1
 rest_cells.clear()
 if not is_instance_valid(world.placement):return
 for key in world.placement.plan.tiles:
  if world.placement.plan.tiles[key]!="bedding":continue
  var cell=parse_cell(key)
  if not world.blocked(region.cell_rect(cell).get_center()):rest_cells.append(cell)
 rest_cells.sort_custom(func(a,b):return a.y<b.y or (a.y==b.y and a.x<b.x))

func bed_spot(fallback:Vector2,taken:Array)->Vector2:
 var chosen=fallback;var best=INF
 for c in rest_cells:
  var p=region.cell_rect(c).get_center()+Vector2(0,8)
  if taken.any(func(other):return absf(other.x-p.x)<65 and absf(other.y-p.y)<30):continue
  if fallback.distance_squared_to(p)<best:chosen=p;best=fallback.distance_squared_to(p)
 if best<INF:return chosen
 # Keep the aisle clear even when all bedding is removed.
 for y in range(295,780,42):
  for x in range(84,1200,70):
   var p=Vector2(x,y)
   if NORTH_AISLE.has_point(p) or world.blocked(p):continue
   if taken.any(func(other):return absf(other.x-p.x)<65 and absf(other.y-p.y)<30):continue
   if fallback.distance_squared_to(p)<best:chosen=p;best=fallback.distance_squared_to(p)
 return chosen

func draw_preview(canvas:Node2D,m:Vector2):
 var rect=region.fence_collision(world.nearest_edge(m)[1]) if world.build_tool in ["fence","gate"] else region.cell_rect(region.cell_of(m)).grow(-2)
 var ok=permitted(rect)
 var tint=Color(.69,.94,.62,.65) if ok else Color(1,.42,.35,.65)
 canvas.draw_rect(rect,Color(tint,.25))
 canvas.draw_rect(rect,tint,false,2)

