extends Node3D
## Native low-poly woodland cast. The game owns encounters and save state;
## this node owns creatures, their poses and the short restoration performance.
var game: Node
var squirrel: Node3D
var artemis: Node3D
var dryads: Array[Node3D] = []
var celebrations: Array[Dictionary] = []
var restored_sites: Dictionary = {}
var residents: Array[Node3D] = []
var materials: Dictionary = {}

func configure(owner_game: Node) -> void:
	game = owner_game
	squirrel = create_animal("squirrel")
	squirrel.name = "RainSongSquirrel"
	add_child(squirrel)
	squirrel.position = ground(-23.0,-21.0)
	for point: Vector2 in [Vector2(-55,10),Vector2(-39,43)]:
		var dryad := create_dryad()
		add_child(dryad)
		dryad.position = ground(point.x,point.y)
		dryad.set_meta("home",dryad.position)
		dryads.append(dryad)
	artemis = create_artemis()
	add_child(artemis)
	artemis.position = ground(13.0,60.0)
	artemis.hide()

func create_artemis() -> Node3D:
	var artemis := create_animal("deer")
	artemis.name = "Artemis"
	artemis.scale = Vector3.ONE*3.25
	_artemis_coat(artemis)
	var crown := Node3D.new()
	crown.name = "MoonCrown"
	artemis.add_child(crown)
	# An open crescent between the great branching antlers.
	for i in 10:
		var angle: float = lerpf(-2.25,2.25,float(i)/9.0)
		var moon := _ellipsoid(crown,Vector3(sin(angle)*0.21,2.36+cos(angle)*0.21,0.55),Vector3(0.058,0.058,0.035),Color("#fff2bc"))
		moon.set_meta("moon",true)
	var halo := _ring(artemis,Color(0.83,0.96,0.72,0.35))
	halo.position.y = 0.025
	halo.scale = Vector3(1.65,1.0,1.65)
	return artemis

func ground(x: float, z: float) -> Vector3:
	var y: float = 0.18+sin(x*0.12+0.5)*0.16+cos(z*0.14-0.3)*0.12+sin((x+z)*0.18)*0.075
	return Vector3(x,y,z)

func _mat(color: Color) -> StandardMaterial3D:
	var key: String = color.to_html()
	if materials.has(key):
		return materials[key]
	var material := StandardMaterial3D.new()
	material.albedo_color = color
	material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	material.cull_mode = BaseMaterial3D.CULL_DISABLED
	if color.a < 1.0:
		material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		material.no_depth_test = false
	materials[key] = material
	return material

func _ellipsoid(parent: Node3D, at: Vector3, size: Vector3, color: Color) -> MeshInstance3D:
	var mesh := SphereMesh.new()
	mesh.radius = 1.0
	mesh.height = 2.0
	mesh.radial_segments = 8
	mesh.rings = 3
	var part := MeshInstance3D.new()
	part.mesh = mesh
	part.position = at
	part.scale = size
	part.material_override = _mat(color)
	parent.add_child(part)
	return part

func _cone(parent: Node3D, at: Vector3, radius: float, height: float, color: Color, tip: float = 0.0) -> MeshInstance3D:
	var mesh := CylinderMesh.new()
	mesh.top_radius = tip
	mesh.bottom_radius = radius
	mesh.height = height
	mesh.radial_segments = 7
	var part := MeshInstance3D.new()
	part.mesh = mesh
	part.position = at
	part.material_override = _mat(color)
	parent.add_child(part)
	return part

func _branch(parent: Node3D, a: Vector3, b: Vector3, radius: float, color: Color) -> MeshInstance3D:
	var part := _cone(parent,(a+b)*0.5,radius,a.distance_to(b),color,radius*0.72)
	part.quaternion = Quaternion(Vector3.UP,(b-a).normalized())
	return part

func _joint(parent: Node3D, label: String, at: Vector3) -> Node3D:
	var joint := Node3D.new()
	joint.name = label
	joint.position = at
	parent.add_child(joint)
	return joint

