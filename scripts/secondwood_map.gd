extends Node3D
## Native batched terrain for the second woodland. Collision follows the same
## authored corridors whose banks, thorns and return paths are drawn here.
const Layout = preload("res://scripts/secondwood_layout.gd")
var bounds: float = Layout.BOUNDS
var geometry: MeshInstance3D
var gates: Dictionary = {}
var site_nodes: Dictionary = {}
var damaged_nodes: Dictionary = {}
var growth_tweens: Dictionary = {}
var healed: Array = []
var bridge_nodes: Dictionary = {}
var sapling: Node3D
var vertices := PackedVector3Array()
var colors := PackedColorArray()
var material: Material
var rng := RandomNumberGenerator.new()
# Metrics are for placement checks, not collision; scenery remains visual.
var scenery_counts: Dictionary = {"flowers":0,"mushrooms":0,"moss":0,"trees":0}
var roadside_tree_positions: Array[Vector2] = []
var floor_details: Array[Dictionary] = []
var detail_chunks: Node3D

static func height_at(x: float, z: float) -> float:
	return 0.20+sin(x*0.09)*0.12+cos(z*0.11)*0.10

func build(shared_material: Material = null) -> void:
	rng.seed = 735112
	material = shared_material
	if material == null:
		var m := StandardMaterial3D.new()
		m.vertex_color_use_as_albedo = true
		m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		m.cull_mode = BaseMaterial3D.CULL_DISABLED
		material = m
	_ground()
	for route: Dictionary in Layout.all_routes(): _trail(route.points,Color("#b8ad89") if route.requires.is_empty() else Color("#aaa989"))
	for clearing: Dictionary in Layout.CLEARINGS:
		_disc(clearing.position,float(clearing.radius),Color("#819b70"))
		_sign(clearing.position+Vector2(3.3,2.0),str(clearing.name))
	_banks()
	# Keep the original ground and route batch intact. Chunk only the newly
	# added details so the renderer can cull distant flowers and roadside trees.
	var base_vertices: PackedVector3Array = vertices
	var base_colors: PackedColorArray = colors
	vertices = PackedVector3Array()
	colors = PackedColorArray()
	_roadside_vegetation()
	_forest_floor()
	_chunk_roadside_geometry()
	vertices = base_vertices
	colors = base_colors
	_forest()
	_landmarks()
	geometry = _flush("SecondWoodBatchedGeometry",self)
	for route: Dictionary in Layout.all_routes():
		if not route.requires.is_empty(): _gate(route)
	for id: String in Layout.SITES:
		var site: Dictionary = Layout.SITES[id]
		var soil: Color = Color("#9a8463") if id=="source" else Color("#65556e") if id=="hollow" else Color("#5b5750")
		_disc(site.position,4.5,soil,0.024)
		damaged_nodes[id] = _flush("WoundedSoil_"+id,self)
		var group := Node3D.new()
		group.name = "Restored_"+id
		add_child(group)
		for i in 16:
			var p: Vector2 = site.position+Vector2.from_angle(TAU*i/16.0)*(2.5+float(i%3)*0.45)
			_column(_point(p.x,p.y),0.035,0.35+float(i%4)*0.1,Color("#84ad65"),0.5)
			_crown(_point(p.x,p.y,0.50),Vector3(0.17,0.10,0.17),Color("#d8d79b") if i%2 else Color("#a9c991"))
		_flush("NewGrowth",group)
		site_nodes[id] = group
		if id=="source":
			_disc(site.position,2.0,Color("#8cbcb9"),0.03)
			_flush("SpringWater",group)
	for route: Dictionary in Layout.SHORTCUTS:
		if route.id in ["source-cut","hollow-cut","ash-cut"]: continue
		var group := Node3D.new()
		group.name = "LivingBridge_"+str(route.id)
		add_child(group)
		for i in range(1,route.points.size()):
			for side in [-0.65,0.65]:
				var a: Vector2 = route.points[i-1]+Vector2(side,0)
				var b: Vector2 = route.points[i]+Vector2(side,0)
				_beam(_point(a.x,a.y,0.09),_point(b.x,b.y,0.09),0.16,Color("#9cab72"))
		_flush("ReconnectedRoots",group)
		bridge_nodes[route.id] = group
	sapling = Node3D.new()
	sapling.name = "ArtemisYoungCanopy"
	add_child(sapling)
	_column(_point(Layout.CROWN.x,Layout.CROWN.y),0.24,3.0,Color("#92734c"),0.4)
	for i in 5:
		var p: Vector2 = Layout.CROWN+Vector2.from_angle(TAU*i/5.0)*1.1
		_beam(_point(0,-130,1.6),_point(p.x,p.y,2.8),0.08,Color("#92734c"))
		_crown(_point(p.x,p.y,3.0),Vector3(1.1,0.8,1.0),Color("#b4ce7c"))
	_flush("Sapling",sapling)
	sync([])

