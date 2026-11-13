extends Node
## The connection to VADS. VADS publishes a port and a one-time token in its data folder; this reads them and connects.
## While connected, world data arrives here directly and the game does not open shared.json.

## INTERFACE: the game's side of the host link. Full reference: ../docs/INTERFACES.md
## Reads <data>/world/game-link.json: port (required), token (required), at (optional).
## Messages are one JSON object per line.
##   Sends:    hello (token, game, actions, economy, walk, residents), ping, quit, action.phase and action.finished through Actions, economy.result through Economy, walk.arrived through Character.
##   Also sends panel.get and panel.do through Dock, seat.result through Seats, entry.result through Entry, body.state through Body.
##   Receives: welcome (residents: true when the game owns the bodies), world (presence), clock (now), weather (reading), pong, quit, action.start, action.done, action.interrupt, action.skip, economy.do, walk.go, panel.data, panel.did, seat.claim, seat.release, entry.route, entry.pass, entry.revoke, body.sync, body.do, body.get.
signal connection_changed(connected: bool)
signal walk_ordered(frame: Dictionary)
signal restaurant_requested(frame: Dictionary)
signal panel_arrived(frame: Dictionary)
## True once VADS has agreed the game owns where everyone is.
var owns_bodies := false
var social_enabled := false
signal panel_done(frame: Dictionary)

const ResidentSleep = preload("res://core/resident_sleep.gd")
const WorldRules = preload("res://core/world_rules.gd")
const Records = preload("res://core/arcade_records.gd")
const Board = preload("res://core/arcade_board.gd")
const Strategy = preload("res://core/arcade_strategy.gd")
var _board_jobs := {}
const Hall = preload("res://core/arcade_hall.gd")
var _hall := Hall.new()
var arcade_view := {"sessions":{},"history":[],"rules":{}}
const BodySave = preload("res://core/body_save.gd")
var body_persistence := false

const ToolPoses = preload("res://core/tool_poses.gd")

const RETRY := 2.0
const PING := 3.0
const SILENT := 9.0
const HELLO := 4.0
const UNIT_FIRST_LINK := 30.0 # launched by VADS: leave if it never answers
const UNIT_LOST_LINK := 6.0 # or if it goes away, so no orphan is left behind

var connected := false
## Optional welcome.host metadata; missing metadata preserves the VADS audio contract.
var host_name := "机器人软件"
var supports_audio_settings := true

var _peer: StreamPeerTCP = null
var _sent_hello := false
var _token := ""
var _buffer := PackedByteArray()
var _retry := 0.0
var _ping := 0.0
var _heard := 0.0
var _clock := 0.0
var _began := 0.0
var _unit := false
var _lost_at := 0.0


func _ready() -> void:
	if OS.get_cmdline_user_args().has("--body-lab") or OS.get_cmdline_user_args().has("--home-editor"): return
	_unit = OS.get_cmdline_user_args().has("--unit")
	get_tree().auto_accept_quit = false
	_try_connect()


func _notification(what: int) -> void:
	if OS.get_cmdline_user_args().has("--home-editor"):return
	if what == NOTIFICATION_WM_CLOSE_REQUEST:
		leave_together()


## Notify intentional window closure; VADS stays available to reopen the game.
func leave_together() -> void:
	if connected and _peer:
		_write({"type": "quit"})
		_peer.poll()
	get_tree().quit()


