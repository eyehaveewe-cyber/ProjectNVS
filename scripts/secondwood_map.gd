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

func _forest() -> void:
	var placed: Array[Vector2] = []
	for attempt in 5000:
		if placed.size()>=630: break
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
