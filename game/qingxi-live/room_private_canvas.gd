extends Node2D
## 2026-11-19 Claude: the owner's private cottage, redrawn (village houses still use
## room_canvas.gd). Same room box as before (floor 262..1018 x 283..710, door gap
## 590..690 at the bottom) so the other systems are unchanged. Ground floor: tiled
## kitchen corner, plank floor, living-room rug, doormat and a staircase built against
## the right wall rising to a landing; upstairs: the landing and a railed stairwell.
## Flat pixel-art colours on a 2 px grid, warm farmhouse palette.
const Rooms=preload("res://qingxi-live/village_rooms.gd")
var style=4
var upstairs=false
var dorm=false

const Loft=preload("res://qingxi-live/dorm_loft.gd")
const VOID=Color("2b2320")
const WOOD_DARK=Color("5e3b27")
const WOOD_MID=Color("8a5a38")
const WOOD_LIGHT=Color("b9824f")
const PAPER=Color("ead5a9")
const PAPER_STRIPE=Color("e1c897")
const PLANKS=[Color("c99c64"),Color("c29461"),Color("bb8d5a"),Color("c69860")]
const SEAM=Color("9b7046")

func _draw():
	if dorm:
		draw_rect(Loft.SHELL.grow(1800),Color("291f1b"))
		draw_texture_rect(Loft.texture(),Loft.SHELL,false)
		woven_runner(Rect2(441,590,191,70),Color("7a9083"))
		woven_runner(Rect2(1038,565,115,43),Color("ad8e74"))
		return
	draw_rect(Rect2(0,0,1280,900),VOID)
	back_wall()
	floor_planks(Rect2(262,283,756,427))
	if not upstairs:
		kitchen_tiles(Rect2(262,283,300,170))
		rug(Rect2(712,452,180,196),Color("7f9b6b"),Color("5d7b4f"))
		doormat(Rect2(602,684,76,22))
	else:
		rug(Rect2(524,555,298,132),Color("8fa3b8"),Color("667e98"))
	# Soft shadow where the floor meets the back and side walls.
	draw_rect(Rect2(262,283,756,12),Color(0,0,0,.16))
	draw_rect(Rect2(262,283,8,427),Color(0,0,0,.12))
	draw_rect(Rect2(1010,283,8,427),Color(0,0,0,.12))
	if upstairs:stairwell()
	else:staircase()
	if not upstairs:
		woven_runner(Rect2(317,501,199,80),Color("aa8c6a"))
		woven_runner(Rect2(577,598,109,92),Color("a67f60"))
	house_trim()
	side_and_front_walls()
	if upstairs:
		# The dorm opens through the bedroom's north wall.
		draw_rect(Rect2(604,220,52,64),WOOD_DARK)
		draw_rect(Rect2(609,225,42,58),Color("68482e"))
		draw_rect(Rect2(613,230,34,22),Color("785837"))
		draw_circle(Vector2(642,262),2,Color("e6bd70"))
		draw_rect(Rect2(608,203,44,14),WOOD_DARK)
		draw_string(ThemeDB.fallback_font,Vector2(610,214),"宿舍",HORIZONTAL_ALIGNMENT_CENTER,40,10,Color("f5dfb5"))
	if not dorm:
		var at=Vector2(972,350) if upstairs else Vector2(971,582)
		var sign=Color("40586c") if upstairs else Color("47705b")
		draw_style_box(sign_box(sign),Rect2(at-Vector2(40,13),Vector2(80,26)))
		var dir=1 if upstairs else -1
		var tip=at+Vector2(-25,dir*5)
		draw_line(tip-Vector2(0,dir*11),tip,Color("fff0cb"),2)
		draw_polyline(PackedVector2Array([tip-Vector2(5,dir*5),tip,tip+Vector2(5,-dir*5)]),Color("fff0cb"),2)
		draw_string(ThemeDB.fallback_font,at+Vector2(-14,5),"下楼 1F" if upstairs else "上楼 2F",HORIZONTAL_ALIGNMENT_LEFT,-1,12,Color("fff1ce"))

func woven_runner(r:Rect2, base:Color):
	draw_rect(r,base.darkened(.32));draw_rect(r.grow(-3),base)
	draw_rect(r.grow(-7),base.lightened(.37),false,1)
	for x in range(int(r.position.x)+13,int(r.end.x)-9,17):
		for y in [r.position.y+8,r.end.y-8]:draw_colored_polygon(PackedVector2Array([Vector2(x-3,y),Vector2(x,y-2),Vector2(x+3,y),Vector2(x,y+2)]),base.lightened(.42))
