extends RefCounted
## Cosmetic preference only. Role IDs, game opponents and receipts stay stable.
const IDS := ["mochi", "naiwa"]
const LABELS := ["团团 · 米白小团子", "Naiwa · 经典皮肤"]
static var selected := ""
static var catalog: Dictionary = {}
static func data() -> Dictionary:
	if catalog.is_empty(): catalog=JSON.parse_string(FileAccess.get_file_as_string("res://assets/npcs.json"))
	return catalog
static func path() -> String:
	return Economy.save_path.get_base_dir().path_join("npc-appearance.cfg")
static func current() -> String:
	if selected=="":
		var config:=ConfigFile.new()
		var value="mochi"
		if config.load(path())==OK:value=config.get_value("npc","skin","mochi")
		selected=value if value in IDS else "mochi"
	return selected
static func label() -> String:
	return "Naiwa" if current()=="naiwa" else "团团"
static func skin() -> Dictionary:
	return data().skins[current()]
static func choose(value:String, tree:SceneTree) -> Error:
	if not value in IDS:return ERR_INVALID_PARAMETER
	var config:=ConfigFile.new()
	config.set_value("npc","skin",value)
	var error:=config.save(path()+".tmp")
	if error!=OK:return error
	error=DirAccess.rename_absolute(path()+".tmp",path())
	if error!=OK:return error
	selected=value
	# Existing characters keep queues, transactions, placement and pose clocks.
	tree.call_group("world_npcs","refresh_appearance")
	return OK
