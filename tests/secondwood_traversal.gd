extends SceneTree
## Spatial checks use explicit progression fixtures. They do not claim to earn
## quests; secondwood_progression.gd separately walks the complete real journey.
const Scene = preload("res://secondwood.tscn")
const Layout = preload("res://scripts/secondwood_layout.gd")
const STEP: float = 0.05
const SPEED: float = 3.2
var checks: Array[String] = []
var failures: Array[String] = []
var samples: int = 0
var walked: float = 0.0
var controller_steps: int = 0
var game: Node

func _initialize() -> void:
	call_deferred("run")

func check(label: String, condition: bool) -> void:
	if condition: checks.append(label)
	else:
		failures.append(label)
		push_error(label)

func p() -> Vector2:
	return Vector2(float(game.state.player.x),float(game.state.player.z))

func relocate(point: Vector2) -> void:
	game.state.player.x = point.x
	game.state.player.z = point.y
	game.body.position = Vector3(point.x,game.map.height_at(point.x,point.y),point.y)
	game.touch_move = Vector2.ZERO

func walk_to(target: Vector2) -> Dictionary:
	var distance: float = 0.0
	var stalls: int = 0
	var jumps: int = 0
	var allowance: int = ceili(p().distance_to(target)/(STEP*SPEED))+60
	for frame in allowance:
		var before: Vector2 = p()
		var difference: Vector2 = target-before
		if difference.length()<0.06: break
		game.touch_move = difference.limit_length(STEP*SPEED)/(STEP*SPEED)
		game._physics_process(STEP)
		controller_steps += 1
		var after: Vector2 = p()
		var moved: float = before.distance_to(after)
		distance += moved
		walked += moved
		stalls = stalls+1 if moved<0.00001 else 0
		if moved>STEP*SPEED+0.002 or not game.map.is_clear(after.x,after.y,game.state.flags()): jumps += 1
		if stalls>=10: break
	game.touch_move = Vector2.ZERO
	return {"walked":distance,"stalls":stalls,"bad_steps":jumps,"endpoint_error":p().distance_to(target)}

func walk_route(points: Array, label: String) -> Dictionary:
	var outcome: Dictionary = {"waypoints":0,"walked":0.0,"bad_steps":0,"stalls":0}
	for i in range(1,points.size()):
		var leg: Dictionary = walk_to(points[i])
		outcome.walked += float(leg.walked)
		outcome.bad_steps += int(leg.bad_steps)
		outcome.stalls += int(leg.stalls)
		if float(leg.endpoint_error)<0.25: outcome.waypoints += 1
		else: break
	check(label+" physically reaches every waypoint",int(outcome.waypoints)==points.size()-1 and p().distance_to(points.back())<0.25)
	check(label+" never stalls or crosses its visible bank",int(outcome.bad_steps)==0 and int(outcome.stalls)==0)
	return outcome

func reachable_cells(healed: Array) -> Dictionary:
	# Orthogonal unit-grid flood fill checks the complete reachable floor, not
	# only route labels, so accidental overlaps cannot silently bypass a gate.
	var start := Vector2i(roundi(Layout.ENTRY.x),roundi(Layout.ENTRY.y))
	var found: Dictionary = {start:true}
	var tested: Dictionary = {start:true}
	var pending: Array[Vector2i] = [start]
	var cursor: int = 0
	while cursor<pending.size():
		var current: Vector2i = pending[cursor]
		cursor += 1
		for direction: Vector2i in [Vector2i.LEFT,Vector2i.RIGHT,Vector2i.UP,Vector2i.DOWN]:
			var next: Vector2i = current+direction
			if tested.has(next): continue
			tested[next] = true
			if game.map.is_clear(next.x,next.y,healed):
				found[next] = true
				pending.append(next)
	return found

func contains(found: Dictionary, point: Vector2) -> bool:
	return found.has(Vector2i(roundi(point.x),roundi(point.y)))

