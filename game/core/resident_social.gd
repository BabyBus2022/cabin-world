extends RefCounted
## Rows and both actors' economies are written in the same atomic save.
## from/to are resident keys. Only the addressee can answer an offer.
const OFFER_MS := 5 * 60000
const PASS_MS := 2 * 3600000
const STAY_MS := 25 * 60000

static func body(actor: String):
	for resident in Economy.get_tree().get_nodes_in_group("world_residents"):
		if resident.key == actor and resident.placed:
			return resident
	return null

static func at_home(actor: String) -> bool:
	var resident = body(actor)
	var scene: String = Residents.person(actor).get("home", {}).get("scene", "")
	return resident != null and resident.scene_id == scene and resident.want_scene == scene

static func near(a: String, b: String) -> bool:
	var first = body(a)
	var second = body(b)
	return first != null and second != null and first.scene_id == second.scene_id and first.want_scene == first.scene_id and second.want_scene == second.scene_id and first.order_id == "" and second.order_id == "" and not first.is_walking() and not second.is_walking() and first.feet.distance_to(second.feet) <= 160

static func home_space(actor: String) -> String:
	return str(WorldData.SPACE_SCENE.find_key(Residents.person(actor).get("home", {}).get("scene", "")))

static func status(row: Dictionary) -> String:
	if row.status in ["offered", "invited"] and SharedFeed.now_ms() >= row.until:
		return "expired"
	return row.status

static func view(actor: String) -> Array:
	var rows := []
	for record in Economy.social.values():
		if actor in [record.from, record.to]:
			var item: Dictionary = record.duplicate(true)
			item.status = status(record)
			rows.append(item)
	return rows

static func active_visit(actor: String, host: String) -> Dictionary:
	for row in Economy.social.values():
		if row.kind == "visit" and row.from == actor and row.to == host and status(row) in ["invited", "visiting"]:
			return row
	return {}

static func door_open(actor: String, host: String) -> bool:
	var row := active_visit(actor, host)
	return not row.is_empty() and at_home(host)

static func departed(actor: String, scene: String) -> void:
	if not VadsLink.social_enabled: return
	for row in Economy.social.values():
		if actor not in [row.from, row.to]: continue
		if row.kind == "gift" and status(row) == "offered":
			Economy.social_request(row.from, {"id":"departure", "action":"cancel", "ticket":row.id})
		elif row.kind == "visit" and row.to == actor and status(row) in ["offered", "invited"] and Residents.person(actor).home.scene == scene:
			Economy.social_request(row.from, {"id":"departure", "action":"cancel", "ticket":row.id})
		elif row.kind == "visit" and row.from == actor and status(row) == "visiting" and Residents.person(row.to).home.scene == scene:
			Economy.social_request(actor, {"id":"departure", "action":"leave", "ticket":row.id})

static func entry_allowed(actor: String, scene: String) -> bool:
	if not VadsLink.social_enabled: return true
	for person in Residents.people():
		if person.key == actor or person.home.scene != scene: continue
		for row in Economy.social.values():
			if row.kind == "visit" and row.from == actor and row.to == person.key:
				return door_open(actor, person.key)
		# Older hosts and walk-only callers still use the existing entry desk.
		return true
	return true

static func fail(message: String) -> Dictionary:
	return {"ok":false, "error":message}

static func known(actor: String, peer: String) -> Array:
	var links: Dictionary = Economy.relationships.get(actor, {})
	var data := Residents.person(actor)
	if data.get("peer_name") == Residents.person(peer).get("name"):
		return Economy.people[actor].get("life", {}).get("bond", {}).get("knownLikes", [])
	return links.get(peer, {}).get("knownLikes", [])

static func eligible(actor: String) -> Array:
	var bag: Dictionary = Economy.people[actor].get("bag", {})
	return Economy.catalog.values().filter(func(p): return bag.get(p.id, 0) > 0)

static func gifted_today(a: String, b: String) -> bool:
	for row in Economy.social.values():
		if row.kind == "gift" and row.status == "received" and row.get("day") == Economy.today() and a in [row.from, row.to] and b in [row.from, row.to]:
			return true
	return false

