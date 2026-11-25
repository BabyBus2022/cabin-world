extends RefCounted
## 清溪村 UI kit, drawn in Cabin World's interface language (CabinWorld/game/ui/hud.gd):
## a pixel grid, dark-wood outline, a wood band with a lit top edge and a shadowed bottom,
## gold corner rivets, cream paper inside, notched corners and small pixel-art icons.
## Every frame is a generated 9-slice texture, so the village HUD, its menus and both
## shops share one look. Use with texture_filter = NEAREST on the UI root.
const WOOD_D=Color("3b2416")
const WOOD=Color("7a4a26")
const WOOD_L=Color("a96f3b")
const WOOD_H=Color("d29a5c")
const WOOD_S=Color("5a341b")
const PAPER=Color("f6e6c8")
const PAPER_D=Color("e2c99f")
const PAPER_H=Color("fff4dc")
const INK=Color("3a2a20")
const INK2=Color("6e5a48")
const GRASS=Color("7f9a3a")
const GRASS_L=Color("9db64a")
const GRASS_D=Color("55702a")
const GOLD=Color("e0b24a")
const CREAM=Color("fdf3dd")
const RED=Color("c4563f")

static var _styles={}
static var _icons={}
static var _font:SystemFont
static var _bold:SystemFont

static func font(bold:=false)->SystemFont:
 if _font==null:
  _font=SystemFont.new();_font.font_names=PackedStringArray(["Microsoft YaHei UI","Microsoft YaHei","SimHei"]);_font.font_weight=500
  _bold=SystemFont.new();_bold.font_names=_font.font_names;_bold.font_weight=700
 return _bold if bold else _font

# ---------------- pixel frames ----------------
static func _fill(img:Image,x:int,y:int,w:int,h:int,c:Color):
 if w>0 and h>0:img.fill_rect(Rect2i(x,y,w,h),c)
static func _notched(img:Image,x:int,y:int,w:int,h:int,c:Color,n:=1):
 _fill(img,x+n,y,w-2*n,h,c);_fill(img,x,y+n,w,h-2*n,c)
static func _wood_button(img:Image,h:int,fill:Color,hi:Color,lip:Color,edge:Color,lip_rows:int):
 var w=img.get_width()
 _notched(img,0,0,w,h,edge);_fill(img,1,1,w-2,h-2,fill)
 _fill(img,2,1,w-4,1,hi);_fill(img,1,2,1,h-3-lip_rows,hi.lerp(fill,.5))
 _fill(img,1,h-1-lip_rows,w-2,lip_rows,lip)
