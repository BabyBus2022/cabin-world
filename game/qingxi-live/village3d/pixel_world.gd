extends Node
var host
var mask_view:SubViewport
var mask_camera:Camera3D
var filter:ColorRect
var material_:ShaderMaterial
var active=true
var target_width=512.0
func setup(h):
	host=h
	h.portrait.layers=2
	for resident in h.residents:resident.sprite.layers=2
	mask_view=SubViewport.new();mask_view.name="CharacterDetailMask";mask_view.world_3d=h.get_world_3d();mask_view.transparent_bg=true;mask_view.render_target_update_mode=SubViewport.UPDATE_ALWAYS;mask_view.msaa_3d=Viewport.MSAA_DISABLED;add_child(mask_view)
	mask_camera=Camera3D.new();mask_camera.projection=Camera3D.PROJECTION_ORTHOGONAL;mask_camera.cull_mask=2;mask_camera.far=150;mask_view.add_child(mask_camera);mask_camera.current=true
	# Post-process the world before the UI (which uses CanvasLayer 1).
	var layer=CanvasLayer.new();layer.layer=0;add_child(layer)
	filter=ColorRect.new();filter.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT);filter.mouse_filter=Control.MOUSE_FILTER_IGNORE;layer.add_child(filter)
	material_=ShaderMaterial.new();material_.shader=preload("res://qingxi-live/village3d/pixel_world.gdshader");material_.set_shader_parameter("actor_mask",mask_view.get_texture());filter.material=material_
	RenderingServer.frame_pre_draw.connect(sync)
	sync()
func sync():
	if not is_instance_valid(host.camera):return
	var size_=Vector2i(host.get_viewport().get_visible_rect().size)
	if mask_view.size!=size_:mask_view.size=size_
	mask_camera.global_transform=host.camera.global_transform;mask_camera.size=host.camera.size
	# Canvas stretch already enlarges the game's 768-wide view; use that baseline.
	material_.set_shader_parameter("pixel_step",maxf(1,roundf(mask_view.size.x/target_width)))
	filter.visible=active
func _exit_tree():
	if RenderingServer.frame_pre_draw.is_connected(sync):RenderingServer.frame_pre_draw.disconnect(sync)
