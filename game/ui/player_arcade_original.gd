extends PanelContainer





















const Board = preload("res://core/arcade_board.gd")
const Hall = preload("res://core/arcade_hall.gd")
const Strategy = preload("res://core/arcade_strategy.gd")
const Chess = preload("res://core/arcade_chess.gd")
const DUO:= ["snake", "xiangqi", "gomoku"]
const ONE_LINE:= {"snake": "吃果子变长，撞墙撞人就出局", "blocks": "摆满一行就消掉，消满 30 行过关", "mines": "翻开所有安全格，第一下一定安全", "xiangqi": "将死对方或让对方无棋可走", "gomoku": "先连成五子就赢 · 15×15 无禁手"}
const SAY_COLORS:= [Color("2f6f9f"), Color("b0475a"), Color("4f7a2f")]

var controls

var cabinet:= ""
var object_id:= ""
var board: Dictionary = {}
var view: ArcadeBoardView
var report: Label
var elapsed:= 0.0
var match_id:= ""
var selected:= -1
var direction:= ""
var settled:= false
var started_at:= 0.0
var search:= -1
var search_board: Dictionary = {}
var hosted:= false
var request:= ""
var waiting_for_seat:= ""
var ready_sent:= false
var hosted_result:= ""

var mode:= ""
var spectating:= false
var invitee:= ""
var invite_state:= ""
var invite_line:= ""
var pending_join:= {}
var active_invite_id:= ""
var owner_answer_request:= ""
var seat_retry_at:= 0
var seat_requested:= false
var remote_play:= false
var wait_ended:= ""
var local_feed: Array = []
var snapshot: Dictionary = {}
var leave_armed:= 0.0
var _font: SystemFont
var _hub: PanelContainer
var _table: PanelContainer
var _title: Label
var _timer: Label
var _plate_top: Control
var _plate_me: Control
var _feed: RichTextLabel
var _wait_card: PanelContainer
var _wait_label: Label
var _wait_face: Control
var _wait_button: Button
var _wait_text:= ""
var _buttons: HBoxContainer
var _banner: Control
var _invite_card: PanelContainer
var _card_layer: CanvasLayer
var _invite_left: Label
var _invite_left_sec:= -1
var _wait_clock_sec:= -1
var _invite_row: Dictionary = {}
var _feed_sig:= ""


func setup(screen) -> void:
 controls = screen
 hide()
 _font = SystemFont.new()
 _font.font_names = PackedStringArray(["Microsoft YaHei UI", "Microsoft YaHei", "SimHei"])
 theme = Theme.new()
 theme.default_font = _font
 theme.default_font_size = 15
 add_theme_stylebox_override("panel", StyleBoxEmpty.new())
 mouse_filter = Control.MOUSE_FILTER_STOP
 set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
 var dim:= ColorRect.new()
 dim.color = Color(0.07, 0.05, 0.04, 0.62)
 dim.mouse_filter = Control.MOUSE_FILTER_STOP
 add_child(dim)
 var center:= CenterContainer.new()
 add_child(center)
 _hub = PanelContainer.new()
 _hub.add_theme_stylebox_override("panel", _card_face())
 center.add_child(_hub)
 _table = PanelContainer.new()
 _table.add_theme_stylebox_override("panel", _card_face())
 center.add_child(_table)
 _build_table()
 _invite_card = PanelContainer.new()
 _invite_card.add_theme_stylebox_override("panel", _card_face())
 _invite_card.theme = theme
 _invite_card.hide()


 _card_layer = CanvasLayer.new()
 _card_layer.name = "ArcadeCardLayer"
 _card_layer.layer = 128
 add_child.call_deferred(_card_layer)
 _card_layer.add_child.call_deferred(_invite_card)
 _wait_card = PanelContainer.new()
 _wait_card.add_theme_stylebox_override("panel", _card_face())
 _wait_card.theme = theme
 _wait_card.hide()
 var wait_paper:= _paper(10)
 _wait_card.add_child(wait_paper)
 var wait_row:= HBoxContainer.new()
 wait_row.add_theme_constant_override("separation", 12)
 wait_paper.add_child(wait_row)
 _wait_face = Face.new()
 _wait_face.owner_ui = self
 _wait_face.custom_minimum_size = Vector2(52, 52)
 wait_row.add_child(_wait_face)
 _wait_label = _label("", 16, Hud.WOOD_D)
 _wait_label.custom_minimum_size = Vector2(300, 0)
 _wait_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
 _wait_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
 wait_row.add_child(_wait_label)
 _wait_button = _button("取消", stop)
 wait_row.add_child(_wait_button)
 _card_layer.add_child.call_deferred(_wait_card)
 VadsLink.foreground_reply.connect(_host_reply)
 VadsLink.connection_changed.connect(func(connected: bool):
  if hosted and not connected:
   stop()
   controls.tell("与电玩城的连接已断开"))
 get_viewport().size_changed.connect(_fit)

static func art_box(bg: Color, border: Color, width:= 2, radius:= 6) -> StyleBoxFlat:
 var f:= StyleBoxFlat.new()
 f.bg_color = bg
 f.border_color = border
 f.set_border_width_all(width)
 f.set_corner_radius_all(radius)
 f.set_content_margin_all(8)
 return f


func _card_face() -> StyleBoxFlat:
 var f:= art_box(Hud.WOOD_D, Hud.WOOD_L, 3, 8)
 f.set_content_margin_all(6)
 f.shadow_color = Color(0, 0, 0, 0.5)
 f.shadow_size = 22
 f.shadow_offset = Vector2(0, 10)
 return f

func _band() -> PanelContainer:
 var band:= PanelContainer.new()
 var f:= art_box(Hud.WOOD, Hud.WOOD_S, 0, 5)
 f.border_width_bottom = 3
 f.content_margin_left = 14
 f.content_margin_right = 8
 f.content_margin_top = 6
 f.content_margin_bottom = 8
 band.add_theme_stylebox_override("panel", f)
 return band

func _paper(margin:= 12) -> PanelContainer:
 var p:= PanelContainer.new()
 var f:= art_box(Hud.PAPER, Hud.PAPER_D, 0, 5)
 f.set_content_margin_all(margin)
 p.add_theme_stylebox_override("panel", f)
 return p

func _plaque_title(text: String, px:= 24) -> Label:
 var l:= _label(text, px, Hud.CREAM)
 l.add_theme_color_override("font_outline_color", Hud.WOOD_D)
 l.add_theme_constant_override("outline_size", 5)
 return l

func _label(text: String, size_px: int, color: Color) -> Label:
 var l:= Label.new()
 l.text = text
 l.add_theme_font_size_override("font_size", size_px)
 l.add_theme_color_override("font_color", color)
 return l

func _button(text: String, used: Callable, primary:= false) -> Button:
 var b:= Button.new()
 b.text = text
 b.focus_mode = Control.FOCUS_NONE

 for state in ["normal", "hover", "pressed", "disabled"]:
  var c: Color = Hud.WOOD if primary else Hud.PAPER_H
  if state == "hover": c = Hud.WOOD_L if primary else Hud.CREAM
  elif state == "pressed": c = Hud.WOOD_S if primary else Hud.PAPER_D
  elif state == "disabled": c = Hud.PAPER_D
  var f:= art_box(c, Hud.WOOD_D if primary else Hud.WOOD_L, 2, 5)
  f.border_width_bottom = 2 if state == "pressed" else 4
  f.content_margin_left = 16
  f.content_margin_right = 16
  f.content_margin_top = 5 if state != "pressed" else 7
  f.content_margin_bottom = 5 if state != "pressed" else 3
  b.add_theme_stylebox_override(state, f)
 for state in ["font_color", "font_hover_color", "font_pressed_color"]:
  b.add_theme_color_override(state, Hud.CREAM if primary else Hud.INK)
 b.add_theme_color_override("font_disabled_color", Hud.INK2)
 b.add_theme_font_size_override("font_size", 15)
 b.pressed.connect(used)
 return b

