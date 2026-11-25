extends RefCounted

static var known={}
static var loaded_path=""

static func restore(pet:Dictionary):
	if pet.has("owner_id"):return
	var key=str(pet.get("id",""))+"@"+str(roundi(float(pet.get("born_at",0))*1000))
	var path=SharedFeed.data_dir.path_join("world/qingxi-saves/pet-adoptions.json")
	if path!=loaded_path:
		known={}
		if FileAccess.file_exists(path):
			var d=JSON.parse_string(FileAccess.get_file_as_string(path))
			if d is Dictionary:known=d
		loaded_path=path
	if known.has(key):pet.owner_id=known[key]

static func caption(pet:Dictionary)->String:
	var owner=str(pet.get("owner_id",""))
	if owner=="owner":return "玩家"
	if owner=="":return "待确认"
	return str(Residents.person(owner).get("name",owner))

static func denied(pet:Dictionary,who:String)->String:
	if who!="" and str(pet.get("owner_id",""))==who:return ""
	return "这只宠物的领养人还没有确认。" if not pet.has("owner_id") else "只有%s可以给它改名或叫它跟随。"%caption(pet)

static func follow(pet:Dictionary,who:String,on:bool)->String:
	var why=denied(pet,who)
	if why!="":return why
	pet.follow=on
	pet.away_until=0.0
	pet.last_away=Time.get_unix_time_from_system()
	if not on:pet.companion_map="ranch"
	return "开始跟随"+caption(pet) if on else "已留在自家农场"