func is_clear(x: float, z: float, current_healed: Variant = null) -> bool:
	return Layout.is_walkable(Vector2(x,z),healed if current_healed == null else current_healed)

func sync(current_healed: Array, animate: bool = false) -> void:
	var previous: Array = healed.duplicate()
	healed = current_healed.duplicate()
	for route: Dictionary in Layout.all_routes():
		if gates.has(str(route.id)): gates[str(route.id)].visible = not Layout.requirements_met(route.requires,healed)
	for route: Dictionary in Layout.SHORTCUTS:
		if bridge_nodes.has(route.id): bridge_nodes[route.id].visible = Layout.requirements_met(route.requires,healed)
	if sapling!=null:
		sapling.visible = healed.has("planted")
		if not animate: sapling.scale = Vector3.ONE
		elif healed.has("planted") and not previous.has("planted"):
			sapling.scale = Vector3.ONE*0.05
			create_tween().tween_property(sapling,"scale",Vector3.ONE,2.5).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
	for id: String in site_nodes:
		var group: Node3D = site_nodes[id]
		group.visible = healed.has(id)
		if not animate or not group.visible:
			if growth_tweens.has(id):
				growth_tweens[id].kill()
				growth_tweens.erase(id)
			group.position.y = 0.0
		elif not previous.has(id):
			group.position.y = -0.5
			var tween := create_tween()
			growth_tweens[id] = tween
			tween.tween_property(group,"position:y",0.0,1.5).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
	for id: String in damaged_nodes: damaged_nodes[id].visible = not healed.has(id)

func _point(x: float, z: float, lift: float = 0.0) -> Vector3:
	return Vector3(x,height_at(x,z)+lift,z)

func _tri(a: Vector3, b: Vector3, c: Vector3, color: Color) -> void:
	var n: Vector3 = (b-a).cross(c-a).normalized()
	var light: float = n.dot(Vector3(-0.45,0.85,-0.3).normalized())
	var shade: float = 0.65+0.32*maxf(light,-light*0.65)
	for p: Vector3 in [a,b,c]:
		vertices.append(p)
		colors.append(color*Color(shade,shade,shade))

func _quad(a: Vector3, b: Vector3, c: Vector3, d: Vector3, color: Color) -> void:
	_tri(a,b,c,color)
	_tri(a,c,d,color)

func _flush(label: String, parent: Node) -> MeshInstance3D:
	var mesh := ArrayMesh.new()
	var arrays: Array = []
	arrays.resize(Mesh.ARRAY_MAX)
	arrays[Mesh.ARRAY_VERTEX] = vertices
	arrays[Mesh.ARRAY_COLOR] = colors
	if not vertices.is_empty(): mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES,arrays)
	var node := MeshInstance3D.new()
	node.name = label
	node.mesh = mesh
	node.material_override = material
	parent.add_child(node)
	vertices = PackedVector3Array()
	colors = PackedColorArray()
	return node

