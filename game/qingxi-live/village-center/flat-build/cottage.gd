extends Node2D
## One layer for floors / roofs, and one y-sorted node at the foot of each wall.
const CELL=64
const STYLE="res://qingxi-live/village-center/art/regions/props/cottage.png"
const FLOOR="res://qingxi-live/classic-regions/art/floor-wood.png"
var plan:Dictionary
var world
var house_art:Texture2D
var wood:Texture2D
var edge_nodes=[]
var roofs=[]
var roof_layer:Node2D
var inside=""
var editing=false

static func key(cell:Vector2i)->String:return "%d:%d"%[cell.x,cell.y]
static func cell_of(p:Vector2)->Vector2i:return Vector2i((p/CELL).floor())
static func coord(k:String)->Vector2i:return Vector2i(int(k.get_slice(":",0)),int(k.get_slice(":",1)))
static func borders(c:Vector2i)->Array:
 return ["h:"+key(c),"v:"+key(c+Vector2i.RIGHT),"h:"+key(c+Vector2i.DOWN),"v:"+key(c)]
static func edge_cells(edge:String)->Array:
 var c=Vector2i(int(edge.get_slice(":",1)),int(edge.get_slice(":",2)))
 return [c,c+(Vector2i.UP if edge.begins_with("h") else Vector2i.LEFT)]
static func edge_box(edge:String)->Rect2:
 var p=Vector2(edge_cells(edge)[0])*CELL
 return Rect2(p-Vector2(0,3),Vector2(CELL,6)) if edge.begins_with("h") else Rect2(p-Vector2(3,0),Vector2(6,CELL))

func setup(host):
 world=host
 var layout=world.region.saved()
 if not layout.has("built_cottage"):layout.built_cottage={"floors":{},"edges":{}}
 plan=layout.built_cottage
 house_art=world.region.tex(STYLE);wood=world.region.tex(FLOOR)
 z_index=-4
 roof_layer=Node2D.new();roof_layer.z_index=2;world.map_layer.add_child(roof_layer)
 roof_layer.draw.connect(draw_roofs)
 rebuild()

func change(tool:String,p:Vector2,erase:bool)->String:
 var c=cell_of(p);var k=key(c)
 if tool=="floor":
  if erase:
   if not plan.floors.erase(k):return ""
   for edge in borders(c):
    var pair=edge_cells(edge)
    if not plan.floors.has(key(pair[0])) and not plan.floors.has(key(pair[1])):plan.edges.erase(edge)
  else:
   if plan.floors.has(k):return ""
   if not world.land_clear(Rect2(Vector2(c)*CELL,Vector2(CELL,CELL)),false):return "请选一块空地铺地板"
   plan.floors[k]=true
 else:
  var edge=str(world.nearest_edge(p)[1]);var pair=edge_cells(edge)
  if erase:
   if not plan.edges.erase(edge):return ""
  else:
   if not plan.floors.has(key(pair[0])) and not plan.floors.has(key(pair[1])):return "先铺地板，再沿边搭墙或留门"
   if tool=="wall" and edge_box(edge).grow(8).has_point(world.player.position):return "先走出这段墙的位置"
   if plan.edges.get(edge,"")==tool:return ""
   plan.edges[edge]=tool
 rebuild();return "ok"

func blocks(p:Vector2)->bool:
 for edge in borders(cell_of(p)):
  if plan.edges.get(edge,"")=="wall" and edge_box(edge).grow(5).has_point(p):return true
 return false