func create_animal(kind: String) -> Node3D:
	var animal := Node3D.new()
	animal.name = kind.capitalize()
	animal.set_meta("kind",kind)
	animal.set_meta("phase",float(residents.size())*1.7)
	var coat: Color = Color("#b86439") if kind=="squirrel" else Color("#d38b46") if kind=="fox" else Color("#d8c4a4") if kind=="rabbit" else Color("#9cb8c2") if kind=="bird" else Color("#b59a70")
	var dark := Color("#302a29")
	if kind=="bird":
		_ellipsoid(animal,Vector3(0,0.27,0),Vector3(0.17,0.22,0.24),coat)
		_ellipsoid(animal,Vector3(0,0.47,0.12),Vector3(0.15,0.15,0.15),coat)
		var beak := _cone(animal,Vector3(0,0.46,0.3),0.07,0.18,Color("#eec368"))
		beak.rotation.x = PI*0.5
		for side in [-1,1]:
			var wing := _joint(animal,"WingLeft" if side<0 else "WingRight",Vector3(side*0.13,0.31,0))
			_ellipsoid(wing,Vector3(side*0.1,0,0),Vector3(0.18,0.04,0.15),Color("#6c8d9c"))
			_ellipsoid(animal,Vector3(side*0.095,0.49,0.22),Vector3.ONE*0.025,dark)
			_branch(animal,Vector3(side*0.06,0.07,0),Vector3(side*0.06,0.18,0),0.018,Color("#be9054"))
		return animal
	var deer: bool = kind=="deer"
	var body_height: float = 0.92 if deer else 0.36
	var body_size := Vector3(0.28,0.32,0.56) if deer else Vector3(0.2,0.23,0.36)
	_ellipsoid(animal,Vector3(0,body_height,0),body_size,coat)
	_ellipsoid(animal,Vector3(0,body_height-0.07,0.12),body_size*Vector3(0.78,0.76,0.66),Color("#f0dfbf"))
	var head := _joint(animal,"Head",Vector3(0,1.5,0.45) if deer else Vector3(0,0.56,0.29))
	if deer:
		_branch(animal,Vector3(0,0.98,0.33),Vector3(0,1.53,0.42),0.17,coat)
	_ellipsoid(head,Vector3.ZERO,Vector3(0.19,0.2,0.3) if deer else Vector3(0.17,0.17,0.2),coat)
	_ellipsoid(head,Vector3(0,-0.045,0.26 if deer else 0.18),Vector3(0.13,0.09,0.16) if deer else Vector3(0.075,0.06,0.1),coat)
	_ellipsoid(head,Vector3(0,-0.03,0.39 if deer else 0.27),Vector3(0.07,0.045,0.04) if deer else Vector3.ONE*0.035,dark)
	for side in [-1,1]:
		_ellipsoid(head,Vector3(side*0.143,0.05,0.14),Vector3(0.026,0.035,0.025),dark)
		var ear := _ellipsoid(head,Vector3(side*(0.23 if deer else 0.12),0.18 if deer else 0.2,-0.02),Vector3(0.14,0.065,0.05) if deer else Vector3(0.06,0.22 if kind=="rabbit" else 0.11,0.05),coat)
		ear.rotation.z = -side*0.4
		if deer:
			var root := Vector3(side*0.11,0.16,-0.03)
			var elbow := Vector3(side*0.28,0.58,-0.12)
			var end := Vector3(side*0.56,0.92,-0.22)
			_branch(head,root,elbow,0.045,Color("#dfcf9d"))
			_branch(head,elbow,end,0.035,Color("#dfcf9d"))
			for i in 3:
				var start := elbow.lerp(end,float(i)/3.0)
				_branch(head,start,start+Vector3(-side*0.12,0.27,0.13),0.022,Color("#f5eac5"))
	for side in [-1,1]:
		for front in [-1,1]:
			var leg := _joint(animal,"Leg_%d_%d" % [side,front],Vector3(side*(0.19 if deer else 0.13),body_height-0.08,front*(0.35 if deer else 0.2)))
			var length: float = 0.75 if deer else 0.25
			_branch(leg,Vector3.ZERO,Vector3(0,-length,0.02),0.055 if deer else 0.047,coat)
			_ellipsoid(leg,Vector3(0,-length,0.04),Vector3(0.065,0.04,0.09),dark if deer else coat)
	var tail := _joint(animal,"Tail",Vector3(0,body_height,-body_size.z*0.78))
	if kind=="squirrel":
		# Broad S-shaped silhouette stays recognizable from the overhead camera.
		_ellipsoid(tail,Vector3(0,0.18,-0.2),Vector3(0.17,0.26,0.17),coat)
		_ellipsoid(tail,Vector3(0,0.48,-0.27),Vector3(0.23,0.31,0.2),coat)
		_ellipsoid(tail,Vector3(0,0.68,-0.13),Vector3(0.2,0.19,0.17),Color("#c77d4c"))
	elif kind=="fox":
		var brush := _ellipsoid(tail,Vector3(0,0.07,-0.3),Vector3(0.17,0.18,0.4),coat)
		brush.rotation.x = -0.35
		_ellipsoid(tail,Vector3(0,0.2,-0.61),Vector3(0.13,0.13,0.17),Color("#f1e8ce"))
	else:
		_ellipsoid(tail,Vector3(0,0.02,-0.06),Vector3(0.11,0.13,0.11),Color("#eee1c9"))
	return animal

