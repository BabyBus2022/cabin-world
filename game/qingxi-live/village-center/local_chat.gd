extends CanvasLayer
const KIT=preload("res://qingxi-live/village-center/ui_kit.gd")
const ASSETS="res://qingxi-live/village-center/art/chat-stickers/"
const GROUP="village"
func resident_names()->Dictionary:
 var rows={}
 for person in Residents.people():rows[person.key]=person.name
 return rows
var file:String
var messages:Array=[]
var stickers:Dictionary={}
var art:Dictionary={}
var hidden_stickers:Dictionary={}
var custom_stickers:Dictionary={}
const RECALL_SECONDS:=120
const MAX_STICKERS:=80
var backdrop:Control
var input:LineEdit
var status:Label
var seq:=0

func setup(path:String):
 file=path;layer=54
 var parsed=JSON.parse_string(FileAccess.get_file_as_string(file)) if FileAccess.file_exists(file) else null
 if parsed is Dictionary and parsed.get("messages") is Array:
  messages=parsed.messages;seq=int(parsed.get("seq",0))
  if parsed.get("hiddenStickers") is Dictionary:hidden_stickers=parsed.hiddenStickers
  if parsed.get("customStickers") is Dictionary:custom_stickers=parsed.customStickers
 var index=JSON.parse_string(FileAccess.get_file_as_string(ASSETS+"index.json"))
 if index is Array:
  for sticker in index:stickers[sticker.id]=sticker.times
 for id in custom_stickers:
  if valid_custom_id(str(id)) and FileAccess.file_exists(sticker_file(id)):stickers[id]=[100]
 build_ui()

func opened()->bool:return is_instance_valid(backdrop) and backdrop.visible

func _input(event):
 if not event is InputEventKey or not event.pressed or event.echo:return
 if event.physical_keycode==KEY_Y and not opened():
  open_chat();get_viewport().set_input_as_handled()
 elif opened() and event.physical_keycode==KEY_ESCAPE:
  backdrop.hide()
  get_viewport().set_input_as_handled()

func open_chat():
 backdrop.show()
 input.grab_focus()

func build_ui():
 backdrop=KIT.panel("window")
 backdrop.set_anchors_preset(Control.PRESET_CENTER_BOTTOM)
 backdrop.offset_left=-262;backdrop.offset_right=262
 backdrop.offset_top=-126;backdrop.offset_bottom=-70
 add_child(backdrop);backdrop.hide()
 var wrap=VBoxContainer.new();backdrop.add_child(wrap)
 var composer=HBoxContainer.new();wrap.add_child(composer)
 input=LineEdit.new()
 input.placeholder_text="发到群聊 · 可 @ 住户"
 input.max_length=500
 input.size_flags_horizontal=Control.SIZE_EXPAND_FILL
 input.add_theme_font_override("font",KIT.font())
 input.add_theme_font_size_override("font_size",17)
 input.add_theme_color_override("font_color",KIT.INK)
 input.add_theme_color_override("font_placeholder_color",KIT.INK2)
 input.add_theme_color_override("caret_color",KIT.INK)
 var field=StyleBoxFlat.new()
 field.bg_color=Color("fff7e7");field.border_color=Color("b99068")
 field.set_border_width_all(1)
 field.content_margin_left=8;field.content_margin_right=8
 input.add_theme_stylebox_override("normal",field)
 input.add_theme_stylebox_override("focus",field)
 composer.add_child(input)
 input.text_submitted.connect(func(value):submit(value,""))
 composer.add_child(KIT.button("发送",func():submit(input.text,"")))
 composer.add_child(KIT.button("群聊",open_desktop_chat))
 status=KIT.label("",14,Color("a04e39"))
 wrap.add_child(status);status.hide()

func open_desktop_chat():
 var host=get_tree().get_meta("qingxi_world_host",false)
 if host:host.open_desktop_chat()
 else:notify_error("请先打开 VADS")

