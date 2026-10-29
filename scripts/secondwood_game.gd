extends Node3D
## A self-contained chapter. Routes, healing tools and reopened shortcuts share
## the layout registry; the first valley keeps its scene and save untouched.
const State = preload("res://scripts/secondwood_state.gd")
const Layout = preload("res://scripts/secondwood_layout.gd")
const World = preload("res://scripts/secondwood_map.gd")
const Faun = preload("res://scripts/faun.gd")
const Music = preload("res://scripts/music.gd")
const Keyboard = preload("res://scripts/keyboard.gd")
const Cast = preload("res://scripts/woodland_cast.gd")
const FINAL_PHRASE: Array[int] = State.FINAL_PHRASE
var state: RefCounted
var map: Node3D
var body: Node3D
var faun: Node3D
var music: Node
var camera: Camera3D
var started: bool = false
var paused: bool = false
var playing: bool = false
var save_enabled: bool = true
var save_path: String = "user://secondwood.json"
var touch_move := Vector2.ZERO
var camera_yaw: float = PI+0.18
var camera_pitch: float = -0.65
var camera_distance: float = 16.0
var dragging: bool = false
var octave: int = Keyboard.DEFAULT_OCTAVE
var held_keys: Dictionary = {}
var modifiers: Dictionary = {}
var clock: float = 0.0
var save_clock: float = 0.0
var items: Dictionary = {}
var site_markers: Dictionary = {}
var particles: Array[Dictionary] = []
var cast: Node3D
var artemis: Node3D
var target_markers: Dictionary = {}
var anchor_markers: Dictionary = {}
var canopy_residents: Array[Node3D] = []
var lens_toggle: bool = false
var lens_button: Button
var lens_meter: ProgressBar
var lens_beam: MeshInstance3D
var keeper: Node3D
var residents: Dictionary = {}
var hud: Control
var goal_label: Label
var region_label: Label
var count_label: Label
var context_label: Label
var inventory_label: Label
var toast_label: Label
var toast_clock: float = 0.0
var music_panel: PanelContainer
var pipe_button: Button
var modal: Control
var modal_box: VBoxContainer
var overview: Control
var note_caption: Label
var key_buttons: Array[Button] = []
var sound_button: Button

class RouteOverview extends Control:
	var game: Node
	func point(p: Vector2) -> Vector2:
		return size*0.5+p*(minf(size.x,size.y)-50.0)/(Layout.BOUNDS*2.0)
	func _draw() -> void:
		if game==null or game.state==null: return
		draw_rect(Rect2(Vector2.ZERO,size),Color("#1c3734"))
		draw_rect(Rect2(Vector2.ONE,size-Vector2.ONE*2),Color("#86a48a"),false,1)
		for route: Dictionary in Layout.PATHS+Layout.SHORTCUTS:
			var open: bool = Layout.requirements_met(route.get("requires",[]),game.state.flags())
			var color := (Color("#a6d9b0") if Layout.SHORTCUTS.has(route) else Color("#bfc493")) if open else Color("#526464")
			var points: Array = route.points
			for i in range(1,points.size()): draw_line(point(points[i-1]),point(points[i]),color,2.0 if open else 1.0,true)
		for id: String in Layout.SITES:
			var p: Vector2 = point(Layout.SITES[id].position)
			draw_circle(p,5,Color("#b6df93") if game.state.healed.has(id) else Color("#dc9a72"))
			var name: String = str(Layout.SITES[id].name)
			var width: float = ThemeDB.fallback_font.get_string_size(name,HORIZONTAL_ALIGNMENT_LEFT,-1,11).x
			draw_string(ThemeDB.fallback_font,p+(Vector2(-width-8,3) if id=="source" else Vector2(8,14) if id=="hollow" else Vector2(-width*0.5,-9)),name,HORIZONTAL_ALIGNMENT_LEFT,-1,11,Color("#eee5c6"))
		for id: String in Layout.ITEMS:
			if game.state.inventory.has(id): continue
			var p: Vector2 = point(Layout.ITEMS[id].position)
			draw_colored_polygon(PackedVector2Array([p+Vector2(0,-4),p+Vector2(4,0),p+Vector2(0,4),p+Vector2(-4,0)]),Color("#e5c76d"))
		for id: String in Layout.TARGETS:
			var p: Vector2 = point(Layout.TARGETS[id].position)
			draw_circle(p,3,Color("#bce2df") if game.state.crossings_complete.has(id) else Color("#d9a6e0"))
		draw_circle(point(Layout.CROWN),6,Color("#b6d985"),false,2)
		draw_string(ThemeDB.fallback_font,point(Layout.CROWN)+Vector2(8,0),"Crown Clearing",HORIZONTAL_ALIGNMENT_LEFT,-1,11,Color("#ecdfb0"))
		for landmark: Dictionary in [{"p":Layout.LENS,"name":"Mirror Wetland","offset":Vector2(-5,-14)},{"p":Layout.SPOOL,"name":"Cinder Loom","offset":Vector2(-55,-14)},{"p":Layout.HUB,"name":"Artemis","offset":Vector2(-18,17)}]:
			draw_string(ThemeDB.fallback_font,point(landmark.p)+Vector2(landmark.offset),str(landmark.name),HORIZONTAL_ALIGNMENT_LEFT,-1,11,Color("#ecdfb0"))
		draw_circle(point(Layout.HUB),3,Color("#e8d8b1"))
		draw_circle(point(Layout.FINAL),6,Color("#d5bde3"),false,2,true)
		draw_string(ThemeDB.fallback_font,point(Layout.FINAL)+Vector2(8,4),"Final grove",HORIZONTAL_ALIGNMENT_LEFT,-1,11,Color("#e2cfe9"))
		draw_circle(point(game.state.position2()),4,Color.WHITE)
		draw_string(ThemeDB.fallback_font,Vector2(size.x*0.5-5,16),"N",HORIZONTAL_ALIGNMENT_LEFT,-1,11,Color("#eee5c6"))

