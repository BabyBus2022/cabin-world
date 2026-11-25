extends Node




























const Social = preload("res://core/resident_social.gd")
signal gift_changed(record: Dictionary)

signal transaction_committed(record: Dictionary)
var social:= {}
var relationships:= {}

func social_request(actor: String, frame: Dictionary) -> Dictionary:
 var reply:= {"type": "economy.result", "id": frame.id, "ok": false}
 if not VadsLink.owns_bodies or not people.has(actor) or Residents.person(actor).is_empty():
  return reply.merged({"error": "住户还没有连上世界"}, true)
 if frame.get("action") == "list":
  return reply.merged({"ok": true, "items": Social.eligible(actor).map(func(p): return p.merged({"count": people [actor].bag.get(p.id, 0)})), "inventory": inventory(actor), "catalog": catalog.values(), "state": people [actor]}, true)
 if FileAccess.file_exists(save_path):
  var backup:= save_path + ".bak-before-2.7.29"
  if not FileAccess.file_exists(backup) and DirAccess.copy_absolute(ProjectSettings.globalize_path(save_path), ProjectSettings.globalize_path(backup)) != OK:
   return reply.merged({"error": "旧存档备份失败"}, true)
 var old_people:= people.duplicate(true)
 var old_social:= social.duplicate(true)
 var old_bonds:= relationships.duplicate(true)
 var result:= Social.change(actor, frame)
 if result.ok and not _save():
  people = old_people
  social = old_social
  relationships = old_bonds
  return reply.merged({"error": "保存失败，交接没有生效"}, true)
 if result.ok:
  if result.row.kind == "gift": gift_changed.emit(result.row)
  for who in [result.row.from, result.row.to]:
   VadsLink.send({"type": "economy.social", "actor": who, "state": people [who], "updates": [result.row]})
 return reply.merged(result, true)

const NO_MONEY:= "零花钱不足"
const BAG_FULL:= "包已装满"
const NOT_IN_BAG:= "包里没有这个"
const KEEP_IDS:= 64


func inventory(actor: String) -> Dictionary:
 var bag: Dictionary = people.get(actor, {}).get("bag", {})
 var items:= []
 for key in bag:
  var id = str(key)
  var count:= int(bag [key])
  if count <= 0: continue
  var item: Dictionary = catalog [id].duplicate() if catalog.has(id) else {"id": id, "name": farm_label(id)}
  item ["count"] = count
  item ["giftable"] = catalog.has(id) and item.get("kind") != "use"
  item ["group"] = inventory_group(id, item)
  items.append(item)
 items.sort_custom(func(a, b): return str(a.group) + str(a.name) + str(a.id) < str(b.group) + str(b.name) + str(b.id))
 return {"actor": actor, "items": items, "used": items.size(), "capacity": limits.bagSlots, "coins": people.get(actor, {}).get("wallet", {}).get("coins", 0)}

func farm_label(id: String) -> String:
 var names: Dictionary = load("res://qingxi-live/rural_state.gd").load_item_names()
 if names.has(id): return names [id]
 if ItemIcons.FARM_NAMES.has(id): return ItemIcons.FARM_NAMES [id]
 var farm = load("res://qingxi-live/village-center/pasture_state.gd")
 if farm.FARM_ITEMS.has(id): return farm.FARM_ITEMS [id]
 if id.begins_with("decor_"): return farm_decor_name(id)
 if id.begins_with("catch:"):
  var fish = load("res://qingxi-live/village-center/pond_fish.gd")
  if fish.kinds().has(id.get_slice(":", 1)): return fish.label(id)
 var book = load("res://qingxi-live/village-center/breed_catalog.gd")
 if id.begins_with("young_") and id.contains(":"):
  var coat = int(id.get_slice(":", 1))
  if coat < 0 or coat >= book.BREEDS.get(id.get_slice(":", 0).trim_prefix("young_"), []).size(): return id
 return book.item_name(id)

func farm_decor_name(id: String) -> String:
 return load("res://qingxi-live/village-center/region.gd").PROP_NAMES.get(id.trim_prefix("decor_"), id)

