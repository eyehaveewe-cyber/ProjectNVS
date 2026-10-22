extends Control
var game: Node

func _draw() -> void:
	if game == null or game.state == null:
		return
	var center := Vector2(83,83)
	draw_circle(center,82,Color("#19332f"))
	for region in [[Vector2(-15,-12),Color("#64516b")],[Vector2(15,-7),Color("#4c7370")],[Vector2(-1,17),Color("#82604e")]]:
		draw_circle(center+region[0]*2.4,28,region[1])
	for site in game.state.definitions:
		var p := center+Vector2(float(site.x),float(site.z))*2.4
		draw_line(center+Vector2(0,9.6),p,Color("#acaa83"),1)
		draw_circle(p,3.0,Color("#bce0a0") if game.state.healed.has(str(site.id)) else Color("#eee0ad"))
	var position := center+Vector2(float(game.state.player.x),float(game.state.player.z))*2.4
	var direction := Vector2(sin(float(game.state.player.yaw)),cos(float(game.state.player.yaw)))
	draw_circle(position,3.0,Color.WHITE)
	draw_line(position,position+direction*9,Color.WHITE,2)
	draw_string(ThemeDB.fallback_font,Vector2(79,14),"N",HORIZONTAL_ALIGNMENT_LEFT,-1,11,Color("#eee0ad"))
