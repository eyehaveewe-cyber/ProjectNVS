extends Node3D
## The quiet country outside the original nine sanctuaries. All geometry is
## authored here, batched once, and uses the same ground height as the faun.
const BOUNDS: float = 125.0
const CORE: float = 28.5
# Seed indices are save identifiers. Append positions when expanding the map;
# never reorder the earlier entries or existing saves would collect other seeds.
const COLLECTIBLE_POSITIONS: Array[Vector2] = [
	Vector2(-28,-25),Vector2(-43,-36),Vector2(-60,-43),Vector2(-63,-15),Vector2(-55,14),Vector2(-38,20),
	Vector2(-24,-59),Vector2(3,-63),Vector2(30,-54),Vector2(49,-19),Vector2(61,-1),Vector2(53,18),
	Vector2(29,33),Vector2(43,42),Vector2(16,61),Vector2(-9,53),Vector2(-38,46),Vector2(-54,30),
	Vector2(-75,-59),Vector2(-102,-86),Vector2(-55,-108),Vector2(3,-105),Vector2(54,-102),Vector2(102,-44),
	Vector2(112,11),Vector2(69,97),Vector2(7,113),Vector2(-89,77),Vector2(-108,21),Vector2(-111,-40)
]
var paths: Array = []
var clearings: Array[Dictionary] = []
var collectible_positions: Array[Vector2] = []
var squirrel_route: Array[Vector2] = []
var colliders: Array[Dictionary] = []
var vertices := PackedVector3Array()
var colors := PackedColorArray()
var regrowth: Dictionary = {}
var growth_tweens: Dictionary = {}
var restored: Array = []
var geometry: MeshInstance3D
var vertex_material: Material
var rng := RandomNumberGenerator.new()

func build(shared_material: Material, sites: Array) -> void:
	vertex_material = shared_material
	rng.seed = 901327
	_setup_routes()
	# A scenery skirt continues past the playable edge, so approaching the
	# boundary does not reveal a cut edge beneath the exploration camera.
	var edge: float = BOUNDS+12.0
	_ground(-edge,-CORE,-edge,edge)
	_ground(CORE,edge,-edge,edge)
	_ground(-CORE,CORE,-edge,-CORE)
	_ground(-CORE,CORE,CORE,edge)
	for route: Array in paths:
		_trail(route)
	_landmarks()
	_woodland()
	for site: Dictionary in sites:
		if str(site.kind) == "scorch":
			_stump_garden(site)
	var mesh := ArrayMesh.new()
	var arrays: Array = []
	arrays.resize(Mesh.ARRAY_MAX)
	arrays[Mesh.ARRAY_VERTEX] = vertices
	arrays[Mesh.ARRAY_COLOR] = colors
	mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES,arrays)
	geometry = MeshInstance3D.new()
	geometry.name = "WildwoodBatchedGeometry"
	geometry.mesh = mesh
	geometry.material_override = shared_material
	add_child(geometry)
	vertices.clear()
	colors.clear()

static func height_at(x: float, z: float) -> float:
	return 0.18 + sin(x*0.12+0.5)*0.16 + cos(z*0.14-0.3)*0.12 + sin((x+z)*0.18)*0.075

