extends Node
























const EDGE_BAND:= 28.0
const EDGE_SPEED:= 680.0
const DRAG_START:= 4.0
const OBSERVER_SPEED:= 900.0
const PLAYER_WALK:= 120.0
const PLAYER_RUN:= 184.0
const ENTRY_KEY:= KEY_T
const ENTRY_SIZE:= Vector2(224, 58)
const ENTRY_MARGIN:= Vector2(10, 10)

var host
var active:= false
var dragging:= false

var _press:= Vector2.ZERO
var _last:= Vector2.ZERO
var _moved:= false
var _pan:= Vector2.ZERO
var _scene:= ""
var _held:= {}
var _dir:= Vector2.ZERO

var _layer: CanvasLayer
var _entry: Control
var _font: SystemFont
var _small: SystemFont






class ObserverEntry extends Control:
 var view
 func _draw() -> void:
  if view != null:
   view.draw_entry(self)
 func _gui_input(event: InputEvent) -> void:
  if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
   accept_event()
   if view != null:
    view.toggle_world()


func setup(main: Control) -> void:
 host = main
 _make_entry()
 sync()



func sync() -> void:
 var want: bool = host != null and bool(host.get("observing"))
 if want == active:
  return
 active = want
 _pan = Vector2.ZERO
 _scene = ""
 dragging = false
 _moved = false
 _held.clear()
 _dir = Vector2.ZERO
 if is_instance_valid(_entry):
  _entry.visible = active
  _entry.queue_redraw()





static func visible_center(pan: Vector2, room: Vector2, half: Vector2) -> Vector2:
 var c:= room * 0.5 + pan
 for axis in 2:
  if half [axis] * 2.0 >= room [axis]:
   c [axis] = room [axis] * 0.5
  else:
   c [axis] = clampf(c [axis], half [axis], room [axis] - half [axis])
 return c



static func stage_offset(center: Vector2, view_size: Vector2, s: float) -> Vector2:
 return view_size * 0.5 - center * s



static func village_center(target: Vector2, bounds: Rect2, half: Vector2) -> Vector2:
 var c:= target
 for axis in 2:
  if half [axis] * 2.0 >= bounds.size [axis]:
   c [axis] = bounds.position [axis] + bounds.size [axis] * 0.5
  else:
   c [axis] = clampf(c [axis], bounds.position [axis] + half [axis], bounds.end [axis] - half [axis])
 return c




func _process(dt: float) -> void:
 sync()
 if not active:
  return
 if not _place_entry() or _editing():
  if is_instance_valid(_entry):
   _entry.visible = false
  return
 _entry.visible = true
 _entry.queue_redraw()
 _dir = _dir_now()
 if _village():
  _lock_follow_pan()
  _edge_scroll(dt)
  if _dir != Vector2.ZERO and not dragging:
   pan_world(_dir * OBSERVER_SPEED * dt)
  _clamp_village()
  return
 if host.view_scene != _scene:
  _scene = str(host.view_scene)
  _pan = Vector2.ZERO
 _edge_scroll(dt)
 if _dir != Vector2.ZERO and not dragging:
  pan_world(_dir * OBSERVER_SPEED * dt)
 apply_room()



func apply_room() -> void:
 if not is_instance_valid(host) or not is_instance_valid(host._view) or not is_instance_valid(host._stage):
  return
 var view: Control = host._view
 var stage: Node2D = host._stage
 var s: float = stage.scale.x
 if s <= 0.0 or view.size.x <= 0.0 or view.size.y <= 0.0:
  return
 var room: Vector2 = view.size / s
 var half: Vector2 = view.size / (2.0 * s)
 stage.position = stage_offset(visible_center(_pan, room, half), view.size, s)


func _village() -> bool:
 var qx = host.get("qingxi_host") if is_instance_valid(host) else null
 return qx != null and bool(qx.spectator) and bool(qx.active)


func _editing() -> bool:
 if is_instance_valid(host.get("_home_editor")) or is_instance_valid(host.get("_map_editor")):
  return true
 var settings = host.get("_settings")
 return is_instance_valid(settings) and settings.visible


func _frame() -> Rect2:
 var hud = host.get("_hud")
 return hud.frame_rect if is_instance_valid(hud) else Rect2()




func _make_entry() -> void:
 _font = SystemFont.new()
 _font.font_names = PackedStringArray(["Microsoft YaHei UI", "Microsoft YaHei", "SimHei"])
 _small = SystemFont.new()
 _small.font_names = _font.font_names
 _layer = CanvasLayer.new()



 _layer.layer = 18
 add_child(_layer)
 _entry = ObserverEntry.new()
 _entry.view = self
 _entry.visible = false
 _entry.size = ENTRY_SIZE
 _entry.mouse_filter = Control.MOUSE_FILTER_STOP
 _layer.add_child(_entry)