func _fit() -> void:
 var screen:= get_viewport_rect().size
 position = Vector2.ZERO
 size = screen
 var w:= clampf(screen.x * 0.9, 640.0, 1180.0)
 var h:= clampf(screen.y * 0.86, 460.0, 720.0)
 _table.custom_minimum_size = Vector2(w, h)


func _build_table() -> void:
 var column:= VBoxContainer.new()
 column.add_theme_constant_override("separation", 6)
 _table.add_child(column)
 var band:= _band()
 column.add_child(band)
 var head:= HBoxContainer.new()
 head.add_theme_constant_override("separation", 14)
 band.add_child(head)
 _title = _plaque_title("电玩城", 26)
 head.add_child(_title)
 report = _label("", 15, Color("f3dcb2"))
 report.size_flags_horizontal = Control.SIZE_EXPAND_FILL
 report.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
 report.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
 head.add_child(report)
 _timer = _label("", 16, Hud.GOLD)
 _timer.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
 head.add_child(_timer)
 head.add_child(_button("✕", _ask_leave, true))
 var paper:= _paper(14)
 paper.size_flags_vertical = Control.SIZE_EXPAND_FILL
 column.add_child(paper)
 var body:= HBoxContainer.new()
 body.add_theme_constant_override("separation", 16)
 body.size_flags_vertical = Control.SIZE_EXPAND_FILL
 paper.add_child(body)
 var board_box:= Control.new()
 board_box.size_flags_vertical = Control.SIZE_EXPAND_FILL
 board_box.size_flags_horizontal = Control.SIZE_EXPAND_FILL
 body.add_child(board_box)
 var mat:= Panel.new()
 var mat_face:= art_box(Hud.WOOD, Hud.WOOD_D, 3, 8)
 mat_face.shadow_color = Color(0, 0, 0, 0.3)
 mat_face.shadow_size = 8
 mat_face.shadow_offset = Vector2(0, 4)
 mat.add_theme_stylebox_override("panel", mat_face)
 mat.mouse_filter = Control.MOUSE_FILTER_IGNORE
 board_box.add_child(mat)
 view = ArcadeBoardView.new()
 view.gui_input.connect(_board_input)
 view.mouse_exited.connect(func(): view.hover = Vector2i(-1, -1))
 board_box.add_child(view)
 view.mouse_filter = Control.MOUSE_FILTER_STOP
 _banner = Banner.new()
 _banner.owner_ui = self
 _banner.mouse_filter = Control.MOUSE_FILTER_IGNORE
 board_box.add_child(_banner)
 board_box.resized.connect(func():
  var side:= minf(board_box.size.x, board_box.size.y) - 24.0
  view.size = Vector2.ONE * side
  view.position = (board_box.size - view.size) / 2.0
  mat.position = view.position - Vector2(10, 10)
  mat.size = view.size + Vector2(20, 20)
  _banner.size = view.size
  _banner.position = view.position)
 var side_column:= VBoxContainer.new()
 side_column.custom_minimum_size = Vector2(390, 0)
 side_column.add_theme_constant_override("separation", 8)
 body.add_child(side_column)
 _plate_top = Plate.new()
 _plate_top.owner_ui = self
 _plate_top.top = true
 _plate_top.custom_minimum_size = Vector2(0, 84)
 side_column.add_child(_plate_top)
 var feed_frame:= PanelContainer.new()
 var feed_face:= art_box(Hud.PAPER_H, Hud.PAPER_D, 2, 8)
 feed_face.set_content_margin_all(10)
 feed_frame.add_theme_stylebox_override("panel", feed_face)
 feed_frame.size_flags_vertical = Control.SIZE_EXPAND_FILL
 side_column.add_child(feed_frame)
 _feed = RichTextLabel.new()
 _feed.bbcode_enabled = true
 _feed.scroll_following = true
 _feed.add_theme_color_override("default_color", Hud.INK)
 _feed.add_theme_font_size_override("normal_font_size", 14)
 _feed.add_theme_font_size_override("italics_font_size", 13)
 _feed.add_theme_font_size_override("bold_font_size", 14)
 feed_frame.add_child(_feed)
 _plate_me = Plate.new()
 _plate_me.owner_ui = self
 _plate_me.custom_minimum_size = Vector2(0, 84)
 side_column.add_child(_plate_me)
 _buttons = HBoxContainer.new()
 _buttons.add_theme_constant_override("separation", 8)
 _buttons.alignment = BoxContainer.ALIGNMENT_END
 side_column.add_child(_buttons)
 _fit()

func _show(card: String) -> void:
 mode = card
 _hub.visible = card == "hub"
 _table.visible = card == "table"
 visible = card in ["hub", "table"]
 if _wait_card != null: _wait_card.visible = card == "wait"
 _fit()
 if card == "wait": _refresh_wait()




static func invite_seconds_left(invitation: Dictionary, now_ms: int) -> int:
 if invitation.is_empty(): return -1
 var created:= int(invitation.get("createdAt", 0))
 var reply:= int(invitation.get("replySeconds", 0))
 if created > 0 and reply > 0:
  return maxi(0, int(ceil(float(created + reply * 1000 - now_ms) / 1000.0)))
 return int(invitation.get("remainingSeconds", -1))


func _wait_now() -> String:
 if wait_ended != "": return "这局没开成 · " + wait_ended
 if remote_play: return "观察者对局（你不在场上） · " + _name(invitee) + "已入座，棋盘是这一局的真实场面"
 var who:= _name(invitee) if invitee != "" else "对手"
 var invitation: Variant = VadsLink.arcade_view.get("invitation")
 var seat:= ""
 var left:= -1
 if invitation is Dictionary and invitation.get("id") == active_invite_id:
  seat = str(invitation.get("residentSeat", ""))
  left = invite_seconds_left(invitation, SharedFeed.now_ms())


 if invite_state == "asking":
  var mine:= "你已入座" if ready_sent else("你正走向座位" if waiting_for_seat != "" else "正在确认机位")
  var hers:= "她还没选机位" if seat == "no_seat_requested" else("她已选机位、还在走" if seat == "heading_to_seat" else "她已入座" if seat == "seated" else "")
  var clock:= (" · 还剩 %d 秒" % left) if left >= 0 else ""
  return "%s · 等%s回话%s · %s" % [mine, who, clock, hers]
 if invite_state == "confirming": return "正在确认你的回复"
 if not pending_join.is_empty(): return "你正走向机台"
 var theirs:= "%s尚未请求入座" % who
 if seat == "heading_to_seat": theirs = "%s已选机位，尚未入座" % who
 if seat == "seated": theirs = "%s已入座" % who
 if not ready_sent:
  return("你正走向座位 · " if waiting_for_seat != "" else "正在确认机位 · ") + theirs
 return "你已入座 · " + theirs

func _refresh_wait() -> void:
 if _wait_card == null or not _wait_card.visible: return
 var text:= _wait_now()
 _wait_face.set("who", invitee)
 _wait_face.queue_redraw()
 _wait_button.text = "好吧" if wait_ended != "" else "取消"
 if text != _wait_text:
  _wait_text = text
  _wait_label.text = text
  _wait_card.reset_size()
 _wait_card.position = Vector2((get_viewport_rect().size.x - _wait_card.size.x) / 2.0, 18.0)


func show_board() -> void:
 _show("table")
 _refresh_buttons()
 _redraw_all()






var _hub_key:= ""
var _hub_object: Dictionary = {}
var _hub_kind:= ""
var _hub_who:= ""

func open_hub(key: String, object: Dictionary) -> void:
 if hosted or not board.is_empty():
  show_board()
  return
 _hub_key = key
 _hub_object = object
 var kinds:= _hub_kinds()
 if not _hub_kind in kinds: _hub_kind = kinds [0]
 if not _hub_who in _hub_opponents().map(func(o): return str(o.id)): _hub_who = _default_opponent()
 _build_hub()
 _show("hub")


func _hub_kinds() -> Array:
 var kinds: Array = ["xiangqi", "gomoku"] if _hub_key.begins_with("xiangqi") else [_hub_key.get_slice("@", 0)]
 if not Features.on("gomoku"): kinds.erase("gomoku")
 return kinds