func inventory_group(id: String, item: Dictionary) -> String:
 if id in ["hay", "fish_feed", "pig_feed"] or id.begins_with("feed_") or id.ends_with("_feed"): return "饲料"
 if id in ["seed", "wheat", "carrot", "veg"] or id.begins_with("seed_"): return "种植"
 if id in ["fry", "fish", "dried_fish"] or id.begins_with("catch:"): return "水产"
 if id.begins_with("feeder_") or id.begins_with("decor_"): return "农场设施"
 if catalog.has(id): return {"drink": "饮品", "eat": "食品"}.get(item.get("kind", ""), "日用品")
 if id in ["meal", "honey"]: return "食品"
 if id == "well_water": return "农场用品"
 return "养殖" if id.begins_with("young_") or load("res://qingxi-live/village-center/breed_catalog.gd").price(id) > 0 else "农场用品"

var catalog:= {}
var limits:= {}
var reward_cap:= 0
var daily_sales: Array = []
var sale_chance:= 0.0
var people:= {}
var save_path:= "user://economy.json"
var _seen: Array = []
var _main_broken:= false


func _ready() -> void:
 var data = JSON.parse_string(FileAccess.get_file_as_string("res://assets/economy.json"))
 for p in data ["products"]:
  catalog [p ["id"]] = p
 limits = data ["wallet"]

 if not Features.on("pocket-money-50"):
  limits = limits.duplicate(); limits ["daily"] = 20; limits ["cap"] = 80
 reward_cap = int(data ["rewardCap"])
 daily_sales = data ["dailySales"]
 sale_chance = float(data ["saleChance"])
 var args:= OS.get_cmdline_user_args()
 var i:= args.find("--save")
 var executable_dir:= OS.get_executable_path().get_base_dir()
 var ini_file:= executable_dir.path_join("cabinworld.ini")
 var ini_text:= FileAccess.get_file_as_string(ini_file) if FileAccess.file_exists(ini_file) else ""
 var configured_save:= InstallPaths.resolve_save(args, OS.get_environment("CABINWORLD_SAVE"), executable_dir, ini_text)
 if not configured_save.is_empty():
  save_path = configured_save.path_join("economy.json")
 elif not args.has("--unit"):

  save_path = "user://dev/economy.json"
 DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(save_path.get_base_dir()))
 _load()
 i = args.find("--price-table")
 if i >= 0 and i + 1 < args.size():
  _write_price_table(args [i + 1])





static func seeded(text: String) -> float:
 var h:= 2166136261
 for i in text.length():
  h ^= text.unicode_at(i)
  h = _imul(h, 16777619)
 h ^= h >> 15
 h = _imul(h, 2246822519)
 h ^= h >> 13
 h = _imul(h, 3266489917)
 h ^= h >> 16
 return float(h) / 4294967296.0


static func _imul(a: int, b: int) -> int:
 return(a * b) & 4294967295


func price_today(product: Dictionary, day: String) -> int:
 var price:= int(product ["price"])
 var v:= seeded("event|" + day)
 if v < sale_chance:
  var sale = daily_sales [int(floor(v / sale_chance * daily_sales.size()))]
  if sale == product ["shelf"]:
   return maxi(1, int(floor(price * 0.7)))
 return price


func today() -> String:
 return Time.get_date_string_from_unix_time(int(SharedFeed.now_ms() / 1000.0) + 8 * 3600)

static func available_today(product: Dictionary, day: String) -> bool:
 if product.has("months") and not Features.on("seasons"): return false
 return not product.has("months") or int(day.substr(5, 2)) in product.months


func _now_ms() -> int:
 return int(SharedFeed.now_ms())


func _top_up(s: Dictionary, day: String) -> void:
 var w = s.get("wallet")
 if not w is Dictionary or not w.has("coins"):
  w = {"coins": int(limits ["start"]), "day": day}
 if w.get("day") != day:

  w ["coins"] = maxi(int(w ["coins"]), mini(int(limits ["cap"]), int(w ["coins"]) + int(limits ["daily"])))
  w ["day"] = day
 s ["wallet"] = w


func _bag_count(s: Dictionary) -> int:
 var n:= 0
 for k in s ["bag"]:
  if int(s ["bag"] [k]) > 0: n += 1
 return n


func _bump_food(s: Dictionary, id: String, kind: String) -> void:
 var r: Dictionary = s ["foods"].get(id, {})
 r [kind] = int(r.get(kind, 0)) + 1
 r ["lastAt"] = _now_ms()
 r ["last"] = kind
 s ["foods"] [id] = r


