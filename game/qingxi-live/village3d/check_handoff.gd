extends SceneTree
var errors=[]
func _initialize():run.call_deferred()
func require_(okay:bool,text_:String):
	if not okay:errors.append(text_);push_error(text_)
func wait_scene(path:String):
	for i in 600:
		await process_frame
		if is_instance_valid(current_scene) and current_scene.scene_file_path==path:
			await physics_frame;await physics_frame;return current_scene
	errors.append("Scene timeout: "+path);return null
func run():
	change_scene_to_file("res://qingxi-live/village3d/main.tscn")
	var village=await wait_scene("res://qingxi-live/village3d/main.tscn")
	if village==null:quit(1);return
	village.sim.data.bag.veg=7;village.sim.data.coins=437
	village.sim.crop_action(0);village.sim.crop_action(0);village.sim.advance(250)
	for region in ["field","ranch","pond"]:
		village.travel_region(region)
		var farm=await wait_scene("res://qingxi-live/main.tscn")
		if farm==null:quit(1);return
		require_(farm.map_id==region,"Wrong region")
		require_(farm.sim.data.coins==437 and farm.sim.data.bag.veg==7,"Inventory lost entering "+region)
		require_(farm.sim.data.crops[0].progress>=250,"Crop progress lost")
		if region=="pond":
			farm.action_target={"kind":"shop","extra":"fish"};farm.selected_cell=-1;farm.interact()
			require_(farm.open_menu=="shop","Fish shop cannot open")
			var found=false
			for control in farm.overlay_body.get_children():
				if control is Button and control.text.begins_with("鱼苗"):found=true
			require_(found,"Fish shop missing fish fry")
		farm.travel("village")
		village=await wait_scene("res://qingxi-live/village3d/main.tscn")
		if village==null:quit(1);return
		require_(village.sim.data.bag.veg==7 and village.sim.data.coins==437,"Inventory lost returning from "+region)
		require_(village.player.position.distance_to(village.GATES[region])<3,"Wrong return gate")
	print("REGION_HANDOFF ","PASS" if errors.is_empty() else "FAIL"," regions=3 inventory=true crops=true fish_shop=true errors=",JSON.stringify(errors));quit(0 if errors.is_empty() else 1)
