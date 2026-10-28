extends Node3D
## Optional discoveries live outside the nine-sanctuary completion path.
const Cast = preload("res://scripts/woodland_cast.gd")
const Valley = preload("res://scripts/valley.gd")
const RAIN: Array[int] = [62,65,69,67,65,62]
const CLEANSE: Array[int] = [64,62,60,62,64,67]
const OIL_SPOT := Vector2(59,-5)
const ARTEMIS_SPOT := Vector2(13,60)
const NURSERY := Vector2(-39,43)
var game: Node
var cast: Node3D
var route: Array = []
var seed_nodes: Array[Node3D] = []
var seeds: Array = []
var oily_animal: Node3D
var rain_left: float = 0.0
var rain_phrase: Array[int] = []
var animal_phrase: Array[int] = []
var rain_mesh: MultiMeshInstance3D
var drops: Array[Vector3] = []
var sprouts: Array[Node3D] = []
var growth: float = 0.0
var squirrel_hint: bool = false
var last_stage: int = -1
var artemis_visit: float = 0.0

func configure(owner_game: Node) -> void:
	game = owner_game
	cast = Cast.new()
	add_child(cast)
	cast.configure(game)
	route = game.valley.expansion.squirrel_route
	seeds = game.valley.expansion.collectible_positions
	for i in seeds.size():
		var p: Vector2 = seeds[i]
		var pod := Node3D.new()
		pod.position = _ground(p)+Vector3.UP*0.65
		add_child(pod)
		var gem: MeshInstance3D = game._gem(Color("#e5c871"),0.14)
		pod.add_child(gem)
		for side in [-1,1]:
			var leaf: MeshInstance3D = game._gem(Color("#95c788"),0.09)
			leaf.position = Vector3(float(side)*0.16,-0.05,0)
			leaf.scale = Vector3(1.8,0.4,1)
			pod.add_child(leaf)
		seed_nodes.append(pod)
	oily_animal = cast.create_animal("fox")
	oily_animal.position = _ground(OIL_SPOT)
	add_child(oily_animal)
	cast.set_oiled(oily_animal,true)
	_build_rain()
	for i in 15:
		var angle: float = i*2.39996
		var p: Vector2 = NURSERY+Vector2(cos(angle),sin(angle))*(1.0+sqrt(float(i))*0.9)
		var plant := Node3D.new()
		plant.position = _ground(p)
		add_child(plant)
		for j in 3:
			var leaf: MeshInstance3D = game._gem(Color("#90bd65") if j<2 else Color("#eed09d"),0.18)
			leaf.position = Vector3(sin(j*2.1)*0.15,0.25+j*0.18,cos(j*2.1)*0.15)
			leaf.scale = Vector3(0.7,1.6,0.7)
			plant.add_child(leaf)
		sprouts.append(plant)
	reset()

func _ground(p: Vector2) -> Vector3:
	return Vector3(p.x,Valley.height_at(p.x,p.y),p.y)

func _build_rain() -> void:
	rain_mesh = MultiMeshInstance3D.new()
	var mesh := BoxMesh.new()
	mesh.size = Vector3(0.018,0.34,0.018)
	rain_mesh.multimesh = MultiMesh.new()
	rain_mesh.multimesh.transform_format = MultiMesh.TRANSFORM_3D
	rain_mesh.multimesh.mesh = mesh
	rain_mesh.multimesh.instance_count = 150
	rain_mesh.material_override = game._material(Color("#b9d7e0"))
	add_child(rain_mesh)
	var rng := RandomNumberGenerator.new()
	rng.seed = 5573
	for i in 150:
		drops.append(Vector3(rng.randf_range(-11,11),rng.randf_range(0,12),rng.randf_range(-11,11)))
	rain_mesh.hide()

func reset() -> void:
	rain_left = 0.0
	rain_phrase.clear()
	animal_phrase.clear()
	rain_mesh.hide()
	oily_animal.position = _ground(OIL_SPOT)
	last_stage = -1
	squirrel_hint = false
	artemis_visit = 0.0
	cast.squirrel.position = _ground(route[mini(game.state.squirrel_stage,route.size()-1)])
	cast.squirrel.visible = true
	cast.sync(game.state.healed)
	cast.set_oiled(oily_animal,not game.state.wildlife_healed)
	growth = 1.0 if game.state.nursery_watered else 0.0
	for i in seed_nodes.size():
		seed_nodes[i].visible = not game.state.collected.has("seed_%02d" % i)
	_update_sprouts()

func near_oil() -> bool:
	return Vector2(float(game.state.player.x),float(game.state.player.z)).distance_to(OIL_SPOT)<4.5 and not game.state.wildlife_healed

