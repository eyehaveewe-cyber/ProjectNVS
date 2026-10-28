extends SceneTree
## Exercises the actual faun movement controller at fixed simulated steps.
## Each route starts with one relocation, then is walked out and back.
## Godot --headless --path . --script tests/woodland_traversal.gd
const Scene = preload("res://main.tscn")
const STEP: float = 0.05
const SPEED: float = 3.2
var checks: Array[String] = []
var failures: Array[String] = []
var movement_steps: int = 0
var walked: float = 0.0
var game: Node

func _initialize() -> void:
	call_deferred("run")

func check(label: String, success: bool) -> void:
	if success:
		checks.append(label)
	else:
		failures.append(label)
		push_error(label)

func player_position() -> Vector2:
	return Vector2(float(game.state.player.x),float(game.state.player.z))

func relocate(point: Vector2) -> void:
	game.state.player.x = point.x
	game.state.player.z = point.y
	game.body.position = Vector3(point.x,game.valley.height_at(point.x,point.y),point.y)
	game.touch_move = Vector2.ZERO

func walk_to(target: Vector2) -> Dictionary:
	var allowance: int = ceili(player_position().distance_to(target)/(SPEED*STEP))+60
	var consecutive_stalls: int = 0
	var bad_steps: int = 0
	var stalls: int = 0
	var distance_walked: float = 0.0
	var maximum_extent: float = maxf(absf(player_position().x),absf(player_position().y))
	for frame in allowance:
		var before: Vector2 = player_position()
		var difference: Vector2 = target-before
		if difference.length()<0.08:
			break
		game.touch_move = difference.limit_length(SPEED*STEP)/(SPEED*STEP)
		game._physics_process(STEP)
		movement_steps += 1
		var after: Vector2 = player_position()
		var distance: float = before.distance_to(after)
		distance_walked += distance
		walked += distance
		maximum_extent = maxf(maximum_extent,maxf(absf(after.x),absf(after.y)))
		if distance<0.00001:
			consecutive_stalls += 1
		else:
			consecutive_stalls = 0
		if consecutive_stalls>=10:
			stalls += 1
			break
		if distance>SPEED*STEP+0.002 or maxf(absf(after.x),absf(after.y))>game.valley.bounds+0.001:
			bad_steps += 1
	game.touch_move = Vector2.ZERO
	return {"walked_distance":distance_walked,"maximum_axis_extent":maximum_extent,"stalls":stalls,"bad_steps":bad_steps,"endpoint_error":player_position().distance_to(target)}

func walk_route(route: Array, label: String) -> Dictionary:
	var result: Dictionary = {"label":label,"waypoints_walked":0,"waypoints_expected":route.size()-1,"walked_distance":0.0,"maximum_axis_extent":0.0,"stalls":0,"bad_steps":0,"endpoint_error":0.0}
	for i in range(1,route.size()):
		var leg: Dictionary = walk_to(route[i])
		result.walked_distance += float(leg.walked_distance)
		result.maximum_axis_extent = maxf(float(result.maximum_axis_extent),float(leg.maximum_axis_extent))
		result.stalls += int(leg.stalls)
		result.bad_steps += int(leg.bad_steps)
		result.endpoint_error = leg.endpoint_error
		if float(leg.endpoint_error)<0.25:
			result.waypoints_walked += 1
		else:
			check("%s reaches waypoint %d with the actual controller" % [label,i],false)
			break
	check(label+" walks every waypoint and reaches its endpoint",int(result.waypoints_walked)==route.size()-1 and player_position().distance_to(route.back())<0.25)
	check(label+" has no stalls or movement jumps",int(result.stalls)==0 and int(result.bad_steps)==0)
	return result

func boundary_probe(direction: Vector2) -> Dictionary:
	# Select a clear four-unit lane at the actual new edge. No geometry is moved.
	var edge: Vector2 = Vector2.ZERO
	var found: bool = false
	for offset in range(-110,111,5):
		var candidate: Vector2 = direction*game.valley.bounds+Vector2(-direction.y,direction.x)*float(offset)
		var clear: bool = true
		for step in 9:
			var point: Vector2 = candidate-direction*float(step)*0.5
			if not game.valley.is_clear(point.x,point.y):
				clear = false
				break
		if clear:
			edge = candidate
			found = true
			break
	check("A clear controller lane exists at world edge "+str(direction),found)
	if not found: return {"direction":str(direction),"clear_lane":false}
	var start: Vector2 = edge-direction*4.0
	relocate(start)
	var outward: Dictionary = walk_to(edge)
	check("Controller reaches expanded world edge "+str(direction),float(outward.endpoint_error)<0.01)
	game.touch_move = direction
	for i in 20:
		game._physics_process(STEP)
		movement_steps += 1
	game.touch_move = Vector2.ZERO
	check("Controller stays inside expanded world edge "+str(direction),player_position().distance_to(edge)<0.01)
	var returning: Dictionary = walk_to(start)
	check("Controller returns from expanded world edge "+str(direction),float(returning.endpoint_error)<0.01 and int(returning.stalls)==0)
	return {"direction":str(direction),"edge":str(edge),"outward":outward,"return":returning}