func _take_from_bag(s: Dictionary, id: String) -> bool:
 if int(s ["bag"].get(id, 0)) <= 0:
  return false
 var left:= int(s ["bag"] [id]) - 1
 if left > 0:
  s ["bag"] [id] = left
 else:
  s ["bag"].erase(id)
 return true






func handle(frame: Dictionary) -> void:
 var from_resident:= frame.duplicate()
 from_resident ["_from_vads"] = true
 VadsLink.send(answer(from_resident))


func answer(frame: Dictionary) -> Dictionary:
 var result:= _answer(frame)
 if result.get("ok", false) and frame.get("op") in ["sync", "top_up", "life_view"]:
  var offers = []
  var day = today()
  for item in catalog.values():
   if item.get("shelf", "") == "restaurant" or str(item.id).begins_with("restaurant-") or not available_today(item, day): continue
   offers.append(item.merged({"price": price_today(item, day)}, true))
  result.shopOffers = offers
 var actor:= str(frame.get("actor", ""))
 if people.has(actor) and not(frame.get("op") == "qingxi" and frame.get("act") == "approach"): result ["view"] = reading(actor, frame)
 return result



func reading(actor: String, context: Dictionary = {}) -> Dictionary:
 var s: Dictionary = people.get(actor, {})
 var who: String = Residents.person(actor).get("flavor", actor)
 var details: Dictionary = context.get("args", context)
 var now:= float(details.get("now", SharedFeed.now_ms()))
 var weather = details.get("weather", SharedFeed.weather)
 var day:= str(details.get("day", Time.get_date_string_from_unix_time(int(now / 1000) + 28800)))
 var feeling:= Life.feeling_now(s.get("feeling"), now)
 var asleep: bool = Body.known(actor) and Body.of(actor).bed_snapshot(now).get("asleep", false)
 var life:= Life.life_view({"who": who, "life": s.get("life"), "feeling": feeling, "weather": weather if weather is Dictionary else {}, "day": day, "now": now, "sleeping": asleep})
 var environment: Dictionary = load("res://core/room_observation.gd").reading(actor)

 if not environment.is_empty():
  life ["environment"] = environment


  life.events.append(environment.note)
 return _tidy({"options": s.get("options", {}), "at": now, "feeling": feeling, "hunger": Life.hunger_of(float(feeling.get("satiety", 0))), "likes": Life.liked_foods(who, feeling, catalog.values()), "life": life, "want": Life.next_want(who, s.get("life")), "care": Life.care_hint(who, s.get("life"), now)})

func _answer(frame: Dictionary) -> Dictionary:
 var id = frame.get("id")
 var actor:= str(frame.get("actor", ""))
 var op:= str(frame.get("op", ""))
 if op == "qingxi" and frame.get("act") == "approach":
  var step:= {"type": "economy.result", "id": id, "ok": true}
  var reason:= _apply({}, op, frame, step)
  if reason != "":
   step.ok = false
   step.error = reason
  return step

 if op != "sync" and id in _seen and people.has(actor):
  return {"type": "economy.result", "id": id, "ok": true, "state": people [actor]}
 if op == "social":
  return social_request(actor, frame)
 if op == "sync":
  var synced:= _sync(frame)
  if VadsLink.social_enabled:
   var history:= Social.view(actor)
   for start in range(0, history.size(), 32):
    VadsLink.send({"type": "economy.social", "actor": actor, "history": history.slice(start, start + 32), "reset": start == 0})
   synced ["socialReady"] = true
  if VadsLink.social_enabled or frame.get("includeCatalog", false):
   synced ["catalog"] = catalog.values()
  return synced
 if op == "need_plan":
  return _need_plan(frame)
 if op == "life_view":
  return {"type": "economy.result", "id": id, "ok": true, "state": people.get(actor, {})}
 var s: Dictionary = _clean(people.get(actor, {}))
 var out:= {"type": "economy.result", "id": id, "ok": true}
 var problem:= _apply(s, op, frame, out)
 if problem != "":
  out ["ok"] = false
  out ["error"] = problem
  out ["state"] = people.get(actor, s)
  return out

 load("res://core/keepsakes.gd").record(s, op, frame)
 s ["rev"] = int(s.get("rev", 0)) + 1
 var before = people.get(actor)
 var old_seen:= _seen.duplicate()
 _seen.append(id)
 if _seen.size() > KEEP_IDS: _seen.remove_at(0)
 people [actor] = s
 if not _save():
  _seen = old_seen
  if before == null:
   people.erase(actor)
  else:
   people [actor] = before
  out ["ok"] = false
  out ["error"] = "保存失败"
  out ["state"] = people.get(actor, s)
  return out
 out ["state"] = s
 transaction_committed.emit({"id": id, "actor": actor, "op": op, "product": frame.get("product", "")})
 for discovered in out.get("discovered", []):
  VadsLink.send({"type": "economy.activity", "actor": actor, "id": "found-" + str(discovered.id), "at": SharedFeed.now_ms(), "action": "discover", "name": "发现主人留下的心意", "detail": str(discovered.text), "space": discovered.scene, "status": "complete"})
 return out


