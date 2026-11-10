extends Node
## The action engine. Every timed action in the world runs here on the fixed tick, one per character.
## Each phase is announced to VADS, which does that phase's data work and answers; then its time runs here.
## An action can be interrupted until VADS says it was committed, and VADS decides that.

## INTERFACE: action messages. Full reference: ../docs/INTERFACES.md section 5.
##   start(frame)      action.start: id, actor, kind, label, phases: [{ id, label, ms, pose }]
##   phase_done(frame) action.done: id, index, ok
##   interrupt(frame)  action.interrupt: id
##   skip(frame)       action.skip: id; cuts the current phase's remaining time short
##   Sends action.phase (id, index) and action.finished (id) through VadsLink.
## Signals carry the actor key, which matches Character.key and the presence keys.
signal phase_started(actor: String, phase: String, label: String, pose: int)
signal action_ended(actor: String)

var _running := {}


func start(frame: Dictionary) -> void:
	var actor := str(frame.get("actor", ""))
	if _running.has(actor):
		action_ended.emit(actor)
	_running[actor] = {"id": frame.get("id"), "kind": frame.get("kind", ""), "phases": frame.get("phases", []), "index": -1, "left": 0.0, "waiting": false}
	_next(actor)


func phase_done(frame: Dictionary) -> void:
	var actor := _actor_of(frame.get("id"))
	if actor == "":
		return
	var a: Dictionary = _running[actor]
	if int(frame.get("index", -1)) != a["index"] or not a["waiting"]:
		return
	a["waiting"] = false
	if frame.get("ok") != true:
		_finish(actor) # VADS already reported the failure on its side
		return
	var ms: float = 0.0 if a.get("skip", false) else float(a["phases"][a["index"]].get("ms", 0))
	a["skip"] = false
	if ms > 0.0:
		a["left"] = ms / 1000.0
	else:
		_next(actor)


func skip(frame: Dictionary) -> void:
	var actor := _actor_of(frame.get("id"))
	if actor == "":
		return
	var a: Dictionary = _running[actor]
	if a["left"] > 0.0:
		a["left"] = 0.0
		_next(actor)
	elif a["waiting"]:
		a["skip"] = true


func interrupt(frame: Dictionary) -> void:
	var actor := _actor_of(frame.get("id"))
	if actor != "":
		_finish(actor)


## The link to VADS is gone: nobody can do the data work, so everything stops.
func clear() -> void:
	for actor in _running.keys():
		_finish(actor)


func _actor_of(id) -> String:
	for actor in _running:
		if _running[actor]["id"] == id:
			return actor
	return ""


func _physics_process(delta: float) -> void:
	for actor in _running.keys():
		var a: Dictionary = _running[actor]
		if a["left"] > 0.0:
			a["left"] -= delta
			if a["left"] <= 0.0:
				a["left"] = 0.0
				_next(actor)


func _next(actor: String) -> void:
	var a: Dictionary = _running[actor]
	a["index"] += 1
	if a["index"] >= a["phases"].size():
		VadsLink.send({"type": "action.finished", "id": a["id"]})
		_finish(actor)
		return
	var phase: Dictionary = a["phases"][a["index"]]
	a["waiting"] = true
	phase_started.emit(actor, str(phase.get("id", "")), str(phase.get("label", "")), int(phase.get("pose", -1)))
	VadsLink.send({"type": "action.phase", "id": a["id"], "index": a["index"]})


func _finish(actor: String) -> void:
	_running.erase(actor)
	action_ended.emit(actor)

## Read-only action identity for in-world service/presentation components.
func current(actor: String) -> Dictionary:
	var running: Dictionary = _running.get(actor,{})
	return {"id":running.get("id",""),"kind":running.get("kind","")}
