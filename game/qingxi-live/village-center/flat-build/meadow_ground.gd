extends Node2D
## Terrain is stored as occupied cells; water topology is recomputed only after edits.
const SIDE=64
const STEPS=[Vector2i.UP,Vector2i.RIGHT,Vector2i.DOWN,Vector2i.LEFT]
var world
var state:Dictionary
var cells={}
var deep={}
var swim_cells={}
var basin={}
var cell_depth={}
var habitats={}
var mask:ImageTexture
var surface:Sprite2D
var fish_marks=[]
const ShoreArt=preload("res://qingxi-live/village-center/shore_art.gd")
var decorations=[]
const BANK_DIR="res://qingxi-live/village-center/flat-build/pond-art/"
static var bank_art={}
var wave_tops:Sprite2D
var banks_layer:Node2D
const REFLECTION_SCALE=4
var reflected_banks:ImageTexture
var reflected_signature=0
var age=0.0
var lighting_wait=0.

static func key(c:Vector2i)->String:return "%d:%d"%[c.x,c.y]
static func coord(k:String)->Vector2i:return Vector2i(int(k.get_slice(":",0)),int(k.get_slice(":",1)))
static func cell(p:Vector2)->Vector2i:return Vector2i((p/SIDE).floor())

func setup(host):
 world=host;z_index=-6
 var layout=world.region.saved()
 if not layout.has("meadow_ground"):layout.meadow_ground={"cells":{},"stocks":{}}
 state=layout.meadow_ground
 for k in state.cells:cells[coord(k)]=state.cells[k]
 if world.has_meta("route_geometry"):
  apply_topology(topology(cells));set_process(false);return
 surface=Sprite2D.new();surface.centered=false;surface.show_behind_parent=true;add_child(surface)
 surface.texture_filter=CanvasItem.TEXTURE_FILTER_NEAREST
 surface.material=ShaderMaterial.new();surface.material.shader=preload("res://qingxi-live/village-center/flat-build/meadow_ground.gdshader")
 for name in ["streambed","moss","plumes","slab","flowers"]:
  if not bank_art.has(name):bank_art[name]=ImageTexture.create_from_image(Image.load_from_file(BANK_DIR+name+".png"))
 surface.material.set_shader_parameter("streambed",bank_art.streambed)
 wave_tops=Sprite2D.new();wave_tops.centered=false;add_child(wave_tops)
 wave_tops.texture_filter=CanvasItem.TEXTURE_FILTER_NEAREST
 wave_tops.material=ShaderMaterial.new()
 wave_tops.material.shader=load("res://qingxi-live/village-center/flat-build/pond_glints.gdshader")
 banks_layer=Node2D.new();add_child(banks_layer)
 banks_layer.texture_filter=CanvasItem.TEXTURE_FILTER_NEAREST
 banks_layer.draw.connect(draw_banks)
 for art in ["earth"]:
  surface.material.set_shader_parameter(art+"_art",preload("res://qingxi-live/village-center/garden_details.gd").tex(art))
 apply_topology(topology(cells))

static func square_cells(tiles:Dictionary,width:int)->Dictionary:
 var matched={}
 for c in tiles:
  if tiles[c]!="channel":continue
  var full=true
  for y in width:
   for x in width:
    if tiles.get(c+Vector2i(x,y),"")!="channel":full=false;break
   if not full:break
  if full:
   for y in width:
    for x in width:matched[c+Vector2i(x,y)]=true
 return matched

