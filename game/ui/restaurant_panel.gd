extends PanelContainer
var service:Node
var actor:OptionButton
var category:OptionButton
var list:VBoxContainer
var message:Label
var choice:Label
var selected=""
var elapsed=0.0
var settling=false
func _ready():
 var theme_of=Theme.new()
 var font=SystemFont.new();font.font_names=PackedStringArray(["Microsoft YaHei"])
 theme_of.default_font=font;theme_of.default_font_size=17
 for type in ["Label","Button","OptionButton"]:theme_of.set_color("font_color",type,Hud.INK)
 for type in ["Button","OptionButton"]:
  for state in ["normal","hover","pressed"]:
   var b=StyleBoxFlat.new();b.bg_color=Hud.PAPER_H if state=="normal" else Hud.PAPER_D
   b.border_color=Hud.WOOD_L;b.set_border_width_all(2);b.set_content_margin_all(7);theme_of.set_stylebox(state,type,b)
 theme=theme_of
 var box=StyleBoxFlat.new();box.bg_color=Hud.PAPER;box.border_color=Hud.WOOD
 box.set_border_width_all(4);box.set_content_margin_all(12);add_theme_stylebox_override("panel",box)
 var col=VBoxContainer.new();col.add_theme_constant_override("separation",8);add_child(col)
 var title=Label.new();title.text="餐厅菜单";title.add_theme_font_size_override("font_size",24);col.add_child(title)
 actor=OptionButton.new()
 for c in service.host.characters:actor.add_item(c.display_name)
 col.add_child(actor)
 category=OptionButton.new()
 for name in ["中餐","日料","美式快餐"]:category.add_item(name)
 category.item_selected.connect(func(_i):populate());col.add_child(category)
 var scroll=ScrollContainer.new();scroll.size_flags_vertical=Control.SIZE_EXPAND_FILL;col.add_child(scroll)
 list=VBoxContainer.new();list.size_flags_horizontal=Control.SIZE_EXPAND_FILL;scroll.add_child(list)
 choice=Label.new();choice.autowrap_mode=TextServer.AUTOWRAP_WORD_SMART;col.add_child(choice)
 for spec in [["找收银员点菜","order"],["自己去后厨做菜","cook"],["吃背包里的这道菜","eat"]]:
  var b=Button.new();b.text=spec[0];b.pressed.connect(command.bind(spec[1]));col.add_child(b)
 var row=HBoxContainer.new();col.add_child(row)
 for spec in [["坐下休息","sit"],["取消安排","cancel"]]:
  var b=Button.new();b.text=spec[0];b.size_flags_horizontal=Control.SIZE_EXPAND_FILL
  b.pressed.connect(command.bind(spec[1]));row.add_child(b)
 message=Label.new();message.autowrap_mode=TextServer.AUTOWRAP_WORD_SMART;message.custom_minimum_size.y=64;col.add_child(message)
 populate()
 visibility_changed.connect(func():
  if visible:call_deferred("settle_layout"))
 call_deferred("settle_layout")
func settle_layout():
 if settling:return
 settling=true
 # Wrapping labels first need the real sidebar width. Containers can expand a
 # zero-width panel during readiness; reapply its assigned height after sorting.
 for frame in 4:await get_tree().process_frame
 if visible:service.host._layout()
 settling=false
func populate():
 for n in list.get_children():n.queue_free()
 var group=category.get_item_text(category.selected)
 var options=service.menu.dishes.filter(func(d):return d.category==group)
 if options.all(func(d):return d.id!=selected):selected=options[0].id
 for dish in options:
  var button=Button.new();button.text=dish.name+"  "+str(int(dish.price))+" 币"
  button.alignment=HORIZONTAL_ALIGNMENT_LEFT;button.custom_minimum_size.y=88
  var texture=AtlasTexture.new();texture.atlas=load(service.menu.sheet)
  var r:Array=dish.region;texture.region=Rect2(r[0],r[1],r[2],r[3])
  button.icon=texture;button.expand_icon=true;button.add_theme_constant_override("icon_max_width",76)
  button.pressed.connect(func():selected=dish.id;update_choice());list.add_child(button)
 update_choice()
func update_choice():
 if choice:choice.text="已选："+service.dishes[selected].name+"\n点菜按菜单扣币；后厨提供基础食材。"
func command(kind:String):
 if actor.selected<0:return
 var c=service.host.characters[actor.selected]
 if kind=="cancel":service.cancel(c.key)
 else:
  var answer=service.start(c.key,kind,selected)
  if not answer.ok:service.status=answer.error
func _process(delta:float):
 elapsed+=delta
 if elapsed<.25:return
 elapsed=0
 if not visible or message==null:return
 var lines=[]
 var labels={"walk":"前往操作位置","order":"正在点菜","cook":"正在做菜","pickup":"正在取餐","eat":"正在用餐","sit":"坐下休息"}
 for key in service.jobs:
  var job:Dictionary=service.jobs[key]
  var action="walk" if job.phase=="walk" else job.steps[job.index].action
  lines.append(service.resident(key).display_name+"："+labels.get(action,action))
 message.text="\n".join(PackedStringArray(lines)) if not lines.is_empty() else service.status
