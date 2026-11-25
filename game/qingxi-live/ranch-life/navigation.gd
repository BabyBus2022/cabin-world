extends RefCounted
## Each fence is an edge, never a filled pasture cell. Graph and physics use the same edges.
const STEP=2.0
const MIN_CELL=Vector2i(-24,-24)
const MAX_CELL=Vector2i(23,27)
const CLEARANCE=.59
const FENCE_CLEARANCE=.56
var graph=AStar2D.new()
var obstacles:Array=[]
var edges:Dictionary={}
var blocked_fences:Array[Rect2]=[]
func cell(p:Vector2)->Vector2i:return Vector2i(floori(p.x/STEP),floori(p.y/STEP))
func center(c:Vector2i)->Vector2:return Vector2(c)*STEP+Vector2.ONE
func id(c:Vector2i)->int:return (c.y-MIN_CELL.y)*(MAX_CELL.x-MIN_CELL.x+1)+c.x-MIN_CELL.x
func edge_key(a:Vector2i,b:Vector2i)->String:
 if a.x>b.x or (a.x==b.x and a.y>b.y):return edge_key(b,a)
 return "%d,%d,%d,%d"%[a.x,a.y,b.x,b.y]
func endpoints(key:String)->Array:
 var n=key.split(",");return [Vector2i(int(n[0]),int(n[1])),Vector2i(int(n[2]),int(n[3]))]
func pick(p:Vector2)->String:
 var c=cell(p);var q=p/STEP-Vector2(c)
 if minf(q.x,1-q.x)<minf(q.y,1-q.y):
  var x=c.x+(1 if q.x>.5 else 0);return edge_key(Vector2i(x,c.y),Vector2i(x,c.y+1))
 var y=c.y+(1 if q.y>.5 else 0);return edge_key(Vector2i(c.x,y),Vector2i(c.x+1,y))
func fence_rect(key:String)->Rect2:
 var e=endpoints(key);var a=Vector2(e[0])*STEP;var b=Vector2(e[1])*STEP
 return Rect2(a.min(b),abs(b-a)).grow(.12)
func walkable(p:Vector2)->bool:
 for r in obstacles:
  if r.grow(CLEARANCE).has_point(p):return false
 return true
func clear_segment(a:Vector2,b:Vector2)->bool:
 for r in obstacles:
  if segment_box(a,b,r.grow(CLEARANCE)):return false
 for rect in blocked_fences:
  if segment_box(a,b,rect):return false
 return true
func segment_box(a:Vector2,b:Vector2,r:Rect2)->bool:
 if maxf(a.x,b.x)<r.position.x or minf(a.x,b.x)>r.end.x or maxf(a.y,b.y)<r.position.y or minf(a.y,b.y)>r.end.y:return false
 if r.has_point(a) or r.has_point(b):return true
 var corners=[r.position,Vector2(r.end.x,r.position.y),r.end,Vector2(r.position.x,r.end.y)]
 for i in 4:
  if Geometry2D.segment_intersects_segment(a,b,corners[i],corners[(i+1)%4])!=null:return true
 return false
func rebuild():
 blocked_fences.clear()
 for key in edges:
  if edges[key]!="open":blocked_fences.append(fence_rect(key).grow(FENCE_CLEARANCE))
 graph.clear()
 for y in range(MIN_CELL.y,MAX_CELL.y+1):
  for x in range(MIN_CELL.x,MAX_CELL.x+1):
   var c=Vector2i(x,y);var p=center(c)
   if walkable(p):graph.add_point(id(c),p)
 for point in graph.get_point_ids():
  var p=graph.get_point_position(point);var c=cell(p)
  for offset in [Vector2i(1,0),Vector2i(0,1)]:
   var next=c+offset
   if next.x>MAX_CELL.x or next.y>MAX_CELL.y:continue
   if graph.has_point(id(next)) and clear_segment(p,center(next)):graph.connect_points(point,id(next))
func nearest(p:Vector2)->int:
 var first=graph.get_closest_point(p)
 if first>=0 and clear_segment(p,graph.get_point_position(first)):return first
 var closest=-1
 var distance=INF
 var at=cell(p)
 for dy in range(-2,3):
  for dx in range(-2,3):
   var c=at+Vector2i(dx,dy)
   if c.x<MIN_CELL.x or c.x>MAX_CELL.x or c.y<MIN_CELL.y or c.y>MAX_CELL.y:continue
   var candidate=id(c)
   if not graph.has_point(candidate):continue
   var q=graph.get_point_position(candidate)
   var d=p.distance_squared_to(q)
   if d<distance and clear_segment(p,q):
    distance=d
    closest=candidate
 return closest
func path(a:Vector2,b:Vector2)->PackedVector2Array:
 if graph.get_point_count()==0:return PackedVector2Array()
 var start=nearest(a);var finish=nearest(b)
 if start<0 or finish<0:return PackedVector2Array()
 if clear_segment(a,b):return PackedVector2Array([b])
 var route=graph.get_point_path(start,finish)
 if route.is_empty():return route
 route.append(b)
 var smoothed=PackedVector2Array()
 var anchor=a
 var index=0
 while index<route.size():
  var last=index
  while last+1<route.size() and clear_segment(anchor,route[last+1]):last+=1
  anchor=route[last]
  smoothed.append(anchor)
  index=last+1
 return smoothed