## 2026-11-19 Claude: the owner asked for a fish pond as soon as water fills 3x3 cells
## (was 4x4). Wading (1 cell) and swimming (2x2) are unchanged.
const POND_SIDE=3
## 2026-11-19 Claude (round 2b): fish water = a connected body of water that holds a 3x3
## pond OR has at least FISH_MIN_CELLS cells in all (the owner: a pond with a river dug
## out of it, or a long river, should have fish everywhere). Its id stays the top-left
## deep cell when there is one (old saves keep their stock), else its top-left cell.
const FISH_MIN_CELLS=9
static func topology(tiles:Dictionary)->Dictionary:
 var depths=square_cells(tiles,POND_SIDE);var ids={};var seen={}
 for start in tiles:
  if tiles[start]!="channel" or seen.has(start):continue
  var queue=[start];var head=0;var center=null;var first:Vector2i=start;seen[start]=true
  while head<queue.size():
   var c:Vector2i=queue[head];head+=1
   if depths.has(c) and (center==null or c.y<center.y or (c.y==center.y and c.x<center.x)):center=c
   if c.y<first.y or (c.y==first.y and c.x<first.x):first=c
   for step in STEPS:
    var n:Vector2i=c+step
    if not seen.has(n) and tiles.get(n,"")=="channel":queue.append(n);seen[n]=true
  if center==null and queue.size()>=FISH_MIN_CELLS:center=first
  if center!=null:
   for c in queue:ids[c]=key(center)
 return {"deep":depths,"basin":ids,"swim":square_cells(tiles,2)}

# Match the rounded visual edge when testing a player's feet.
func covers(p:Vector2,tool:String)->bool:
 var pixel=(p/2).floor()
 var q=(pixel+Vector2(.5,.5))/32-Vector2(.5,.5);var at=Vector2i(q.floor())
 var f=q-q.floor()
 f=Vector2(smoothstep(0,1,f.x),smoothstep(0,1,f.y))
 var top=lerpf(float(cells.get(at,"")==tool),float(cells.get(at+Vector2i.RIGHT,"")==tool),f.x)
 var bottom=lerpf(float(cells.get(at+Vector2i.DOWN,"")==tool),float(cells.get(at+Vector2i.ONE,"")==tool),f.x)
 var noise=.015*sin(pixel.x*.29+pixel.y*.13)+.014*sin(pixel.y*.4)
 return lerpf(top,bottom,f.y)+noise>(.52 if tool=="channel" else .61)

func edit(tool:String,brush:Dictionary,erase:bool)->String:
 var proposed=cells.duplicate();var changed=false
 for c in brush:
  if erase:
   if proposed.get(c,"")==tool:
    if tool=="channel" and is_instance_valid(world.bridges) and world.bridges.overlaps(world.region.cell_rect(c)):return "先拆掉水面上的桥"
    proposed.erase(c);changed=true
  elif proposed.get(c,"")!=tool:
   if proposed.has(c) or not world.terrain_cell_free(c,tool):return "请先腾出这段地面"
   proposed[c]=tool;changed=true
 if not changed:return ""
 var next=topology(proposed) if tool=="channel" else {"deep":deep,"basin":basin,"swim":swim_cells}
 var player_cell=cell(world.player.position)
 if not deep.has(player_cell) and next.deep.has(player_cell):return "先走到岸上，再拓宽水面"
 # Keep each stock with one surviving part of its original fish water (round 2b: any
 # fish-water cell, not only the deep 3x3 part).
 var stocks={}
 for id in state.stocks:
  var fish:Dictionary=state.stocks[id]
  if int(fish.count)==0:continue
  var anchor=coord(id);var dest="";var distance=INF
  for c in basin:
   if basin[c]!=id or not next.basin.has(c):continue
   var d=anchor.distance_squared_to(c);var new_id=str(next.basin[c])
   if d<distance or (d==distance and new_id<dest):distance=d;dest=new_id
  if dest=="":return "塘里还有鱼，先捕捞再填浅"
  if stocks.has(dest):return "两边都有鱼，先收一塘再打通"
  stocks[dest]=fish
 cells=proposed;state.cells.clear()
 for c in cells:state.cells[key(c)]=cells[c]
 state.stocks=stocks;apply_topology(next)
 if tool=="channel":world.region.refresh_ranch()
 world.save_progress();return "ok"

