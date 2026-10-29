extends Node3D
## Region-specific wildlife and softly moving airborne details. MultiMesh keeps
## the fixed particle pools cheap and distance culling stops offscreen work.
const World = preload("res://scripts/secondwood_map.gd")
const FIELDS: Array = [
	{"name":"Glade pollen","center":Vector2(-8,32),"color":Color("#f3d88c"),"mode":"pollen","radius":5.0},
	{"name":"Spring glints","center":Vector2(-15,25),"color":Color("#9fe0e6"),"mode":"glint","radius":3.5},
	{"name":"Wetland fireflies","center":Vector2(-122,10),"color":Color("#d6f3a0"),"mode":"firefly","radius":6.0},
	{"name":"Cinder embers","center":Vector2(122,-15),"color":Color("#eab089"),"mode":"ember","radius":5.5},
	{"name":"Ridge petals","center":Vector2(0,-130),"color":Color("#e2d5b5"),"mode":"petal","radius":5.5}
]
const SQUIRREL_HOMES: Array[Vector2] = [Vector2(-8,32),Vector2(-65,-14),Vector2(130,68),Vector2(-95,-108),Vector2(0,-130)]
const PARTICLE_COUNT := 26
var game: Node
var cast: Node3D
var squirrels: Array[Node3D] = []
var fields: Array[Dictionary] = []
var clock: float = 0.0

func setup(owner_game: Node, woodland_cast: Node3D) -> void:
	game = owner_game
	cast = woodland_cast
	name = "WoodlandAmbience"
	for index in SQUIRREL_HOMES.size():
		var squirrel: Node3D = cast.create_animal("squirrel")
		squirrel.name = "WoodlandSquirrel%d" % (index+1)
		squirrel.scale = Vector3.ONE*1.35
		add_child(squirrel)
		squirrel.hide()
		squirrels.append(squirrel)
	for definition: Dictionary in FIELDS:
		var field := MultiMeshInstance3D.new()
		field.name = str(definition.name).replace(" ","")
		var mesh := SphereMesh.new()
		mesh.radius = 0.065
		mesh.height = 0.13
		mesh.radial_segments = 5
		mesh.rings = 3
		var material := StandardMaterial3D.new()
		material.albedo_color = definition.color
		material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		material.emission_enabled = true
		material.emission = definition.color
		material.emission_energy_multiplier = 0.45
		mesh.material = material
		var instances := MultiMesh.new()
		instances.transform_format = MultiMesh.TRANSFORM_3D
		instances.instance_count = PARTICLE_COUNT
		instances.mesh = mesh
		field.multimesh = instances
		add_child(field)
		fields.append({"node":field,"definition":definition})
		field.visible = false

func _process(delta: float) -> void:
	if not is_instance_valid(game) or not is_instance_valid(cast) or not game.started:
		return
	if game.paused: return
	clock += minf(delta,0.25)
	var player: Vector2 = game.state.position2()
	for index in squirrels.size():
		var squirrel: Node3D = squirrels[index]
		var home: Vector2 = SQUIRREL_HOMES[index]
		squirrel.visible = player.distance_to(home)<35.0
		if not squirrel.visible: continue
		# Short hops, pauses and tail movements stay near the original path.
		var phase: float = clock*0.8+float(index)*1.7
		var hop: float = maxf(0.0,sin(phase*3.0))
		var location: Vector2 = home+Vector2(sin(phase)*0.8,cos(phase)*0.55)
		squirrel.position = Vector3(location.x,World.height_at(location.x,location.y)+hop*0.12,location.y)
		squirrel.rotation.y = phase+PI*0.5
		cast._animate(squirrel,clock+float(index),true)
	for entry: Dictionary in fields:
		var field: MultiMeshInstance3D = entry.node
		var definition: Dictionary = entry.definition
		var center: Vector2 = definition.center
		field.visible = player.distance_to(center)<38.0
		if not field.visible: continue
		var radius: float = float(definition.radius)
		for index in PARTICLE_COUNT:
			var seed: float = float(index)
			var phase: float = fposmod(clock*(0.13+0.017*float(index%4))+seed*0.17,1.0)
			var angle: float = seed*2.399+clock*(0.22 if definition.mode=="petal" else 0.08)
			var ring: float = radius*(0.22+0.72*fposmod(seed*0.618,1.0))
			var x: float = center.x+cos(angle)*ring
			var z: float = center.y+sin(angle)*ring
			var y: float = World.height_at(x,z)+0.4+phase*2.7
			if definition.mode=="petal": y = World.height_at(x,z)+3.1-phase*2.5
			elif definition.mode=="firefly": y = World.height_at(x,z)+1.2+sin(clock*1.4+seed)*0.55
			elif definition.mode=="glint": y = World.height_at(x,z)+0.15+phase*0.8
			var size: float = 0.3+0.7*sin(phase*PI)
			if definition.mode=="firefly": size = 0.35+0.65*absf(sin(clock*1.2+seed))
			var shape := Vector3.ONE*size
			if definition.mode=="petal": shape = Vector3(size*1.5,size*0.25,size*0.8)
			field.multimesh.set_instance_transform(index,Transform3D(Basis.from_scale(shape),Vector3(x,y,z)))