func _hub_suffix() -> String:
 return "@xjhome" if _hub_object.get("space") == "xjhome" else "@home" if _hub_object.get("space") == "home" else ""


func _hub_opponents() -> Array:
 var out: Array = []
 if _hub_suffix().is_empty():
  out.append({"id": "computer", "name": ArcadePanel.name_of("computer") if _hub_kind in DUO else "自己玩", "free": true, "playing": ""})
 if VadsLink.owns_bodies and _hub_kind in DUO and not(_hub_kind == "snake" and not _hub_suffix().is_empty()):
  for r in _residents(): out.append(r)
 return out

func _default_opponent() -> String:
 var all:= _hub_opponents()
 for o in all:
  if str(o.id) != "computer" and o.get("free", false) and str(o.get("playing", "")) == "": return str(o.id)
 return str(all [0].id) if not all.is_empty() else ""

func _icon_button(px: Vector2, radius: int, selected: bool, bg: Color) -> Button:
 var b:= Button.new()
 b.focus_mode = Control.FOCUS_NONE
 b.custom_minimum_size = px
 b.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
 for state in ["normal", "hover", "pressed", "disabled"]:
  var f:= art_box(bg if state != "hover" else bg.lightened(0.12), Hud.GOLD if selected else(Hud.WOOD_L if state == "hover" else Hud.WOOD_D), 4 if selected else 2, radius)
  f.set_content_margin_all(6)
  f.shadow_color = Color(0, 0, 0, 0.3 if selected else 0.18)
  f.shadow_size = 7 if selected else 3
  f.shadow_offset = Vector2(0, 3)
  b.add_theme_stylebox_override(state, f)
 return b


func _icon_cell(icon: Button, caption: String, sub:= "", sub_color:= Hud.INK2) -> VBoxContainer:
 var cell:= VBoxContainer.new()
 cell.add_theme_constant_override("separation", 3)
 cell.add_child(icon)
 var name_label:= _label(caption, 15, Hud.INK)
 name_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
 cell.add_child(name_label)
 if sub != "":
  var s:= _label(sub, 12, sub_color)
  s.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
  cell.add_child(s)
 return cell

static func _sample_board(kind: String) -> Dictionary:
 var b: Dictionary = Board.begin({"kind": kind, "seed": 11, "players": ["a", "b"], "skill": {}})
 if kind == "gomoku":
  for k in [112, 97, 113, 127, 111, 98]: b.board [k] = 0 if k in [112, 113, 111] else 1
  b.last = 111
 return b

func _icon_grid() -> HFlowContainer:
 var grid:= HFlowContainer.new()
 grid.add_theme_constant_override("h_separation", 26)
 grid.add_theme_constant_override("v_separation", 12)
 grid.alignment = FlowContainer.ALIGNMENT_CENTER
 return grid

func _build_hub() -> void:
 for c in _hub.get_children(): c.queue_free()
 var column:= VBoxContainer.new()
 column.add_theme_constant_override("separation", 6)
 _hub.add_child(column)
 var band:= _band()
 column.add_child(band)
 var head:= HBoxContainer.new()
 band.add_child(head)
 var title:= _plaque_title(str(_hub_object.get("name", "电玩城")), 22)
 title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
 head.add_child(title)
 if not VadsLink.arcade_view.get("settings", {}).is_empty():
  head.add_child(_button("规则设置", _show_rules))
 head.add_child(_button("✕", stop, true))
 var paper:= _paper(18)
 column.add_child(paper)
 var body:= VBoxContainer.new()
 body.custom_minimum_size = Vector2(520, 0)
 body.add_theme_constant_override("separation", 12)
 paper.add_child(body)

 body.add_child(_label("① 玩什么", 14, Hud.WOOD))
 var games:= _icon_grid()
 body.add_child(games)
 for kind in _hub_kinds():
  var icon:= _icon_button(Vector2(112, 112), 24, kind == _hub_kind, Hud.WOOD_D)
  var mini:= ArcadeBoardView.new()
  mini.board = _sample_board(kind)
  mini.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
  mini.offset_left = 10
  mini.offset_top = 10
  mini.offset_right = -10
  mini.offset_bottom = -10
  icon.add_child(mini)
  icon.pressed.connect(func():
   if _hub_kind == kind: return
   _hub_kind = kind
   if not _hub_who in _hub_opponents().map(func(o): return str(o.id)): _hub_who = _default_opponent()
   _build_hub.call_deferred())
  games.add_child(_icon_cell(icon, Hall.NAMES.get(kind, kind)))
 var rule:= _label(ONE_LINE.get(_hub_kind, ""), 13, Hud.INK2)
 rule.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
 body.add_child(rule)
 body.add_child(HSeparator.new())

 body.add_child(_label("② 和谁玩", 14, Hud.WOOD))
 var people:= _icon_grid()
 body.add_child(people)
 var chosen: Dictionary = {}
 for o in _hub_opponents():
  var id:= str(o.id)
  var busy:= str(o.get("playing", "")) != ""
  if id == _hub_who: chosen = o
  var icon:= _icon_button(Vector2(84, 84), 42, id == _hub_who, Hud.PAPER_D)
  var face:= Face.new()
  face.who = id
  face.owner_ui = self
  face.mouse_filter = Control.MOUSE_FILTER_IGNORE
  face.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
  face.offset_left = 8
  face.offset_top = 8
  face.offset_right = -8
  face.offset_bottom = -8
  icon.add_child(face)
  icon.pressed.connect(func():
   if _hub_who == id: return
   _hub_who = id
   _build_hub.call_deferred())
  var sub:= "电脑" if id == "computer" else(("在玩" + str(o.playing)) if busy else("有空" if o.get("free", false) else "在忙"))
  var sub_color: Color = Hud.INK2 if id == "computer" else(Color("4f8a3a") if o.get("free", false) and not busy else Color("a0623a"))
  var cell:= _icon_cell(icon, str(o.get("name", id)), ("● " if id != "computer" else "") + sub, sub_color)
  if busy: cell.modulate = Color(1, 1, 1, 0.55)
  people.add_child(cell)

 body.add_child(HSeparator.new())
 var foot:= HBoxContainer.new()
 foot.add_theme_constant_override("separation", 12)
 body.add_child(foot)
 var notes:= VBoxContainer.new()
 notes.size_flags_horizontal = Control.SIZE_EXPAND_FILL
 notes.add_theme_constant_override("separation", 0)
 foot.add_child(notes)
 var record:= _record_with(_hub_kind, _hub_who) if _hub_who != "computer" else ""
 notes.add_child(_label(record if record != "" else("她会按自己的心情决定来不来" if not _hub_who in ["", "computer"] else "随时可以按 Esc 离开"), 13, Hud.INK2))
 notes.add_child(_label("赢 +5 钱 · 输 −2 钱 · 平局和中断不算", 12, Hud.INK2))
 var go:= _button("开始" if _hub_who == "computer" else "邀请" + str(chosen.get("name", "")), _hub_go, true)
 go.custom_minimum_size = Vector2(150, 46)
 go.add_theme_font_size_override("font_size", 18)
 go.disabled = _hub_who == "" or str(chosen.get("playing", "")) != ""
 foot.add_child(go)

func _show_rules() -> void:
 var settings: Dictionary = VadsLink.arcade_view.get("settings", {})
 var notes: Dictionary = settings.get("notes", {})
 var lines:= PackedStringArray()
 for key in notes:
  if settings.has(key):
   lines.append(str(notes [key]) + "  " + str(settings [key]))
 var dialog:= AcceptDialog.new()
 dialog.title = "电玩城规则设置"
 dialog.dialog_text = "\n\n".join(lines)
 dialog.get_label().autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
 dialog.confirmed.connect(dialog.queue_free)
 dialog.canceled.connect(dialog.queue_free)
 add_child(dialog)
 dialog.popup_centered(Vector2i(630, 540))

