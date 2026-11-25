extends "res://qingxi-live/rural_layout.gd"

const CENTER_ROUTES=[
 [30,Vector2(140,1000),Vector2(340,950),Vector2(550,820),Vector2(730,780),Vector2(900,860)],
 [24,Vector2(550,820),Vector2(530,650),Vector2(519,500)],
 [24,Vector2(900,740),Vector2(1020,610),Vector2(1190,520),Vector2(1380,480),Vector2(1750,390),Vector2(2180,300),Vector2(2700,270)],
 [24,Vector2(1390,880),Vector2(1540,830),Vector2(1695,800),Vector2(1695,740)],
 [30,Vector2(1460,1020),Vector2(1730,1100),Vector2(2100,1200),Vector2(2530,1440),Vector2(3000,1400)],
 [21,Vector2(900,1090),Vector2(820,1210),Vector2(650,1410)],
 [19,Vector2(1380,480),Vector2(1300,450),Vector2(1290,390)],
 [22,Vector2(820,1210),Vector2(970,1530),Vector2(1300,1720),Vector2(1770,1820),Vector2(2350,1750),Vector2(2530,1440)],
 [18,Vector2(650,1410),Vector2(450,1570),Vector2(490,1820),Vector2(810,1970),Vector2(1300,1720)],
 [20,Vector2(2180,300),Vector2(2420,570),Vector2(2520,850),Vector2(2440,1150),Vector2(2530,1440)],
 [19,Vector2(1730,1100),Vector2(1840,1370),Vector2(1770,1820)]
]

func mask(id:String)->Texture2D:
 if id!="village":return super.mask(id)
 if masks.has(id):return masks[id]
 var img=Image.create(1600,1120,false,Image.FORMAT_R8);img.fill(Color.BLACK)
 for route in CENTER_ROUTES:
  var curve=Curve2D.new();curve.bake_interval=8
  for i in range(1,route.size()):
   var before:Vector2=route[maxi(1,i-1)];var after:Vector2=route[mini(route.size()-1,i+1)]
   var tangent=(after-before)*.17
   curve.add_point(route[i],-tangent if i>1 else Vector2.ZERO,tangent if i<route.size()-1 else Vector2.ZERO)
  var points=curve.get_baked_points()
  for i in range(points.size()-1):stamp(img,points[i]/2,points[i+1]/2,float(route[0])/2)
 masks[id]=ImageTexture.create_from_image(img);return masks[id]
