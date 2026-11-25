extends CanvasLayer
const KIT=preload("res://qingxi-live/village-center/ui_kit.gd")
const NAME="RuralMapLoading"
var card:Control
var shell:PanelContainer
var progress_text:Label
var progress:=0.0
var title_:Label

## 2026-11-19 Claude (Cabin World host): inside Cabin World the loading card lives in 清溪村's own view.
static func card_parent(tree:SceneTree)->Node:
 var host=tree.get_meta("qingxi_world_host",false)
 return host.loading_parent() if host else tree.root
static func loading(tree:SceneTree)->bool:return card_parent(tree).has_node(NAME)

static func quiet(tree:SceneTree)->bool:
 return bool(tree.get_meta("center_testing",false)) or DisplayServer.get_name()=="headless"

static func begin(tree:SceneTree,title:String):
 var screen=load("res://qingxi-live/village-center/map_loading.gd").new()
 screen.name=NAME
 card_parent(tree).add_child(screen)
 screen.title_.text=title
 return screen

static func rebuild(tree:SceneTree,title:String,action:Callable):
 if quiet(tree) or loading(tree):
  action.call();return
 var screen=begin(tree,title)
 await screen.show_progress(.20,.16)
 await screen.show_progress(.58,.14)
 if action.is_valid():action.call()
 await tree.process_frame
 await screen.finish()

static func change(tree:SceneTree,path:String,title:String)->int:
 var host=tree.get_meta("qingxi_world_host",false)
 if quiet(tree):
  return host.mount_scene(load(path)) if host else tree.change_scene_to_file(path)
 if loading(tree):return ERR_BUSY
 var screen=begin(tree,title)
 var result=ResourceLoader.load_threaded_request(path,"PackedScene")
 if result==OK:
  await screen.show_progress(.12,.14)
  while true:
   var amount=[]
   var status=ResourceLoader.load_threaded_get_status(path,amount)
   if status==ResourceLoader.THREAD_LOAD_LOADED:
    var scene:PackedScene=ResourceLoader.load_threaded_get(path)
    result=host.mount_scene(scene) if host else tree.change_scene_to_packed(scene)
    if result==OK and not host:await tree.scene_changed
    break
   if status!=ResourceLoader.THREAD_LOAD_IN_PROGRESS:
    result=ERR_CANT_OPEN;break
   screen.set_progress(maxf(screen.progress,.12+float(amount[0])*.76))
   await tree.process_frame
 if result==OK:await screen.finish()
 else:screen.queue_free()
 return result

func _ready():
 layer=70
 var background=ColorRect.new()
 background.color=Color("233249")
 background.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT);add_child(background)
 var center=CenterContainer.new()
 center.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT);add_child(center)
 shell=KIT.panel("window");center.add_child(shell)
 var margin=MarginContainer.new()
 for side in ["left","right"]:margin.add_theme_constant_override("margin_"+side,22)
 for side in ["top","bottom"]:margin.add_theme_constant_override("margin_"+side,16)
 shell.add_child(margin)
 var body=VBoxContainer.new();body.add_theme_constant_override("separation",10);margin.add_child(body)
 title_=KIT.label("",28,KIT.INK,true)
 title_.horizontal_alignment=HORIZONTAL_ALIGNMENT_CENTER;body.add_child(title_)
 card=Control.new();body.add_child(card)
 card.draw.connect(draw_progress)
 progress_text=KIT.label("0%",18,KIT.INK2,true)
 progress_text.horizontal_alignment=HORIZONTAL_ALIGNMENT_CENTER
 body.add_child(progress_text)
 get_viewport().size_changed.connect(layout_card)
 layout_card()
 set_process_input(true)

func layout_card():
 var w=clampf(get_viewport().get_visible_rect().size.x*.48,345,1020)
 shell.custom_minimum_size.x=w
 title_.add_theme_font_size_override("font_size",clampi(roundi(w*.040),21,40))
 progress_text.add_theme_font_size_override("font_size",clampi(roundi(w*.026),14,24))
 card.custom_minimum_size.y=clampf(w*.124,66,117)
 card.queue_redraw()

func _input(_event):get_viewport().set_input_as_handled()

func set_progress(value:float):
 progress=value
 progress_text.text="%d%%"%roundi(progress*100)
 card.queue_redraw()

func show_progress(value:float,seconds:float):
 var tween=create_tween()
 tween.tween_method(set_progress,progress,value,seconds).set_trans(Tween.TRANS_SINE)
 await tween.finished

func finish():
 await show_progress(1.0,.26)
 queue_free()

func draw_progress():
 var r=card.size
 var icon_scale=clampf(r.x/730.0,.62,1.45)
 var pad=50.0*icon_scale
 var rail=Rect2(pad,r.y-16,r.x-pad*2.0,15)
 card.draw_rect(rail,Color("6f584b"))
 card.draw_rect(rail.grow(-2),Color("d9c4a4"))
 var fill=(rail.size.x-4.0)*progress
 if fill>0:
  card.draw_rect(Rect2(rail.position+Vector2(2,2),Vector2(fill,11)),Color("427bc6"))
  card.draw_rect(Rect2(rail.position+Vector2(2,2),Vector2(fill,3)),Color("87c6ed"))
 var x=rail.position.x+2+fill
 draw_whale(Vector2(x,rail.position.y-5),icon_scale)

