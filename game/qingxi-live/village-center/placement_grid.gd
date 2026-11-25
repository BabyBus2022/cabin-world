extends Node2D
## Persistent surface tiles and furniture footprints, shared by every editable map.
const Stay=preload("res://qingxi-live/cottage_lodging.gd")
const COTTAGE_WIDTHS={"cw_table":104,"cw_dining_table":116,"cw_chair_e":32,"cw_chair_w":32,"cw_chair_n":32,"cw_bed":106,"cw_sofa":108,"cw_side_table":58,"cw_writing_desk":98,"cw_album_cabinet":92,"cw_bookshelf":102}
const SIZE=64
const Props=preload("res://qingxi-live/village-center/region.gd")
const WOOD="res://qingxi-live/classic-regions/art/floor-wood.png"
const STONE="res://qingxi-live/village-center/art/garden-v3/sprites/paving.png"
const GRASS="res://qingxi-live/village-center/art/garden-v3/sprites/grass.png"
const FLOORS={"wood_tile":["木地板",WOOD],"stone_tile":["石砖",STONE],"grass_tile":["草皮",GRASS],"bedding":["铺草",GRASS]}
const ITEMS={
 "ranch_lamp":["牧场白炽挂灯","ranch-incandescent",56,Vector2i.ONE,""],
 "pasture_floodlight":["双头牧场灯","pasture-floodlight",138,Vector2i.ONE,""],
 "pet_shelter":["领养小窝",0,76,Vector2i.ONE,"adopt"],
 "pet_bed":["宠物睡篮",0,67,Vector2i.ONE,""],
 "bed":["床",0,94,Vector2i(2,2),"rest"],
 "sofa":["沙发",1,140,Vector2i(3,1),"rest"],
 "tea_table":["茶桌",2,91,Vector2i(2,1),"eat"],
 "cabinet":["立柜",3,76,Vector2i(2,1),"storage"],
 "stove":["灶台",4,145,Vector2i(3,1),"cook"],
 "shared_chest":["共用物资箱","shared-farm-chest",78,Vector2i(2,1),"shared_chest"],
 "chest":["储物箱",5,72,Vector2i(2,1),"storage"],
 "desk":["书桌",6,112,Vector2i(2,1),"read"],
 # 2026-11-19 Claude: Cabin World's own furniture (art/cabin-furniture/README.md), drawn at
 # 0.7x. [name, file (string = Cabin World view), width, cells, E action ("" = none)].
 "cw_bed":["鲸鱼床","xiaojingyu-home--xj-bed",134,Vector2i(2,2),"rest"],
 "cw_bookshelf":["书架","xiaojingyu-home--xj-bookshelf",137,Vector2i(2,1),"read"],
 "cw_sofa":["沙发","xiaojingyu-home--xj-sofa",137,Vector2i(2,1),"rest"],
 "cw_writing_desk":["写字桌","xiaojingyu-home--xj-writing_desk",137,Vector2i(2,1),"read"],
 "cw_chair":["木椅","xiaojingyu-home--xj-desk-chair",48,Vector2i(1,1),"rest"],
 "cw_chair_n":["木椅（朝北）","xiaojingyu-home--xj-desk-chair#N",48,Vector2i(1,1),"rest"],
 "cw_album_cabinet":["相册柜","xiaojingyu-home--xj-album-cabinet",137,Vector2i(2,1),"storage"],
 "cw_side_table":["小茶几","xiaojingyu-home--xj-accessory_table",92,Vector2i(1,1),"eat"],
 "cw_dining_table":["四人餐桌","world-restaurant--1",182,Vector2i(3,1),"eat"],
 # 2026-11-19 Claude (round 2): the 双人餐桌 shows its top, so it reads as a dining table;
 # chairs sit at its ends in side view instead of poking over the back.
 "cw_table":["餐桌","world-restaurant--0",182,Vector2i(3,1),"eat"],
 "cw_chair_e":["木椅（朝东）","xiaojingyu-home--xj-desk-chair#E",48,Vector2i(1,1),"rest"],
 "cw_chair_w":["木椅（朝西）","xiaojingyu-home--xj-desk-chair#W",48,Vector2i(1,1),"rest"],
 "cw_stove":["双炉灶台","world-restaurant--6",92,Vector2i(1,1),"cook"],
 "cw_sink":["洗碗台","world-restaurant--7",92,Vector2i(1,1),""],
 "cw_cupboard":["碗碟柜","world-restaurant--12",92,Vector2i(1,1),"storage"]
}
const DETAIL_ITEMS={
 "house_fern":["盆栽","plant-west",43,Vector2i.ONE,""],
 "house_leaf":["窗边绿植","plant-east",38,Vector2i.ONE,""],
 "house_lamp":["落地灯","lamp-floor",32,Vector2i.ONE,""],
 "house_easel":["画架","easel",56,Vector2i.ONE,"read"],
 "house_cushions":["软座","sofa",54,Vector2i.ONE,"rest"],
 "house_basket":["收纳筐","@qianxia-shop--baskets",45,Vector2i.ONE,"storage"]
}
static var detail_textures={}
static func detail_texture(part:String)->Texture2D:
 if not detail_textures.has(part):
  var path=("res://assets/furniture-views/"+part.substr(1)+"/S.png") if part.begins_with("@") else ("res://assets/baked/xiaojingyu-home.xj-"+part+".png")
  var source=load(path) as Texture2D
  var trimmed=AtlasTexture.new()
  trimmed.atlas=source
  trimmed.region=Rect2(source.get_image().get_used_rect())
  detail_textures[part]=trimmed
 return detail_textures[part]