func _hub_go() -> void:
 var kind:= _hub_kind
 var object:= _hub_object
 if _hub_who == "computer":
  var solo_key: String = _hub_key if _hub_key.get_slice("@", 0) == kind else kind

  stop()
  if not start(solo_key, str(object.get("id", ""))): controls.tell("这个机位正在使用")
  return
 var physical: String = (kind + _hub_suffix()) if kind in ["xiangqi", "gomoku"] else _hub_key
 invite(physical, _hub_who)

func _residents() -> Array:
 var rows: Array = VadsLink.arcade_view.get("residents", [])
 if rows.is_empty():
  for p in Residents.people():
   if p.key != Residents.PLAYER: rows.append({"id": p.key, "name": p.get("name", p.key), "free": true, "playing": ""})
 return rows

func _record_with(kind: String, who: String) -> String:
 var won:= 0
 var lost:= 0
 var draw:= 0
 for r in VadsLink.arcade_view.get("history", []):
  if not r is Dictionary or r.get("kind") != kind: continue
  var ids: Array = r.get("players", []).map(func(p): return str(p.get("id", "")))
  if not(Residents.PLAYER in ids and who in ids): continue
  for p in r.players:
   if p.get("id") == Residents.PLAYER:
    match p.get("result"):
     "won": won += 1
     "lost": lost += 1
     "draw": draw += 1
 return "" if won + lost + draw == 0 else "你们之间 %d 胜 %d 负 %d 平" % [won, lost, draw]



func invite(key: String, who: String) -> void:
 stop()
 cabinet = key
 hosted = true
 invitee = who
 invite_state = "asking"
 invite_line = ""
 request = "invite-" + str(Time.get_ticks_usec())
 active_invite_id = request
 controls.player.stop_navigation()
 local_feed = [{"kind": "system", "text": "你邀请了%s" % _name(who)}]
 _title.text = Hall.NAMES.get(key.get_slice("@", 0), "对局")
 _show("wait")
 VadsLink.send({"type": "arcade.playerInvite", "id": request, "key": key, "resident": who})



 _join_own_seat()


func _join_own_seat() -> void:
 request = "join-" + str(Time.get_ticks_usec())
 view.board = {}
 seat_requested = true
 var frame:= {"type": "arcade.playerJoin", "id": request, "key": cabinet, "inviteId": active_invite_id}
 VadsLink.send(frame)


func _owner_invited(frame: Dictionary) -> void:
 _invite_row = frame.duplicate()
 _invite_row ["until"] = Time.get_ticks_msec() + int(frame.get("seconds", 1)) * 1000
 for c in _invite_card.get_children(): c.queue_free()
 var paper:= _paper(12)
 _invite_card.add_child(paper)
 var row:= HBoxContainer.new()
 row.add_theme_constant_override("separation", 12)
 paper.add_child(row)
 var face:= Face.new()
 face.who = str(frame.get("from", ""))
 face.owner_ui = self
 face.custom_minimum_size = Vector2(64, 64)
 row.add_child(face)
 var text:= VBoxContainer.new()
 text.custom_minimum_size = Vector2(320, 0)
 text.add_theme_constant_override("separation", 4)
 row.add_child(text)
 text.add_child(_label("%s 邀请你去%s玩%s" % [frame.get("name", "她"), frame.get("place", "电玩城"), frame.get("game", "")], 17, Hud.WOOD_D))
 var words:= str(frame.get("words", ""))
 if words != "":
  var said:= _label("“%s”" % words, 15, Hud.INK)
  said.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
  text.add_child(said)
 var bar:= ProgressBar.new()
 bar.name = "Bar"
 bar.show_percentage = false
 bar.custom_minimum_size = Vector2(0, 6)
 bar.max_value = 1.0
 bar.value = 1.0
 bar.add_theme_stylebox_override("background", art_box(Hud.PAPER_D, Hud.PAPER_D, 0, 3))
 bar.add_theme_stylebox_override("fill", art_box(Hud.WOOD_L, Hud.WOOD_L, 0, 3))
 text.add_child(bar)
 _invite_left = _label("", 13, Hud.INK)
 _invite_left_sec = -1
 text.add_child(_invite_left)
 var actions:= VBoxContainer.new()
 actions.add_theme_constant_override("separation", 6)
 row.add_child(actions)
 actions.add_child(_button("好呀", _answer_owner_invite.bind(true), true))
 actions.add_child(_button("下次吧", _answer_owner_invite.bind(false)))
 _invite_card.show()
 _place_invite_card.call_deferred()

func _place_invite_card() -> void:
 _invite_card.reset_size()
 _invite_card.position = Vector2((get_viewport_rect().size.x - _invite_card.size.x) / 2.0, 18.0)

func _answer_owner_invite(yes: bool) -> void:
 var row:= _invite_row
 _invite_row = {}
 _invite_card.hide()
 if row.is_empty(): return



 var observer: bool = not controls.player.player_enabled
 var answer_id:= "answer-" + str(Time.get_ticks_usec())
 if yes:
  stop()
  owner_answer_request = answer_id
  active_invite_id = str(row.get("inviteId", ""))
  invitee = str(row.get("from", ""))
  cabinet = str(row.get("key", ""))
  remote_play = observer or bool(row.get("remote", false))
  invite_state = "confirming"
  _title.text = Hall.NAMES.get(cabinet.get_slice("@", 0), "对局") + (" · 观察者对局" if remote_play else "")
  _show("wait")
  if remote_play: controls.tell("观察者模式：你会以远程对局的方式和她下，不在场上坐着")
 VadsLink.send({"type": "arcade.ownerInviteAnswer", "id": answer_id, "inviteId": row.get("inviteId", ""), "accept": yes})

func _walk_to_invited_machine() -> void:
 invite_state = "coming"

 if remote_play:
  start_shared(cabinet, active_invite_id)
  return
 var space:= "home" if cabinet.ends_with("@home") else "xjhome" if cabinet.ends_with("@xjhome") else "arcade"
 var scene: String = WorldData.scene_of_space(space)
 if controls.player.scene_id == scene:
  start_shared(cabinet, active_invite_id)
 elif controls.player.go_local(scene):
  pending_join = {"key": cabinet, "scene": scene, "inviteId": active_invite_id}
 else:
  _end_wait("现在无法走到机台")


func refresh_remote_note() -> void:
 if not remote_play: return
 if report != null: report.text = "观察者对局（你不在场上） · 她在对面板前"
 _title.text = Hall.NAMES.get(cabinet.get_slice("@", 0), "对局") + " · 观察者对局"

func _end_wait(reason: String) -> void:
 stop()
 wait_ended = reason
 _show("wait")


func start_shared(key: String, invite_id:= "") -> void:
 var keep_invitee:= invitee
 var keep_state:= invite_state
 var keep_feed:= local_feed.duplicate()
 stop(false)
 active_invite_id = invite_id
 invitee = keep_invitee
 invite_state = keep_state
 local_feed = keep_feed
 cabinet = key
 hosted = true
 request = "join-" + str(Time.get_ticks_usec())
 controls.player.stop_navigation()
 _title.text = Hall.NAMES.get(key.get_slice("@", 0), "对局")
 view.board = {}
 _show("wait")
 var frame:= {"type": "arcade.playerJoin", "id": request, "key": cabinet}
 if invite_id != "": frame ["inviteId"] = invite_id
 VadsLink.send(frame)


func watch(key: String) -> void:
 if hosted or not board.is_empty(): return
 stop()
 spectating = true
 cabinet = key
 _title.text = Hall.NAMES.get(key.get_slice("@", 0), "对局") + " · 观战"
 show_board()