## kind: window, ribbon, plaque, slot, slot_hi, slot_off, key, wood, wood_hi, wood_down, wood_off,
##       green, green_hi, green_down, chip
static func frame(kind:String)->StyleBoxTexture:
 if _styles.has(kind):return _styles[kind]
 var img:Image;var tm=[4,4,4,4];var cm=[6,4,6,4]
 match kind:
  "window":
   img=Image.create_empty(32,34,false,Image.FORMAT_RGBA8)
   _fill(img,2,32,28,2,Color(0,0,0,.22));_fill(img,1,31,30,2,Color(0,0,0,.18))
   _notched(img,0,0,32,32,WOOD_D,2);_notched(img,1,1,30,30,WOOD)
   _fill(img,2,1,28,1,WOOD_H);_fill(img,1,2,1,28,WOOD_L);_fill(img,2,30,28,1,WOOD_S);_fill(img,30,2,1,28,WOOD_S)
   _fill(img,5,5,22,22,WOOD_D);_fill(img,6,6,20,20,PAPER);_fill(img,6,6,20,1,PAPER_H)
   _fill(img,6,25,20,1,PAPER_D);_fill(img,25,7,1,18,PAPER_D)
   for p in [Vector2i(2,2),Vector2i(28,2),Vector2i(2,28),Vector2i(28,28)]:_fill(img,p.x,p.y,2,2,GOLD)
   tm=[8,8,8,10];cm=[12,10,12,13]
  "ribbon":
   img=Image.create_empty(16,18,false,Image.FORMAT_RGBA8)
   _fill(img,1,16,14,2,Color(0,0,0,.2))
   _notched(img,0,0,16,16,WOOD_D);_fill(img,1,1,14,14,WOOD);_fill(img,2,1,12,1,WOOD_H);_fill(img,1,14,14,1,WOOD_S)
   _fill(img,3,3,10,10,PAPER);_fill(img,3,12,10,1,PAPER_D)
   tm=[5,5,5,7];cm=[9,5,9,7]
  "plaque":
   img=Image.create_empty(16,16,false,Image.FORMAT_RGBA8)
   _wood_button(img,16,WOOD,WOOD_H,WOOD_S,WOOD_D,2)
   _fill(img,2,3,1,1,GOLD);_fill(img,13,3,1,1,GOLD)
   tm=[5,4,5,5];cm=[9,3,9,5]
  "chip":
   img=Image.create_empty(16,16,false,Image.FORMAT_RGBA8)
   _notched(img,0,0,16,16,WOOD_D);_fill(img,1,1,14,14,WOOD_S);_fill(img,2,1,12,1,WOOD)
   tm=[4,4,4,4];cm=[7,3,8,3]
  "slot","slot_hi","slot_off":
   img=Image.create_empty(12,12,false,Image.FORMAT_RGBA8)
   var edge={"slot":Color("b48a5e"),"slot_hi":GOLD,"slot_off":Color("ccb48c")}[kind]
   var inside={"slot":Color("ecd8b0"),"slot_hi":PAPER_H,"slot_off":Color("e4d3b2")}[kind]
   _notched(img,0,0,12,12,edge);_fill(img,1,1,10,10,inside)
   _fill(img,1,1,10,1,inside.darkened(.1));_fill(img,1,2,1,9,inside.darkened(.07))
   if kind=="slot_hi":_fill(img,1,1,10,1,GOLD.lightened(.3))
   tm=[3,3,3,3];cm=[3,3,3,3]
  "key":
   img=Image.create_empty(10,12,false,Image.FORMAT_RGBA8)
   _notched(img,0,0,10,12,WOOD_D);_fill(img,1,1,8,10,PAPER_H);_fill(img,1,9,8,2,PAPER_D)
   tm=[3,3,3,4];cm=[5,1,5,3]
  "wood","wood_hi","wood_down","wood_off","green","green_hi","green_down":
   img=Image.create_empty(12,14,false,Image.FORMAT_RGBA8)
   var green=kind.begins_with("green")
   var fill=GRASS if green else WOOD;var hi=GRASS_L if green else WOOD_H;var lip=GRASS_D if green else WOOD_S;var edge=Color("2f3d14") if green else WOOD_D
   if kind.ends_with("_hi"):fill=GRASS_L if green else WOOD_L;hi=Color("c8dc7a") if green else Color("ecc08a")
   if kind=="wood_off":fill=Color("8f8070");hi=Color("a89a8a");lip=Color("6e6256");edge=Color("4a4038")
   if kind.ends_with("_down"):
    _notched(img,0,1,12,13,edge);_fill(img,1,2,10,11,fill.darkened(.08));_fill(img,2,2,8,1,lip)
    tm=[4,5,4,3];cm=[10,5,10,3]
   else:
    _wood_button(img,14,fill,hi,lip,edge,2);tm=[4,3,4,4];cm=[10,3,10,5]
 var s=StyleBoxTexture.new();s.texture=ImageTexture.create_from_image(img)
 s.texture_margin_left=tm[0];s.texture_margin_top=tm[1];s.texture_margin_right=tm[2];s.texture_margin_bottom=tm[3]
 s.content_margin_left=cm[0];s.content_margin_top=cm[1];s.content_margin_right=cm[2];s.content_margin_bottom=cm[3]
 _styles[kind]=s;return s

static func panel(kind:="window")->PanelContainer:
 var p=PanelContainer.new();p.add_theme_stylebox_override("panel",frame(kind));p.texture_filter=CanvasItem.TEXTURE_FILTER_NEAREST;return p

# ---------------- text, buttons, keycaps ----------------
static func label(t:String,size_:int,color:=INK,bold:=false,outline:=Color(0,0,0,0))->Label:
 var l=Label.new();l.text=t;l.add_theme_font_override("font",font(bold));l.add_theme_font_size_override("font_size",size_)
 l.add_theme_color_override("font_color",color);l.mouse_filter=Control.MOUSE_FILTER_IGNORE
 if outline.a>0:l.add_theme_color_override("font_outline_color",outline);l.add_theme_constant_override("outline_size",3)
 return l