func _setup_routes() -> void:
	paths = [
		[Vector2(-19,-17),Vector2(-26,-23),Vector2(-33,-30),Vector2(-47,-35),Vector2(-58,-47)],
		[Vector2(-47,-35),Vector2(-62,-22),Vector2(-65,-4),Vector2(-55,10),Vector2(-38,18),Vector2(-26,20)],
		[Vector2(-58,-47),Vector2(-43,-58),Vector2(-23,-62),Vector2(0,-61),Vector2(24,-57),Vector2(42,-44),Vector2(48,-17)],
		[Vector2(20,-13),Vector2(26,-17),Vector2(34,-21),Vector2(48,-17),Vector2(59,-5),Vector2(58,12),Vector2(45,24),Vector2(31,30),Vector2(22,26)],
		[Vector2(-1,23),Vector2(-8,31),Vector2(-17,42),Vector2(-7,55),Vector2(13,60),Vector2(33,52),Vector2(45,38),Vector2(45,24)],
		[Vector2(-17,42),Vector2(-39,43),Vector2(-55,29),Vector2(-55,10)],
		# Five outer walks share landmarks to make one circuit, with inward
		# returns to familiar clearings instead of compulsory out-and-back trips.
		[Vector2(-58,-47),Vector2(-74,-57),Vector2(-90,-69),Vector2(-99,-88),Vector2(-82,-105),Vector2(-54,-110),Vector2(-27,-105),Vector2(0,-105),Vector2(0,-84),Vector2(0,-61)],
		[Vector2(0,-105),Vector2(28,-108),Vector2(55,-100),Vector2(80,-84),Vector2(96,-64),Vector2(104,-46),Vector2(87,-32),Vector2(70,-18),Vector2(59,-5)],
		[Vector2(104,-46),Vector2(111,-20),Vector2(110,12),Vector2(103,42),Vector2(88,73),Vector2(67,99),Vector2(45,104),Vector2(24,93),Vector2(13,75),Vector2(13,60)],
		[Vector2(67,99),Vector2(40,113),Vector2(8,115),Vector2(-23,108),Vector2(-51,94),Vector2(-73,85),Vector2(-91,75),Vector2(-77,60),Vector2(-59,50),Vector2(-39,43)],
		[Vector2(-91,75),Vector2(-107,49),Vector2(-111,21),Vector2(-109,-8),Vector2(-112,-40),Vector2(-106,-68),Vector2(-99,-88)]
	]
	squirrel_route = [Vector2(-23,-20.43),Vector2(-26,-23),Vector2(-33,-30),Vector2(-47,-35),Vector2(-54,-42),Vector2(-58,-47)]
	clearings = [
		{"id":"moonmere","name":"MOONMERE","position":Vector2(-58,-47),"radius":7.0},
		{"id":"dryad-glade","name":"THE DRYAD GLADE","position":Vector2(-55,10),"radius":7.0},
		{"id":"reedwater","name":"REEDWATER BEND","position":Vector2(59,-5),"radius":7.0},
		{"id":"artemis-meadow","name":"ARTEMIS' MEADOW","position":Vector2(13,60),"radius":9.0},
		{"id":"stump-nursery","name":"THE STUMP NURSERY","position":Vector2(-39,43),"radius":7.0},
		{"id":"north-listening","name":"THE LISTENING STONES","position":Vector2(0,-61),"radius":6.0},
		{"id":"fern-hollow","name":"FERN HOLLOW","position":Vector2(-99,-88),"radius":8.0},
		{"id":"wind-stones","name":"THE WIND STONES","position":Vector2(0,-105),"radius":9.0},
		{"id":"willow-pool","name":"WILLOW POOL","position":Vector2(104,-46),"radius":9.0},
		{"id":"sunwash-meadow","name":"SUNWASH MEADOW","position":Vector2(67,99),"radius":10.0},
		{"id":"elder-ring","name":"THE ELDER RING","position":Vector2(-91,75),"radius":9.0}
	]
	collectible_positions = COLLECTIBLE_POSITIONS

func _point(x: float, z: float, lift: float = 0.0) -> Vector3:
	return Vector3(x,height_at(x,z)+lift,z)

func _triangle(a: Vector3, b: Vector3, c: Vector3, color: Color) -> void:
	var normal: Vector3 = (b-a).cross(c-a).normalized()
	var light: float = normal.dot(Vector3(-0.45,0.85,-0.3).normalized())
	var shade: float = 0.62+0.35*maxf(light,-light*0.65)
	var shaded: Color = color * Color(shade,shade,shade)
	for p: Vector3 in [a,b,c]:
		vertices.append(p)
		colors.append(shaded)

func _quad(a: Vector3, b: Vector3, c: Vector3, d: Vector3, color: Color) -> void:
	_triangle(a,b,c,color)
	_triangle(a,c,d,color)

func _ground(x0: float, x1: float, z0: float, z1: float) -> void:
	var palette: Array[Color] = [Color("#718b60"),Color("#7d9367"),Color("#879b6b"),Color("#7b9469")]
	var width: int = ceili((x1-x0)/2.5)
	var depth: int = ceili((z1-z0)/2.5)
	for ix in width:
		for iz in depth:
			var x: float = lerpf(x0,x1,float(ix)/width)
			var xx: float = lerpf(x0,x1,float(ix+1)/width)
			var z: float = lerpf(z0,z1,float(iz)/depth)
			var zz: float = lerpf(z0,z1,float(iz+1)/depth)
			_quad(_point(x,z),_point(xx,z),_point(xx,zz),_point(x,zz),palette[rng.randi_range(0,palette.size()-1)])