func _host_reply(frame: Dictionary) -> void:
 if frame.get("type") == "arcade.ownerInvite":
  _owner_invited(frame)
  return
 if frame.get("type") == "arcade.ownerInviteAnswerResult":
  if owner_answer_request == "" or frame.get("id") != owner_answer_request: return
  owner_answer_request = ""
  if frame.get("ok", false): _walk_to_invited_machine()
  else: _end_wait(str(frame.get("error", "邀请已结束")))
  return
 if not hosted or frame.get("id") != request:
  return
 match str(frame.type):
  "arcade.inviteReply":
   pass
  "arcade.playerFinished":
   var outcome: Dictionary = frame.get("outcome", {})
   hosted_result = str(outcome.get("reason", "对局结束"))
   if outcome.get("matchId") == match_id and outcome.get("result") in ["won", "lost", "draw"]:
    controls.transact("life_event", {"event": {"type": "arcade", "matchId": match_id, "kind": outcome.kind, "result": outcome.result}})
  "arcade.playerResult":
   if not frame.get("ok", false):
    _end_wait(str(frame.get("error", "机位暂不可用")))
    return
   match_id = str(frame.matchId)

   if frame.get("remote", false) or remote_play:
    remote_play = true
    waiting_for_seat = ""
    report.text = "观察者对局 · 你不在场上"
    _title.text = Hall.NAMES.get(cabinet.get_slice("@", 0), "对局") + " · 观察者对局"
    VadsLink.send({"type": "arcade.playerReady", "id": request, "matchId": match_id})
    refresh_remote_note()
    _refresh_buttons(); _redraw_all()
    return
   waiting_for_seat = str(frame.zone)
   if not controls.player.go_local(controls.player.scene_id, waiting_for_seat):
    _end_wait("现在无法走到座位")
    return
   report.text = "正走向座位"
  "arcade.playerReadyResult":
   if frame.get("matchId") == match_id and frame.get("ok", false):
    ready_sent = true
    controls.player.action = "sit"
    controls.player.action_label = "等对手入座"
 _refresh_buttons()
 _redraw_all()


func start(key: String, object: String) -> bool:
 var game_kind:= key.get_slice("@", 0)
 if not Hall.NAMES.has(game_kind) or(game_kind == "gomoku" and not Features.on("gomoku")):
  return false
 var physical:= key.replace("gomoku", "xiangqi")
 for existing in VadsLink.arcade_view.get("sessions", {}):
  var snap: Dictionary = VadsLink.arcade_view.sessions [existing]
  if str(existing).replace("gomoku", "xiangqi") == physical and snap.get("status") in ["waiting", "playing"]:
   return false
 stop()
 cabinet = physical
 object_id = object
 match_id = "player-%s-%s" % [game_kind, Time.get_ticks_usec()]
 started_at = SharedFeed.now_ms()
 settled = false
 selected = -1
 direction = ""
 elapsed = 0
 board = Board.begin({"kind": game_kind, "seed": randi(), "players": ["owner", "computer"] if game_kind in DUO else ["owner"], "skill": {"owner": 0.7, "computer": 0.65}})
 local_feed = [{"kind": "system", "text": "开局了"}]
 controls.player.stop_navigation()
 controls.player.action = "sit"
 controls.player.action_label = "在玩" + Hall.NAMES [game_kind]
 _title.text = Hall.NAMES [game_kind]
 show_board()
 return true

func stop(notify:= true) -> void:
 if notify and VadsLink.connected and(hosted or active_invite_id != ""):
  VadsLink.send({"type": "arcade.playerLeave", "id": request, "matchId": match_id, "inviteId": active_invite_id})
 if hosted or not pending_join.is_empty():
  controls.player.stop_navigation()
 if ready_sent and is_instance_valid(controls):
  controls.player.action = ""
  controls.player.action_label = ""
 if search >= 0:
  WorkerThreadPool.wait_for_task_completion(search)
  search = -1
 if visible and is_instance_valid(controls) and not spectating and mode == "table":
  controls.player.action = ""
  controls.player.action_label = ""
 _show("")
 _wait_text = ""
 hosted = false
 spectating = false
 request = ""
 match_id = ""
 waiting_for_seat = ""
 hosted_result = ""
 ready_sent = false
 seat_requested = false
 remote_play = false
 selected = -1
 cabinet = ""
 board = {}
 snapshot = {}
 invitee = ""
 invite_state = ""
 invite_line = ""
 active_invite_id = ""
 owner_answer_request = ""
 seat_retry_at = 0
 wait_ended = ""
 pending_join = {}
 local_feed = []
 leave_armed = 0.0
 _feed_sig = ""
 _timer.text = ""
 if view != null:
  view.selected = -1
  view.targets = []
  view.board = {}

func redraw() -> void:
 _redraw_all()


func _name(id: String) -> String:
 if id == "": return ""
 if id == Residents.PLAYER: return "你"
 if id == "computer": return ArcadePanel.name_of("computer")
 for p in snapshot.get("players", []):
  if str(p.get("id")) == id: return str(p.get("name", id))
 for r in VadsLink.arcade_view.get("residents", []):
  if str(r.get("id")) == id: return str(r.get("name", id))
 return str(Residents.person(id).get("name", id))

func characters() -> Array:
 return controls.game.characters if controls != null and controls.game != null else []


func seats() -> Array:
 var ids: Array = []
 if board.has("sides"): ids = board.sides.duplicate()
 elif board.has("snakes"): ids = board.snakes.map(func(s): return str(s.id))
 elif board.has("players"): ids = board.players.duplicate()
 elif not snapshot.is_empty(): ids = snapshot.get("players", []).map(func(p): return str(p.get("id")))
 ids = ids.map(func(x): return str(x))
 if ids.is_empty() and(hosted or invitee != ""): ids = [invitee, Residents.PLAYER]
 if ids.size() == 1: ids.push_front("")
 if ids.size() >= 2 and ids [0] == Residents.PLAYER: ids.reverse()
 return ids

func side_label(id: String) -> String:
 if board.is_empty() or id == "": return ""
 match str(board.kind):
  "xiangqi": return "红方" if board.sides.find(id) == 1 else "黑方"
  "gomoku": return "白棋 ○" if board.sides.find(id) == 1 else "黑棋 ●"
  "snake":
   for i in board.snakes.size():
    if str(board.snakes [i].id) == id: return("绿蛇" if i == 0 else "黄蛇") + " · %d 个" % int(board.snakes [i].score)
 return ""


func side_color(id: String) -> Color:
 if board.is_empty() or id == "": return Hud.PAPER_D
 match str(board.kind):
  "xiangqi": return Color("b53950") if board.sides.find(id) == 1 else Color("253145")
  "gomoku": return Color("e9dcc0") if board.sides.find(id) == 1 else Color("252735")
  "snake":
   for i in board.snakes.size():
    if str(board.snakes [i].id) == id: return Color("7be04a") if i == 0 else Color("f2d347")
 return Hud.WOOD_L

func to_move() -> String:
 if board.get("status") != "playing" or not board.has("sides"): return ""
 return str(board.sides [int(board.turn)])

func mind_of(id: String) -> Dictionary:
 return snapshot.get("minds", {}).get(id, {})

func feed_rows() -> Array:
 var rows: Array = snapshot.get("feed", [])
 return local_feed + rows if not rows.is_empty() else local_feed

func _redraw_all() -> void:
 if view == null: return
 if selected >= 0 and board.get("kind") == "xiangqi":
  view.selected = selected
  view.targets = _targets(selected)
 else:
  view.selected = -1
  view.targets = []
 view.board = board
 view.queue_redraw()
 _plate_top.queue_redraw()
 _plate_me.queue_redraw()
 _banner.queue_redraw()
 _refresh_feed()
 _refresh_report()

func _refresh_report() -> void:
 if board.is_empty(): return
 var kind: String = board.kind
 var text: String = ONE_LINE.get(kind, "")
 if board.get("status") != "playing":
  text = str(board.get("reason", "已结束"))
 elif kind in ["xiangqi", "gomoku"]:
  var who:= to_move()
  if who == Residents.PLAYER: text = "轮到你" + (" · 点自己的棋子，再点亮起的落点" if kind == "xiangqi" else " · 点交叉点落子")
  elif mind_of(who).get("thinking", false): text = "%s在想…" % _name(who)
  else: text = "轮到%s" % _name(who)
  if board.get("inCheck", false): text += " · 将军！"
 elif kind == "snake":
  text = "方向键 / WASD 控制 · " + text
 elif kind == "blocks":
  text = "← → 移动 · ↑ 旋转 · 空格落下 · 消行 %d/%d" % [int(board.lines), int(board.target)]
 elif kind == "mines":
  text = "左键翻开 · 右键插旗 · 翻开 %d/%d" % [board.open.size(), int(board.w * board.h - board.total)]
 report.text = text

