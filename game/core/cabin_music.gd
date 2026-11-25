class_name CabinMusic
extends Node




















const RULES_PATH:= "res://assets/music-rules.json"
const GROUP:= "cabin_music"
const MUTE_DB:= -60.0
const START_DB:= -40.0
const RETURN_GUARD:= 0.15
const NIGHT_RECHECK_MS:= 500.0

var main: Node
var scenes: Dictionary = {}
var base:= "res://qingxi-live/village-center/audio/music/"
var default_db:= -14.0
var fade_scene:= 1.4
var fade_tod:= 3.0
var fade_mute:= 0.8
var fade_board:= 1.2

var players: Array [AudioStreamPlayer] = []
var current:= 0
var track:= ""
var target_db:= -14.0
var pitch:= 1.0
var fade:= 1.4
var enabled:= true
var volume:= 80

var _streams: Dictionary = {}
var _room_light: GDScript
var _daylight: GDScript
var _night:= false
var _night_checked_ms:= 0.0
var _was_in_village:= false
var _homecoming:= false
var _return_guard:= 0.0


func setup(game: Node) -> void:
 main = game
 name = "CabinMusic"
 add_to_group(GROUP)
 _room_light = load("res://entities/room_light.gd")
 _daylight = load("res://core/daylight.gd")
 _load_rules()
 var config:= read_config()
 enabled = bool(config.get("enabled", true))
 volume = int(config.get("volume", 80))
 for i in 2:
  var p:= AudioStreamPlayer.new()
  p.name = "Music%d" % i
  p.volume_db = MUTE_DB
  add_child(p)
  players.append(p)



func _load_rules() -> void:
 scenes = {}
 if not FileAccess.file_exists(RULES_PATH):
  push_warning("CabinMusic: no " + RULES_PATH)
  return
 var data = JSON.parse_string(FileAccess.get_file_as_string(RULES_PATH))
 if not data is Dictionary:
  push_warning("CabinMusic: cannot parse " + RULES_PATH)
  return
 base = str(data.get("base", base))
 default_db = float(data.get("defaultDb", default_db))
 if data.get("scenes") is Dictionary:
  scenes = data ["scenes"]
 var fades = data.get("fade")
 if fades is Dictionary:
  fade_scene = float(fades.get("scene", fade_scene))
  fade_tod = float(fades.get("timeOfDay", fade_tod))
  fade_mute = float(fades.get("mute", fade_mute))
  fade_board = float(fades.get("board", fade_board))



func rule_for(scene_id: String, night: bool) -> Dictionary:
 var entry = scenes.get(scene_id)
 if not entry is Dictionary:
  return {}
 if entry.get("day") is Dictionary or entry.get("night") is Dictionary:
  var rule = entry.get("night" if night else "day")
  if rule is Dictionary:
   return rule
 if entry.get("default") is Dictionary:
  return entry ["default"]
 return {}


func has_day_night(scene_id: String) -> bool:
 var entry = scenes.get(scene_id)
 return entry is Dictionary and(entry.get("day") is Dictionary or entry.get("night") is Dictionary)


func is_night() -> bool:
 var now:= float(_room_light.call("now_ms"))
 if _night_checked_ms > 0.0 and absf(now - _night_checked_ms) < NIGHT_RECHECK_MS:
  return _night
 _night_checked_ms = now
 _night = str(_daylight.call("reading", now).get("phase", "")) == "night"
 return _night



func stream_for(track_name: String) -> AudioStream:
 if track_name == "":
  return null
 if _streams.has(track_name):
  return _streams [track_name]
 var path:= base + track_name
 var s: AudioStream = null
 if FileAccess.file_exists(path + ".ogg"):
  s = AudioStreamOggVorbis.load_from_file(path + ".ogg")
  if s != null:
   (s as AudioStreamOggVorbis).loop = true
 elif FileAccess.file_exists(path + ".wav"):
  s = AudioStreamWAV.load_from_file(path + ".wav")
  if s != null:
   var wav:= s as AudioStreamWAV
   var frame_bytes:= (2 if wav.format == AudioStreamWAV.FORMAT_16_BITS else 1) * (2 if wav.stereo else 1)
   wav.loop_mode = AudioStreamWAV.LOOP_FORWARD
   wav.loop_begin = 0
   wav.loop_end = wav.data.size() / frame_bytes
 if s == null:
  return null
 _streams [track_name] = s
 return s



func config_path() -> String:
 var save:= "user://economy.json"
 var economy:= get_node_or_null("/root/Economy")
 if economy != null:
  save = str(economy.get("save_path"))
 return save.get_base_dir().path_join("music.cfg")


func read_config() -> Dictionary:
 var out:= {"enabled": true, "volume": 80}
 var config:= ConfigFile.new()
 if config.load(config_path()) != OK:
  return out
 out ["enabled"] = bool(config.get_value("music", "enabled", true))
 out ["volume"] = clampi(int(config.get_value("music", "volume", 80)), 0, 100)
 return out


