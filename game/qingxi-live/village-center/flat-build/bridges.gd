extends Node2D
const ART=preload("res://qingxi-live/village-center/garden_details.gd")
var world
var spans={}
var saved:Array
var tiles={}
var legacy=[]
var wood:Texture2D
func setup(host):
 world=host;z_index=-3
 var layout=world.region.saved()
 if not layout.has("meadow_bridges"):layout.meadow_bridges=[]
 saved=layout.meadow_bridges
 wood=ART.tex("wood_h")
 texture_filter=CanvasItem.TEXTURE_FILTER_NEAREST
 for row in saved:
  if is_tile(row):tiles[Vector2i(row[0],row[1])]=row
  else:
   legacy.append(row)
   draw_span(row)

func is_tile(row:Array)->bool:
 return row[0]==row[2] and row[1]==row[3]

func deck(row:Array)->Rect2:
 if is_tile(row):return world.region.cell_rect(Vector2i(row[0],row[1]))
 var a=(Vector2(row[0],row[1])+Vector2(.5,.5))*64
 var b=(Vector2(row[2],row[3])+Vector2(.5,.5))*64
 var across=Vector2(0,23) if row[1]==row[3] else Vector2(23,0)
 return Rect2(a-across,b-a+across*2)

func candidate(p:Vector2,_direction:int)->Array:
 var c=world.region.cell_of(p)
 if world.ground_tiles.cells.get(c,"")!="channel" or not world.region.in_zone_cell(c):return []
 var rect=world.region.cell_rect(c)
 if overlaps(rect) or world.building_blocks_facility(rect,true):return []
 for solid in world.solids:
  if rect.grow(-1).intersects(solid):return []
 for plot in world.fields:
  if rect.intersects(plot.rect):return []
 return [c.x,c.y,c.x,c.y]

func overlaps(rect:Rect2)->bool:
 var start=world.region.cell_of(rect.position)
 var end=Vector2i((rect.end/64.).ceil())
 for y in range(start.y,end.y):
  for x in range(start.x,end.x):
   if tiles.has(Vector2i(x,y)):return true
 for row in legacy:
  if deck(row).intersects(rect):return true
 return false

func underfoot(p:Vector2)->int:
 if tiles.has(world.region.cell_of(p)):return 1
 for row in legacy:
  var r=deck(row)
  if not r.grow(2).has_point(p):continue
  var lateral=absf(p.y-r.get_center().y) if row[1]==row[3] else absf(p.x-r.get_center().x)
  return 1 if lateral<20 else -1
 return 0

func change(p:Vector2,remove:bool,direction:int)->String:
 if remove:
  var c=world.region.cell_of(p)
  if tiles.has(c):
   if world.player.is_visible_in_tree() and world.region.cell_of(world.player.position)==c:return "先离开脚下的桥面再拆"
   saved.erase(tiles[c]);tiles.erase(c)
   return finish_change()
  for row in legacy:
   var r=deck(row)
   if not r.grow(8).has_point(p):continue
   if r.has_point(world.player.position):return "先走到岸上再拆桥"
   saved.erase(row)
   legacy.erase(row)
   for piece in spans[str(row)]:piece.queue_free()
   spans.erase(str(row));return finish_change()
  return ""
 var row=candidate(p,direction)
 if row.is_empty():return "请选择一格空水面铺木桥"
 join_legacy_neighbors(world.region.cell_of(p))
 saved.append(row);tiles[world.region.cell_of(p)]=row
 return finish_change()

func join_legacy_neighbors(c:Vector2i):
 # Keep old bridges intact until the player extends one. Convert its water
 # tiles in the same save operation so the old inside railing disappears.
 for row in legacy.duplicate():
  var start=Vector2i(row[0],row[1])
  var end=Vector2i(row[2],row[3])
  var step=(end-start).sign()
  var adjacent=false
  var water_cells=[]
  var at=start
  while at!=end:
   if world.ground_tiles.cells.get(at,"")=="channel":
    water_cells.append(at)
    var offset=(c-at).abs()
    if offset.x+offset.y==1:adjacent=true
   at+=step
  if not adjacent:continue
  for piece in spans[str(row)]:
   piece.hide()
   piece.queue_free()
  spans.erase(str(row));saved.erase(row);legacy.erase(row)
  for cell in water_cells:
   var tile=[cell.x,cell.y,cell.x,cell.y]
   saved.append(tile);tiles[cell]=tile