func _escape(t: String) -> String:
 return t.replace("[", "[lb]")

func _refresh_feed() -> void:
 var rows:= feed_rows()
 var sig:= str(rows.size()) + ":" + (str(rows [-1]) if not rows.is_empty() else "") + invite_state
 if sig == _feed_sig: return
 _feed_sig = sig
 var lines:= PackedStringArray()
 for r in rows.slice(-40):
  var text:= _escape(str(r.get("text", "")))
  var who:= str(r.get("name", ""))

  var mine:= str(r.get("from", "")) == Residents.PLAYER
  var color: Color = SAY_COLORS [2] if mine else SAY_COLORS [absi(who.hash()) % 2]
  var chip:= "[bgcolor=#%s][color=#fdf3dd] %s [/color][/bgcolor]" % [color.to_html(false), "你" if mine else _escape(who)]
  match str(r.get("kind", "")):
   "system": lines.append("[center][font_size=12][color=#a08a74]· %s ·[/color][/font_size][/center]" % text)
   "move": lines.append("[font_size=12][color=#8a7462]%s 走[/color] [bgcolor=#e2c99f][color=#3b2416] %s [/color][/bgcolor][/font_size]" % [_escape(who), text])
   "thought": lines.append("[i][color=#9a8a7a]%s 心里想：%s[/color][/i]" % [_escape(who), text])
   "lesson": lines.append("[bgcolor=#f6d98e][color=#5a341b] 记下心得 [/color][/bgcolor] [color=#7a4a26]%s：%s[/color]" % [_escape(who), text])
   _: lines.append("%s %s" % [chip, text])
 _feed.text = "\n".join(lines)
 _feed.add_theme_constant_override("line_separation", 6)

func _refresh_buttons() -> void:
 for c in _buttons.get_children(): c.queue_free()
 var playing: bool = board.get("status") == "playing"
 var finished: bool = not board.is_empty() and not playing
 if spectating:
  _buttons.add_child(_button("关闭", stop))
  return
 if invite_state == "declined":
  _buttons.add_child(_button("好吧", stop, true))
  return
 if playing:
  if board.kind in DUO:
   _buttons.add_child(_button("认输", _resign))
  _buttons.add_child(_button("离开", _ask_leave))
 elif finished:
  _buttons.add_child(_button("再来一局", _rematch, true))
  _buttons.add_child(_button("离开", stop))
 else:
  _buttons.add_child(_button("离开", stop))

func _targets(from: int) -> Array:
 var out: Array = []
 if board.is_empty() or board.kind != "xiangqi": return out
 var side:= int(board.turn)
 for m in Strategy.moves(board.board, side):
  if int(m [0]) == from and Chess.legal(board.board, side, int(m [0]), int(m [1])): out.append(int(m [1]))
 return out


func _resign() -> void:
 if hosted:
  turn({"resign": true})
 elif not board.is_empty() and board.status == "playing":
  var other:= ""
  for id in board.get("sides", board.get("players", [])):
   if str(id) != Residents.PLAYER: other = str(id)
  if other != "": Board.finish(board, "won", other, "你认输了")
  else: Board.finish(board, "lost", null, "主动放弃")
  redraw()
 _refresh_buttons()

func _ask_leave() -> void:
 if board.get("status") == "playing" and not spectating and Time.get_ticks_msec() > leave_armed:
  leave_armed = Time.get_ticks_msec() + 2500.0
  report.text = "再按一次离开（这局不算输赢）"
  return
 stop()

func _rematch() -> void:
 var key:= cabinet
 var kind: String = str(board.get("kind", key.get_slice("@", 0)))
 var partner:= invitee
 if partner == "":
  for id in seats():
   if id != Residents.PLAYER and id != "computer" and id != "": partner = id
 var shared:= hosted or not snapshot.is_empty()
 var object:= object_id
 stop()
 if shared and partner != "":
  invite(kind + ("@" + key.get_slice("@", 1) if "@" in key else ""), partner)
 elif object != "":
  start(kind, object)


func _unhandled_key_input(event: InputEvent) -> void:
 if not visible or not event is InputEventKey or not event.pressed:
  return
 if event.physical_keycode == KEY_ESCAPE:
  if mode == "hub": stop()
  else: _ask_leave()
  get_viewport().set_input_as_handled()
  return
 if board.get("status") != "playing" or spectating:
  return
 if board.kind == "snake":
  direction = {KEY_UP: "up", KEY_DOWN: "down", KEY_LEFT: "left", KEY_RIGHT: "right", KEY_W: "up", KEY_S: "down", KEY_A: "left", KEY_D: "right"}.get(event.physical_keycode, direction)
  if hosted and direction != "":
   turn({"direction": direction})
 elif board.kind == "blocks":
  match event.physical_keycode:
   KEY_LEFT: turn({"move": "left"})
   KEY_RIGHT: turn({"move": "right"})
   KEY_UP: turn({"rotate": true})
   KEY_DOWN, KEY_SPACE: turn({"drop": true})
 get_viewport().set_input_as_handled()

func _board_input(event: InputEvent) -> void:
 if not visible or board.is_empty():
  return
 if event is InputEventMouseMotion:
  var cell:= ArcadeBoardView.cell_at(board, view.area(), event.position)
  if cell != view.hover:
   view.hover = cell
  return
 if spectating or board.get("status") != "playing" or not event is InputEventMouseButton or not event.pressed:
  return
 var kind: String = board.kind
 var width:= int(board.get("w", 9))
 var point:= ArcadeBoardView.cell_at(board, view.area(), event.position)
 if point.x < 0:
  return
 if kind == "mines":
  if event.button_index in [MOUSE_BUTTON_LEFT, MOUSE_BUTTON_RIGHT]:
   turn({"x": point.x, "y": point.y, "flag": event.button_index == MOUSE_BUTTON_RIGHT})
 elif kind in ["gomoku", "xiangqi"] and event.button_index == MOUSE_BUTTON_LEFT and to_move() == Residents.PLAYER:
  var index:= point.y * width + point.x
  if kind == "gomoku":
   if int(board.board [index]) == -1: turn({"at": index, "player": "owner"})
  else:
   var piece = board.board [index]
   if piece is Dictionary and int(piece.side) == int(board.turn):
    selected = -1 if selected == index else index
    redraw()
   elif selected >= 0:
    if index in _targets(selected):
     turn({"from": selected, "to": index, "player": "owner"})
    selected = -1
    redraw()

func turn(input: Dictionary) -> void:
 if board.is_empty() or board.get("status") != "playing":
  return
 if hosted:
  VadsLink.send({"type": "arcade.playerInput", "id": request, "matchId": match_id, "input": input})
  return
 Board.advance(board, input)
 redraw()

static func computer_move(candidate: Dictionary) -> void:
 Board.advance(candidate, Strategy.suggest(candidate))