func sticker_texture(id:String,animated:bool)->Texture2D:
 var key=id+str(animated)
 if art.has(key):return art[key]
 var custom=valid_custom_id(id)
 var raw=Image.load_from_file(sticker_file(id) if custom else ASSETS+id+".png")
 if raw==null or raw.is_empty():return null
 var tex:Texture2D=ImageTexture.create_from_image(raw)
 if custom:art[key]=tex;return tex
 if stickers[id].size()>1 and animated:
  var animation=AnimatedTexture.new()
  animation.frames=stickers[id].size()
  for i in animation.frames:
   animation.set_frame_texture(i,ImageTexture.create_from_image(raw.get_region(sticker_rect(i))))
   animation.set_frame_duration(i,maxf(.031,float(stickers[id][i])/1000.0))
  art[key]=animation
 else:art[key]=sticker_frame(tex,0)
 return art[key]

func valid_custom_id(id:String)->bool:
 return id.begins_with("custom-") and id.length()==31 and id.substr(7).is_valid_hex_number()

func sticker_file(id:String)->String:
 return file.get_base_dir().path_join("qingxi-stickers").path_join(id+".png")

func toggle_saved(id:String)->Dictionary:
 if not stickers.has(id):return {"ok":false,"error":"找不到这个表情"}
 var next=hidden_stickers.duplicate()
 if next.has(id):next.erase(id)
 else:next[id]=true
 if not persist(messages,seq,next,custom_stickers):return {"ok":false,"error":"表情保存失败"}
 hidden_stickers=next
 return {"ok":true}

func import_sticker(path:String)->Dictionary:
 if custom_stickers.size()>=MAX_STICKERS:return {"ok":false,"error":"表情库已满"}
 var file_=FileAccess.open(path,FileAccess.READ)
 if file_==null or file_.get_length()>8*1024*1024:return {"ok":false,"error":"请选 8 MB 以内的图片"}
 file_.close()
 var image_=Image.load_from_file(path)
 if image_==null or image_.is_empty():return {"ok":false,"error":"无法读取这张图片"}
 var token:String=Marshalls.raw_to_base64(Crypto.new().generate_random_bytes(16)).sha256_text().left(24)
 var id="custom-"+token
 var edge=maxi(image_.get_width(),image_.get_height())
 if edge>256:
  var size_=Vector2(image_.get_size())*256.0/edge
  image_.resize(maxi(1,roundi(size_.x)),maxi(1,roundi(size_.y)),Image.INTERPOLATE_LANCZOS)
 var path_=sticker_file(id)
 DirAccess.make_dir_recursive_absolute(path_.get_base_dir())
 if image_.save_png(path_)!=OK:return {"ok":false,"error":"图片保存失败"}
 var next=custom_stickers.duplicate()
 next[id]=path.get_file().get_basename().left(48)
 if not persist(messages,seq,hidden_stickers,next):
  DirAccess.remove_absolute(path_)
  return {"ok":false,"error":"表情库保存失败"}
 custom_stickers=next
 stickers[id]=[100]
 return {"ok":true,"sticker_id":id}

func notify_error(reason:String):
 status.text=reason
 status.visible=reason!=""

func desktop_snapshot()->Dictionary:
 var rows=[]
 for row in history():
  var item:Dictionary=row.duplicate()
  item.erase("route");item.erase("transport");item.erase("to");item.erase("invite")
  item.sender_kind=sender_kind(str(row.actor))
  rows.append(item)
 return {"messages":rows,"stickers":stickers.keys().map(func(id):return {"id":id,"hidden":hidden_stickers.has(id)})}

func persist(rows:Array,n:int,hidden:Dictionary,custom:Dictionary)->bool:
 DirAccess.make_dir_recursive_absolute(file.get_base_dir())
 var tmp=file+".tmp"
 var f=FileAccess.open(tmp,FileAccess.WRITE)
 if f==null:return false
 f.store_string(JSON.stringify({"seq":n,"messages":rows,"hiddenStickers":hidden,"customStickers":custom}))
 f.close()
 return DirAccess.rename_absolute(tmp,file)==OK