func _apply(s: Dictionary, op: String, frame: Dictionary, out: Dictionary) -> String:
 var id:= str(frame.get("product", ""))
 var day:= today()
 match op:
  "qingxi":
   var qx = Engine.get_main_loop().get_meta("qingxi_world_host", null)
   if qx == null: return "清溪村不在这个游戏里"
   return qx.resident_act(s, frame, out)
  "keepsake":
   return "留言、礼物与纪念册已停用"
  "top_up":
   _top_up(s, day)
  "buy":
   if not catalog.has(id):
    return "没有这个东西"
   if not available_today(catalog [id], day): return "这个时令商品本月暂未上架"
   _top_up(s, day)
   var price:= price_today(catalog [id], day)
   if int(s ["wallet"] ["coins"]) < price:
    return NO_MONEY
   var drink_here = frame.get("drinkHere", false) == true and catalog [id].get("kind") == "drink"
   if not drink_here and int(s.bag.get(id, 0)) <= 0 and _bag_count(s) >= int(limits.bagSlots):
    return BAG_FULL
   s ["wallet"] ["coins"] = int(s ["wallet"] ["coins"]) - price
   if drink_here:
    s ["feeling"] = _tidy(Life.experience({"saved": s.get("feeling"), "now": _now_ms(), "who": frame.get("who", ""), "objectId": "bag", "use": "drink", "product": catalog [id]}))
    _bump_food(s, id, "eaten")
   else: s.bag [id] = int(s.bag.get(id, 0)) + 1
   _bump_food(s, id, "bought")
   out ["price"] = price
  "consume":
   if not catalog.has(id) or int(s ["bag"].get(id, 0)) <= 0:
    return NOT_IN_BAG
   if catalog [id].get("keep") != true:
    _take_from_bag(s, id)
   _bump_food(s, id, "used" if frame.get("kind") == "used" else "eaten")
   if catalog [id].get("shelf") == "restaurant":
    s ["feeling"] = _tidy(Life.experience({"saved": s.get("feeling"), "now": SharedFeed.now_ms(), "who": frame.get("who", "unknown"), "objectId": id, "use": "eat", "product": catalog [id]}))
   out ["lines"] = food_description(catalog [id], frame.get("weather", {}), str(frame.get("space", "")))
  "options":
   var options: Dictionary = s.get("options", {}).duplicate()
   if frame.get("paused") is bool: options.paused = frame.paused



   var from_resident: bool = frame.get("_from_vads", false) == true
   if frame.get("lamps") in ["auto", "on", "off"]:
    if from_resident and not bool(options.get("residentLighting", false)):
     return "主人没有允许改灯光"
    options.lamps = frame.lamps
   if frame.get("residentLighting") is bool:
    if from_resident: return "只有主人能改这项许可"
    options.residentLighting = frame.residentLighting
   s.options = options
  "reward":
   _top_up(s, str(frame.get("day", day)))
   var coins:= int(s ["wallet"] ["coins"])
   s ["wallet"] ["coins"] = maxi(coins, mini(reward_cap, coins + maxi(0, roundi(float(frame.get("amount", 0))))))
  "gift_in":
   s ["bag"] [id] = int(s ["bag"].get(id, 0)) + 1
  "gift_out":
   if not _take_from_bag(s, id):
    return NOT_IN_BAG
  "play":
   var r = frame.get("weather")
   var result_play:= Life.play_outcome(str(frame.get("use", "")), r if r is Dictionary else {}, frame.get("umbrella") == true, func(): return randf(), Life.fish_luck_today(str(frame.get("day", ""))), int(s.get("fishBlanks", 0)))
   if frame.get("use") == "fish" and result_play ["outcome"] != null:
    s ["fishBlanks"] = 0 if Life.truthy(result_play ["outcome"].get("sizeCm")) else int(s.get("fishBlanks", 0)) + 1
    var fishing_day:= str(frame.get("day", day))
    var record: Dictionary = s.get("fishing", {})
    if record.get("day") != fishing_day: record = {"day": fishing_day, "count": 0, "best": "", "bestCm": 0}
    record.count = int(record.count) + 1
    var cm:= Life.n(result_play.outcome.get("sizeCm"))
    if result_play.outcome.has("kind"):
     var host = Engine.get_main_loop().get_meta("qingxi_world_host", null)
     if host == null: return "农场背包暂时无法连接。"
     var farm = host._farm_sim()
     var key = farm.sim.keep_catch(result_play.outcome.kind, cm)
     if key == "": return "未能收下河鱼。"
     host._farm_commit(farm)
     result_play.outcome.item = key
    if cm > float(record.bestCm):
     record.bestCm = cm
     record.best = str(cm) + "厘米的" + str(result_play.outcome.get("catch", "鱼"))
    s.fishing = record
   out ["lines"] = result_play ["lines"]
   out ["outcome"] = _tidy(result_play ["outcome"])
  "use_record":
   _record_use(s, str(frame.get("objectId", "")), str(frame.get("use", "")), str(frame.get("label", "")), float(frame.get("at", 0)))
  "uses":
   s ["uses"] = _tidy(frame.get("uses", {}))
   s ["usage"] = _tidy(frame.get("usage", {}))
  "experience":
   var args: Dictionary = frame.get("args", {}).duplicate()
   args ["saved"] = s.get("feeling")
   args ["who"] = frame.get("who", args.get("who", ""))
   s ["feeling"] = _tidy(Life.experience(args))
  "arcade_feeling":
   var args: Dictionary = frame.get("args", {}).duplicate()
   args ["saved"] = s.get("feeling")
   s ["feeling"] = _tidy(Life.arcade_feeling(args))
  "life_event":
   var now_ms:= float(frame.get("now", 0))
   var was_settled: bool = frame.get("event", {}).get("matchId", "") in s.get("life", {}).get("records", {}).get("arcadeMatches", [])
   var result:= Life.apply_event(s.get("life"), frame.get("event", {}), str(frame.get("who", "")), str(frame.get("day", "")), now_ms, frame.get("weather", {}) if frame.get("weather") is Dictionary else {})
   s ["life"] = _tidy(result ["life"])
   var event: Dictionary = frame.get("event", {})
   if event.get("type") == "arcade" and event.get("result") in ["won", "lost", "draw"] and not str(event.get("matchId", "")).is_empty():
    var payouts: Dictionary = s.get("arcadePayouts", {})
    var match_id: String = str(event.matchId)
    if not payouts.has(match_id):
     var before:= int(s ["wallet"] ["coins"])
     var delta:= 0 if was_settled else 5 if event.result == "won" else -2 if event.result == "lost" else 0
     s ["wallet"] ["coins"] = maxi(0, before + delta)
     payouts [match_id] = int(s ["wallet"] ["coins"]) - before
     s ["arcadePayouts"] = payouts
     if payouts [match_id] != 0: result ["notes"].append("对局结算：%+d钱" % int(payouts [match_id]))
    out ["arcadeCoins"] = int(payouts [match_id])
   if float(result ["joy"]) != 0.0:
    var f:= Life.feeling_now(s.get("feeling"), now_ms)
    f ["joy"] = minf(100.0, float(f ["joy"]) + float(result ["joy"]))
    s ["feeling"] = _tidy(f)
   out ["notes"] = result ["notes"]
   out ["joy"] = result ["joy"]
   out ["memorable"] = result ["memorable"]
   out ["diary"] = result ["diary"]
  _:
   return "不认识的操作：" + op
 return ""