const CABIN_FURNITURE="res://qingxi-live/village-center/art/cabin-furniture/"
static var cabin_textures={}
var world
var plan:Dictionary
var bounds:Rect2
var nodes={}
var ranch_lamps={}
const Lamp=preload("res://qingxi-live/village-center/ranch_hanging_lamp.gd")
const Tower=preload("res://qingxi-live/village-center/pasture_floodlight.gd")
static func is_lamp(item:String)->bool:return item in ["ranch_lamp","pasture_floodlight"]
var lamp_preview_dir=0

func rotate_lamp(at:Vector2,preview:bool):
 for id in ranch_lamps:
  if not nodes[id].draw.has_point(at):continue
  var lamp=ranch_lamps[id]
  var direction=(lamp.facing+1)%4
  lamp.face(direction)
  nodes[id].draw.position=lamp.get_parent().global_position
  if not plan.has("lamp_directions"):plan.lamp_directions={}
  plan.lamp_directions[id]=direction
  world.save_progress()
  return
 if preview:lamp_preview_dir=(lamp_preview_dir+1)%4
var materials={}
var prop_textures={}

static func cell(p:Vector2)->Vector2i:return Vector2i((p/SIZE).floor())
static func key(c:Vector2i)->String:return "%d:%d"%[c.x,c.y]
static func coord(id:String)->Vector2i:return Vector2i(int(id.get_slice(":",0)),int(id.get_slice(":",1)))
static func tile(c:Vector2i)->Rect2:return Rect2(Vector2(c)*SIZE,Vector2(SIZE,SIZE))

const Loft=preload("res://qingxi-live/dorm_loft.gd")
func setup(host,area:Rect2):
 world=host;bounds=area;z_index=-6
 var layout=world.layout_save()
 if not layout.has("placement_by_map"):layout.placement_by_map={}
 if not layout.placement_by_map.has(world.map_id):
  layout.placement_by_map[world.map_id]={"tiles":{},"furniture":{}}
  if world.is_barn_floor():
   for k in world.barn_editor.plan.straw:layout.placement_by_map[world.map_id].tiles[k]="bedding"
 plan=layout.placement_by_map[world.map_id]
 for id in FLOORS:
  if id!="bedding" and not world.has_meta("route_geometry"):
   var path=FLOORS[id][1]
   materials[id]=ImageTexture.create_from_image(Image.load_from_file(path))
 if not world.rooms.contains(world.map_id):load_furniture()
 queue_redraw()

func load_furniture():
 for id in plan.furniture:spawn(id,plan.furniture[id])