func create_dryad() -> Node3D:
	var dryad := Node3D.new()
	dryad.name = "Dryad"
	dryad.set_meta("kind","dryad")
	var wood := Color("#9d7656")
	var leaf := Color("#7fa76b")
	_cone(dryad,Vector3(0,0.77,0),0.22,0.8,wood,0.17)
	_cone(dryad,Vector3(0,0.38,0),0.52,0.65,Color("#5d8e62"),0.19)
	for i in 7:
		var a: float = float(i)*TAU/7.0
		var skirt := _ellipsoid(dryad,Vector3(sin(a)*0.3,0.43,cos(a)*0.3),Vector3(0.16,0.38,0.08),leaf)
		skirt.rotation = Vector3(cos(a)*0.4,a,-sin(a)*0.4)
	var head := _joint(dryad,"Head",Vector3(0,1.38,0))
	_ellipsoid(head,Vector3.ZERO,Vector3(0.19,0.23,0.18),Color("#c9ab7e"))
	for side in [-1,1]:
		_ellipsoid(head,Vector3(side*0.075,0.025,0.16),Vector3(0.025,0.03,0.018),Color("#274132"))
		var arm := _joint(dryad,"ArmLeft" if side<0 else "ArmRight",Vector3(side*0.19,1.05,0))
		_branch(arm,Vector3.ZERO,Vector3(side*0.24,-0.3,0),0.065,wood)
		_branch(arm,Vector3(side*0.24,-0.3,0),Vector3(side*0.35,-0.17,0.1),0.048,wood)
		_branch(head,Vector3(side*0.12,0.16,0),Vector3(side*0.32,0.54,0),0.035,wood)
		_branch(head,Vector3(side*0.23,0.36,0),Vector3(side*0.42,0.43,0.05),0.022,wood)
		for i in 3:
			_ellipsoid(head,Vector3(side*(0.18+float(i)*0.09),0.3+float(i)*0.1,0.01),Vector3(0.12,0.055,0.065),leaf)
	_ellipsoid(head,Vector3(0,0.21,-0.04),Vector3(0.23,0.13,0.2),Color("#5d8e62"))
	return dryad

func _recolor(node: Node, color: Color) -> void:
	for child in node.get_children():
		if child is MeshInstance3D:
			child.material_override = _mat(color)
		_recolor(child,color)

