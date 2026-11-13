extends RefCounted
## Versioned JSON with a validated previous generation. Corrupt input is never
## promoted to the backup; an unreadable pair is never silently reset.
static var _noted:Dictionary={}

static func raw(path:String)->Variant:
	if not FileAccess.file_exists(path):return null
	var parser:=JSON.new()
	if parser.parse(FileAccess.get_file_as_string(path))!=OK:return null
	return parser.data

static func supported(data:Variant,legacy:bool)->bool:
	return data is Dictionary and (data.get("version")==1 or (legacy and not data.has("version")))

static func read_document(path:String,validate:Callable,legacy:bool=false)->Dictionary:
	var primary=raw(path)
	if primary is Dictionary and primary.has("version") and primary.version!=1:
		note(path,"unsupported-version")
		return {"ok":false,"writable":false,"data":{},"recovered":false}
	if supported(primary,legacy) and bool(validate.call(primary)):
		return {"ok":true,"writable":true,"data":primary,"recovered":false}
	var backup=raw(path+".bak")
	if supported(backup,legacy) and bool(validate.call(backup)):
		note(path,"backup-recovered")
		return {"ok":true,"writable":true,"data":backup,"recovered":true}
	var empty:bool=not FileAccess.file_exists(path) and not FileAccess.file_exists(path+".bak")
	if not empty:note(path,"both-copies-invalid")
	return {"ok":empty,"writable":empty,"data":{},"recovered":false}

static func write_document(path:String,data:Dictionary,validate:Callable,legacy:bool=false)->bool:
	if data.get("version")!=1 or not bool(validate.call(data)):return false
	var previous:=read_document(path,validate,legacy)
	if not previous.writable:return false
	var absolute:=ProjectSettings.globalize_path(path)
	if DirAccess.make_dir_recursive_absolute(absolute.get_base_dir())!=OK:return false
	var tmp:=absolute+".tmp"
	var f:=FileAccess.open(tmp,FileAccess.WRITE)
	if f==null:return false
	f.store_string(JSON.stringify(data,"",false,true));f.flush()
	var ok:bool=f.get_error()==OK;f.close()
	var checked=raw(tmp)
	if not ok or not supported(checked,false) or not bool(validate.call(checked)):
		DirAccess.remove_absolute(tmp);return false
	if FileAccess.file_exists(absolute):
		if previous.recovered:
			var corrupt:=absolute+".corrupt-"+str(Time.get_ticks_usec())
			if DirAccess.copy_absolute(absolute,corrupt)!=OK:DirAccess.remove_absolute(tmp);return false
		elif DirAccess.copy_absolute(absolute,absolute+".bak")!=OK:
			DirAccess.remove_absolute(tmp);return false
	if DirAccess.rename_absolute(tmp,absolute)!=OK:DirAccess.remove_absolute(tmp);return false
	return true

static func note(path:String,reason:String)->void:
	var key:=path+":"+reason
	if _noted.has(key):return
	_noted[key]=true
	print("SAVE_RECOVERY ",path.get_file()," ",reason)
	var journal:=path.get_base_dir().path_join("save-recovery.jsonl")
	var f:=FileAccess.open(journal,FileAccess.READ_WRITE if FileAccess.file_exists(journal) else FileAccess.WRITE)
	if f!=null:
		f.seek_end();f.store_line(JSON.stringify({"at":Time.get_unix_time_from_system()*1000,"file":path.get_file(),"reason":reason}));f.close()
