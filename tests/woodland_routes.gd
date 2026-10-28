extends SceneTree
## Native collision/topology audit, not a substitute for player traversal.
## Godot --headless --path . --script tests/woodland_routes.gd
const Valley = preload("res://scripts/valley.gd")
var checks: Array[String] = []
var failures: Array[String] = []
var blocked: Array = []
var sample_count: int = 0

func _initialize() -> void:
	call_deferred("_run")

func check(label: String, success: bool) -> void:
	if success:
		checks.append(label)
	else:
		failures.append(label)
		push_error(label)

func _sample(valley: Node3D, route: Array, label: String) -> float:
	var length: float = 0.0
	for i in range(1,route.size()):
		var a: Vector2 = route[i-1]
		var b: Vector2 = route[i]
		var steps: int = maxi(1,ceili(a.distance_to(b)*2.0))
		length += a.distance_to(b)
		for n in range(steps+1):
			var p: Vector2 = a.lerp(b,float(n)/steps)
			sample_count += 1
			if not valley.is_clear(p.x,p.y):
				blocked.append({"route":label,"x":p.x,"z":p.y})
	return length

func _routes_touch(a: Array, b: Array) -> bool:
	for point: Vector2 in a:
		for i in range(1,b.size()):
			var start: Vector2 = b[i-1]
			var end: Vector2 = b[i]
			var t: float = clampf((point-start).dot(end-start)/(end-start).length_squared(),0.0,1.0)
			if point.distance_to(start.lerp(end,t))<0.1:
				return true
	return false

func _run() -> void:
	var start_ms: int = Time.get_ticks_msec()
	var valley := Valley.new()
	root.add_child(valley)
	check("Expansion retains nine original sanctuaries",valley.definitions.size()==9)
	check("Walkable bounds expand to 250 by 250 units",valley.bounds==125.0)
	var routes: Array = valley.expansion.paths
	check("Original quiet routes gain a connected outer-country network",routes.size()>6)
	var length: float = 0.0
	var original_length: float = 0.0
	for i in routes.size():
		var route_length: float = _sample(valley,routes[i],"trail_%d" % i)
		length += route_length
		if i<6: original_length += route_length
	check("Every trail centerline is clear in the native collision world",blocked.is_empty())
	check("Expanded routes add at least 500 units of walking",length>1057.65)
	var outer_axes: Array[bool] = [false,false,false,false]
	for route: Array in routes:
		for p: Vector2 in route:
			if p.x<-90: outer_axes[0] = true
			if p.x>90: outer_axes[1] = true
			if p.y<-90: outer_axes[2] = true
			if p.y>90: outer_axes[3] = true
	check("Authored walking routes reach new country in all four directions",not outer_axes.has(false))
	var trail_samples: int = sample_count
	var trail_blocked: int = blocked.size()
	_sample(valley,valley.expansion.squirrel_route,"squirrel")
	check("All squirrel route segments are clear",blocked.size()==trail_blocked)
	var occupied_seeds: Array[int] = []
	for i in valley.expansion.collectible_positions.size():
		var p: Vector2 = valley.expansion.collectible_positions[i]
		if not valley.is_clear(p.x,p.y): occupied_seeds.append(i)
	check("All original and added seed locations are clear collision points",valley.expansion.collectible_positions.size()>18 and occupied_seeds.is_empty())
	var old_seed_positions: Array[Vector2] = [Vector2(-28,-25),Vector2(-43,-36),Vector2(-60,-43),Vector2(-63,-15),Vector2(-55,14),Vector2(-38,20),Vector2(-24,-59),Vector2(3,-63),Vector2(30,-54),Vector2(49,-19),Vector2(61,-1),Vector2(53,18),Vector2(29,33),Vector2(43,42),Vector2(16,61),Vector2(-9,53),Vector2(-38,46),Vector2(-54,30)]
	var original_seed_ids_stable: bool = true
	for i in old_seed_positions.size():
		original_seed_ids_stable = original_seed_ids_stable and valley.expansion.collectible_positions[i]==old_seed_positions[i]
	check("Original eighteen seed IDs keep their exact discovery positions",original_seed_ids_stable)
	var seeds_outside_old_world: int = 0
	var seeds_outside_bounds: int = 0
	for p: Vector2 in valley.expansion.collectible_positions:
		if maxf(absf(p.x),absf(p.y))>75.0: seeds_outside_old_world += 1
		if maxf(absf(p.x),absf(p.y))>=valley.bounds: seeds_outside_bounds += 1
	check("Added discoveries occupy new country inside the expanded boundary",seeds_outside_old_world>=10 and seeds_outside_bounds==0)
	var occupied_clearings: Array[String] = []
	for clearing: Dictionary in valley.expansion.clearings:
		var p: Vector2 = clearing.position
		if not valley.is_clear(p.x,p.y): occupied_clearings.append(str(clearing.id))
	check("Every original and added named clearing center is clear",valley.expansion.clearings.size()>6 and occupied_clearings.is_empty())
	var reached: Array[int] = [0]
	var frontier: Array[int] = [0]
	while not frontier.is_empty():
		var current: int = frontier.pop_front()
		for i in routes.size():
			if not reached.has(i) and (_routes_touch(routes[current],routes[i]) or _routes_touch(routes[i],routes[current])):
				reached.append(i)
				frontier.append(i)
	check("Every original and added route shares one connected trail graph",reached.size()==routes.size())
	var seam_blocked: int = blocked.size()
	for seam: Array in [[Vector2(-26,-23),Vector2(-33,-30)],[Vector2(26,-17),Vector2(34,-21)],[Vector2(-1,23),Vector2(-8,31)],[Vector2(-26,20),Vector2(-32,19)],[Vector2(22,26),Vector2(31,30)]]:
		_sample(valley,seam,"core_seam")
	check("Five sampled passages cross the old core boundary without collision",blocked.size()==seam_blocked)
	valley.set_healed(["orchard-ash","orchard-stump","orchard-seeds"],true)
	check("Restored scorched sites expose young shoots",valley.expansion.regrowth["orchard-ash"].visible and valley.expansion.regrowth["orchard-stump"].visible and valley.expansion.regrowth["orchard-seeds"].visible)
	var report: Dictionary = {
		"engine":Engine.get_version_info().string,"status":"passed" if failures.is_empty() else "failed",
		"checks":checks,"failures":failures,"bounds":valley.bounds,"routes":routes.size(),"trail_length":length,
		"original_trail_length":original_length,"added_trail_length":length-original_length,
		"trail_samples":trail_samples,"all_samples":sample_count,"blocked_samples":blocked,
		"occupied_seeds":occupied_seeds,"occupied_clearings":occupied_clearings,
		"colliders":valley.colliders.size(),"expansion_triangles":valley.expansion.geometry.mesh.surface_get_array_len(0)/3,
		"construction_ms":Time.get_ticks_msec()-start_ms,
		"scope":"Authored centerlines, fixed discovery positions, topology and native collision sampling. This does not prove camera readability, fun, frame rate, or actual player traversal."}
	var file := FileAccess.open("res://docs/woodland-routes-verification.json",FileAccess.WRITE)
	file.store_string(JSON.stringify(report,"  "))
	file.close()
	print(JSON.stringify(report,"  "))
	valley.queue_free()
	await process_frame
	quit(0 if failures.is_empty() else 1)