func _trail(route: Array) -> void:
	for i in range(1,route.size()):
		var a: Vector2 = route[i-1]
		var b: Vector2 = route[i]
		var normal := Vector2(-(b-a).y,(b-a).x).normalized()*1.0
		var steps: int = maxi(1,ceili(a.distance_to(b)/2.0))
		for n in steps:
			var start: Vector2 = a.lerp(b,float(n)/steps)
			var end: Vector2 = a.lerp(b,float(n+1)/steps)
			_quad(_point((start+normal).x,(start+normal).y,0.036),_point((end+normal).x,(end+normal).y,0.036),_point((end-normal).x,(end-normal).y,0.036),_point((start-normal).x,(start-normal).y,0.036),Color("#b6ad88"))
		for n in range(0,steps,3):
			var p: Vector2 = a.lerp(b,float(n)/steps)
			_disc(p,0.22,Color("#c7bd98"),0.043)

func path_distance(point: Vector2) -> float:
	var closest: float = INF
	for route: Array in paths:
		for i in range(1,route.size()):
			var a: Vector2 = route[i-1]
			var b: Vector2 = route[i]
			var t: float = clampf((point-a).dot(b-a)/(b-a).length_squared(),0.0,1.0)
			closest = minf(closest,point.distance_to(a.lerp(b,t)))
	return closest

func _clearing_distance(point: Vector2) -> float:
	var best: float = INF
	for clearing: Dictionary in clearings:
		best = minf(best,point.distance_to(clearing.position)-float(clearing.radius))
	return best

func _disc(center: Vector2, radius: float, color: Color, lift: float = 0.025) -> void:
	for i in 12:
		var a: Vector2 = center+Vector2.from_angle(TAU*i/12.0)*radius
		var b: Vector2 = center+Vector2.from_angle(TAU*(i+1)/12.0)*radius
		_triangle(_point(center.x,center.y,lift),_point(a.x,a.y,lift),_point(b.x,b.y,lift),color)

func _column(base: Vector3, radius: float, height: float, color: Color, taper: float = 0.7, segments: int = 6) -> void:
	for i in segments:
		var a := Vector3(cos(TAU*i/segments),0,sin(TAU*i/segments))
		var b := Vector3(cos(TAU*(i+1)/segments),0,sin(TAU*(i+1)/segments))
		_quad(base+a*radius,base+b*radius,base+b*radius*taper+Vector3.UP*height,base+a*radius*taper+Vector3.UP*height,color)
		_triangle(base+Vector3.UP*height,base+a*radius*taper+Vector3.UP*height,base+b*radius*taper+Vector3.UP*height,color.lightened(0.12))

func _crown(center: Vector3, size: Vector3, color: Color) -> void:
	for i in 7:
		var a := Vector3(cos(TAU*i/7.0)*size.x,0,sin(TAU*i/7.0)*size.z)
		var b := Vector3(cos(TAU*(i+1)/7.0)*size.x,0,sin(TAU*(i+1)/7.0)*size.z)
		_triangle(center+a,center+b,center+Vector3(0,size.y,0),color)
		_triangle(center+b,center+a,center-Vector3(0,size.y*0.45,0),color.darkened(0.10))

func _tree(point: Vector2, size: float) -> void:
	var base: Vector3 = _point(point.x,point.y)
	_column(base,0.22*size,3.3*size,Color("#786244"),0.53)
	_crown(base+Vector3(0,3.6*size,0),Vector3(1.5,1.7,1.4)*size,Color("#789b63"))
	_crown(base+Vector3(-0.8,2.9,0.1)*size,Vector3(1.0,1.1,1.0)*size,Color("#90aa71"))
	_crown(base+Vector3(0.8,3.2,-0.1)*size,Vector3(0.9,1.3,1.0)*size,Color("#6b905c"))
	colliders.append({"x":point.x,"z":point.y,"radius":0.28*size})

