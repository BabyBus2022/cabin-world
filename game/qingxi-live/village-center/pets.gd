extends RefCounted
















const Rules:= preload("res://qingxi-live/village-center/pets_rules.gd")
const PETS_KEY:= "pets"
const ROSTER_VERSION:= 2

var data: Dictionary
var rng:= RandomNumberGenerator.new()

func _init(farm_data: Dictionary):
 data = farm_data
 rng.randomize()
 ensure(data)


static func ensure(farm_data: Dictionary) -> bool:
 if not farm_data is Dictionary:
  return false
 var created:= false
 if not farm_data.has(PETS_KEY) or not farm_data [PETS_KEY] is Dictionary:
  farm_data [PETS_KEY] = {"version": ROSTER_VERSION, "next_id": 1, "list": []}
  created = true
 var state: Dictionary = farm_data [PETS_KEY]
 if not state.get("list", null) is Array:
  state ["list"] = []
 if not(state.get("next_id", null) is int or state.get("next_id", null) is float):
  state ["next_id"] = 1
 if int(state.get("version", 0)) < ROSTER_VERSION:
  state ["version"] = ROSTER_VERSION
 return created

func state() -> Dictionary:
 ensure(data)
 return data [PETS_KEY]

func list() -> Array:
 var s:= state()
 var l = s.get("list", [])
 return l if l is Array else []

func count() -> int:
 return list().size()

func pet(id: String) -> Dictionary:
 for p in list():
  if p is Dictionary and str(p.get("id", "")) == id:
   return p
 return {}


func pets_of(kind: String) -> Array:
 var out:= []
 for p in list():
  if p is Dictionary and str(p.get("kind", "")) == kind:
   out.append(p)
 return out


func pets_of_breed(kind: String, breed: String) -> Array:
 var want:= Rules.breed_key_of(kind, breed)
 var out:= []
 for p in pets_of(kind):
  if Rules.breed_of(p) == want:
   out.append(p)
 return out


func find(key: String) -> Dictionary:
 var t:= str(key).strip_edges().replace("，", ":").replace(",", ":")
 if t == "":
  return {}
 var head:= t.split(":", false)
 var last:= str(head [head.size() - 1]).strip_edges() if head.size() > 0 else t
 var found:= pet(last)
 if not found.is_empty():
  return found

 for p in list():
  if p is Dictionary and str(p.get("name", "")).strip_edges() == last:
   return p
 return {}

func _now() -> float:
 return Time.get_unix_time_from_system()

func _id_next() -> String:
 var s:= state()
 var n:= int(s.get("next_id", 1))
 s ["next_id"] = n + 1
 return str(n)




func adopt(kind: String, now: float = 0.0) -> Dictionary:
 return adopt_of(kind, "", now)


func adopt_of(kind: String, breed: String, now: float = 0.0) -> Dictionary:
 if not Rules.known_kind(kind):
  return {}
 var key:= Rules.breed_key_of(kind, breed)
 if key == "":
  return {}
 if now <= 0.0:
  now = _now()
 var pet:= {
  "id": _id_next(), "kind": kind, "breed": key,
  "stage": "baby", "grown_at": 0.0,
  "name": "", "named_by": "", "named_at": 0.0,
  "food": 70.0, "bond": Rules.bond_start(),
  "away_until": 0.0, "last_away": 0.0, "last_rub": 0.0,
  "last_play": now, "last_walk": 0.0,
  "gift_clock": 0.0, "gifts": 0, "guards": 0, "guard_mark": 0.0,
  "born_at": now,
 }
 if kind == "dog":
  pet ["last_walk"] = now
 list().append(pet)
 return pet



func advance(dt: float, now: float = 0.0) -> void:
 if dt <= 0.0 or not Rules.ok():
  return
 if now <= 0.0:
  now = _now()
 var rw:= Rules.rewards()
 var gift_interval:= float(rw.get("gift_interval_seconds", 5400.0))
 var max_rolls:= int(rw.get("max_rolls_per_advance", 24))
 var cat_gift: Dictionary = rw.get("cat_gift", {})
 for pet in list():
  if not pet is Dictionary:
   continue
  var kind:= str(pet.get("kind", ""))
  if not Rules.known_kind(kind):
   continue

  Rules.ensure_pet(pet)

  Rules.advance_stage(pet, now)
  _advance_food(pet, kind, dt, now)
  _advance_bond(pet, kind, dt, now)
  if kind == "cat":
   _advance_cat_away(pet, now)
   _advance_cat_gifts(pet, now, dt, gift_interval, max_rolls, cat_gift)
 _update_next_id()

