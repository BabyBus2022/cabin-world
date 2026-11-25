extends Node
## Sound for 清溪村. Music per place with crossfades (free pastoral tracks in audio/music/,
## credited in village-center/README.md), ambience by time of day, footsteps by surface,
## UI and action effects (synthesized by tools/bake_audio.py). Loaded at runtime from
## OGG/WAV so no editor import is needed.
const DIR="res://qingxi-live/village-center/audio/"
const MUSIC={"village":"music/meadow-quiet","field":"music/farm","ranch":"music/meadow-quiet","pond":"music/pond",
 "seedshop":"music/shop","livestockshop":"music/shop","barn":"music/meadow-quiet"}
const MUSIC_DB=-14.0
const AMB_DB=-16.0
var cache={}
var music=[]
var amb=[]
var water:AudioStreamPlayer
var current=0
var music_name=""
var village_center := false
var target_music_db := -60.0
var village_mix:Dictionary=JSON.parse_string(FileAccess.get_file_as_string("res://qingxi-live/village-center/village-mix.json"))
var base_music=""
var festival=false
var paused_by_host=false
var amb_name=""
var pool=[]
var next_voice=0
var muted=false
func _ready():
 for i in 2:
  var m=AudioStreamPlayer.new();m.volume_db=-60;add_child(m);music.append(m)
  var a=AudioStreamPlayer.new();a.volume_db=-60;add_child(a);amb.append(a)
 water=AudioStreamPlayer.new();water.volume_db=-60;add_child(water)
 for i in 10:
  var s=AudioStreamPlayer.new();add_child(s);pool.append(s)
func _process(_dt:float):
 var host=get_tree().get_meta("qingxi_world_host",false)
 var pause=bool(host and not host.audible_scene(get_parent()))
 if pause==paused_by_host:return
 paused_by_host=pause
 for player in music+amb+pool+[water]:player.stream_paused=pause
 if pond_water!=null:pond_water.stream_paused=pause

func stream(name:String,looped:=false)->AudioStream:
 if cache.has(name):return cache[name]
 var s=null
 var ogg=DIR+name+".ogg"
 var wav=DIR+name+".wav"
 if FileAccess.file_exists(ogg):
  s=AudioStreamOggVorbis.load_from_file(ogg)
  if s!=null:s.loop=looped
 elif FileAccess.file_exists(wav):
  s=AudioStreamWAV.load_from_file(wav)
  if s!=null and looped:
   var frame_bytes=(2 if s.format==AudioStreamWAV.FORMAT_16_BITS else 1)*(2 if s.stereo else 1)
   s.loop_mode=AudioStreamWAV.LOOP_FORWARD;s.loop_begin=0;s.loop_end=s.data.size()/frame_bytes
 if s==null:return null
 cache[name]=s;return s
func fade(player:AudioStreamPlayer,to_db:float,seconds:float,stop_after:=false):
 var t=create_tween();t.tween_property(player,"volume_db",to_db,seconds)
 if stop_after:t.tween_callback(player.stop)
func play_music(name:String):
 var level:float=-17.0 if name=="music/meadow-quiet" else MUSIC_DB
 if village_center:level=village_mix.get(name,level)
 if name==music_name:
  if target_music_db!=level:fade(music[current],level,1.6)
  target_music_db=level
  return
 target_music_db=level
 music_name=name
 var old=music[current];current=1-current;var nxt=music[current]
 fade(old,-60,1.6,true)
 var s=stream(name,true)
 if s==null:return
 nxt.stream=s;nxt.volume_db=-40;nxt.play();nxt.stream_paused=paused_by_host
 fade(nxt,level,1.6)
func set_festival(on:bool):
 if festival==on:return
 festival=on
 play_music("music/plaza-festival" if on else base_music)

func play_ambience(name:String):
 if name==amb_name:return
 amb_name=name
 for a in amb:
  if a.playing:fade(a,-60,2.0,true)
 if name=="":return
 var a=amb[0] if not amb[0].playing else amb[1]
 a.stream=stream(name,true);a.volume_db=-40;a.play();a.stream_paused=paused_by_host;fade(a,AMB_DB,2.0)
## Place + time of day choose music and ambience.
func place(map_id:String,night:bool):
 village_center=map_id=="village"
 var barn=map_id in ["barn","barn_up"] or map_id.begins_with("barn_floor_")
 var indoor=barn or map_id in ["seedshop","livestockshop"] or map_id.begins_with("room")
 var key=MUSIC.get("barn" if barn else map_id,"music/shop" if indoor else "music/village_day")
 if map_id in ["room_private","room_private_up"]:key="music/meadow-quiet"
 if map_id=="village" and night:key="music/village_night"
 base_music=key
 if map_id!="village":festival=false
 play_music("music/plaza-festival" if festival else base_music)
 play_ambience("" if indoor else ("amb_crickets" if night else "amb_birds"))
## Running water swells as you approach the creek, canal or pond.
func set_water(distance:float):
 if paused_by_host:return
 if water.stream==null:water.stream=stream("amb_water",true)
 var target=-60.0 if distance>420 else lerpf(-12.0,-34.0,clampf(distance/420.0,0,1))
 if target>-55 and not water.playing:water.volume_db=-50;water.play()
 water.volume_db=lerpf(water.volume_db,target,.05)
## 2026-11-19 Claude: fish ponds (3x3 deep water or larger) get their own running-water
## loop (audio/amb_pond.wav, tools/bake_water_extra_20261119.py) on top of the creek sound.
var pond_water:AudioStreamPlayer
func set_pond(distance:float):
 if paused_by_host:return
 if pond_water==null:
  pond_water=AudioStreamPlayer.new();pond_water.volume_db=-60;add_child(pond_water)
  pond_water.stream=stream("amb_pond",true)
 if pond_water.stream==null:return
 var target=-60.0 if distance>360 else lerpf(-11.0,-36.0,clampf(distance/360.0,0,1))
 if target>-55 and not pond_water.playing:pond_water.volume_db=-50;pond_water.play()
 pond_water.volume_db=lerpf(pond_water.volume_db,target,.05)
 if pond_water.volume_db<-58 and target<=-60 and pond_water.playing:pond_water.stop()
func sfx(name:String,db:=-6.0,pitch_spread:=.06):
 if paused_by_host:return
 var s=stream(name)
 if s==null:return
 var p:AudioStreamPlayer=pool[next_voice];next_voice=(next_voice+1)%pool.size()
 p.stream=s;p.volume_db=db;p.pitch_scale=1.0+randf_range(-pitch_spread,pitch_spread);p.play()
var wading:Dictionary=JSON.parse_string(FileAccess.get_file_as_string(DIR+"wading.json"))
var previous_splash := ""
func step(surface:String):
 if surface=="water":
  var variants:Array=wading.samples.duplicate()
  if variants.size()>1:variants.erase(previous_splash)
  if not variants.is_empty():
   previous_splash=str(variants.pick_random())
   sfx(previous_splash,float(wading.gain_db),float(wading.pitch_spread))
  return
 # 2026-11-19 Claude: "water" = wading through a shallow river cell.
 sfx("step_%s_%d"%[surface,randi()%3],{"grass":-15.0,"dirt":-12.0,"wood":-10.0,"stone":-12.0,"water":-9.0}.get(surface,-12.0),.08)