## Wood buttons: cream text, a 2-pixel lip that presses flat, a lighter board on hover.
static func style_button(b:Button,green:=false):
 var k="green" if green else "wood"
 b.add_theme_stylebox_override("normal",frame(k));b.add_theme_stylebox_override("hover",frame(k+"_hi"))
 b.add_theme_stylebox_override("pressed",frame(k+"_down"));b.add_theme_stylebox_override("hover_pressed",frame(k+"_down"))
 b.add_theme_stylebox_override("disabled",frame("wood_off"));b.add_theme_stylebox_override("focus",StyleBoxEmpty.new())
 b.add_theme_font_override("font",font(true));b.add_theme_font_size_override("font_size",12)
 for c in ["font_color","font_hover_color","font_pressed_color","font_hover_pressed_color"]:b.add_theme_color_override(c,CREAM)
 b.add_theme_color_override("font_disabled_color",Color("d8ccbc"))
 b.add_theme_color_override("font_outline_color",Color(WOOD_D,.55));b.add_theme_constant_override("outline_size",2)
 b.focus_mode=Control.FOCUS_NONE;b.texture_filter=CanvasItem.TEXTURE_FILTER_NEAREST
 b.mouse_default_cursor_shape=Control.CURSOR_POINTING_HAND
static func button(t:String,fn:Callable,green:=false)->Button:
 var b=Button.new();b.text=t;style_button(b,green);b.pressed.connect(fn);return b
static func keycap(k:String)->PanelContainer:
 var p=panel("key");var l=label(k,10,INK,true);l.horizontal_alignment=HORIZONTAL_ALIGNMENT_CENTER;p.add_child(l);p.mouse_filter=Control.MOUSE_FILTER_IGNORE;return p
## Window header: wood plaque with the title (and an optional icon), close button on the right.
static func header(title:String,close_fn:Callable,icon_name:="")->HBoxContainer:
 var row=HBoxContainer.new();row.add_theme_constant_override("separation",6)
 var plaque=panel("plaque");row.add_child(plaque)
 var inner=HBoxContainer.new();inner.add_theme_constant_override("separation",5);plaque.add_child(inner)
 if icon_name!="":inner.add_child(icon(icon_name,2))
 inner.add_child(label(title,14,CREAM,true,Color(WOOD_D,.6)))
 var gap=Control.new();gap.size_flags_horizontal=Control.SIZE_EXPAND_FILL;row.add_child(gap)
 if close_fn.is_valid():
  var x=Button.new();style_button(x);x.icon=icon_texture("close");x.custom_minimum_size=Vector2(26,24);x.tooltip_text="关闭 · Esc"
  x.add_theme_constant_override("icon_max_width",14);x.expand_icon=false;x.pressed.connect(close_fn);row.add_child(x)
 return row

