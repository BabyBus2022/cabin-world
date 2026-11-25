extends "res://core/dsh_economy_base.gd"

func _answer(frame:Dictionary)->Dictionary:
	if frame.get("op")=="qingxi" and frame.get("act") in ["crop_targets","look","survey"]:
		var actor=str(frame.get("actor",""))
		var state=people.get(actor,{})
		var reply={"type":"economy.result","actor":actor,"id":frame.get("id"),"ok":true,"state":state}
		var issue=super._apply(state,"qingxi",frame,reply)
		if issue!="":reply.ok=false;reply.error=issue
		return reply
	if frame.get("op")=="shop_offers":
		var day:=today()
		var prices:Dictionary={}
		for key in catalog:
			var p:Dictionary=catalog[key]
			if p.get("shelf")!="restaurant" and available_today(p,day):prices[key]=price_today(p,day)
		return {"type":"economy.result","id":frame.get("id"),"actor":frame.get("actor"),"ok":true,"day":day,"prices":prices}
	return super._answer(frame)

func _apply(s:Dictionary,op:String,frame:Dictionary,out:Dictionary)->String:
	var key:=str(frame.get("product",""))
	if op=="meal_rating":
		var food:Dictionary=s.foods.get(key,{})
		var eaten:=int(food.get("eaten",0))
		var rating:=str(frame.get("choice",""))
		if eaten<=0 or catalog.get(key,{}).get("shelf","")!="restaurant":return "尚未确认吃过这道菜"
		if rating not in ["like","neutral","dislike"]:return "请选择喜欢、一般或不喜欢"
		var first_like:bool=rating=="like" and int(food.get("likedMeal",0))<eaten
		food["mealRating"]=rating
		var now:=SharedFeed.now_ms()
		var feeling:Dictionary=s.get("feeling",{}).duplicate(true)
		var tastes:Dictionary=feeling.get("tastes",{}).duplicate(true)
		tastes[key]={"score":{"like":2,"dislike":-2,"neutral":0}[rating],"lastAt":now,"count":eaten}
		feeling["tastes"]=tastes
		s["feeling"]=feeling
		if first_like:
			food["likedMeal"]=eaten
			var event:={"type":"meal_rating","liked":true,"product":catalog[key],"thought":str(frame.get("reason","")).left(80)}
			var params:=frame.duplicate()
			params.merge({"now":now,"event":event,"day":today()},true)
			return super._apply(s,"life_event",params,out)
		return ""
	var failure:=super._apply(s,op,frame,out)
	if failure=="" and frame.get("recordEating",false) and ((op=="consume" and frame.get("kind","")=="eaten") or (op=="buy" and frame.get("drinkHere")==true and catalog.get(key,{}).get("kind")=="drink")):
		var product:Dictionary=catalog[key]
		var liked=Life.liked_foods(str(frame.get("who","")),s.get("feeling",{}),[product]).has(product.name)
		var params=frame.duplicate()
		params.merge({"now":SharedFeed.now_ms(),"day":today(),"event":{"type":"eat","product":product,"liked":liked,"thought":str(frame.get("thought","")).left(200)}},true)
		var detail={}
		var issue=super._apply(s,"life_event",params,detail)
		if issue!="":return issue
		out["foodNotes"]=detail.get("notes",[])
	if failure==NO_MONEY and op=="buy" and catalog.has(key):
		return "%s需要 %d 元，现有 %d 元。"%[catalog[key].name,price_today(catalog[key],today()),s.wallet.coins]
	if failure=="" and op=="qingxi" and str(frame.get("act","")) not in ["approach","look","survey","guide","crop_targets"] and s.get("life") is Dictionary and out.get("text","")!="":
		s.life.thought={"text":str(out.text).left(80),"at":SharedFeed.now_ms()}
	return failure

