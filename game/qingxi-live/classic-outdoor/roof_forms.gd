extends RefCounted
var f
func _init():
 f=preload("res://qingxi-live/material-gallery/house.gd").new(Image.load_from_file("res://qingxi-live/material-gallery/assets/01-pixel-story.png"),true)
func face(root:Node3D,p:Array):
 var uv=[]
 for v in p:uv.append(Vector2(v.x,v.z)/3.5)
 f.roof_face(root,p,uv)
func wall(root:Node3D,p:Array):
 var uv=[]
 for v in p:uv.append(Vector2(v.x+v.z,v.y)/3)
 f.panel(root,p,uv,2)
func hip(root:Node3D,w:float,d:float,low:float,high:float):
 var r=w*.45
 face(root,[Vector3(-w,low,d),Vector3(w,low,d),Vector3(r,high,0),Vector3(-r,high,0)])
 face(root,[Vector3(w,low,-d),Vector3(-w,low,-d),Vector3(-r,high,0),Vector3(r,high,0)])
 for s in [-1,1]:face(root,[Vector3(s*w,low,-d),Vector3(s*w,low,d),Vector3(s*r,high,0)])
 f.beam(root,Vector3(-r,high,0),Vector3(r,high,0),.16,0)
func build(spec:Dictionary,root:Node3D):
 var id=spec.get("id","shed");var w=float(spec.get("width",3.12))/2+.48;var d=float(spec.depth)/2+.48;var low=3.25
 if id=="seed":
  hip(root,w,d,low,4.65)
  # Wide shallow shop canopy, with one lower display bay.
  face(root,[Vector3(-w,2.45,d+1),Vector3(w*.40,2.45,d+1),Vector3(w*.40,2.95,d-.45),Vector3(-w,2.95,d-.45)])
 elif id=="livestock":
  # Broken-pitch barn roof: steep lower slopes and a broad central crown.
  var shoulder=w*.63
  for s in [-1,1]:
   face(root,[Vector3(s*w,low,-d),Vector3(s*w,low,d),Vector3(s*shoulder,4.65,d),Vector3(s*shoulder,4.65,-d)])
   face(root,[Vector3(s*shoulder,4.65,-d),Vector3(s*shoulder,4.65,d),Vector3(0,5.3,d),Vector3(0,5.3,-d)])
  for z in [-d+.2,d-.2]:
   wall(root,[Vector3(-w+.2,low,z),Vector3(-shoulder,4.55,z),Vector3(0,5.2,z),Vector3(shoulder,4.55,z),Vector3(w-.2,low,z)])
   for x in [-1.1,-.55,0,.55,1.1]:f.block(root,Vector3(x,3.85,z+.03),Vector3(.10,.8,.1),1)
  f.beam(root,Vector3(0,5.3,-d),Vector3(0,5.3,d),.18,0)
 elif id=="fish":
  # Low waterside shop with a single sweeping slope and a covered porch.
  face(root,[Vector3(-w,3.0,d+1),Vector3(w,3.0,d+1),Vector3(w,4.5,-d),Vector3(-w,4.5,-d)])
  for s in [-1,1]:wall(root,[Vector3(s*(w-.2),3.15,d-.2),Vector3(s*(w-.2),3.15,-d+.2),Vector3(s*(w-.2),4.4,-d+.2)])
  wall(root,[Vector3(-w+.2,3.15,-d+.2),Vector3(w-.2,3.15,-d+.2),Vector3(w-.2,4.4,-d+.2),Vector3(-w+.2,4.4,-d+.2)])
  for x in [-w+.3,w-.3]:f.block(root,Vector3(x,1.45,d+.6),Vector3(.16,2.9,.16),1)
 elif id=="resident_a":
  hip(root,w,d,low,4.9)
  # Asymmetric little entry gable breaks the eave silhouette.
  for s in [-1,1]:face(root,[Vector3(-.8+s*1.35,2.7,d+1.1),Vector3(-.8+s*1.35,2.7,d-.3),Vector3(-.8,3.5,d-.3),Vector3(-.8,3.5,d+1.1)])
 elif id=="resident_b":
  for s in [-1,1]:face(root,[Vector3(-w,low,s*d),Vector3(w,low,s*d),Vector3(w,5.0,0),Vector3(-w,5.0,0)])
  for s in [-1,1]:wall(root,[Vector3(s*(w-.2),low,-d+.2),Vector3(s*(w-.2),4.9,0),Vector3(s*(w-.2),low,d-.2)])
  face(root,[Vector3(-1.1,2.55,d+.35),Vector3(1.1,2.55,d+.35),Vector3(1.1,3.05,d-.2),Vector3(-1.1,3.05,d-.2)])
  for x in [-1.05,1.05]:f.block(root,Vector3(x,1.25,d+.25),Vector3(.12,2.5,.12),1)
 else:
  # Small decorative outbuildings have a low hip rather than another tall gable.
  hip(root,w,d,low,3.95)

