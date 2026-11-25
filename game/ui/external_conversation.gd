class_name ExternalConversation
extends VBoxContainer

const MAX_TEXT_UNITS := 500
var _log := RichTextLabel.new()
var _entry := LineEdit.new()
var _send := Button.new()
var _status := Label.new()
var _request := ""
var _message := ""
var _pending_until := 0
var _refresh_at := 0
var _cursor := ""
var _host := ""

func _ready() -> void:
	_host = OS.get_environment("CABIN_EXTERNAL_HOST_NAME").strip_edges().left(32)
	if _host.is_empty():
		_host = "宿主"
	_log.fit_content = false
	_log.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_log.custom_minimum_size.y = 64
	_log.add_theme_color_override("default_color", Hud.INK)
	_log.selection_enabled = true
	add_child(_log)
	_status.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_status.add_theme_color_override("font_color", Hud.INK2)
	add_child(_status)
	var composer := HBoxContainer.new()
	add_child(composer)
	_entry.placeholder_text = "给 %s 发消息…" % _host
	_entry.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	composer.add_child(_entry)
	_send.text = "发送"
	composer.add_child(_send)
	_entry.text_changed.connect(func(_value: String): _update_controls())
	_entry.text_submitted.connect(func(_value: String): _submit())
	_send.pressed.connect(_submit)
	ExternalHost.conversation_frame.connect(_receive)
	ExternalHost.availability_changed.connect(_availability)
	_availability(ExternalHost.available)

func _process(_dt: float) -> void:
	var now := Time.get_ticks_msec()
	if _pending_until > 0 and now >= _pending_until:
		_pending_until = 0
		_status.text = "发送未确认，可以重试。"
		_update_controls()
	if is_visible_in_tree() and ExternalHost.available and now >= _refresh_at:
		_refresh_at = now + 1000
		ExternalHost.send_conversation({"type": "chat-read"})

func _availability(online: bool) -> void:
	_status.text = "等待会话连接…" if not online else ""
	if not online:
		_pending_until = 0
	_refresh_at = 0
	_update_controls()

func _update_controls() -> void:
	_entry.editable = ExternalHost.available and _pending_until == 0
	var text := _entry.text.strip_edges()
	var too_long := text.to_utf16_buffer().size() > MAX_TEXT_UNITS * 2
	_send.disabled = not _entry.editable or text.is_empty() or too_long
	_entry.tooltip_text = "最多 %d 个字符" % MAX_TEXT_UNITS if too_long else ""

func _submit() -> void:
	if _send.disabled:
		return
	var text := _entry.text.strip_edges()
	if _request.is_empty() or text != _message:
		_request = Crypto.new().generate_random_bytes(16).hex_encode()
		_message = text
	if ExternalHost.send_conversation({"type": "chat-send", "id": _request, "text": text}):
		_pending_until = Time.get_ticks_msec() + 10000
		_status.text = "正在发送…"
		_update_controls()
	else:
		_status.text = "连接暂不可用，输入已保留。"

func _receive(frame: Dictionary) -> void:
	match frame.get("type"):
		"chat-result":
			if frame.get("id") != _request or _request.is_empty():
				return
			_pending_until = 0
			if frame.get("ok") == true:
				_entry.clear()
				_request = ""
				_message = ""
				_status.text = ""
				_refresh_at = 0
			else:
				_status.text = str(frame.get("error", "发送失败，可以重试。")).left(280)
			_update_controls()
		"chat-state":
			var rows: Variant = frame.get("messages")
			if not rows is Array:
				return
			var revision := JSON.stringify(rows)
			if revision == _cursor:
				return
			_cursor = revision
			_update_log(rows)

func _update_log(rows: Array) -> void:
	var bar := _log.get_v_scroll_bar()
	var scroll := bar.value
	var at_end := scroll + bar.page >= bar.max_value - 24
	_log.clear()
	for item in rows.slice(-120):
		if not item is Dictionary or not item.get("text") is String:
			continue
		var label := "你" if item.get("side") == "user" else _host
		_log.push_bold()
		_log.add_text(label + "  ")
		_log.pop()
		_log.add_text(item.text.left(4000))
		_log.newline()
		_log.newline()
	await get_tree().process_frame
	if is_instance_valid(bar):
		bar.value = bar.max_value if at_end else scroll