func _artemis_coat(node: Node) -> void:
	for child in node.get_children():
		if child is MeshInstance3D:
			var original: Color = child.material_override.albedo_color
			var tint := Color("#d5e6cf")
			if original == Color("#302a29"): tint = Color("#405e53")
			elif original == Color("#f0dfbf") or original == Color("#eee1c9"): tint = Color("#f2efd6")
			elif original == Color("#dfcf9d") or original == Color("#f5eac5"): tint = Color("#afc49b")
			child.material_override = _mat(tint)
		_artemis_coat(child)

func set_oiled(animal: Node3D, oiled: bool) -> void:
	animal.set_meta("oiled",oiled)
	if not animal.has_meta("coat_backup"):
		var backup: Dictionary = {}
		for mesh in animal.find_children("*","MeshInstance3D",true,false):
			backup[mesh.get_path()] = mesh.material_override
		animal.set_meta("coat_backup",backup)
	if oiled:
		_recolor(animal,Color("#3e354d"))
	else:
		var backup: Dictionary = animal.get_meta("coat_backup")
		for path in backup:
			var mesh: Node = get_node_or_null(path)
			if mesh != null:
				mesh.material_override = backup[path]

func _ring(parent: Node3D, color: Color) -> MeshInstance3D:
	var mesh := TorusMesh.new()
	mesh.inner_radius = 0.92
	mesh.outer_radius = 1.0
	mesh.rings = 32
	mesh.ring_segments = 4
	var ring := MeshInstance3D.new()
	ring.mesh = mesh
	ring.material_override = _mat(color)
	parent.add_child(ring)
	return ring

func celebrate(site: Dictionary) -> void:
	var id: String = str(site.id)
	if restored_sites.has(id):
		return
	var origin := ground(float(site.x),float(site.z))
	var troupe: Array[Node3D] = []
	for i in 5:
		var actor := create_dryad() if i==4 else create_animal(["rabbit","fox","squirrel","bird"][i])
		add_child(actor)
		actor.position = origin
		actor.set_meta("home",origin)
		actor.set_meta("phase",float(i)*1.6)
		troupe.append(actor)
		residents.append(actor)
	var effects := Node3D.new()
	effects.position = origin
	add_child(effects)
	for i in 3:
		var ring := _ring(effects,Color(0.79,0.95,0.56,0.65-float(i)*0.14))
		ring.name = "BloomRing%d" % i
		ring.position.y = 0.06+float(i)*0.03
	for i in 30:
		var petal := _ellipsoid(effects,Vector3.ZERO,Vector3(0.08,0.025,0.14),Color("#eabfa4") if i%3==0 else Color("#e5df9c") if i%3==1 else Color("#a6dca2"))
		petal.name = "Petal%d" % i
	celebrations.append({"age":0.0,"origin":origin,"actors":troupe,"effects":effects})
	restored_sites[id] = troupe

func sync(healed: Array) -> void:
	for event in celebrations:
		if is_instance_valid(event.effects):
			event.effects.queue_free()
	celebrations.clear()
	for actor in residents:
		actor.queue_free()
	residents.clear()
	restored_sites.clear()
	if game == null:
		return
	for site in game.state.definitions:
		if not healed.has(str(site.id)):
			continue
		var origin := ground(float(site.x),float(site.z))
		var troupe: Array[Node3D] = []
		for i in 2:
			var actor := create_animal("rabbit" if i==0 else "bird")
			add_child(actor)
			actor.position = ground(origin.x+cos(i*PI)*2.2,origin.z+sin(i*PI)*2.2)
			actor.set_meta("home",actor.position)
			actor.set_meta("phase",float(i)*PI)
			troupe.append(actor)
			residents.append(actor)
		restored_sites[str(site.id)] = troupe

func show_artemis(visible_now: bool = true) -> void:
	if artemis != null:
		artemis.visible = visible_now