func _ground() -> void:
	for x in range(-164,164,4):
		for z in range(-164,164,4):
			var tint: Color = Color("#62765b").lightened(rng.randf_range(0.0,0.09))
			_quad(_point(x,z),_point(x+4,z),_point(x+4,z+4),_point(x,z+4),tint)

func _trail(route: Array, color: Color) -> void:
	for i in range(1,route.size()):
		var a: Vector2 = route[i-1]
		var b: Vector2 = route[i]
		var normal := Vector2(-(b-a).y,(b-a).x).normalized()*1.3
		var steps: int = maxi(1,ceili(a.distance_to(b)/2.0))
		for n in steps:
			var p: Vector2 = a.lerp(b,float(n)/steps)
			var q: Vector2 = a.lerp(b,float(n+1)/steps)
			_quad(_point((p+normal).x,(p+normal).y,0.028),_point((q+normal).x,(q+normal).y,0.028),_point((q-normal).x,(q-normal).y,0.028),_point((p-normal).x,(p-normal).y,0.028),color)
		_disc(a,1.3,color,0.028)
	_disc(route.back(),1.3,color,0.028)

func _disc(center: Vector2, radius: float, color: Color, lift: float = 0.02) -> void:
	for i in 18:
		var a: Vector2 = center+Vector2.from_angle(TAU*i/18.0)*radius
		var b: Vector2 = center+Vector2.from_angle(TAU*(i+1)/18.0)*radius
		_tri(_point(center.x,center.y,lift),_point(a.x,a.y,lift),_point(b.x,b.y,lift),color)

func _column(base: Vector3, radius: float, height: float, color: Color, taper: float = 0.75) -> void:
	for i in 6:
		var a := Vector3(cos(TAU*i/6.0),0,sin(TAU*i/6.0))
		var b := Vector3(cos(TAU*(i+1)/6.0),0,sin(TAU*(i+1)/6.0))
		_quad(base+a*radius,base+b*radius,base+b*radius*taper+Vector3.UP*height,base+a*radius*taper+Vector3.UP*height,color)
		_tri(base+Vector3.UP*height,base+a*radius*taper+Vector3.UP*height,base+b*radius*taper+Vector3.UP*height,color.lightened(0.08))

func _crown(center: Vector3, size: Vector3, color: Color) -> void:
	for i in 7:
		var a := Vector3(cos(TAU*i/7.0)*size.x,0,sin(TAU*i/7.0)*size.z)
		var b := Vector3(cos(TAU*(i+1)/7.0)*size.x,0,sin(TAU*(i+1)/7.0)*size.z)
		_tri(center+a,center+b,center+Vector3(0,size.y,0),color)
		_tri(center+b,center+a,center-Vector3(0,size.y*0.4,0),color.darkened(0.1))

func _beam(start: Vector3, end: Vector3, radius: float, color: Color) -> void:
	var axis: Vector3 = (end-start).normalized()
	var side: Vector3 = axis.cross(Vector3.UP if absf(axis.y)<0.9 else Vector3.RIGHT).normalized()
	var up: Vector3 = axis.cross(side).normalized()
	for i in 5:
		var a: Vector3 = (side*cos(TAU*i/5.0)+up*sin(TAU*i/5.0))*radius
		var b: Vector3 = (side*cos(TAU*(i+1)/5.0)+up*sin(TAU*(i+1)/5.0))*radius
		_quad(start+a,start+b,end+b,end+a,color)

func _bank_allowed(point: Vector2) -> bool:
	# Permanent banks describe the eventual corridor network. Stateful roots
	# close the entrances to walks that have not yet recovered.
	for clearing: Dictionary in Layout.CLEARINGS:
		if point.distance_to(clearing.position)<float(clearing.radius)+1.1: return false
	for route: Dictionary in Layout.all_routes():
		if Layout.route_distance(point,route.points)<Layout.CORRIDOR_RADIUS+0.35: return false
	return true

