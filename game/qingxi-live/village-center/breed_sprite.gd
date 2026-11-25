extends RefCounted
const DIR="res://qingxi-live/village-center/art/garden-v3/breeds/"
static var frames={}
var foot_baseline=92.0
var animal:Dictionary
var pose=1
var mirrored=false
var phase=0.0
var shorn=false
var step=0
func _init(a:Dictionary):animal=a
func animate(dt:float,moving:bool,_mode:String,is_shorn:bool,heading:Vector2):
	shorn=is_shorn
	if moving:
		phase+=dt*5.5
		step=int(phase)%2
		mirrored=heading.x>0 and absf(heading.x)>absf(heading.y)
		pose=(1+step) if absf(heading.x)>absf(heading.y) else (0 if heading.y>0 else 3)
	else:
		step=0
		if pose==2:pose=1
func texture()->Texture2D:
	var coat=int(animal.coat)
	var file=str(animal.kind)
	if coat>=2:file+="_rare"
	elif animal.kind=="chicken" and animal.sex=="m":file="rooster"
	if animal.kind=="sheep" and shorn:file="sheep_shorn"+("_rare" if coat>=2 else "")
	if not frames.has(file):
		var sheet=Image.load_from_file(DIR+file+".png")
		var list=[]
		for i in 8:
			var img=sheet.get_region(Rect2i(i%4*56,i/4*48,56,48))
			img.resize(112,96,Image.INTERPOLATE_NEAREST)
			list.append(ImageTexture.create_from_image(img))
		frames[file]=list
	return frames[file][coat%2*4+pose]