static func product_id(value: String) -> String:
	var term := value.strip_edges()
	if Economy.catalog.has(term) or term == "": return term
	var exact := Economy.catalog.values().filter(func(p): return p.name == term)
	if exact.size() == 1: return exact[0].id
	if term.length() >= 2:
		var matches := Economy.catalog.values().filter(func(p): return term in p.name)
		if matches.size() == 1: return matches[0].id
	return term

static func propose(actor: String, f: Dictionary) -> Dictionary:
	var peer := str(f.get("peer", ""))
	var kind := str(f.get("action", ""))
	f = f.duplicate(true)
	if kind == "gift": f.product = product_id(str(f.get("product", "")))
	if actor == peer or not Economy.people.has(peer) or Residents.person(peer).is_empty():
		return fail("找不到这位在线住户")
	var key := str(f.get("ticket", ""))
	if key == "" or key.length() > 100:
		return fail("缺少提议编号")
	if Economy.social.has(key):
		var prior: Dictionary = Economy.social[key]
		if prior.from != actor or prior.to != peer or prior.kind != kind: return fail("提议编号已使用")
		return {"ok":true, "row":prior}
	for prior in Economy.social.values():
		if prior.from != actor or prior.to != peer or prior.kind != kind: continue
		if status(prior) in ["offered", "invited", "visiting"]:
			if kind == "gift" and f.get("product", "") not in ["", prior.product]: return fail("先处理上一份礼物")
			return {"ok":true, "row":prior}
	var row := {"id":key, "kind":kind, "from":actor, "to":peer, "status":"offered",
		"fromName":Residents.person(actor).name, "toName":Residents.person(peer).name,
		"legacy":f.get("legacy") == true, "until":SharedFeed.now_ms()+OFFER_MS, "at":SharedFeed.now_ms()}
	if kind == "visit":
		if not at_home(peer): return fail("对方不在家")
		row.space = home_space(peer)
	else:
		if not near(actor, peer): return fail("要先当面走到对方身边")
		row.spontaneous = f.get("spontaneous") == true
		if row.spontaneous and gifted_today(actor, peer): return fail("今天已经送过礼了")
		var options := eligible(actor)
		var id := str(f.get("product", ""))
		if id == "":
			var picked = Life.pick_gift(options, known(actor, peer), func(): return randf())
			if picked != null: id = picked.id
		if not options.any(func(p): return p.id == id): return fail("没有找到这份可赠物，请用 world_inventory 或 world_social list 查看准确名称和数量")
		row.product = id
		row.item = Economy.catalog[id].name
	Economy.social[key] = row
	return {"ok":true, "row":row}

static func life(actor: String, other: String, event: Dictionary) -> void:
	var state: Dictionary = Economy.people[actor]
	var profile := Residents.person(actor)
	var other_name := str(Residents.person(other).name)
	event.partner = other_name
	var life_state: Dictionary = state.get("life", {}).duplicate(true)
	var original = life_state.get("bond")
	var peers: Dictionary = Economy.relationships.get_or_add(actor, {})
	# The original two-person bond remains the legacy peer's live view.
	var default_peer: bool = profile.get("peer_name") == other_name
	if not default_peer: life_state["bond"] = peers.get(other, {})
	state["life"] = life_state
	Economy._apply(state, "life_event", {"event":event, "who":profile.flavor, "day":Economy.today(), "now":SharedFeed.now_ms(), "weather":SharedFeed.weather}, {})
	peers[other] = state.life.bond.duplicate(true)
	if not default_peer:
		if original != null: state.life.bond = original
		else: state.life.erase("bond")
	state.rev = int(state.rev) + 1

static func willing(host: String, guest: String, frame: Dictionary) -> bool:
	if frame.get("called") == true: return true
	var s: Dictionary = Economy.people[host]
	var now := SharedFeed.now_ms()
	var facts := Life.life_view({"who":Residents.person(host).flavor, "life":s.get("life"), "feeling":Life.feeling_now(s.get("feeling"), now), "day":Economy.today(), "now":now, "weather":SharedFeed.weather})
	var closeness: float = facts.bond.closeness
	if Residents.person(host).peer_name != Residents.person(guest).name:
		closeness = Economy.relationships.get(host, {}).get(guest, {}).get("closeness", 20)
	var chance := minf(0.95, 0.5 + (0.2 if facts.needs.fun < 40 else 0.0) + (0.15 if facts.needs.social < 40 else 0.0) + closeness / 250.0)
	return float(frame.get("roll", 1.0)) < chance