func _banks() -> void:
	for route: Dictionary in Layout.all_routes():
		for i in range(1,route.points.size()):
			var a: Vector2 = route.points[i-1]
			var b: Vector2 = route.points[i]
			var normal := Vector2(-(b-a).y,(b-a).x).normalized()
			var count: int = maxi(1,ceili(a.distance_to(b)/1.2))
			for n in range(count+1):
				for side in [-1,1]:
					var p: Vector2 = a.lerp(b,float(n)/count)+normal*float(side)*3.35
					if not _bank_allowed(p): continue
					_column(_point(p.x,p.y),0.8,0.65+float(n%3)*0.16,Color("#6d7867"),0.8)
					if n%3==0: _crown(_point(p.x,p.y,0.8),Vector3(0.8,0.45,0.8),Color("#66835c"))
	# Clearing rims visibly continue the same low banks. Leave all approach
	# openings clear, including routes whose roots will open later.
	for clearing: Dictionary in Layout.CLEARINGS:
		var steps: int = ceili(TAU*(float(clearing.radius)+0.6)/1.3)
		for i in steps:
			var p: Vector2 = clearing.position+Vector2.from_angle(TAU*i/steps)*(float(clearing.radius)+0.7)
			var open_approach: bool = false
			for route: Dictionary in Layout.all_routes():
				if Layout.route_distance(p,route.points)<3.5: open_approach = true; break
			if open_approach: continue
			_column(_point(p.x,p.y),0.65,0.7,Color("#707c69"),0.8)

func _nearest_route(point: Vector2) -> float:
	var distance: float = INF
	for route: Dictionary in Layout.all_routes():
		distance = minf(distance,Layout.route_distance(point,route.points))
	return distance

func _away_from_clearings(point: Vector2, margin: float) -> bool:
	for clearing: Dictionary in Layout.CLEARINGS:
		if point.distance_to(clearing.position)<float(clearing.radius)+margin: return false
	return true

func _tree_camera_clear(point: Vector2) -> bool:
	# Camera looks towards the north from the south at its initial angle.
	# Preserve important clearing sightlines as in the older forest placement.
	for clearing: Dictionary in Layout.CLEARINGS:
		var local: Vector2 = point-Vector2(clearing.position)
		if local.length()<float(clearing.radius)+4.0: return false
		if local.y>0.0 and local.y<14.0 and absf(local.x-local.y*0.18)<6.0: return false
	return true

func _flower(point: Vector2, color: Color, stem_height: float) -> void:
	var base: Vector3 = _point(point.x,point.y,0.03)
	var top: Vector3 = base+Vector3.UP*stem_height
	# Flat green stem and four broad low-poly petals. Small irregular clumps
	# stay legible from the walking camera without adding separate draw calls.
	_quad(base+Vector3(-0.018,0,0),base+Vector3(0.018,0,0),top+Vector3(0.018,0,0),top+Vector3(-0.018,0,0),Color("#638d4f"))
	for side in 4:
		var angle: float = TAU*side/4.0
		var toward := Vector3(cos(angle),0,sin(angle))
		var across := Vector3(-sin(angle),0,cos(angle))
		var center: Vector3 = top+toward*0.16
		_tri(top,center+across*0.12,center+toward*0.18,color)
		_tri(top,center+toward*0.18,center-across*0.12,color)
	var center: Vector3 = top+Vector3.UP*0.018
	_quad(center+Vector3(-0.045,0,-0.045),center+Vector3(0.045,0,-0.045),center+Vector3(0.045,0,0.045),center+Vector3(-0.045,0,0.045),Color("#f3df97"))
	scenery_counts.flowers += 1

func _mushroom(point: Vector2, size: float, tint: Color) -> void:
	_column(_point(point.x,point.y),0.075*size,0.33*size,Color("#e9dfbd"),0.86)
	_crown(_point(point.x,point.y,0.35*size),Vector3(0.24,0.12,0.24)*size,tint)
	# A single cream fleck makes the cap recognizable from above.
	_crown(_point(point.x+0.06*size,point.y,0.46*size),Vector3(0.04,0.035,0.04)*size,Color("#f6edcf"))
	scenery_counts.mushrooms += 1

