class_name Body
extends RefCounted
## A resident's bed, phone and headphones, and computer. Same rules as bed.mjs, accessories.mjs and computer.mjs in VADS.
## One implementation for every resident. Everything runs on absolute time, so the same steps at the same times give the same result.
##
## INTERFACE: body messages. Full reference: ../docs/INTERFACES.md section 4.
##   body.sync   host -> game  actor, at, bed (plan), items, audioRevision, computer, computerRevision, motion. Sent when the link opens.
##   body.do     host -> game  actor, part ("bed", "items", "computer"), method, args (array), at (ms since 1970). VADS did this; do the same.
##   body.get    host -> game  id, actor, at
##   body.state  game -> host  id, bed, items, computer: what this module says at that time.
##
## DATA MAPPING: the game draws from view(), which replaces view.bed, view.items and view.computer in her presence row.
## body.open / body.patch commit durable fields through BodySave; body.sync carries live transitions.

const SleepRules = preload("res://core/resident_sleep.gd")
var actor_key := ""

const LABELS := {"empty": "站在床边", "approaching": "走向床边", "edge": "坐在床沿", "climbing": "收腿上床", "reclining": "靠向枕头", "lying": "躺着休息", "covering": "拉好被子", "covered": "盖着被子休息", "sleeping": "盖着被子睡觉", "waking": "刚刚醒来", "uncovering": "掀开被子", "sitting_up": "在床上坐起", "leaving": "双脚落地，下床"}
const BED_FINAL := {"sit": "edge", "rest": "lying", "cover": "covered", "sleep": "sleeping", "wake": "covered", "leave": "empty"}
const APPROACH := {"x": 240.0, "y": 230.0}
const SEAT := {"x": 240.0, "y": 178.0}
const STAND := {"x": 325.0, "y": 244.0}

static var _people := {}

var plan := {"version": 1, "revision": 0, "start": 0.0, "steps": [], "final": "empty", "source": "manual"}
var items := {"phone": "dock", "headphones": "dock", "audio": "stopped", "transfer": null}
var audio_revision := 0
var computer := {"phase": "standing", "x": 325.0, "y": 244.0, "screen": "off", "intent": null, "job": null, "error": null}
var computer_revision := 0
var simple_rest: Dictionary = {}
var motion = null
var seen: Array = []


static func of(actor: String) -> Body:
	if not _people.has(actor):
		_people[actor] = Body.new()
		_people[actor].actor_key = actor
	return _people[actor]


static func known(actor: String) -> bool:
	return _people.has(actor)


static func handle(frame: Dictionary) -> void:
	var actor := str(frame.get("actor", ""))
	var at := float(frame.get("at", 0))
	match frame.get("type"):
		"body.sync":
			var b := Body.new()
			b.actor_key = actor
			b.restore(frame)
			_people[actor] = b
		"body.do":
			of(actor).apply(str(frame.get("part", "")), str(frame.get("method", "")), frame.get("args", []), at)
		"body.get":
			VadsLink.send({"type": "body.state", "id": frame.get("id"), "bed": of(actor).bed_snapshot(at), "items": of(actor).items_snapshot(at), "computer": of(actor).computer_tick(at)})


func load_committed(row: Dictionary) -> void:
	if row.get("bed") is Dictionary:
		plan = row.bed.duplicate(true)
	for key in ["phone", "headphones"]:
		if row.has(key):
			items[key] = row[key]
	if row.get("rest") is Dictionary:
		simple_rest = row.rest.duplicate()
		var asleep: bool = simple_rest.sleeping
		if asleep != (plan.final == "sleeping"):
			bed_command("sleep" if asleep else "wake", "resident", SharedFeed.now_ms())
	if row.get("computer") is Dictionary:
		var c: Dictionary = row.computer
		for key in ["phase", "x", "y", "screen", "error"]:
			computer[key] = c.get(key)
		computer["intent"] = null
		computer["job"] = null
		motion = c.get("motion")


