extends Node
## Optional localhost connection activated only by the process that starts the game.

signal conversation_frame(frame: Dictionary)
signal availability_changed(available: bool)

var actor_key := ""
var available := false
var _address := ""
var _portrait_file := ""
var _portrait_dir := ""
var _peer: WebSocketPeer
var _resident: Character
var _body: ImageTexture
var _anchor := Vector2.ZERO
var _body_height := 0.0
var _rendered := false
var _ready_sent := false
var _report_position := false
var _placed_window := false
var _window_mode := Window.MODE_WINDOWED
var _shown := false
var _retry_at := 0
var _portraits := {}
var _checked_portraits := {}

func _ready() -> void:
	var local_host := RegEx.create_from_string("^ws://127[.]0[.]0[.]1:[1-9][0-9]{0,4}/[a-f0-9]{48}$")
	var safe_key := RegEx.create_from_string("^[A-Za-z0-9][A-Za-z0-9_-]{0,47}$")
	_address = OS.get_environment("CABIN_EXTERNAL_HOST_SOCKET")
	actor_key = OS.get_environment("CABIN_EXTERNAL_HOST_ACTOR")
	if local_host.search(_address) == null or safe_key.search(actor_key) == null:
		actor_key = ""
		set_process(false)
		return
	_portrait_file = OS.get_environment("CABIN_EXTERNAL_HOST_PORTRAIT")
	_portrait_dir = OS.get_environment("CABIN_EXTERNAL_HOST_PORTRAITS")
	DisplayServer.window_set_flag(DisplayServer.WINDOW_FLAG_NO_FOCUS, true)
	_connect()

func _connect() -> void:
	_peer = WebSocketPeer.new()
	_peer.inbound_buffer_size = 1024 * 1024
	_peer.connect_to_url(_address)
	_retry_at = Time.get_ticks_msec() + 450

func _process(_delta: float) -> void:
	var world = get_tree().current_scene
	if not is_instance_valid(world) or not world.has_method("follow_external_resident"):
		return
	if not _placed_window:
		_placed_window = true
		var window := get_window()
		_window_mode = window.mode
		if window.mode != Window.MODE_WINDOWED:
			window.mode = Window.MODE_WINDOWED
		window.position = Vector2i(-16000, -16000)
	_peer.poll()
	match _peer.get_ready_state():
		WebSocketPeer.STATE_CLOSED:
			_detach()
			if Time.get_ticks_msec() >= _retry_at:
				_connect()
			return
		WebSocketPeer.STATE_OPEN:
			_read_packets()
		_: return
	var current: Character = world.follow_external_resident(actor_key)
	if current != _resident:
		if is_instance_valid(_resident):
			_resident.clear_external_appearance()
		_resident = current
		_ready_sent = false
		_rendered = false
	if not is_instance_valid(_resident) or not _resident.placed or _body == null:
		return
	_apply_portraits(world)
	_resident.show_external_body(_body, _anchor, _body_height)
	if _report_position and VadsLink.connected:
		_resident.report_position()
		_report_position = _peer.send_text("position-reported") != OK
	if _rendered and not _ready_sent:
		_ready_sent = _peer.send_text("ready") == OK
		if _ready_sent and _shown:
			_set_available(true)
	elif not _rendered and _resident.external_body_visible() and not RenderingServer.frame_post_draw.is_connected(_frame_completed):
		RenderingServer.frame_post_draw.connect(_frame_completed, CONNECT_ONE_SHOT)

func _frame_completed() -> void:
	_rendered = true

func _read_packets() -> void:
	var frame := PackedByteArray()
	while _peer.get_available_packet_count() > 0:
		var packet := _peer.get_packet()
		if not _peer.was_string_packet():
			frame = packet
			continue
		if packet.size() > 512 * 1024:
			continue
		var command := packet.get_string_from_utf8()
		match command:
			"report-position": _report_position = true
			"reveal": _reveal()
			_:
				if available and command.begins_with("{"):
					var value: Variant = JSON.parse_string(command)
					if value is Dictionary and value.get("type") in ["chat-state", "chat-result"]:
						conversation_frame.emit(value)
	if not frame.is_empty():
		_upload_frame(frame)