func _woodland() -> void:
	var placed: Array[Vector2] = []
	for attempt in 3600:
		if placed.size() >= 680:
			break
		var p := Vector2(rng.randf_range(-BOUNDS+3.0,BOUNDS-3.0),rng.randf_range(-BOUNDS+3.0,BOUNDS-3.0))
		if maxf(absf(p.x),absf(p.y)) < 31.0 or path_distance(p)<3.1 or _clearing_distance(p)<1.5 or _seed_distance(p)<2.2 or _elder_view_apron(p):
			continue
		var blocked: bool = false
		for other: Vector2 in placed:
			if p.distance_to(other)<4.6:
				blocked = true
				break
		if blocked:
			continue
		placed.append(p)
		_tree(p,rng.randf_range(0.9,1.6))
	# Low distant silhouettes sit outside the walkable boundary.
	for i in 64:
		var direction := Vector2.from_angle(TAU*i/64.0)
		# Square-edge placement keeps diagonal silhouettes outside the bounds too.
		var p: Vector2 = direction*rng.randf_range(BOUNDS+12.0,BOUNDS+22.0)/maxf(absf(direction.x),absf(direction.y))
		_crown(_point(p.x,p.y,-1.5),Vector3(rng.randf_range(5,9),rng.randf_range(6,13),6),Color("#798877"))

func _elder_view_apron(point: Vector2) -> bool:
	# The default exploration camera looks into the ring from the southeast.
	# Keep this local foreground apron open so crowns cannot cover its center,
	# junction signs and entering paths. The rest of the forest keeps its density.
	var local: Vector2 = point-Vector2(-91,75)
	var facing := Vector2(0.179,0.984).normalized()
	var depth: float = local.dot(facing)
	return depth > -2.0 and depth < 20.0 and absf(local.cross(facing)) < 10.0

func _seed_distance(point: Vector2) -> float:
	var closest: float = INF
	for seed: Vector2 in collectible_positions:
		closest = minf(closest,point.distance_to(seed))
	return closest

func _sign(point: Vector2, text: String) -> void:
	_column(_point(point.x,point.y),0.08,1.3,Color("#766247"),0.9,5)
	var label := Label3D.new()
	label.text = text
	label.position = _point(point.x,point.y,1.7)
	label.font_size = 38
	label.pixel_size = 0.011
	label.modulate = Color("#f1dfaa")
	label.outline_modulate = Color("#263f30")
	label.outline_size = 10
	label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	label.no_depth_test = false
	add_child(label)

func _landmarks() -> void:
	for clearing: Dictionary in clearings:
		_disc(clearing.position,float(clearing.radius),Color("#8fa776"),0.015)
		_sign(clearing.position+Vector2(3.5,2),str(clearing.name))
	_sign(Vector2(-24,-20),"MOONMERE  ↖\nA squirrel knows the way")
	_sign(Vector2(24,-14),"REEDWATER  ↗\nTake the long way round")
	_sign(Vector2(-3,27),"ARTEMIS' MEADOW  ↓\nQuiet paths beyond the orchard")
	_disc(Vector2(-60,-49),3.5,Color("#7ea9a5"),0.03)
	_disc(Vector2(-60,-49),2.7,Color("#9dbdb3"),0.036)
	_disc(Vector2(63,-6),3.2,Color("#779d98"),0.03)
	for i in 7:
		var p: Vector2 = Vector2(0,-61)+Vector2.from_angle(TAU*i/7.0)*3.8
		if path_distance(p)<1.6:
			continue
		_column(_point(p.x,p.y),0.42,1.5+float(i%3)*0.25,Color("#a5a28b"),0.85,5)
		colliders.append({"x":p.x,"z":p.y,"radius":0.48})
	# Broad flower arcs make Artemis' clearing distinct without filling the path.
	for i in 35:
		var a: float = TAU*i/35.0
		var p := Vector2(13,60)+Vector2.from_angle(a)*7.5
		_column(_point(p.x,p.y),0.025,0.3,Color("#607b4c"),0.7,4)
		_crown(_point(p.x,p.y,0.35),Vector3(0.16,0.07,0.16),Color("#e5d3a0"))
	# This nursery keeps its old stumps; rain can later coax up a second growth.
	for i in 8:
		var p := Vector2(-39,43)+Vector2.from_angle(TAU*i/8.0)*3.8
		_column(_point(p.x,p.y),0.37,0.45,Color("#70634d"),0.92)
	_far_landmarks()