# ---------------- pixel icons ----------------
## Rows of palette letters, '.' is clear. Items, HUD symbols and the close cross.
const ICONS={
 "well_water":[["..oooo....",".o....o...","oooooooo..","obbbbbbo.o","oBbBBBbooo","oBBBBBBo..",".oooooo..."],{"o":"635854","b":"96d0db","B":"579eaf"}],
 "honey":[["..oooo..","..wwww..",".oooooo.",".oYYYYo.",".oyYYyo.",".oyyyyo.",".oYYYyo.","..oooo.."],{"o":"85522e","w":"e9c68e","Y":"ffe29b","y":"e6a541"}],
 "dried_fish":[["....ooo..",".o.oYYo..",".ooYYyo..","..oyyyoo.","..oYyoo..",".ooYoo...","..ooo...."],{"o":"715342","Y":"e4bd85","y":"bc8d64"}],
 "chicken":[["....rrr...","...owwo...","..owweey..",".owwwwwo..","oWwwwwwo..",".oWWWwo...","..oooo....","...y.y...."],{"r":"ba554e","w":"fff2cd","W":"d4b594","o":"705348","e":"342829","y":"dc9a35"}],
 "egg":[["...oo...","..owwo..",".owwwwo.",".owwwwO.","owwwwWOo","owwwWWOo",".oWWWoo.","..oooo.."],{"o":"865a48","w":"fff0c9","W":"ead0a0","O":"d3ad88"}],
 "meat":[["...oooo...",".oorrrro..","orrrwrrro.","orrrwwrrro","orrrrwWrro",".orrrrwwro","..oRRRRoo.","...oooo..."],{"o":"895050","r":"de8174","R":"c26d61","w":"fbe6c4","W":"efbea7"}],
 "hide":[["oo....oo","oOooooOo",".oOOOOo.","..oOOo..",".oOOOOo.","oOOOOOOo","oo....oo"],{"o":"74513c","O":"c49765"}],
 "feather":[["......oo","....oWWo","...oWWwo","..oWWwo.",".oWWwo..",".oWw....","..o.....",".o......"],{"o":"80604e","w":"f7e5c7","W":"d2b18f"}],
 "seed":[[".oooooooo.",".owwwwwwo.",".owwgwwwo.",".owggGwwo.",".owwGgwwo.",".owwGwwwo.",".oyyyyyyo.",".oyyyyyyo.",".oooooooo."],{"o":"6b4a2c","w":"f6e6c8","g":"7fb04a","G":"55702a","y":"d8a85a"}],
 "hay":[[".oooooooo.",".oyYyyYyo.",".orrrrrro.",".oyyYyyYo.",".oYyyYyyo.",".orrrrrro.",".oyYyyYyo.",".oooooooo."],{"o":"7a5a2a","y":"e8c35a","Y":"c99a3a","r":"a0522d"}],
 "pig_feed":[["...o..o...","....tt....","...oSSo...","..osssso..",".osssssso.",".ossSSsso.",".osssssso.",".oSssssSo.","..oooooo.."],{"o":"5a3a20","s":"c98f5a","S":"a06a3a","t":"e8c35a"}],
 "fish_feed":[["..oooooo..",".obbbbbbo.",".oBBBBBBo.",".obpbbpbo.",".obbpbbbo.",".obbbbpbo.",".oBBBBBBo.","..oooooo.."],{"o":"2e4f6e","b":"7fb8d8","B":"4f88b0","p":"e8c35a"}],
 "wheat":[["....y.....","...yYy....","...yYy.y..","....g.yYy.",".y..g.yYy.","yYy.g..g..","yYy.g.g...",".g..gg....","..g.g.....","...gg....."],{"y":"e8b84a","Y":"b8862a","g":"7f9a3a"}],
 "carrot":[["......g.g.",".....gGg..","....OOg...","...oooO...","...ooO....","..ooO.....","..oO......",".oO.......",".O........"],{"o":"f08a3a","O":"c8602a","g":"6fbf4e","G":"4f8f2e"}],
 "fry":[["...cc.....","..cccc..c.",".cecccccc.",".ccccCCcc.","..cccc..c.","...cc....."],{"c":"7fd4e7","C":"4aa8c8","e":"2e4f6e"}],
 "veg":[["...gggg...","..gGwwGg..",".gGwwwwGg.",".gwwGGwwg.",".gGwwwwGg.",".dgGwwGgd.","..dggggd..","...dddd..."],{"g":"8fd66a","G":"5ea83a","d":"3f7a2a","w":"dff2c0"}],
 "milk":[["...oooo...","...obbo...","...owwo...","..owwwwo..",".owwwwwwo.",".obbbbbbo.",".owwwwwWo.",".owwwwwWo.",".oWWWWWWo.","..oooooo.."],{"o":"7a8aa0","w":"fdfaf2","W":"dcd6c8","b":"6f9ed8"}],
 "wool":[["...oooo...","..owWwwo..",".owwWwWwo.",".oWwwWwwo.",".owWwwWwo.",".owwWwwWo.","..owwWwo..","...oooo..."],{"o":"8a7a6a","w":"f3eee2","W":"d8cfbf"}],
 "fish":[["...bbb..B.","..bbbbbBB.",".bebbbbbB.",".bbwwbbBB.","..bbbbb.B.","...bbb...."],{"b":"5aa0d8","B":"3a78b0","e":"1e2a3a","w":"cfe6f5"}],
 "meal":[["...s.s....","....s.s...","..wwwwww..",".wwwwwwww.",".rrrrrrrr.",".RrrrrrrR.","..RrrrrR..","...RRRR..."],{"w":"fff4dc","r":"c4563f","R":"8f3a2a","s":"f2b26a"}],
 "cow":[[".o......o.",".oooooooo.",".owwbbwwo.",".owewwewo.",".owwwwbwo.",".obwwwwwo.","..oppppo..","..opoopo..","...oooo..."],{"o":"3a2a20","w":"fdfaf2","b":"3a2a20","e":"3a2a20","p":"f5b7c5"}],
 "sheep":[["..wWwwWw..",".wwwwwwwW.","wWwffffwwW","wwfeffefww","wWwffffwWw",".wwwffwww.","..wWwwWw..","...f..f..."],{"w":"f3eee2","W":"cfc5b3","f":"5a4a3c","e":"fdf3dd"}],
 "pig":[[".P......P.",".PppppppP.",".pppppppp.",".popppopp.",".ppnnnnpp.",".ppnonopp.",".ppnnnnpp.","..pppppp.."],{"p":"f5b7c5","P":"e98ea6","o":"6a3040","n":"d9788f"}],
 "coin":[["..oooo..",".oyhyyo.","oyhyyyYo","oyhYYyYo","oyyYYyYo","oyyyyyYo",".oYYYYo.","..oooo.."],{"o":"7a5a1a","y":"f2c94c","Y":"c99a2a","h":"fff4bf"}],
 "sun":[["...y....",".y.y..y.","..yyyy..",".yyyyyy.","yyyyyyyy",".yyyyyy.","..yyyy..",".y.y..y."],{"y":"e89a2a"}],
 "dusk":[["........","...oo...",".o.oo.o.","..oooo..",".oooooo.","oooooooo","pppppppp","..pppp.."],{"o":"f0a64a","p":"c4563f"}],
 "moon":[["..mmm...",".mmm....","mmm.....","mmm.....","mmm.....","mmmm...m",".mmmmmm.","..mmmm.."],{"m":"37508c"}],
 "bag":[["...oooo...","..oo..oo..",".oooooooo.",".obbbbbbo.",".obbttbbo.",".oBbttbBo.",".obbbbbbo.",".obbbbbbo.",".oBBBBBBo.","..oooooo.."],{"o":"2a1810","b":"f0c890","B":"d29a5c","t":"e0b24a"}],
 "map":[["oooooooooo","opppPpppPo","opgpPbbpPo","opggPbppPo","oppgPpprPo","opppPprrPo","oppbPpprPo","opbbPpppPo","opppPpppPo","oooooooooo"],{"o":"6b4a2c","p":"f6e6c8","P":"e2c99f","g":"7fb04a","b":"6f9ed8","r":"c4563f"}],
 "pin":[[".rrr.","rrwrr","rrrrr",".rrr.","..r.."],{"r":"c4563f","w":"fff4dc"}],
 "close":[["xx....xx","xxx..xxx",".xxxxxx.","..xxxx..","..xxxx..",".xxxxxx.","xxx..xxx","xx....xx"],{"x":"fdf3dd"}],
 "help":[["..xxxx..",".xx..xx.",".....xx.","....xx..","...xx...","...xx...","........","...xx..."],{"x":"fdf3dd"}],
}
const Garden=preload("res://qingxi-live/village-center/harvest/garden_kitchen.gd")
static func icon_texture(name:String,grey:=false)->Texture2D:
 var plant=name.trim_suffix("_seed")
 if Garden.book().recipes.has(name) or plant in ["tomato","eggplant","strawberry","watermelon"]:
  var cache_key=name+("~garden-grey" if grey else "~garden")
  if not _icons.has(cache_key):
   var img=Garden.texture(name if Garden.book().recipes.has(name) else plant+"-icon").get_image()
   img.resize(18,18,Image.INTERPOLATE_LANCZOS)
   if grey:img.adjust_bcs(.9,.88,0)
   _icons[cache_key]=ImageTexture.create_from_image(img)
  return _icons[cache_key]
 if name.begins_with("decor_"):
  var dkey=name+("~" if grey else "")
  if _icons.has(dkey):return _icons[dkey]
  var art=Image.load_from_file("res://qingxi-live/village-center/art/regions/props/"+name.substr(6)+".png")
  var k=minf(18.0/art.get_width(),16.0/art.get_height())
  art.resize(maxi(1,roundi(art.get_width()*k)),maxi(1,roundi(art.get_height()*k)),Image.INTERPOLATE_LANCZOS)
  var box=Image.create_empty(18,16,false,Image.FORMAT_RGBA8)
  box.blit_rect(art,Rect2i(Vector2i.ZERO,art.get_size()),Vector2i((18-art.get_width())/2,16-art.get_height()))
  if grey:box.adjust_bcs(.94,.85,0)
  var dt_=ImageTexture.create_from_image(box);_icons[dkey]=dt_;return dt_
 if name.begins_with("feeder_"):
  var fkey=name+("~" if grey else "")
  if _icons.has(fkey):return _icons[fkey]
  var src=Image.load_from_file("res://qingxi-live/village-center/art/regions/props/feeders/"+name+".png")
  var f=minf(18.0/src.get_width(),12.0/src.get_height())
  src.resize(maxi(1,roundi(src.get_width()*f)),maxi(1,roundi(src.get_height()*f)),Image.INTERPOLATE_LANCZOS)
  var canvas=Image.create_empty(18,14,false,Image.FORMAT_RGBA8)
  canvas.blit_rect(src,Rect2i(Vector2i.ZERO,src.get_size()),Vector2i((18-src.get_width())/2,14-src.get_height()))
  if grey:canvas.adjust_bcs(.94,.85,0)
  var ft=ImageTexture.create_from_image(canvas);_icons[fkey]=ft;return ft
 if name.begins_with("young_") and ":" in name:
  var cache_key=name+("~" if grey else "")
  if _icons.has(cache_key):return _icons[cache_key]
  var kind=name.get_slice(":",0).substr(6)
  var coat=int(name.get_slice(":",1))
  var file=kind+("_rare" if coat>=2 else "")
  if kind=="chicken" and coat<2 and name.ends_with(":m"):file="rooster"
  var atlas=Image.load_from_file("res://qingxi-live/village-center/art/garden-v3/breeds/"+file+".png")
  var img=atlas.get_region(Rect2i(56,coat%2*48,56,48))
  img.resize(18,16,Image.INTERPOLATE_LANCZOS)
  if grey:img.adjust_bcs(.94,.85,0)
  var tex=ImageTexture.create_from_image(img);_icons[cache_key]=tex;return tex
 name=name.get_slice(":",0)
 if name in ["pork","beef","poultry","mutton"]:name="meat"
 if name=="pelt":name="hide"
 if name.begins_with("young_"):name=name.substr(6)
 var key=name+("~" if grey else "")
 if _icons.has(key):return _icons[key]
 var def=ICONS.get(name,ICONS["seed"]);var rows:Array=def[0];var pal:Dictionary=def[1]
 var w=0
 for r in rows:w=maxi(w,str(r).length())
 var img=Image.create_empty(w,rows.size(),false,Image.FORMAT_RGBA8)
 for y in rows.size():
  var line=str(rows[y])
  for x in line.length():
   if line[x]!=".":
    var c=Color(pal[line[x]])
    if grey:var v=c.get_luminance();c=Color(v,v,v).lerp(Color("d8cfbf"),.55)
    img.set_pixel(x,y,c)
 var t=ImageTexture.create_from_image(img);_icons[key]=t;return t