func write_config(on: bool, level: int) -> bool:
 var path:= config_path()
 var config:= ConfigFile.new()
 config.set_value("music", "enabled", on)
 config.set_value("music", "volume", clampi(level, 0, 100))
 if config.save(path + ".tmp") != OK:
  return false
 return DirAccess.rename_absolute(path + ".tmp", path) == OK


func set_enabled(on: bool, persist:= true) -> void:
 enabled = on
 if persist:
  write_config(enabled, volume)
 if not enabled:
  _silence(fade_mute)
 else:
  _refresh()


func set_volume(level: int, persist:= true) -> void:
 volume = clampi(level, 0, 100)
 if persist:
  write_config(enabled, volume)
 if volume <= 0 or not enabled:
  _silence(fade_mute)
 elif track != "":
  _retune()
 else:
  _refresh()



func _process(delta: float) -> void:
 if main == null or not is_instance_valid(main):
  return
 var host = main.get("qingxi_host")
 var in_village: bool = host != null and bool(host.active)
 var transit: bool = host != null and bool(host.transit)

 if in_village:
  _was_in_village = true
  _homecoming = false
  if _any_playing():
   _stop_now()
  return
 if _was_in_village:

  _was_in_village = false
  _homecoming = true
  _stop_now()
  _return_guard = RETURN_GUARD
  return
 if _return_guard > 0.0:
  _return_guard = maxf(0.0, _return_guard - delta)
  return
 if not transit:
  _homecoming = false
 if transit and not _homecoming:

  if track != "":
   _silence(fade_board)
  return
 _refresh()


func _refresh() -> void:
 if not enabled or volume <= 0:
  if track != "":
   _silence(fade_mute)
  return
 var scene_id:= str(main.view_scene)
 var night:= is_night() if has_day_night(scene_id) else false
 var rule:= rule_for(scene_id, night)
 var raw_track = rule.get("track", null)
 if raw_track == null:
  if track != "":
   _silence(fade_scene)
  return
 var want:= str(raw_track)
 if want == "":
  if track != "":
   _silence(fade_scene)
  return
 var want_db:= float(rule.get("db", default_db))
 var want_pitch:= float(rule.get("pitch", 1.0))
 var want_fade:= float(rule.get("fade", fade_scene))
 if want == track and is_equal_approx(want_pitch, pitch):
  target_db = want_db
  _retune()
  return
 _crossfade(want, want_db, want_pitch, want_fade)


func _effective_db(level: float) -> float:
 return level + linear_to_db(clampf(float(volume) / 100.0, 0.0, 1.0))



func _crossfade(want: String, db: float, pitch_value: float, seconds: float) -> void:
 var stream:= stream_for(want)
 if stream == null:
  push_warning("CabinMusic: cannot load track " + want)
  _stop_now()
  return
 if seconds <= 0.0:
  seconds = 0.05
 var old:= players [current]
 current = 1 - current
 var nxt:= players [current]
 if old.playing:
  _fade_player(old, MUTE_DB, seconds, true)
 if nxt.playing:
  _stop_player(nxt)
 nxt.stream = stream
 nxt.pitch_scale = pitch_value
 nxt.volume_db = START_DB
 nxt.play()
 track = want
 target_db = db
 pitch = pitch_value
 fade = seconds
 _fade_player(nxt, _effective_db(db), seconds)


func _retune() -> void:
 var p:= players [current]
 if track == "" or not p.playing:
  return
 _kill_fade(p)
 p.volume_db = _effective_db(target_db)


func _silence(seconds: float) -> void:
 track = ""
 for p in players:
  if not p.playing:
   continue
  if seconds <= 0.01:
   _stop_player(p)
  else:
   _fade_player(p, MUTE_DB, seconds, true)


func _stop_now() -> void:
 track = ""
 for p in players:
  _stop_player(p)


func _stop_player(p: AudioStreamPlayer) -> void:
 _kill_fade(p)
 p.volume_db = MUTE_DB
 if p.playing:
  p.stop()


func _fade_player(p: AudioStreamPlayer, to_db: float, seconds: float, stop_after:= false) -> void:
 _kill_fade(p)
 var tw:= create_tween()
 p.set_meta("cabin_music_fade", tw)
 tw.tween_property(p, "volume_db", to_db, maxf(seconds, 0.01))
 if stop_after:
  tw.tween_callback(p.stop)


func _kill_fade(p: AudioStreamPlayer) -> void:
 if not p.has_meta("cabin_music_fade"):
  return
 var tw = p.get_meta("cabin_music_fade")
 if tw is Tween and(tw as Tween).is_valid():
  (tw as Tween).kill()


func _any_playing() -> bool:
 for p in players:
  if p.playing:
   return true
 return false



func status() -> Dictionary:
 var db_list: Array = []
 var playing_list: Array = []
 for p in players:
  db_list.append(p.volume_db)
  playing_list.append(p.playing)
 return {
  "track": track,
  "target_db": target_db,
  "pitch": pitch,
  "fade": fade,
  "enabled": enabled,
  "volume": volume,
  "playing": _any_playing(),
  "player_playing": playing_list,
  "player_db": db_list,
  "current": current,
  "scene": str(main.view_scene) if is_instance_valid(main) else "",
 }
