extends Node2D
const SHEET="res://qingxi-live/village-center/art/jp/tuantuan-roadworks.png"
const NOTICE="预留 待开发"
const DARK=Color("553925")
const WOOD=Color("b17a49")
const CREAM=Color("ffe3a1")
const RED=Color("c8703c")
static var worker_frames:SpriteFrames
var axis=Vector2.RIGHT
var half_width=92.0
var workers=[]
var cones=[]
var notice_font=SystemFont.new()

func setup(direction:Vector2,width_:float,variant:int):
 axis=direction.normalized()
 half_width=maxf(68,width_*.5+16)
 var face=Vector2(-axis.y,axis.x)
 notice_font.font_names=PackedStringArray(["Microsoft YaHei UI","Microsoft YaHei","SimHei"])
 notice_font.font_weight=700
 cones=[face*(-half_width+6)-axis*28,face*(half_width-8)-axis*19]
 var frames=build_worker_frames()
 for i in 2:
  var s=AnimatedSprite2D.new();s.sprite_frames=frames
  s.centered=true;s.offset=Vector2(0,-float(frames.get_frame_texture(str(i),0).get_height())*.40)
  s.scale=Vector2.ONE*.132
  s.flip_h=(i+variant)%2==1
  s.texture_filter=CanvasItem.TEXTURE_FILTER_NEAREST
  s.position=(face*(float(i)*2-1)*minf(half_width*.48,67)-axis*(60+i*14)).snapped(Vector2(2,2))
  add_child(s)
  s.play(str(i));s.frame=(variant+i)%4
  workers.append(s)
 queue_redraw()

static func build_worker_frames()->SpriteFrames:
 if worker_frames!=null:return worker_frames
 worker_frames=SpriteFrames.new()
 var art=ImageTexture.create_from_image(Image.load_from_file(SHEET))
 var cell=Vector2(art.get_width()/4.0,art.get_height()/2.0)
 for row in 2:
  var clip=str(row)
  worker_frames.add_animation(clip);worker_frames.set_animation_speed(clip,4.5)
  for col in 4:
   var frame=AtlasTexture.new();frame.atlas=art
   frame.region=Rect2(Vector2(col,row)*cell,cell);frame.filter_clip=true
   worker_frames.add_frame(clip,frame,1.0 if col%2 else 1.25)
 return worker_frames

func blocks(p:Vector2)->bool:
 var offset=p-global_position
 return absf(offset.dot(axis))<13.0 and absf(offset.dot(Vector2(-axis.y,axis.x)))<half_width+7.0

func plank(a:Vector2,b:Vector2,w:float,c:Color):
 draw_line(a.snapped(Vector2(2,2)),b.snapped(Vector2(2,2)),c,w)

func _draw():
 var cross=Vector2(-axis.y,axis.x)
 var a=cross*-half_width
 var b=cross*half_width
 plank(a+Vector2(0,4),b+Vector2(0,4),13.0,Color(DARK,.24))
 for i in 4:
  var p=a.lerp(b,float(i)/3)
  draw_rect(Rect2(p-Vector2(7,0),Vector2(16,5)),DARK)
  draw_rect(Rect2(p-Vector2(4,40),Vector2(9,42)),DARK)
  draw_rect(Rect2(p-Vector2(3,39),Vector2(4,37)),WOOD)
 for y in [-34,-18]:
  var offset=Vector2(0,y)
  plank(a+offset,b+offset,15,DARK)
  plank(a+offset,b+offset,11,WOOD)
  for i in 10:
   if i%2==0:plank(a.lerp(b,(i+.08)/10)+offset,a.lerp(b,(i+.90)/10)+offset,9,CREAM)
   else:plank(a.lerp(b,(i+.08)/10)+offset,a.lerp(b,(i+.90)/10)+offset,9,RED)
 for p in cones:
  draw_rect(Rect2(p-Vector2(11,2),Vector2(22,7)),DARK)
  var body=PackedVector2Array([p-Vector2(8,1),p-Vector2(3,25),p+Vector2(3,-25),p+Vector2(8,-1)])
  draw_colored_polygon(body,RED)
  draw_rect(Rect2(p-Vector2(5,12),Vector2(10,5)),CREAM)
  draw_rect(Rect2(p-Vector2(4,22),Vector2(6,3)),Color("e4a46b"))
 var sign_pos=Vector2(-48,-62)
 var box=Rect2(sign_pos-Vector2(75,21),Vector2(150,37))
 for x in [-55,55]:
  draw_rect(Rect2(sign_pos+Vector2(x,12),Vector2(7,36)),DARK)
  draw_rect(Rect2(sign_pos+Vector2(x+2,12),Vector2(3,35)),WOOD)
 draw_rect(box,DARK)
 draw_rect(box.grow(-3),CREAM)
 draw_rect(box.grow(-6),Color("efd09a"),false,1)
 var width_=notice_font.get_string_size(NOTICE,HORIZONTAL_ALIGNMENT_LEFT,-1,19).x
 draw_string(notice_font,sign_pos+Vector2(-width_/2,5),NOTICE,HORIZONTAL_ALIGNMENT_LEFT,-1,19,DARK)

