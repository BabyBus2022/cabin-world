extends "res://ui/player_controls.gd"

func nearby_choices() -> Array:
	var choices:=super.nearby_choices()
	if player.scene_id=="xiaojingyu-home" and Features.on("seaside-path"):
		var zones:Dictionary=WorldData.scenes[player.scene_id].zones
		if zones.has("xj_beach") and zones.has("xj_door"):
			var beach:=WorldData.point(zones.xj_beach)
			var door:=WorldData.point(zones.xj_door)
			add_choice(choices,door,"沿小路去海边",walk_path.bind(beach))
			add_choice(choices,beach,"沿小路回家门",walk_path.bind(door))
	return choices

func walk_path(destination:Vector2) -> void:
	panel.hide()
	player.click_walk(destination)

func begin_effect() -> void:
	super.begin_effect()
	if activity.get("id")=="onsen_pool":
		var water:Dictionary=WorldPresentation.facts().water
		var center:=Vector2(water.x,water.y)
		var radii:=Vector2(water.rx,water.ry)
		player.swim_feet=center+((player.feet-center)/radii).limit_length(1.0)*radii
		tell("方向键或 WASD 游泳，按 E 上岸")

func _process(dt:float) -> void:
	if not is_instance_valid(player) or not player.swim_feet.is_finite():
		super._process(dt)
		return
	if not viewing_player() or activity.get("id")!="onsen_pool" or player.action!="swim":
		stop_activity()
		super._process(dt)
		return
	var direction:=Vector2.ZERO
	if allows_input():
		direction.x=float(Input.is_physical_key_pressed(KEY_D) or Input.is_physical_key_pressed(KEY_RIGHT))-float(Input.is_physical_key_pressed(KEY_A) or Input.is_physical_key_pressed(KEY_LEFT))
		direction.y=float(Input.is_physical_key_pressed(KEY_S) or Input.is_physical_key_pressed(KEY_DOWN))-float(Input.is_physical_key_pressed(KEY_W) or Input.is_physical_key_pressed(KEY_UP))
	swim_step(direction,dt)
	# Keep the shared HUD, seat, input routing and proximity interaction active.
	_input_was_moving=direction!=Vector2.ZERO
	activity.left=maxf(activity.left,5)
	super._process(dt)
	player.direction_input=Vector2.ZERO
	action_button.text="上岸  E"

func swim_step(direction:Vector2,dt:float) -> void:
	var water:Dictionary=WorldPresentation.facts().water
	var center:=Vector2(water.x,water.y)
	var radii:=Vector2(water.rx,water.ry)
	var next:Vector2=player.swim_feet+direction.limit_length(1.0)*85.0*minf(dt,.08)
	player.swim_feet=center+((next-center)/radii).limit_length(1.0)*radii
	if direction.x!=0:player.swim_flip=direction.x<0

func stop_activity() -> void:
	var swimming:bool=is_instance_valid(player) and player.swim_feet.is_finite() and activity.get("id")=="onsen_pool"
	if is_instance_valid(player):player.swim_feet=Vector2.INF
	super.stop_activity()
	if swimming:
		var result:=transact("use_record",{"objectId":"onsen_pool","use":"swim","label":"游泳"})
		if result.get("ok"):transact("experience",{"args":{"objectId":"onsen_pool","use":"swim","label":"游泳","now":SharedFeed.now_ms()}})

