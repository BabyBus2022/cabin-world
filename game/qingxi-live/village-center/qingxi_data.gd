extends RefCounted
## Plan coordinates remain immutable; enlarge distances, not the character.
const SCALE=1.5
const SIZE=Vector2(4800,3360)
var plan:Dictionary
var roads=[]
var buildings=[]
var bridges=[]
var exits=[]
var creek=PackedVector2Array()
var canal=PackedVector2Array()
var plaza=Vector2(1770,1500)
var radius=300.0
func point(a)->Vector2:return Vector2(a[0],a[1])*SCALE
func points(a)->PackedVector2Array:
 var result=PackedVector2Array()
 for p in a:result.append(point(p))
 return result
var creek_block=72.0
var canal_block=30.0
func _init():
 plan=JSON.parse_string(FileAccess.get_file_as_string("res://qingxi-live/village-center/plan/VILLAGE_PLAN.json"))
 # Roads, water and bridges come from the baked ground (village-center/tools/bake_ground.py),
 # so walking, collision and the painted ground always agree.
 var geo=JSON.parse_string(FileAccess.get_file_as_string("res://qingxi-live/village-center/art/jp/geometry.json"))
 creek=to_line(geo.creek.points);creek_block=float(geo.creek.block)
 canal=to_line(geo.canal.points);canal_block=float(geo.canal.block)
 plaza=Vector2(geo.plaza.center[0],geo.plaza.center[1]);radius=float(geo.plaza.radius)
 for source in geo.roads:roads.append({"id":source.id,"width":float(source.width),"style":source.style,"points":to_line(source.points)})
 for source in geo.bridges:
  var horizontal=absf(float(source.dir[0]))>.5
  var span=Vector2(source.length,source.width) if horizontal else Vector2(source.width,source.length)
  bridges.append({"id":str(source.road)+"_"+str(source.over),"style":source.style,"pos":Vector2(source.center[0],source.center[1]),"size":span,"vertical":not horizontal})
  bridges[-1]["slope"]=0.0   # bridges sit square to the road; the art spans bank to bank
 for source in plan.buildings:
  var b=source.duplicate(true);b.pos=Vector2(b.x,b.door_y)*SCALE
  if b.id=="watermill":b.pos.y-=48
  buildings.append(b)
 for source in plan.exits:
  var e=source.duplicate(true);e.pos=point(e.pos);exits.append(e)
 fields=Image.load_from_file("res://qingxi-live/village-center/art/jp/fields.png")
## Baked lookup (tools/bake_ground.py): R road distance, G water block, B creek-edge distance; texels of 2 world px.
var fields:Image
func field(p:Vector2)->Color:
 var x=clampi(int(p.x/2),0,fields.get_width()-1);var y=clampi(int(p.y/2),0,fields.get_height()-1)
 return fields.get_pixel(x,y)
func creek_clearance(p:Vector2)->float:return field(p).b8*2.0
func to_line(a)->PackedVector2Array:
 var result=PackedVector2Array()
 for p in a:result.append(Vector2(p[0],p[1]))
 return result
func distance_to_line(p:Vector2,line:PackedVector2Array)->float:
 var best=INF
 for i in range(line.size()-1):best=minf(best,p.distance_to(Geometry2D.get_closest_point_to_segment(p,line[i],line[i+1])))
 return best
func on_bridge(p:Vector2)->bool:
 for b in bridges:
  var local=p-b.pos;local.y-=float(b.get("slope",0.0))*local.x
  if Rect2(-b.size/2,b.size).grow(-8).has_point(local):return true
 return false
func water_blocks(p:Vector2)->bool:
 if p.x<0 or p.y<0 or p.x>=SIZE.x or p.y>=SIZE.y:return false
 for b in bridges:
  var slope=float(b.get("slope",0.0))
  if is_zero_approx(slope):continue
  var local=p-b.pos
  if absf(local.x)<b.size.x/2:
   if absf(local.y-slope*local.x)<b.size.y/2-8:return false
   if absf(local.y)<b.size.y/2:return true
 return field(p).g8>127
func wade_at(p:Vector2)->bool:
 return field(p).g8==192 and not on_bridge(p)

func on_road(p:Vector2,margin=0.0)->bool:
 return field(p).r8*2.0<=margin
