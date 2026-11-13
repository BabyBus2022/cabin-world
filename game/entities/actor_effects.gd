class_name ActorEffects
extends RefCounted
## Pixel glyphs and timing ported from actor-presentation.mjs, shared by skins.
const NOTES := ["#9fd8ef","#f6b4cf","#c9b6f2","#ffe08a"]
const PAINT := ["#3d4f86","#5a73b4","#dfe6f3","#2c3a63","#8fa3cf"]
const PASTEL := ["#ff9ec7","#ffd36e","#9fe0c8","#a9c8ff","#d6b0ff"]
static func hash_of(n: float) -> float:
	var x := sin(n*127.1+311.7)*43758.5453
	return x-floorf(x)
static func r(out: Array,c: String,x: float,y: float,w: float,h: float,a: float=1) -> void: AmbientArt.pixel(out,c,x,y,w,h,a)
static func heart(out: Array,x: float,y: float,c: String,big: bool,a: float=1) -> void:
	x=floorf(x+.5);y=floorf(y+.5)
	var rows := [[1,0,2,1],[4,0,2,1],[0,1,7,2],[1,3,5,1],[2,4,3,1],[3,5,1,1]] if big else [[0,0,2,1],[3,0,2,1],[0,1,5,1],[1,2,3,1],[2,3,1,1]]
	for p in rows:r(out,c,x+p[0],y+p[1],p[2],p[3],a)
	if big:r(out,"#ffffff",x+1,y+1,1,1,a)
static func star(out: Array,x: float,y: float,c: String,s: float=1,a: float=1) -> void:
	x=floorf(x+.5);y=floorf(y+.5)
	r(out,c,x-s,y,s*2+1,1,a);r(out,c,x,y-s,1,s*2+1,a)
	if s>1:r(out,c,x-1,y-1,3,3,a)
static func notes(g: Rect2,time: float) -> Array:
	var out := []
	for k in 4:
		var t := fmod(time*.55+k/4.0,1)
		var side := -1 if k%2 else 1
		var x := floorf((g.position.x+g.size.x+3 if side>0 else g.position.x-6)+side*t*5+sin(t*9+k)*2+.5)
		var y := floorf(g.position.y+10-t*18-absf(sin(time*6+k))*1.5+.5)
		var a := minf(1,(1-t)*1.6)*minf(1,t*6)
		var rows := [[0,5,2,2],[4,4,2,2],[1,0,1,6],[5,-1,1,6],[1,0,5,1]] if k%3==2 else [[0,5,3,2],[2,0,1,6],[3,1,1,1],[4,2,1,1]]
		for p in rows:r(out,NOTES[k],x+p[0],y+p[1],p[2],p[3],a)
	return out
static func sleep(g: Rect2,time: float) -> Array:
	var out := []
	for k in 3:
		var t := fmod(time*.32+k/3.0,1)
		var s := 2+floori(t*2+.5)
		var x := floorf(g.position.x+g.size.x-2+t*12+sin(t*6)*1.5+.5)
		var y := floorf(g.position.y-2-t*18+.5)
		var a := sin(t*PI)*.9
		var c := "#f3c6dc" if k==1 else "#cfe0f6"
		r(out,c,x,y,s+1,1,a)
		for i in range(1,s):r(out,c,x+s-i,y+i,1,1,a)
		r(out,c,x,y+s,s+1,1,a)
	var radius := 1+floori((sin(time*1.4)+1)+.5)
	var bx := floorf(g.position.x+g.size.x*.72+.5)
	var by := floorf(g.position.y+g.size.y*.62+.5)
	r(out,"#e8f4ff",bx-radius,by,radius*2+1,1,.55)
	r(out,"#e8f4ff",bx-radius+1,by-radius,radius*2-1,radius*2+1,.55)
	r(out,"#ffffff",bx-radius+1,by-radius+1,1,1,.55)
	return out