func recall(actor:String,id:int,remote_transport:="",verified_remote:=false)->Dictionary:
 var index=messages.find_custom(func(row):
  return (row.get("transport","")==remote_transport if remote_transport!="" else row.id==id and row.actor==actor and row.source=="game"))
 if index<0:return {"ok":false,"error":"找不到可撤回的消息"}
 var old:Dictionary=messages[index]
 if old.get("recalled",false):return {"ok":true}
 if not verified_remote and remote_transport=="" and Time.get_unix_time_from_system()-float(old.at)>RECALL_SECONDS:
  return {"ok":false,"error":"超过两分钟，无法撤回"}
 var row=old.duplicate()
 row.merge({"recalled":true,"text":"","sticker":"","to":[],"route":{}},true)
 var next=messages.duplicate()
 next[index]=row
 if not persist(next,seq,hidden_stickers,custom_stickers):return {"ok":false,"error":"撤回保存失败"}
 messages=next
 var host=get_tree().get_meta("qingxi_world_host",false)
 if host:host.chat_posted(row)
 return {"ok":true,"message":row}

func sticker_frame(tex:Texture2D,i:int)->AtlasTexture:
 var region=AtlasTexture.new();region.atlas=tex;region.filter_clip=true
 region.region=sticker_rect(i)
 return region

func sticker_rect(i:int)->Rect2i:return Rect2i((i%8)*96,(i/8)*96,96,96)

func history(room:=GROUP)->Array:
 if room!=GROUP:return []
 var rows=messages.filter(func(row):return row.room==GROUP)
 return rows.slice(maxi(0,rows.size()-70))

func names()->Dictionary:
 var host=get_tree().get_meta("qingxi_world_host",false)
 var result=resident_names().duplicate()
 result.owner=host.owner_display_name() if host else "你"
 return result

func addressed(actor:String,value:String,explicit:String)->Array:
 var list=[]
 var labels=names()
 for id in labels:
  if id==actor:continue
  if id==explicit or ("@"+str(labels[id])) in value:list.append(id)
 return list

func sender_kind(actor:String)->String:
 return "bot" if resident_names().has(actor) else ("player" if actor=="owner" else "qq_member")

func send(actor:String,name_:String,room:String,message:String,sticker:String="",target:="",reply_to:=0,source:="game",transport:="",invite:="")->Dictionary:
 if room!=GROUP or (source=="game" and actor!="owner" and not resident_names().has(actor)):
  return {"ok":false,"error":"消息只能发到群聊"}
 if transport!="":
  var existing=messages.filter(func(row):return row.get("transport","")==transport)
  if not existing.is_empty():return {"ok":true,"message":existing[0]}
 var value=message.strip_edges().left(500)
 var live_bot=source=="game" and resident_names().has(actor)
 var labels=names()
 if live_bot and labels.has(target) and actor!=target and ("@"+str(labels[target])) not in value:
  value=("@"+str(labels[target])+" "+value).strip_edges().left(500)
 var mentions=addressed(actor,value,target if source=="qq" or live_bot else "")
 var routing={}
 if live_bot:
  routing={"sender":actor,"recipients":mentions.filter(func(id):return resident_names().has(id)),"replyTo":reply_to}
 if value=="" and not stickers.has(sticker):return {"ok":false,"error":"请填写消息或选一个表情"}
 if sticker!="" and not stickers.has(sticker):return {"ok":false,"error":"找不到这个表情"}
 var id=seq+1
 var row={"id":id,"actor":actor,"name":name_,"room":room,"text":value,"sticker":sticker,"at":Time.get_unix_time_from_system(),
  "to":mentions,"reply_to":reply_to,"source":source,"transport":transport,"sender_kind":sender_kind(actor)}
 if (live_bot or actor=="owner") and not invite.is_empty():row.invite=invite ## 2026-11-19 owner invitations carry an invite id too
 if not routing.is_empty():row.route=routing
 var next=messages+ [row]
 if next.size()>1400:next=next.slice(next.size()-1400)
 if not persist(next,id,hidden_stickers,custom_stickers):return {"ok":false,"error":"消息保存失败"}
 seq=id
 messages=next
 var host=get_tree().get_meta("qingxi_world_host",false)
 if host:host.chat_posted(row)
 return {"ok":true,"message":row}

func submit(value:String,sticker:String):
 var host=get_tree().get_meta("qingxi_world_host",false)
 var name_:String=host.owner_display_name() if host else "你"
 var res=send("owner",name_,GROUP,value,sticker)
 notify_error(str(res.get("error","")))
 if res.ok:
  input.clear()
  backdrop.hide()
 else:input.grab_focus()
