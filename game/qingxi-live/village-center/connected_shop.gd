extends "res://qingxi-live/seedshop-study/shop.gd"
## The seed shop connected to 清溪村 (the livestock shop extends this file).
## Rooms, furniture and lighting come from seedshop-study/shop.gd (Codex, left untouched);
## this file swaps its study HUD for the village UI (ui_kit.gd, Cabin World's wood and
## paper): shop plaque top-left, clock and coins top-right, bag / keys buttons bottom-right,
## an "E" ribbon only near something usable, counter rows with item icons and prices,
## the shared slot bag, Esc → pause, H → keys. No tutorial bars.
const StateModel=preload("res://qingxi-live/rural_state.gd")
const SESSION=preload("res://qingxi-live/village3d/session.gd")
const KIT=preload("res://qingxi-live/village-center/ui_kit.gd")
const CONNECTED_SAVE="user://village-center-test.json"
const MapLoading=preload("res://qingxi-live/village-center/map_loading.gd")
const Book=preload("res://qingxi-live/village-center/breed_catalog.gd")
var sim=preload("res://qingxi-live/village-center/pasture_state.gd").new()
var leaving=false
var exit_grace=.6
var from_meadow=false
var meadow_via_village=false

var audio
var step_distance=0.0
var shop_title="青芽种子店"
func _ready():
 from_meadow=get_tree().has_meta("return_shop_to_meadow")
 if from_meadow:
  meadow_via_village=bool(get_tree().get_meta("return_shop_to_meadow"))
  get_tree().remove_meta("return_shop_to_meadow")
 if not SESSION.consume(get_tree(),sim):sim.load_from(qingxi_save_path(CONNECTED_SAVE))
 super._ready()
 # Shop music and wooden-floor footsteps, same sound set as the village.
 audio=preload("res://qingxi-live/village-center/audio.gd").new();add_child(audio);audio.place("seedshop",false)
 test_mode=bool(get_tree().get_meta("center_testing",false))
 hour=float(get_tree().get_meta("center_hour",8.0));cycle_running=bool(get_tree().get_meta("center_cycle",true))
 player.position=Vector2(432,691);apply_time();sync_purse();update_camera(true)
 if not get_tree().has_meta("qingxi_world_host"):   # 2026-11-19 Claude (Cabin World host): inside Cabin World this would touch the whole app
  get_tree().auto_accept_quit=false
  DisplayServer.window_set_title("小屋世界 · %s"%shop_title)
 game_ui()
 if sim.data.get("nursery_watered",false):water_nursery()

func sync_purse():
 purse.coins=sim.data.coins;purse.seed=sim.data.bag.seed;purse.harvest=sim.data.bag.veg
 refresh_wallet()

func _physics_process(dt):
 if leaving:return
 var previous=player.position
 super._physics_process(dt)
 if audio:
  step_distance+=player.position.distance_to(previous)
  if step_distance>=40.0:step_distance=0.0;audio.step("wood")
 exit_grace=maxf(0,exit_grace-dt)
 refresh_ui()
 if not menu.visible and exit_grace<=0 and previous.y<735 and player.position.y>=735 and absf(player.position.x-432)<50:return_to_center.call_deferred()

func return_to_center():
 if leaving:return
 leaving=true;save_study()
 get_tree().set_meta("center_hour",hour);get_tree().set_meta("center_cycle",cycle_running)
 if from_meadow:
  if meadow_via_village:get_tree().set_meta("enter_meadow_from_village",true)
  SESSION.publish(get_tree(),sim,"ranch")
  if await MapLoading.change(get_tree(),"res://qingxi-live/village-center/flat-build/meadow.tscn","自家农场")!=OK:leaving=false
  return
 get_tree().set_meta("center_from_shop",true)
 SESSION.publish(get_tree(),sim,"village")
 if await MapLoading.change(get_tree(),"res://qingxi-live/village-center/main.tscn","清溪村")!=OK:leaving=false

# ---------------- counter ----------------
func transact(item:String):
 sim.buy(item);save_study();sync_purse();open_shop();ching()
func sell_connected():
 preload("res://qingxi-live/village3d/trade.gd").sell(sim,"seed");save_study();sync_purse();open_shop();ching()
## Counter window: coins in the header, one row per item, selling at the bottom.
func counter(title:String,line:String):
 sync_purse();open_panel(title,"bag")
 var head=HBoxContainer.new();menu_body.add_child(head)
 head.add_child(KIT.label(line,11,KIT.INK2));var gap=Control.new();gap.size_flags_horizontal=Control.SIZE_EXPAND_FILL;head.add_child(gap)
 head.add_child(KIT.coin_chip(sim.data.coins))