func _roadside_vegetation() -> void:
	# Place the small details from authored walk segments, so new country is
	# just as richly planted as the original core. All placements are stable.
	# The two banks remain legible, and nothing alters the walkability predicate.
	var local_rng := RandomNumberGenerator.new()
	local_rng.seed = 870429
	var flower_colors: Array[Color] = [Color("#f1d763"),Color("#ed9c54"),Color("#b495d6")]
	var placed_trees: Array[Vector2] = []
	for route: Dictionary in Layout.PATHS:
		for segment in range(1,route.points.size()):
			var a: Vector2 = route.points[segment-1]
			var b: Vector2 = route.points[segment]
			var side := Vector2(-(b-a).y,(b-a).x).normalized()
			var steps: int = maxi(1,ceili(a.distance_to(b)/4.0))
			for index in steps:
				var middle: Vector2 = a.lerp(b,(float(index)+0.5)/steps)
				for sign_side in [-1,1]:
					var normal: Vector2 = side*float(sign_side)
					var edge: Vector2 = middle+normal*3.35
					if _bank_allowed(edge) and local_rng.randf()<0.58:
						_crown(_point(edge.x,edge.y,0.76),Vector3(0.67,0.15,0.56),Color("#80a85c"))
						scenery_counts.moss += 1
					var cluster: Vector2 = middle+normal*local_rng.randf_range(3.9,5.0)
					if not _away_from_clearings(cluster,1.5) or _nearest_route(cluster)<2.95: continue
					var tint: Color = flower_colors[local_rng.randi_range(0,flower_colors.size()-1)]
					for flower in 7:
						var spot: Vector2 = cluster+Vector2.from_angle(local_rng.randf_range(0,TAU))*local_rng.randf_range(0.0,1.1)
						if _nearest_route(spot)<2.85 or not _away_from_clearings(spot,1.0): continue
						_flower(spot,tint.lightened(local_rng.randf_range(0.0,0.12)),local_rng.randf_range(0.46,0.78))
					if local_rng.randf()<0.48:
						for shroom in 2:
							var spot: Vector2 = cluster+normal*(0.3+float(shroom)*0.42)+side*0.2*float(shroom)
							if _nearest_route(spot)<3.0 or not _away_from_clearings(spot,1.0): continue
							_mushroom(spot,local_rng.randf_range(0.75,1.2),Color("#c36c59") if local_rng.randf()<0.5 else Color("#d4ad77"))
					if local_rng.randf()>0.55: continue
					var tree: Vector2 = cluster+normal*local_rng.randf_range(1.8,3.4)
					if maxf(absf(tree.x),absf(tree.y))>Layout.BOUNDS-2.0 or _nearest_route(tree)<4.8 or not _tree_camera_clear(tree): continue
					var close: bool = false
					for existing: Vector2 in placed_trees:
						if tree.distance_to(existing)<5.2: close = true; break
					if close: continue
					placed_trees.append(tree)
					roadside_tree_positions.append(tree)
					var size: float = local_rng.randf_range(0.75,1.1)
					_column(_point(tree.x,tree.y),0.22*size,3.1*size,Color("#826c4d"),0.65)
					_crown(_point(tree.x,tree.y,3.4*size),Vector3(1.5,1.5,1.4)*size,Color("#7b9c60"))
					_crown(_point(tree.x-0.55,tree.y,2.9*size),Vector3(1.1,0.9,1.0)*size,Color("#a2b873"))
					scenery_counts.trees += 1
	# Fill the ground between neighboring lanes, without putting plants on
	# authored paths or on interaction clearings. Clumps have an uneven edge,
	# so the intervening woodland reads as a place instead of a flower grid.
	for x in range(-150,151,6):
		for z in range(-150,151,6):
			if local_rng.randf()>0.62: continue
			var center := Vector2(float(x)+local_rng.randf_range(-2.2,2.2),float(z)+local_rng.randf_range(-2.2,2.2))
			var distance: float = _nearest_route(center)
			if distance<5.6 or distance>17.0 or not _away_from_clearings(center,4.0): continue
			var tint: Color = flower_colors[local_rng.randi_range(0,flower_colors.size()-1)]
			for flower in 5:
				var spot: Vector2 = center+Vector2.from_angle(local_rng.randf_range(0,TAU))*local_rng.randf_range(0.0,1.1)
				_flower(spot,tint.lightened(local_rng.randf_range(0.0,0.1)),local_rng.randf_range(0.42,0.72))
			if local_rng.randf()<0.35:
				_mushroom(center+Vector2(0.45,0.3),local_rng.randf_range(0.8,1.2),Color("#c36c59") if local_rng.randf()<0.5 else Color("#d4ad77"))

