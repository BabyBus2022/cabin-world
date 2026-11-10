extends RefCounted
## Finished matches only. An interrupted game has no result. Match ids survive
## restarts and make importing the VADS mirror or retrying an append idempotent.
static func valid_record(row: Variant) -> bool:
	return row is Dictionary and row.get("matchId") is String and not row.matchId.is_empty() and (row.get("at") is float or row.get("at") is int) and row.get("players") is Array and not row.players.is_empty() and row.players.all(func(p): return p is Dictionary and p.get("result") in ["won","lost","draw"])

static func read_rows(path: String) -> Variant:
	if FileAccess.file_exists(path):
		var data = JSON.parse_string(FileAccess.get_file_as_string(path))
		if data is Dictionary and data.get("version")==1 and data.get("history") is Array and data.history.all(valid_record):
			return data.history
	return null

static func merge_history(rows: Array) -> Variant:
	var path := ProjectSettings.globalize_path(Economy.save_path.get_base_dir().path_join("arcade-records.json"))
	var saved = read_rows(path)
	var good_primary := saved is Array
	if saved==null: saved=read_rows(path+".bak")
	if saved==null:
		if FileAccess.file_exists(path) or FileAccess.file_exists(path+".bak"): return null
		saved=[]
	var known := {}
	var history: Array = saved.duplicate()
	for row in history: known[row.matchId]=true
	for row in rows:
		if not valid_record(row) or known.has(row.matchId): continue
		known[row.matchId]=true
		var insert_at := history.size()
		while insert_at and float(history[insert_at-1].at)>float(row.at): insert_at-=1
		history.insert(insert_at,row)
	history=history.slice(maxi(0,history.size()-40))
	if history==saved and good_primary: return history
	var f := FileAccess.open(path+".tmp",FileAccess.WRITE)
	if f==null: return null
	f.store_string(JSON.stringify({"version":1,"history":history},"",false,true))
	f.flush()
	var ok := f.get_error()==OK
	f.close()
	if not ok or (good_primary and DirAccess.copy_absolute(path,path+".bak")!=OK): return null
	if DirAccess.rename_absolute(path+".tmp",path)!=OK: return null
	return history