func buy_row(key:String):
 var r=KIT.shop_row(key,StateModel.ITEM_NAMES[key],"背包里 %d"%int(sim.data.bag[key]),StateModel.PRICES[key],sim.data.coins>=StateModel.PRICES[key],func():transact(key))
 menu_body.add_child(r)
func sell_row(key:String,title:String,count:int,each:int,fn:Callable,sub:=""):
 var r=KIT.shop_row(key,title,sub if sub!="" else "背包里 %d"%count,each,count>0,fn,"卖")
 menu_body.add_child(r)
func open_shop():
 counter("团团的种子铺","今天想买点什么？")
 for key in ["seed","wheat","carrot","tomato_seed","eggplant_seed","strawberry_seed","watermelon_seed","fry","fish_feed"]:buy_row(key)
 sell_row("veg","出售白菜",int(sim.data.bag.veg),4,sell_connected)

## Same slot bag as the village.
func open_bag():
 sync_purse();open_panel("背包","bag")
 var head=HBoxContainer.new();menu_body.add_child(head)
 head.add_child(KIT.label("随身携带",11,KIT.INK2));var gap=Control.new();gap.size_flags_horizontal=Control.SIZE_EXPAND_FILL;head.add_child(gap)
 head.add_child(KIT.coin_chip(sim.data.coins))
 var names=StateModel.ITEM_NAMES.duplicate();names.merge(StateModel.YOUNG_NAMES)
 for key in sim.data.bag:
  if Book.price(key)>0 or key.begins_with("young_"):names[key]=Book.item_name(key)
 names.merge(sim.FARM_ITEMS)
 KIT.inventory(menu_body,sim.data.bag,names)

## In-world reading: short, no dev notes or key instructions.
func read(title:String,text_:String):
 open_panel(title)
 var l=KIT.label(text_,12,KIT.INK);l.autowrap_mode=TextServer.AUTOWRAP_WORD_SMART;menu_body.add_child(l)
func water_nursery():
 plant_watered=true
 sim.data.nursery_watered=true
 for pot in nursery_pots:pot.modulate=Color("e2f3dc")

func interact_point(kind:String):
 match kind:
  "catalog","sample":read("种子目录","白菜、胡萝卜、小麦、番茄、茄子、草莓和西瓜。麦粒和胡萝卜可以直接播种。")
  "grow":
   water_nursery();save_study()
   read("育苗间","给窗边的幼苗浇好了水。")
  "stock":read("种子库","左架是蔬菜种子，右架是花种与香草。")
  _:super.interact_point(kind)
func save_study():
 if bool(get_tree().get_meta("center_testing",false)):return
 sim.settle();sim.data.map="ranch" if from_meadow else "village"
 sim.save_to(qingxi_save_path(sim.MEADOW_SAVE if from_meadow else CONNECTED_SAVE))
func _notification(what):
 if what==NOTIFICATION_WM_CLOSE_REQUEST:
  save_study()
  if not get_tree().has_meta("qingxi_world_host"):get_tree().quit()   # 2026-11-19 Claude (Cabin World host): inside Cabin World this would touch the whole app
func _unhandled_key_input(event):
 if event is InputEventKey and event.pressed and not event.echo:
  # Esc closes a window, otherwise pauses; H shows the keys instead of hiding the HUD.
  if event.physical_keycode==KEY_ESCAPE:
   if menu.visible:close_panel()
   else:open_pause()
   return
  if event.physical_keycode==KEY_H:
   if menu.visible and menu_kind=="help":close_panel()
   else:open_help()
   return
  if event.physical_keycode==KEY_B and menu.visible and menu_kind=="bag":close_panel();return
  if event.physical_keycode==KEY_G:return
 super._unhandled_key_input(event)

