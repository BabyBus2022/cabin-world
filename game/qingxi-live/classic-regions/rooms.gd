extends RefCounted
const FLOOR=Rect2(128,208,1024,444)
const ENTRY=Vector2(640,635)
var world
var configs={"home":{"up":false,"title":"村庄小屋"},"seedshop":{"up":false,"title":"青芽种子店"},"stockshop":{"up":false,"title":"牧铃牲畜店"}}
var houses=[]
var cache={}
func _init(host):
 world=host
 var sheet=Image.load_from_file("res://qingxi-live/classic-regions/art/buildings.png");var cell=Vector2i(sheet.get_width()/3,sheet.get_height()/2)
 for i in 6:houses.append(ImageTexture.create_from_image(world.trim_image(sheet.get_region(Rect2i(Vector2i(i%3,i/3)*cell,cell)))))
func contains(id:String)->bool:return configs.has(id)
func outside_house(index:int,p:Vector2,width_:float,door_x=0.0):
 world.object(houses[index],p,width_,Rect2(),true,"house")
 # Front entrance remains reachable, all of the back footprint stays solid.
 world.solids.append(Rect2(p+Vector2(-width_*.43,-55),Vector2(width_*.86,35)))
 world.solids.append(Rect2(p+Vector2(-width_*.43,-20),Vector2(width_*.43+door_x-23,20)))
 world.solids.append(Rect2(p+Vector2(door_x+23,-20),Vector2(width_*.43-door_x-23,20)))
func exterior():
 outside_house(0,Vector2(360,475),256,-65)
 outside_house(1,Vector2(1080,500),272,-5)
 outside_house(2,Vector2(990,1120),270,-70)
 for p in [Vector2(1540,750),Vector2(1770,900),Vector2(1270,1200)]:world.object(houses[3],p,150,Rect2(-58,-35,116,35),true,"house")
func furniture(id:String,p:Vector2,width_:float,footprint:Vector2):
 width_*=0.50;footprint*=0.50
 if not cache.has(id):
  var im=Image.load_from_file("res://qingxi-live/village01/art/classic-furniture/"+id+"/S.png");cache[id]=ImageTexture.create_from_image(world.trim_image(im))
 world.object(cache[id],p,width_,Rect2(Vector2(-footprint.x/2,-footprint.y),footprint),false)
func build(id:String,arrival:Vector2):
 var canvas=Node2D.new();canvas.set_script(preload("res://qingxi-live/classic-regions/room_canvas.gd"));canvas.z_index=-8;world.map_layer.add_child(canvas)
 world.solids.append(Rect2(120,200,1040,12));world.solids.append(Rect2(120,200,8,460));world.solids.append(Rect2(1152,200,8,460))
 if id=="home":
  furniture("world-restaurant--6",Vector2(325,280),130,Vector2(110,30));furniture("world-restaurant--7",Vector2(405,280),130,Vector2(110,30))
  furniture("xiaojingyu-home--xj-album-cabinet",Vector2(960,280),125,Vector2(105,28))
  furniture("world-restaurant--0",Vector2(370,425),160,Vector2(130,45))
  furniture("qianxia-park--bench",Vector2(910,430),145,Vector2(120,30))
  world.add_target("home",Vector2(640,500),"村庄生活 · 做饭 / 储物 / 休息")
  world.add_target("furniture",Vector2(325,315),"灶台 · 做家常菜","cook")
  world.add_target("furniture",Vector2(960,315),"储物柜","storage")
  world.add_target("furniture",Vector2(910,465),"长椅 · 休息","rest")
 else:
  for x in [280,510,870,1050]:
   furniture("qianxia-shop--bread-shelf" if x<800 else "qianxia-shop--produce",Vector2(x,280),150,Vector2(120,35))
  furniture("qianxia-shop--counter",Vector2(640,350),230,Vector2(200,40))
  world.object(world.villagers.rows[0 if id=="seedshop" else 1][0],Vector2(640,315),40,Rect2(),false)
  world.add_target("shop",Vector2(640,385),"买入 / 收购 · "+configs[id].title,"seed" if id=="seedshop" else "livestock")
 for link in world.LINKS[id]:world.add_target("portal",link[1],"走出大门 · 村庄中心",str(link[0]))
 decorations(id)
 world.make_actor();world.player.position=arrival if arrival!=Vector2.ZERO else ENTRY-Vector2(0,60)
 world.show_idle();world.update_camera(true);world.set_light(world.sky_value());world.update_hud();world.queue_redraw()
func floor_height(_id:String,_p:Vector2)->float:return 0
func portal_direction(from:String,_to:String)->float:return 1.0 if contains(from) else -1.0
func arrival(from:String,to:String)->Vector2:
 if contains(to):return ENTRY-Vector2(0,60)
 for link in world.LINKS[to]:
  if link[0]==from:return link[1]+Vector2(0,48)
 return Vector2.ZERO
func interact(action:String):
 match action:
  "rest":world.perform(world.sim.rest())
  "cook":world.perform(world.sim.cook())
  "storage":world.show_home()

func decor(file:String,p:Vector2,width_:float,solid=false):
 if not cache.has(file):
  var im=Image.load_from_file("res://qingxi-live/classic-regions/art/"+file+".png");cache[file]=ImageTexture.create_from_image(world.trim_image(im))
 world.object(cache[file],p,width_,Rect2(-10,-7,20,10) if solid else Rect2(),false)
func decorations(id:String):
 for x in [350,935]:decor("window",Vector2(x,196),100)
 for p in [Vector2(185,280),Vector2(1090,280),Vector2(1090,580)]:decor("plant",p,32,true)
 if id=="home":
  furniture("xiaojingyu-home--xj-desk-chair",Vector2(370,485),68,Vector2(40,30))
  furniture("xiaojingyu-home--xj-bookshelf",Vector2(790,280),140,Vector2(120,36))
  decor("lamp",Vector2(1040,435),25,true)