static func icon(name:String,scale_:=2,grey:=false)->TextureRect:
 var t=icon_texture(name,grey);var r=TextureRect.new();r.texture=t;r.texture_filter=CanvasItem.TEXTURE_FILTER_NEAREST
 r.expand_mode=TextureRect.EXPAND_IGNORE_SIZE;r.stretch_mode=TextureRect.STRETCH_KEEP_ASPECT_CENTERED
 r.custom_minimum_size=Vector2(t.get_width(),t.get_height())*scale_;r.mouse_filter=Control.MOUSE_FILTER_IGNORE;return r

# ---------------- shared game widgets ----------------
## Coin counter: dark chip, pixel coin, bold number.
static func coin_chip(amount)->PanelContainer:
 var p=panel("chip");var row=HBoxContainer.new();row.add_theme_constant_override("separation",4);p.add_child(row)
 row.add_child(icon("coin",2));var l=label(str(int(amount)),13,CREAM,true);l.name="Amount";row.add_child(l);return p
## One inventory slot: icon, count in the corner; empty items stay as greyed outlines.
## Scroll bars as a thin wood rail with a wood grip.
static func style_scroll(sc:ScrollContainer):
 var bar=sc.get_v_scroll_bar()
 var rail=StyleBoxFlat.new();rail.bg_color=PAPER_D;rail.content_margin_left=3;rail.content_margin_right=3
 var grip=StyleBoxFlat.new();grip.bg_color=WOOD_L;grip.border_color=WOOD_D;grip.set_border_width_all(1)
 var grip_hi=grip.duplicate();grip_hi.bg_color=WOOD_H
 bar.add_theme_stylebox_override("scroll",rail);bar.add_theme_stylebox_override("scroll_focus",rail)
 bar.add_theme_stylebox_override("grabber",grip);bar.add_theme_stylebox_override("grabber_highlight",grip_hi);bar.add_theme_stylebox_override("grabber_pressed",grip_hi)
 sc.vertical_scroll_mode=ScrollContainer.SCROLL_MODE_AUTO