func _place_entry() -> bool:
 if not is_instance_valid(_entry):
  return false
 var frame:= _frame()
 if frame.size.x <= 0.0 or frame.size.y <= 0.0:
  return false
 var pos:= frame.position + ENTRY_MARGIN
 pos.x = maxf(pos.x, frame.position.x + 4.0)
 pos.y = maxf(pos.y, frame.position.y + 4.0)
 pos.x = minf(pos.x, frame.end.x - ENTRY_SIZE.x - 4.0)
 pos.y = minf(pos.y, frame.end.y - ENTRY_SIZE.y - 4.0)
 _entry.position = pos.round()
 return true



func entry_rect() -> Rect2:
 if not is_instance_valid(_entry):
  return Rect2()
 return Rect2(_entry.position, _entry.size)


func entry_visible() -> bool:
 return is_instance_valid(_entry) and _entry.visible



func entry_title() -> String:
 if _village():
  return "回小屋世界  T"
 if not _can_cross():
  return "清溪村不在这个包里"
 return "去清溪村  T"


func entry_hint() -> String:
 var who:= ""
 if host != null and int(host.follow) >= 0 and int(host.follow) < host.characters.size():
  var c = host.characters [int(host.follow)]
  if c != null:
   who = str(c.display_name)
 if who != "":
  return "跟随 %s · Esc 解锁" % who
 if _village():
  return "拖拽平移 · 比走路快 7.5 倍"
 return "自由镜头 · 拖拽平移"


func _can_cross() -> bool:
 var qx = host.get("qingxi_host") if is_instance_valid(host) else null
 return qx != null and ResourceLoader.exists("res://qingxi-live/village-center/main.tscn")



func toggle_world() -> void:
 if not active or _editing():
  return
 var qx = host.get("qingxi_host") if is_instance_valid(host) else null
 if qx == null:
  return
 if bool(qx.spectator) and bool(qx.active):
  host.observer_leave_village()
 else:
  host.observer_enter_village()


func draw_entry(c: Control) -> void:
 var r:= Rect2(Vector2.ZERO, c.size)
 c.draw_rect(r, Color(0.09, 0.11, 0.17, 0.88))
 c.draw_rect(Rect2(Vector2(0.5, 0.5), c.size - Vector2(1.0, 1.0)), Color(0.98, 0.86, 0.62, 0.85), false, 1.5)
 c.draw_string(_font, Vector2(12, 25), entry_title(), HORIZONTAL_ALIGNMENT_LEFT, -1.0, 17, Color(1.0, 0.96, 0.86))
 c.draw_string(_small, Vector2(12, 46), entry_hint(), HORIZONTAL_ALIGNMENT_LEFT, c.size.x - 20.0, 12, Color(0.8, 0.84, 0.9))







func _input(event: InputEvent) -> void:
 if not active or _editing():
  return
 var frame:= _frame()
 if frame.size.x <= 0.0:
  return
 if event is InputEventMouseButton and event.button_index in [MOUSE_BUTTON_LEFT, MOUSE_BUTTON_MIDDLE]:
  if _over_entry(event.position):
   return
  if event.pressed:
   if not frame.has_point(event.position):
    return
   dragging = true
   _moved = false
   _press = event.position
   _last = event.position
  elif dragging:
   dragging = false
   if _moved:
    get_viewport().set_input_as_handled()
   _moved = false
 elif event is InputEventMouseMotion and dragging:
  var moved: Vector2 = event.position - _last
  _last = event.position
  if not _moved and event.position.distance_to(_press) < DRAG_START:
   return
  if not _moved:
   release_follow()
  _moved = true
  pan_screen(- moved)
  get_viewport().set_input_as_handled()
 elif event is InputEventKey:
  _key(event)


func _over_entry(at: Vector2) -> bool:
 return entry_visible() and entry_rect().has_point(at)


func _key(event: InputEventKey) -> void:

 if get_viewport().gui_get_focus_owner() != null:
  return
 var code:= event.physical_keycode
 if code == ENTRY_KEY:
  if event.pressed and not event.echo:
   get_viewport().set_input_as_handled()
   toggle_world()
  return
 if code == KEY_ESCAPE:
  if event.pressed and not event.echo:
   _held.clear()
   _dir = Vector2.ZERO
   release_follow()
   get_viewport().set_input_as_handled()
  return
 if not _is_move_key(code):
  return
 if event.pressed:
  _held [code] = true
 else:
  _held.erase(code)
 get_viewport().set_input_as_handled()