func restore(frame: Dictionary) -> void:
	if frame.get("bed") is Dictionary:
		plan = frame["bed"]
	if frame.get("items") is Dictionary:
		items = frame["items"]
	audio_revision = int(frame.get("audioRevision", 0))
	if frame.get("computer") is Dictionary:
		computer = frame["computer"]
	computer_revision = int(frame.get("computerRevision", 0))
	motion = frame.get("motion")


func apply(part: String, method: String, args: Array, at: float) -> void:
	var a0 = args[0] if args.size() > 0 else null
	var a1 = args[1] if args.size() > 1 else null
	match part + "." + method:
		"bed.command":
			bed_command(str(a0), str(a1) if a1 != null else "manual", at)
		"items.begin":
			items_begin(str(a0), str(a1), at)
		"items.commit":
			items_commit(at)
		"items.cancel":
			items["transfer"] = null
		"items.pocket":
			if items["phone"] == "hand" and items["transfer"] == null:
				items["phone"] = "pocket"
		"items.play":
			if items["headphones"] == "worn":
				items["audio"] = "playing"
				audio_revision += 1
		"items.finish":
			if int(a0) == audio_revision:
				items["audio"] = "finished" if a1 == true else "failed"
		"computer.use":
			computer_use(str(a0) if a0 != null else "video", a1, at)
		"computer.finish":
			computer_finish(a0, a1 != false)
		"computer.stand":
			computer_revision += 1
			computer["job"] = null
			computer["intent"] = null
			computer["screen"] = "desktop"
			_transition("leaving", STAND, 1000.0, at)
		"computer.powerOff":
			computer["screen"] = "off"
			computer["intent"] = null
			computer["job"] = null


# ---- Bed ------------------------------------------------------------------------------

func bed_snapshot(at: float) -> Dictionary:
	var cursor := float(plan["start"])
	for s in plan["steps"]:
		var duration := float(s[1])
		if at < cursor + duration:
			return _describe(str(s[0]), maxf(0.0, (at - cursor) / duration))
		cursor += duration
	return _describe(str(plan["final"]), 1.0)


func _describe(phase: String, progress: float) -> Dictionary:
	return {"phase": phase, "progress": progress, "label": LABELS.get(phase, ""), "occupied": not phase in ["empty", "approaching"], "engaged": phase != "empty", "covered": phase in ["covered", "sleeping", "waking", "uncovering"], "asleep": phase == "sleeping", "revision": plan["revision"], "source": plan["source"], "plan": plan}


func bed_command(action: String, source: String, at: float) -> bool:
	if not BED_FINAL.has(action):
		return false
	var s := bed_snapshot(at)
	var profile: Dictionary = Residents.person(actor_key).get("sleep", {})
	var final_phase: String = profile.get("wakeFinal", "covered") if action == "wake" else BED_FINAL[action]
	if plan["final"] == final_phase and s["engaged"]:
		return false
	if (action == "wake" or action == "leave") and not s["engaged"]:
		return false
	var steps: Array = []
	if action in ["sleep", "wake"] and not profile.is_empty():
		steps = SleepRules.steps(profile, action, s)
	elif action == "leave":
		if s["asleep"]:
			steps.append(["waking", 700])
		if s["covered"] or s["phase"] == "covering":
			steps.append(["uncovering", 700])
		if s["occupied"]:
			steps.append(["sitting_up", 700])
			steps.append(["edge", 500])
		steps.append(["leaving", 700])
	elif action == "wake":
		steps.append(["waking", 800])
	else:
		if action in ["sit", "rest"] and s["occupied"]:
			if s["asleep"]:
				steps.append(["waking", 700])
			if s["covered"]:
				steps.append(["uncovering", 700])
			if action == "sit" and s["phase"] != "edge":
				steps.append(["sitting_up", 700])
		if not s["occupied"]:
			steps.append(["approaching", 1500])
			steps.append(["edge", 650])
		if action != "sit":
			if not s["phase"] in ["lying", "covered", "sleeping"]:
				steps.append(["climbing", 650])
				steps.append(["reclining", 750])
			if action == "cover" or action == "sleep":
				steps.append(["covering", 850])
	plan = {"version": 1, "revision": int(plan["revision"]) + 1, "start": at, "steps": steps, "final": final_phase, "source": source}
	return true