func _ready() -> void:
	get_tree().auto_accept_quit = false
	state = State.new()
	map = World.new()
	add_child(map)
	var material := StandardMaterial3D.new()
	material.vertex_color_use_as_albedo = true
	material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	material.cull_mode = BaseMaterial3D.CULL_DISABLED
	map.build(material)
	body = Node3D.new()
	add_child(body)
	faun = Faun.new()
	body.add_child(faun)
	var bytes: PackedByteArray = FileAccess.get_file_as_bytes("res://assets/valley.nvs.gz")
	var data: Variant = JSON.parse_string(bytes.decompress_dynamic(64000000,FileAccess.COMPRESSION_GZIP).get_string_from_utf8())
	assert(data is Dictionary and data.has("faun"),"The shared faun source asset could not be read.")
	faun.build(data.faun)
	music = Music.new()
	add_child(music)
	camera = Camera3D.new()
	camera.fov = 54.0
	camera.far = 300.0
	camera.current = true
	add_child(camera)
	var environment := WorldEnvironment.new()
	var settings := Environment.new()
	settings.background_mode = Environment.BG_COLOR
	settings.background_color = Color("#899c98")
	environment.environment = settings
	add_child(environment)
	_make_discoveries()
	_build_ui()
	_sync_position()
	_update_camera(1.0)
	get_viewport().size_changed.connect(_layout_ui)

func start_level(resume: bool = false) -> void:
	music.stop()
	lens_toggle = false
	held_keys.clear()
	modifiers.clear()
	state = State.new()
	if resume:
		var saved: Variant = _read_save(save_path)
		if not saved is Dictionary: saved = _read_save(save_path+".bak")
		state.restore(saved)
	else:
		state.player.yaw = camera_yaw+PI
	map.sync(state.flags())
	_sync_relics()
	if not map.is_clear(float(state.player.x),float(state.player.z),state.flags()):
		state.player.x = Layout.ENTRY.x
		state.player.z = Layout.ENTRY.y
	started = true
	paused = false
	playing = false
	touch_move = Vector2.ZERO
	clock = state.elapsed
	save_clock = 0.0
	modal.hide()
	hud.show()
	for id: String in items: items[id].visible = not state.inventory.has(id)
	for id: String in site_markers:
		_set_site_marker(id)
		residents[id].visible = state.healed.has(id)
	music_panel.hide()
	pipe_button.text = "Tab · Raise pipes"
	_sync_position()
	_update_camera(1.0)
	update_hud()
	_toast("The branching wood keeps its wounds in sight. Artemis waits beside the lantern fork.")
	save_game()

func _read_save(path: String) -> Variant:
	if not FileAccess.file_exists(path): return null
	return JSON.parse_string(FileAccess.get_file_as_string(path))

func _material(color: Color) -> StandardMaterial3D:
	var mat := StandardMaterial3D.new()
	mat.albedo_color = color
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	return mat

func _gem(color: Color, radius: float) -> MeshInstance3D:
	var node := MeshInstance3D.new()
	var mesh := SphereMesh.new()
	mesh.radius = radius
	mesh.height = radius*2.2
	mesh.radial_segments = 5
	mesh.rings = 3
	node.mesh = mesh
	node.material_override = _material(color)
	return node

func _ground(p: Vector2, lift: float = 0.0) -> Vector3:
	return Vector3(p.x,World.height_at(p.x,p.y)+lift,p.y)