func _process(delta: float) -> void:
	if OS.get_cmdline_user_args().has("--body-lab") or OS.get_cmdline_user_args().has("--home-editor"): return
	_collect_boards()
	if connected and owns_bodies: _hall.advance(delta)
	_clock += delta
	if _unit and not connected and _clock - _lost_at > (UNIT_LOST_LINK if _lost_at > 0.0 else UNIT_FIRST_LINK):
		get_tree().quit()
		return
	if _peer == null:
		_retry -= delta
		if _retry <= 0.0:
			_try_connect()
		return
	_peer.poll()
	var status := _peer.get_status()
	if status == StreamPeerTCP.STATUS_CONNECTING:
		if _clock - _began > HELLO:
			_drop()
		return
	if status != StreamPeerTCP.STATUS_CONNECTED:
		_drop()
		return
	if not _sent_hello:
		_sent_hello = true
		_write({"type": "hello", "token": _token, "game": "cabin-world", "furnitureMaker":1, "restaurant": 2, "personal":1, "residentRegistry":1, "actions": 1, "economy": 1, "walk": 1, "residents": 1, "arcadeProfiles": Hall.profiles(), "worldRules": 1, "social": 1, "bodySave": 1, "sleepProfiles": ResidentSleep.profiles(), "toolPoses": ToolPoses.profiles()})
		_heard = _clock
	_read()
	if _peer == null:
		return
	if not connected and _clock - _began > HELLO:
		_drop() # wrong or old token: VADS said nothing
		return
	if connected:
		_ping -= delta
		if _ping <= 0.0:
			_ping = PING
			_write({"type": "ping"})
		if _clock - _heard > SILENT:
			_drop()


func _try_connect() -> void:
	_retry = RETRY
	var file := SharedFeed.data_dir.path_join("world").path_join("game-link.json")
	if not FileAccess.file_exists(file):
		return
	var info = JSON.parse_string(FileAccess.get_file_as_string(file))
	if not info is Dictionary or not info.has("port") or not info.has("token"):
		return
	_token = str(info["token"])
	var peer := StreamPeerTCP.new()
	if peer.connect_to_host("127.0.0.1", int(info["port"])) != OK:
		return
	_peer = peer
	_sent_hello = false
	_buffer.clear()
	_began = _clock


func send(frame: Dictionary) -> void:
	if connected:
		_write(frame)


func _write(frame: Dictionary) -> void:
	if _peer:
		_peer.put_data((JSON.stringify(frame, "", false, true) + "\n").to_utf8_buffer())


func _read() -> void:
	var available := _peer.get_available_bytes()
	if available <= 0:
		return
	var got := _peer.get_data(available)
	if got[0] != OK:
		_drop()
		return
	_buffer.append_array(got[1])
	if _buffer.size()>36*1024*1024:
		_drop();return
	_heard = _clock
	while true:
		var at := _buffer.find(10)
		if at < 0:
			return
		var line := _buffer.slice(0, at).get_string_from_utf8()
		_buffer = _buffer.slice(at + 1)
		var frame = JSON.parse_string(line)
		if frame is Dictionary:
			_handle(frame)
			if _peer == null:
				return


