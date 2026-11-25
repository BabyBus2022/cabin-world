extends SceneTree
func _initialize():run.call_deferred()
func run():
 var scene=load("res://qingxi-live/seedshop-study/main.tscn").instantiate()
 root.add_child(scene)
 await process_frame
 scene.paused_for_capture=true
 var bad=[]
 for value in [0,1,2,3]:
  scene.set_preset(value)
  for window in scene.windows:
   if window.self_modulate!=Color.WHITE:bad.append("window and attached wall darkened as one rectangular tile at preset %d"%value)
  if value==1 and scene.lights[0].energy!=0:bad.append("daytime lamps not off")
  if value==3 and scene.lights[0].energy<.3:bad.append("night lamps not automatically on")
 var last=scene.sky_color(0)
 for i in range(1,2401):
  var color=scene.sky_color(i*.01)
  if maxf(absf(color.r-last.r),maxf(absf(color.g-last.g),absf(color.b-last.b)))>.01:bad.append("abrupt daylight transition")
  last=color
 if scene.sky_color(0)!=scene.sky_color(24):bad.append("midnight seam")
 scene.hour=23.99;scene.cycle_running=true;scene.paused_for_capture=false;scene._physics_process(.2)
 if scene.hour>=24 or scene.hour<0:bad.append("clock failed to wrap")
 print("WINDOW_WALL_LIGHTING ","PASS" if bad.is_empty() else "FAIL"," ",bad)
 quit(0 if bad.is_empty() else 1)