func _record_use(s: Dictionary, id: String, use: String, label: String, at: float) -> void:
 if use != "":
  var uses: Dictionary = s.get("uses") if s.get("uses") is Dictionary else {}
  uses [id] = {"use": use, "label": label, "at": int(at)}
  s ["uses"] = uses
 var usage: Dictionary = s.get("usage") if s.get("usage") is Dictionary else {}
 var old: Dictionary = usage.get(id) if usage.get(id) is Dictionary else {}
 var day:= Time.get_date_string_from_unix_time(int(floorf((at + 28800000.0) / 1000.0)))
 usage [id] = {"count": int(old.get("count", 0)) + 1, "lastAt": int(at), "lastLabel": label.substr(0, 40), "day": day, "dayCount": int(old.get("dayCount", 0)) + 1 if old.get("day") == day else 1}
 s ["usage"] = usage



func _need_plan(frame: Dictionary) -> Dictionary:
 var actor:= str(frame.get("actor", ""))
 var who:= str(frame.get("who", ""))
 var s: Dictionary = _clean(people.get(actor, {}))
 var now:= float(frame.get("now", 0))
 _top_up(s, str(frame.get("day", "")))
 var feeling:= Life.feeling_now(s.get("feeling"), now)
 var shop: Array = catalog.values()
 var in_bag: Array = shop.filter(func(p): return int(s ["bag"].get(p ["id"], 0)) > 0)
 shop = shop.filter(func(p): return available_today(p, str(frame.get("day", today()))))
 var w = frame.get("weather")
 var weather: Dictionary = w if w is Dictionary else {}
 var queue: Array = frame.get("rands", []).duplicate() if frame.get("rands") is Array else []
 var random:= func(): return float(queue.pop_front()) if not queue.is_empty() else randf()
 var coins:= float(s ["wallet"] ["coins"])
 var plan = Life.hunger_plan(who, feeling, in_bag, shop, coins, weather, now, random) if frame.get("need") == "hunger" else Life.thirst_plan(who, feeling, in_bag, shop, coins, weather, now, random)
 var out:= {"type": "economy.result", "id": frame.get("id"), "ok": true, "plan": null}
 if plan is Dictionary:
  var home: Variant = Residents.flavor(who).get("thirst_at_home")
  if frame.get("need") == "thirst" and home is Dictionary and(plan ["action"] == "broke" or(plan ["action"] == "buy" and frame.get("space") == home ["space"])):
   out ["plan"] = {"action": "use", "objectId": home ["objectId"], "use": home ["use"], "feeling": home ["feeling"]}
  else:
   out ["plan"] = {"action": plan ["action"], "product": plan ["product"] ["id"] if plan.has("product") else null}
   if plan.action == "buy" and frame.get("need") == "thirst" and _bag_count(s) >= int(limits.bagSlots): out.plan ["drinkHere"] = true
 return out


