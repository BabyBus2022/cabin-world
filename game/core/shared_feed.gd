extends Node
## Where the game hears about the world. While VADS is connected, data comes over the link.
## Otherwise it reads the last state from shared.json, read-only, so the world still shows with VADS closed.
## VADS replaces that file by renaming over it, which fails on Windows while a reader has it open,
## so the file is only opened shortly after it changes, and not at all while connected.

signal presence_changed(presence: Dictionary)

const POLL := 0.3
const AFTER_CHANGE := 1.5 # modified times only have one-second resolution

var data_dir := ""
var found := false
var linked := false
var newest_at := 0.0
var reads := 0
var received := 0
## The latest rows and weather from VADS, for whoever draws them.
var presence_now := {}
var weather = null
var local_weather = null
var clock_synced := false
## How far VADS's time is from this computer's. All game time goes through now_ms.
var _clock_offset := 0.0

var _file := ""
var _stamp := 0
var _elapsed := 0.0
var _hot_until := 0.0
var _clock := 0.0


func _ready() -> void:
	data_dir = _find_data_dir()
	_file = data_dir.path_join("world").path_join("shared.json")
	poll()


func _find_data_dir() -> String:
	var directory := OS.get_executable_path().get_base_dir()
	var ini := directory.path_join("cabinworld.ini")
	var text := FileAccess.get_file_as_string(ini) if FileAccess.file_exists(ini) else ""
	return InstallPaths.resolve_data(OS.get_cmdline_user_args(), OS.get_environment("CABINWORLD_DATA"), directory, text)


func _process(delta: float) -> void:
	_clock += delta
	_elapsed += delta
	if _elapsed >= POLL:
		_elapsed = 0.0
		poll()


func poll() -> void:
	if linked:
		return
	if not FileAccess.file_exists(_file):
		found = false
		return
	var stamp := FileAccess.get_modified_time(_file)
	if stamp != _stamp:
		_stamp = stamp
		_hot_until = _clock + AFTER_CHANGE
	elif found and _clock > _hot_until:
		return
	var text := FileAccess.get_file_as_string(_file)
	reads += 1
	if text == "":
		return # it was being replaced; try again next poll
	var parsed = JSON.parse_string(text)
	if not parsed is Dictionary:
		return # keep the last good state
	found = true
	_publish(parsed.get("presence", {}))


func set_link(on: bool) -> void:
	linked = on
	if on:
		found = true


func receive(presence: Dictionary) -> void:
	received += 1
	found = true
	_publish(presence)


func _publish(presence: Dictionary) -> void:
	for row in presence.values():
		newest_at = maxf(newest_at, float(row.get("at", 0)))
	presence_now = presence
	presence_changed.emit(presence)


## INTERFACE: clock message from the host: now (required, ms since 1970). Before the first one, it's this computer's time.
func set_clock(vads_now: float) -> void:
	clock_synced = true
	_clock_offset = vads_now - Time.get_unix_time_from_system() * 1000.0


func now_ms() -> float:
	return Time.get_unix_time_from_system() * 1000.0 + _clock_offset


func is_live() -> bool:
	return linked
