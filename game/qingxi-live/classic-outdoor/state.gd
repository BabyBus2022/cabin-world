extends "res://qingxi-live/rural_state.gd"
const CROPS={"cabbage":{"name":"白菜","seed":"seed","item":"veg","seconds":1200.0},"wheat":{"name":"小麦","seed":"wheat_seed","item":"wheat","seconds":1800.0},"carrot":{"name":"胡萝卜","seed":"carrot_seed","item":"carrot","seconds":1500.0}}
const EXTRA_NAMES={"wheat_seed":"小麦种子","carrot_seed":"胡萝卜种子"}
const EXTRA_PRICE={"wheat_seed":2,"carrot_seed":3}
const SALE={"veg":4,"wheat":3,"carrot":4,"milk":12,"wool":16,"fish":10}
func reset():
 super.reset()
 for k in EXTRA_NAMES:data.bag[k]=3;data.storage[k]=0
 data.selected_crop="cabbage";data.guide_done={};data.v01=true
 for c in data.crops:c.kind="cabbage"
func label(key:String)->String:return EXTRA_NAMES.get(key,ITEM_NAMES.get(key,key))
func price(key:String)->int:return EXTRA_PRICE.get(key,PRICES.get(key,0))
func buy(item:String)->String:
 if not EXTRA_PRICE.has(item):return super.buy(item)
 if data.coins<price(item):return "零钱不足"
 data.coins-=price(item);data.bag[item]+=1;return "买入"+label(item)+" ×1"
func advance(seconds:float):
 var dt=maxf(seconds,0.0)
 for c in data.crops:
  if not c.planted:continue
  var spec=CROPS.get(c.get("kind","cabbage"),CROPS.cabbage);var used=minf(dt,float(c.water))
  c.progress=minf(spec.seconds,float(c.progress)+used);c.water=maxf(0,float(c.water)-used)
 livestock.advance(dt*12.0)
 var p=data.pond
 if p.count>0:
  var used=minf(dt*8.0,float(p.feed));p.progress=minf(FISH_SECONDS,float(p.progress)+used);p.feed=maxf(0,float(p.feed)-used)
func crop_action(index:int)->String:
 if index<0 or index>=data.crops.size():return "没有这块田"
 var c=data.crops[index]
 if not c.planted:
  var kind=str(data.selected_crop);var spec=CROPS[kind]
  if data.bag[spec.seed]<1:return "缺少"+label(spec.seed)+"，去种子店购买"
  data.bag[spec.seed]-=1;c.kind=kind;c.planted=true;c.progress=0.0;c.water=0.0;data.guide_done.plant=true
  return "已种下"+spec.name+"，再按 E 浇水"
 var spec=CROPS[c.get("kind","cabbage")]
 if c.progress>=spec.seconds:
  data.bag[spec.item]+=2;data.bag[spec.seed]+=1;c.planted=false;c.progress=0.0;c.water=0.0;data.guide_done.harvest=true
  return "收获"+spec.name+" ×2、种子 ×1"
 c.water=14400.0;return "已浇水，湿润生长约 %d 分钟成熟"%int(spec.seconds/60)
func quick_grow(area_id:String)->String:
 if area_id!="field":return super.quick_grow(area_id)
 data.test_uses+=1
 for c in data.crops:
  if c.planted:c.progress=CROPS[c.get("kind","cabbage")].seconds
 return "测试：已种作物成熟"
func sell_items(items:Array)->String:
 var earned=0
 for item in items:
  earned+=int(data.bag.get(item,0))*int(SALE.get(item,0));data.bag[item]=0
 data.coins+=earned
 if earned>0:data.guide_done.sell=true
 return "出售获得 %d 币"%earned if earned>0 else "没有可出售的产物"
func store_items(take:bool)->String:
 var source=data.storage if take else data.bag;var target=data.bag if take else data.storage;var count=0
 for k in source:count+=int(source[k]);target[k]=int(target.get(k,0))+int(source[k]);source[k]=0
 return ("取回" if take else "存入")+str(count)+" 件物品"
func pond_action()->String:
 return super.pond_action().replace("8 小时长成","约 1 小时长成").replace("12 小时生长","约 1.5 小时生长").replace("乡村中心","鱼塘边的鱼苗铺")