func _make_discoveries() -> void:
	for id: String in Layout.ITEMS:
		var item: Dictionary = Layout.ITEMS[id]
		var group := Node3D.new()
		group.position = _ground(item.position,0.85)
		add_child(group)
		var color := Color("#9bd0dc") if id=="vessel" else Color("#b9d88c") if id=="spore" else Color("#e8c18c")
		group.add_child(_gem(color,0.26))
		for side in [-1,1]:
			var leaf := _gem(Color("#e6d5a2"),0.12)
			leaf.position = Vector3(float(side)*0.3,0,0)
			leaf.scale = Vector3(1.8,0.6,0.6)
			group.add_child(leaf)
		items[id] = group
	for id: String in Layout.SITES:
		var group := Node3D.new()
		group.position = _ground(Layout.SITES[id].position,1.4)
		group.add_child(_gem(Color("#dba482"),0.16))
		add_child(group)
		site_markers[id] = group
	cast = Cast.new()
	add_child(cast)
	keeper = cast.create_dryad()
	keeper.name = "WoodlandKeeper"
	keeper.position = _ground(Layout.HUB+Vector2(-2.0,1.0))
	add_child(keeper)
	artemis = cast.create_artemis()
	artemis.position = _ground(Layout.ARTEMIS)
	add_child(artemis)
	for id: String in Layout.TARGETS:
		var marker := _gem(Color("#c7b2e5"),0.25)
		marker.position = _ground(Layout.TARGETS[id].position,0.5)
		marker.name = "RelicTarget_"+id
		add_child(marker)
		target_markers[id] = marker
	for id: String in Layout.ANCHORS:
		anchor_markers[id] = []
		for anchor: Vector2 in Layout.ANCHORS[id]:
			var marker := _gem(Color("#e3ca7f"),0.22)
			marker.position = _ground(anchor,0.45)
			add_child(marker)
			var caption := Label3D.new()
			caption.text = "ROOT ANCHOR %d · E" % (anchor_markers[id].size()+1)
			caption.font_size = 28
			caption.pixel_size = 0.008
			caption.billboard = BaseMaterial3D.BILLBOARD_ENABLED
			caption.position.y = 0.7
			marker.add_child(caption)
			var stump := MeshInstance3D.new()
			var wood := CylinderMesh.new()
			wood.top_radius = 0.18
			wood.bottom_radius = 0.24
			wood.height = 0.5
			wood.radial_segments = 6
			stump.mesh = wood
			stump.material_override = _material(Color("#867251"))
			stump.position.y = -0.3
			marker.add_child(stump)
			anchor_markers[id].append(marker)
	for i in 4:
		var animal: Node3D = cast.create_animal("bird" if i%2 else "rabbit")
		animal.position = _ground(Layout.CROWN+Vector2.from_angle(i*TAU/4.0)*2.5)
		add_child(animal)
		canopy_residents.append(animal)
	for id: String in Layout.SITES:
		var animal: Node3D = cast.create_animal("bird" if id=="source" else "rabbit")
		animal.position = _ground(Layout.SITES[id].position+Vector2(1.3,1.3))
		animal.hide()
		add_child(animal)
		residents[id] = animal
	lens_beam = MeshInstance3D.new()
	var beam_mesh := BoxMesh.new()
	beam_mesh.size = Vector3(0.12,0.08,1.0)
	lens_beam.mesh = beam_mesh
	lens_beam.material_override = _material(Color("#e9efbe"))
	lens_beam.hide()
	add_child(lens_beam)
	var lantern := _gem(Color("#e6c57e"),0.25)
	lantern.position = _ground(Layout.HUB,1.5)
	add_child(lantern)

func _set_site_marker(id: String) -> void:
	var marker: MeshInstance3D = site_markers[id].get_child(0)
	marker.material_override = _material(Color("#a9db92") if state.healed.has(id) else Color("#dba482"))

func _sync_position() -> void:
	body.position = _ground(state.position2())
	body.rotation.y = float(state.player.yaw)

func _physics_process(delta: float) -> void:
	if not started or paused: return
	clock += delta
	state.elapsed += delta
	save_clock += delta
	if save_clock>=5.0:
		save_clock = 0.0
		save_game()
	var x: float = float(Input.is_physical_key_pressed(KEY_D) or Input.is_physical_key_pressed(KEY_RIGHT))-float(Input.is_physical_key_pressed(KEY_A) or Input.is_physical_key_pressed(KEY_LEFT))
	var z: float = float(Input.is_physical_key_pressed(KEY_W) or Input.is_physical_key_pressed(KEY_UP))-float(Input.is_physical_key_pressed(KEY_S) or Input.is_physical_key_pressed(KEY_DOWN))
	var movement: Vector2 = (Vector2(x,z)+touch_move).limit_length(1.0)
	if playing: movement = Vector2.ZERO
	var walking: bool = movement.length()>0.01
	if walking:
		state.phrase.clear()
		var direction := Vector2(movement.x*cos(camera_yaw)+movement.y*sin(camera_yaw),-movement.x*sin(camera_yaw)+movement.y*cos(camera_yaw))
		var speed: float = 4.5 if Input.is_physical_key_pressed(KEY_SHIFT) else 3.2
		# Small substeps prevent a long frame jumping across a locked corridor.
		var count: int = maxi(1,ceili(speed*delta/0.12))
		var step: Vector2 = direction*speed*delta/float(count)
		for i in count:
			var nx: float = clampf(float(state.player.x)+step.x,-Layout.BOUNDS,Layout.BOUNDS)
			var nz: float = clampf(float(state.player.z)+step.y,-Layout.BOUNDS,Layout.BOUNDS)
			if map.is_clear(nx,float(state.player.z),state.flags()): state.player.x = nx
			if map.is_clear(float(state.player.x),nz,state.flags()): state.player.z = nz
		state.player.yaw = lerp_angle(float(state.player.yaw),atan2(direction.x,direction.y),minf(1.0,delta*13.0))
	var pitches: Array = held_keys.values()
	if lens_toggle: pitches.append(62)
	var lens_event: Dictionary = state.hold_lens(delta,pitches,playing)
	if not lens_event.is_empty():
		if lens_toggle: music.note_off(62)
		lens_toggle = false
		_apply_quest_event(lens_event)
	_update_lens_beam()
	_sync_position()
	faun.animate(delta,walking,playing,false,clock)
	cast._animate(keeper,clock,state.position2().distance_to(Layout.HUB)<5.5)
	cast._animate(artemis,clock,state.acorn_state=="planted")
	artemis.rotation.y = atan2(body.position.x-artemis.position.x,body.position.z-artemis.position.z)
	for animal in canopy_residents:
		if animal.visible: cast._animate(animal,clock,true)
	keeper.rotation.y = atan2(body.position.x-keeper.position.x,body.position.z-keeper.position.z)
	for id: String in residents:
		if residents[id].visible: cast._animate(residents[id],clock,true)
	for id: String in items:
		if state.collect_item(id):
			items[id].hide()
			_burst(body.position,22)
			music.melody([64,67,72],0.17)
			_toast(str(Layout.ITEMS[id].name)+" found. "+str(Layout.ITEMS[id].description)+" It stays in your pack after use.")
			save_game()
	music.restoration = float(state.healed.size())/3.0
	music.region = "THE BRANCHING WOOD"
	if not playing: music.tick(delta)
	update_hud()

