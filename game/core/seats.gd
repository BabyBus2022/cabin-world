class_name Seats
extends RefCounted
## Who is using which facility. The game keeps this table; VADS asks for a seat and waits for the answer.
## Same rules as SharedWorld.claimFacility in VADS: same facilities, slots, expiry and refusal.
##
## INTERFACE: seat messages. Full reference: ../docs/INTERFACES.md section 8.
##   seat.claim    host -> game  id (required, unique), owner (required, character key), object (required, object id), seconds (required)
##   seat.result   game -> host  id, ok, slot (a slot name, or null when the object has no seats), error (when not ok)
##   seat.release  host -> game  owner (required). Lets go of everything she holds.
##
## DATA MAPPING: table key is "<object>:<slot>", value { owner, until } with until in ms since 1970. Saved with the residents.

const REFUSED := "这个设施正在被使用，请等一会儿或选择其他活动"
const HAS_SEATS := ["swing", "slide", "carousel", "seesaw", "rider", "pier", "long_bench", "onsen_soak", "onsen_shower", "onsen_bench"]
const SLOTS := {"seesaw": ["left", "right"], "long_bench": ["a", "b", "c"], "onsen_soak": ["a", "b"], "onsen_shower": ["a", "b", "c"], "onsen_bench": ["a", "b"]}
const HELD_AFTER := 20.0


## Answers { slot, error }. slot is null when the object has no seats.
static func claim(owner: String, object: String, seconds: float) -> Dictionary:
	if not object in HAS_SEATS:
		return {"slot": null, "error": ""}
	var table := Residents.seats()
	var now: float = SharedFeed.now_ms()
	# A refusal changes nothing: what she already holds stays hers.
	var kept := {}
	var owned_slot = null
	for k in table:
		if float(table[k].get("until", 0)) > now and table[k].get("owner") != owner:
			kept[k] = table[k]
		elif float(table[k].get("until", 0)) > now and table[k].get("owner") == owner and str(k).begins_with(object + ":"):
			owned_slot = str(k).trim_prefix(object + ":")
	var chosen = null
	for s in ([owned_slot] if owned_slot != null else SLOTS.get(object, ["only"])):
		if not kept.has(object + ":" + s):
			chosen = s
			break
	if chosen == null:
		return {"slot": null, "error": REFUSED}
	table.clear()
	table.merge(kept)
	table[object + ":" + str(chosen)] = {"owner": owner, "until": now + (seconds + HELD_AFTER) * 1000.0}
	Residents.save_now()
	return {"slot": chosen, "error": ""}


static func release(owner: String) -> void:
	var table := Residents.seats()
	for k in table.keys():
		if table[k].get("owner") == owner:
			table.erase(k)
	Residents.save_now()


static func handle_claim(frame: Dictionary) -> void:
	var answer := claim(str(frame.get("owner", "")), str(frame.get("object", "")), float(frame.get("seconds", 30)))
	var reply := {"type": "seat.result", "id": frame.get("id"), "ok": answer["error"] == "", "slot": answer["slot"]}
	if answer["error"] != "":
		reply["error"] = answer["error"]
	VadsLink.send(reply)