func _advance_food(pet: Dictionary, kind: String, dt: float, now: float) -> void:
 var mult:= 1.0
 if kind == "cat" and Rules.is_away(pet, now):
  var away = Rules.kind_rules("cat").get("away", {})
  mult = float(away.get("food_multiplier_away", 0.5)) if away is Dictionary else 0.5
 var per_point:= Rules.food_seconds_per_point(kind)
 pet ["food"] = clampf(Rules.food_of(pet) - dt / maxf(1.0, per_point) * mult, 0.0, 100.0)

func _advance_bond(pet: Dictionary, kind: String, dt: float, now: float) -> void:
 var patience:= Rules.bond_patience_hours(kind) * 3600.0
 var last:= float(pet.get("last_play", 0.0))
 if kind == "dog":
  last = Rules.dog_last_company(pet)
 if last <= 0.0:
  last = now
  pet ["last_play"] = now
 var idle:= now - last - patience
 if idle <= 0.0:
  return
 var hours:= minf(idle, dt) / 3600.0
 var mult:= 1.0
 if kind == "dog":
  var ax = Rules.kind_rules("dog").get("anxious", {})
  if ax is Dictionary and Rules.anxious(pet, now):
   mult = float(ax.get("bond_decay_multiplier", 2.5))

 pet ["bond"] = clampf(Rules.bond_of(pet) - Rules.bond_decay_per_hour(kind) * mult * Rules.bond_decay_mult(pet) * hours, 0.0, 100.0)


func _advance_cat_away(pet: Dictionary, now: float) -> void:
 var away: Dictionary = Rules.kind_rules("cat").get("away", {})
 if not away is Dictionary:
  return
 var until:= float(pet.get("away_until", 0.0))
 if until > 0.0 and until <= now:
  pet ["away_until"] = 0.0
  pet ["last_away"] = now
  return
 if until > now:
  return
 var bond:= Rules.bond_of(pet)
 var home_minutes:= float(away.get("home_minutes", 15.0))
 if bool(away.get("home_scale_by_bond", true)):
  home_minutes *= maxf(0.35, bond / 100.0)
 var last_away:= float(pet.get("last_away", 0.0))
 if last_away <= 0.0:
  pet ["last_away"] = now
  return
 if now - last_away < home_minutes * 60.0:
  return
 var scale:= 1.0 + (1.0 - bond / 100.0) * float(away.get("away_scale_by_bond", 1.0))
 var lo:= float(away.get("min_minutes", 10.0))
 var hi:= maxf(lo, float(away.get("max_minutes", 40.0)))
 var minutes:= rng.randf_range(lo, hi) * scale
 pet ["away_until"] = now + minutes * 60.0



func _advance_cat_gifts(pet: Dictionary, now: float, dt: float, interval: float, max_rolls: int, gift: Dictionary) -> void:
 if gift.is_empty():
  return
 var bond:= Rules.bond_of(pet)
 if bond < float(gift.get("min_bond", 0.0)):
  return
 pet ["gift_clock"] = float(pet.get("gift_clock", 0.0)) + dt
 var rolls:= 0
 while float(pet ["gift_clock"]) >= interval and rolls < max_rolls:
  pet ["gift_clock"] = float(pet ["gift_clock"]) - interval
  rolls += 1
  var chance:= float(gift.get("base_chance", 0.2))
  if bool(gift.get("chance_scales_with_bond", true)):
   chance *= bond / 100.0
  chance *= Rules.gift_chance_mult(pet)
  if rng.randf() >= chance:
   continue
  var got:= _award_tier(pet, gift.get("tiers", []), now)
  if not got.is_empty():
   pet ["gifts"] = int(pet.get("gifts", 0)) + 1
   pet ["bond"] = clampf(Rules.bond_of(pet) + float(gift.get("bond_gain", 4.0)) * Rules.gift_bond_mult(pet), 0.0, 100.0)


