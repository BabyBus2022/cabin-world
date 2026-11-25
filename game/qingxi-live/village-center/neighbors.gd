extends RefCounted
const ROUTES=[
 [Vector2(900,1515),Vector2(700,1515),Vector2(530,1515)],
 [Vector2(1550,1520),Vector2(1640,1460),Vector2(1710,1370)],
 [Vector2(2080,1260),Vector2(2150,1240),Vector2(2170,1220)],
 [Vector2(3250,1600),Vector2(3400,1620),Vector2(3500,1620)],
 [Vector2(1765,960),Vector2(1880,930),Vector2(1960,930)],
 [Vector2(1450,2440),Vector2(1630,2430),Vector2(1800,2430)]
]
const FRAME_SIZE=Vector2i(64,72)
const STRIDE_FRAMES=4
const ATLAS_COLUMNS=STRIDE_FRAMES+1
const GROUND=68.0
const WALK_SPEED=34.0
# The view foreshortens the steps towards and away from the camera.
const STRIDE_PX_SIDE=30.0
const STRIDE_PX_DEPTH=24.0
var world
var walk_sheet:Texture2D
var walk_frames={}
var actors=[]
var grid:AStarGrid2D
var scanned:=0
func _init(host):
 world=host
 walk_sheet=ImageTexture.create_from_image(Image.load_from_file("res://qingxi-live/village-center/art/jp/tuantuan-walk.png"))
func reset():actors.clear();grid=null
func spawn():
 grid=AStarGrid2D.new();grid.region=Rect2i(0,0,300,210);grid.cell_size=Vector2(16,16);grid.offset=Vector2(8,8);grid.diagonal_mode=AStarGrid2D.DIAGONAL_MODE_ONLY_IF_NO_OBSTACLES;grid.update()
 scanned=0
 for i in 6:
  var node=Node2D.new();node.position=ROUTES[i][0];world.scenery.add_child(node)
  var shadow=Polygon2D.new();world.shadow_root.add_child(shadow)
  var sprite=Sprite2D.new();sprite.centered=false;sprite.material=world.light_material();node.add_child(sprite)
  var tag=world.world_label("团团",Vector2.ZERO);tag.reparent(node);tag.position=Vector2(-64,-65)
  actors.append({"node":node,"sprite":sprite,"tag":tag,"shadow":shadow,"next":0,"pause":float(i),"phase":float(i)*.6,"mode":"day","path":PackedVector2Array(),"goal":node.position,"dancing":false,"direction":0,"walk_progress":0.0})
  var interaction={"kind":"villager","pos":node.position,"name":"团团 · 聊聊天","extra":str(i%3)}
  world.targets.append(interaction);actors.back().interaction=interaction
 tick(0)
func direction_of(step:Vector2,last:int)->int:
 if step.length_squared()<.001:return last
 if absf(step.x)>absf(step.y):return 1 if step.x<0 else 3
 return 2 if step.y<0 else 0

func walking_texture(role:int,direction:int,frame:int)->Texture2D:
 var row=role*4+direction
 var key=row*ATLAS_COLUMNS+frame
 if not walk_frames.has(key):
  var region=AtlasTexture.new()
  region.atlas=walk_sheet
  region.region=Rect2(Vector2(frame*FRAME_SIZE.x,row*FRAME_SIZE.y),Vector2(FRAME_SIZE))
  region.filter_clip=true
  walk_frames[key]=region
 return walk_frames[key]

func stride_frame(a:Dictionary,distance:float)->int:
 if distance<=.001:
  a.walk_progress=0.0
  return 0
 var phase:float=a.walk_progress
 var stride=STRIDE_PX_SIDE if a.direction in [1,3] else STRIDE_PX_DEPTH
 a.walk_progress=fposmod(phase+distance/stride,1.0)
 return 1+floori(phase*STRIDE_FRAMES)

# Build navigation in small slices; a clear short walk can start immediately.
func scan_paths():
 if not grid:return
 var until=Time.get_ticks_usec()+1700
 var cells=grid.region.size
 while scanned<cells.x*cells.y:
  var end=mini(scanned+32,cells.x*cells.y)
  while scanned<end:
   var cell=Vector2i(scanned%cells.x,scanned/cells.x)
   grid.set_point_solid(cell,world.blocked(Vector2(cell)*16+Vector2(8,8)))
   scanned+=1
  if Time.get_ticks_usec()>=until:break

