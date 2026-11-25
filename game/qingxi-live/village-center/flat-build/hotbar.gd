extends Control
const KIT=preload("res://qingxi-live/village-center/ui_kit.gd")
const DEFAULT=["plot","fence","gate","path","channel","barn_unit","house_unit","feeder_cow","bridge"]
const ART={"bridge":"res://qingxi-live/village-center/art/garden-v3/sprites/wood_h.png","plot":"res://qingxi-live/village-center/art/regions/props/plot_soil.png","fence":"res://qingxi-live/village-center/art/regions/props/fence_h.png","gate":"res://qingxi-live/village-center/art/regions/props/fence_h.png","barn_unit":"res://qingxi-live/ranch-life/art/barn-exterior.png","house_unit":"res://qingxi-live/village-center/art/regions/props/cottage.png","path":"res://qingxi-live/village-center/art/garden-v3/sprites/earth.png","channel":"res://qingxi-live/village-center/art/garden-v3/sprites/water.png"}
var world
var row=HBoxContainer.new()
var library:PanelContainer
var slots=[]
var buttons=[]
var active=0
var names={}
var icons={}
var counts=[]
var entries={}
var tabs={}
var scroller:ScrollContainer

func setup(host):
 world=host;set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT);mouse_filter=MOUSE_FILTER_IGNORE
 texture_filter=CanvasItem.TEXTURE_FILTER_NEAREST
 for entry in world.editor_catalog():names[entry[0]]=entry[1]
 var layout=world.layout_save()
 var stored=layout.get("meadow_hotbar",DEFAULT)
 for i in DEFAULT.size():
  var id=str(stored[i]) if i<stored.size() else ""
  if id in ["feeder_chicken","feeder_sheep","feeder_pig"]:id="feeder_cow"
  if not names.has(id) or id in slots:id=""
  slots.append(id)
 for i in slots.size():
  if slots[i]=="":slots[i]=DEFAULT.filter(func(id):return id not in slots)[0]
 active=clampi(int(layout.get("meadow_slot",0)),0,slots.size()-1)
 add_child(row);row.add_theme_constant_override("separation",3)
 for i in slots.size():
  var b=KIT.button("",select.bind(i));b.focus_mode=Control.FOCUS_NONE
  b.custom_minimum_size=Vector2(41,39);row.add_child(b)
  var art=TextureRect.new();art.position=Vector2(9,8);art.size=Vector2(27,24)
  art.expand_mode=TextureRect.EXPAND_IGNORE_SIZE;art.stretch_mode=TextureRect.STRETCH_KEEP_ASPECT_CENTERED;art.mouse_filter=MOUSE_FILTER_IGNORE;b.add_child(art)
  var number=KIT.label(str(i+1),9,KIT.CREAM,true,KIT.WOOD_D);number.mouse_filter=MOUSE_FILTER_IGNORE;number.position=Vector2(4,0);b.add_child(number)
  var qty=KIT.label("",9,KIT.CREAM,true,KIT.WOOD_D);qty.mouse_filter=MOUSE_FILTER_IGNORE;qty.position=Vector2(24,23);b.add_child(qty);counts.append(qty)
  b.set_drag_forwarding(begin_slot_drag.bind(i,b),accept_drop,drop_on.bind(i))
  buttons.append(b)
 row.add_child(KIT.button("设施库",toggle_library))
 library=KIT.panel("window");add_child(library);library.hide();library.custom_minimum_size=Vector2(406,0)
 var column=VBoxContainer.new();library.add_child(column)
 var head=HBoxContainer.new();column.add_child(head)
 var title=KIT.label("设施库",15,KIT.INK,true);title.size_flags_horizontal=Control.SIZE_EXPAND_FILL;head.add_child(title)
 head.add_child(KIT.button("关闭",close_library))
 column.add_child(KIT.label("拖到下方格子，或点击替换当前选中格。",10,KIT.INK2))
 var categories=HBoxContainer.new();column.add_child(categories)
 for name_ in ["全部","地面","建造","家具","牧养","生活","农务"]:
  var tab=KIT.button(name_,filter_library.bind(name_));categories.add_child(tab);tabs[name_]=tab
 scroller=ScrollContainer.new();scroller.custom_minimum_size=Vector2(0,132);column.add_child(scroller)
 var grid=GridContainer.new();grid.columns=3;scroller.add_child(grid)
 for id in names:
  var b=KIT.button("",equip_current.bind(id));b.focus_mode=Control.FOCUS_NONE
  b.custom_minimum_size=Vector2(120,39);b.tooltip_text=names[id]
  var plate=ColorRect.new();plate.color=Color("e1cba2");plate.position=Vector2(4,3);plate.size=Vector2(39,32)
  plate.mouse_filter=Control.MOUSE_FILTER_IGNORE;b.add_child(plate)
  var icon=TextureRect.new();icon.texture=icon_for(id);icon.expand_mode=TextureRect.EXPAND_IGNORE_SIZE
  icon.stretch_mode=TextureRect.STRETCH_KEEP_ASPECT_CENTERED;icon.position=Vector2(2,1);icon.size=Vector2(35,30)
  icon.mouse_filter=Control.MOUSE_FILTER_IGNORE;plate.add_child(icon)
  var label=KIT.label(names[id],11,KIT.CREAM,true,KIT.WOOD_D);label.position=Vector2(47,0);label.size=Vector2(70,38)
  label.vertical_alignment=VERTICAL_ALIGNMENT_CENTER;label.text_overrun_behavior=TextServer.OVERRUN_TRIM_ELLIPSIS
  label.mouse_filter=Control.MOUSE_FILTER_IGNORE;b.add_child(label)
  b.set_drag_forwarding(begin_drag.bind(id,b),Callable(),Callable());grid.add_child(b);entries[id]=b
 filter_library("全部")
 render_slots()
 hide()