func finish_change()->String:
 queue_redraw()
 world.herd_ai.layout_changed()
 world.save_progress()
 return "ok"

func _draw():
 if wood==null:return
 for c in tiles:
  var r:Rect2=world.region.cell_rect(c)
  var shade=1.-float(posmod(c.x*13+c.y*7,5))*.014
  # Sample the existing bridge's planks and stagger the joints across each bay.
  for band in 2:
   var source_x=22+posmod(c.x*17+c.y*11+band*23,30)
   var strip=Rect2(r.position+Vector2(0,band*32),Vector2(64,32))
   draw_texture_rect_region(wood,strip,Rect2(source_x,19,64,18),Color(shade,shade,shade))
  # Flush planks across shared edges. Only exposed ends have a timber fascia.
  for step in [Vector2i.LEFT,Vector2i.RIGHT,Vector2i.UP,Vector2i.DOWN]:
   if tiles.has(c+step):continue
   var edge=r
   if step.x!=0:
    edge.size.x=3
    if step.x>0:edge.position.x=r.end.x-3
    draw_rect(edge,Color("805134"))
    draw_rect(edge.grow(-1),Color("c49466"))
   else:
    edge.size.y=7
    if step.y>0:edge.position.y=r.end.y-7
    draw_texture_rect_region(wood,edge,Rect2(25,42,64,9))
   # Repeat short posts along long water-facing edges. The shore ends stay open.
   if world.ground_tiles.cells.get(c+step,"")=="channel":
    var run=c.x if step.y!=0 else c.y
    if posmod(run,2)==0:
     var foot=edge.get_center()-Vector2(4,6)
     draw_texture_rect_region(wood,Rect2(foot,Vector2(8,10)),Rect2(6,33,12,13))
  for x in [5,57]:
   for y in [6,54]:
    draw_rect(Rect2(r.position+Vector2(x,y),Vector2(2,2)),Color("755637"))
  for corner in [Vector2i(-1,-1),Vector2i(1,-1),Vector2i(-1,1),Vector2i(1,1)]:
   if tiles.has(c+Vector2i(corner.x,0)) or tiles.has(c+Vector2i(0,corner.y)):continue
   var at=r.position+Vector2(54 if corner.x>0 else 0,53 if corner.y>0 else 0)
   draw_texture_rect_region(wood,Rect2(at,Vector2(10,11)),Rect2(6,33,12,13))

func draw_span(row:Array):
 var r=deck(row);var h=row[1]==row[3]
 var s=NinePatchRect.new();s.mouse_filter=Control.MOUSE_FILTER_IGNORE
 s.texture=ART.tex("wood_h" if h else "wood_v")
 # Keep the bank ends at their native proportions; tile the middle across wider ponds.
 s.axis_stretch_horizontal=NinePatchRect.AXIS_STRETCH_MODE_TILE_FIT if h else NinePatchRect.AXIS_STRETCH_MODE_STRETCH
 s.axis_stretch_vertical=NinePatchRect.AXIS_STRETCH_MODE_STRETCH if h else NinePatchRect.AXIS_STRETCH_MODE_TILE_FIT
 if h:
  s.patch_margin_left=24;s.patch_margin_right=24
  s.position=r.position-Vector2(5,17);s.size=r.size+Vector2(10,21)
 else:
  s.patch_margin_top=20;s.patch_margin_bottom=20
  s.position=r.position-Vector2(7,5);s.size=r.size+Vector2(14,10)
 s.texture_filter=CanvasItem.TEXTURE_FILTER_NEAREST;add_child(s)
 var holder=Node2D.new()
 holder.position=Vector2(r.get_center().x,r.end.y-4)
 world.scenery.add_child(holder)
 var front=s.duplicate()
 holder.add_child(front)
 front.global_position=s.global_position
 front.material=ART.bridge_foreground(not h,false)
 spans[str(row)]=[s,holder]