func house_trim():
	for x in [268,575,684,1008]:
		draw_rect(Rect2(x,200,5,84),WOOD_MID)
		draw_rect(Rect2(x+1,201,1,82),WOOD_LIGHT)
	for x in ([353,903] if upstairs else [575,883]):
		# A shaded wall sconce with a brass foot.
		draw_rect(Rect2(x-2,221,4,14),Color("865936"))
		draw_circle(Vector2(x,237),3,Color("ba8b53"))
		draw_colored_polygon(PackedVector2Array([Vector2(x-5,209),Vector2(x+5,209),Vector2(x+8,219),Vector2(x-8,219)]),Color("a37845"))
		draw_colored_polygon(PackedVector2Array([Vector2(x-4,210),Vector2(x+4,210),Vector2(x+6,218),Vector2(x-6,218)]),Color("f4d9a1"))
	if not upstairs:
		# Open kitchen rail with hanging ladle and two copper pans.
		draw_rect(Rect2(338,217,91,4),WOOD_DARK)
		for j in 3:
			var x=350+j*28
			draw_line(Vector2(x,220),Vector2(x,230),Color("775747"),2)
			draw_circle(Vector2(x,233),4+j,Color("76503b"))
			draw_circle(Vector2(x-1,232),3+j,Color("c59670"))
	elif dorm:
		# Pinned keepsakes over the reading corner.
		draw_rect(Rect2(929,208,50,33),WOOD_DARK)
		draw_rect(Rect2(932,211,44,27),Color("b28a5d"))
		for j in 3:
			var x=936+j*12;var y=213+j%2*4
			draw_rect(Rect2(x,y,10,13),Color("eee2c6"))
			draw_rect(Rect2(x+1,y+2,8,6),[Color("829da0"),Color("b38575"),Color("9fa481")][j])
			draw_circle(Vector2(x+5,y),1,Color("874b38"))
	if dorm:
		painting(Rect2(488,212,32,24),Color("95b2b4"));painting(Rect2(742,214,28,22),Color("bea684"))
func sign_box(color:Color)->StyleBoxFlat:
	var box=StyleBoxFlat.new()
	box.bg_color=color;box.border_color=WOOD_DARK;box.set_border_width_all(2);box.set_corner_radius_all(3)
	return box

func back_wall():
	var top=196.0;var base=283.0
	draw_rect(Rect2(250,top,780,base-top),PAPER)
	for x in range(250,1030,16):draw_rect(Rect2(x,top+8,6,base-top-44),PAPER_STRIPE)
	for x in range(258,1030,32):
		for y in range(int(top)+18,int(base)-44,24):draw_rect(Rect2(x+((y/24)%2)*16,y,2,2),Color("d3b282"))
	# Crown moulding and wainscot with framed panels.
	draw_rect(Rect2(250,top,780,8),WOOD_DARK);draw_rect(Rect2(250,top+8,780,2),WOOD_MID)
	draw_rect(Rect2(250,base-40,780,40),WOOD_MID)
	draw_rect(Rect2(250,base-42,780,4),WOOD_LIGHT)
	for x in range(258,1018,60):
		draw_rect(Rect2(x,base-32,50,24),Color("7d5032"))
		draw_rect(Rect2(x+2,base-30,46,2),Color("9c6a43"))
	if upstairs:
		window(Rect2(420,206,64,36),Color("c98a7a"))
		window(Rect2(800,206,64,36),Color("c98a7a"))
		painting(Rect2(612,208,40,28),Color("8fb1c9"))
	else:
		window(Rect2(470,206,64,36),Color("d39a6a"))
		window(Rect2(770,206,64,36),Color("a6b878"))
		painting(Rect2(296,210,34,26),Color("e0b06a"))

func window(r:Rect2,curtain:Color):
	draw_rect(r.grow(4),WOOD_DARK)
	draw_rect(r,Color("bfe0ea"))
	draw_rect(Rect2(r.position,Vector2(r.size.x,r.size.y*.45)),Color("d8eef2"))
	draw_rect(Rect2(r.position.x+r.size.x/2-2,r.position.y,4,r.size.y),Color("f3ead6"))
	draw_rect(Rect2(r.position.x,r.position.y+r.size.y/2-2,r.size.x,4),Color("f3ead6"))
	draw_rect(Rect2(r.position.x-6,r.end.y+2,r.size.x+12,4),Color("f3ead6"))   # sill
	for side in [-1,1]:
		var x=r.position.x-10 if side<0 else r.end.x-2
		draw_rect(Rect2(x,r.position.y-6,12,r.size.y+10),curtain)
		draw_rect(Rect2(x+(8 if side<0 else 0),r.position.y-6,4,r.size.y+10),curtain.darkened(.18))
	draw_rect(Rect2(r.position.x-14,r.position.y-8,r.size.x+28,4),WOOD_DARK)   # rod