func _sync(frame: Dictionary) -> Dictionary:
 var actor:= str(frame.get("actor", ""))
 var theirs:= int(frame.get("rev", 0))
 if not people.has(actor) or theirs > int(people [actor].get("rev", 0)):
  var keepsakes: Dictionary = people.get(actor, {}).get("keepsakes", {}).duplicate(true)
  var payouts: Dictionary = people.get(actor, {}).get("arcadePayouts", {}).duplicate(true)
  people [actor] = _clean(frame)
  if not keepsakes.is_empty(): people [actor].keepsakes = keepsakes
  if not payouts.is_empty(): people [actor].arcadePayouts = payouts
  people [actor] ["rev"] = theirs
  _save()
 else:

  var filled:= false
  for field in ["feeling", "life", "uses", "usage"]:
   if not people [actor].has(field) and frame.get(field) is Dictionary:
    people [actor] [field] = _tidy(frame [field])
    filled = true
  if not people [actor].has("fishBlanks") and frame.get("fishBlanks") != null:
   people [actor] ["fishBlanks"] = int(frame ["fishBlanks"])
   filled = true
  if filled:
   _save()
 return {"type": "economy.result", "id": frame.get("id"), "ok": true, "state": people [actor]}



func _clean(raw: Dictionary) -> Dictionary:
 var out:= {"bag": {}, "foods": {}, "rev": int(raw.get("rev", 0))}
 if raw.has("farmCoinSeq"): out.farmCoinSeq = int(raw.farmCoinSeq)
 var w = raw.get("wallet")
 if w is Dictionary and w.has("coins"):
  out ["wallet"] = {"coins": int(w ["coins"]), "day": str(w.get("day", ""))}
 var bag = raw.get("bag")
 if bag is Dictionary:
  for k in bag:
   if int(bag [k]) > 0:
    out ["bag"] [k] = int(bag [k])
 var foods = raw.get("foods")
 if foods is Dictionary:
  for k in foods:
   var r:= {}
   for field in foods [k]:
    var v = foods [k] [field]
    r [field] = int(v) if v is float else v
   out ["foods"] [k] = r
 for field in ["feeling", "life", "uses", "usage", "fishing", "options", "keepsakes", "arcadePayouts"]:
  if raw.get(field) is Dictionary:
   out [field] = _tidy(raw [field])
 if raw.get("fishBlanks") != null:
  out ["fishBlanks"] = int(raw ["fishBlanks"])
 return out

