extends Control
## Whole-valley map: the quiet trails stay visible beyond the old core.
var game: Node
var map_size: float = 166.0
var label_clearings: bool = false

func _map(point: Vector2) -> Vector2:
	var extent: float = float(game.valley.bounds)
	return Vector2.ONE*map_size*0.5+point*((map_size-40.0 if label_clearings else map_size-20.0)/(extent*2.0))

func _route(points: Array, color: Color) -> void:
	for i in range(1,points.size()):
		draw_line(_map(points[i-1]),_map(points[i]),color,1.2,true)

func _diamond(point: Vector2, color: Color, radius: float = 3.0) -> void:
	draw_colored_polygon(PackedVector2Array([point+Vector2(0,-radius),point+Vector2(radius,0),point+Vector2(0,radius),point+Vector2(-radius,0)]),color)

func _draw() -> void:
	if game == null or game.state == null or game.valley == null:
		return
	draw_rect(Rect2(Vector2.ZERO,Vector2.ONE*map_size),Color("#19332f"))
	draw_rect(Rect2(Vector2(1,1),Vector2.ONE*(map_size-2)),Color("#7b957c"),false,1)
	for biome in [[Vector2(-15,-12),Color("#53465c")],[Vector2(15,-7),Color("#3f6865")],[Vector2(-1,17),Color("#795c48")]]:
		draw_circle(_map(biome[0]),12.0*(map_size-20.0)/(game.valley.bounds*2.0),biome[1])
	var trails: Color = Color("#8c9271")
	for route: Array in game.valley.expansion.paths:
		_route(route,trails)
	_route([Vector2(0,5),Vector2(0,1),Vector2(-3,-2),Vector2(-7,-5),Vector2(-11,-9),Vector2(-15,-13),Vector2(-19,-17)],trails)
	_route([Vector2(0,3),Vector2(4,0),Vector2(8,-2),Vector2(12,-5),Vector2(17,-9),Vector2(20,-13)],trails)
	_route([Vector2(0,6),Vector2(-2,9),Vector2(-1,12),Vector2(1,16),Vector2(5,20)],trails)
	for site: Dictionary in game.state.definitions:
		var start := Vector2(-13,-10) if site.kind=="corruption" else Vector2(14,-7) if site.kind=="pollution" else Vector2(0,16)
		_route([start,Vector2(float(site.x),float(site.z))],trails)
	for clearing: Dictionary in game.valley.expansion.clearings:
		var p: Vector2 = _map(clearing.position)
		draw_circle(p,3.7,Color("#8da778"),false,1.0,true)
		if label_clearings:
			var label: String = str(clearing.name).replace("THE ","").replace("ARTEMIS' MEADOW","ARTEMIS").replace("REEDWATER BEND","REEDWATER").replace("SUNWASH MEADOW","SUNWASH")
			var label_width: float = ThemeDB.fallback_font.get_string_size(label,HORIZONTAL_ALIGNMENT_LEFT,-1,10).x
			draw_string(ThemeDB.fallback_font,p+Vector2(-label_width*0.5,14),label,HORIZONTAL_ALIGNMENT_LEFT,-1,10,Color("#e3ddbb"))
	for site: Dictionary in game.state.definitions:
		var p: Vector2 = _map(Vector2(float(site.x),float(site.z)))
		var color := Color("#bce0a0") if game.state.healed.has(str(site.id)) else Color("#c69bca") if site.kind=="corruption" else Color("#b2d6d0") if site.kind=="pollution" else Color("#e3b079")
		draw_circle(p,2.6,color)
		if game.waypoint==str(site.id): draw_circle(p,4.7,Color.WHITE,false,1.0,true)
	_diamond(_map(Vector2(0,4)),Color("#e9d5a4"),2.5)
	if game.journey != null:
		var squirrel: Node3D = game.journey.cast.squirrel
		var s: Vector2 = _map(Vector2(squirrel.position.x,squirrel.position.z))
		draw_colored_polygon(PackedVector2Array([s+Vector2(0,-4),s+Vector2(3,3),s+Vector2(-3,3)]),Color("#edc66b"))
		var fox: Vector2 = _map(Vector2(59,-5))
		_diamond(fox,Color("#aad490") if game.state.wildlife_healed else Color("#df9b62"),3.6)
		if game.state.healed.size()>=3:
			var artemis: Vector2 = _map(Vector2(13,60))
			draw_circle(artemis,2.2,Color("#f0efda"))
			draw_line(artemis+Vector2(-3,-4),artemis+Vector2(0,1),Color("#f0efda"),1.5,true)
			draw_line(artemis+Vector2(3,-4),artemis+Vector2(0,1),Color("#f0efda"),1.5,true)
		var player_world := Vector2(float(game.state.player.x),float(game.state.player.z))
		var nearest: Vector2 = Vector2.ZERO
		var nearest_distance: float = 23.0
		for i in game.journey.seeds.size():
			if game.state.collected.has("seed_%02d" % i): continue
			var seed: Vector2 = game.journey.seeds[i]
			var distance: float = player_world.distance_to(seed)
			if distance<nearest_distance:
				nearest = seed
				nearest_distance = distance
		if nearest_distance<23.0:
			var seed_map: Vector2 = _map(nearest)
			draw_line(seed_map-Vector2(2,0),seed_map+Vector2(2,0),Color("#d8c378"),1.0)
			draw_line(seed_map-Vector2(0,2),seed_map+Vector2(0,2),Color("#d8c378"),1.0)
	var position: Vector2 = _map(Vector2(float(game.state.player.x),float(game.state.player.z)))
	var direction := Vector2(sin(float(game.state.player.yaw)),cos(float(game.state.player.yaw)))
	draw_circle(position,3.0,Color.WHITE)
	draw_line(position,position+direction*7,Color.WHITE,2,true)
	draw_string(ThemeDB.fallback_font,Vector2(map_size*0.5-5,13),"N",HORIZONTAL_ALIGNMENT_LEFT,-1,10,Color("#eee0ad"))