func painting(r:Rect2,sky:Color):
	draw_rect(r.grow(3),Color("8d5e36"))
	draw_rect(r,sky)
	draw_colored_polygon(PackedVector2Array([r.position+Vector2(0,r.size.y),r.position+Vector2(r.size.x*.35,r.size.y*.45),r.position+Vector2(r.size.x*.6,r.size.y*.75),r.position+Vector2(r.size.x*.8,r.size.y*.5),r.end]),Color("6f9a5d"))

func floor_planks(r:Rect2):
	var row=0
	for y in range(int(r.position.y),int(r.end.y),20):
		var shift=(row*53)%120
		var x=r.position.x-shift
		var i=0
		while x<r.end.x:
			var a=maxf(x,r.position.x);var b=minf(x+120,r.end.x)
			if b>a:
				var c:Color=PLANKS[(row*3+i)%PLANKS.size()]
				draw_rect(Rect2(a,y,b-a,19),c)
				draw_rect(Rect2(a,y,b-a,2),c.lightened(.07))
				if (row+i)%5==0:draw_rect(Rect2(a+30,y+8,6,3),c.darkened(.16))   # knot
				draw_rect(Rect2(b-1,y,1,19),SEAM)
			x+=120;i+=1
		draw_rect(Rect2(r.position.x,y+19,r.size.x,1),SEAM)
		row+=1

func kitchen_tiles(r:Rect2):
	for y in range(int(r.position.y),int(r.end.y),30):
		for x in range(int(r.position.x),int(r.end.x),30):
			var light=((x-int(r.position.x))/30+(y-int(r.position.y))/30)%2==0
			var w=minf(30,r.end.x-x);var h=minf(30,r.end.y-y)
			draw_rect(Rect2(x,y,w,h),Color("b6a68a"))
			draw_rect(Rect2(x+1,y+1,w-2,h-2),Color("eadfc6") if light else Color("cfc1a3"))
	draw_rect(Rect2(r.position.x,r.end.y,r.size.x,3),Color("9b8a6c"))
	draw_rect(Rect2(r.end.x,r.position.y,3,r.size.y+3),Color("9b8a6c"))

func rug(r:Rect2,base:Color,edge:Color):
	draw_rect(r,edge)
	draw_rect(r.grow(-6),base)
	draw_rect(r.grow(-12),Color("eadbb3"),false,2)
	for x in range(int(r.position.x)+20,int(r.end.x)-16,16):
		draw_rect(Rect2(x,r.position.y+18,6,r.size.y-36),base.lightened(.08))
	for x in range(int(r.position.x)+4,int(r.end.x)-2,8):   # fringe
		draw_rect(Rect2(x,r.position.y-4,3,4),Color("eadbb3"));draw_rect(Rect2(x,r.end.y,3,4),Color("eadbb3"))

func doormat(r:Rect2):
	draw_rect(r,Color("8e623d"))
	draw_rect(r.grow(-3),Color("b3814f"))
	for x in range(int(r.position.x)+6,int(r.end.x)-4,8):draw_rect(Rect2(x,r.position.y+5,3,r.size.y-10),Color("9b6c41"))

