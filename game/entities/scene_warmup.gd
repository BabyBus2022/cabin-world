extends RefCounted
## Prime the actual room shaders/textures in an off-screen viewport. Preview
## rooms do not mount residents, NPCs, interactive mechanisms or save writers.
static func run(owner:Node)->void:
	if DisplayServer.get_name()=="headless":return
	var id:="qianxia-park"
	if not WorldData.scenes.has(id):return
	var view:=SubViewport.new()
	view.size=Vector2i(WorldData.scenes[id].width,WorldData.scenes[id].height)
	view.transparent_bg=true;view.render_target_update_mode=SubViewport.UPDATE_ALWAYS
	owner.add_child(view)
	var room=load("res://entities/room.gd").new()
	room.preview_only=true;view.add_child(room);room.setup(id);room.build();room.visible=true
	# The live park also draws river masks, nature and moving furniture. These
	# visual-only nodes must be primed too; baked preview art does not use them.
	AmbientArt.mount(room,id)
	WorldMechanism.mount(room,id)
	await owner.get_tree().process_frame
	await RenderingServer.frame_post_draw
	await owner.get_tree().process_frame
	await RenderingServer.frame_post_draw
	view.queue_free()
