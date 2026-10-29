extends SceneTree
const Layout = preload("res://scripts/secondwood_layout.gd")
func _initialize() -> void:
	var routes: Array = []
	var clearings: Array = []
	var length: float = 0
	for route: Dictionary in Layout.all_routes():
		var points: Array = []
		for p: Vector2 in route.points: points.append([p.x,p.y])
		routes.append({"id":route.id,"points":points,"requires":route.requires,"shortcut":Layout.SHORTCUTS.has(route)})
		length += Layout.route_length(route.points)
	for c: Dictionary in Layout.CLEARINGS: clearings.append({"id":c.id,"position":[c.position.x,c.position.y],"radius":c.radius,"requires":c.requires})
	var report := {"bounds":Layout.BOUNDS,"area":pow(Layout.BOUNDS*2,2),"length":length,"routes":routes,"clearings":clearings,"all_flags":Layout.all_flags(),"corridor_radius":Layout.CORRIDOR_RADIUS}
	var file := FileAccess.open("res://docs/secondwood-layout-data.json",FileAccess.WRITE)
	file.store_string(JSON.stringify(report,"  "))
	print("Second wood length: ",length)
	quit()
