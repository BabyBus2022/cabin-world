@tool
extends EditorPlugin

class PortableAssets extends EditorExportPlugin:
	func _get_name() -> String:
		return "CabinWorldPortableAssets"

	func _export_file(path: String, _type: String, _features: PackedStringArray) -> void:
		if path.get_extension().to_lower() in ["png", "jpg", "wav", "ogg", "ico"]:
			# Runtime appearance packs copy original files, and Qingxi reads pixels from PNGs.
			add_file(path, FileAccess.get_file_as_bytes(path), false)

var portable_assets := PortableAssets.new()

func _enter_tree() -> void:
	add_export_plugin(portable_assets)

func _exit_tree() -> void:
	remove_export_plugin(portable_assets)

