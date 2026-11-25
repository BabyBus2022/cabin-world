extends "res://qingxi-live/village-center/connected_shop.gd"
## 牧铃畜牧铺: the original seed shop (seedshop-study/shop.gd by Codex) is the reference.
## Same rooms, floors, walls, windows, pendant lights, seating and counter keeper;
## the fixtures are re-cast for a feed & livestock-supply shop using the same
## furniture library, and the counter sells feed, treats and young animals.

func build_interior():
 floor_layer=Node2D.new();floor_layer.z_index=-10;add_child(floor_layer)
 ground_rect(Rect2(-1000,-1000,3200,2600),Color("292d36"))
 for area in ROOMS:
  ground_rect(area.grow(8),Color("624633"))
  classic_tile("../lighting-refresh/ash-oak.png",Rect2i(),area)
 for area in [ROOMS[3],ROOMS[4]]:classic_tile("tile-floor.png",Rect2i(),area)
 scenery=Node2D.new();scenery.y_sort_enabled=true;add_child(scenery)
 shadow_root=Node2D.new();shadow_root.z_index=-8;add_child(shadow_root)
 floor_light_material=make_floor_material();beam_material=make_floor_material(true)
 rear_wall(32,144,320);rear_wall(352,208,384);rear_wall(736,272,352)
 wall_segment(Rect2(24,144,8,512));wall_segment(Rect2(1088,272,8,320))
 wall_segment(Rect2(344,144,8,64));wall_segment(Rect2(344,208,8,128))
 wall_segment(Rect2(32,336,112,8));wall_segment(Rect2(256,336,96,8))
 wall_segment(Rect2(736,272,8,152));wall_segment(Rect2(736,536,8,120))
 wall_segment(Rect2(736,592,352,8),14)
 wall_segment(Rect2(32,656,224,8),14);wall_segment(Rect2(576,656,160,8),14)
 wall_segment(Rect2(248,656,8,96));wall_segment(Rect2(576,656,8,96))
 wall_segment(Rect2(256,752,120,8),14);wall_segment(Rect2(488,752,88,8),14)
 for r in [Rect2(144,332,112,12),Rect2(732,424,12,112),Rect2(376,744,112,16)]:ground_rect(r,Color("ad794c"))
 # Feed store: crated supplies, sacks of grain and a scale desk for weighing feed.
 furnishing("seedshop--design-23","S",Vector2(64,176))
 furnishing("seedshop--design-17","S",Vector2(224,176))
 furnishing("seedshop--design-13","S",Vector2(64,240))
 plaque("饲料仓 · 称重",Vector2(96,64),120)
 add_window(Vector2(671,204))
 plaque("牧 铃 畜 牧 铺",Vector2(494,123),134)
 furnishing("seedshop--design-05","S",Vector2(448,304))
 # Sales hall: carrots and wheat (animal treats), feed sacks, brushes and shears.
 furnishing("qianxia-shop--produce","S",Vector2(96,400))
 furnishing("qianxia-shop--baskets","S",Vector2(288,432))
 furnishing("qianxia-shop--baskets","S",Vector2(336,432))
 furnishing("seedshop--design-17","S",Vector2(256,368))
 furnishing("seedshop--design-23","S",Vector2(384,240))
 furnishing("seedshop--design-14","S",Vector2(608,560))
 furnishing("seedshop--design-19","S",Vector2(480,560))
 var rug=classic.sprite("rug.png",floor_layer,Vector2(59,523));rug.scale=Vector2(.45,.45)
 rest_seat=furnishing("xiaojingyu-home--xj-sofa","E",Vector2(76,530))
 var tea=furnishing("xiaojingyu-home--xj-accessory_table","S",Vector2(194,575))
 ornament("tea",Vector2(225,577),19,tea.node)
 ornament("lamp",Vector2(54,548),53)
 ornament("plant-large",Vector2(61,400),57)
 # Tools & young animals: mixing cabinet, crates, grain sacks, care pamphlets, tool cart.
 add_window(Vector2(816,268));add_window(Vector2(1007,268))
 plaque("工 具 · 幼 畜 间",Vector2(870,190),118)
 furnishing("seedshop--packing","S",Vector2(768,304))
 furnishing("seedshop--design-23","S",Vector2(960,304))
 furnishing("seedshop--design-17","S",Vector2(832,432))
 furnishing("qianxia-shop--baskets","S",Vector2(944,440))
 furnishing("seedshop--design-15","S",Vector2(1024,432))
 furnishing("qianxia-shop--magazines","S",Vector2(960,528))
 furnishing("seedshop--design-19","S",Vector2(1024,528))
 furnishing("xiaojingyu-home--xj-desk-chair","E",Vector2(780,542))
 var tea2=furnishing("xiaojingyu-home--xj-accessory_table","S",Vector2(844,550))
 ornament("tea",Vector2(877,552),17,tea2.node)
 furnishing("qianxia-shop--produce","S",Vector2(256,688))
 ornament("plant-large",Vector2(547,715),58)
 points=[{"p":Vector2(576,386),"name":"团团 · 饲料与幼畜","type":"shop"},{"p":Vector2(900,520),"name":"照料手册","type":"care"},{"p":Vector2(652,642),"name":"打包台 · 查看背包","type":"bag"},{"p":Vector2(165,604),"name":"坐下歇一会儿","type":"rest"},{"p":Vector2(208,272),"name":"饲料仓 · 查看存货","type":"stock"}]
 points.append({"p":Vector2(512,608),"name":"价目表 · 查看商品","type":"catalog"})
 points.append({"p":Vector2(160,480),"name":"胡萝卜和小麦","type":"sample"})
 var sheet=Image.load_from_file("res://qingxi-live/assets/tuantuan-villagers.png")
 var cell=Vector2i(sheet.get_width()/4,sheet.get_height()/3)
 for col in [0,3]:
  var im=sheet.get_region(Rect2i(Vector2i(col,0)*cell,cell));npc_frames.append(ImageTexture.create_from_image(trim_image(im)))
 var holder=Node2D.new();holder.position=SELLER;scenery.add_child(holder)
 npc=Sprite2D.new();npc.texture=npc_frames[0];npc.centered=false;npc.scale=Vector2.ONE*60/npc.texture.get_height();npc.position=Vector2(-npc.texture.get_width()*npc.scale.x/2,-60);holder.add_child(npc)
 ambient=CanvasModulate.new();add_child(ambient)
 for p in [Vector2(670,204),Vector2(816,272),Vector2(1007,272)]:
  var beam=Polygon2D.new();beam.position=p;beam.uv=PackedVector2Array([Vector2(0,0),Vector2(1,0),Vector2(1,1),Vector2(0,1)])
  beam.material=beam_material;beam.z_index=-9;add_child(beam);beams.append(beam)
 for p in [Vector2(200,255),Vector2(560,400),Vector2(260,540),Vector2(924,450),Vector2(430,710)]:
  var g=Gradient.new();g.offsets=PackedFloat32Array([0,.22,.65,1]);g.colors=PackedColorArray([Color(1,1,1,1),Color(1,1,1,.85),Color(1,1,1,.24),Color(1,1,1,0)])
  var tex=GradientTexture2D.new();tex.gradient=g;tex.width=256;tex.height=256;tex.fill=GradientTexture2D.FILL_RADIAL;tex.fill_from=Vector2(.5,.5);tex.fill_to=Vector2(1,.5)
  var light=PointLight2D.new();light.texture=tex;light.position=p-Vector2(0,196);light.texture_scale=1.8;light.color=Color("fff2d9");add_child(light);lights.append(light)
  var fixture=Node2D.new();fixture.position=p-Vector2(0,200);fixture.z_index=15;add_child(fixture)
  var cable=Line2D.new();cable.points=PackedVector2Array([Vector2(0,-25),Vector2(0,-7)]);cable.width=1.5;cable.default_color=Color("80736a");fixture.add_child(cable)
  var shade=Sprite2D.new();shade.texture=classic.texture("pendant.png");shade.scale=Vector2(.45,.45);fixture.add_child(shade)
  var g2=Gradient.new();g2.colors=PackedColorArray([Color(1,.96,.85,.12),Color(1,.96,.85,0)])
  var halo=GradientTexture2D.new();halo.width=64;halo.height=64;halo.gradient=g2;halo.fill=GradientTexture2D.FILL_RADIAL;halo.fill_from=Vector2(.5,.5);halo.fill_to=Vector2(1,.5)
  var glow=Sprite2D.new();glow.texture=halo;glow.position.y=4;fixture.add_child(glow)
  var mat=CanvasItemMaterial.new();mat.blend_mode=CanvasItemMaterial.BLEND_MODE_ADD;glow.material=mat
  pendants.append({"node":fixture,"shade":shade,"glow":glow})
 marker=label("E",12,Color("fff5d8"));marker.add_theme_color_override("font_outline_color",Color("634d40"));marker.add_theme_constant_override("outline_size",4);marker.z_index=20;add_child(marker)