func _process(delta: float) -> void:
	if not is_instance_valid(camera): return
	_update_camera(delta)
	if paused: return
	for id: String in items:
		var item: Node3D = items[id]
		item.rotation.y = clock*0.8
		item.position.y = World.height_at(item.position.x,item.position.z)+0.85+sin(clock*2.0)*0.1
	for id: String in site_markers:
		var marker: Node3D = site_markers[id]
		marker.rotation.y = clock*0.5
	for i in range(particles.size()-1,-1,-1):
		var particle: Dictionary = particles[i]
		particle.age += delta
		particle.node.position += particle.velocity*delta
		particle.node.scale = Vector3.ONE*maxf(0.01,1.0-float(particle.age)/2.5)
		if particle.age>=2.5:
			particle.node.queue_free()
			particles.remove_at(i)
	if toast_clock>0:
		toast_clock -= delta
		toast_label.visible = toast_clock>0

func _update_camera(delta: float) -> void:
	var focus: Vector3 = body.global_position+Vector3.UP*0.9
	var offset := Vector3(-sin(camera_yaw)*cos(camera_pitch),-sin(camera_pitch),-cos(camera_yaw)*cos(camera_pitch))*camera_distance
	camera.global_position = camera.global_position.lerp(focus+offset,minf(1.0,delta*8.0))
	camera.look_at(focus)

func _current_octave() -> int:
	return int(modifiers.values().back()) if not modifiers.is_empty() else octave

func _input(event: InputEvent) -> void:
	if event is InputEventKey and not event.pressed:
		var key: int = event.physical_keycode if event.physical_keycode!=0 else event.keycode
		if held_keys.has(key):
			var pitch: int = held_keys[key]
			held_keys.erase(key)
			if not held_keys.values().has(pitch): music.note_off(pitch)
		modifiers.erase(str(key)+":"+str(event.location))
	if event is InputEventMouseButton and not event.pressed: dragging = false

func _unhandled_input(event: InputEvent) -> void:
	if not started: return
	if event is InputEventKey and event.pressed and not event.echo:
		var key: int = event.physical_keycode if event.physical_keycode!=0 else event.keycode
		if key==KEY_ESCAPE:
			resume_game() if paused else show_pause()
			get_viewport().set_input_as_handled()
			return
		if paused: return
		if key==KEY_TAB: set_pipes(not playing)
		elif playing:
			if key in [KEY_PAGEUP,KEY_PAGEDOWN]: octave = clampi(octave+(1 if key==KEY_PAGEUP else -1),1,6)
			elif key in [KEY_CTRL,KEY_SHIFT,KEY_CAPSLOCK]: modifiers[str(key)+":"+str(event.location)] = Keyboard.octave_for_modifier(key,event.location)
			else:
				var pitch: int = Keyboard.pitch_for_key(key,_current_octave(),Input.is_physical_key_pressed(KEY_SPACE))
				if pitch>=0 and not held_keys.has(key):
					held_keys[key] = pitch
					play_midi(pitch,true)
		elif key==KEY_E: interact()
		elif key==KEY_J: show_journal()
		get_viewport().set_input_as_handled()
	if paused: return
	if event is InputEventMouseButton and event.pressed:
		if event.button_index==MOUSE_BUTTON_WHEEL_UP: camera_distance = maxf(9.0,camera_distance-1.0)
		elif event.button_index==MOUSE_BUTTON_WHEEL_DOWN: camera_distance = minf(27.0,camera_distance+1.0)
		elif event.button_index in [MOUSE_BUTTON_LEFT,MOUSE_BUTTON_RIGHT]: dragging = true
	if event is InputEventMouseMotion and dragging:
		camera_yaw -= event.relative.x*0.006
		camera_pitch = clampf(camera_pitch-event.relative.y*0.003,-1.08,-0.3)

