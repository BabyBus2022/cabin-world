extends "res://qingxi-live/village3d/check_handoff.gd"
func run():
	change_scene_to_file("res://qingxi-live/village3d/main.tscn")
	var village=await wait_scene("res://qingxi-live/village3d/main.tscn")
	village.travel_region("field")
	var farm=await wait_scene("res://qingxi-live/main.tscn")
	for region in ["field","ranch","pond"]:
		farm.build_map(region)
		for pos in [Vector2(25,450),Vector2(640,450),Vector2(1255,450),Vector2(640,25),Vector2(640,875)]:
			farm.camera.zoom=Vector2.ONE*0.5
			farm.player.position=pos;farm.update_camera(true)
			for i in 4:await process_frame
			var inverse=root.get_canvas_transform().affine_inverse()
			var size=root.get_visible_rect().size
			var rect=Rect2(inverse*Vector2.ZERO,inverse*size-inverse*Vector2.ZERO)
			require_(farm.world_bounds().grow(1).encloses(rect),"Viewport exposes void: %s at %s viewport=%s zoom=%s rect=%s"%[region,pos,size,farm.camera.zoom,rect])
		if DisplayServer.get_name()!="headless":
			farm.player.position=Vector2(25,450);farm.update_camera(true)
			for i in 4:await process_frame
			await RenderingServer.frame_post_draw
			root.get_texture().get_image().save_png(ProjectSettings.globalize_path("res://qingxi-live/village3d/bounds-"+region+".png"))
	print("VIEWPORT_CHECK ","PASS" if errors.is_empty() else "FAIL"," ",JSON.stringify(errors));quit(0 if errors.is_empty() else 1)