func _animate(actor: Node3D, clock: float, lively: bool) -> void:
	var phase: float = float(actor.get_meta("phase",0.0))
	var beat: float = sin(clock*(7.0 if lively else 2.1)+phase)
	var kind: String = str(actor.get_meta("kind",""))
	if kind=="dryad":
		actor.rotation.z = beat*(0.07 if lively else 0.018)
		for label: String in ["ArmLeft","ArmRight"]:
			var arm: Node3D = actor.get_node(label)
			arm.rotation.z = beat*0.33+(0.9 if label=="ArmLeft" else -0.9) if lively else beat*0.09
	else:
		for child in actor.get_children():
			if str(child.name).begins_with("Leg_"):
				child.rotation.x = beat*(0.45 if lively else 0.04)*(-1.0 if str(child.name).ends_with("-1") else 1.0)
		var tail: Node3D = actor.get_node_or_null("Tail")
		if tail != null:
			tail.rotation.z = beat*0.22
		var head: Node3D = actor.get_node_or_null("Head")
		if head != null:
			head.rotation.x = beat*(0.13 if lively else 0.035)
		if kind=="bird":
			actor.get_node("WingLeft").rotation.z = beat*0.65
			actor.get_node("WingRight").rotation.z = -beat*0.65

func tick(delta: float, clock: float, player_position: Vector3) -> void:
	if squirrel != null:
		_animate(squirrel,clock,true)
	for dryad in dryads:
		dryad.visible = dryad.position.distance_to(player_position)<50.0
		if not dryad.visible: continue
		var nearby: bool = dryad.position.distance_to(player_position)<7.0
		_animate(dryad,clock,nearby)
		if nearby:
			dryad.rotation.y = atan2(player_position.x-dryad.position.x,player_position.z-dryad.position.z)
	for actor in residents:
		actor.visible = actor.position.distance_to(player_position)<40.0
		if actor.visible: _animate(actor,clock,false)
	if artemis != null and artemis.visible:
		_animate(artemis,clock,false)
		var facing: float = atan2(player_position.x-artemis.position.x,player_position.z-artemis.position.z)
		artemis.rotation.y = lerp_angle(artemis.rotation.y,facing,minf(1.0,delta*0.5))
	for index in range(celebrations.size()-1,-1,-1):
		var event: Dictionary = celebrations[index]
		event.age = float(event.age)+delta
		var age: float = event.age
		var center: Vector3 = event.origin
		var actors: Array = event.actors
		for i in actors.size():
			var actor: Node3D = actors[i]
			var angle: float = age*0.65+float(i)*TAU/float(actors.size())
			var radius: float = lerpf(5.0,2.2,minf(1.0,age/1.4))
			actor.position = ground(center.x+sin(angle)*radius,center.z+cos(angle)*radius)
			actor.position.y += absf(sin(age*6.0+float(i)*1.2))*(0.38 if i<4 else 0.12)
			actor.rotation.y = angle+PI*0.5
			if actor.visible: _animate(actor,clock,true)
		var effects: Node3D = event.effects
		effects.visible = center.distance_to(player_position)<40.0
		for i in 3:
			var ring: Node3D = effects.get_node("BloomRing%d" % i)
			var radius: float = fmod(age*1.1+float(i)*1.8,7.0)
			ring.scale = Vector3(radius,1.0,radius)
			ring.visible = age<6.5 and radius<6.3
		for i in 30:
			var petal: Node3D = effects.get_node("Petal%d" % i)
			var angle: float = float(i)*2.399+age*0.7
			var radius: float = 0.4+float(i%6)*0.48+age*0.12
			petal.position = Vector3(sin(angle)*radius,0.25+fmod(age*0.48+float(i)*0.13,3.0),cos(angle)*radius)
			petal.rotation = Vector3(age+float(i),angle,age*0.8)
			petal.scale = Vector3(0.08,0.025,0.14)*minf(1.0,(8.0-age)*1.3)
		if age>=8.0:
			for actor: Node3D in actors:
				actor.position = ground(actor.position.x,actor.position.z)
				actor.set_meta("home",actor.position)
			effects.queue_free()
			celebrations.remove_at(index)
