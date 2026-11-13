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
	var stored:Dictionary=load("res://core/safe_store.gd").read_document(path,valid_save)
	if not stored.ok:return null
	var saved:Array=stored.data.get("history",[])
	var good_primary:bool=not stored.recovered and FileAccess.file_exists(path)
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
	return history if load("res://core/safe_store.gd").write_document(path,{"version":1,"history":history},valid_save) else null

static func valid_save(data:Dictionary)->bool:
	return data.get("history") is Array and data.history.all(valid_record)