## 2026-11-19 Claude: the loading whale is now pixel art in the game's own style (the owner
## found the smooth polygon whale ugly). 32 x 17 pixels, 3 screen px each, bottom centre at
## `at`; it bobs and its spout puffs while the bar fills. Old drawing kept below as
## draw_whale_vector() for reference.
const WHALE_PIXELS=[
 "..................s..s.........",
 ".................s.ss.s........",
 "..................ssss.........",
 "..............oooooooo.........",
 "oo.........oooLLLLLLLLooo......",
 "oLo......ooLLLLLLLLLLLLLLoo....",
 "obLo....oLLLbbbbbbbbbbbbLLLo...",
 ".obLo..oLbbbbbbbbbbbbbbbbbbbo..",
 "..obbooobbbbbbbbbbbbbbbbbbbbbo.",
 "...obbbbbbbbbbbbbbbbbbbbbbeebo.",
 "..obbobbbbbbbbbbbbbbbbbbbbeebbo",
 ".obbo.obbbbbbbbbbbbbbbbbbbbbccbo",
 "obbo..obwwwwwwwwwwwwwwwwbbbbccbo",
 "oo....owwwwwwwwwwobbowwwwwwobbo.",
 "......oowwwwwwwwwwobbbowwwwwoo..",
 "........oowwwwwwwwwoooowwwoo....",
 "..........ooooooooooo.oooo......"]
const WHALE_INK={"o":Color("1c3468"),"b":Color("3d7fd6"),"L":Color("7ab6f0"),"w":Color("e8f4ff"),"e":Color("121e46"),"c":Color("f296ac"),"s":Color("8fd0ff")}
func draw_whale(at:Vector2,scale_:float):
 var px=3.0*scale_
 var t=Time.get_ticks_msec()/1000.0
 var bob=roundf(sin(t*3.2)*1.0)*px
 var puff=fmod(t*1.6,1.0)<.55
 var w=32*px;var h=WHALE_PIXELS.size()*px
 var origin=(at-Vector2(w*.5,h)+Vector2(0,bob)).round()
 for y in WHALE_PIXELS.size():
  var row:String=WHALE_PIXELS[y]
  for x in row.length():
   var ch=row[x]
   if not WHALE_INK.has(ch):continue
   if ch=="s" and not puff and y<2:continue
   card.draw_rect(Rect2(origin+Vector2(x,y)*px,Vector2(px,px)),WHALE_INK[ch])
func draw_whale_vector(at:Vector2,scale_:float):
 card.draw_set_transform(at,0.0,Vector2.ONE*scale_)
 var points=PackedVector2Array([
  Vector2(-49,-29),Vector2(-42,-31),Vector2(-34,-28),Vector2(-30,-23),
  Vector2(-27,-29),Vector2(-19,-33),Vector2(-15,-32),Vector2(-16,-25),Vector2(-22,-17),
  Vector2(-13,-18),Vector2(-5,-28),Vector2(4,-39),Vector2(15,-46),Vector2(26,-48),
  Vector2(36,-45),Vector2(44,-39),Vector2(49,-30),Vector2(49,-22),Vector2(45,-13),
  Vector2(38,-7),Vector2(28,-3),Vector2(15,-1),Vector2(1,-2),Vector2(-14,-6),
  Vector2(-24,-12),Vector2(-30,-17),Vector2(-38,-19),Vector2(-44,-23)
 ])
 card.draw_colored_polygon(points,Color("397cdc"))
 var outline=points.duplicate();outline.append(points[0])
 card.draw_polyline(outline,Color("224a90"),2.6,true)
 card.draw_colored_polygon(PackedVector2Array([Vector2(-6,-9),Vector2(10,-14),Vector2(24,-13),Vector2(35,-14),Vector2(44,-20),Vector2(44,-14),Vector2(37,-8),Vector2(26,-5),Vector2(13,-4),Vector2(0,-5)]),Color("deeffc"))
 card.draw_polyline(PackedVector2Array([Vector2(-3,-23),Vector2(5,-33),Vector2(16,-40),Vector2(25,-42)]),Color("9bd3ff"),2.8,true)
 card.draw_circle(Vector2(33,-28),3.1,Color("192e64"),true,-1.0,true)
 card.draw_circle(Vector2(34,-29),.85,Color.WHITE,true,-1.0,true)
 card.draw_arc(Vector2(40,-23),4.7,.18,2.14,9,Color("214c88"),1.7,true)
 card.draw_line(Vector2(17,-51),Vector2(12,-58),Color("57aaf5"),3.4,true)
 card.draw_line(Vector2(22,-52),Vector2(25,-61),Color("57aaf5"),3.4,true)
 card.draw_set_transform(Vector2.ZERO)

