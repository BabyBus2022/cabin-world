extends Node2D
## 2026-11-19 Claude: ambient life on outdoor maps (village, farm, ranch, pond), so the
## world moves by itself even when you stand still:
##   butterflies  by day (not in winter), fluttering near the player
##   birds        pecking on open grass; they take off when you come close, land elsewhere
##   fireflies    on the farm maps at night (the village has its own)
##   snow         in winter (seasons.gd), light flakes around the camera
## Everything lives around the camera (no cost far away) and is pixel art on a 2 px grid.
var world
var butterflies=[]
var birds=[]
var flies=[]
var flakes=[]
var age=0.0
const WINGS=[Color("fff6e0"),Color("f6d45a"),Color("f29a5c"),Color("b9d8ff")]
func setup(host):
 world=host;z_index=6
 for i in 6:butterflies.append({"p":Vector2.ZERO,"v":Vector2.ZERO,"c":WINGS[i%4],"seed":i*17+3,"live":false})
 for i in 5:birds.append({"p":Vector2.ZERO,"state":"none","t":0.0,"seed":i*29+5,"dir":1.0})
 for i in 14:flies.append({"p":Vector2.ZERO,"seed":i*11+1,"live":false})
 for i in 60:flakes.append(Vector2(randf()*1600,randf()*1000))
func hour()->float:return world.sky_value()*24.0
func season()->int:return world.season() if world.has_method("season") else 0
func around()->Rect2:
 var c:Vector2=world.camera.get_screen_center_position() if is_instance_valid(world.camera) else world.player.position
 var view=world.get_viewport_rect().size/(world.camera.zoom if is_instance_valid(world.camera) else Vector2.ONE)
 return Rect2(c-view/2,view)
func free_spot(r:Rect2,seed_:int)->Vector2:
 for k in 12:
  var h=absi(hash(Vector2i(seed_,k+int(age))))
  var p=r.position+Vector2(h%int(maxf(r.size.x,1)),(h/101)%int(maxf(r.size.y,1)))
  if not world.blocked(p) and not world.water_at(p):return p
 return Vector2.INF
func _process(dt):
 if world==null or not is_instance_valid(world.player):return
 age+=dt
 var view=around();var h=hour();var s=season()
 var day=h>7.0 and h<17.5 and s!=3
 for b in butterflies:
  if not day:b.live=false;continue
  if not b.live or not view.grow(200).has_point(b.p):
   var p=free_spot(view,int(b.seed)+int(age*3))
   if p!=Vector2.INF:b.p=p-Vector2(0,30);b.live=true
   continue
  var t=age*1.3+float(b.seed)
  b.v=b.v.lerp(Vector2(cos(t*.7)*22.0,sin(t*1.1)*14.0),dt*2.0)
  b.p+=b.v*dt
 for bird in birds:
  match bird.state:
   "none":
    if day or (s==3 and h>8 and h<16):
     var p=free_spot(view,int(bird.seed)+int(age))
     if p!=Vector2.INF and p.distance_to(world.player.position)>180:bird.p=p;bird.state="peck";bird.t=0.0
   "peck":
    bird.t+=dt
    if bird.p.distance_to(world.player.position)<90:   # startled: take off away from you
     bird.state="fly";bird.dir=signf(bird.p.x-world.player.position.x+.01);bird.t=0.0
     if world.audio:world.audio.sfx("ui_click",-24,.4)
    elif not view.grow(300).has_point(bird.p):bird.state="none"
   "fly":
    bird.t+=dt;bird.p+=Vector2(bird.dir*150.0,-90.0)*dt
    if bird.t>2.5:bird.state="none"
 var night=h>=19.5 or h<5.0
 var fireflies=night and world.map_id!="village" and s!=3
 for f in flies:
  if not fireflies:f.live=false;continue
  if not f.live or not view.grow(120).has_point(f.p):
   var p=free_spot(view,int(f.seed)+int(age))
   if p!=Vector2.INF:f.p=p-Vector2(0,20);f.live=true
   continue
  f.p+=Vector2(sin(age*.9+f.seed)*10.0,cos(age*.7+f.seed*.5)*7.0)*dt
 queue_redraw()
func _draw():
 if world==null:return
 var tint:Color=world.ground_tint
 for b in butterflies:
  if not b.live:continue
  var p:Vector2=b.p.snapped(Vector2(2,2))
  var open=int(age*10.0+b.seed)%2==0
  var w=4.0 if open else 2.0
  draw_rect(Rect2(p+Vector2(-w-1,-3),Vector2(w,4)),b.c*tint);draw_rect(Rect2(p+Vector2(1,-3),Vector2(w,4)),b.c*tint)
  draw_rect(Rect2(p+Vector2(-1,-3),Vector2(2,5)),Color("3a2a20")*tint)
 for bird in birds:
  if bird.state=="none":continue
  var p:Vector2=bird.p.snapped(Vector2(2,2))
  var ink=Color("6b4a35")*tint
  if bird.state=="peck":
   var bob=2.0 if int(bird.t*3.0+bird.seed)%3==0 else 0.0
   draw_rect(Rect2(p+Vector2(-4,-6+bob),Vector2(8,5)),ink)
   draw_rect(Rect2(p+Vector2(3,-8+bob*1.5),Vector2(4,4)),ink)
   draw_rect(Rect2(p+Vector2(7,-6+bob*1.5),Vector2(2,1)),Color("e0a040")*tint)
   draw_rect(Rect2(p+Vector2(-6,-5+bob),Vector2(3,2)),ink.darkened(.2))
  else:
   var flap=int(bird.t*12.0)%2==0
   draw_rect(Rect2(p+Vector2(-3,-2),Vector2(6,3)),ink)
   draw_rect(Rect2(p+Vector2(-9,-5 if flap else 0),Vector2(6,2)),ink);draw_rect(Rect2(p+Vector2(3,-5 if flap else 0),Vector2(6,2)),ink)
 for f in flies:
  if not f.live:continue
  var glow=.5+.5*sin(age*3.0+f.seed)
  draw_rect(Rect2(f.p.snapped(Vector2(2,2)),Vector2(2,2)),Color(1,.95,.55,glow))
  draw_rect(Rect2(f.p.snapped(Vector2(2,2))-Vector2(2,2),Vector2(6,6)),Color(1,.9,.4,.18*glow))
 if season()==3 and world.map_id in ["village","field","ranch","pond"]:
  var view=around()
  for i in flakes.size():
   var base:Vector2=flakes[i]
   var p=view.position+Vector2(fposmod(base.x+sin(age*.6+i)*14.0,view.size.x),fposmod(base.y+age*(26.0+float(i%5)*6.0),view.size.y))
   draw_rect(Rect2(p.snapped(Vector2(2,2)),Vector2(2,2)) if i%3 else Rect2(p.snapped(Vector2(2,2)),Vector2(4,4)),Color(1,1,1,.85))
