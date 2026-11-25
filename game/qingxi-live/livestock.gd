extends RefCounted
const GROWTH={"cow":172800.0,"sheep":86400.0,"pig":259200.0}
const OUTPUT={"cow":28800.0,"sheep":86400.0,"pig":0.0}
const NAMES={"cow":"奶牛","sheep":"绵羊","pig":"猪"}
const FOOD={"cow":"hay","sheep":"hay","pig":"pig_feed"}
const TREAT={"cow":"wheat","sheep":"wheat","pig":"carrot"}
const CAPACITY=6
const PENS={"cow":Rect2(160,380,260,235),"sheep":Rect2(515,485,300,220),"pig":Rect2(900,350,250,240)}
## A map can move the pens (village-center ranch); absent kinds use PENS.
static var pen_override:Dictionary={}
static func pen(kind:String)->Rect2:
	return pen_override.get(kind,PENS[kind])
var data:Dictionary
func _init():
	data={"next_id":1,"herd":[],"pens":{}}
	for kind in NAMES:
		data.pens[kind]={"feed":86400.0,"water":172800.0,"grass":172800.0 if kind=="sheep" else 0.0,"dirt":0.0}
		for i in 2:add(kind)
func members(kind:String)->Array:
	return data.herd.filter(func(a):return a.kind==kind)
func animal(id:String)->Dictionary:
	for a in data.herd:
		if a.id==id:return a
	return {}
func add(kind:String)->Dictionary:
	var id=str(data.next_id);data.next_id+=1
	var pen:Rect2=pen(kind)
	var n=members(kind).size()
	var p=pen.position+Vector2(85+(n%2)*90,110+(n/2)*30)
	var a={"id":id,"kind":kind,"age":0.0,"progress":0.0,"ready":0,"shorn":false,"cooldown":0.0,"love":0.0,"pos":[p.x,p.y]}
	data.herd.append(a);return a
func advance(dt:float):
	dt=maxf(0,dt)
	for kind in NAMES:
		var herd=members(kind);var p:Dictionary=data.pens[kind];var count=herd.size()
		if kind=="sheep":p.grass=minf(259200.0,float(p.grass)+dt*0.25)
		if count==0:continue
		var available=float(p.feed)+(float(p.grass) if kind=="sheep" else 0.0)
		var usable=minf(dt,minf(available/count,float(p.water)/count))
		var feed_used=usable*count
		if kind=="sheep":
			var grazed=minf(feed_used,float(p.grass));p.grass-=grazed;feed_used-=grazed
		p.feed=maxf(0,float(p.feed)-feed_used);p.water=maxf(0,float(p.water)-usable*count)
		var efficiency=0.65 if kind=="pig" and p.dirt>=80 else 1.0
		if kind=="pig":p.dirt=minf(100,float(p.dirt)+usable*count/86400.0*15.0)
		for a in herd:
			a.cooldown=maxf(0,float(a.cooldown)-dt);a.love=maxf(0,float(a.love)-dt)
			var before=float(a.age);var active=usable*efficiency
			a.age=minf(GROWTH[kind],before+active)
			if kind=="sheep" and before<GROWTH[kind] and a.age>=GROWTH[kind]:a.ready=1;a.progress=OUTPUT[kind];a.shorn=false
			var adult_time=maxf(0,active-maxf(0,GROWTH[kind]-before))
			if OUTPUT[kind]>0 and a.ready==0:
				a.progress=minf(OUTPUT[kind],float(a.progress)+adult_time)
				if a.progress>=OUTPUT[kind]:a.ready=1;a.shorn=false
func feed_pen(kind:String,bag:Dictionary)->String:
	var key=FOOD[kind]
	if bag[key]<1:return "缺少"+("干草" if key=="hay" else "猪饲料")
	if data.pens[kind].feed>=members(kind).size()*172800+86400:return "食槽已足够，不必继续添加"
	bag[key]-=1;data.pens[kind].feed+=86400.0
	return "已向"+NAMES[kind]+"食槽加料：一袋可供一只动物一天"
func water_pen(kind:String)->String:
	data.pens[kind].water=maxi(1,members(kind).size())*172800.0
	return "水槽已加满，可供当前动物饮用两天"
func clean_pen(kind:String)->String:
	data.pens[kind].dirt=0.0
	return "圈舍已清理干净"
func treat(id:String,bag:Dictionary)->String:
	var a=animal(id)
	if a.is_empty():return "动物已离开"
	var key=TREAT[a.kind]
	if bag[key]<1:return "需要"+("小麦" if key=="wheat" else "胡萝卜")
	if a.love>0:return "它已经愿意亲近同伴，不用重复喂"
	if a.age>=GROWTH[a.kind] and a.cooldown>0:return "繁殖后还需休息 %.1f 小时"%(a.cooldown/3600)
	bag[key]-=1
	if a.age<GROWTH[a.kind]:
		a.age=minf(GROWTH[a.kind],a.age+GROWTH[a.kind]*0.08)
		if a.kind=="sheep" and adult(a):a.ready=1;a.progress=OUTPUT.sheep;a.shorn=false
		return "喂食幼崽，成长加快了一些"
	a.love=600.0
	return "它愿意亲近同伴了；同圈另一只成年动物也喂食后可繁殖"
func breed()->Array:
	var babies=[]
	for kind in NAMES:
		var eligible=members(kind).filter(func(a):return a.age>=GROWTH[kind] and a.love>0 and a.cooldown<=0)
		if eligible.size()<2:continue
		var p:Dictionary=data.pens[kind]
		if p.water<=0 or (p.feed<=0 and p.grass<=0):continue
		var a:Dictionary=eligible[0];var b:Dictionary=eligible[1]
		if Vector2(a.pos[0],a.pos[1]).distance_to(Vector2(b.pos[0],b.pos[1]))>52:continue
		a.love=0.0;b.love=0.0;a.cooldown=21600.0;b.cooldown=21600.0
		var baby=add(kind);baby.pos=a.pos.duplicate();babies.append(baby.id)
	return babies
func collect(id:String,bag:Dictionary)->String:
	var a=animal(id)
	if a.is_empty():return "动物已离开"
	if a.kind=="pig":return "猪走育肥路线：成年后可出售，不会定时掉落产品"
	if a.age<GROWTH[a.kind]:return "幼崽还不能"+("挤奶" if a.kind=="cow" else "剪毛")
	if a.ready==0:return "还需要照料一段时间，才能再次"+("挤奶" if a.kind=="cow" else "剪毛")
	var key="milk" if a.kind=="cow" else "wool"
	bag[key]+=2;a.ready=0;a.progress=0.0
	if a.kind=="sheep":a.shorn=true
	return "挤奶完成：牛奶 ×2" if a.kind=="cow" else "剪毛完成：羊毛 ×2；吃草后会重新长毛"
func grow_all():
	for a in data.herd:
		if a.kind=="sheep" and not adult(a):a.ready=1;a.progress=OUTPUT.sheep;a.shorn=false
		a.age=GROWTH[a.kind]
func produce_all():
	for a in data.herd:
		if a.kind!="pig" and a.age>=GROWTH[a.kind]:a.ready=1;a.progress=OUTPUT[a.kind];a.shorn=false
func adult(a:Dictionary)->bool:return a.age>=GROWTH[a.kind]
func weight(a:Dictionary)->int:return int(12+88*clampf(float(a.age)/GROWTH.pig,0,1))