func seed_room(items:Array):
 # 2026-11-19 Claude: a room whose design changed (the private cottage, design 2) swaps the
 # furniture it was first given ("room_*" keys) for the new set once. Pieces the owner
 # placed themselves ("placed_*") stay where they are.
 var design:int=world.rooms.design_of(world.map_id) if world.rooms.has_method("design_of") else 1
 if plan.has("room_seeded") and int(plan.get("room_design",1))<design:
  for k in plan.furniture.keys():
   if str(k).begins_with("room_"):plan.furniture.erase(k)
  plan.erase("room_seeded")
 if not plan.has("room_seeded"):
  plan.room_design=design
  for row in items:
   var p:Vector2=row[1]
   plan.furniture["room_%d"%plan.furniture.size()]=[row[0],p.x,p.y,row[2],row[3]]
  plan.room_seeded=true
 if world.rooms.private_room(world.map_id):
  for key_ in plan.furniture:
   var row:Array=plan.furniture[key_]
   if not COTTAGE_WIDTHS.has(row[0]):continue
   var width_=float(COTTAGE_WIDTHS[row[0]])
   if row.size()>4 and float(row[3])!=width_:
    var ratio=width_/float(row[3])
    for i in 4:row[4][i]=roundf(float(row[4][i])*ratio)
   row[3]=width_
   if row[0]=="cw_chair_e" and row[1]==314 and row[2]==556:row[1]=349
   if row[0]=="cw_chair_w" and row[1]==518 and row[2]==556:row[1]=483
   if row[0]=="cw_chair_n" and row[1]==530 and row[2]==404:row[2]=379
 if world.rooms.private_room(world.map_id) and not plan.get("cottage_details",false):
  for extra in world.rooms.cottage_details(world.map_id):
   var name=str(extra[0]);var pos=Vector2(extra[1],extra[2])
   var span=float(DETAIL_ITEMS[name][2]) if DETAIL_ITEMS.has(name) else float(COTTAGE_WIDTHS.get(name,ITEMS[name][2]))
   var rect=Rect2(-span*.38,-16,span*.76,16)
   var space=Rect2(pos+rect.position,rect.size)
   var clear=true
   for row in plan.furniture.values():
    var occupied_rect=footprint(row[0],Vector2(row[1],row[2]))
    if row.size()>4:
     var box=row[4];occupied_rect=Rect2(row[1]+box[0],row[2]+box[1],box[2],box[3])
    if space.grow(4).intersects(occupied_rect):clear=false;break
   if clear:plan.furniture["detail_%s_%s"%[name,int(pos.x)]]=[name,pos.x,pos.y,span,[rect.position.x,rect.position.y,rect.size.x,rect.size.y]]
  plan.cottage_details=true
 if world.map_id==Stay.DORM:Loft.relocate(self)
 load_furniture()
 sync_cottage_beds()

func sync_cottage_beds():
 if not world.rooms.private_room(world.map_id):return
 var keys=[]
 for key_ in plan.furniture:
  if plan.furniture[key_][0] in ["cw_bed","bed"]:keys.append(key_)
 Stay.sync_floor(Stay.path_for(world),world.map_id,keys)

## "<cabin world id>" or "<cabin world id>#N" (facing; default S = facing the viewer).
static func cabin_texture(file:String,facing:="S")->Texture2D:   # 2026-11-19 Claude
 if "#" in file:facing=file.get_slice("#",1);file=file.get_slice("#",0)
 var key_=file+"."+facing
 if not cabin_textures.has(key_):
  cabin_textures[key_]=ImageTexture.create_from_image(Image.load_from_file(CABIN_FURNITURE+key_+".png"))
 return cabin_textures[key_]
func texture_for(id:String)->Texture2D:
 if id=="pet_shelter":
  var image=Image.new()
  image.load_png_from_buffer(FileAccess.get_file_as_bytes("res://qingxi-live/village-center/art/garden-v3/pets/shelter.png"))
  return ImageTexture.create_from_image(image)
 if id=="pet_bed":return preload("res://core/pet_comfort.gd").texture()
 if id=="house_basket":return world.rooms.art[5]
 if DETAIL_ITEMS.has(id):return detail_texture(DETAIL_ITEMS[id][1])
 if not id.begins_with("prop:") and ITEMS[id][1] is String:return cabin_texture(ITEMS[id][1])   # 2026-11-19 Claude: Cabin World view
 if not id.begins_with("prop:"):return world.rooms.art[ITEMS[id][1]]
 if not prop_textures.has(id):
  var path="res://qingxi-live/village-center/art/regions/props/"+id.substr(5)+".png"
  prop_textures[id]=ImageTexture.create_from_image(Image.load_from_file(path))
 return prop_textures[id]

func piece_cells(id:String)->Vector2i:
 if DETAIL_ITEMS.has(id):return DETAIL_ITEMS[id][3]
 if not id.begins_with("prop:"):return ITEMS[id][3]
 var box:Rect2=Props.BOXES.get(id.substr(5),Rect2(-16,-10,32,10))
 return Vector2i((box.size/SIZE).ceil()).max(Vector2i.ONE)