func run() -> void:
	game = Scene.instantiate()
	game.save_enabled = false
	game.save_path = "user://woodland-traversal-isolated-test.json"
	root.add_child(game)
	game.set_physics_process(false)
	game.set_process(false)
	game.new_game(false)
	game.music.muted = true
	game.music.stop()
	game.camera_yaw = 0.0
	game.set_pipes(false)
	var reports: Array = []
	var authored_length: float = 0.0
	var original_length: float = 0.0
	var total_waypoints: int = 0
	for route_index in game.valley.expansion.paths.size():
		var route: Array = game.valley.expansion.paths[route_index]
		for i in range(1,route.size()):
			var segment: float = Vector2(route[i-1]).distance_to(route[i])
			authored_length += segment
			if route_index<6: original_length += segment
			total_waypoints += 2
		relocate(route[0])
		var label: String = "Route %d" % (route_index+1)
		var forward: Dictionary = walk_route(route,label+" outward")
		var reversed: Array = route.duplicate()
		reversed.reverse()
		var returning: Dictionary = walk_route(reversed,label+" return")
		check(label+" returns to its start without relocating",player_position().distance_to(route[0])<0.25)
		if route_index>=6:
			check(label+" physically reaches beyond the former world edge",float(forward.maximum_axis_extent)>75.0 and float(returning.maximum_axis_extent)>75.0)
		reports.append({"route":route_index+1,"outward":forward,"return":returning})
	# Fern Hollow has deliberately open ground beside its connecting trail.
	var hollow: Vector2 = game.valley.expansion.clearings[6].position
	var off_trail: Array = [hollow,hollow+Vector2(-2,0),hollow+Vector2(0,2),hollow+Vector2(2,0),hollow+Vector2(0,-2),hollow]
	var off_path_distance: float = 0.0
	for point: Vector2 in off_trail:
		off_path_distance = maxf(off_path_distance,game.valley.expansion.path_distance(point))
	check("Outer clearing has walkable exploration away from the marked path",off_path_distance>1.0)
	relocate(hollow)
	var clearing_walk: Dictionary = walk_route(off_trail,"Fern Hollow off-trail circuit")
	var boundary_reports: Array = []
	for direction: Vector2 in [Vector2.LEFT,Vector2.RIGHT,Vector2.UP,Vector2.DOWN]:
		boundary_reports.append(boundary_probe(direction))
	check("Walking updates the visible faun to the controller's final location",Vector2(game.body.position.x,game.body.position.z).distance_to(player_position())<0.001)
	check("Traversal leaves the isolated test save disabled",not game.save_enabled and not FileAccess.file_exists(game.save_path))
	var report: Dictionary = {
		"engine":Engine.get_version_info().string,"status":"passed" if failures.is_empty() else "failed",
		"checks":checks,"failures":failures,"routes":reports,"starting_relocations":reports.size(),
		"off_trail_circuit":clearing_walk,"boundary_probes":boundary_reports,
		"trail_waypoints_requested":total_waypoints,"controller_steps":movement_steps,"step_seconds":STEP,
		"simulated_seconds":movement_steps*STEP,"authored_distance":authored_length,"original_trail_length":original_length,
		"added_trail_length":authored_length-original_length,"walked_distance":walked,
		"scope":"Every route uses real game._physics_process movement, native collision, normal speed and touch_move input, with one starting relocation per route. Each route is walked forward and backward without relocating between directions. Fern Hollow adds a separate off-trail circuit; four edge probes test clamping and return. Time advances in fixed simulated steps; this is not a frame-rate measurement or human playtest."}
	var file := FileAccess.open("res://docs/woodland-traversal-verification.json",FileAccess.WRITE)
	file.store_string(JSON.stringify(report,"  "))
	file.close()
	print(JSON.stringify(report,"  "))
	game.touch_move = Vector2.ZERO
	game.music.stop()
	await create_timer(0.15).timeout
	for tween in get_processed_tweens(): tween.kill()
	game.queue_free()
	for i in 3: await process_frame
	quit(0 if failures.is_empty() else 1)