func _fern(p: Vector2, size: float) -> void:
	var base: Vector3 = _point(p.x,p.y,0.04)
	for i in 6:
		var direction := Vector3(cos(TAU*i/6.0),0,sin(TAU*i/6.0))
		var side := Vector3(-direction.z,0,direction.x)
		var tip: Vector3 = base+direction*size+Vector3.UP*size*0.42
		var middle: Vector3 = base.lerp(tip,0.55)+Vector3.UP*size*0.15
		_tri(base,middle+side*size*0.18,tip,Color("#83a65b"))
		_tri(base,tip,middle-side*size*0.18,Color("#628d50"))

func _forest_floor() -> void:
	# A separate seed preserves existing flowers and landmarks. All of this
	# ground cover joins the same spatially culled meshes as the blossoms.
	var plant_rng := RandomNumberGenerator.new()
	plant_rng.seed = 417632
	for x in range(-148,149,6):
		for z in range(-148,149,6):
			var p := Vector2(x+plant_rng.randf_range(-2.0,2.0),z+plant_rng.randf_range(-2.0,2.0))
			var distance: float = _nearest_route(p)
			if distance<4.2 or distance>14.0 or not _away_from_clearings(p,3.0): continue
			var size: float = plant_rng.randf_range(0.45,0.75)
			floor_details.append({"position":p,"radius":size,"kind":"fern"})
			_fern(p,size)
			# Low grass tufts vary the outline of bare patches with only six
			# triangles each; warm eastern grass and cool wetland leaves differ.
			for clump in 2:
				var q: Vector2 = p+Vector2.from_angle(plant_rng.randf_range(0,TAU))*0.7
				var base: Vector3 = _point(q.x,q.y,0.035)
				var tint := Color("#a6ae65") if p.x>80 else Color("#7f9958")
				for blade in 3:
					var side := Vector3(cos(blade*2.1),0,sin(blade*2.1))*0.08
					_tri(base-side,base+side,base+Vector3(0.1,0.25+blade*0.07,0.04),tint)
			if distance>7.0 and _away_from_clearings(p,5.0) and plant_rng.randf()<0.075:
				var direction: Vector2 = Vector2.from_angle(plant_rng.randf_range(0,TAU))
				var start: Vector2 = p-direction*1.1
				var end: Vector2 = p+direction*1.1
				_beam(_point(start.x,start.y,0.22),_point(end.x,end.y,0.22),0.22,Color("#756143"))
				for j in 3:
					var patch: Vector2 = start.lerp(end,float(j+1)/4.0)
					_crown(_point(patch.x,patch.y,0.43),Vector3(0.27,0.06,0.18),Color("#8ba760"))
				floor_details.append({"position":p,"radius":1.35,"kind":"mossy-log"})