func _award_tier(pet: Dictionary, tiers: Array, now: float) -> Dictionary:
 var bond:= Rules.bond_of(pet)
 var chosen: Dictionary = {}
 for tier in tiers:
  if tier is Dictionary and bond >= float(tier.get("bond_at_least", 0.0)):
   chosen = tier
   break
 if chosen.is_empty():
  return {}
 var items: Array = chosen.get("items", [])
 if items.is_empty():
  return {}
 var pair = items [rng.randi_range(0, items.size() - 1)]
 if not pair is Array or pair.size() < 2:
  return {}
 var key:= str(pair [0])
 var n:= int(pair [1])
 var bag = data.get("bag", null)
 if not bag is Dictionary:
  return {}
 bag [key] = int(bag.get(key, 0)) + n
 pet ["last_gift"] = now
 return {"item": key, "count": n, "label": str(chosen.get("label", key))}




func feed(pet_id: String, bag: Dictionary, now: float = 0.0) -> String:
 var pet:= find(pet_id)
 if pet.is_empty():
  return "没有这只宠物"
 if now <= 0.0:
  now = _now()
 var kind:= str(pet.get("kind", ""))
 var key:= _feed_key(kind, bag)
 if key == "":
  return "背包里没有%s吃的东西" % Rules.kind_cn(kind)
 bag [key] = int(bag.get(key, 0)) - 1
 pet ["food"] = minf(100.0, maxf(Rules.food_of(pet), Rules.feed_raise_to()))
 var gain:= Rules.feed_bond_gain_of(pet)
 pet ["bond"] = clampf(Rules.bond_of(pet) + gain, 0.0, 100.0)
 return "%s吃了%s，饱食度抬到 %.0f（亲密 %+d）" % [Rules.name_text(pet), Rules.feed_item_name(key), Rules.food_of(pet), roundi(gain)]


func feed_key_for(kind: String, bag: Dictionary) -> String:
 return _feed_key(kind, bag)

func _feed_key(kind: String, bag: Dictionary) -> String:
 for item in Rules.feed_items(kind):
  var want:= str(item)
  var best:= ""
  var best_grade:= 99
  for k in bag:
   if int(bag [k]) <= 0:
    continue
   if str(k) == want or str(k).begins_with(want + ":"):
    var grade:= 1
    if ":" in str(k):
     grade = int(str(k).get_slice(":", 1))
    if grade < best_grade:
     best = str(k)
     best_grade = grade
  if best != "":
   return best
 return ""



func play(pet_id: String, now: float = 0.0) -> String:
 var pet:= find(pet_id)
 if pet.is_empty():
  return "没有这只宠物"
 if now <= 0.0:
  now = _now()
 var kind:= str(pet.get("kind", ""))
 if kind == "dog":
  var ax: Dictionary = Rules.kind_rules("dog").get("anxious", {})
  if ax is Dictionary and bool(ax.get("refuses_fetch", true)) and Rules.anxious(pet, now):
   return "%s 现在有点着急，不肯叼球：先带它出去走走（walk_pet %s）" % [Rules.name_text(pet), str(pet.get("id", ""))]
 var gain:= Rules.play_bond_gain_of(pet)
 pet ["bond"] = clampf(Rules.bond_of(pet) + gain, 0.0, 100.0)
 pet ["last_play"] = now
 if kind == "cat":
  return "陪%s玩了一会儿，亲密抬到 %.0f" % [Rules.name_text(pet), Rules.bond_of(pet)]

 var fetch: Dictionary = Rules.rewards().get("dog_find", {})
 var chance:= float(fetch.get("base_chance", 0.3))
 if bool(fetch.get("chance_scales_with_bond", true)):
  chance *= Rules.bond_of(pet) / 100.0
 if int(pet.get("guards", 0)) > 0:
  chance += float(fetch.get("guard_bonus", 0.0))
 chance *= Rules.gift_chance_mult(pet)
 var got:= {}
 if rng.randf() < chance:
  got = _award_tier(pet, fetch.get("tiers", []), now)
 if got.is_empty():
  return "%s把球叼回来了，亲密抬到 %.0f" % [Rules.name_text(pet), Rules.bond_of(pet)]
 return "%s把球叼回来了，还%s（%s ×%d 进背包），亲密抬到 %.0f" % [Rules.name_text(pet), str(got.label), Rules.feed_item_name(str(got.item)), int(got.count), Rules.bond_of(pet)]