func new_width(id:String)->float:
 if DETAIL_ITEMS.has(id):return DETAIL_ITEMS[id][2]
 if world.rooms.private_room(world.map_id) and COTTAGE_WIDTHS.has(id):return COTTAGE_WIDTHS[id]
 return texture_for(id).get_width()*2.0 if id.begins_with("prop:") else float(ITEMS[id][2])

func spawn(id:String,row:Array):
 var name=str(row[0]);var pos=Vector2(row[1],row[2])
 var rect=footprint(str(row[0]),pos)
 if row.size()>4:
  var raw=row[4]
  rect=Rect2(pos+Vector2(raw[0],raw[1]),Vector2(raw[2],raw[3]))
 var width_=float(row[3])
 var tex=world.rooms.art[2] if world.rooms.private_room(world.map_id) and name in ["cw_table","cw_dining_table","cw_side_table"] else texture_for(name)
 if name=="cw_bed" and world.map_id==Stay.DORM and id in ["room_0","room_2"]:
  tex=quilt_variant(tex,id)
 var draw_sprite=world.object(tex,pos,width_,Rect2(),false)
 draw_sprite.texture_filter=CanvasItem.TEXTURE_FILTER_NEAREST
 if is_lamp(name):
  var lamp=Lamp.new() if name=="ranch_lamp" else Tower.new()
  lamp.mount(world,draw_sprite)
  lamp.face(int(plan.get("lamp_directions",{}).get(id,0)))
  ranch_lamps[id]=lamp
  if name=="ranch_lamp":rect=Rect2(pos+Vector2(-width_*.49,-width_*.20),Vector2(width_*.34,width_*.20))
  if name=="pasture_floodlight":
   # Only the stone plinth touches the ground (150 x 193 directional art).
   var art_scale=width_/150.0
   rect=Rect2(pos+Vector2(-28,-27)*art_scale,Vector2(56,19)*art_scale)
 if name=="pet_bed":
  # Sort this low basket from its back rim so a pet on the cushion is visible.
  var height=tex.get_height()*width_/tex.get_width()
  draw_sprite.get_parent().position.y-=height*.8
  draw_sprite.position.y+=height*.8
 else:world.solids.append(rect)
 var target={}
 if name.begins_with("prop:"):
  var prop=name.substr(5)
  var title=str(Props.PROP_NAMES[prop])
  var action_point=pos+Vector2(0,18)
  var old_count=world.targets.size()
  match prop:
   "well","pump":world.add_target("well",action_point,title+" · 打水")
   "shipping_bin":world.add_target("ship",action_point,title+" · 出货")
   "drying_rack":world.add_target("dry_fish",action_point,title,"rack:"+world.map_id+":"+id)
   "beehive":world.add_target("hive",action_point,title,"hive:"+world.map_id+":"+id)
   "bench":world.add_target("furniture",action_point,title,"rest")
   "lantern":draw_sprite.material.set_shader_parameter("emissive_mode",2.0)
  if world.targets.size()>old_count:target=world.targets.back()
 else:
  var info=DETAIL_ITEMS[name] if DETAIL_ITEMS.has(name) else ITEMS[name]
  if str(info[4])!="":   # 2026-11-19 Claude: decorative pieces (sink) have no E action
   if world.rooms.private_room(world.map_id) and name in ["cw_bed","bed"]:
    world.add_target("furniture",pos+Vector2(0,18),"床 · 睡觉","cottage_sleep/"+id)
    var sleeper=preload("res://qingxi-live/cottage_sleeper.gd").new()
    sleeper.setup(Stay.path_for(world),world.map_id+"/"+id,tex,width_)
    draw_sprite.get_parent().add_child(sleeper)
   elif name=="pet_shelter":world.add_target("pet_adopt",pos+Vector2(0,18),"宠物小窝 · 领养小猫小狗")
   else:world.add_target("furniture",pos+Vector2(0,18),info[0],info[4])
   target=world.targets.back()
 if world.rooms.private_room(world.map_id) and name in ["cw_writing_desk","cw_album_cabinet"]:
  var top=Sprite2D.new()
  top.texture=detail_texture("desk-book" if name=="cw_writing_desk" else "plant-desk")
  var span=22.0 if name=="cw_writing_desk" else 18.0
  top.scale=Vector2.ONE*span/top.texture.get_width()
  top.position=Vector2(-width_*.18,-width_*tex.get_height()/tex.get_width()*.85-top.texture.get_height()*top.scale.y*.36)
  draw_sprite.get_parent().add_child(top)
 var height_=float(tex.get_height())*width_/float(tex.get_width())
 nodes[id]={"holder":draw_sprite.get_parent(),"material":draw_sprite.material,"solid":rect,"draw":Rect2(pos-Vector2(width_/2,height_),Vector2(width_,height_)),"target":target}
 if is_lamp(name):nodes[id].draw.position=draw_sprite.global_position

