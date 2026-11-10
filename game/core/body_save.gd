extends RefCounted
## Game-owned durable body fields. The first body.open imports an existing
## resident, then only explicit property changes may replace saved values.
const FIELDS := ["bed", "phone", "headphones", "computer", "rest", "outfit"]
static var people: Dictionary = {}
static var loaded := false
static var writable := false

static func file() -> String:
	return ProjectSettings.globalize_path(Economy.save_path.get_base_dir().path_join("bodies.json"))

static func point(value: Variant) -> bool:
	return value is Dictionary and number(value.get("x")) and number(value.get("y"))

static func number(value: Variant) -> bool:
	return (value is float or value is int) and is_finite(float(value))

static func valid_fields(row: Variant) -> bool:
	if not row is Dictionary:
		return false
	if row.has("outfit") and not row.outfit in ["","yukata"]:
		return false
	if row.has("phone") and not row.phone in ["dock", "hand", "pocket"]:
		return false
	if row.has("headphones") and not row.headphones in ["dock", "worn"]:
		return false
	if row.has("rest"):
		var r = row.rest
		if not r is Dictionary or not r.get("sleeping") is bool or (r.get("bedUntil") != null and not number(r.bedUntil)):
			return false
	if row.has("bed"):
		var b = row.bed
		if not b is Dictionary or b.get("version") != 1 or not Body.LABELS.has(b.get("final")) or not number(b.get("start")) or not number(b.get("revision")) or not b.get("source") is String or not b.get("steps") is Array:
			return false
		for step in b.steps:
			if not step is Array or step.size() != 2 or not Body.LABELS.has(step[0]) or not number(step[1]) or step[1] <= 0:
				return false
	if row.has("computer"):
		var c = row.computer
		if not c is Dictionary or not c.get("phase") in ["standing", "approaching", "sitting", "seated", "leaving"] or not c.get("screen") in ["off", "desktop", "error"] or not number(c.get("x")) or not number(c.get("y")):
			return false
		var m = c.get("motion")
		if m != null and (not m is Dictionary or not point(m.get("from")) or not point(m.get("to")) or not number(m.get("start")) or not number(m.get("duration")) or m.duration <= 0):
			return false
	return true

static func read_rows(path: String) -> Variant:
	if FileAccess.file_exists(path):
		var d = JSON.parse_string(FileAccess.get_file_as_string(path))
		if d is Dictionary and d.get("version") == 1 and d.get("people") is Dictionary:
			for row in d.people.values():
				if not valid_fields(row):
					return null
			return d.people
	return null

static func load_rows() -> void:
	if loaded:
		return
	loaded = true
	for path in [file(), file() + ".bak"]:
		var rows = read_rows(path)
		if rows is Dictionary:
			people = rows
			writable = true
			return
	# An unreadable existing pair must never be overwritten by an empty seed.
	writable = not FileAccess.file_exists(file()) and not FileAccess.file_exists(file() + ".bak")

static func commit(next: Dictionary) -> bool:
	var path := file()
	var f := FileAccess.open(path + ".tmp", FileAccess.WRITE)
	if f == null:
		return false
	f.store_string(JSON.stringify({"version": 1, "people": next}, "", false, true))
	f.flush()
	var ok := f.get_error() == OK
	f.close()
	if not ok:
		return false
	if read_rows(path) != null and DirAccess.copy_absolute(path, path + ".bak") != OK:
		return false
	if DirAccess.rename_absolute(path + ".tmp", path) != OK:
		return false
	people = next
	return true

static func accept(frame: Dictionary) -> Dictionary:
	load_rows()
	var actor := str(frame.get("actor", ""))
	if not writable or Residents.person(actor).is_empty():
		return {"ok": false}
	var opening: bool = frame.type == "body.open"
	if not valid_fields(frame.get("patch")) or (opening and not valid_fields(frame.get("seed"))):
		return {"ok": false}
	if not opening and not people.has(actor):
		return {"ok": false}
	var row: Dictionary = people.get(actor, {}).duplicate(true)
	for key in FIELDS:
		if opening and not row.has(key) and frame.get("seed", {}).has(key):
			row[key] = frame.seed[key]
		if frame.get("patch", {}).has(key):
			row[key] = frame.patch[key]
	if row != people.get(actor):
		if opening and people.has(actor) and not people[actor].has("outfit") and row.has("outfit"):
			var snapshot := file()+".bak-before-2.7.28"
			var source := file() if read_rows(file())!=null else file()+".bak"
			if not FileAccess.file_exists(snapshot) and DirAccess.copy_absolute(source,snapshot)!=OK:
				return {"ok":false}
		var next := people.duplicate()
		next[actor] = row
		if not commit(next):
			return {"ok": false}
	return {"ok": true, "state": row}
