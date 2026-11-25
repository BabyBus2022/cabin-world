extends RefCounted
## Same presentation interface as AnimalModel; simulation stays in farm_animals.gd.
const DIR="res://qingxi-live/village-center/art/garden-v3/animals/"
static var sheets={}
var kind:String
var foot_baseline=92.0
var direction=1
var frame=0
var phase=0.0
var shorn=false
func _init(_parent:Node,animal_kind:String):
 kind=animal_kind
func texture()->Texture2D:
 var name=kind+("_shorn" if kind=="sheep" and shorn else "")
 if not sheets.has(name):
  var image=Image.load_from_file(DIR+name+".png")
  var list=[]
  for i in 16:list.append(ImageTexture.create_from_image(image.get_region(Rect2i(i%4*112,i/4*96,112,96))))
  sheets[name]=list
 return sheets[name][direction*4+frame]
func animate(dt:float,moving:bool,_mode:String,is_shorn:bool,heading:Vector2):
 shorn=is_shorn
 if moving:
  direction=(3 if heading.x>0 else 1) if absf(heading.x)>absf(heading.y) else (0 if heading.y>0 else 2)
  phase+=dt*5.5;frame=int(phase)%4
 else:
  phase=0.0;frame=0
