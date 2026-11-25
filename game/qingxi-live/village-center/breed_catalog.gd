extends RefCounted

const BREEDS = {
	"cow": ["荷斯坦牛","娟姗牛","苏格兰高地牛","腰带加洛威牛"], "sheep": ["美利奴羊","萨福克羊","雅各布羊","瓦莱黑鼻羊"],
	"pig": ["大白猪","巴克夏猪","格洛斯特花斑猪","曼加利察绵羊猪"], "chicken": ["白来航鸡","洛岛红鸡","丝羽乌骨鸡","银边怀恩多特鸡"]
}
# Game specialties: an extra item in the corresponding harvest or processing batch.
const SPECIALTY={"cow":["milk","milk","beef","hide"],"sheep":["wool","mutton","pelt","wool"],"pig":["pork","pork","pork","pork"],"chicken":["egg","poultry","feather","egg"]}
static func stock_cost(kind:String,coat:int)->int:
	return roundi(float(YOUNG_PRICE[kind])*(1.5 if coat>=2 else 1.0))
static func harvest_amount(a:Dictionary)->int:
	return 3 if SPECIALTY[a.kind][a.coat]==PRODUCT.get(a.kind,"") and breed_trait(a)=="yield" else 2
const KIND = {"cow":"牛", "sheep":"羊", "pig":"猪", "chicken":"鸡"}
const MAX_HP = {"cow":140, "sheep":90, "pig":110, "chicken":55}
const YOUNG_PRICE = {"cow":60, "sheep":50, "pig":40, "chicken":18}
const ADULT_PRICE = {"cow":125, "sheep":100, "pig":90, "chicken":36}
const MATURITY = {"cow":172800.0, "sheep":86400.0, "pig":259200.0, "chicken":43200.0}
const TERM = {"cow":28800.0, "sheep":21600.0, "pig":14400.0, "chicken":7200.0}
const INTERVAL = {"cow":28800.0, "sheep":43200.0, "chicken":14400.0}
const PRODUCT = {"cow":"milk", "sheep":"wool", "chicken":"egg"}
const YIELD = {"cow":["beef","hide"], "sheep":["mutton","pelt"], "pig":["pork"], "chicken":["poultry","feather"]}
const LABEL = {"milk":"牛奶", "wool":"羊毛", "egg":"鸡蛋", "beef":"牛肉", "hide":"牛皮", "mutton":"羊肉", "pelt":"羊皮", "pork":"猪肉", "poultry":"鸡肉", "feather":"羽毛"}
const BASE = {"milk":12,"wool":16,"egg":6,"beef":42,"hide":32,"mutton":35,"pelt":25,"pork":48,"poultry":20,"feather":5}
const TRAITS={"cow":["output","yield","line","growth"],"pig":["growth","yield","term","line"],"sheep":["output","growth","line","yield"],"chicken":["output","growth","line","yield"]}
const TRAIT_NAMES={"output":"产出间隔缩短 20%","growth":"幼崽成长快 25%","term":"妊娠时间缩短 25%","line":"配种升品概率多 12 个百分点","yield":"擅长产物多一份"}
static func breed_trait(a:Dictionary)->String:return TRAITS[a.kind][a.coat]
static func interval(a:Dictionary)->float:return INTERVAL[a.kind]*(.8 if breed_trait(a)=="output" else 1.0)
const GRADE = ["普通","优良","珍品","典藏"]
const MULT = [1.0,1.5,2.25,3.25]

static func lot(item:String, quality:int)->String:
	return item if quality == 1 else "%s:q%d" % [item,quality]
static func grade(key:String)->int:
	return clampi(int(key.get_slice(":q",1)),1,4) if ":q" in key else 1
static func price(key:String)->int:
	return roundi(float(BASE.get(key.get_slice(":",0),0))*MULT[grade(key)-1])
static func young_key(kind:String, coat:int, sex:String)->String:
	return "young_%s:%d:%s" % [kind,coat,sex]
static func item_name(key:String)->String:
	var item=key.get_slice(":",0)
	if item.begins_with("young_"):
		var kind=item.substr(6)
		if not BREEDS.has(kind):return key
		if ":" not in key:return "幼"+KIND[kind]
		return "%s幼崽 · %s" % [BREEDS[kind][int(key.get_slice(":",1))],"母" if key.ends_with(":f") else "公"]
	return GRADE[grade(key)-1]+" · "+LABEL[item] if LABEL.has(item) else key
static func breed_name(a:Dictionary)->String:
	var breeds=BREEDS[a.kind]
	var name_=str(breeds[a.coat])
	if a.genes[0]!=a.genes[1]:name_+="花色 · 杂交"
	return name_
static func live_price(a:Dictionary)->int:
	var base=float(ADULT_PRICE[a.kind]) if a.age>=MATURITY[a.kind] else float(YOUNG_PRICE[a.kind])*0.75
	return roundi(base*MULT[int(a.quality)-1])