func rebuild():
 for n in edge_nodes:n.hide();n.queue_free()
 edge_nodes.clear()
 for edge in plan.edges:
  var box=edge_box(edge);var n=Node2D.new()
  n.position=Vector2(box.get_center().x,box.end.y);world.scenery.add_child(n)
  n.draw.connect(draw_wall.bind(n,edge));edge_nodes.append(n)
 roofs.clear()
 var seen={}
 for k in plan.floors:
  if seen.has(k):continue
  var cells=[coord(k)];var head=0;seen[k]=true;var enclosed=true;var door=false
  while head<cells.size():
   var c:Vector2i=cells[head];head+=1
   for edge in borders(c):
    var pair=edge_cells(edge);var other=key(pair[1] if pair[0]==c else pair[0])
    var neighbor=plan.floors.has(other)
    if not neighbor:
     var part=plan.edges.get(edge,"")
     if part=="":enclosed=false
     if part=="door":door=true
    elif not seen.has(other):
     seen[other]=true;cells.append(coord(other))
  if enclosed and door:roofs.append({"cells":cells,"spans":roof_spans(cells)})
 queue_redraw();roof_layer.queue_redraw()

# Merge matching horizontal runs so each roof wing has one continuous ridge and two hips.
func roof_spans(cells:Array)->Array:
 var rows={}
 for c in cells:
  if not rows.has(c.y):rows[c.y]=[]
  rows[c.y].append(c.x)
 var ys=rows.keys();ys.sort()
 var rectangles=[]
 var previous={}
 for y in ys:
  var xs:Array=rows[y];xs.sort()
  var next={};var i=0
  while i<xs.size():
   var left=int(xs[i]);var right=left+1;i+=1
   while i<xs.size() and xs[i]==right:right+=1;i+=1
   var span=Vector2i(left,right)
   if previous.has(span) and rectangles[previous[span]].end.y==y:
    var idx=int(previous[span]);rectangles[idx].size.y+=1;next[span]=idx
   else:
    next[span]=rectangles.size();rectangles.append(Rect2i(left,y,right-left,1))
  previous=next
 return rectangles

func follow():
 var k=key(cell_of(world.player.position))
 if k!=inside or editing!=world.build_mode:
  inside=k;editing=world.build_mode;roof_layer.queue_redraw()

func _draw():
 if not wood:return
 for k in plan.floors:
  var p=Vector2(coord(k))*CELL
  draw_texture_rect(wood,Rect2(p,Vector2(CELL,CELL)),false,world.ground_tint)

func draw_wall(n:Node2D,edge:String):
 var horizontal=edge.begins_with("h")
 var door=plan.edges.get(edge,"")=="door"
 var tint:Color=world.ground_tint
 if horizontal:
  if door:
   n.draw_texture_rect_region(house_art,Rect2(-32,-38,9,38),Rect2(40,60,5,40),tint)
   n.draw_texture_rect_region(house_art,Rect2(23,-38,9,38),Rect2(40,60,5,40),tint)
   n.draw_texture_rect_region(house_art,Rect2(-32,-42,64,8),Rect2(51,55,40,6),tint)
  else:
   n.draw_texture_rect_region(house_art,Rect2(-32,-42,64,42),Rect2(39,62,55,52),tint)
 else:
  for segment in 4:
   if door and segment in [1,2]:continue
   n.draw_rect(Rect2(-5,-77+segment*16,10,19),Color("754b39")*tint)
   n.draw_rect(Rect2(-3,-77+segment*16,5,17),Color("bc935f")*tint)
  n.draw_rect(Rect2(-5,-15,10,15),Color("754b39")*tint)

func draw_roofs():
 if editing:return
 for room in roofs:
  if inside!="" and room.cells.has(coord(inside)):continue
  for span in room.spans:
   var p=Vector2(span.position)*CELL
   var extent=Vector2(span.size)*CELL
   var top=p.y-58;var height=extent.y+25
   var body=Rect2(p.x-4,top,extent.x+8,height)
   roof_layer.draw_texture_rect_region(house_art,body,Rect2(68,0,100,61),world.ground_tint)
   roof_layer.draw_texture_rect_region(house_art,Rect2(body.position-Vector2(20,0),Vector2(20,height)),Rect2(17,0,51,61),world.ground_tint)
   roof_layer.draw_texture_rect_region(house_art,Rect2(body.end.x,top,18,height),Rect2(168,0,31,61),world.ground_tint)

