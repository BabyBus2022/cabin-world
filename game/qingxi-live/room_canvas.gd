extends Node2D
var style=0
var upstairs=false
func _draw():
	draw_rect(Rect2(0,0,1280,900),Color("343b3d"))
	draw_rect(Rect2(244,270,792,456),Color("594733"))
	draw_rect(Rect2(260,282,760,428),Color("ba945c"))
	for row in 18:
		var y=282+row*24
		for col in 9:
			var x=260+col*96-(48 if row%2 else 0)
			var a=maxi(260,x);var b=mini(1020,x+95)
			if b<=a:continue
			var color=Color("c6a16d").darkened(float((row*17+col*7)%5)*0.016)
			draw_rect(Rect2(a,y,b-a,23),color)
			if col%3==row%3:draw_line(Vector2(a+7,y+16),Vector2(mini(b-4,a+38),y+16),Color("b3915f"),1)
	# Thick top wall with low timber panels; front wall is cut away for visibility.
	draw_rect(Rect2(250,211,780,72),Color("f0deb6"))
	draw_rect(Rect2(250,260,780,23),Color("a98251"))
	for x in [250,510,770,1018]:draw_rect(Rect2(x,208,12,77),Color("795839"))
	draw_rect(Rect2(250,208,780,9),Color("795839"))
	for x in [360,834]:
		draw_rect(Rect2(x,222,83,40),Color("755d42"))
		draw_rect(Rect2(x+5,226,73,30),Color("bdd0b4"))
		draw_rect(Rect2(x+39,224,4,34),Color("8a6d49"))
		draw_rect(Rect2(x+3,239,77,3),Color("8a6d49"))
		draw_colored_polygon(PackedVector2Array([Vector2(x+4,286),Vector2(x+78,286),Vector2(x+115,365),Vector2(x+21,365)]),Color(1,0.93,0.65,0.11))
	var rug=Rect2(369,458 if not upstairs else 538,205,125)
	var colors=[Color("8b9c79"),Color("b1a17b"),Color("8c9e9d"),Color("c3a186"),Color("84999c")]
	draw_rect(rug,colors[style]);draw_rect(rug.grow(-5),Color("e5d6b1"),false,2);draw_rect(rug.grow(-11),colors[style].lightened(0.09))
	if not upstairs:
		draw_rect(Rect2(670,282,18,215),Color("ead5ac"))
		draw_rect(Rect2(670,282,5,215),Color("795839"))
		draw_rect(Rect2(670,493,18,5),Color("795839"))
	else:
		draw_rect(Rect2(850,578,59,79),Color("534731"))
		for i in 7:
			draw_rect(Rect2(855,585+i*10,49,6),Color("ab895d").darkened(i*0.075))
		draw_rect(Rect2(847,577,7,83),Color("926b45"));draw_rect(Rect2(905,577,7,83),Color("926b45"))
	draw_rect(Rect2(250,280,12,440),Color("795839"));draw_rect(Rect2(1018,280,12,440),Color("795839"))
	draw_rect(Rect2(250,710,340,10),Color("795839"));draw_rect(Rect2(690,710,340,10),Color("795839"))
	draw_rect(Rect2(598,682,84,35),Color("898677"));draw_rect(Rect2(603,686,74,25),Color("b5aa8c"))
