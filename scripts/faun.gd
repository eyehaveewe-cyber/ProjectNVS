extends Node3D
## Reuses the actual faun vertices and named Zendelves joint pivots.
var joints: Dictionary = {}
var walk_phase: float = 0.0
var pose: float = 0.0

func build(parts: Array) -> void:
	var cache: Dictionary = {}
	for part in parts:
		var joint_name: String = part.name
		var joint: Node3D
		if not joints.has(joint_name):
			joint = Node3D.new()
			joint.position = Vector3(float(part.pivot[0]),float(part.pivot[1]),float(part.pivot[2]))
			joint.name = joint_name
			joints[joint_name] = joint
			add_child(joint)
		else:
			joint = joints[joint_name]
		var vertices := PackedVector3Array()
		for triangle in part.triangles:
			for index in triangle:
				var v: Array = part.vertices[int(index)]
				vertices.append(Vector3(float(v[0]),float(v[1]),float(v[2])))
		var arrays: Array = []
		arrays.resize(Mesh.ARRAY_MAX)
		arrays[Mesh.ARRAY_VERTEX] = vertices
		var mesh := ArrayMesh.new()
		mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES,arrays)
		var instance := MeshInstance3D.new()
		instance.mesh = mesh
		var color: String = part.color
		if not cache.has(color):
			var mat := StandardMaterial3D.new()
			mat.albedo_color = Color(color)
			mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
			mat.cull_mode = BaseMaterial3D.CULL_DISABLED
			cache[color] = mat
		instance.material_override = cache[color]
		joint.add_child(instance)
	var shadow := MeshInstance3D.new()
	var disc := CylinderMesh.new()
	disc.top_radius = 0.34
	disc.bottom_radius = 0.34
	disc.height = 0.012
	shadow.mesh = disc
	shadow.position.y = 0.025
	var shade := StandardMaterial3D.new()
	shade.albedo_color = Color("#364536")
	shade.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	shadow.material_override = shade
	add_child(shadow)

func animate(delta: float, walking: bool, playing: bool, resting: bool, clock: float) -> void:
	if joints.is_empty():
		return
	if walking:
		walk_phase += delta * 9.0
	pose = move_toward(pose,1.0 if playing else 0.0,delta*5.0)
	var swing: float = sin(walk_phase) if walking else 0.0
	joints.leftLeg.rotation.x = swing * 0.48
	joints.rightLeg.rotation.x = -swing * 0.48
	joints.leftArm.rotation.x = -swing*0.28-pose*1.03
	joints.rightArm.rotation.x = swing*0.28-pose*1.03
	joints.pipes.rotation.x = joints.rightArm.rotation.x
	joints.leftArm.rotation.z = -pose*0.12
	joints.rightArm.rotation.z = pose*0.12
	joints.pipes.rotation.z = pose*0.12
	joints.head.rotation.x = pose*0.09
	var bob: float = sin(walk_phase*2.0)*0.025 if walking else sin(clock*2.0)*0.008
	position.y = bob - (0.23 if resting else 0.0)
