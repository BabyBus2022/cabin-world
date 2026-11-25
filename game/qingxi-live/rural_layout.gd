extends RefCounted
# Routes describe destinations and bends, never a shared cross-shaped template.
const ROUTES={
"village":[
	[23,Vector2(150,940),Vector2(330,890),Vector2(470,760),Vector2(570,650),Vector2(620,590),Vector2(805,640),Vector2(1030,715),Vector2(1190,810),Vector2(1420,905),Vector2(1650,1050),Vector2(1830,1160)],
	[19,Vector2(805,640),Vector2(875,525),Vector2(1020,545),Vector2(1150,470),Vector2(1330,420),Vector2(1550,320)],
	[19,Vector2(1030,715),Vector2(925,865),Vector2(800,1020),Vector2(750,1190),Vector2(710,1340)],
	[13,Vector2(470,760),Vector2(350,700),Vector2(275,580),Vector2(295,493)],
	[13,Vector2(1020,545),Vector2(1075,518)],
	[14,Vector2(1420,905),Vector2(1480,840),Vector2(1520,768)],
	[14,Vector2(800,1020),Vector2(845,1115),Vector2(920,1138)],
	[18,Vector2(620,590),Vector2(620,551)],
	[12,Vector2(539,682),Vector2(453,638),Vector2(465,600)],
	[34,Vector2(584,592),Vector2(627,597),Vector2(653,581)]],
"field":[
	[15,Vector2(340,610),Vector2(420,625),Vector2(560,660),Vector2(707,710)],
	[22,Vector2(1030,650),Vector2(1042,700),Vector2(920,731),Vector2(801,669),Vector2(795,571),Vector2(830,560)],
	[15,Vector2(796,592),Vector2(747,533),Vector2(690,485)],
	[17,Vector2(801,669),Vector2(707,710),Vector2(640,780)],
	[12,Vector2(795,615),Vector2(762,613)]],
"ranch":[
	[23,Vector2(120,740),Vector2(235,705),Vector2(375,696),Vector2(464,754),Vector2(640,800),Vector2(786,755),Vector2(864,674),Vector2(1025,644),Vector2(1025,590)],
	[16,Vector2(375,696),Vector2(296,668),Vector2(290,615)],
	[16,Vector2(786,755),Vector2(701,759),Vector2(665,705)]],
"pond":[
	[18,Vector2(640,240),Vector2(495,257),Vector2(389,331),Vector2(359,462),Vector2(388,596),Vector2(529,683),Vector2(708,713),Vector2(856,665),Vector2(884,608)],
	[17,Vector2(388,596),Vector2(305,614),Vector2(250,650)],
	[20,Vector2(856,665),Vector2(948,691),Vector2(1030,650)],
	[12,Vector2(1030,650),Vector2(1121,577),Vector2(1108,491)]],
"home":[
	[20,Vector2(330,625),Vector2(438,658),Vector2(541,622),Vector2(579,554),Vector2(620,500)],
	[12,Vector2(541,622),Vector2(714,659),Vector2(817,597)],
	[27,Vector2(608,514),Vector2(645,530)]]}
const TREES={
"village":[Vector2(174,320),Vector2(219,300),Vector2(189,390),Vector2(490,375),Vector2(1205,525),Vector2(1260,566),Vector2(1247,460),Vector2(180,738),Vector2(222,805),Vector2(807,780),Vector2(877,822),Vector2(554,291),Vector2(565,345),Vector2(1651,692),Vector2(1720,762),Vector2(1676,830),Vector2(1230,1090),Vector2(1290,1156),Vector2(1180,1195),Vector2(522,1090),Vector2(584,1137),Vector2(515,1175),Vector2(1570,1270),Vector2(1500,1305),Vector2(1390,560),Vector2(1440,570),Vector2(1800,440),Vector2(1860,480),Vector2(1080,260),Vector2(1000,260)],
"field":[Vector2(330,420),Vector2(397,443),Vector2(365,497),Vector2(507,291),Vector2(565,323),Vector2(1075,425),Vector2(1128,487),Vector2(490,709),Vector2(541,755),Vector2(1110,803)],
"ranch":[Vector2(127,328),Vector2(191,295),Vector2(446,359),Vector2(510,393),Vector2(810,436),Vector2(842,382),Vector2(1148,316),Vector2(1139,700),Vector2(1075,778),Vector2(355,811)],
"pond":[Vector2(281,359),Vector2(306,432),Vector2(232,455),Vector2(431,206),Vector2(502,200),Vector2(831,237),Vector2(894,247),Vector2(1100,329),Vector2(1166,385),Vector2(353,751),Vector2(419,796),Vector2(1084,789)],
"home":[Vector2(302,426),Vector2(349,401),Vector2(331,486),Vector2(925,453),Vector2(981,504),Vector2(1005,407),Vector2(841,282),Vector2(500,287),Vector2(252,744),Vector2(303,788),Vector2(909,737),Vector2(979,765)]}
var masks={}
func mask(id:String)->Texture2D:
	if masks.has(id):return masks[id]
	var img=Image.create(1024 if id=="village" else 640,768 if id=="village" else 450,false,Image.FORMAT_R8);img.fill(Color.BLACK)
	for route in ROUTES[id]:
		var curve=Curve2D.new();curve.bake_interval=10
		for i in range(1,route.size()):
			var before:Vector2=route[maxi(1,i-1)];var after:Vector2=route[mini(route.size()-1,i+1)]
			var tangent=(after-before)*0.17
			curve.add_point(route[i],-tangent if i>1 else Vector2.ZERO,tangent if i<route.size()-1 else Vector2.ZERO)
		var points=curve.get_baked_points()
		for i in range(points.size()-1):stamp(img,points[i]/2,points[i+1]/2,float(route[0])/2)
	masks[id]=ImageTexture.create_from_image(img);return masks[id]
func stamp(img:Image,a:Vector2,b:Vector2,r:float):
	var lo=(a.min(b)-Vector2.ONE*(r+3)).floor().max(Vector2.ZERO)
	var hi=(a.max(b)+Vector2.ONE*(r+3)).ceil().min(Vector2(img.get_width()-1,img.get_height()-1))
	var ab=b-a
	for y in range(int(lo.y),int(hi.y)+1):
		for x in range(int(lo.x),int(hi.x)+1):
			var p=Vector2(x,y);var nearest=a+ab*clampf((p-a).dot(ab)/maxf(ab.length_squared(),0.01),0,1)
			var edge=sin(x*0.27+y*0.19)*0.65+sin(x*1.37+y*0.7)*0.35
			var value=clampf((r+edge-p.distance_to(nearest)+1.8)/3.6,0,1)
			if value>img.get_pixel(x,y).r:img.set_pixel(x,y,Color(value,0,0,1))
