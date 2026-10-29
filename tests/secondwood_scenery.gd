extends SceneTree
## Audits actual generated scenery footprints and all path centerlines. This
## checks placements and traversal predicates, not camera readability or FPS.
const Scene = preload("res://secondwood.tscn")
const Layout = preload("res://scripts/secondwood_layout.gd")
const Dales = preload("res://scripts/secondwood_dales.gd")
var checks: Array[String] = []
var failures: Array[String] = []
func _initialize() -> void: call_deferred("run")
func check(label: String, condition: bool) -> void:
	if condition: checks.append(label)
	else:
		failures.append(label)
		push_error(label)
func run() -> void:
	var start: int = Time.get_ticks_msec()
	var game: Node3D = Scene.instantiate()
	game.save_enabled = false
	root.add_child(game)
	var scene_ms: int = Time.get_ticks_msec()-start
	var map: Node3D = game.map
	var dale: Node3D = game.find_child("SunlitDales",true,false)
	check("Dales are part of the actual secondwood scene",dale!=null)
	if dale==null:
		dale = Dales.new()
		map.add_child(dale)
		dale.build()
	var floor_safe: bool = true
	var fern_count: int = 0
	var log_count: int = 0
	for detail: Dictionary in map.floor_details:
		if detail.kind=="fern": fern_count += 1
		else: log_count += 1
		for route: Dictionary in Layout.all_routes():
			if Layout.route_distance(detail.position,route.points)-float(detail.radius)<Layout.CORRIDOR_RADIUS: floor_safe = false
		for clearing: Dictionary in Layout.CLEARINGS:
			if Vector2(detail.position).distance_to(clearing.position)-float(detail.radius)<float(clearing.radius): floor_safe = false
	check("Fern and mossy log footprints stay outside all paths and encounters",floor_safe and fern_count>100 and log_count>5)
	var counts: Dictionary = map.scenery_counts
	check("Woodland has many new flower clusters",int(counts.flowers)>100)
	check("Woodland has mushrooms, moss and new pathside trees",int(counts.mushrooms)>20 and int(counts.moss)>20 and int(counts.trees)>20)
	check("Every recorded roadside tree has a generated placement",map.roadside_tree_positions.size()==int(counts.trees))
	var min_route: float = INF
	var min_clearing_edge: float = INF
	var hidden_sightlines: int = 0
	for position: Vector2 in map.roadside_tree_positions:
		for route: Dictionary in Layout.all_routes():
			min_route = minf(min_route,Layout.route_distance(position,route.points))
		for clearing: Dictionary in Layout.CLEARINGS:
			var relative: Vector2 = position-Vector2(clearing.position)
			min_clearing_edge = minf(min_clearing_edge,relative.length()-float(clearing.radius))
			if relative.y>0.0 and relative.y<14.0 and absf(relative.x-relative.y*0.18)<6.0: hidden_sightlines += 1
	check("Roadside tree trunks stay at least 4.8 units from every trail",min_route>=4.8-0.0001)
	check("Roadside trees leave at least four units around each clearing",min_clearing_edge>=4.0-0.0001)
	check("Roadside tree positions preserve initial camera sightlines to clearings",hidden_sightlines==0)
	check("Small hills and pools of sunlight are generated",dale.hill_centers.size()>20 and dale.sun_centers.size()>5)
	var min_hill_route_margin: float = INF
	var min_hill_clearing_margin: float = INF
	var max_hill_height: float = 0.0
	for hill: Dictionary in dale.hill_centers:
		var center: Vector2 = hill.position
		var radius: float = hill.radius
		max_hill_height = maxf(max_hill_height,float(hill.height))
		for route: Dictionary in Layout.all_routes():
			min_hill_route_margin = minf(min_hill_route_margin,Layout.route_distance(center,route.points)-radius-Layout.CORRIDOR_RADIUS)
		for clearing: Dictionary in Layout.CLEARINGS:
			min_hill_clearing_margin = minf(min_hill_clearing_margin,center.distance_to(clearing.position)-radius-float(clearing.radius))
	check("Every hill footprint stays beyond all open and closed trail corridors",min_hill_route_margin>=0.8-0.0001)
	check("Every hill footprint stays clear of interaction clearings",min_hill_clearing_margin>=1.3-0.0001)
	check("New hills remain low enough to be little dales",max_hill_height<=1.1+0.0001)
	var samples: int = 0
	var inaccessible: int = 0
	for route: Dictionary in Layout.all_routes():
		for i in range(1,route.points.size()):
			var a: Vector2 = route.points[i-1]
			var b: Vector2 = route.points[i]
			var steps: int = maxi(1,ceili(a.distance_to(b)*2.0))
			for step in range(steps+1):
				var p: Vector2 = a.lerp(b,float(step)/steps)
				samples += 1
				if not map.is_clear(p.x,p.y,Layout.all_flags()): inaccessible += 1
	check("All fully unlocked centerlines remain walkable",inaccessible==0)
	map.sync([])
	var initially_closed: bool = true
	for route: Dictionary in Layout.SHORTCUTS:
		if map.gates.has(route.id) and not map.gates[route.id].visible: initially_closed = false
	check("Shortcut gates still begin closed",initially_closed)
	map.sync(Layout.all_flags())
	var opened: bool = true
	for route: Dictionary in Layout.SHORTCUTS:
		if map.gates.has(route.id) and map.gates[route.id].visible: opened = false
	check("Shortcut gates still open for their unlocks",opened)
	var mesh: ArrayMesh = map.geometry.mesh
	var chunk_root: Node = map.find_child("WoodlandDetailChunks",true,false)
	var detail_triangles: int = 0
	if chunk_root!=null:
		for child in chunk_root.get_children():
			if child is MeshInstance3D and child.mesh!=null:
				for surface in child.mesh.get_surface_count(): detail_triangles += int(child.mesh.surface_get_array_len(surface)/3)
	check("Scenery details are spatially chunked for visibility culling",chunk_root!=null and chunk_root.get_child_count()>1)
	var report := {"status":"passed" if failures.is_empty() else "failed","checks":checks,"failures":failures,"scenery":counts,"ferns":fern_count,"mossy_logs":log_count,"hills":dale.hill_centers.size(),"sun_pools":dale.sun_centers.size(),"minimum_tree_route_distance":min_route,"minimum_tree_clearing_edge_distance":min_clearing_edge,"minimum_hill_route_margin":min_hill_route_margin,"minimum_hill_clearing_margin":min_hill_clearing_margin,"centerline_samples":samples,"scene_construction_ms":scene_ms,"base_map_triangles":int(mesh.surface_get_array_len(0)/3),"detail_triangles":detail_triangles,"total_map_and_detail_triangles":int(mesh.surface_get_array_len(0)/3)+detail_triangles,"detail_chunks":chunk_root.get_child_count() if chunk_root!=null else 0,"scope":"One native headless startup timing is indicative, not a frame-rate benchmark. Geometry clearance and complete unlocked centerlines are verified from placement data and the native walkability predicate; visual inspection and actual controller progression are separate."}
	var output := FileAccess.open("res://docs/secondwood-scenery-verification.json",FileAccess.WRITE)
	output.store_string(JSON.stringify(report,"  "))
	output.close()
	print(JSON.stringify(report,"  "))
	game.music.stop()
	game.queue_free()
	for i in 3: await process_frame
	quit(0 if failures.is_empty() else 1)