func _ready():
 shop_title="牧铃畜牧铺"
 super._ready()

func room_name(p:Vector2)->String:
 if ROOMS[1].has_point(p):return "饲料仓 · 干草与谷物"
 if ROOMS[3].has_point(p):return "工具 · 幼畜间"
 if ROOMS[4].has_point(p):return "门厅 · 欢迎光临"
 return "售卖厅 · 随便逛逛"

func return_to_center():
 if not from_meadow:get_tree().set_meta("center_from_livestock",true)
 super.return_to_center()

const GOODS = ["hay","pig_feed","wheat","carrot","fry","fish_feed","cat_food","dog_food"]
var stock_kind="cow"
var stock_sex="f"
func open_shop():
 counter("牧铃畜牧铺","今天要点什么？")
 for key in GOODS:buy_row(str(key))
 for kind in ["cow"]:
  var k=str(kind);var key="feeder_"+k;var price=int(sim.FEEDER_PRICE[k])
  menu_body.add_child(KIT.shop_row(key,sim.FEEDERS[k],"背包里 %d"%int(sim.data.bag.get(key,0)),price,sim.data.coins>=price,
   func():sim.buy_feeder(k);save_study();sync_purse();open_shop();ching()))
 var kinds=HBoxContainer.new();menu_body.add_child(kinds)
 for kind in Book.KIND:
  var k=str(kind)
  kinds.add_child(KIT.button(Book.KIND[k],func():stock_kind=k;open_shop(),k==stock_kind))
 var sex_row=HBoxContainer.new();menu_body.add_child(sex_row)
 for sex in ["f","m"]:
  var gender=str(sex)
  sex_row.add_child(KIT.button("母幼崽" if gender=="f" else "公幼崽",func():stock_sex=gender;open_shop(),gender==stock_sex))
 for coat in Book.BREEDS[stock_kind].size():
  var k=stock_kind;var c=int(coat);var sex=stock_sex
  var key=Book.young_key(k,c,sex);var price=Book.stock_cost(k,c)
  menu_body.add_child(KIT.shop_row(key,Book.BREEDS[k][c],Book.TRAIT_NAMES[Book.TRAITS[k][c]],price,sim.data.coins>=price,
   func():sim.buy_stock(k,c,sex);save_study();sync_purse();open_shop();ching()))
 for item in sim.data.bag:
  var key=str(item);var count=int(sim.data.bag[key]);var each=Book.price(key)
  if count<=0 or each==0:continue
  sell_row(key,"出售"+Book.item_name(key),count,each*count,func():sim.sell_lot(key);save_study();sync_purse();open_shop();ching(),"%d 件 × %d 币" % [count,each])

func interact_point(kind:String):
 match kind:
  "catalog":
   open_panel("牧铃价目表")
   for key in GOODS:menu_body.add_child(label("%s  ·  %d 币"%[StateModel.ITEM_NAMES[key],StateModel.PRICES[key]],12))
   for k in Book.KIND:menu_body.add_child(label("%s幼崽 · %d 币起" % [Book.KIND[k],Book.YOUNG_PRICE[k]],12))
   menu_body.add_child(label("普通品收购 · 牛奶 12 币，羊毛 16 币，鸡蛋 6 币",11))
  "sample":
   open_panel("胡萝卜和小麦")
   menu_body.add_child(label("牛和羊爱吃小麦，猪爱吃胡萝卜。\n手里拿着，它们就会跟过来。",11))
  "stock":
   open_panel("饲料仓 · 存货")
   menu_body.add_child(label("牛羊吃干草，猪吃猪饲料，鸡吃小麦。柜台也卖鱼苗、鱼饲料、猫粮和狗粮。",11))
  "care":
   open_panel("照料手册")
   menu_body.add_child(label("同圈两只成年动物都吃饱喝足、靠近时会生下幼崽。\n靠近动物可以指定伴侣、收取产物或出栏。",11))
  _:super.interact_point(kind)