func run() -> void:
	game = Scene.instantiate()
	game.save_enabled = false
	game.save_path = "user://secondwood-traversal-isolated.json"
	root.add_child(game)
	game.set_physics_process(false)
	game.set_process(false)
	game.start_level(false)
	game.music.muted = true
	game.music.stop()
	game.camera_yaw = 0.0
	var length: float = 0.0
	var path_length: float = 0.0
	var shortcut_length: float = 0.0
	for route: Dictionary in Layout.all_routes():
		var size: float = Layout.route_length(route.points)
		length += size
		if Layout.SHORTCUTS.has(route): shortcut_length += size
		else: path_length += size
		for i in range(1,route.points.size()):
			var a: Vector2 = route.points[i-1]
			var b: Vector2 = route.points[i]
			var steps: int = maxi(1,ceili(a.distance_to(b)*2.0))
			for n in range(steps+1):
				var sample: Vector2 = a.lerp(b,float(n)/steps)
				samples += 1
				if not game.map.is_clear(sample.x,sample.y,Layout.all_flags()):
					check("Open authored centerline remains within physical floor "+str(route.id),false)
	check("Second wood has long authored branching and curling walks",Layout.PATHS.size()>=8 and path_length>900 and Layout.SHORTCUTS.size()==9)
	check("Added shortcuts are shorter traversable connections",length>=3050 and length<=3350 and Layout.BOUNDS==156)
	var initial: Dictionary = reachable_cells([])
	check("Initial physical floor connects entrance, keeper and all three visible wounds",contains(initial,Layout.HUB) and contains(initial,Layout.SITES.source.position) and contains(initial,Layout.SITES.hollow.position) and contains(initial,Layout.SITES.ash.position))
	check("Both initial long branches are physically reachable before healing",contains(initial,Layout.ITEMS.vessel.position) and contains(initial,Layout.ITEMS.spore.position))
	check("Full-floor reachability cannot bypass the first ability gate",not contains(initial,Layout.ITEMS.spindle.position))
	check("Full-floor reachability cannot bypass the final all-healed gate",not contains(initial,Layout.FINAL))
	var source: Dictionary = reachable_cells(["source"])
	check("Healing the source connects the northern item through actual floor",contains(source,Layout.ITEMS.spindle.position))
	check("The source alone still cannot reach the final grove",not contains(source,Layout.FINAL))
	var completed: Dictionary = reachable_cells(["source","hollow","ash"])
	check("All land healed connects every discovery and final grove",contains(completed,Layout.FINAL) and contains(completed,Layout.ITEMS.spindle.position))
	check("Progression increases reachable floor rather than merely removing a label",source.size()>initial.size() and completed.size()>source.size())
	var shortcut_samples: Array = []
	for shortcut: Dictionary in Layout.SHORTCUTS:
		var closed_points: int = 0
		var newly_open: int = 0
		for i in range(1,shortcut.points.size()):
			var a: Vector2 = shortcut.points[i-1]
			var b: Vector2 = shortcut.points[i]
			for n in 11:
				var point: Vector2 = a.lerp(b,float(n)/10.0)
				if not game.map.is_clear(point.x,point.y,[]):
					closed_points += 1
					if game.map.is_clear(point.x,point.y,shortcut.requires): newly_open += 1
		check(str(shortcut.id)+" changes blocked ground into a usable return",closed_points>0 and newly_open==closed_points)
		shortcut_samples.append({"id":shortcut.id,"new_walkable_samples":newly_open})
	# A long frame must not jump through a sealed branch. This is an explicit
	# entry fixture, not a quest action, and runs the production substep loop.
	relocate(Layout.SITES.ash.position)
	game.touch_move = (Vector2(-8,-24)-p()).normalized()
	game._physics_process(20.0)
	game.touch_move = Vector2.ZERO
	check("Long-frame movement cannot tunnel through a closed northern walk",game.map.is_clear(p().x,p().y,[]) and p().distance_to(Layout.SITES.ash.position)<9.0 and not game.state.inventory.has("spindle"))
	check("Distant unmarked terrain and outside-world points stay behind banks",not game.map.is_clear(-89,89,[]) and not game.map.is_clear(0,Layout.BOUNDS+1,["source","hollow","ash"]))
	# Geometry fixtures deliberately supply earned state only for route sweeps;
	# the continuous quest test proves how these states are actually obtained.
	game.state.inventory.assign(["vessel","spore","spindle"])
	game.state.healed.assign(["source","hollow","ash"])
	game.state.inventory.append_array(["lens","spool"])
	game.state.crossings_complete.assign(["west-sluice","west-ridge-roots","east-root-bridge","ash-east-cut","south-return"])
	game.state.acorn_state = "planted"
	game.map.sync(game.state.flags())
	var reports: Array = []
	for definition: Dictionary in Layout.all_routes():
		var points: Array = definition.points
		relocate(points[0])
		var forward: Dictionary = walk_route(points,str(definition.id)+" outward")
		var reverse: Array = points.duplicate()
		reverse.reverse()
		var returning: Dictionary = walk_route(reverse,str(definition.id)+" return")
		check(str(definition.id)+" returns to its start without another relocation",p().distance_to(points[0])<0.25)
		reports.append({"id":definition.id,"forward":forward,"return":returning})
	check("Traversal leaves the isolated save disabled",not FileAccess.file_exists(game.save_path) and not game.save_enabled)
	var report: Dictionary = {"engine":Engine.get_version_info().string,"status":"passed" if failures.is_empty() else "failed","checks":checks,"failures":failures,"centerline_samples":samples,"path_length":path_length,"shortcut_length":shortcut_length,"total_authored_length":length,"reachable_floor_cells":{"initial":initial.size(),"source_healed":source.size(),"all_healed":completed.size()},"shortcut_samples":shortcut_samples,"routes":reports,"route_starting_relocations":reports.size(),"controller_steps":controller_steps,"walked_distance":walked,"simulated_seconds":controller_steps*STEP,"scope":"Unit-grid full-floor flood fills test physical gate reachability and accidental spatial bypasses at three progression states. Half-unit samples audit authored centerlines. Controller sweeps use explicit completed-state fixtures, one relocation per route, and walk each route forward and backward; a separate real progression test earns that state continuously. These are not first-time navigation or hardware performance measurements."}
	var output := FileAccess.open("res://docs/secondwood-traversal-verification.json",FileAccess.WRITE)
	output.store_string(JSON.stringify(report,"  "))
	output.close()
	print(JSON.stringify(report,"  "))
	game.music.stop()
	await create_timer(0.15).timeout
	for tween in get_processed_tweens(): tween.kill()
	game.queue_free()
	for i in 3: await process_frame
	quit(0 if failures.is_empty() else 1)