# ---------------- game UI (same kit as the village HUD) ----------------
var ui_room:Label
var ui_clock:Label
var ui_period:Label
var ui_sun:TextureRect
var ui_sun_kind=""
var ui_coins:Label
var ui_info:HBoxContainer
var ui_actions:HBoxContainer
var bubble:PanelContainer
var bubble_text:Label
var bubble_key:PanelContainer
var bubble_last="-"
var menu_kind=""
var menu_scroll:ScrollContainer
func game_ui():
 shop_hud.texture_filter=CanvasItem.TEXTURE_FILTER_NEAREST
 # Hide the study bars (title/info bar, room line, tool buttons, bottom prompt) and the floating "E".
 for child in shop_hud.get_children():
  if child!=menu:child.hide()
 marker.hide()
 menu.add_theme_stylebox_override("panel",KIT.frame("window"));menu.position=Vector2(174,40);menu.custom_minimum_size=Vector2(420,0)
 # Wrap the body in a scroll so long counters (livestock) stay on screen.
 menu.remove_child(menu_body);menu_scroll=ScrollContainer.new();menu_scroll.horizontal_scroll_mode=ScrollContainer.SCROLL_MODE_DISABLED;menu.add_child(menu_scroll)
 menu_body.size_flags_horizontal=Control.SIZE_EXPAND_FILL;menu_scroll.add_child(menu_body);KIT.style_scroll(menu_scroll)
 menu_body.add_theme_constant_override("separation",6)
 # shop plaque + room (top-left)
 var left=VBoxContainer.new();left.position=Vector2(6,6);left.add_theme_constant_override("separation",-6);left.mouse_filter=Control.MOUSE_FILTER_IGNORE;shop_hud.add_child(left)
 var plaque=KIT.panel("plaque");left.add_child(plaque)
 var pr=HBoxContainer.new();pr.add_theme_constant_override("separation",4);plaque.add_child(pr)
 pr.add_child(KIT.icon("pin",2));pr.add_child(KIT.label(shop_title,13,KIT.CREAM,true,Color(KIT.WOOD_D,.6)))
 var room=KIT.panel("ribbon");room.size_flags_horizontal=Control.SIZE_SHRINK_CENTER;left.add_child(room)
 ui_room=KIT.label("",10,KIT.INK2,true);room.add_child(ui_room)
 # clock + coins (top-right)
 ui_info=HBoxContainer.new();ui_info.add_theme_constant_override("separation",4);ui_info.mouse_filter=Control.MOUSE_FILTER_IGNORE;shop_hud.add_child(ui_info)
 var ck=KIT.panel("ribbon");ui_info.add_child(ck)
 var cr=HBoxContainer.new();cr.add_theme_constant_override("separation",5);ck.add_child(cr)
 ui_sun=KIT.icon("sun",2);cr.add_child(ui_sun)
 var cc=VBoxContainer.new();cc.add_theme_constant_override("separation",-4);cr.add_child(cc)
 ui_clock=KIT.label("",15,KIT.INK,true);cc.add_child(ui_clock);ui_period=KIT.label("",9,KIT.INK2);cc.add_child(ui_period)
 var coins=KIT.coin_chip(0);coins.size_flags_vertical=Control.SIZE_SHRINK_CENTER;ui_info.add_child(coins);ui_coins=coins.find_child("Amount",true,false)
 # bag / keys (bottom-right)
 ui_actions=HBoxContainer.new();ui_actions.add_theme_constant_override("separation",8);shop_hud.add_child(ui_actions)
 ui_actions.add_child(action_button("bag","B","背包",open_bag))
 ui_actions.add_child(action_button("help","H","按键",open_help))
 # interaction ribbon (bottom-centre)
 bubble=KIT.panel("ribbon");bubble.mouse_filter=Control.MOUSE_FILTER_IGNORE;shop_hud.add_child(bubble)
 var br=HBoxContainer.new();br.add_theme_constant_override("separation",6);bubble.add_child(br)
 bubble_key=KIT.keycap("E");br.add_child(bubble_key)
 bubble_text=KIT.label("",12,KIT.INK,true);br.add_child(bubble_text);bubble.modulate.a=0.0
 refresh_ui()
func action_button(icon_name:String,key:String,tip:String,fn:Callable)->Control:
 var holder=Control.new();holder.custom_minimum_size=Vector2(42,42)
 var b=Button.new();KIT.style_button(b);b.icon=KIT.icon_texture(icon_name);b.expand_icon=true;b.tooltip_text=tip
 for k in ["normal","hover","pressed","hover_pressed"]:
  var s2=b.get_theme_stylebox(k).duplicate();var down=k.contains("pressed")
  s2.content_margin_left=7;s2.content_margin_right=7;s2.content_margin_top=8 if down else 6;s2.content_margin_bottom=7 if down else 9;b.add_theme_stylebox_override(k,s2)
 b.custom_minimum_size=Vector2(36,36);b.size=Vector2(36,36);holder.add_child(b)
 b.pressed.connect(fn);b.pressed.connect(func():if audio:audio.sfx("ui_click",-10))
 var cap=KIT.keycap(key);cap.position=Vector2(23,23);holder.add_child(cap)
 return holder