func set_pipes(value: bool) -> void:
	music.release_all()
	held_keys.clear()
	modifiers.clear()
	playing = value
	if not value:
		state.reset_lens()
		_update_lens_beam()
		lens_toggle = false
	state.phrase.clear()
	music_panel.visible = value
	pipe_button.text = "Tab · Lower pipes" if value else "Tab · Raise pipes"
	_layout_ui()
	update_hud()

func play_midi(pitch: int, held: bool = false) -> void:
	if not started or paused: return
	if not playing: set_pipes(true)
	if held: music.note_on(pitch,0.65)
	else: music.play_note(pitch,0.65)
	_burst(body.position,2)
	if state.play_pitch(pitch):
		map.sync(state.flags())
		_burst(_ground(Layout.FINAL),65)
		save_game()
		_toast("Artemis bows beneath the young canopy." if state.artemis_finale_done else "Water, spores and roots answer together. The branching wood is alive again.")
		_sync_relics()
		show_ending()
		music.melody([60,64,67,72,76,79],0.18)
	update_hud()

func interact() -> void:
	if not started or paused or playing: return
	var position2: Vector2 = state.position2()
	# Relic and Artemis interactions have explicit spatial boundaries.
	if position2.distance_to(Layout.ARTEMIS)<=4.0:
		_apply_quest_event(state.accept_artemis_quest())
		if state.acorn_state=="planted":
			music.melody(FINAL_PHRASE,0.5)
			_toast("Artemis: The roots remember. Answer with Q E U I U E Q.")
		return
	if position2.distance_to(Layout.CROWN)<=3.5:
		save_game()
		_apply_quest_event(state.plant_acorn())
		return
	for repair: String in Layout.ANCHORS:
		if not state.repair_anchors.has(repair) or state.crossings_complete.has(repair): continue
		for index in 3:
			if not state.repair_anchors[repair].has(index) and position2.distance_to(Layout.ANCHORS[repair][index])<=1.6:
				_apply_quest_event(state.bind_anchor(repair,index))
				return
	var target: String = nearest_target()
	if not target.is_empty():
		_apply_quest_event(state.activate_relic_target(target))
		return
	if position2.distance_to(Layout.SITES.source.position)<=3.5 and state.healed.has("source") and state.inventory.has("lens"):
		_apply_quest_event(state.activate_relic_target("attune"))
		return
	var nearest_id: String = ""
	var nearest: float = 3.5
	for id: String in Layout.SITES:
		var distance: float = position2.distance_to(Layout.SITES[id].position)
		if distance<=nearest:
			nearest = distance
			nearest_id = id
	if not nearest_id.is_empty():
		var result: Dictionary = state.try_heal(nearest_id)
		var site: Dictionary = Layout.SITES[nearest_id]
		if result.type=="healed":
			map.sync(state.flags(),true)
			_set_site_marker(nearest_id)
			residents[nearest_id].show()
			_burst(_ground(site.position),42)
			music.melody([60,64,67,72],0.19)
			_toast(str(site.name)+" recovers. Roots unfold into a permanent shortcut. Your "+str(Layout.ITEMS[str(site.item)].name)+" remains in your pack.")
			save_game()
		elif result.type=="missing":
			_toast(str(site.description)+" Return with the "+str(Layout.ITEMS[str(site.item)].name)+". Other tools cannot heal this wound.")
		else: _toast(str(site.name)+" is breathing again. Its reopened path stays open.")
	elif position2.distance_to(Layout.HUB)<5.5:
		_toast("Keeper: "+state.objective())
	elif position2.distance_to(Layout.FINAL)<6.0:
		if state.healed.size()==3:
			music.melody(FINAL_PHRASE,0.5)
			_toast("The final grove remembers Q E U I U E Q. Raise the pipes and answer at your own pace.")
		else: _toast("The final grove waits for water, living spores and young roots. Heal all three wounded places first.")
	else: _toast(state.objective())
	update_hud()

func _update_lens_beam() -> void:
	lens_beam.visible = state.lens_focused and state.lens_progress>0.0
	if not lens_beam.visible: return
	var start: Vector3 = _ground(Layout.TARGETS["west-ridge-roots"].position,0.18)
	var end: Vector3 = _ground(Vector2(-110,-15),0.18)
	var progress: float = state.lens_progress/1.5
	lens_beam.position = start.lerp(end,progress*0.5)
	lens_beam.look_at(end)
	lens_beam.scale.z = maxf(0.01,start.distance_to(end)*progress)

func nearest_target() -> String:
	var best: String = ""
	var distance: float = 3.5
	for id: String in Layout.TARGETS:
		var d: float = state.position2().distance_to(Layout.TARGETS[id].position)
		if d<=distance:
			distance = d
			best = id
	return best