func apply_topology(next:Dictionary):
 deep=next.deep;basin=next.basin;swim_cells=next.swim
 if not world.has_meta("route_geometry"):arrange_shore()
 for id in basin.values():
  if not state.stocks.has(id):state.stocks[id]={"count":0,"progress":0.0,"feed":0.0}
 world.sim.recover_ponds()
 world.targets=world.targets.filter(func(t):return t.kind!="meadow_fish")
 var dims=Vector2i((world.region.size()/SIDE).ceil())
 var img=Image.create_empty(dims.x,dims.y,false,Image.FORMAT_RGBA8)
 cell_depth.clear()
 habitats.clear()
 var extents={}
 for c in basin:
  var id=basin[c]
  var limits:Vector2i=extents.get(id,Vector2i(c.x,c.x))
  extents[id]=Vector2i(mini(limits.x,c.x),maxi(limits.y,c.x))
 for c in cells:
  if cells[c]=="path":
   img.set_pixelv(c,Color(1,0,0,1))
  else:
   cell_depth[c]=pond_depth(c)
   var span:Vector2i=extents.get(basin.get(c,""),Vector2i(c.x,c.x))
   var across=(float(c.x-span.x)+.5)/float(span.y-span.x+1)
   img.set_pixelv(c,Color(0,1,cell_depth[c],across))
 # A dry bank beside fish water can be used for fishing: every bank of the deep pond,
 # and every third cell of bank along a fish river (round 2b), so long rivers work too.
 for c in basin:
  var in_pond=deep.has(c)
  if not in_pond and (c.x+c.y)%3!=0:continue
  for direction in STEPS:
   var bank:Vector2i=c+direction
   if cells.get(bank,"")=="channel":continue
   var p=(Vector2(c)+Vector2(.5,.5))*SIDE+Vector2(direction)*43
   if world.blocked(p):continue
   var id=str(basin[c])
   world.add_target("meadow_fish",p,"塘边 · 放苗 / 投喂 / 捕捞",id)
 if world.has_meta("route_geometry"):return
 if mask==null:mask=ImageTexture.create_from_image(img)
 else:mask.update(img)
 surface.texture=mask;surface.scale=Vector2(SIDE,SIDE)
 wave_tops.texture=mask;wave_tops.scale=surface.scale
 surface.material.set_shader_parameter("mask",mask)
 wave_tops.material.set_shader_parameter("mask",mask)
 bake_bank_reflections(dims)
 banks_layer.queue_redraw()
 # Round 2b: each fish is a little swimmer that starts somewhere in its fish water and
 # wanders cell to cell along it, so fish go out into rivers dug from the pond.
 rebuild_school()

# Bake the inverted artwork when the coast changes; waves displace it on the GPU.
func bake_bank_reflections(dims:Vector2i):
 var signature=hash([dims,decorations])
 if reflected_banks!=null and reflected_signature==signature:return
 reflected_signature=signature
 var atlas=Image.create_empty(dims.x*SIDE/REFLECTION_SCALE,dims.y*SIDE/REFLECTION_SCALE,false,Image.FORMAT_RGBA8)
 for prop in decorations:
  if not bank_art.has(prop[0]):continue
  var texture:Texture2D=bank_art[prop[0]]
  var size=texture.get_size()*(float(prop[2])/texture.get_width())
  var im=texture.get_image()
  var px=Vector2i((size*Vector2(1.,.83)/REFLECTION_SCALE).ceil())
  im.resize(maxi(px.x,1),maxi(px.y,1),Image.INTERPOLATE_LANCZOS)
  im.flip_y()
  var inward:Vector2=-prop[3]
  var anchor:Vector2=prop[1]+inward*size.y*.23+Vector2(-size.x*.5,-size.y*.13)
  atlas.blend_rect(im,Rect2i(Vector2i.ZERO,im.get_size()),Vector2i((anchor/REFLECTION_SCALE).floor()))
 if reflected_banks==null:reflected_banks=ImageTexture.create_from_image(atlas)
 else:reflected_banks.update(atlas)
 wave_tops.material.set_shader_parameter("reflected_banks",reflected_banks)