func _upload_frame(bytes: PackedByteArray) -> void:
	if bytes.size() < 24 or bytes.size() > 512 * 1024 or bytes.slice(0, 8).hex_encode() != "89504e470d0a1a0a":
		return
	var w := (bytes[16] << 24) | (bytes[17] << 16) | (bytes[18] << 8) | bytes[19]
	var h := (bytes[20] << 24) | (bytes[21] << 16) | (bytes[22] << 8) | bytes[23]
	if w < 1 or h < 1 or w > 1024 or h > 1024:
		return
	var image := Image.new()
	if image.load_png_from_buffer(bytes) != OK:
		return
	image.convert(Image.FORMAT_RGBA8)
	if _body != null:
		if _body.get_size() == Vector2(image.get_size()):
			_body.update(image)
		return
	var body_rect := image.get_used_rect()
	if body_rect.size.y < 30 or body_rect == Rect2i(Vector2i.ZERO, image.get_size()):
		return
	_anchor = Vector2(body_rect.get_center().x, body_rect.end.y)
	_body_height = body_rect.size.y
	_body = ImageTexture.create_from_image(image)
	var portrait := Image.load_from_file(_portrait_file) if FileAccess.file_exists(_portrait_file) else null
	if portrait == null or portrait.is_empty():
		body_rect.size.y = maxi(1, body_rect.size.y * 3 / 5)
		portrait = image.get_region(body_rect)
	var ratio := 185.0 / maxi(portrait.get_width(), portrait.get_height())
	portrait.resize(maxi(1, roundi(portrait.get_width() * ratio)), maxi(1, roundi(portrait.get_height() * ratio)), Image.INTERPOLATE_LANCZOS)
	_portraits[actor_key] = ImageTexture.create_from_image(portrait)
	if _portrait_dir.is_absolute_path():
		var square := Image.create_empty(185, 185, false, Image.FORMAT_RGBA8)
		portrait.convert(Image.FORMAT_RGBA8)
		var offset := (Vector2i(185, 185) - portrait.get_size()) / 2
		square.blit_rect(portrait, Rect2i(Vector2i.ZERO, portrait.get_size()), offset)
		square.save_png(_portrait_dir.path_join(actor_key + ".png"))

func _apply_portraits(world: Control) -> void:
	for child in get_tree().get_nodes_in_group("world_residents"):
		var resident := child as Character
		if resident == null or resident.external_portrait != null:
			continue
		if not _portraits.has(resident.key) and not _checked_portraits.has(resident.key) and _portrait_dir.is_absolute_path() and resident.key.is_valid_filename() and resident.key not in [".", ".."]:
			_checked_portraits[resident.key] = true
			var file := _portrait_dir.path_join(resident.key + ".png")
			if FileAccess.file_exists(file):
				var picture := Image.load_from_file(file)
				if picture != null and picture.get_size() == Vector2i(185, 185):
					_portraits[resident.key] = ImageTexture.create_from_image(picture)
		var portrait: Texture2D = _portraits.get(resident.key)
		if portrait != null:
			resident.external_portrait = portrait
			world.refresh_external_portraits()

func _reveal() -> void:
	if not _ready_sent or not _placed_window:
		return
	if not _shown:
		_shown = true
		var window := get_window()
		var screen := DisplayServer.screen_get_usable_rect(DisplayServer.SCREEN_PRIMARY)
		window.position = screen.position + (screen.size - window.size) / 2
		window.mode = _window_mode
		DisplayServer.window_set_flag(DisplayServer.WINDOW_FLAG_NO_FOCUS, false)
		_set_available(true)
	_peer.send_text("presented")

func _detach() -> void:
	if is_instance_valid(_resident):
		_resident.clear_external_appearance()
		_resident = null
		var world = get_tree().current_scene
		world.refresh_external_portraits()
	_portraits.erase(actor_key)
	_body = null
	if RenderingServer.frame_post_draw.is_connected(_frame_completed):
		RenderingServer.frame_post_draw.disconnect(_frame_completed)
	_ready_sent = false
	_rendered = false
	_set_available(false)

func _set_available(value: bool) -> void:
	if available != value:
		available = value
		availability_changed.emit(value)

func send_conversation(frame: Dictionary) -> bool:
	return available and _peer.get_ready_state() == WebSocketPeer.STATE_OPEN and _peer.send_text(JSON.stringify(frame)) == OK