func refresh_ui():
 if ui_room==null:return
 marker.hide()
 var vw=get_viewport_rect().size
 ui_room.text=room_name(player.position).split(" · ")[0]
 ui_clock.text="%02d:%02d"%[int(hour),int(fmod(hour,1.0)*60)]
 ui_period.text="清晨" if hour>=5.5 and hour<10 else ("白天" if hour>=10 and hour<16.5 else ("黄昏" if hour>=16.5 and hour<19.5 else "夜晚"))
 var kind="moon" if hour<5.5 or hour>=19.5 else ("sun" if hour>=7 and hour<17 else "dusk")
 if kind!=ui_sun_kind:ui_sun_kind=kind;ui_sun.texture=KIT.icon_texture(kind)
 var coins=str(int(sim.data.coins))
 if ui_coins.text!=coins and ui_coins.text!="":ui_pop(ui_coins)
 ui_coins.text=coins
 ui_info.position=Vector2(vw.x-6-ui_info.size.x,6)
 ui_actions.position=Vector2(vw.x-6-ui_actions.size.x,vw.y-48)
 var t_=""
 if menu.visible:t_=""
 elif seated:t_="起身"
 elif player.position.y>700 and absf(player.position.x-432)<60:t_="↓ "+return_label()
 elif nearest>=0:t_=str(points[nearest].name)
 if t_==bubble_last:return
 bubble_last=t_
 if t_=="":
  create_tween().tween_property(bubble,"modulate:a",0.0,.12);return
 bubble_text.text=t_;bubble_key.visible=not t_.begins_with("↓")
 bubble.reset_size()
 var y=vw.y-40
 bubble.position=Vector2(roundf((vw.x-bubble.get_combined_minimum_size().x)/2),y+6)
 var tw=create_tween().set_parallel(true);tw.tween_property(bubble,"modulate:a",1.0,.12)
 tw.tween_property(bubble,"position:y",y,.18).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
func ui_pop(node:Control):
 node.pivot_offset=node.size/2
 var t2=create_tween();t2.tween_property(node,"scale",Vector2(1.3,1.3),.06);t2.tween_property(node,"scale",Vector2.ONE,.16).set_trans(Tween.TRANS_BACK)
## Windows: wood frame, title plaque, pixel close button, pop-in and sounds.
func open_panel(title:String,icon_name:=""):
 var opening=not menu.visible
 for child in menu_body.get_children():menu_body.remove_child(child);child.queue_free()
 menu.show();menu_body.add_child(KIT.header(title,close_panel,icon_name))
 menu_kind={"背包":"bag","暂停":"pause","按键":"help"}.get(title,"")
 if menu_scroll:fit_menu.call_deferred()
 if opening:
  if audio:audio.sfx("ui_open",-10)
  KIT.pop_in(menu)
func close_panel():
 if audio and menu.visible:audio.sfx("ui_close",-12)
 menu.hide();menu_kind=""
func button(text_:String,fn:Callable)->Button:
 var b=super.button(text_,fn);KIT.style_button(b)
 b.pressed.connect(func():if audio:audio.sfx("ui_click",-10))
 return b
func label(text_:String,size_:int,color=KIT.INK)->Label:
 if shop_hud==null:return super.label(text_,size_,color)
 return KIT.label(text_,size_,KIT.INK if color==Color("554a38") else color)
func return_label()->String:
 return "自家农场" if from_meadow else "清溪村"

func open_pause():
 open_panel("暂停")
 var col=VBoxContainer.new();col.add_theme_constant_override("separation",6);menu_body.add_child(col)
 for entry in [["继续",close_panel,true],["按键",open_help,false],["回到"+return_label(),func():close_panel();return_to_center.call_deferred(),false]]+([] if get_tree().has_meta("qingxi_world_host") else [["保存并退出",func():save_study();get_tree().quit(),false]]):   # 2026-11-19 Claude (Cabin World host): inside Cabin World this would touch the whole app
  var b=KIT.button(entry[0],entry[1],entry[2]);b.custom_minimum_size=Vector2(0,30);b.pressed.connect(func():if audio:audio.sfx("ui_click",-10));col.add_child(b)
func open_help():
 open_panel("按键","help")
 KIT.key_rows(menu_body,[["W A S D","行走"],["Shift","快走"],["E","互动"],["B","背包"],["1–4 T L","光照 · 昼夜 · 吊灯"],["Esc","关闭 · 暂停"]])
func ching():
 if audio:audio.sfx("coin",-8)
func fit_menu():
 if menu_scroll:KIT.fit(menu_scroll,menu_body,330.0);menu.reset_size()