func _sync_relics() -> void:
	for id: String in target_markers:
		target_markers[id].material_override = _material(Color("#addb95") if state.crossings_complete.has(id) else Color("#c7b2e5"))
	for id: String in anchor_markers:
		var done: Array = state.repair_anchors.get(id,[])
		for index in 3:
			var marker: MeshInstance3D = anchor_markers[id][index]
			marker.visible = state.repair_anchors.has(id)
			var next: int = 0
			while done.has(next): next += 1
			marker.scale = Vector3.ONE*(1.2 if index==next else 0.8)
			marker.material_override = _material(Color("#9ccc86") if done.has(index) else Color("#f2d983") if index==next else Color("#b4a981"))
	for animal in canopy_residents: animal.visible = state.acorn_state=="planted"

func _apply_quest_event(event: Dictionary) -> void:
	if event.has("text"): _toast(str(event.text))
	map.sync(state.flags(),true)
	_sync_relics()
	if event.get("type","") in ["opened","bound","planted","attuned","acorn"]:
		_burst(body.position,20)
		music.melody([62,65,69],0.18)
	save_game()
	update_hud()

func toggle_lens_hold() -> void:
	if not state.lens_focused: return
	lens_toggle = not lens_toggle
	if lens_toggle: music.note_on(62,0.65)
	else: music.note_off(62)

func _burst(origin: Vector3, amount: int) -> void:
	for i in amount:
		var gem := _gem(Color("#b5d68a") if i%2 else Color("#e5d29c"),0.045)
		gem.position = origin+Vector3(randf_range(-0.5,0.5),0.5,randf_range(-0.5,0.5))
		add_child(gem)
		particles.append({"node":gem,"age":0.0,"velocity":Vector3(randf_range(-0.9,0.9),randf_range(0.5,1.6),randf_range(-0.9,0.9))})

func save_game() -> void:
	if not save_enabled or not started: return
	var file := FileAccess.open(save_path+".tmp",FileAccess.WRITE)
	if file==null: _toast("The journey could not be saved. Your earlier save is preserved."); return
	file.store_string(JSON.stringify(state.serialize()))
	file.close()
	var absolute: String = ProjectSettings.globalize_path(save_path)
	if FileAccess.file_exists(save_path+".bak"): DirAccess.remove_absolute(absolute+".bak")
	if FileAccess.file_exists(save_path): DirAccess.rename_absolute(absolute,absolute+".bak")
	if DirAccess.rename_absolute(absolute+".tmp",absolute)!=OK:
		if FileAccess.file_exists(save_path+".bak"): DirAccess.rename_absolute(absolute+".bak",absolute)
		_toast("The save could not be completed. Your earlier journey is preserved.")

func _notification(what: int) -> void:
	if what==NOTIFICATION_WM_CLOSE_REQUEST:
		save_game()
		get_tree().quit()
	if what==NOTIFICATION_APPLICATION_FOCUS_OUT and started and not paused: show_pause()

func _exit_tree() -> void:
	if started: save_game()

func update_hud() -> void:
	if not is_instance_valid(goal_label): return
	goal_label.text = state.objective()
	count_label.text = "%d / 3 lands healed · %d / 5 tools and relics" % [state.healed.size(),state.inventory.size()]
	var tool_names := PackedStringArray()
	for id: String in state.inventory: tool_names.append(str(Layout.ITEMS[id].name))
	inventory_label.text = "Pack: "+(", ".join(tool_names) if not tool_names.is_empty() else "Find tools along the longer trails")
	region_label.text = "THE BRANCHING WOOD"
	var position2: Vector2 = state.position2()
	for clearing: Dictionary in Layout.CLEARINGS:
		if position2.distance_to(clearing.position)<float(clearing.radius)+2.0:
			region_label.text = str(clearing.name).to_upper()
	context_label.text = "W A S D / arrows walk · Shift brisk walk · Drag looks · J journal · Tab pipes"
	for id: String in Layout.SITES:
		if position2.distance_to(Layout.SITES[id].position)<4.0:
			context_label.text = "E · Inspect healed land" if state.healed.has(id) else "E · Use "+str(Layout.ITEMS[str(Layout.SITES[id].item)].name)+" here"
	if position2.distance_to(Layout.HUB)<5.5: context_label.text = "E · Ask the keeper about the wounded land"
	if position2.distance_to(Layout.ARTEMIS)<=4.0: context_label.text = "E · Speak with Artemis"
	if position2.distance_to(Layout.CROWN)<=3.5: context_label.text = "E · Visit the young canopy" if state.acorn_state=="planted" else "E · Plant Artemis's acorn with the Spindle"
	var target: String = nearest_target()
	if not target.is_empty(): context_label.text = "E · "+str(Layout.TARGETS[target].name)
	for repair: String in Layout.ANCHORS:
		if not state.repair_anchors.has(repair): continue
		for index in 3:
			if not state.repair_anchors[repair].has(index) and position2.distance_to(Layout.ANCHORS[repair][index])<=1.6: context_label.text = "E · Bind root anchor %d / 3" % (index+1)
	if position2.distance_to(Layout.SITES.source.position)<=3.5 and state.inventory.has("lens") and state.healed.has("source"): context_label.text = "E · Clarify and attune Moon Lens"
	if lens_button!=null:
		lens_meter.visible = state.lens_focused
		lens_meter.value = state.lens_progress/1.5*100.0
		lens_button.visible = state.lens_focused
		lens_button.text = "Stop holding D" if lens_toggle else "Hold D · toggle"
	if position2.distance_to(Layout.FINAL)<6.0: context_label.text = "E · Hear the final phrase · Tab pipes · Q E U I U E Q"
	for button: Button in key_buttons:
		var keycode: int = int(button.get_meta("keycode"))
		var pitch: int = Keyboard.pitch_for_key(keycode,_current_octave(),Input.is_physical_key_pressed(KEY_SPACE))
		button.text = Keyboard.key_name(keycode)+" "+Keyboard.note_name(pitch)
	if playing:
		context_label.text = "MBean1 rows play · Space sharpens · PgUp/PgDn octaves · Tab lowers pipes"
		note_caption.text = ("Moon Lens · D held %d%% · 1.5 seconds · Hold D toggle available" % int(state.lens_progress/1.5*100.0)) if state.lens_focused else "Base C%d · %d / 7 final notes" % [_current_octave(),state.phrase.size()]