func tick(delta: float, clock: float) -> void:
	var player: Vector3 = game.body.position
	var position2 := Vector2(player.x,player.z)
	cast.tick(delta,clock,player)
	cast._animate(oily_animal,clock,game.state.wildlife_healed)
	if game.state.wildlife_healed:
		oily_animal.position = _ground(OIL_SPOT+Vector2(sin(clock*0.6),cos(clock*0.6))*1.2)
		oily_animal.rotation.y = clock*0.6+PI*0.5
	else:
		oily_animal.position = _ground(OIL_SPOT)
		oily_animal.get_node("Head").rotation.x = 0.2
	for i in seed_nodes.size():
		var seed: Node3D = seed_nodes[i]
		if not seed.visible: continue
		seed.rotation.y = clock*0.7+i
		seed.position.y = Valley.height_at(seed.position.x,seed.position.z)+0.65+sin(clock*2+i)*0.1
		if position2.distance_to(seeds[i])<1.15:
			seed.hide()
			game.state.collected.append("seed_%02d" % i)
			game._burst(seed.position,8)
			game.music.play_note(81,0.4)
			game._toast("A wild seed remembered. %d / %d found. These are yours to gather at leisure." % [game.state.collected.size(),seeds.size()])
			game.save_game()
	_tick_squirrel(delta,position2)
	var near_artemis: bool = game.state.healed.size()>=3 and position2.distance_to(ARTEMIS_SPOT)<25
	cast.show_artemis(near_artemis)
	if near_artemis:
		artemis_visit += delta
		cast.artemis.position = _ground(ARTEMIS_SPOT+Vector2(sin(clock*0.08)*3.0,cos(clock*0.08)*2.0))
		if position2.distance_to(ARTEMIS_SPOT)<12 and not game.state.artemis_seen:
			game.state.artemis_seen = true
			game._toast("Artemis walks the moon meadow. A vast white deer turns to listen.")
			game.music.melody([57,64,69,76,74,69],0.65)
			game.save_game()
	game.valley.material.set_shader_parameter("rain_amount",minf(1.0,rain_left/3.0))
	if rain_left>0:
		rain_left = maxf(0,rain_left-delta)
		rain_mesh.visible = rain_left>0
		rain_mesh.position = player
		for i in drops.size():
			var drop: Vector3 = drops[i]
			drop.y = fposmod(drop.y-delta*10,12)
			drops[i] = drop
			rain_mesh.multimesh.set_instance_transform(i,Transform3D(Basis.IDENTITY,drop))
		if position2.distance_to(NURSERY)<14 and not game.state.nursery_watered:
			game.state.nursery_watered = true
			game._toast("Rain beads on the cut stumps. Vines and tiny flowers begin to grow.")
			game.save_game()
	if game.state.nursery_watered and growth<1:
		growth = minf(1,growth+delta/14.0)
		_update_sprouts()

func _update_sprouts() -> void:
	for sprout in sprouts:
		sprout.visible = growth>0
		sprout.scale = Vector3.ONE*maxf(0.01,growth)

func _tick_squirrel(delta: float, player: Vector2) -> void:
	var squirrel: Node3D = cast.squirrel
	if game.state.rain_learned:
		return
	var stage: int = mini(game.state.squirrel_stage,route.size()-1)
	var at := Vector2(squirrel.position.x,squirrel.position.z)
	var distance: float = at.distance_to(player)
	if not squirrel_hint and distance<9:
		squirrel_hint = true
		game._toast("A squirrel with a silver acorn is watching. Follow it along the fern trail.")
	var target: Vector2 = route[stage]
	if at.distance_to(target)>0.15 and distance<16:
		var next: Vector2 = at.move_toward(target,delta*4.0)
		squirrel.position = _ground(next)
		squirrel.rotation.y = atan2(target.x-at.x,target.y-at.y)
	elif at.distance_to(target)<=0.15 and distance<4:
		if stage<route.size()-1:
			game.state.squirrel_stage = stage+1
			game.save_game()
		else:
			game.state.rain_learned = true
			game._toast("The squirrel shares Raincall: D F A G F D. Raise your pipes and play W R I U R W.")
			game.music.melody(RAIN,0.5)
			game._burst(squirrel.position,28)
			game.save_game()

func _match(buffer: Array[int], pitch: int, expected: Array[int]) -> bool:
	buffer.append(60+posmod(pitch-60,12))
	while buffer.size()>expected.size(): buffer.pop_front()
	return buffer == expected

func play_pitch(pitch: int) -> bool:
	if near_oil():
		if _match(animal_phrase,pitch,CLEANSE):
			game.state.wildlife_healed = true
			cast.set_oiled(oily_animal,false)
			cast.celebrate({"x":OIL_SPOT.x,"z":OIL_SPOT.y,"kind":"pollution","id":"wildlife"})
			game._toast("The oil lifts from the fox's fur. It shakes, stretches, and joins the dance.")
			game.save_game()
		return true
	if game.state.rain_learned and _match(rain_phrase,pitch,RAIN):
		rain_left = 45.0
		rain_phrase.clear()
		game._toast("Raincall answered. Soft rain follows you for forty-five seconds.")
		game._burst(game.body.position,24)
	return false

func interact() -> bool:
	var p := Vector2(float(game.state.player.x),float(game.state.player.z))
	if near_oil():
		game.music.melody(CLEANSE)
		game._toast("A fox is coated in oil. Raise your pipes: E W Q W E U. Listen before you answer.")
		return true
	if p.distance_to(ARTEMIS_SPOT)<12 and game.state.healed.size()>=3:
		game._toast("Artemis: Let the young things grow. Beyond this wood, a forest has fallen silent.")
		return true
	for point in [Vector2(-55,10),NURSERY]:
		if p.distance_to(point)<6:
			game._toast("Dryad: The squirrel remembers rain. Follow the northwestern ferns. Bring its song to the cut stumps." if not game.state.rain_learned else "Dryad: Raincall is W R I U R W. Play it among the stumps; small beginnings are enough.")
			return true
	return false

func hint() -> String:
	if near_oil(): return "Oiled fox · E to listen · Tab raises pipes"
	var p := Vector2(float(game.state.player.x),float(game.state.player.z))
	if p.distance_to(NURSERY)<8: return "Stump nursery · E speaks with the dryad · Raincall can nurture new growth"
	if p.distance_to(Vector2(-55,10))<8: return "Dryad glade · E speaks with the dryad"
	if p.distance_to(ARTEMIS_SPOT)<15 and game.state.healed.size()>=3: return "Artemis in the moon meadow · E to listen"
	return ""
