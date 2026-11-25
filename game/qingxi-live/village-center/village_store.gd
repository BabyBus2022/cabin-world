extends RefCounted

const ART = "res://assets/baked/"
const SCALE = 1.5
const BOUNDS = Rect2(0, 0, 960, 640.5)
const EXIT = Vector2(320, 405) * SCALE
const ENTRY = Vector2(320, 365) * SCALE
const LABELS = {"snack":"食品和零食", "daily":"日用品", "hotdrink":"热饮柜", "drink":"饮料冰柜", "icecream":"冰品柜", "all":"收银台"}
const CATEGORIES = {
 "snack-shelf":"snack", "food-shelf":"snack", "daily-shelf":"daily",
 "bread-shelf":"snack", "drink-fridge":"drink", "drink-fridge-2":"drink",
 "food-island":"snack", "snack-island":"snack", "daily-island":"daily",
 "snack-island-2":"snack", "produce":"snack", "sale-island":"all",
 "magazines":"daily", "freezer":"icecream", "counter-extension":"all",
 "counter":"all", "hot-cabinet":"hotdrink"
}

static func lights(night:float)->Array:
 var sources = []
 var tints = []
 for point in [Vector2(158,17), Vector2(480,17)]:
  var at:Vector2 = point * SCALE
  sources.append(Vector4(at.x, at.y, 300., lerpf(.22,.83,night)))
  tints.append(Vector4(1.,.88,.68,.85))
 return [sources,tints]

static func blocks(pos:Vector2, solids:Array)->bool:
 var q = pos / SCALE
 if not Rect2(36,104,568,287).has_point(q) and not Rect2(246,378,150,35).has_point(q):
  return true
 for fixture in solids:
  if fixture.grow(3).has_point(pos):return true
 return false

static func build(world,arrival:Vector2):
 # Fixed village floor plan taken from the installed shop's resolved furniture grid.
 var manifest = JSON.parse_string(FileAccess.get_file_as_string("res://qingxi-live/village-center/store_layout.json"))
 for obstacle in manifest.obstacles:
  world.solids.append(Rect2(Vector2(obstacle.x,obstacle.y)*SCALE,Vector2(obstacle.w,obstacle.h)*SCALE))
 var ground = Sprite2D.new()
 ground.texture = preload("res://assets/baked/qianxia-shop.ground.png")
 ground.centered = false
 ground.scale = BOUNDS.size / ground.texture.get_size()
 ground.z_index = -8
 ground.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
 world.map_layer.add_child(ground)
 for layer in manifest.layers:
  var id = str(layer.id)
  var pivot = Node2D.new()
  pivot.position = Vector2(layer.x,layer.depth)*SCALE
  world.scenery.add_child(pivot)
  var sprite = Sprite2D.new()
  sprite.texture = load((ART+str(layer.file)).simplify_path())
  sprite.centered = false
  sprite.position.y = (float(layer.y)-float(layer.depth))*SCALE
  sprite.scale = Vector2(layer.w,layer.h)*SCALE/sprite.texture.get_size()
  sprite.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
  pivot.add_child(sprite)
  var foot = Vector2(layer.x, float(layer.y)+float(layer.h))
  if id=="counter":
   add_cashier(world,Vector2(layer.x,layer.y))
  if CATEGORIES.has(id):
   var category:String = CATEGORIES[id]
   world.add_target("shop_shelf",(foot+Vector2(float(layer.w)*.5,8))*SCALE,LABELS[category]+" · 选购",category)
 world.add_target("portal",EXIT,"走出小铃杂货","village")
 world.make_actor()
 world.player.position = arrival if arrival!=Vector2.ZERO and not blocks(arrival,world.solids) else ENTRY
 world.show_idle()
 world.update_camera(true)
 world.set_light(world.sky_value())
 world.update_hud()
 world.queue_redraw()

static func add_cashier(world,counter:Vector2):
 var appearance=preload("res://core/npc_appearance.gd")
 for row in appearance.data().characters:
  if row.get("role","")!="cashier" or row.scene!="qianxia-shop":continue
  var entry:Dictionary=row.duplicate(true)
  var anchor=Vector2(entry.station_anchor[0],entry.station_anchor[1])
  var station=Node2D.new()
  station.position=(counter+anchor)*SCALE
  station.scale=Vector2.ONE*SCALE
  world.scenery.add_child(station)
  entry.erase("station_module")
  entry.scene="village_store"
  entry.id="village-shop-cashier"
  entry.feet=[0.,0.]
  var clerk=preload("res://entities/service_npc.gd").new()
  clerk.configure(appearance.data().skins[entry.skin].merged(entry,true))
  station.add_child(clerk)
  return

static func open_shelf(world,target:Dictionary):
 var category:String = target.extra
 var economy = world.get_node("/root/Economy")
 var day:String = economy.today()
 world.open_menu = "village_store"
 world.clear_menu("小铃杂货 · "+str(LABELS[category]))
 world.menu_line("钱包 %d 币" % economy.inventory("owner").coins)
 if category=="all":
  world.menu_button("店里的茶点 · 2 币（当场吃）",tea.bind(world,target))
 for item in economy.catalog.values():
  if item.get("shelf","")=="restaurant" or str(item.id).begins_with("restaurant-"):continue
  if category!="all" and item.get("shelf","")!=category:continue
  if economy.available_today(item,day):
   world.menu_button("%s · %d 币" % [item.name,economy.price_today(item,day)],buy.bind(world,target,str(item.id)))

static func at_shelf(world,target:Dictionary)->bool:
 return world.map_id=="village_store" and world.overlay.visible and world.player.position.distance_to(target.pos)<=72.

static func buy(world,target:Dictionary,id:String):
 if not at_shelf(world,target):return
 var economy = world.get_node("/root/Economy")
 var result:Dictionary = economy._answer({"op":"buy","actor":"owner","who":"owner","space":"village_store","product":id,"id":"village-shop-%d-%d"%[Time.get_unix_time_from_system(),Time.get_ticks_usec()]})
 if result.ok:
  open_shelf(world,target)
  world.notify("%s 已放入小屋背包" % economy.catalog[id].name)
 else:
  world.notify(str(result.error))

static func tea(world,target:Dictionary):
 if not at_shelf(world,target):return
 var receipt:String = world.sim.tea_break()
 if not receipt.begins_with("吃过"):
  world.notify(receipt)
  return
 world.close_menu()
 world.play_action("meal-eat-south")
 world.perform(receipt)