func filter_library(category:String):
 for id in entries:
  var group="建造"
  if id.begins_with("furn:"):group="家具"
  elif id in world.Grid.FLOORS:group="地面"
  elif id.begins_with("feeder_") or id in ["prop:haybale","prop:haystack","prop:milk_cans"]:group="牧养"
  elif id in ["prop:lantern","prop:bench","prop:well","prop:mailbox","prop:signpost","prop:laundry","prop:barrel","prop:crate"]:group="生活"
  elif id.begins_with("prop:"):group="农务"
  entries[id].visible=category=="全部" or category==group
 for tab in tabs:KIT.style_button(tabs[tab],tab==category)
 scroller.scroll_vertical=0

func icon_for(id:String)->Texture2D:
 if icons.has(id):return icons[id]
 var img:Image
 if id.begins_with("prop:"):
  img=Image.load_from_file("res://qingxi-live/village-center/art/regions/props/"+id.substr(5)+".png")
 elif id.begins_with("feeder_"):
  img=Image.load_from_file("res://qingxi-live/village-center/art/regions/props/feeders/"+id+".png")
 elif id=="furn:pet_shelter":
  img=Image.new()
  img.load_png_from_buffer(FileAccess.get_file_as_bytes("res://qingxi-live/village-center/art/garden-v3/pets/shelter.png"))
 elif id=="furn:pet_bed":
  img=preload("res://core/pet_comfort.gd").texture().get_image()
 elif id.begins_with("furn:"):
  var art_ref=world.Grid.ITEMS[id.substr(5)][1]   # 2026-11-19 Claude: Cabin World pieces load by file
  img=(world.Grid.cabin_texture(art_ref) if art_ref is String else world.rooms.art[art_ref]).get_image()
 elif id=="bedding":
  img=Image.create_empty(24,24,false,Image.FORMAT_RGBA8);img.fill(Color("d9b374"))
  for i in 16:img.fill_rect(Rect2i((i*7)%17,(i*11)%24,5,1),Color("f1d49c"))
 elif id=="stairs":
  img=Image.create_empty(24,24,false,Image.FORMAT_RGBA8);img.fill(Color("5f4029"))
  for y in range(0,24,4):img.fill_rect(Rect2i(3,y,18,3),Color("d09a66"))
 else:
  var path=world.Grid.FLOORS[id][1] if world.Grid.FLOORS.has(id) else ART.get(id,ART.plot)
  img=Image.load_from_file(path)
 if id=="gate":img=img.get_region(Rect2i(0,0,img.get_width()/2,img.get_height()))
 var used=img.get_used_rect()
 if used.has_area():img=img.get_region(used)
 # Preserve small source sprites at native resolution; prefilter only oversized art.
 var scale_=minf(70.0/img.get_width(),60.0/img.get_height())
 if scale_<1.:img.resize(maxi(1,roundi(img.get_width()*scale_)),maxi(1,roundi(img.get_height()*scale_)),Image.INTERPOLATE_LANCZOS)
 icons[id]=ImageTexture.create_from_image(img);return icons[id]

func render_slots():
 for i in buttons.size():
  var b:Button=buttons[i];var id=str(slots[i]);var thumb:TextureRect=b.get_child(0)
  thumb.texture=icon_for(id);KIT.style_button(b,i==active);b.tooltip_text="%d · %s"%[i+1,names[id]]
 world.build_tool=slots[active];world.queue_redraw()

func select(i:int):
 active=i;world.layout_save().meadow_slot=i
 world.clear_build_gesture()
 render_slots()

func equip(i:int,id:String):
 if not names.has(id):return
 var other=slots.find(id);var old=slots[i]
 if other>=0:slots[other]=old
 slots[i]=id;world.layout_save().meadow_hotbar=slots.duplicate()
 select(i);world.save_progress()

func equip_current(id:String):equip(active,id)
func begin_slot_drag(p:Vector2,i:int,b:Button):return begin_drag(p,slots[i],b)
func begin_drag(_p:Vector2,id:String,b:Button):
 var preview=TextureRect.new();preview.texture=icon_for(id);preview.custom_minimum_size=Vector2(34,30)
 preview.stretch_mode=TextureRect.STRETCH_KEEP_ASPECT_CENTERED;b.set_drag_preview(preview)
 return {"meadow_item":id}
func accept_drop(_p:Vector2,data)->bool:
 return data is Dictionary and names.has(data.get("meadow_item",""))
func drop_on(_p:Vector2,data,i:int):equip(i,str(data.meadow_item))
func close_library():library.hide()
func toggle_library():
 library.visible=not library.visible
 world.clear_build_gesture()

func refresh():
 visible=world.build_mode and world.can_build() and not world.overlay.visible
 if not visible:close_library();return
 for i in slots.size():
  var id=str(slots[i])
  counts[i].text=str(int(world.sim.data.bag.get(id,0))) if id.begins_with("feeder_") else ""
 var screen=get_viewport_rect().size
 row.position=Vector2(roundf((screen.x-row.size.x)/2),screen.y-row.size.y-5)
 library.position=Vector2(roundf((screen.x-library.size.x)/2),row.position.y-library.size.y-28)