static func chat(g: Rect2,time: float) -> Array:
	var out := []
	var cy := floorf(g.position.y+g.size.y*.72+.5)
	r(out,"#ff8fb0",g.position.x+g.size.x*.2,cy,3,1,.35)
	r(out,"#ff8fb0",g.position.x+g.size.x*.68,cy,3,1,.35)
	var t := fmod(time*.4,1)
	if t<.7:heart(out,g.position.x+g.size.x+1+sin(t*6)*1.5,g.position.y-2-t*10,"#ff8fb8",false,sin(t/.7*PI)*.9)
	return out
static func paint(m: Rect2,seconds: float) -> Array:
	var out := []
	for i in mini(28,int(floorf(seconds*1.4))):
		r(out,PAINT[int(floorf(hash_of(i*3.1)*PAINT.size()))],m.position.x+m.size.x*.18+hash_of(i)*m.size.x*.62,m.position.y+m.size.y*.25+hash_of(i+.5)*m.size.y*.34,2 if hash_of(i+.7)>.6 else 1,1)
	return out
static func dust(rows: Array,now: float) -> Array:
	var out := []
	for d in rows:
		var p: float=(now-d.at)/520
		var radius := 1+p*3
		var alpha := floorf((1-p)*.75*100+.5)/100
		for offsets in [[-radius,0,1],[radius*.8,-radius*.3,1],[0,-radius*.7,1.3]]:
			var x := floorf(d.x+offsets[0]+.5)
			var y := floorf(d.y-1+offsets[1]+.5)
			var k := maxf(1,floorf(offsets[2]*(1+p*1.5)+.5))
			r(out,"#f0e2cc",x-k,y,k*2+1,1,alpha);r(out,"#f0e2cc",x-k+1,y-1,k*2-1,1,alpha);r(out,"#f0e2cc",x-k+1,y+1,k*2-1,1,alpha)
	return out
