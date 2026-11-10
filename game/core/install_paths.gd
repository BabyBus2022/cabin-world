class_name InstallPaths
extends RefCounted
## Portable discovery. Explicit --data wins, then environment, then the INI
## beside the executable. Relative paths are relative to that executable.
## The host normally supplies --data; no developer-machine fallback exists.

static func resolve_data(args: PackedStringArray, environment: String, executable_dir: String, ini_text: String) -> String:
	var index := args.find("--data")
	var value := ""
	if index >= 0 and index + 1 < args.size():
		value = args[index + 1].strip_edges()
	if value.is_empty():
		value = environment.strip_edges()
	if value.is_empty():
		for raw in ini_text.replace("\r", "").split("\n"):
			var line := raw.strip_edges()
			if line.begins_with("data="):
				value = line.substr(5).strip_edges()
				break
	if value.is_empty():
		value = "data"
	return value.simplify_path() if value.is_absolute_path() else executable_dir.path_join(value).simplify_path()

## An explicit portable save location is separate from host discovery data.
## Empty means keep the existing editor/VADS save behavior.
static func resolve_save(args: PackedStringArray, environment: String, executable_dir: String, ini_text: String) -> String:
	var index := args.find("--save")
	var value := args[index + 1].strip_edges() if index >= 0 and index + 1 < args.size() else ""
	if value.is_empty(): value = environment.strip_edges()
	if value.is_empty():
		for raw in ini_text.replace("\r", "").split("\n"):
			var line := raw.strip_edges()
			if line.begins_with("save="):
				value = line.substr(5).strip_edges()
				break
	if value.is_empty(): return ""
	return value.simplify_path() if value.is_absolute_path() else executable_dir.path_join(value).simplify_path()