## Ground floor: the flight rises north along the right wall; above its top is the front
## face of the upstairs landing (panelled), which is also a wall at this level.
func staircase():
	var run:Rect2=Rooms.STAIR_RUN
	var x0=run.position.x;var x1=run.end.x
	# Landing front face and the boards of the landing seen from below.
	draw_rect(Rect2(x0,283,run.size.x,run.position.y-283),WOOD_MID)
	for y in [298,334]:draw_rect(Rect2(x0+8,y,run.size.x-16,26),Color("7a4e31"));draw_rect(Rect2(x0+10,y+2,run.size.x-20,2),Color("9a6a43"))
	draw_rect(Rect2(x0,run.position.y-6,run.size.x,6),WOOD_DARK)
	# Treads: nine steps, each a light top with a nosing highlight over a dark riser,
	# getting lighter as they rise towards the upstairs light.
	var steps=9;var h=run.size.y/steps
	for i in steps:
		var y=run.end.y-(i+1)*h
		var tone=Color("b27c4a").lightened(i*.028)
		draw_rect(Rect2(x0,y,run.size.x,h),Color("5e3b27"))       # riser
		draw_rect(Rect2(x0,y,run.size.x,h-6),tone)                  # tread
		draw_rect(Rect2(x0,y,run.size.x,2),tone.lightened(.16))     # nosing
		draw_rect(Rect2(x0+14+(i*23)%40,y+6,10,2),tone.darkened(.12))   # grain
	draw_rect(Rect2(x1-6,run.position.y,6,run.size.y),WOOD_DARK)     # wall stringer
	# Banister on the open (west) side: string, balusters, handrail, newel posts.
	draw_rect(Rect2(x0-8,run.position.y,8,run.size.y-26),WOOD_DARK)
	for y in range(int(run.position.y)+6,int(run.end.y)-30,18):draw_rect(Rect2(x0-6,y,4,10),Color("e2bd88"))
	draw_rect(Rect2(x0-10,run.position.y,4,run.size.y-26),Color("c68f58"))
	newel(Vector2(x0-4,run.end.y-30))
	newel(Vector2(x0-4,run.position.y-4))

## Upstairs: the landing in front of the back wall and the stairwell going down, railed on
## its west and south sides so it reads as an opening, not a floor patch.
func stairwell():
	var run:Rect2=Rooms.STAIR_RUN;var landing:Rect2=Rooms.STAIR_LANDING
	var x0=run.position.x
	draw_rect(Rect2(x0,run.position.y,run.size.x,run.size.y),Color("1d1512"))
	var steps=4;var h=22.0
	for i in steps:   # the first treads going down, fading into the dark
		var y=run.position.y+i*h
		var tone=Color("b9824f").darkened(.18+i*.17)
		draw_rect(Rect2(x0+4,y,run.size.x-8,h-6),tone)
		draw_rect(Rect2(x0+4,y,run.size.x-8,2),tone.lightened(.12))
	draw_rect(Rect2(x0,run.position.y,run.size.x,4),Color("e0b07c"))   # landing lip
	draw_rect(Rect2(x0,landing.position.y,run.size.x,2),Color(0,0,0,.12))
	# West and south railings with balusters, posts at the corners.
	draw_rect(Rect2(x0-12,run.position.y,10,run.size.y+10),WOOD_DARK)
	draw_rect(Rect2(x0-12,run.end.y,run.size.x+12,10),WOOD_DARK)
	for y in range(int(run.position.y)+8,int(run.end.y),18):draw_rect(Rect2(x0-10,y,6,8),Color("e2bd88"))
	for x in range(int(x0)+8,int(run.end.x),18):draw_rect(Rect2(x,run.end.y+2,8,6),Color("e2bd88"))
	draw_rect(Rect2(x0-14,run.position.y,4,run.size.y+12),Color("c68f58"))
	draw_rect(Rect2(x0-14,run.end.y+8,run.size.x+14,4),Color("c68f58"))
	newel(Vector2(x0-8,run.position.y-4));newel(Vector2(x0-8,run.end.y+4))

func newel(c:Vector2):
	draw_rect(Rect2(c-Vector2(8,8),Vector2(16,16)),WOOD_DARK)
	draw_rect(Rect2(c-Vector2(6,6),Vector2(12,12)),Color("9d6a41"))
	draw_rect(Rect2(c-Vector2(6,6),Vector2(12,3)),Color("c99258"))

func side_and_front_walls():
	for x in [250,1018]:
		draw_rect(Rect2(x,190,12,530),WOOD_DARK)
		draw_rect(Rect2(x+(8 if x==250 else 0),190,4,530),WOOD_MID)
	if upstairs:   # no front door up here
		draw_rect(Rect2(250,710,780,12),WOOD_DARK);draw_rect(Rect2(250,710,780,3),WOOD_MID)
		return
	draw_rect(Rect2(250,710,340,12),WOOD_DARK);draw_rect(Rect2(690,710,340,12),WOOD_DARK)
	draw_rect(Rect2(250,710,340,3),WOOD_MID);draw_rect(Rect2(690,710,340,3),WOOD_MID)
	# Door frame posts either side of the opening.
	for x in [582,690]:draw_rect(Rect2(x,698,8,24),Color("7a4e31"))
