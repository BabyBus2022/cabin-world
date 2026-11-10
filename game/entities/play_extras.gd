class_name PlayExtras
extends RefCounted
## drawPlayExtras from the original page. Geometry depends on the shared head
## and room module boxes, never on resident names or a particular sprite sheet.
static func ellipse(canvas: CanvasItem,at: Vector2,rx: float,ry: float,color: Color) -> void:
	var points := PackedVector2Array()
	var segments:=maxi(12,int(ceil(PI/acos(clampf(1.0-.05/maxf(1,maxf(rx,ry)),-1,1)))))
	for i in segments+1:points.append(at+Vector2(cos(TAU*i/segments)*rx,sin(TAU*i/segments)*ry))
	canvas.draw_polyline(points,color,1,true)

## Subdivide the original quadratic until its chord error is below .05 room pixels.
## Fixed 16-segment curves visibly kinked when the game was enlarged.
static func curve_points(a: Vector2,b: Vector2,c: Vector2,depth:=0) -> PackedVector2Array:
	if depth>=12 or (a-2*b+c).length()/4<=.05:
		return PackedVector2Array([a,c])
	var ab:=a.lerp(b,.5)
	var bc:=b.lerp(c,.5)
	var mid:=ab.lerp(bc,.5)
	var left:=curve_points(a,ab,mid,depth+1)
	var right:=curve_points(mid,bc,c,depth+1)
	left.append_array(right.slice(1))
	return left
static func curve(canvas: CanvasItem,a: Vector2,b: Vector2,c: Vector2,color: Color) -> void:
	canvas.draw_polyline(curve_points(a,b,c),color,1,true)
static func draw(canvas: CanvasItem,effect: Dictionary,sec: float,head: Rect2,feet: Vector2,modules: Dictionary,time: float,umbrella: bool) -> void:
	var hand := Vector2(head.end.x+2,head.end.y+10)
	var rows := []
	if umbrella:
		var center := Vector2(head.position.x+head.size.x/2,head.position.y-6)
		var points := PackedVector2Array([center+Vector2(-26,0)])
		for i in 17:points.append(center+Vector2(cos(PI+PI*i/16)*26,sin(PI+PI*i/16)*12))
		canvas.draw_colored_polygon(points,Color("bfe0efcc"))
		ActorEffects.r(rows,"#ffffff88",center.x-20,center.y-2,40,2)
		ActorEffects.r(rows,"#5b6270",center.x,center.y-2,1,26)
	if effect.is_empty() or sec>=float(effect.get("seconds",6)):
		AmbientArt.paint(canvas,rows)
		return
	var outcome: Dictionary=effect.outcome if effect.get("outcome") is Dictionary else {}
	var kind := str(effect.get("kind",""))
	var item: Dictionary=effect.item if effect.get("item") is Dictionary else {}
	if kind in ["pick","coins"] and not item.is_empty():
		var at := hand-Vector2(6,8)
		if kind=="pick":
			var m: Dictionary=modules.get(str(effect.get("module","")),{})
			var origin := Vector2(m.x+m.w/2,m.y+10) if not m.is_empty() else hand
			var q := WorldPresentation.eased(minf(1,sec/1.4))
			at=origin.lerp(at,q)-Vector2(0,sin(q*PI)*10)
		ActorEffects.r(rows,"#3c3941",at.x-1,at.y-1,8,10)
		ActorEffects.r(rows,{"snack":"#ff6f6c","drink":"#ff8a3d","icecream":"#fff4d6","daily":"#5aa6d6"}.get(item.get("shelf"),"#ffd34e"),at.x,at.y,6,8)
		ActorEffects.r(rows,"#ffffff99",at.x+1,at.y+1,2,3)
		if item.get("shelf")=="icecream":ActorEffects.r(rows,"#c8a35a",at.x+2,at.y+8,2,4)
	elif kind=="ducks":
		for k in 5:
			var t := fmod(sec*.8+k/5.0,1)
			ActorEffects.r(rows,"#e8c88a",hand.x+t*36+k*3,hand.y-6-sin(t*PI)*16+t*30,2,2)
	elif kind=="splash":
		for k in 6:
			var t := fmod(sec*1.4+k/6.0,1)
			ActorEffects.r(rows,"#bee1fa",feet.x-10+k*4+sin(k)*3,feet.y-2-sin(t*PI)*10,2,2,snappedf(.9*(1-t),.01))
		var radius := 6+fmod(sec,1)*10
		ellipse(canvas,feet,radius,radius*.35,Color(220/255.0,240/255.0,1,.7))
	elif kind=="kite":
		var flew: bool=outcome.get("flew",true)!=false
		var h := (150 if outcome.get("height")=="很高" else 110)*minf(1,sec/3) if flew else 6.0
		var kite := hand+Vector2((70 if flew else 30)+sin(time*1.3)*8,-h+cos(time*1.7)*5)
		curve(canvas,hand,hand+Vector2(30,-h*.3),kite+Vector2(0,8),Color("ffffffcc"))
		AmbientArt.cell(rows,"life/event-kite-draft.png",int(floorf(time*2))%2,2,1,[kite.x-16,kite.y-20,38,38])
	elif kind=="stones":
		var origin := feet+Vector2(6,-30)
		var p := minf(1,sec/1.2)
		if p<1:ActorEffects.r(rows,"#8a8f99",origin.x+40*p,origin.y+20*p-sin(p*PI)*16,3,2)
		for k in int(outcome.get("skips",3)):
			if sec<1.2+k*.35:break
			var t := minf(1,(sec-1.2-k*.35)/1.2)
			ellipse(canvas,Vector2(origin.x+40+k*22,feet.y-46+sin(k)*2),2+t*8,(2+t*8)*.4,Color(225/255.0,240/255.0,1,snappedf(.8*(1-t),.01)))
	elif kind in ["eat","drink"]:
		var at := hand-Vector2(6,6)
		if kind=="drink":
			ActorEffects.r(rows,"#ff8a3d",at.x,at.y,5,9);ActorEffects.r(rows,"#ffffff",at.x+1,at.y+2,3,2)
			for k in 3:
				var t := fmod(time*.8+k/3.0,1)
				ActorEffects.r(rows,"#ffffff",at.x+2+sin(t*6+k)*2,at.y-2-t*10,2,2,snappedf(.7*(1-t),.01))
		else:
			ActorEffects.r(rows,"#ffd34e",at.x,at.y,7,5);ActorEffects.r(rows,"#ff9ec7",at.x+1,at.y+1,3,2)
			for k in 3:ActorEffects.r(rows,"#f2d6a2",at.x+3+k*2,at.y+6+fmod(time*1.2+k/3.0,1)*10,1,1)
	AmbientArt.paint(canvas,rows)