## Window height follows its content (up to max_h), so short menus have no dead space.
static func fit(sc:ScrollContainer,body:Control,max_h:=330.0):
 sc.custom_minimum_size.y=clampf(body.get_combined_minimum_size().y,40.0,max_h)
static func slot(key:String,count:int,size_:=40)->PanelContainer:
 var p=panel("slot" if count>0 else "slot_off");p.custom_minimum_size=Vector2(size_,size_);p.mouse_filter=Control.MOUSE_FILTER_STOP
 var holder=Control.new();holder.mouse_filter=Control.MOUSE_FILTER_IGNORE;p.add_child(holder)
 var ic=icon(key,2,count<=0);ic.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT);holder.add_child(ic)
 if count>0:
  var n=label(str(count),10,CREAM,true,WOOD_D);n.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_RIGHT);n.grow_horizontal=Control.GROW_DIRECTION_BEGIN;n.grow_vertical=Control.GROW_DIRECTION_BEGIN
  n.position+=Vector2(2,3);holder.add_child(n)
 p.mouse_entered.connect(func():p.add_theme_stylebox_override("panel",frame("slot_hi")))
 p.mouse_exited.connect(func():p.add_theme_stylebox_override("panel",frame("slot" if count>0 else "slot_off")))
 return p
## The bag: grouped slot grids and a detail line that names whatever is under the mouse.
const BAG_GROUPS=[["种子与饲料",["seed","wheat","carrot","hay","pig_feed","fish_feed","fry"]],["幼畜",["young_cow","young_sheep","young_pig"]],["牧场设施",["feeder_cow","feeder_sheep","feeder_pig","feeder_chicken"]],["农具",["well_water"]],["摆设",[]],["收获",["veg","milk","wool","fish","dried_fish","honey"]],["料理",["meal"]]]
## use: optional Callable(key) run when a slot is clicked; usable(key) says which slots react.
static func inventory(body:Control,bag:Dictionary,names:Dictionary,details:=Callable(),use:=Callable(),usable:=Callable()):
 var detail=label(" ",11,INK2)
 var delay=0.0
 for group in BAG_GROUPS:
  var keys=[]
  for key in group[1]:
   if bag.has(key):keys.append(str(key))
  for key in bag:
   if int(bag[key])<=0 or key in keys:continue
   if group[0]=="种子与饲料" and key.ends_with("_seed") and Garden.book().produce.has(key):keys.append(key)
   elif group[0]=="收获" and key in ["tomato","eggplant","strawberry","watermelon"]:keys.append(key)
   elif group[0]=="料理" and Garden.book().recipes.has(key):keys.append(key)
   elif group[0]=="幼畜" and key.begins_with("young_"):keys.append(key)
   elif group[0]=="摆设" and key.begins_with("decor_") and int(bag[key])>0:keys.append(key)
   elif group[0]=="收获" and preload("res://qingxi-live/village-center/breed_catalog.gd").price(key)>0:keys.append(key)
  if keys.is_empty():continue
  var head=HBoxContainer.new();head.add_theme_constant_override("separation",6);body.add_child(head)
  head.add_child(label(group[0],11,INK2,true))
  var rule=ColorRect.new();rule.color=PAPER_D;rule.custom_minimum_size=Vector2(0,2);rule.size_flags_horizontal=Control.SIZE_EXPAND_FILL;rule.size_flags_vertical=Control.SIZE_SHRINK_CENTER;head.add_child(rule)
  var grid=GridContainer.new();grid.columns=8;grid.add_theme_constant_override("h_separation",4);grid.add_theme_constant_override("v_separation",4);body.add_child(grid)
  for key in keys:
   var count=int(bag[key]);var s=slot(key,count);grid.add_child(s)
   var line="%s ×%d"%[names.get(key,key),count]
   if details.is_valid():line+=str(details.call(key))
   s.set_meta("bag_item",key);s.tooltip_text=line
   if use.is_valid() and count>0 and (not usable.is_valid() or usable.call(key)):
    s.mouse_default_cursor_shape=Control.CURSOR_POINTING_HAND
    s.gui_input.connect(func(e):if e is InputEventMouseButton and e.pressed and e.button_index==MOUSE_BUTTON_LEFT:use.call(key))
   s.mouse_entered.connect(func():detail.text=line;detail.add_theme_color_override("font_color",INK))
   s.mouse_exited.connect(func():detail.text=" ")
   s.modulate.a=0.0;s.scale=Vector2(.8,.8);s.pivot_offset=Vector2(20,20)
   var tw=s.create_tween().set_parallel(true);tw.tween_property(s,"modulate:a",1.0,.14).set_delay(delay)
   tw.tween_property(s,"scale",Vector2.ONE,.18).set_delay(delay).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT);delay+=.02
 var total=0
 for key in bag:total+=int(bag[key])
 var idle="共 %d 件"%total;detail.text=idle
 for grid in body.find_children("*","GridContainer",false,false):
  for s in grid.get_children():s.mouse_exited.connect(func():detail.text=idle;detail.add_theme_color_override("font_color",INK2))
 var foot=panel("slot_off");foot.add_child(detail);body.add_child(foot)