func _style() -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.055,0.14,0.13,0.94)
	style.content_margin_left = 16
	style.content_margin_right = 16
	style.content_margin_top = 12
	style.content_margin_bottom = 12
	return style

func _panel(parent: Node,at: Vector2,dimensions: Vector2) -> PanelContainer:
	var panel := PanelContainer.new()
	panel.position = at
	panel.custom_minimum_size = dimensions
	panel.size = dimensions
	panel.add_theme_stylebox_override("panel",_style())
	parent.add_child(panel)
	return panel

func _label(parent: Node,text: String,font_size: int = 16) -> Label:
	var label := Label.new()
	label.text = text
	label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	label.add_theme_font_size_override("font_size",font_size)
	label.add_theme_color_override("font_color",Color("#eee5cc"))
	parent.add_child(label)
	return label

func _button(parent: Node,text: String,callback: Callable) -> Button:
	var button := Button.new()
	button.text = text
	button.custom_minimum_size.y = 35
	button.focus_mode = Control.FOCUS_NONE
	button.pressed.connect(callback)
	parent.add_child(button)
	return button

func _build_ui() -> void:
	var layer := CanvasLayer.new()
	add_child(layer)
	hud = Control.new()
	hud.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	hud.mouse_filter = Control.MOUSE_FILTER_IGNORE
	layer.add_child(hud)
	var goal_panel := _panel(hud,Vector2(24,24),Vector2(390,170))
	var goals := VBoxContainer.new()
	goals.add_theme_constant_override("separation",8)
	goal_panel.add_child(goals)
	region_label = _label(goals,"THE BRANCHING WOOD",13)
	count_label = _label(goals,"",15)
	goal_label = _label(goals,"",16)
	var top := HBoxContainer.new()
	top.position = Vector2(785,24)
	top.name = "TopActions"
	hud.add_child(top)
	_button(top,"Journal · J",show_journal)
	pipe_button = _button(top,"Tab · Raise pipes",func() -> void: set_pipes(not playing))
	sound_button = _button(top,"Sound on",toggle_sound)
	_button(top,"Pause · Esc",show_pause)
	inventory_label = _label(hud,"",15)
	inventory_label.position = Vector2(28,208)
	inventory_label.size = Vector2(370,80)
	context_label = _label(hud,"",15)
	context_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	toast_label = _label(hud,"",17)
	toast_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	toast_label.add_theme_stylebox_override("normal",_style())
	toast_label.hide()
	music_panel = _panel(hud,Vector2(220,550),Vector2(840,206))
	var instrument := VBoxContainer.new()
	music_panel.add_child(instrument)
	note_caption = _label(instrument,"MBean1 keyboard",13)
	lens_button = _button(instrument,"Hold D · toggle",toggle_lens_hold)
	lens_button.hide()
	lens_meter = ProgressBar.new()
	lens_meter.custom_minimum_size.y = 12
	lens_meter.show_percentage = false
	instrument.add_child(lens_meter)
	lens_meter.hide()
	for row: Dictionary in Keyboard.rows():
		var keys := HBoxContainer.new()
		instrument.add_child(keys)
		for entry: Dictionary in row["keys"]:
			var keycode: int = entry.keycode
			var button := _button(keys,str(entry.key)+" "+str(entry.note),func() -> void: play_midi(Keyboard.pitch_for_key(keycode,_current_octave(),Input.is_physical_key_pressed(KEY_SPACE))))
			button.custom_minimum_size = Vector2(100,30)
			button.add_theme_font_size_override("font_size",12)
			button.set_meta("keycode",keycode)
			key_buttons.append(button)
	music_panel.hide()
	modal = Control.new()
	modal.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	layer.add_child(modal)
	var shade := ColorRect.new()
	shade.color = Color(0.015,0.04,0.035,0.86)
	shade.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	modal.add_child(shade)
	var sheet := _panel(modal,Vector2(290,55),Vector2(700,690))
	sheet.name = "Sheet"
	var scroll := ScrollContainer.new()
	sheet.add_child(scroll)
	modal_box = VBoxContainer.new()
	modal_box.custom_minimum_size.x = 650
	modal_box.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	modal_box.add_theme_constant_override("separation",12)
	scroll.add_child(modal_box)
	modal.hide()
	_layout_ui()