func _is_move_key(code: int) -> bool:
 return code in [KEY_LEFT, KEY_RIGHT, KEY_UP, KEY_DOWN, KEY_A, KEY_D, KEY_W, KEY_S]


func _dir_now() -> Vector2:
 var d:= Vector2.ZERO
 if _held.has(KEY_LEFT) or _held.has(KEY_A):
  d.x -= 1.0
 if _held.has(KEY_RIGHT) or _held.has(KEY_D):
  d.x += 1.0
 if _held.has(KEY_UP) or _held.has(KEY_W):
  d.y -= 1.0
 if _held.has(KEY_DOWN) or _held.has(KEY_S):
  d.y += 1.0
 return d.normalized()



func pan_screen(delta_screen: Vector2) -> void:
 if _village():
  host.qingxi_host.observe_pan(delta_screen)
  _clamp_village()
  return
 var s: float = host._stage.scale.x if is_instance_valid(host.get("_stage")) else 1.0
 if s <= 0.0:
  return
 _pan -= delta_screen / s



func pan_world(delta_world: Vector2) -> void:
 if _village():


  host.qingxi_host.observe_pan(- delta_world * float(host.qingxi_host.scale_k))
  _clamp_village()
  return
 _pan += delta_world




func _lock_follow_pan() -> void:
 if host == null or int(host.follow) < 0:
  return
 var qx = host.get("qingxi_host")
 if qx != null and bool(qx.spectator):
  qx.spectator_pan = Vector2.ZERO



func _clamp_village() -> void:
 var qx = host.get("qingxi_host") if is_instance_valid(host) else null
 if qx == null or not bool(qx.spectator) or not is_instance_valid(qx.scene):
  return
 var cam = qx.scene.get("camera")
 if not(cam is Camera2D):
  return
 var bounds: Rect2 = qx.scene.world_bounds() if qx.scene.has_method("world_bounds") else Rect2(Vector2.ZERO, Vector2(1280, 900))
 var extent:= Vector2(qx.view.size_2d_override)
 if extent.x <= 0.0 or extent.y <= 0.0:
  extent = Vector2(qx.view.size)
 var half: Vector2 = extent / cam.zoom * 0.5
 var base: Vector2 = qx._spectator_point()
 var center:= village_center(base + qx.spectator_pan, bounds, half)
 qx.spectator_pan = center - base






func release_follow() -> void:
 var qx = host.get("qingxi_host") if is_instance_valid(host) else null
 if qx != null and bool(qx.spectator) and bool(qx.active) and is_instance_valid(qx.scene):
  var cam = qx.scene.get("camera")
  if cam is Camera2D:
   var bounds: Rect2 = qx.scene.world_bounds() if qx.scene.has_method("world_bounds") else Rect2(Vector2.ZERO, Vector2(1280, 900))
   var extent:= Vector2(qx.view.size_2d_override)
   if extent.x <= 0.0 or extent.y <= 0.0:
    extent = Vector2(qx.view.size)
   var half: Vector2 = extent / cam.zoom * 0.5
   var here: Vector2 = village_center(qx._spectator_point() + qx.spectator_pan, bounds, half)
   qx.observe_release()
   if qx.scene.get("player") is Node2D:

    qx.spectator_pan = here - qx.scene.player.position
   _clamp_village()
   return
 _pan = Vector2.ZERO

 if host != null and int(host.follow) >= 0:
  host.follow = -1
  var hud = host.get("_hud")
  if is_instance_valid(hud):
   hud.follow = -1
   hud.queue_redraw()


func _edge_scroll(dt: float) -> void:
 if dragging:
  return
 var frame:= _frame()
 var mouse: Vector2 = host.get_viewport().get_mouse_position()
 if not frame.has_point(mouse):
  return
 var dir:= Vector2.ZERO
 if mouse.x - frame.position.x < EDGE_BAND:
  dir.x -= 1.0
 elif frame.end.x - mouse.x < EDGE_BAND:
  dir.x += 1.0
 if mouse.y - frame.position.y < EDGE_BAND:
  dir.y -= 1.0
 elif frame.end.y - mouse.y < EDGE_BAND:
  dir.y += 1.0
 if dir == Vector2.ZERO:
  return

 pan_screen(- dir.normalized() * EDGE_SPEED * dt)
