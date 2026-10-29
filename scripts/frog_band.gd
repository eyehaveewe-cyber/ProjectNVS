extends Node3D
## A small, locally animated frog trio. The chapter controls audience, music,
## and persistence; this node owns the performers and their instruments.
var players: Array[Dictionary] = []
var elapsed: float = 0.0
var materials: Dictionary = {}

func _mat(color: Color) -> StandardMaterial3D:
	var key: String = color.to_html()
	if not materials.has(key):
		var m := StandardMaterial3D.new()
		m.albedo_color = color
		m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		materials[key] = m
	return materials[key]

func _ball(parent: Node3D, label: String, at: Vector3, size: Vector3, color: Color) -> MeshInstance3D:
	var node := MeshInstance3D.new()
	node.name = label
	var mesh := SphereMesh.new()
	mesh.radius = 0.5
	mesh.height = 1.0
	mesh.radial_segments = 8
	mesh.rings = 4
	node.mesh = mesh
	node.position = at
	node.scale = size*2.0
	node.material_override = _mat(color)
	parent.add_child(node)
	return node

func _rod(parent: Node3D, label: String, a: Vector3, b: Vector3, radius: float, color: Color) -> MeshInstance3D:
	var node := MeshInstance3D.new()
	node.name = label
	var mesh := CylinderMesh.new()
	mesh.top_radius = radius
	mesh.bottom_radius = radius
	mesh.height = a.distance_to(b)
	mesh.radial_segments = 6
	node.mesh = mesh
	node.position = (a+b)*0.5
	node.quaternion = Quaternion(Vector3.UP,(b-a).normalized())
	node.material_override = _mat(color)
	parent.add_child(node)
	return node

func _disc(parent: Node3D, label: String, at: Vector3, radius: float, depth: float, color: Color) -> MeshInstance3D:
	var node := MeshInstance3D.new()
	node.name = label
	var mesh := CylinderMesh.new()
	mesh.top_radius = radius
	mesh.bottom_radius = radius
	mesh.height = depth
	mesh.radial_segments = 12
	node.mesh = mesh
	node.position = at
	node.rotation.x = PI/2.0
	node.material_override = _mat(color)
	parent.add_child(node)
	return node

func build() -> void:
	# A dry log makes the group legible without adding collision on the path.
	_rod(self,"BandLog",Vector3(-2.0,0.22,-0.12),Vector3(2.0,0.22,-0.12),0.28,Color("#715340"))
	for index in 3:
		var frog := Node3D.new()
		frog.name = "BanjoFrog%d" % (index+1)
		frog.position = Vector3(float(index-1)*1.24,0.27,0)
		frog.rotation.y = float(index-1)*-0.13
		add_child(frog)
		var green: Color = [Color("#789e5f"),Color("#a2b969"),Color("#698d60")][index]
		var pale := Color("#d5dda0")
		_ball(frog,"Body",Vector3(0,0.39,0),Vector3(0.34,0.34,0.28),green)
		_ball(frog,"Belly",Vector3(0,0.36,0.19),Vector3(0.26,0.24,0.12),pale)
		var head := Node3D.new()
		head.name = "Head"
		head.position = Vector3(0,0.69,0.08)
		frog.add_child(head)
		_ball(head,"Face",Vector3.ZERO,Vector3(0.37,0.23,0.26),green)
		_ball(head,"Muzzle",Vector3(0,-0.08,0.20),Vector3(0.29,0.095,0.10),pale)
		for side in [-1,1]:
			_ball(head,"EyeRise",Vector3(side*0.24,0.17,0.02),Vector3(0.15,0.15,0.15),green)
			_ball(head,"Eye",Vector3(side*0.24,0.20,0.14),Vector3(0.105,0.09,0.045),Color("#f3e4b8"))
			_ball(head,"Pupil",Vector3(side*0.24,0.20,0.18),Vector3(0.037,0.045,0.022),Color("#25372a"))
			_ball(frog,"Haunch",Vector3(side*0.29,0.17,0),Vector3(0.23,0.21,0.21),green)
			_ball(frog,"Foot",Vector3(side*0.31,0.02,0.25),Vector3(0.18,0.055,0.18),green)
			for toe in [-1,0,1]:
				_ball(frog,"Toe",Vector3(side*0.31+toe*0.07,0.035,0.38),Vector3(0.038,0.035,0.08),green.lightened(0.12))
		# Drum rim and pale membrane face the audience. The neck and four
		# strings give the small instrument its characteristic banjo silhouette.
		var instrument := Node3D.new()
		instrument.name = "Banjo"
		instrument.position = Vector3(-0.04,0.42,0.35)
		instrument.rotation.z = -0.22
		frog.add_child(instrument)
		_disc(instrument,"WoodenRim",Vector3.ZERO,0.23,0.10,Color("#805b40"))
		_disc(instrument,"BanjoHead",Vector3(0,0,0.065),0.19,0.035,Color("#ead9aa"))
		_rod(instrument,"Neck",Vector3(0.10,0.16,0),Vector3(0.40,0.57,0),0.060,Color("#845a3a"))
		_ball(instrument,"Peghead",Vector3(0.42,0.59,0),Vector3(0.10,0.11,0.06),Color("#a0794c"))
		for string in 4:
			var x: float = (float(string)-1.5)*0.025
			_rod(instrument,"String%d" % string,Vector3(x,-0.14,0.092),Vector3(0.36+x,0.52,0.04),0.006,Color("#f2e5c4"))
		for fret in 3:
			var p := Vector3(0.18+fret*0.055,0.27+fret*0.075,0.07)
			_rod(instrument,"Fret",p+Vector3(-0.035,0.025,0),p+Vector3(0.035,-0.025,0),0.007,Color("#e2d29e"))
		var left := Node3D.new()
		left.name = "FrettingArm"
		left.position = Vector3(0.28,0.59,0.16)
		frog.add_child(left)
		_rod(left,"Forearm",Vector3.ZERO,Vector3(0.02,-0.10,0.29),0.07,green)
		_ball(left,"Hand",Vector3(0.02,-0.10,0.29),Vector3(0.10,0.07,0.08),green.lightened(0.1))
		var right := Node3D.new()
		right.name = "StrummingArm"
		right.position = Vector3(-0.27,0.57,0.15)
		frog.add_child(right)
		_rod(right,"Forearm",Vector3.ZERO,Vector3(0.18,-0.17,0.30),0.07,green)
		_ball(right,"Hand",Vector3(0.18,-0.17,0.30),Vector3(0.10,0.07,0.08),green.lightened(0.1))
		players.append({"frog":frog,"head":head,"strum":right,"fret":left,"phase":index*0.35,"base_y":frog.position.y})

func animate(delta: float, performing: bool) -> void:
	elapsed += maxf(delta,0.0)
	for player: Dictionary in players:
		var phase: float = elapsed*7.0+float(player.phase)
		var strength: float = 1.0 if performing else 0.18
		var frog: Node3D = player.frog
		var head: Node3D = player.head
		var strum: Node3D = player.strum
		var fret: Node3D = player.fret
		frog.position.y = float(player.base_y)+absf(sin(phase*0.5))*0.055*strength
		head.rotation.z = sin(phase*0.5)*0.12*strength
		strum.rotation.z = sin(phase)*0.48*strength
		fret.rotation.z = sin(phase*0.5+1.0)*0.12*strength