func clear_walk(a:Vector2,b:Vector2)->bool:
 var steps=maxi(1,ceili(a.distance_to(b)/8))
 for i in range(1,steps+1):
  if world.blocked(a.lerp(b,float(i)/steps)):return false
 return true

func go(a:Dictionary,goal:Vector2):
 var start=Vector2i(((a.node.position-Vector2(8,8))/16).round())
 var end=Vector2i(((goal-Vector2(8,8))/16).round())
 a.goal=goal;a.path=PackedVector2Array()
 if clear_walk(a.node.position,goal):a.path.append(goal);return
 if scanned<grid.region.size.x*grid.region.size.y:return
 if not grid.is_in_boundsv(start) or not grid.is_in_boundsv(end) or grid.is_point_solid(end):return
 a.path=grid.get_point_path(start,end)
 if a.path.is_empty():return
 a.path.remove_at(0)
 if clear_walk(grid.get_point_position(end),goal):a.path.append(goal)
func tick(dt:float):
 scan_paths()
 for i in actors.size():
  var a:Dictionary=actors[i];a.phase+=dt
  var start:Vector2=a.node.position
  var gather=world.district.night_festival()
  var wanted="gather" if gather else "day"
  if a.mode!=wanted:
   a.mode=wanted
   go(a,world.district.dance_point(i*TAU/9) if gather else ROUTES[i][a.next])
  if gather and a.node.position.distance_to(world.qingxi.plaza)<150:
   var orbit=world.district.dance_point(i*TAU/9)
   if a.dancing or a.node.position.distance_to(orbit)<100:
    var step:Vector2=(orbit-a.node.position).limit_length(dt*54)
    if not world.blocked(a.node.position+step):
     a.node.position+=step;a.dancing=true
     a.direction=direction_of(step,a.direction)
   if a.dancing:a.path=PackedVector2Array()
  if not gather:a.dancing=false
  if not a.dancing and a.path.size()>0:
   var target:Vector2=a.path[0];var step=(target-a.node.position).limit_length(dt*WALK_SPEED)
   if not world.blocked(a.node.position+step):
    a.node.position+=step
    a.direction=direction_of(step,a.direction)
   else:
    a.path.clear();a.pause=.45+float(i)*.12
   if not a.path.is_empty() and a.node.position.distance_to(target)<2:a.path.remove_at(0)
  elif not a.dancing:
   a.pause-=dt
   if a.pause<=0:
    a.next=(a.next+1)%ROUTES[i].size();a.pause=3+i*.4
    var night=gather
    a.mode="gather" if night else "day"
    var goal=world.district.dance_point(i*TAU/9) if night else ROUTES[i][a.next]
    go(a,goal)
  var frame=stride_frame(a,start.distance_to(a.node.position))
  if a.dancing:
   a.walk_progress=0.0
   frame=1+floori(a.phase*8.0)%STRIDE_FRAMES
  var factor=60.0/FRAME_SIZE.x
  var hop=pow(maxf(0,sin(world.elapsed*TAU*104.0/60.0)),2)*4.0 if a.dancing else 0.0
  a.sprite.texture=walking_texture(i%3,a.direction,frame)
  a.sprite.scale=Vector2.ONE*factor
  a.sprite.position=Vector2(-FRAME_SIZE.x*.5*factor,-GROUND*factor-hop)
  a.sprite.rotation=0.0
  a.tag.visible=a.node.position.distance_to(world.player.position)<85
  # Same sun as the scenery: the shadow swings with the hour and stretches at dusk.
  var tip=world.sun_dir*world.sun_len*58.0
  a.shadow.polygon=PackedVector2Array([a.node.position+Vector2(-11,0),a.node.position+Vector2(11,0),a.node.position+tip+Vector2(8,0),a.node.position+tip+Vector2(-8,0)])
  a.shadow.color=world.shadow_ink
  a.interaction.pos=a.node.position
