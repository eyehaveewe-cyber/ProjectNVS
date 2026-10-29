extends Node3D
## Sunlit pools on existing paths and small grassy mounds beyond their banks.
## The existing layout remains the sole owner of walkability; this geometry is
## visual only and never modifies collision, player height or save state.
const Layout = preload("res://scripts/secondwood_layout.gd")
const World = preload("res://scripts/secondwood_map.gd")
const SUN_ANCHORS: Array[Vector2] = [
	Vector2(-30,45),Vector2(-70,50),Vector2(-76,5),Vector2(-146,10),
	Vector2(40,55),Vector2(76,8),Vector2(147,40),Vector2(90,-112),
	Vector2(-95,-108),Vector2(-78,-148),Vector2(-100,143),Vector2(100,143),
	Vector2(31,-62),Vector2(63,-45),Vector2(-12,-82),Vector2(0,120)
]
var hill_centers: Array[Dictionary] = []
var sun_centers: Array[Vector2] = []
var hill_vertices := PackedVector3Array()
var hill_colors := PackedColorArray()
var light_vertices := PackedVector3Array()
var light_colors := PackedColorArray()
var random := RandomNumberGenerator.new()

func _terrain_point(p: Vector2, lift: float = 0.0) -> Vector3:
	return Vector3(p.x,World.height_at(p.x,p.y)+lift,p.y)

func _safe_hill(center: Vector2, radius: float) -> bool:
	if maxf(absf(center.x),absf(center.y))+radius>Layout.BOUNDS-0.5: return false
	# All routes, including currently closed shortcuts, remain unobstructed.
	for route: Dictionary in Layout.all_routes():
		if Layout.route_distance(center,route.points)<radius+Layout.CORRIDOR_RADIUS+0.8: return false
	for clearing: Dictionary in Layout.CLEARINGS:
		if center.distance_to(clearing.position)<radius+float(clearing.radius)+1.3: return false
	for hill: Dictionary in hill_centers:
		if center.distance_to(hill.position)<radius+float(hill.radius)+1.0: return false
	return true

func _hill_triangle(a: Vector3,b: Vector3,c: Vector3,color: Color) -> void:
	for vertex: Vector3 in [a,b,c]:
		hill_vertices.append(vertex)
		hill_colors.append(color)

func _add_hill(center: Vector2,radius: float,height: float) -> void:
	var peak: Vector3 = _terrain_point(center,height)
	var base := Color("#829763").lightened(random.randf_range(0.0,0.09))
	const SIDES: int = 12
	for i in SIDES:
		var a: Vector2 = Vector2.from_angle(TAU*float(i)/SIDES)
		var b: Vector2 = Vector2.from_angle(TAU*float(i+1)/SIDES)
		var o1: Vector3 = _terrain_point(center+a*radius,0.025)
		var o2: Vector3 = _terrain_point(center+b*radius,0.025)
		var m1: Vector3 = _terrain_point(center+a*radius*0.53,height*0.70)
		var m2: Vector3 = _terrain_point(center+b*radius*0.53,height*0.70)
		var tint: Color = base.lightened(0.04*maxf(0.0,-a.x+a.y))
		_hill_triangle(o1,o2,m2,tint.darkened(0.05))
		_hill_triangle(o1,m2,m1,tint.darkened(0.05))
		_hill_triangle(m1,m2,peak,tint)

func _light_triangle(a: Vector3,b: Vector3,c: Vector3,colors: Array) -> void:
	for i in 3:
		light_vertices.append([a,b,c][i])
		light_colors.append(colors[i])

func _add_sun_pool(center: Vector2,radius: float) -> void:
	# A softly feathered golden oval follows the height field and lets the
	# trail surface show through. It is a visual pool, not a navigation marker.
	var bright := Color(1.0,0.89,0.53,0.18)
	var clear := Color(1.0,0.89,0.53,0.0)
	var middle: Vector3 = _terrain_point(center,0.06)
	const SIDES: int = 18
	for i in SIDES:
		var a: Vector2 = Vector2.from_angle(TAU*float(i)/SIDES)*Vector2(radius,radius*0.66)
		var b: Vector2 = Vector2.from_angle(TAU*float(i+1)/SIDES)*Vector2(radius,radius*0.66)
		var inner_a: Vector3 = _terrain_point(center+a*0.52,0.06)
		var inner_b: Vector3 = _terrain_point(center+b*0.52,0.06)
		var outer_a: Vector3 = _terrain_point(center+a,0.06)
		var outer_b: Vector3 = _terrain_point(center+b,0.06)
		_light_triangle(middle,inner_a,inner_b,[bright,bright,bright])
		_light_triangle(inner_a,outer_a,outer_b,[bright,clear,clear])
		_light_triangle(inner_a,outer_b,inner_b,[bright,clear,bright])

func _mesh(vertices: PackedVector3Array,colors: PackedColorArray,label: String,transparent: bool) -> void:
	var arrays: Array = []
	arrays.resize(Mesh.ARRAY_MAX)
	arrays[Mesh.ARRAY_VERTEX] = vertices
	arrays[Mesh.ARRAY_COLOR] = colors
	var mesh := ArrayMesh.new()
	if not vertices.is_empty(): mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES,arrays)
	var material := StandardMaterial3D.new()
	material.vertex_color_use_as_albedo = true
	material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	material.cull_mode = BaseMaterial3D.CULL_DISABLED
	if transparent:
		material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		material.depth_draw_mode = BaseMaterial3D.DEPTH_DRAW_DISABLED
	var node := MeshInstance3D.new()
	node.name = label
	node.mesh = mesh
	node.material_override = material
	add_child(node)

func build() -> void:
	name = "SunlitDales"
	random.seed = 912351
	for route: Dictionary in Layout.PATHS:
		for index in range(1,route.points.size()):
			var a: Vector2 = route.points[index-1]
			var b: Vector2 = route.points[index]
			var direction: Vector2 = (b-a).normalized()
			var normal := Vector2(-direction.y,direction.x)
			var count: int = maxi(1,floori(a.distance_to(b)/13.0))
			for step in count:
				var middle: Vector2 = a.lerp(b,(float(step)+0.5)/float(count))
				for side: float in [-1.0,1.0]:
					var radius: float = random.randf_range(2.1,3.9)
					var center: Vector2 = middle+normal*side*random.randf_range(8.0,13.5)
					if not _safe_hill(center,radius): continue
					var height: float = random.randf_range(0.45,1.1)
					hill_centers.append({"position":center,"radius":radius,"height":height})
					_add_hill(center,radius,height)
	for anchor: Vector2 in SUN_ANCHORS:
		sun_centers.append(anchor)
		_add_sun_pool(anchor,random.randf_range(3.0,4.6))
	_mesh(hill_vertices,hill_colors,"GrassyDaleHills",false)
	_mesh(light_vertices,light_colors,"GoldenSunlightPools",true)