# ---- Phone and headphones -------------------------------------------------------------

func items_snapshot(at: float) -> Dictionary:
	var out := items.duplicate()
	if bed_snapshot(at).asleep:
		if out.phone=="hand":out.phone="pocket"
		out.transfer=null
		# Nothing plays while she sleeps (sleep mute). A playback that already finished or failed keeps that
		# result, as VADS RoomAccessories reports it (body-sync diverged here: "finished" vs "stopped").
		if out.audio=="playing":out.audio="stopped"
		return out
	var t = items["transfer"]
	if t is Dictionary:
		var copy: Dictionary = t.duplicate()
		copy["progress"] = minf(1.0, maxf(0.0, (at - float(t["start"])) / 800.0))
		out["transfer"] = copy
	return out


func items_begin(item: String, to: String, at: float) -> void:
	if bed_snapshot(at).asleep:
		return
	if items.get(item) == to or items["transfer"] != null:
		return
	items["transfer"] = {"item": item, "from": items[item], "to": to, "start": at}


func items_commit(at := -1.0) -> void:
	if at < 0.0: at = SharedFeed.now_ms()
	if bed_snapshot(at).asleep:
		items.transfer=null
		return
	var t = items["transfer"]
	if not t is Dictionary:
		return
	items[t["item"]] = t["to"]
	items["transfer"] = null
	if t["item"] == "headphones" and t["to"] == "dock":
		audio_revision += 1
		items["audio"] = "stopped"


# ---- Computer -------------------------------------------------------------------------

func computer_use(kind: String, event_id, at: float) -> void:
	if event_id != null and event_id != "":
		if event_id in seen:
			return
		seen.append(event_id)
		if seen.size() > 128:
			seen.pop_front()
	if not kind in ["video", "web", "typing", "desktop"]:
		return
	computer["intent"] = kind
	computer["error"] = null
	computer["job"] = event_id if event_id != null and event_id != "" else null
	computer_revision += 1
	if computer["phase"] == "seated":
		computer["screen"] = kind
		return
	_transition("approaching", APPROACH, 1200.0, at)


func _transition(phase: String, to: Dictionary, duration: float, start: float) -> void:
	computer["phase"] = phase
	motion = {"from": {"x": computer["x"], "y": computer["y"]}, "to": to, "start": start, "duration": duration}


func computer_tick(at: float) -> Dictionary:
	var step := 0
	while motion is Dictionary and step < 3:
		var duration := float(motion["duration"])
		var start := float(motion["start"])
		var t := minf(1.0, maxf(0.0, (at - start) / duration))
		var q := t * t * (3.0 - 2.0 * t)
		var from: Dictionary = motion["from"]
		var to: Dictionary = motion["to"]
		computer["x"] = float(from["x"]) + (float(to["x"]) - float(from["x"])) * q
		computer["y"] = float(from["y"]) + (float(to["y"]) - float(from["y"])) * q
		if t < 1.0:
			break
		motion = null
		if computer["phase"] == "approaching":
			_transition("sitting", SEAT, 700.0, start + duration)
		elif computer["phase"] == "sitting":
			computer["phase"] = "seated"
			if computer["intent"] != null:
				computer["screen"] = computer["intent"]
		else:
			computer["phase"] = "standing"
			computer["intent"] = null
		step += 1
	var out := computer.duplicate()
	out["chairOccupied"] = computer["phase"] in ["seated", "sitting"]
	return out


func computer_finish(event_id, ok: bool) -> void:
	if event_id != computer["job"]:
		return
	computer["job"] = null
	computer["intent"] = null
	computer["screen"] = "desktop" if ok else "error"
	computer["error"] = null if ok else "操作失败"


## What the drawing reads.
func view(at: float) -> Dictionary:
	return {"bed": bed_snapshot(at), "items": items_snapshot(at), "computer": computer_tick(at)}