static func food_description(product: Dictionary, weather: Dictionary, space: String) -> Array:
 var lines:= [str(product.get("taste", ""))]
 if product.get("cold", false) and float(weather.get("temp", 20)) >= 24 and space != "shop": lines.append("大热天吃下去整个人都凉快了")
 if product.get("cold", false) and float(weather.get("temp", 20)) <= 13: lines.append("天有点冷，冰得牙齿一酸")
 if product.get("id") == "umbrella": lines [0] = "撑开伞，雨点打在伞面上噼里啪啦" if float(weather.get("rain", 0)) > 0 and space == "park" else "收在包里，下雨在外面时会撑开"
 return lines


static func _tidy(v):
 if v is float:
  return int(v) if v == floor(v) and absf(v) < 1000000000000000.0 else v
 if v is Dictionary:
  var d:= {}
  for k in v:
   d [k] = _tidy(v [k])
  return d
 if v is Array:
  return v.map(_tidy)
 return v




func _valid_save(data: Dictionary) -> bool:
 if not data.get("people") is Dictionary or not data.people.values().all(func(p): return p is Dictionary): return false
 if not data.get("seen", []) is Array or not data.get("social", {}) is Dictionary or not data.get("relationships", {}) is Dictionary: return false
 for person in data.people.values():
  if person.get("keepsakes") is Dictionary and not load("res://core/keepsakes.gd").valid(person.keepsakes): return false
  if person.has("arcadePayouts") and(not person.arcadePayouts is Dictionary or not person.arcadePayouts.values().all(func(v): return(v is int or v is float) and is_finite(float(v)) and v >= -2 and v <= 5)): return false
  for field in ["bag", "foods", "uses", "usage", "options", "keepsakes", "arcadePayouts"]:
   if person.has(field) and not person [field] is Dictionary: return false
  if person.has("wallet"):
   var wallet = person.wallet
   if not wallet is Dictionary or not(wallet.get("coins") is int or wallet.get("coins") is float) or not is_finite(float(wallet.coins)): return false
 return true

func _save() -> bool:
 return load("res://core/safe_store.gd").write_document(save_path, {"version": 1, "people": people, "seen": _seen, "social": social, "relationships": relationships}, _valid_save, true)

func _load() -> void:
 var stored: Dictionary = load("res://core/safe_store.gd").read_document(save_path, _valid_save, true)
 _main_broken = stored.recovered
 if not stored.ok: return
 var data: Dictionary = stored.data
 for actor in data.get("people", {}): people [actor] = _clean(data.people [actor])
 _seen = data.get("seen", []); social = data.get("social", {}); relationships = data.get("relationships", {})



func _write_price_table(file: String) -> void:
 var base:= Time.get_unix_time_from_datetime_string("2026-01-01T12:00:00")
 var table:= {}
 for d in 400:
  var day:= Time.get_date_string_from_unix_time(base + d * 86400)
  var row:= {}
  for id in catalog:
   row [id] = price_today(catalog [id], day)
  table [day] = row
 var f:= FileAccess.open(file, FileAccess.WRITE)
 f.store_string(JSON.stringify(table))
 f.close()