func _chunk_roadside_geometry() -> void:
	# Triangles stay intact even at cell boundaries. Chunk centers are close
	# enough that a 75-unit radius retains neighboring details from the camera.
	var buckets: Dictionary = {}
	for i in range(0,vertices.size(),3):
		var center: Vector3 = (vertices[i]+vertices[i+1]+vertices[i+2])/3.0
		var key := Vector2i(floori(center.x/24.0),floori(center.z/24.0))
		if not buckets.has(key): buckets[key] = {"vertices":[],"colors":[]}
		for j in 3:
			buckets[key].vertices.append(vertices[i+j])
			buckets[key].colors.append(colors[i+j])
	detail_chunks = Node3D.new()
	detail_chunks.name = "WoodlandDetailChunks"
	add_child(detail_chunks)
	for key: Vector2i in buckets:
		var origin := Vector3((float(key.x)+0.5)*24.0,0.0,(float(key.y)+0.5)*24.0)
		vertices = PackedVector3Array(buckets[key].vertices)
		for index in vertices.size(): vertices[index] -= origin
		colors = PackedColorArray(buckets[key].colors)
		var chunk: MeshInstance3D = _flush("WoodlandDetail_%d_%d" % [key.x,key.y],detail_chunks)
		chunk.position = origin
		chunk.visibility_range_end = 75.0
		chunk.visibility_range_end_margin = 4.0

func _forest() -> void:
	# Existing deeper-forest trees also respect the new roadside trunks.
	var placed: Array[Vector2] = roadside_tree_positions.duplicate()
	var forest_count: int = 0
	for attempt in 5000:
		if forest_count>=630: break
		var p := Vector2(rng.randf_range(-154,154),rng.randf_range(-154,154))
		if Layout.is_walkable(p,Layout.all_flags()): continue
		var hides_clearing: bool = false
		for clearing: Dictionary in Layout.CLEARINGS:
			var local: Vector2 = p-Vector2(clearing.position)
			if local.length()<float(clearing.radius)+3.0 or (local.y>0.0 and local.y<14.0 and absf(local.x-local.y*0.18)<6.0):
				hides_clearing = true
				break
		if hides_clearing: continue
		var near_path: bool = false
		for route: Dictionary in Layout.all_routes():
			if Layout.route_distance(p,route.points)<6.0: near_path = true; break
		if near_path: continue
		var close: bool = false
		for other: Vector2 in placed:
			if p.distance_to(other)<6.0: close = true; break
		if close: continue
		placed.append(p)
		forest_count += 1
		var size: float = rng.randf_range(0.85,1.35)
		_column(_point(p.x,p.y),0.24*size,3.3*size,Color("#76624b"),0.6)
		_crown(_point(p.x,p.y,3.5*size),Vector3(1.9,1.8,1.7)*size,Color("#71905f"))
		_crown(_point(p.x-0.8,p.y,2.8*size),Vector3(1.4,1.1,1.3)*size,Color("#8ba371"))

func _gate(route: Dictionary) -> void:
	var points: Array = route.points
	var start: Vector2 = points[0]
	var direction: Vector2 = (Vector2(points[1])-start).normalized()
	var distance: float = 6.5
	if str(route.id) in ["west-sluice","west-ridge-roots","east-root-bridge","ash-east-cut","south-return","ridge-descent"]:
		# Keep visible roots outside the interaction clearing, where the closed
		# floor actually stops. Repairs must never stand inside their own gate.
		for step in 24:
			var candidate: Vector2 = start+direction*distance
			var inside: bool = false
			for clearing: Dictionary in Layout.CLEARINGS:
				if candidate.distance_to(clearing.position)<float(clearing.radius)+0.6: inside = true
			if not inside or distance>=start.distance_to(points[1])-1.0: break
			distance += 0.5
	var p: Vector2 = start+direction*distance
	var side := Vector2(-direction.y,direction.x)
	var group := Node3D.new()
	group.name = "Roots_"+str(route.id)
	add_child(group)
	for i in 6:
		var q: Vector2 = p+side*(-3.0+float(i)*1.2)
		_column(_point(q.x,q.y),0.38,1.25+float(i%2)*0.45,Color("#685549"),0.3)
		_beam(_point(q.x,q.y,0.5),_point(q.x+direction.x*0.8,q.y+direction.y*0.8,1.7),0.11,Color("#85715b"))
	_flush("TangledRoots",group)
	gates[str(route.id)] = group
	var hint: String = "ROOTS AWAIT "
	for flag: String in route.requires:
		hint += (str(Layout.SITES[flag].name).to_upper() if Layout.SITES.has(flag) else flag.replace("-"," ").to_upper())+" "
	_sign(p+side*4.0,hint,group)
	# New links have two visible approaches. The shared floor predicate keeps
	# their entire unopened corridor closed even on a long movement frame.
	if str(route.id) in ["west-sluice","west-ridge-roots","east-root-bridge","ash-east-cut","south-return","ridge-descent"]:
		var end: Vector2 = points.back()
		var back: Vector2 = (Vector2(points[points.size()-2])-end).normalized()
		var q: Vector2 = end+back*6.5
		_beam(_point(q.x-back.y*2.5,q.y+back.x*2.5,0.4),_point(q.x+back.y*2.5,q.y-back.x*2.5,1.2),0.35,Color("#685549"))
		_sign(q+Vector2(-back.y,back.x)*4.0,hint,group)
	_flush("GateSignPost_"+str(route.id),group)