func size_band(fish:Dictionary)->int:
 var cm=world.sim.Fish.length_cm(fish)
 if cm>=100.:return 2
 return 1 if cm>=45. else 0

# Multi-source distances let a growing fish reach deeper water even through a flat inlet.
# Only water in this connected pond participates; use its best available depth in tiny ponds.
func habitat(id:String,band:int)->Dictionary:
 if not habitats.has(id):habitats[id]={}
 if habitats[id].has(band):return habitats[id][band]
 var group=[]
 var deepest=0.
 for c in basin:
  if basin[c]==id:
   group.append(c)
   deepest=maxf(deepest,cell_depth[c])
 var cutoff=minf([0.,.21,.40][band],deepest*.72)
 var preferred=[]
 var distance={}
 for c in group:
  if cell_depth[c]>=cutoff:
   preferred.append(c)
   distance[c]=0
 var queue=preferred.duplicate()
 var cursor=0
 while cursor<queue.size():
  var c:Vector2i=queue[cursor]
  cursor+=1
  for step in STEPS:
   var other:Vector2i=c+step
   if basin.get(other,"")==id and not distance.has(other):
    distance[other]=int(distance[c])+1
    queue.append(other)
 var result={"preferred":preferred,"distance":distance}
 habitats[id][band]=result
 return result

func rebuild_school():
 fish_marks.clear()
 for id in state.stocks:
  var fish=world.sim.Fish.stock(state.stocks[id])
  for i in fish.size():
   var group=habitat(id,size_band(fish[i])).preferred
   if group.is_empty():continue
   var start:Vector2i=group[(i*13+group.size()/2)%group.size()]
   var p=(Vector2(start)+Vector2(.5,.5))*SIDE
   fish_marks.append({"pos":p,"cell":start,"goal":p,"id":id,"index":i,"seed":cell_hash(start,i+3),"heading":float(i)*2.4,"beat":float(i)*1.77})
 queue_redraw()

func swim_fish(dt:float):
 for f in fish_marks:
  var to:Vector2=f.goal
  var delta:Vector2=to-f.pos
  var pace=20.+(int(f.index)*11%17)+5.*sin(age*1.6+f.index*2.4)
  if delta.length()>2.:f.heading=lerp_angle(f.heading,delta.angle(),1.-exp(-dt*5.))
  f.beat+=dt*(4.3+pace*.13)
  f.pos=f.pos.move_toward(to,dt*pace)
  if f.pos.distance_to(to)<2.0:
   # Next: a random neighbouring cell of the same water (or wiggle in place).
   var stock=world.sim.Fish.stock(state.stocks[f.id])
   if int(f.index)>=stock.size():continue
   var fish=stock[f.index]
   var distance=habitat(f.id,size_band(fish)).distance
   var remaining=int(distance[f.cell])
   var options=[]
   for d in STEPS:
    var neighbor:Vector2i=f.cell+d
    if distance.has(neighbor) and int(distance[neighbor])<=maxi(0,remaining-1):
     options.append(neighbor)
   if options.is_empty():options.append(f.cell)
   if options.size()>1:options.erase(f.get("previous",f.cell))
   f.previous=f.cell
   f.seed=cell_hash(f.cell,int(f.seed))
   var next_cell:Vector2i=options[int(f.seed)%options.size()]
   f.cell=next_cell
   f.goal=(Vector2(next_cell)+Vector2(.5,.5))*SIDE+Vector2(int(f.seed/7)%21-10,int(f.seed/151)%17-8)