static func effect(kind: String,b: Rect2,g: Rect2,p: float,sec: float) -> Array:
	var out := []
	var fade := minf(1,p*6)*minf(1,(1-p)*5)
	var cx := b.position.x+b.size.x/2
	var top := b.position.y
	match kind:
		"sand":
			# A tiny whale drawn gradually at her feet, instead of a generic sparkle.
			var pixels:=[[0,2],[1,1],[2,0],[3,0],[4,0],[5,1],[6,2],[7,2],[8,1],[9,0],[9,1],[8,2],[7,3],[6,4],[5,5],[4,5],[3,5],[2,4],[1,4],[0,3],[2,2]]
			var count:int=mini(pixels.size(),int(p*pixels.size()*1.4)+1)
			for i in count:
				r(out,"#947958",cx+float(pixels[i][0])*1.5-7,b.end.y+float(pixels[i][1])*1.2+1,2,1,fade)
			r(out,"#e4d0a4",cx+sin(sec*2)*5,b.end.y+2,2,1,fade)

		"hearts":
			for k in 5:
				var t := fmod(sec*.45+k/5.0,1)
				heart(out,cx-6+hash_of(k)*12+sin(t*7+k)*3,top-2-t*20,"#ff8fb8" if k%2 else "#ff6fa3",k==0,fade*sin(t*PI))
		"sparkle":
			for k in 7:
				var tw := (sin(sec*5+k*2.3)+1)/2
				star(out,b.position.x+hash_of(k*1.7)*b.size.x,b.position.y+hash_of(k*2.9)*maxf(8,b.size.y*.7)-4,"#fff6c4" if k%3 else "#ffffff",2 if tw>.75 else 1,fade*tw)
		"water":
			for k in 6:
				var t := fmod(sec*1.2+k/6.0,1)
				var x := floorf(cx-5+hash_of(k)*10+.5)
				var y := floorf(top-6+t*(b.size.y*.5)+.5)
				var a := fade*(1-t*.6)
				r(out,"#7cc4f2",x,y,1,1,a);r(out,"#7cc4f2",x-1,y+1,3,2,a);r(out,"#ffffff",x-1,y+1,1,1,a)
			for k in 3:star(out,b.position.x+hash_of(k+9)*b.size.x,top+hash_of(k+3)*8,"#ffffff",1,fade*(sin(sec*4+k*2)+1)/2)
		"petals":
			for k in 8:
				var t := fmod(sec*.35+k/8.0,1)
				var x := floorf(b.position.x+hash_of(k)*b.size.x+sin(t*6+k)*6+t*10+.5)
				var y := floorf(top+t*(b.size.y+30)+.5)
				var a := fade*sin(t*PI)
				var c := "#ffc2d8" if k%2 else "#ffe3ee"
				if sin(sec*3+k)>0:r(out,c,x,y,2,1,a);r(out,c,x+1,y+1,1,1,a)
				else:r(out,c,x,y,1,2,a);r(out,c,x+1,y,1,1,a)
		"tea":
			for k in 5:
				var t := fmod(sec*.5+k/5.0,1)
				var x := floorf(cx+sin(t*5+k)*3+.5)
				var y := floorf(top+2-t*16+.5)
				r(out,"#f6f2ea",x,y,2,2,fade*.6*(1-t));r(out,"#f6f2ea",x+1,y-1,1,1,fade*.6*(1-t))
			heart(out,g.position.x+g.size.x/2-2,g.position.y-4-sin(sec*2)*2,"#ffb0c8",false,fade*minf(1,sec/2)*(.6+.4*sin(sec*3)))
		"rainbow":
			for k in 10:
				var t := fmod(sec*.6+k/10.0,1)
				r(out,PASTEL[k%5],b.position.x+b.size.x*.2+hash_of(k)*b.size.x*.6+sin(t*6)*2,b.position.y+b.size.y*.2-t*14,2,2,fade*sin(t*PI))
		"stars":
			for k in 6:
				var a := sec*3+k*PI/3
				var radius := 14+sin(sec*2)*2
				star(out,g.position.x+g.size.x/2+cos(a)*radius,g.position.y+g.size.y*.6+sin(a)*radius*.5,PASTEL[k%5],1 if k%2 else 2,fade*(.6+.4*sin(sec*6+k)))
		"leaf":
			for k in 6:
				var t := fmod(sec*.3+k/6.0,1)
				var x := floorf(b.position.x+hash_of(k)*b.size.x+sin(t*7+k)*8+.5)
				var y := floorf(b.position.y+b.size.y*.2+t*b.size.y*.8+.5)
				var c := "#d4a33a" if k%2 else "#7fb35c"
				r(out,c,x,y,3,2,fade*sin(t*PI));r(out,c,x+1,y-1,1,1,fade*sin(t*PI))
		"butterfly":
			for k in 2:
				var a := sec*1.6+k*3
				var x := floorf(cx+cos(a)*20+k*6+.5)
				var y := floorf(top-6+sin(a*1.7)*8+.5)
				var wing := 3 if int(floorf(sec*10+k))%2 else 2
				var c := "#ffffff" if k else "#ffd34e"
				r(out,c,x-wing,y,wing,3,fade);r(out,c,x+1,y,wing,3,fade);r(out,"#3c3941",x,y,1,3,fade)
		"coins":
			var alpha := fade
			for k in 4:
				var t := fmod(sec*.7+k/4.0,1)
				alpha=fade*sin(t*PI)
				var x := floorf(cx-8+k*5+.5)
				var y := floorf(top-4-t*14+.5)
				r(out,"#ffd34e",x,y,4,4,alpha);r(out,"#e0a33a",x+1,y+1,2,2,alpha)
			heart(out,cx-3,top-24+sin(sec*3)*2,"#ff8fb8",false,alpha)
		"idea":
			var x := floorf(cx+.5)
			var y := floorf(top-12-absf(sin(sec*3))*3+.5)
			r(out,"#ffe58a",x-2,y,5,4,fade);r(out,"#ffe58a",x-1,y-1,3,1,fade);r(out,"#ffe58a",x-1,y+4,3,1,fade);r(out,"#ffffff",x-1,y+1,1,1,fade);r(out,"#b9a27a",x-1,y+5,3,1,fade)
			for k in 4:star(out,x+cos(k*PI/2+sec)*7,y+2+sin(k*PI/2+sec)*5,"#fff3b0",1,fade*(.5+.5*sin(sec*6+k)))
	return out