func _handle(frame: Dictionary) -> void:
	# Deleted identities retain recovery saves, but stale hosts may not act on them.
	var removed_actor:String=str(frame.get("actor",frame.get("owner","")))
	if removed_actor!="" and load("res://core/resident_registry.gd").removed(removed_actor) and frame.get("type")!="resident.do":
		var responses:={"economy.do":"economy.result","personal.do":"personal.result","body.open":"body.saved","body.patch":"body.saved","body.get":"body.state","body.do":"body.state","body.sync":"body.state","seat.claim":"seat.result","walk.go":"walk.arrived","restaurant.do":"restaurant.result","restaurant.get":"restaurant.result","entry.route":"entry.result","entry.pass":"entry.result","action.start":"action.cancelled"}
		if responses.has(frame.get("type")):send({"type":responses[frame.type],"id":frame.get("id",""),"actor":removed_actor,"ok":false,"error":"住户已删除"})
		return
	match frame.get("type"):
		"welcome":
			var host_info: Dictionary = frame.get("host", {}) if frame.get("host", {}) is Dictionary else {}
			host_name = str(host_info.get("name", "VADS")).strip_edges().left(40)
			if host_name.is_empty(): host_name = "机器人软件"
			supports_audio_settings = host_info.get("audioSettings", true) == true
			connected = true
			owns_bodies = frame.get("residents") == true
			body_persistence = owns_bodies and frame.get("bodySave") == 1
			social_enabled = owns_bodies and frame.get("social") == 1
			if body_persistence:
				BodySave.load_rows()
				for actor in BodySave.people:
					if not load("res://core/resident_registry.gd").removed(actor):Body.of(actor).load_committed(BodySave.people[actor])
			_ping = 0.0
			SharedFeed.set_link(true)
			connection_changed.emit(true)
		"world":
			SharedFeed.receive(frame.get("presence", {}))
		"clock":
			SharedFeed.set_clock(float(frame.get("now", 0)))
		"weather":
			if frame.has("reading"): SharedFeed.weather = frame.reading
			if frame.has("local"): SharedFeed.local_weather = frame.local
		"quit":
			get_tree().quit()
		"window.show":
			if DisplayServer.get_name() != "headless":
				if get_window().mode == Window.MODE_MINIMIZED:
					get_window().mode = Window.MODE_WINDOWED
				get_window().show()
				get_window().grab_focus()
		"economy.do":
			Economy.handle(frame)
		"walk.go", "walk.cancel":
			walk_ordered.emit(frame)
		"restaurant.do", "restaurant.get":
			restaurant_requested.emit(frame)
		"resident.do":
			var reply:Dictionary=load("res://core/resident_registry.gd").accept(frame)
			send(reply.merged({"type":"resident.result","id":frame.get("id",""),"actor":frame.get("actor","")}))
			if reply.get("ok",false) and frame.get("action") in ["remove","rename_home"]:
				send({"type":"resident.changed","actor":frame.get("actor",""),"removed":frame.get("action")=="remove"})
		"furniture.do":
			var reply:Dictionary=load("res://core/furniture_maker.gd").accept(frame)
			send(reply.merged({"type":"furniture.result","id":frame.get("id",""),"actor":frame.get("actor","")}))
		"personal.do":
			var reply:Dictionary=load("res://core/resident_personal.gd").accept(frame)
			send(reply.merged({"type":"personal.result","id":frame.get("id",""),"actor":frame.get("actor","")}))
		"panel.data":
			panel_arrived.emit(frame)
		"panel.did":
			panel_done.emit(frame)
		"body.open", "body.patch":
			if body_persistence:
				var reply := BodySave.accept(frame)
				if reply.ok:
					var b := Body.of(frame.actor)
					var changes: Dictionary = frame.get("patch", {}).duplicate()
					# The staged computer is replayed live, including its current job.
					# Its durable snapshot is used on restart, never as a tool event.
					changes.erase("computer")
					if frame.type == "body.open" and not reply.state.has("bed"):
						b.load_committed(reply.state)
					else:
						b.load_committed(changes)
				reply.merge({"type": "body.saved", "actor": frame.actor, "id": frame.id})
				send(reply)
		"arcade.view":
			if owns_bodies and frame.get("sessions") is Dictionary:
				arcade_view = {"sessions":Board.restore_numbers(frame.sessions),"history":frame.get("history",[]),"rules":frame.get("rules",{})}
		"arcade.watch":
			if owns_bodies: _hall.watch(frame)
		"arcade.records":
			if owns_bodies and frame.get("history") is Array:
				var history = Records.merge_history(frame.history)
				send({"type":"arcade.history","id":frame.id,"ok":history!=null,"history":history})
		"rules.ask":
			if owns_bodies:
				_answer_rule(frame)
		"body.sleep":
			var profile: Dictionary = Residents.person(str(frame.actor)).get("sleep", {})
			if owns_bodies and not profile.is_empty():
				send({"type": "body.sleepPlan", "id": frame.id, "actor": frame.actor, "decision": ResidentSleep.decide(profile, frame.facts)})
		"body.tool":
			if owns_bodies:
				var visual := ToolPoses.resolve(frame.actor, frame.name, frame.location)
				send({"type": "body.toolPose", "actor": frame.actor, "name": frame.name, "location": frame.location, "visual": visual})
		"body.sync", "body.do", "body.get":
			Body.handle(frame)
		"entry.route", "entry.pass", "entry.revoke":
			Entry.handle(frame)
		"seat.claim":
			Seats.handle_claim(frame)
		"seat.release":
			Seats.release(str(frame.get("owner", "")))
		"action.skip":
			Actions.skip(frame)
		"action.start":
			Actions.start(frame)
		"action.done":
			Actions.phase_done(frame)
		"action.interrupt":
			Actions.interrupt(frame)