static func change(actor: String, f: Dictionary) -> Dictionary:
	var action := str(f.get("action", ""))
	if action in ["gift", "visit"]: return propose(actor, f)
	var row: Dictionary = Economy.social.get(str(f.get("ticket", "")), {})
	if row.is_empty() or actor not in [row.from, row.to]: return fail("找不到自己的提议")
	var phase := status(row)
	if action in ["accept", "decide_visit", "decline"] and actor != row.to: return fail("只有收到提议的人可以答复")
	if action in ["arrive", "cancel", "leave"] and actor != row.from: return fail("只有发起者可以执行")
	if action == "decide_visit" and row.kind != "visit": return fail("这不是串门提议")
	if phase in ["received", "declined", "cancelled", "left", "expired", "failed"]:
		return {"ok":true, "row":row.merged({"status":phase}, true)}
	match action:
		"decline":
			if phase != "offered": return fail("已经答复过了")
			row.status = "declined"
			row.reason = str(f.get("reason", "这次不方便")).left(80)
		"cancel", "leave":
			row.status = "left" if phase == "visiting" else "cancelled"
		"accept", "decide_visit":
			if phase != "offered": return {"ok":true, "row":row}
			if row.kind == "visit":
				var resident = body(actor)
				var energy := float(Life.feeling_now(Economy.people[actor].get("feeling"), SharedFeed.now_ms()).energy)
				if not at_home(actor) or resident.sleeping or f.get("free") != true or energy < 20:
					row.status = "failed"
					row.reason = "主人不在家或正需要休息"
				elif action == "decide_visit" and not willing(actor, row.from, f):
					row.status = "declined"
					row.reason = "对方现在不太方便"
				else:
					row.status = "invited"
					row.until = SharedFeed.now_ms()+PASS_MS
			else:
				var giver: Dictionary = Economy.people[row.from]
				var taker: Dictionary = Economy.people[actor]
				var problem := ""
				if not near(row.from, actor): problem = "双方已经不在身边"
				elif row.get("spontaneous") == true and gifted_today(row.from, actor): problem = "今天已经送过礼了"
				elif Economy._bag_count(taker) >= int(Economy.limits.bagSlots): problem = Economy.BAG_FULL
				elif not Economy._take_from_bag(giver, row.product): problem = Economy.NOT_IN_BAG
				if problem != "":
					row.status = "failed"
					row.reason = problem
				else:
					taker.bag[row.product] = int(taker.bag.get(row.product, 0))+1
					row.liked = Life.likes_gift(Residents.person(actor).flavor, Life.feeling_now(taker.get("feeling"), SharedFeed.now_ms()), row.product)
					row.status = "received"
					row.completedAt = int(SharedFeed.now_ms())
					row.scene = body(actor).scene_id
					row.day = Economy.today()
					var event := {"type":"gift_out", "product":{"id":row.product, "name":row.item}, "liked":row.liked}
					life(row.from, actor, event)
					life(actor, row.from, event.merged({"type":"gift_in"}, true))
		"arrive":
			if phase == "visiting": return {"ok":true, "row":row}
			if phase != "invited": return fail("主人还没有同意")
			var guest = body(actor)
			if not at_home(row.to) or guest == null or guest.scene_id != Residents.person(row.to).home.scene or guest.order_id != "" or guest.is_walking():
				return fail("还没有在主人家见面")
			row.status = "visiting"
			row.arrivedAt = SharedFeed.now_ms()
			row.returnAt = row.arrivedAt + STAY_MS
			life(actor, row.to, {"type":"visit"})
			life(row.to, actor, {"type":"visit", "guest":true})
		_: return fail("没有这个社交动作")
	return {"ok":true, "row":row}