# Distance from each cell centre to the closest dry cell rectangle, in tile units.
# Five tiles is beyond visible bottom depth. This field only changes after terrain edits.
func pond_depth(c:Vector2i)->float:
 var best_sq=25.0
 for dy in range(-5,6):
  for dx in range(-5,6):
   var gap=Vector2(maxf(abs(dx)-.5,0.),maxf(abs(dy)-.5,0.))
   var dist_sq=gap.length_squared()
   if dist_sq<best_sq and cells.get(c+Vector2i(dx,dy),"")!="channel":best_sq=dist_sq
 return sqrt(best_sq)/5.0

func tend(id:String)->String:
 if not state.stocks.has(id):state.stocks[id]={"count":0,"progress":0.0,"feed":0.0}
 var result=world.sim.tend_pond(state.stocks[id])
 apply_topology({"deep":deep,"basin":basin,"swim":swim_cells})
 return result

func _process(dt):
 age+=dt
 if surface!=null:surface.material.set_shader_parameter("tint",world.ground_tint)
 lighting_wait-=dt
 if lighting_wait<=0. and surface!=null:
  lighting_wait=.65
  var host=world.time_host()
  var weather:Dictionary=host.rural_weather() if host else {}
  var sun=maxf(0.,sin((world.sky_value()-.25)*TAU))
  wave_tops.material.set_shader_parameter("sky_time",world.sky_value())
  surface.material.set_shader_parameter("sky_time",world.sky_value())
  wave_tops.material.set_shader_parameter("cloud_cover",float(weather.get("cloud",.18)))
  wave_tops.material.set_shader_parameter("clear_sky",float(weather.get("sun",1.)))
  surface.material.set_shader_parameter("sunlight",sun*float(weather.get("sun",1.)))
  surface.material.set_shader_parameter("rainfall",float(weather.get("rain",0.)))
  wave_tops.material.set_shader_parameter("sunlight",sun*float(weather.get("sun",1.)))
  wave_tops.material.set_shader_parameter("rainfall",float(weather.get("rain",0.)))
  wave_tops.material.set_shader_parameter("tint",world.ground_tint)
  banks_layer.queue_redraw()
 swim_fish(dt)
 if not fish_marks.is_empty() or not basin.is_empty():queue_redraw()

## 2026-11-19 Claude (round 2): fish ponds were not obvious enough. Every pond (3x3+) now
## has lily pads (some in flower) on the deeper cells, cattails along its banks, slow
## expanding ripple rings, and bigger fish shadows when stocked. Placement is
## deterministic per cell, so the decoration does not jump around when you edit.
func cell_hash(c:Vector2i,salt:int)->int:return absi(hash(Vector3i(c.x,c.y,salt)))
func arrange_shore():
 decorations.clear()
 for c in basin:
  var h=cell_hash(c,21)
  var p=(Vector2(c)+Vector2(.5,.5))*SIDE
  var banks=[]
  for d in STEPS:
   if cells.get(c+d,"")!="channel":banks.append(d)
  if banks.size()>0:
   var normal=Vector2(banks[h%banks.size()])
   var at=p+normal*30.+normal.orthogonal()*(h%19-9)
   if h%5!=2:
    var kind=["moss","plumes","slab","flowers"][cell_hash(c,63)%4]
    var width={"moss":43.,"plumes":33.,"slab":46.,"flowers":38.}[kind]
    decorations.append([kind,at-normal*3.,width*(.80+float(cell_hash(c,72)%37)*.01),normal])
   if h%8==0:decorations.append(["lilies",at-normal*18,.68+(h%7)*.035])
   if h%3==1:decorations.append(["weeds",p+normal*8,.70])
  elif h%19==0:decorations.append(["lilies",p,.83])