func _drop() -> void:
	_hall.sessions.clear()
	for row in arcade_view.sessions.values():
		if row.get("status") in ["waiting","playing"]:
			row.status = "interrupted"
			row.reason = "世界连接中断"
			row.endedAt = SharedFeed.now_ms()
	if _peer:
		_peer.disconnect_from_host()
	_peer = null
	_retry = RETRY
	if connected:
		connected = false
		_lost_at = _clock
		Actions.clear()
		SharedFeed.set_link(false)
		connection_changed.emit(false)

## Only pure decisions cross this boundary. A delayed clothing reply belongs to
## its original connection; a disconnected host finishes its local timer.
func _answer_rule(frame: Dictionary) -> void:
	var peer := _peer
	var value: Variant
	match frame.rule:
		"residentAt":
			value=false
			for resident in get_tree().get_nodes_in_group("world_residents"):
				if resident.key==frame.args.actor:
					value=resident.placed and not resident.is_walking() and resident.order_id=="" and resident.scene_id==frame.args.scene and resident.want_zone==frame.args.zone
					break
		"meetDistance":
			var spots := []
			for actor in frame.args.actors:
				for resident in get_tree().get_nodes_in_group("world_residents"):
					if resident.key!=actor: continue
					if resident.placed and not resident.is_walking() and resident.order_id=="" and resident.scene_id==frame.args.scene:
						var zones: Dictionary=WorldData.scenes[resident.scene_id].zones
						if zones.has(resident.want_zone): spots.append(WorldData.point(zones[resident.want_zone]))
					break
			value={"arrived":spots.size()==2,"near":spots.size()==2 and spots[0].distance_to(spots[1])<=160}
		"changeClothes":
			await get_tree().create_timer(2.5).timeout
			value = true
		"arcadeStep":
			value = Board.advance(frame.args.board, frame.args.action)
		"arcadeAuto":
			# Search can visit thousands of chess positions. Only the result is
			# delivered on the main thread; the board belongs to this request.
			if _board_jobs.size()<8:
				var board: Dictionary = frame.args.board
				var session := _hall.match_for(frame.args)
				if session.get("board") is Dictionary:
					if session.board.ticks>board.ticks:
						send({"type":"rules.answer","id":frame.id,"ok":true,"value":session.board})
						return
					if session.board.ticks==board.ticks: board=session.board.duplicate(true)
				var task := WorkerThreadPool.add_task(_auto_board.bind(board))
				_board_jobs[task]={"id":frame.id,"peer":peer,"board":board,"key":frame.args.get("key",""),
					"matchId":frame.args.get("matchId",""),"at":frame.args.get("at",0)}
				return
		"arcadeLobby":
			value = Board.lobby(frame.args)
		"arcadeSeat":
			value = Hall.seat(frame.args)
		_:
			value = WorldRules.resolve(frame.rule, frame.args)
	if peer == _peer and connected:
		send({"type":"rules.answer", "id":frame.id, "ok":value != null, "value":value})

static func _auto_board(board: Dictionary) -> void:
	Board.restore_numbers(board)
	Board.advance(board,Strategy.suggest(board))

func _collect_boards() -> void:
	for task in _board_jobs.keys():
		if not WorkerThreadPool.is_task_completed(task): continue
		WorkerThreadPool.wait_for_task_completion(task)
		var job: Dictionary=_board_jobs[task]
		_board_jobs.erase(task)
		if connected and _peer==job.peer:
			var session := _hall.match_for(job)
			if not session.is_empty():
				if job.board.status=="playing" and job.at-session.startedAt>Hall.LIMIT[job.board.kind]:
					job.board.status="draw"
					job.board.reason="时间到了"
				session.board=job.board
			send({"type":"rules.answer","id":job.id,"ok":true,"value":job.board})

func _exit_tree() -> void:
	for task in _board_jobs:
		WorkerThreadPool.wait_for_task_completion(task)