func _layout_ui() -> void:
	if hud==null: return
	var size: Vector2 = get_viewport().get_visible_rect().size
	hud.get_node("TopActions").position = Vector2(size.x-500,24)
	context_label.position = Vector2(16,size.y-52)
	context_label.size = Vector2(size.x-32,34)
	music_panel.position = Vector2((size.x-840)/2.0,size.y-264)
	toast_label.position = Vector2((size.x-590)/2.0,size.y-410 if playing else size.y-170)
	toast_label.size = Vector2(590,78)
	modal.get_node("Sheet").position = Vector2((size.x-700)/2.0,maxf(15.0,(size.y-690)/2.0))

func _open_modal() -> void:
	paused = true
	state.reset_lens()
	_update_lens_beam()
	lens_toggle = false
	touch_move = Vector2.ZERO
	held_keys.clear()
	modifiers.clear()
	music.stop()
	save_game()
	for child in modal_box.get_children():
		modal_box.remove_child(child)
		child.queue_free()
	modal.show()

func resume_game() -> void:
	paused = false
	modal.hide()

func show_pause() -> void:
	if not started: return
	_open_modal()
	_label(modal_box,"The branching wood can wait",30)
	_label(modal_box,"Your tools, healed land and open shortcuts are saved together.",17)
	_button(modal_box,"Continue walking",resume_game)
	_button(modal_box,"Level select",return_to_select)

func return_to_select() -> void:
	save_game()
	music.stop()
	get_tree().change_scene_to_file("res://start.tscn")

func show_journal() -> void:
	if not started: return
	_open_modal()
	_label(modal_box,"The branching wood",31)
	_label(modal_box,state.objective(),18)
	overview = RouteOverview.new()
	overview.game = self
	overview.name = "BranchingOverview"
	overview.custom_minimum_size = Vector2(620,440)
	overview.mouse_filter = Control.MOUSE_FILTER_IGNORE
	modal_box.add_child(overview)
	_label(modal_box,"Pale paths are open; green links are reopened shortcuts. Dim paths await restoration. Circles mark wounded land; gold diamonds mark waiting tools.",14)
	_label(modal_box,"Artemis and the returning canopy",23)
	_label(modal_box,"Restore the three wounds → find and attune the Moon Lens and Root Spool → mend both ridge crossings → receive Artemis's acorn → plant at Crown Clearing → return by the new descent and answer Artemis's song.",16)
	_label(modal_box,"Crossings reopened · %d / 6 new links" % (state.crossings_complete.size()+int(state.acorn_state=="planted")),16)
	for id: String in Layout.TARGETS:
		_label(modal_box,("Open · " if state.crossings_complete.has(id) else "Revisit · ")+str(Layout.TARGETS[id].name),15)
	_label(modal_box,"Tools and relics",23)
	for id: String in Layout.ITEMS:
		_label(modal_box,("Carrying · " if state.inventory.has(id) else "Find · ")+str(Layout.ITEMS[id].name)+". "+str(Layout.ITEMS[id].description),16)
	_label(modal_box,"Places to revisit",23)
	for id: String in Layout.SITES:
		_label(modal_box,("Restored · " if state.healed.has(id) else "Return · ")+str(Layout.SITES[id].name)+" needs "+str(Layout.ITEMS[str(Layout.SITES[id].item)].name)+". "+str(Layout.SITES[id].description),16)
	_label(modal_box,"Tools remain in your pack. Healing opens permanent shortcuts. Nothing here is consumed, and a wrong tool cannot spoil a place.",16)
	_button(modal_box,"Return to the wood",resume_game)
	_button(modal_box,"Level select",return_to_select)

func show_ending() -> void:
	_open_modal()
	_label(modal_box,"Under the young canopy" if state.artemis_finale_done else "The paths remember one another",30)
	if state.artemis_finale_done: _label(modal_box,"Artemis bows. The acorn has taken root, birds return to Crown Clearing, and the opened paths remain yours to wander.",18)
	_label(modal_box,"You carried water, living spores and young roots back to the places that needed them. The recovered land has connected the wood again.",18)
	_label(modal_box,"3 lands healed · 5 reusable tools and relics · young canopy" if state.artemis_finale_done else "3 lands healed · 3 reusable tools · permanent return paths",16)
	_button(modal_box,"Walk the reopened wood",resume_game)
	_button(modal_box,"Level select",return_to_select)

func toggle_sound() -> void:
	state.reset_lens()
	_update_lens_beam()
	lens_toggle = false
	music.muted = not music.muted
	music.stop()
	held_keys.clear()
	sound_button.text = "Sound off" if music.muted else "Sound on"

func _toast(text: String) -> void:
	if toast_label==null: return
	toast_label.text = text
	toast_label.show()
	toast_clock = 7.0