## A shop counter row: item slot, name, price tag and a green buy button.
static func shop_row(key:String,title:String,sub:String,price:int,affordable:bool,fn:Callable,verb:="买")->PanelContainer:
 var p=panel("slot");var st=frame("slot").duplicate();st.content_margin_left=4;st.content_margin_right=5;st.content_margin_top=2;st.content_margin_bottom=2;p.add_theme_stylebox_override("panel",st)
 p.mouse_entered.connect(func():p.add_theme_stylebox_override("panel",st));p.mouse_exited.connect(func():p.add_theme_stylebox_override("panel",st))
 var row=HBoxContainer.new();row.add_theme_constant_override("separation",8);p.add_child(row)
 row.add_child(icon(key,2))
 var col=HBoxContainer.new();col.add_theme_constant_override("separation",8);col.size_flags_horizontal=Control.SIZE_EXPAND_FILL;row.add_child(col)
 var t=label(title,12,INK,true);t.size_flags_vertical=Control.SIZE_SHRINK_CENTER;col.add_child(t)
 var s=label(sub,10,INK2);s.size_flags_vertical=Control.SIZE_SHRINK_CENTER;col.add_child(s)
 var tag=HBoxContainer.new();tag.add_theme_constant_override("separation",3);tag.size_flags_vertical=Control.SIZE_SHRINK_CENTER;row.add_child(tag)
 tag.add_child(icon("coin",2));tag.add_child(label(str(price),13,Color("8a5a14") if affordable else RED,true))
 var b=button(verb,fn,true);b.disabled=not affordable;b.custom_minimum_size=Vector2(48,24);b.size_flags_vertical=Control.SIZE_SHRINK_CENTER;b.set_meta("item",key);row.add_child(b)
 return p
## Key list for the help window: keycap + what it does.
static func key_rows(body:Control,rows:Array):
 var grid=GridContainer.new();grid.columns=2;grid.add_theme_constant_override("h_separation",12);grid.add_theme_constant_override("v_separation",6);body.add_child(grid)
 for r in rows:
  var keys=HBoxContainer.new();keys.add_theme_constant_override("separation",3);keys.custom_minimum_size=Vector2(120,0);grid.add_child(keys)
  for k in str(r[0]).split(" "):keys.add_child(keycap(k))
  grid.add_child(label(str(r[1]),12,INK))
## Menu pop-in shared by every window.
static func pop_in(node:Control):
 node.pivot_offset=node.size/2;node.modulate.a=0.0;node.scale=Vector2(.9,.9)
 var tw=node.create_tween().set_parallel(true);tw.tween_property(node,"modulate:a",1.0,.12)
 tw.tween_property(node,"scale",Vector2.ONE,.22).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
