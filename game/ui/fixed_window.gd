class_name FixedWindow
extends Node
## One logical canvas. Normal window edge drags preserve 16:9; maximized windows letterbox.
const BASE := Vector2i(1920, 1080)
const MINIMUM := Vector2i(960, 540)
var previous := Vector2i.ZERO
var pending := false
var requested := Vector2i(1280,720)

static func fitted(raw: Vector2i, before: Vector2i) -> Vector2i:
	var width_driven := absf(raw.x - before.x) / BASE.x >= absf(raw.y - before.y) / BASE.y
	var k := maxf(0.5, float(raw.x) / BASE.x if width_driven else float(raw.y) / BASE.y)
	return Vector2i(roundi(BASE.x * k), roundi(BASE.y * k))

func _ready() -> void:
	var window := get_window()
	window.min_size = MINIMUM
	previous = window.size
	window.size_changed.connect(_changed)
	var config := ConfigFile.new()
	if config.load(preferences_path()) == OK:
		var value = config.get_value("display","size",requested)
		if value is Vector2i and value.x >= MINIMUM.x and value.y >= MINIMUM.y:
			apply_display(fitted(value,Vector2i.ZERO), config.get_value("display","fullscreen",false) == true, false)

func preferences_path() -> String:
	return Economy.save_path.get_base_dir().path_join("display.cfg")

func apply_display(resolution: Vector2i, fullscreen: bool, persist := true) -> Error:
	requested = fitted(resolution,Vector2i.ZERO)
	var window := get_window()
	pending = true
	if fullscreen:
		window.mode = Window.MODE_FULLSCREEN
	else:
		window.mode = Window.MODE_WINDOWED
		var target := requested
		var usable := DisplayServer.screen_get_usable_rect(window.current_screen)
		if usable.size.x > 0 and usable.size.y > 40:
			var k := minf(1.0,minf(float(usable.size.x)/target.x,float(usable.size.y-40)/target.y))
			target = Vector2i(Vector2(target)*k)
		window.size = target
		previous = target
		if usable.size.x > 0: window.position = usable.position+(usable.size-target)/2
	pending = false
	if not persist: return OK
	var config := ConfigFile.new()
	config.set_value("display","size",requested)
	config.set_value("display","fullscreen",fullscreen)
	return config.save(preferences_path())


func _changed() -> void:
	if pending or get_window().mode != Window.MODE_WINDOWED: return
	pending = true
	_fix.call_deferred()

func _fix() -> void:
	var window := get_window()
	if window.mode == Window.MODE_WINDOWED:
		var target := fitted(window.size, previous)
		var usable := DisplayServer.screen_get_usable_rect(window.current_screen).size
		if usable.x > 0 and usable.y > 40:
			var k := minf(1.0, minf(float(usable.x) / target.x, float(usable.y - 40) / target.y))
			target = Vector2i(Vector2(target) * k)
		previous = target
		if window.size != target: window.size = target
	pending = false