func _far_landmarks() -> void:
	# Junction signs show destinations in both directions. The outer walks are
	# optional quiet loops; no seed count or restoration state gates a return.
	_sign(Vector2(-62,-49),"FERN HOLLOW  NW\nMOONMERE  SE")
	_sign(Vector2(4,-82),"WIND STONES  NORTH\nLIVING VALLEY  SOUTH")
	_sign(Vector2(65,-9),"WILLOW POOL  NE\nREEDWATER  SW")
	_sign(Vector2(17,77),"SUNWASH  NE\nARTEMIS' MEADOW  SOUTH")
	_sign(Vector2(-62,53),"ELDER RING  NW\nSTUMP NURSERY  EAST")
	_sign(Vector2(-103,-83),"WIND STONES  EAST\nELDER RING  SOUTH")
	_sign(Vector2(100,-42),"WIND STONES  NW\nSUNWASH  SOUTH")
	_sign(Vector2(64,95),"ELDER RING  WEST\nARTEMIS' MEADOW  NW")
	_sign(Vector2(-87,79),"FERN HOLLOW  NORTH\nSTUMP NURSERY  EAST")
	# Fern Hollow has a fallen elder at the far side, with space to walk around
	# its end. Low fern fans frame it without closing the traversable center.
	_beam(_point(-105,-93,0.6),_point(-94,-95,0.6),0.6,Color("#736044"))
	for i in 6:
		var p := Vector2(-105,-93).lerp(Vector2(-94,-95),float(i)/5.0)
		colliders.append({"x":p.x,"z":p.y,"radius":0.72})
	for i in 22:
		var angle: float = TAU*i/22.0
		var p: Vector2 = Vector2(-99,-88)+Vector2.from_angle(angle)*6.6
		if path_distance(p)<1.8 or _seed_distance(p)<1.5: continue
		_fern(p,0.7+float(i%3)*0.15)
	# Tall, staggered stones give the northern loop an identifiable skyline.
	for i in 5:
		var p: Vector2 = Vector2(0,-105)+Vector2.from_angle(PI+float(i)*PI/4.0)*6.5
		if path_distance(p)<2.2: continue
		_column(_point(p.x,p.y),0.65,2.7+float(i%3)*0.8,Color("#b0ada0"),0.74,5)
		colliders.append({"x":p.x,"z":p.y,"radius":0.72})
	# The pool sits beside the path rather than over it. Its low bank and
	# drooping willow silhouette distinguish this bend from the old marsh.
	_disc(Vector2(109,-49),3.8,Color("#709c9f"),0.033)
	_disc(Vector2(109,-49),2.9,Color("#99bcbb"),0.038)
	_column(_point(110,-53),0.38,3.6,Color("#74674a"),0.62)
	colliders.append({"x":110.0,"z":-53.0,"radius":0.46})
	for side in [-1,1]:
		_crown(_point(110+float(side)*1.4,-53,3.7),Vector3(2.1,1.1,1.8),Color("#87ad7b"))
		for i in 5:
			var x: float = 110+float(side)*(1.2+float(i)*0.35)
			_beam(_point(x,-52.2,3.7),_point(x,-52.2,1.5+float(i%3)*0.25),0.055,Color("#92b581"))
	# Wide arcs of low flowers keep the southern meadow open for free walking.
	for i in 66:
		var angle: float = TAU*i/66.0
		var p: Vector2 = Vector2(67,99)+Vector2.from_angle(angle)*(6.5+float(i%3))
		if path_distance(p)<1.7 or _seed_distance(p)<1.2: continue
		_column(_point(p.x,p.y),0.025,0.28,Color("#688150"),0.7,4)
		_crown(_point(p.x,p.y,0.35),Vector3(0.18,0.1,0.18),Color("#e8cb85") if i%2 else Color("#dca9b1"))
	# Broad elders frame the distant arc of an open ring. The southeastern
	# apron stays clear for the exploration camera and the inward return path.
	# Gaps in the arc keep both northern approaches physically open.
	for i in 7:
		var p: Vector2 = Vector2(-91,75)+Vector2.from_angle(PI+PI*float(i)/6.0)*7.2
		if path_distance(p)<3.1 or _seed_distance(p)<2.2: continue
		_tree(p,1.85)
		for root_index in 3:
			var outward: Vector2 = Vector2.from_angle(TAU*root_index/3.0+float(i))
			var end: Vector2 = p+outward*1.1
			_beam(_point(p.x,p.y,0.3),_point(end.x,end.y,0.08),0.12,Color("#786244"))

func _fern(point: Vector2, size: float) -> void:
	for i in 7:
		var direction := Vector2.from_angle(TAU*i/7.0)
		var center: Vector3 = _point(point.x,point.y,0.1)
		var tip: Vector3 = _point(point.x+direction.x*size,point.y+direction.y*size,0.38*size)
		var side := Vector3(-direction.y,0,direction.x)*0.18*size
		_triangle(center,tip+side,tip,Color("#6c9c69"))
		_triangle(center,tip,tip-side,Color("#8bb47b"))

