extends "res://core/dsh_life_base.gd"

func _wish_passes(id:String,e:Dictionary)->bool:
	if e.get("type")=="meal_rating":return id=="treat" and e.get("liked",false)
	return super._wish_passes(id,e)

func experience(a:Dictionary)->Dictionary:
	var result:=super.experience(a)
	var use:=str(a.get("use",""))
	var label:=str(a.get("label",""))
	if use in ["buy","take","wear","return","put_back","change","change_back","dock","remove"] and label!="":
		result.last=label+"。"
	return result

func apply_event(saved,event_in:Dictionary,who:String,day:String,now:float,weather:Dictionary)->Dictionary:
	var result:=super.apply_event(saved,event_in,who,day,now,weather)
	var life:Dictionary=result.life
	var event_type:=str(event_in.get("type",""))
	if event_type=="arcade" and (not event_in.get("result","") in ["won","lost","draw"] or (saved is Dictionary and event_in.get("matchId") in saved.get("records",{}).get("arcadeMatches",[]))):return result
	var text:=str(event_in.get("thought","")).strip_edges().left(80)
	var flash=life.get("flash")
	var fresh_flash:bool=flash is Dictionary and (not saved is Dictionary or flash!=saved.get("flash"))
	if fresh_flash:flash.until=minf(float(flash.until),now+5*60000)
	var relaxing:bool=event_type=="use" and event_in.get("use") in ["soak","swim","shower","rest"]
	var liked:bool=event_type=="eat" and event_in.get("liked",false)
	if not fresh_flash and (relaxing or liked):
		life.flash={"word":"放松" if relaxing else "满足","icon":"😊","cause":str(event_in.get("label","刚休息了一会")) if relaxing else "刚吃到喜欢的"+str(event_in.get("product",{}).get("name","食物")),"until":now+3*60000}
	if text=="":
		match event_type:
			"arcade":
				text="刚才的%s%s了。"%[event_in.get("name","对局"),{"won":"赢","lost":"输","draw":"打平"}.get(event_in.get("result"),"结束")]
			"eat":text="刚吃了"+str(event_in.get("product",{}).get("name","东西"))+"。"
			"use":
				if event_in.get("label","")!="":text="刚刚"+str(event_in.label)+"。"
	if text!="":life.thought={"text":text.left(80),"at":now}
	return result

func mood_of(who:String,feeling:Dictionary,life,weather:Dictionary,now:float,sleeping:bool)->Dictionary:
	# Old saves can still carry the previous forty-minute post-loss timer.
	if life is Dictionary and life.get("flash") is Dictionary and life.flash.get("word")=="有点难过":
		var remaining:=float(life.flash.get("until",0))-now
		if remaining>5*60000 or float(feeling.get("joy",45))>=85:
			var adjusted:Dictionary=life.duplicate()
			adjusted.flash=null
			return super.mood_of(who,feeling,adjusted,weather,now,sleeping)
	return super.mood_of(who,feeling,life,weather,now,sleeping)