func walk(pet_id: String, now: float = 0.0) -> String:
 var pet:= find(pet_id)
 if pet.is_empty():
  return "没有这只宠物"
 if str(pet.get("kind", "")) != "dog":
  return "%s 不用遛：猫自己会出门转，回来就好" % Rules.name_text(pet)
 if now <= 0.0:
  now = _now()
 var w: Dictionary = Rules.kind_rules("dog").get("walk", {})
 pet ["last_walk"] = now
 pet ["last_play"] = maxf(float(pet.get("last_play", 0.0)), now)
 var gain:= float(w.get("bond_gain", 8.0)) * Rules.bond_gain_mult(pet)
 pet ["bond"] = clampf(Rules.bond_of(pet) + gain, 0.0, 100.0)
 return "带%s出去走了一圈，亲密抬到 %.0f" % [Rules.name_text(pet), Rules.bond_of(pet)]


func rub(pet_id: String, now: float = 0.0) -> String:
 var pet:= find(pet_id)
 if pet.is_empty():
  return ""
 if now <= 0.0:
  now = _now()
 if not Rules.rub_ready(pet, now):
  return ""
 var r: Dictionary = Rules.kind_rules("cat").get("rub", {})
 pet ["last_rub"] = now
 var gain:= float(r.get("bond_gain", 6.0)) * Rules.bond_gain_mult(pet)
 pet ["bond"] = clampf(Rules.bond_of(pet) + gain, 0.0, 100.0)
 return "%s蹭了蹭你的手，亲密抬到 %.0f" % [Rules.name_text(pet), Rules.bond_of(pet)]


func observe(pet_id: String, now: float, hour: float, dt: float = 0.0) -> void:
 var pet:= find(pet_id)
 if pet.is_empty() or not Rules.is_dog(pet):
  return
 var g: Dictionary = Rules.kind_rules("dog").get("guard", {})
 if not g is Dictionary or not Rules.guarding(pet, now, hour):
  return
 if dt > 0.0:
  var extra:= maxf(0.0, float(g.get("food_multiplier", 1.5)) - 1.0)
  pet ["food"] = clampf(Rules.food_of(pet) - dt / maxf(1.0, Rules.food_seconds_per_point("dog")) * extra, 0.0, 100.0)
 var mark:= float(pet.get("guard_mark", 0.0))
 if now - mark > 6.0 * 3600.0:
  pet ["guard_mark"] = now
  pet ["guards"] = int(pet.get("guards", 0)) + 1




func name(pet_id: String, raw: String, who: String, now: float = 0.0) -> Dictionary:
 var pet:= find(pet_id)
 if pet.is_empty():
  return {"ok": false, "text": "没有这只宠物"}
 if now <= 0.0:
  now = _now()
 var wait:= Rules.rename_wait(pet, now)
 if wait > 0.5:
  return {"ok": false, "text": "%s 刚改过名字，再等 %.0f 秒" % [Rules.name_text(pet), wait]}
 var checked:= Rules.name_ok(raw)
 if not bool(checked.get("ok", false)):
  return {"ok": false, "text": str(checked.get("why", "这个名字不能用"))}
 var cleaned:= str(checked.get("text", ""))
 if cleaned == "":
  pet ["name"] = ""
  pet ["named_by"] = who
  pet ["named_at"] = now
  return {"ok": true, "text": "把名字清掉了，现在叫 %s" % Rules.name_text(pet)}
 pet ["name"] = cleaned
 pet ["named_by"] = who
 pet ["named_at"] = now
 return {"ok": true, "text": "把%s叫作「%s」了（%s 取的，所有人都看得见）" % [Rules.kind_cn(str(pet.get("kind", ""))), cleaned, Rules.named_by_cn(who) if Rules.named_by_cn(who) != "" else who]}


func _update_next_id() -> void:
 var s:= state()
 var max_id:= 0
 for p in list():
  if p is Dictionary:
   max_id = maxi(max_id, int(str(p.get("id", "0"))))
 if int(s.get("next_id", 1)) <= max_id:
  s ["next_id"] = max_id + 1