static var quilts={}
static func quilt_variant(source:Texture2D,key_:String)->Texture2D:
 if not quilts.has(key_):
  var img=source.get_image().duplicate() as Image
  var sepia=key_=="room_0"
  for y in range(img.get_height()/2,img.get_height()):
   for x in img.get_width():
    var c=img.get_pixel(x,y)
    if c.a>.1 and c.h>.53 and c.h<.75 and c.s>.23:
     img.set_pixel(x,y,Color.from_hsv(.078 if sepia else .36,c.s*.66,c.v*(1.02 if sepia else .92),c.a))
  quilts[key_]=ImageTexture.create_from_image(img)
 return quilts[key_]

func remove(id:String):
 var item=nodes[id]
 ranch_lamps.erase(id)
 if plan.has("lamp_directions"):plan.lamp_directions.erase(id)
 if plan.furniture[id][0]!="pet_bed":world.solids.erase(item.solid)
 world.surfaces.erase(item.material)
 world.targets.erase(item.target)
 item.holder.hide();item.holder.queue_free()
 nodes.erase(id);plan.furniture.erase(id)

func furniture_anchor(id:String,p:Vector2)->Vector2:
 var grid=tile(cell(p))
 return grid.position+Vector2(piece_cells(id).x*32,64)

func footprint(id:String,anchor:Vector2)->Rect2:
 var size_=Vector2(piece_cells(id))*SIZE
 return Rect2(anchor-Vector2(size_.x/2,size_.y),size_)

func occupied(rect:Rect2,include_player:bool)->bool:
 if not editable_area(rect):return true
 for id in nodes:
  if plan.furniture[id][0]=="pet_bed" and nodes[id].solid.intersects(rect.grow(-1)):return true
 if include_player and world.player.is_visible_in_tree() and rect.grow(9).has_point(world.player.position):return true
 if world.get_meta("open_meadow",false) and world.map_id=="ranch" and world.facility_conflict(rect):return true
 for solid in world.solids:
  if solid.intersects(rect.grow(-1)):return true
 for field in world.fields:
  if field.rect.intersects(rect):return true
 for target in world.targets:
  if (target.kind in ["portal","exit"] or target.get("extra","")=="cottage_door") and rect.grow(30).has_point(target.pos):return true
 return false

func editable_area(rect:Rect2)->bool:
 return bounds.encloses(rect) and (world.map_id!=Stay.DORM or Loft.contains_rect(rect))

func has_support(rect:Rect2)->bool:
 if world.barn_level(world.map_id)<2:return true
 for y in range(floori(rect.position.y/SIZE),ceili(rect.end.y/SIZE)):
  for x in range(floori(rect.position.x/SIZE),ceili(rect.end.x/SIZE)):
   if not supports(Vector2i(x,y)):return false
 return true

func supports(c:Vector2i)->bool:return plan.tiles.get(key(c),"") in ["wood_tile","stone_tile"]

func paint(tool:String,p:Vector2,erase:bool)->String:
 var c=cell(p);var id=key(c);var r=tile(c)
 if erase:
  if not plan.tiles.has(id):return ""
  if world.barn_level(world.map_id)>1 and supports(c):
   if world.is_stair_opening(r):return "先收回上面的楼梯"
   if r.grow(10).has_point(world.player.position):return "先站到别的楼板上"
   if occupied(r,false):return "先搬走这格楼板上的家具或设施"
  plan.tiles.erase(id)
 else:
  if not editable_area(r):return "这格在可铺设范围之外"
  if world.is_stair_opening(r):return "楼梯口需要留空"
  if world.get_meta("open_meadow",false) and world.map_id=="ranch" and world.facility_conflict(r):return "请避开水面、桥面和建筑"
  for field in world.fields:
   if field.rect.intersects(r):return "请先收回田地"
  for solid in world.solids:
   if solid.has_point(r.get_center()):return "请先搬走格内物件"
  if world.barn_level(world.map_id)>1 and tool not in ["wood_tile","stone_tile"]:return "楼板可用木地板或石砖"
  plan.tiles[id]=tool
 if world.is_barn_floor():world.barn_editor.refresh_beds()
 world.save_progress();queue_redraw();return "ok"