func _process(dt: float) -> void:
 _tick_invitation()
 _tick_invite_card()
 _tick_pending_join()
 _tick_wait_clock()
 if mode == "wait":
  _refresh_wait()
  if hosted: update_shared_board()
  return
 if not visible or mode != "table":
  return
 view.queue_redraw()
 _plate_top.queue_redraw()
 _plate_me.queue_redraw()
 _banner.queue_redraw()
 if board.get("status") == "playing":
  var secs:= int((SharedFeed.now_ms() - float(snapshot.get("startedAt", started_at))) / 1000.0)
  _timer.text = "%d:%02d" % [secs / 60, secs % 60] if secs >= 0 and secs < 36000 else ""
 if hosted or spectating:
  update_shared_board()
  return
 if board.is_empty():
  return
 if search >= 0 and WorkerThreadPool.is_task_completed(search):
  WorkerThreadPool.wait_for_task_completion(search)
  search = -1
  board = search_board
  redraw()
 if board.status == "playing" and SharedFeed.now_ms() - started_at >= float(Hall.LIMIT [board.kind]):
  Board.finish(board, "draw", null, "时间到了")
  redraw()
 if board.status != "playing":
  if not settled:
   settled = true
   var result:= "draw" if board.status == "draw" else "won" if board.get("winner") == "owner" or(board.status == "won" and board.kind not in DUO) else "lost"
   controls.transact("life_event", {"event": {"type": "arcade", "matchId": match_id, "kind": board.kind, "result": result}})
   local_feed.append({"kind": "system", "text": str(board.get("reason", "结束"))})
   redraw()
   _refresh_buttons()
  return
 elapsed += dt
 if elapsed < float(Hall.INTERVAL [board.kind]):
  return
 elapsed = 0.0
 if board.kind == "snake":
  var action:= Strategy.snake(board)
  if direction != "":
   action ["owner"] = direction
  turn(action)
 elif board.kind == "blocks":
  turn({})
 elif board.kind in ["xiangqi", "gomoku"] and search < 0 and board.sides [int(board.turn)] != "owner":
  search_board = board.duplicate(true)
  search = WorkerThreadPool.add_task(computer_move.bind(search_board))

func _tick_invitation() -> void:
 var invitation: Variant = VadsLink.arcade_view.get("invitation")
 if not invitation is Dictionary: return
 if _invite_row.get("inviteId") == invitation.get("id") and invitation.get("status") != "pending":
  _invite_row = {}
  _invite_card.hide()
 if active_invite_id == "" or invitation.get("id") != active_invite_id or mode != "wait": return
 var status:= str(invitation.get("status", ""))
 if status in ["declined", "expired", "cancelled"]:
  _end_wait(str(invitation.get("reason", "邀请已结束")))
 elif status == "accepted" and invite_state == "asking":
  invite_line = str(invitation.get("reply", ""))



  if match_id != "" or seat_requested:
   invite_state = "coming"
  else:
   _walk_to_invited_machine()

func _tick_invite_card() -> void:
 if _invite_row.is_empty() or not _invite_card.visible: return
 var left:= float(int(_invite_row.until) - Time.get_ticks_msec())
 var bar:= _invite_card.find_child("Bar", true, false) as ProgressBar
 if bar: bar.value = clampf(left / (float(_invite_row.get("seconds", 1)) * 1000.0), 0.0, 1.0)

 var now_sec:= int(ceil(maxf(left, 0.0) / 1000.0))
 if _invite_left != null and now_sec != _invite_left_sec:
  _invite_left_sec = now_sec
  _invite_left.text = ("还剩 %d 秒" % now_sec) if now_sec > 0 else "这就要过期了"
 if left <= 0:
  _invite_row = {}
  _invite_card.hide()


func _tick_wait_clock() -> void:
 if mode != "wait": return
 var invitation: Variant = VadsLink.arcade_view.get("invitation")
 var left:= invite_seconds_left(invitation if invitation is Dictionary else {}, SharedFeed.now_ms())
 if left == _wait_clock_sec: return
 _wait_clock_sec = left
 _refresh_wait()

func _tick_pending_join() -> void:
 if pending_join.is_empty(): return
 var p = controls.player
 if not p.player_enabled or p.want_scene != pending_join.scene:
  _end_wait("前往机台的路线已中断")
  return
 if p.scene_id == pending_join.scene and not p.is_walking():
  var row:= pending_join
  pending_join = {}
  start_shared(str(row.key), str(row.inviteId))

func update_shared_board() -> void:
 if spectating:
  snapshot = VadsLink.arcade_view.get("sessions", {}).get(cabinet, {})
  var g = snapshot.get("game")
  if g is Dictionary and g != board:
   board = g
   redraw()
   _refresh_buttons()
  _refresh_feed()
  return
 if match_id.is_empty():
  return
 var player = controls.player
 if waiting_for_seat != "" and mode == "wait" and player.want_zone != waiting_for_seat:
  _end_wait("前往座位的路线已中断")
  return
 if not ready_sent and waiting_for_seat != "":
  var zones: Dictionary = WorldData.scenes [player.scene_id].zones
  var now:= Time.get_ticks_msec()
  var settings: Dictionary = VadsLink.arcade_view.get("settings", {})
  var reach:= float(settings.get("seatArrivalPixels", 0))
  if zones.has(waiting_for_seat) and player.want_scene == player.scene_id and player.order_id == "" and not player.is_walking() and now >= seat_retry_at:
   if player.feet.distance_to(WorldData.point(zones [waiting_for_seat])) <= reach:
    seat_retry_at = now + 1000
    VadsLink.send({"type": "arcade.playerReady", "id": request, "matchId": match_id})
 var snap: Dictionary = VadsLink.arcade_view.get("sessions", {}).get(cabinet, {})
 if snap.get("matchId") != match_id:
  return
 var changed: bool = snap.get("feed", []).size() != snapshot.get("feed", []).size() or snap.get("minds", {}) != snapshot.get("minds", {}) or snap.get("status") != snapshot.get("status")
 var first: bool = snapshot.is_empty()
 snapshot = snap
 if first: _refresh_buttons()
 var latest = snap.get("game")
 if latest is Dictionary:
  if latest != board:
   var was: String = str(board.get("status", ""))
   board = latest
   if invite_state == "coming": invite_state = ""
   if mode == "wait": show_board()
   redraw()
   if was != str(board.get("status", "")): _refresh_buttons()
  elif changed:
   redraw()
  player.action_label = ("在玩" + Hall.NAMES [board.kind]) if board.status == "playing" else "对局结束"
 else:
  if changed: _redraw_all()
  if snap.get("status") != "waiting" and mode == "wait":
   _end_wait(str(snap.get("reason", "对局中断")))
  elif ready_sent:
   var invited:= str(snap.get("invited", ""))
   report.text = ("%s正在过来 · 可以先聊两句" % invited) if invited != "" else "等对手入座 · 可以随时离开"

func _exit_tree() -> void:
 if search >= 0:
  WorkerThreadPool.wait_for_task_completion(search)



func art_face(canvas: CanvasItem, who: String, r: Rect2, ring: Color, thinking: bool) -> void:
 canvas.draw_style_box(art_box(Hud.PAPER_D, ring, 3, 10), r.grow(3))
 var drawn:= false
 for c in characters():
  if is_instance_valid(c) and str(c.key) == who:
   var f: Dictionary = c.portrait_frame()
   if f.get("texture") != null:
    var fr: Array = f.rect
    var an: Array = f.anchor
    canvas.draw_texture_rect_region(f.texture, r, Rect2(float(fr [0]) + float(an [0]) - 92.5, float(fr [1]) + float(an [1]) - 278.0, 185, 185))
    drawn = true
   break
 if not drawn:
  var letter:= _name(who).left(1) if who != "" else "?"
  var px:= int(r.size.y * 0.5)
  var w:= _font.get_string_size(letter, HORIZONTAL_ALIGNMENT_LEFT, -1, px).x
  canvas.draw_string(_font, r.get_center() + Vector2(- w / 2.0, px * 0.36), letter, HORIZONTAL_ALIGNMENT_LEFT, -1, px, Hud.WOOD)
 if thinking:
  var at:= r.position + Vector2(r.size.x - 4, 2)
  canvas.draw_circle(at, 9, Hud.CREAM)
  canvas.draw_arc(at, 9, 0, TAU, 20, Hud.WOOD_L, 1.5)
  canvas.draw_circle(at + Vector2(-9, 10), 2.5, Hud.CREAM)
  var lit:= int(Time.get_ticks_msec() / 300) % 3
  for i in 3:
   canvas.draw_circle(at + Vector2(-4 + i * 4, 0), 1.6, Hud.WOOD if i == lit else Hud.PAPER_D)

class Face extends Control:
 var who:= ""
 var owner_ui
 func _draw() -> void:
  owner_ui.art_face(self, who, Rect2(Vector2(3, 3), size - Vector2(6, 6)), Hud.WOOD_L, false)


