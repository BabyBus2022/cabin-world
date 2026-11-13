extends RefCounted
## Game-owned display names and physical desk journals, keyed by stable actor ID.
const Store=preload("res://core/safe_store.gd")
static func file()->String:return Economy.save_path.get_base_dir().path_join("resident-personal.json")
static func valid_name(value:Variant)->bool:
	if not value is String or value.strip_edges().is_empty() or value.length()>32:return false
	for c in value:
		if c.unicode_at(0)<32 or c.unicode_at(0)==127:return false
	return true
static func valid(data:Dictionary)->bool:
	if not data.get("people",{}) is Dictionary:return false
	for row in data.get("people",{}).values():
		if not row is Dictionary:return false
		if row.has("name") and not valid_name(row.name):return false
		if not row.get("journal",[]) is Array:return false
		for e in row.get("journal",[]):
			if not e is Dictionary or not e.get("id") is String or not e.get("text") is String:return false
	return true
static func label(actor:String,fallback:String)->String:
	var stored:Dictionary=Store.read_document(file(),valid)
	return str(stored.data.get("people",{}).get(actor,{}).get("name",fallback)) if stored.ok else fallback
static func accept(frame:Dictionary)->Dictionary:
	var actor:String=str(frame.get("actor",""))
	if Residents.person(actor).is_empty():return {"ok":false,"error":"没有这位住户"}
	var stored:Dictionary=Store.read_document(file(),valid)
	if not stored.ok or not stored.writable:return {"ok":false,"error":"个人设置存档异常，未覆盖原文件"}
	var doc:Dictionary=stored.data.duplicate(true)
	doc.version=1
	if not doc.has("people"):doc.people={}
	var row:Dictionary=doc.people.get(actor,{"journal":[]}).duplicate(true)
	var action:String=str(frame.get("action","read"))
	if action=="rename":
		if not valid_name(frame.get("name")):return {"ok":false,"error":"名字须为1–32字，不能含换行或控制字符"}
		row.name=frame.name.strip_edges()
	elif action=="write":
		var content=frame.get("text")
		if not content is String or content.strip_edges().is_empty() or content.length()>2000:return {"ok":false,"error":"请提供1–2000字的日记正文"}
		var id:String=str(frame.get("id",""))
		if id.is_empty():return {"ok":false,"error":"缺少操作编号"}
		var entries:Array=row.get("journal",[])
		for e in entries:
			if e.id==id:return {"ok":e.text==content.strip_edges(),"entry":e,"error":"" if e.text==content.strip_edges() else "重复编号的正文不同"}
		row.journal=(entries+[{"id":id,"text":content.strip_edges(),"at":SharedFeed.now_ms()}]).slice(-500)
	elif action=="read":return {"ok":true,"entries":row.get("journal",[]).slice(-20)}
	else:return {"ok":false,"error":"未知个人设置操作"}
	doc.people[actor]=row
	if not Store.write_document(file(),doc,valid):return {"ok":false,"error":"保存失败，未确认完成"}
	if action=="rename":
		Residents.person(actor).name=row.name
		load("res://core/resident_registry.gd").refresh_name(actor)
		var tree=Engine.get_main_loop()
		if tree is SceneTree:
			for c in tree.get_nodes_in_group("world_residents"):
				if c.key==actor:c.display_name=row.name
		return {"ok":true,"name":row.name}
	return {"ok":true,"entry":row.journal[-1]}
