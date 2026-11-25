extends RefCounted
const SHOPS={
	"seed":{"name":"种子农资店","buy":["seed","wheat","carrot"],"sell":["veg"]},
	"livestock":{"name":"畜牧用品店","buy":["hay","pig_feed","wheat","carrot"],"sell":["milk","wool"]},
	"fish":{"name":"鱼苗与渔业用品店","buy":["fry","fish_feed"],"sell":["fish"]}}
static func sell(sim,kind:String)->String:
	var amount=0;var count=0
	for item in SHOPS[kind].sell:
		var n=int(sim.data.bag[item]);count+=n;amount+=n*int(sim.SELL[item]);sim.data.bag[item]=0
	sim.data.coins+=amount
	return "本店收购产物 ×%d，获得 %d 币"%[count,amount] if count>0 else "背包里没有本店收购的产物"