class Plate extends Control:
 var owner_ui
 var top:= false
 func _draw() -> void:
  var ui = owner_ui
  var ids: Array = ui.seats()
  var id: String = "" if ids.is_empty() else str(ids [0] if top else ids [-1])
  var shown: String = id if id != "" or not top else str(ui.invitee)
  if ids.is_empty() and not top and(ui.hosted or not ui.board.is_empty()): shown = Residents.PLAYER
  var active: bool = id != "" and ui.to_move() == id
  var box:= Rect2(Vector2(2, 2), size - Vector2(4, 4))
  if active:
   var glow:= 0.25 + 0.2 * sin(Time.get_ticks_msec() / 300.0)
   draw_style_box(ui.art_box(Color(Hud.GOLD, 0.0), Color(Hud.GOLD, glow), 3, 11), box.grow(2))
  draw_style_box(ui.art_box(Hud.CREAM if active else Hud.PAPER_H, Hud.GOLD if active else Hud.PAPER_D, 2, 9), box)
  var accent: Color = ui.side_color(shown)
  draw_rect(Rect2(box.position + Vector2(0, 8), Vector2(5, box.size.y - 16)), accent)
  if shown == "" and ui.board.is_empty(): return
  if active:
   var tag_text:= "走棋中" if ui.board.get("kind") in ["xiangqi", "gomoku"] else "进行中"
   var tw2: float = ui._font.get_string_size(tag_text, HORIZONTAL_ALIGNMENT_LEFT, -1, 12).x
   var tag:= Rect2(Vector2(size.x - tw2 - 26, 10), Vector2(tw2 + 16, 20))
   draw_style_box(ui.art_box(Hud.WOOD, Hud.WOOD_D, 1, 10), tag)
   draw_string(ui._font, tag.position + Vector2(8, 15), tag_text, HORIZONTAL_ALIGNMENT_LEFT, -1, 12, Hud.CREAM)
  var r:= Rect2(Vector2(16, 12), Vector2.ONE * (size.y - 24))
  var mind: Dictionary = ui.mind_of(shown)
  var thinking: bool = mind.get("thinking", false)
  ui.art_face(self, shown, r, Hud.GOLD if active else Hud.WOOD_L, thinking)
  var x:= r.end.x + 14
  var name_of: String = ui._name(shown) if shown != "" else "等待对手"
  draw_string(ui._font, Vector2(x, 34), name_of, HORIZONTAL_ALIGNMENT_LEFT, -1, 19, Hud.INK)
  var tag: String = ui.side_label(shown)
  if tag != "":
   var name_w: float = ui._font.get_string_size(name_of, HORIZONTAL_ALIGNMENT_LEFT, -1, 19).x
   var tw: float = ui._font.get_string_size(tag, HORIZONTAL_ALIGNMENT_LEFT, -1, 13).x
   var chip:= Rect2(Vector2(x + name_w + 10, 16), Vector2(tw + 14, 22))
   draw_style_box(ui.art_box(Hud.PAPER_D, Hud.PAPER_D, 0, 8), chip)
   draw_string(ui._font, chip.position + Vector2(7, 16), tag, HORIZONTAL_ALIGNMENT_LEFT, -1, 13, Hud.INK)
  var dots:= ".".repeat(1 + int(Time.get_ticks_msec() / 400) % 3)
  var line:= ""
  var color: Color = Hud.INK2
  if thinking:
   var secs:= int((SharedFeed.now_ms() - float(mind.get("since", SharedFeed.now_ms()))) / 1000.0)
   line = "在想" + dots + ("  %ds" % secs if secs > 2 and secs < 600 else "")
   color = Hud.WOOD
  elif top and ui.invite_state == "asking":
   line = "在想要不要来" + dots
  elif top and ui.invite_state == "coming" and ui.board.is_empty():
   line = "正在赶来" + dots
  elif str(mind.get("thought", "")) != "":
   line = "“" + str(mind.thought) + "”"
  elif str(mind.get("plan", "")) != "":
   line = "打法：" + str(mind.plan)
  elif active:
   line = "轮到你了" if shown == Residents.PLAYER else "轮到她了"
   color = Hud.WOOD
  draw_string(ui._font, Vector2(x, 64), line, HORIZONTAL_ALIGNMENT_LEFT, maxf(40.0, size.x - x - 10), 14, color)


class Banner extends Control:
 var owner_ui
 func _draw() -> void:
  var ui = owner_ui
  var b: Dictionary = ui.board
  var title:= ""
  var sub:= ""
  var lesson:= ""
  if ui.invite_state == "declined":
   title = "%s这次没来" % ui._name(ui.invitee)
   sub = ui.invite_line
  elif b.is_empty():
   if ui.invite_state == "asking": title = "等%s回话…" % ui._name(ui.invitee)
   elif ui.invite_state == "coming": title = "%s答应了" % ui._name(ui.invitee)
   elif ui.hosted: title = "等对手入座"
   if title == "": return
   sub = ui.invite_line if ui.invite_line != "" else ui.report.text
  elif b.get("status") != "playing":
   var me:= Residents.PLAYER
   var w:= str(b.get("winner", ""))
   if b.status == "draw": title = "平局"
   elif ui.spectating or not(me in ui.seats()): title = ("%s 赢了" % ui._name(w)) if w != "" and w != "<null>" else "结束"
   elif w == me or(b.status == "won" and b.kind not in ["snake", "xiangqi", "gomoku"]): title = "你赢了！"
   else: title = "这局输了"
   sub = str(b.get("reason", ""))
   for r in ui.feed_rows():
    if r.get("kind") == "lesson": lesson = "%s记下了：%s" % [r.get("name", ""), r.get("text", "")]
  else:
   return
  var won: bool = title == "你赢了！"
  var card:= Rect2(Vector2(size.x * 0.06, size.y * 0.3), Vector2(size.x * 0.88, size.y * (0.38 if lesson != "" else 0.28)))
  draw_rect(Rect2(Vector2.ZERO, size), Color(0.1, 0.07, 0.05, 0.38))
  if won:
   var t:= Time.get_ticks_msec() / 1000.0
   for i in 46:
    var x:= fmod(float(i * 97 % 101) / 101.0 * size.x + sin(t * 1.3 + i) * 12.0, size.x)
    var y:= fmod(float(i * 53 % 89) / 89.0 * size.y + t * (40.0 + i % 5 * 14.0), size.y)
    draw_rect(Rect2(Vector2(x, y), Vector2(5, 3 + i % 3)), [Hud.GOLD, Hud.PINK, Hud.GREEN, Hud.CREAM] [i % 4])
  draw_style_box(ui.art_box(Hud.PAPER, Hud.WOOD_D, 4, 12), card)
  var ribbon:= Rect2(card.position + Vector2(-12, 14), Vector2(card.size.x + 24, 52))
  draw_style_box(ui.art_box(Hud.WOOD if not won else Color("b8862f"), Hud.WOOD_D, 3, 6), ribbon)
  var f: Font = ui._font
  var tw:= f.get_string_size(title, HORIZONTAL_ALIGNMENT_LEFT, -1, 30).x
  var at:= Vector2(card.get_center().x - tw / 2.0, ribbon.position.y + 38)
  draw_string_outline(f, at, title, HORIZONTAL_ALIGNMENT_LEFT, -1, 30, 6, Hud.WOOD_D)
  draw_string(f, at, title, HORIZONTAL_ALIGNMENT_LEFT, -1, 30, Hud.CREAM)
  card.position.y += 24
  if sub != "":
   var sw:= minf(card.size.x - 30, f.get_string_size(sub, HORIZONTAL_ALIGNMENT_LEFT, -1, 16).x)
   draw_string(f, Vector2(card.get_center().x - sw / 2.0, card.position.y + 84), sub, HORIZONTAL_ALIGNMENT_LEFT, card.size.x - 30, 16, Hud.INK2)
  if lesson != "":
   draw_multiline_string(f, Vector2(card.position.x + 18, card.position.y + 118), lesson, HORIZONTAL_ALIGNMENT_LEFT, card.size.x - 36, 14, 3, Hud.WOOD)