func _sign(point: Vector2, text: String, parent: Node = null) -> void:
	_column(_point(point.x,point.y),0.07,1.25,Color("#806a4b"),0.85)
	var label := Label3D.new()
	label.text = text
	label.position = _point(point.x,point.y,1.7)
	label.font_size = 31
	label.pixel_size = 0.01
	label.modulate = Color("#ecdfb0")
	label.outline_modulate = Color("#263d30")
	label.outline_size = 8
	label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	(parent if parent!=null else self).add_child(label)

func _landmarks() -> void:
	_sign(Vector2(-5,47),"WEST: SPRING VESSEL\nEAST: LIVING SPORE\nNORTH: THE WOUNDED WALKS")
	_sign(Vector2(-98,66),"WEST: MIRROR WETLAND\nMOON LENS · BRING SPRING WATER")
	_sign(Vector2(101,62),"EAST: CINDER LOOM · ROOT SPOOL")
	_sign(Vector2(-69,-100),"NORTH: CROWN CLEARING")
	# Wetland pools and blackened eastern stumps give the outer loops distinct silhouettes.
	for i in 24:
		var angle: float = TAU*i/24.0
		var wet := Vector2(-122,10)+Vector2(cos(angle)*15.0,sin(angle)*14.0)
		if not Layout.is_walkable(wet,Layout.all_flags()): _disc(wet,2.0,Color("#709fa2"),0.035)
		var burned := Vector2(122,-15)+Vector2(cos(angle)*14.0,sin(angle)*15.0)
		if not Layout.is_walkable(burned,Layout.all_flags()): _column(_point(burned.x,burned.y),0.35,2.0+float(i%4)*0.5,Color("#504b46"),0.5)
	# A dry stone basin, poisoned roots and charcoal stumps remain after
	# healing; the returning water and small flowers show what changed.
	for i in 9:
		var p: Vector2 = Vector2(-15,25)+Vector2.from_angle(TAU*i/9.0)*2.5
		_column(_point(p.x,p.y),0.5,0.45,Color("#999785"),0.9)
	for i in 7:
		var p: Vector2 = Vector2(18,20)+Vector2.from_angle(TAU*i/7.0)*3.0
		_beam(_point(p.x,p.y,0.3),_point(p.x+cos(i)*1.0,p.y+sin(i)*1.0,0.8),0.15,Color("#716651"))
	for i in 6:
		var p: Vector2 = Vector2(0,-5)+Vector2.from_angle(TAU*i/6.0)*2.8
		_column(_point(p.x,p.y),0.28,0.6,Color("#564c43"),0.85)
	for clearing: Dictionary in Layout.CLEARINGS:
		if clearing.id in ["vessel","spore","spindle","final"]:
			for i in 4:
				var p: Vector2 = clearing.position+Vector2.from_angle(TAU*i/4.0)*4.2
				_column(_point(p.x,p.y),0.30,1.4 if clearing.id=="final" else 0.65,Color("#aaab90"),0.7)