func edit_furniture(tool:String,p:Vector2,erase:bool)->String:
 if not erase and tool=="furn:shared_chest" and not Features.on("sharedChest12"):return "共用物资箱模块已关闭"
 if erase:
  var found=""
  for id in nodes:
   if nodes[id].solid.has_point(p) or nodes[id].draw.has_point(p):found=id
  if found=="":return ""
  if world.rooms.private_room(world.map_id) and world.map_id+"/"+found in Stay.data(Stay.path_for(world)).get("guests",{}).values():return "床上有人，等起床后再收起。"
  var existing=str(plan.furniture[found][0])
  if existing=="prop:drying_rack" and world.sim.data.get("farm_timers",{}).has("rack:"+world.map_id+":"+found):return "先收回晒架上的鱼"
  if existing.begins_with("prop:") and not world.get_meta("open_meadow",false):
   var stock="decor_"+existing.substr(5)
   world.sim.data.bag[stock]=int(world.sim.data.bag.get(stock,0))+1
  remove(found)
 else:
  var id=tool.trim_prefix("furn:")
  var anchor=furniture_anchor(id,p);var r=footprint(id,anchor)
  if occupied(r,true) or world.is_stair_opening(r) or not has_support(r):return "占地需要空格、楼板和可走的出口"
  if id.begins_with("prop:") and not world.get_meta("open_meadow",false):
   var stock="decor_"+id.substr(5)
   if int(world.sim.data.bag.get(stock,0))<=0:return "背包里没有可摆放的这件物品"
   world.sim.data.bag[stock]-=1
  plan.serial=int(plan.get("serial",0))+1
  var uid="placed_%d"%plan.serial
  plan.furniture[uid]=[id,anchor.x,anchor.y,new_width(id)]
  if is_lamp(id) and lamp_preview_dir!=0:
   if not plan.has("lamp_directions"):plan.lamp_directions={}
   plan.lamp_directions[uid]=lamp_preview_dir
  spawn(uid,plan.furniture[uid]);world.set_light(world.sky_value())
 sync_cottage_beds()
 world.save_progress();return "ok"

func preview(canvas:Node2D,tool:String,p:Vector2):
 var rect=tile(cell(p));var good=editable_area(rect)
 if tool.begins_with("furn:") or tool.begins_with("prop:"):
  var id=tool.trim_prefix("furn:")
  var anchor=furniture_anchor(id,p)
  rect=footprint(id,anchor);good=not occupied(rect,true) and has_support(rect) and not world.is_stair_opening(rect)
  var tex=texture_for(id)
  var width_=new_width(id);var h=tex.get_height()*width_/tex.get_width()
  if is_lamp(id):
   tex=cabin_texture(ITEMS[id][1],Lamp.VIEWS[lamp_preview_dir])
   if id=="ranch_lamp":anchor.x+=Lamp.OFFSETS[lamp_preview_dir]*width_/tex.get_width()
  canvas.draw_texture_rect(tex,Rect2(anchor-Vector2(width_/2,h),Vector2(width_,h)),false,Color(1,1,1,.55))
 else:good=good and not world.is_stair_opening(rect)
 var ink=Color("b7e28c") if good else Color("f07f68")
 canvas.draw_rect(rect,Color(ink,.25))
 canvas.draw_rect(rect,ink,false,2)
 for x in range(int(rect.position.x)+64,int(rect.end.x),64):
  canvas.draw_line(Vector2(x,rect.position.y),Vector2(x,rect.end.y),ink)
 for y in range(int(rect.position.y)+64,int(rect.end.y),64):
  canvas.draw_line(Vector2(rect.position.x,y),Vector2(rect.end.x,y),ink)

func _draw():
 if plan.is_empty():return
 for id in plan.tiles:
  var material=str(plan.tiles[id]);var c=coord(id);var rect=tile(c)
  if world.map_id==Stay.DORM and not editable_area(rect):continue
  if material=="bedding":
   draw_rect(rect,Color("d9b374"))
   for i in 34:
    var h=absi(hash(Vector3i(c.x,c.y,i)))
    var p=rect.position+Vector2(4+h%51,4+(h/47)%54)
    draw_line(p,p+Vector2(3+h%8,-1-h%3),Color("ebce93") if i%3 else Color("bf9357"),2)
  elif materials.has(material):
   draw_texture_rect(materials[material],rect,false)
  if world.barn_level(world.map_id)>1:
   draw_rect(rect.grow(-1),Color(.31,.21,.16,.42),false,2)

