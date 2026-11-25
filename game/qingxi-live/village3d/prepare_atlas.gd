extends SceneTree
func _initialize():
	var img=Image.load_from_file("res://qingxi-live/assets/parametric-village/clean-atlas-original.png")
	img.resize(1024,1024,Image.INTERPOLATE_NEAREST)
	img.save_png(ProjectSettings.globalize_path("res://qingxi-live/assets/parametric-village/clean-atlas.png"))
	quit()