func _draw():
 var tint:Color=world.ground_tint
 for prop in decorations:
  if prop[0]=="weeds":ShoreArt.paint(self,prop[0],prop[1],prop[2],Color(.57,.85,.80,.50)*tint)
 # Round 2b: now and then a fish jumps out of stocked water, with a splash ring.
 if not fish_marks.is_empty():
  var slot=int(age/3.0);var ph=fmod(age,3.0)/1.0
  var jumper:Dictionary=fish_marks[absi(hash(slot))%fish_marks.size()]
  var at:Vector2=jumper.pos
  if ph<1.0:
   var lift=sin(ph*PI)*16.0
   draw_swimmer(jumper,at+Vector2(0,-lift),jumper.heading-0.20*sin(ph*TAU),tint)
  elif ph<1.8:
   var rr=(ph-1.0)/.8
   ShoreArt.ring(self,at+Vector2(5,0),3.+rr*18.,rr,tint)
 for i in fish_marks.size():
  var f:Dictionary=fish_marks[i]
  if i==absi(hash(int(age/3.)))%fish_marks.size() and fmod(age,3.)<1.:continue
  var p=(f.pos+Vector2(0,sin(age*2.0+i)*2.0)).snapped(Vector2(2,2))
  draw_swimmer(f,p,f.heading,Color(.95,.98,.99,.96)*tint)

func draw_banks():
 var tint:Color=world.ground_tint
 for prop in decorations:
  if bank_art.has(prop[0]):
   var art:Texture2D=bank_art[prop[0]]
   var size=art.get_size()*(float(prop[2])/art.get_width())
   banks_layer.draw_texture_rect(art,Rect2(prop[1]-size*Vector2(.50,.72),size),false,tint)
  elif prop[0]!="weeds":ShoreArt.paint(banks_layer,prop[0],prop[1],prop[2],tint)
 
func draw_swimmer(f:Dictionary,p:Vector2,angle:float,tint:Color):
 var list=world.sim.Fish.stock(state.stocks[f.id])
 if int(f.index)>=list.size():return
 var fish:Dictionary=list[f.index]
 var radius:float=world.sim.Fish.pixels(fish)*.50+3.
 # Keep the whole silhouette under water, including the snout of a full-grown sturgeon.
 var base:Vector2i=f.cell if basin.get(cell(p),"")!=f.id else cell(p)
 var left=base;var right=base;var above=base;var below=base
 var reach=ceili(radius/SIDE)+1
 for i in reach:
  if basin.get(left+Vector2i.LEFT,"")==f.id:left+=Vector2i.LEFT
  if basin.get(right+Vector2i.RIGHT,"")==f.id:right+=Vector2i.RIGHT
  if basin.get(above+Vector2i.UP,"")==f.id:above+=Vector2i.UP
  if basin.get(below+Vector2i.DOWN,"")==f.id:below+=Vector2i.DOWN
 var vertical=(right.x-left.x+1)*SIDE<radius*2.+16. and below.y>above.y
 var margin=Vector2(radius*.34,radius) if vertical else Vector2(radius,radius*.34)
 var low=Vector2(left.x,above.y)*SIDE+margin+Vector2(8,8)
 var high=Vector2(right.x+1,below.y+1)*SIDE-margin-Vector2(8,8)
 p=p.clamp(low.min((low+high)*.5),high.max((low+high)*.5))
 if vertical:angle=PI*.5 if f.goal.y>=f.pos.y else -PI*.5
 var q=p/SIDE-Vector2(.5,.5)
 var at=Vector2i(q.floor())
 var frac=q-q.floor()
 var top=lerpf(cell_depth.get(at,0.),cell_depth.get(at+Vector2i.RIGHT,0.),frac.x)
 var bottom=lerpf(cell_depth.get(at+Vector2i.DOWN,0.),cell_depth.get(at+Vector2i.ONE,0.),frac.x)
 var immersion=smoothstep(.08,.43,lerpf(top,bottom,frac.y))*(.77+.16*sin(age*.64+f.index))
 var underwater=Color.WHITE.lerp(Color(.51,.78,.86,.72),immersion)
 world.sim.Fish.draw_fish(self,fish,p,angle,f.beat,tint*underwater)

func refresh_stock():
 rebuild_school()

func sync_fish_counts():
 var desired=0
 for s in state.stocks.values():desired+=int(s.count)
 if desired!=fish_marks.size():rebuild_school()