func _beam(start: Vector3, end: Vector3, radius: float, color: Color) -> void:
	var axis: Vector3 = (end-start).normalized()
	var reference := Vector3.UP if absf(axis.dot(Vector3.UP))<0.9 else Vector3.RIGHT
	var side: Vector3 = axis.cross(reference).normalized()
	var up: Vector3 = axis.cross(side).normalized()
	for i in 7:
		var a: Vector3 = (side*cos(TAU*i/7.0)+up*sin(TAU*i/7.0))*radius
		var b: Vector3 = (side*cos(TAU*(i+1)/7.0)+up*sin(TAU*(i+1)/7.0))*radius
		_quad(start+a,start+b,end+b,end+a,color)
		_triangle(start,start+b,start+a,color.lightened(0.12))
		_triangle(end,end+a,end+b,color.lightened(0.12))

func _stump_garden(site: Dictionary) -> void:
	var group := Node3D.new()
	group.name = "Sprouts_"+str(site.id)
	add_child(group)
	regrowth[str(site.id)] = group
	for offset: Vector2 in [Vector2(-2.5,-0.2),Vector2(2.3,0.9)]:
		var p := Vector2(float(site.x),float(site.z))+offset
		_column(_point(p.x,p.y),0.35,0.52,Color("#554c40"),0.88)
		_column(_point(p.x,p.y,0.52),0.29,0.025,Color("#aa8c65"),1.0)
		for n in 6:
			var shoot := Node3D.new()
			shoot.position = _point(p.x,p.y,0.5)+Vector3(cos(TAU*n/6.0)*0.18,0,sin(TAU*n/6.0)*0.18)
			shoot.rotation.y = TAU*n/6.0
			group.add_child(shoot)
			var stem := MeshInstance3D.new()
			var stem_mesh := CylinderMesh.new()
			stem_mesh.top_radius = 0.012
			stem_mesh.bottom_radius = 0.035
			stem_mesh.height = 0.6+float(n%3)*0.2
			stem_mesh.radial_segments = 4
			stem.mesh = stem_mesh
			stem.position.y = stem_mesh.height*0.5
			stem.rotation.z = 0.3
			stem.material_override = _solid_material(Color("#81a363"))
			shoot.add_child(stem)
			for side in [-1,1]:
				var leaf := MeshInstance3D.new()
				var mesh := SphereMesh.new()
				mesh.radius = 0.14
				mesh.height = 0.1
				mesh.radial_segments = 5
				mesh.rings = 2
				leaf.mesh = mesh
				leaf.position = Vector3(float(side)*0.12,0.34+float(side)*0.13,0)
				leaf.rotation.z = float(side)*0.4
				leaf.material_override = _solid_material(Color("#a1c57a") if n%2 else Color("#e3c39a"))
				shoot.add_child(leaf)
	group.hide()

func _solid_material(color: Color) -> StandardMaterial3D:
	var material := StandardMaterial3D.new()
	material.albedo_color = color
	material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	return material

func set_healed(ids: Array, immediate: bool = false) -> void:
	for id: String in regrowth:
		var group: Node3D = regrowth[id]
		var enabled: bool = ids.has(id)
		if enabled and not restored.has(id):
			if growth_tweens.has(id):
				growth_tweens[id].kill()
				growth_tweens.erase(id)
			group.show()
			group.scale = Vector3.ONE if immediate else Vector3(1,0.01,1)
			if not immediate:
				var tween := create_tween()
				growth_tweens[id] = tween
				tween.tween_property(group,"scale",Vector3.ONE,5.0).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
		elif not enabled:
			if growth_tweens.has(id):
				growth_tweens[id].kill()
				growth_tweens.erase(id)
			group.hide()
	restored = ids.duplicate()

func region_name(point: Vector2) -> String:
	for clearing: Dictionary in clearings:
		if point.distance_to(clearing.position)<float(clearing.radius)+3.0:
			return str(clearing.name)
	if point.y < -80: return "THE HIGH NORTHERN WALK"
	if point.x < -80: return "THE ELDERWOOD WALK"
	if point.x > 80: return "THE WILLOW WALK"
	if point.y > 80: return "THE SUNWASH WALK"
	if point.y < -30: return "THE NORTHERN WALK"
	if point.x < -30: return "THE LONG WOOD"
	if point.x > 30: return "REEDWATER TRAIL"
	if point.y > 30: return "THE SOUTHERN MEADOWS"
	return "THE LIVING VALLEY"
