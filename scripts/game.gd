extends Node3D
## Native Godot edition of Project NVS. The browser prototype remains in src/.
## The port preserves its authored valley, nine-site loop and MBean-derived pipes.
const State = preload("res://scripts/grove_state.gd")
const Valley = preload("res://scripts/valley.gd")
const Faun = preload("res://scripts/faun.gd")
const Music = preload("res://scripts/music.gd")
const Map = preload("res://scripts/minimap.gd")
const PITCHES: Array[int] = [60,62,64,67,69]
const NOTE_NAMES: Array[String] = ["Q","W","E","R","T"]
const HEART: Array[int] = [0,2,3,4,3,2,0]
const SAVE_PATH = "user://journey.json"
var state: RefCounted
var valley: Node3D
var faun: Node3D
var body: Node3D
var music: Node
var camera: Camera3D
var started: bool = false
var paused: bool = false
var playing: bool = false
var save_enabled: bool = true
var save_path: String = SAVE_PATH
var clock: float = 0.0
var save_clock: float = 0.0
var camera_yaw: float = PI+0.18
var camera_pitch: float = -0.57
var camera_distance: float = 15.0
var dragging: bool = false
var waypoint: String = ""
var heart_phrase: Array[int] = []
var walking: bool = false
var touch_move := Vector2.ZERO
var markers: Dictionary = {}
var butterflies: Array[Node3D] = []
var particles: Array[Dictionary] = []
var hud: Control
var menu: Control
var modal: Control
var modal_box: VBoxContainer
var goal_panel: PanelContainer
var music_panel: PanelContainer
var needs_panel: PanelContainer
var title: Label
var region: Label
var objective: Label
var objective_hint: Label
var progress: ProgressBar
var count_label: Label
var energy: ProgressBar
var comfort: ProgressBar
var mood: Label
var song: Label
var description: Label
var phrase: Label
var context: Label
var toast_label: Label
var toast_clock: float = 0.0
var pipe_button: Button
var listen_button: Button
var rest_button: Button
var sound_button: Button
var note_buttons: Array[Button] = []
var map: Control
var buttons_row: HBoxContainer
var move_controls: Control
var warned_restart: bool = false

func _ready() -> void:
	get_tree().auto_accept_quit = false
	valley = Valley.new()
	add_child(valley)
	state = State.new()
	state.definitions = valley.definitions
	body = Node3D.new()
	add_child(body)
	body.position = Vector3(0,Valley.height_at(0,4),4)
	faun = Faun.new()
	body.add_child(faun)
	faun.build(valley.data.faun)
	valley.data.erase("faun")
	camera = Camera3D.new()
	camera.fov = 54
	camera.far = 180
	add_child(camera)
	camera.current = true
	var environment := WorldEnvironment.new()
	var settings := Environment.new()
	settings.background_mode = Environment.BG_COLOR
	settings.background_color = Color("#97b8af")
	environment.environment = settings
	add_child(environment)
	music = Music.new()
	add_child(music)
	_make_effects()
	_build_ui()
	_show_menu()
	_update_camera(1.0)
	get_viewport().size_changed.connect(_layout_ui)

func _material(color: Color) -> StandardMaterial3D:
	var mat := StandardMaterial3D.new()
	mat.albedo_color = color
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	return mat

func _gem(color: Color, radius: float = 0.2) -> MeshInstance3D:
	var instance := MeshInstance3D.new()
	var mesh := SphereMesh.new()
	mesh.radius = radius
	mesh.height = radius*2.4
	mesh.radial_segments = 4
	mesh.rings = 2
	instance.mesh = mesh
	instance.material_override = _material(color)
	return instance

func _make_effects() -> void:
	for site in state.definitions:
		var color := Color("#ba8bd9") if site.kind=="corruption" else Color("#a8c7aa") if site.kind=="pollution" else Color("#dfad7c")
		var marker := _gem(color)
		marker.position = Vector3(float(site.x),Valley.height_at(float(site.x),float(site.z))+1.4,float(site.z))
		add_child(marker)
		markers[site.id] = marker
		for i in 2:
			var butterfly := Node3D.new()
			butterfly.set_meta("site",site)
			butterfly.set_meta("phase",float(i)*PI)
			for side in [-1,1]:
				var wing := MeshInstance3D.new()
				var mesh := BoxMesh.new()
				mesh.size = Vector3(0.2,0.015,0.12)
				wing.mesh = mesh
				wing.position.x = float(side)*0.09
				wing.material_override = _material(Color("#dbc995") if i==0 else Color("#a8d8d0"))
				butterfly.add_child(wing)
			add_child(butterfly)
			butterflies.append(butterfly)

func _physics_process(delta: float) -> void:
	if not started or paused:
		return
	clock += delta
	save_clock += delta
	if save_clock >= 5:
		save_clock = 0
		save_game()
	if state.tick(delta):
		_toast("Warmth returns. Energy and comfort restored.")
		update_hud()
		return
	var x: float = float(Input.is_physical_key_pressed(KEY_D) or Input.is_physical_key_pressed(KEY_RIGHT))-float(Input.is_physical_key_pressed(KEY_A) or Input.is_physical_key_pressed(KEY_LEFT))
	var z: float = float(Input.is_physical_key_pressed(KEY_W) or Input.is_physical_key_pressed(KEY_UP))-float(Input.is_physical_key_pressed(KEY_S) or Input.is_physical_key_pressed(KEY_DOWN))
	var movement := (Vector2(x,z)+touch_move).limit_length(1.0)
	if playing:
		movement = Vector2.ZERO
	walking = movement.length() > 0.01
	if walking:
		state.resting = 0.0
		var direction := Vector2(movement.x*cos(camera_yaw)+movement.y*sin(camera_yaw),-movement.x*sin(camera_yaw)+movement.y*cos(camera_yaw))
		var speed: float = 4.5 if Input.is_physical_key_pressed(KEY_SHIFT) else 3.2
		var nx: float = clampf(float(state.player.x)+direction.x*speed*delta,-26.2,26.2)
		var nz: float = clampf(float(state.player.z)+direction.y*speed*delta,-26.2,26.2)
		if valley.is_clear(nx,float(state.player.z)):
			state.player.x = nx
		if valley.is_clear(float(state.player.x),nz):
			state.player.z = nz
		state.player.yaw = lerp_angle(float(state.player.yaw),atan2(direction.x,direction.y),minf(1.0,delta*13.0))
		state.sequence.clear()
		state.active_site = ""
	body.position = Vector3(float(state.player.x),Valley.height_at(float(state.player.x),float(state.player.z)),float(state.player.z))
	body.rotation.y = float(state.player.yaw)
	faun.animate(delta,walking,playing,state.resting>0,clock)
	music.tick(delta)
	update_hud()

func _process(delta: float) -> void:
	_update_camera(delta)
	if paused:
		return
	for site in state.definitions:
		var marker: MeshInstance3D = markers[site.id]
		marker.visible = not state.healed.has(str(site.id))
		marker.position.y = Valley.height_at(float(site.x),float(site.z))+1.4+sin(clock*1.7+float(site.x))*0.14
		marker.rotation.y += delta*0.55
	for butterfly in butterflies:
		var site: Dictionary = butterfly.get_meta("site")
		butterfly.visible = state.healed.has(str(site.id))
		var a: float = clock*0.6+float(butterfly.get_meta("phase"))+float(site.x)
		butterfly.position = Vector3(float(site.x)+sin(a)*1.5,Valley.height_at(float(site.x),float(site.z))+1.2+sin(clock*2+a)*0.3,float(site.z)+cos(a)*1.5)
		butterfly.rotation = Vector3(sin(clock*14+a)*0.4,a,0)
	for i in range(particles.size()-1,-1,-1):
		var particle: Dictionary = particles[i]
		particle.age = float(particle.age)+delta
		particle.node.position += particle.velocity*delta
		particle.node.scale = Vector3.ONE*maxf(0.01,1-float(particle.age)/2.0)
		if float(particle.age) >= 2.0:
			particle.node.queue_free()
			particles.remove_at(i)
	if toast_clock > 0:
		toast_clock -= delta
		toast_label.visible = toast_clock>0
	if map != null:
		map.queue_redraw()

func _update_camera(delta: float) -> void:
	if camera == null:
		return
	var focus: Vector3 = body.global_position+Vector3.UP*0.9
	var offset := Vector3(-sin(camera_yaw)*cos(camera_pitch),-sin(camera_pitch),-cos(camera_yaw)*cos(camera_pitch))*camera_distance
	camera.global_position = camera.global_position.lerp(focus+offset,minf(1.0,delta*8))
	camera.look_at(focus)
	valley.material.set_shader_parameter("faun_focus",focus)

func _input(event: InputEvent) -> void:
	if event is InputEventMouseButton and not event.pressed:
		dragging = false

func _unhandled_input(event: InputEvent) -> void:
	if not started:
		return
	if event is InputEventKey and event.pressed and not event.echo:
		var key: int = event.physical_keycode if event.physical_keycode != 0 else event.keycode
		if key == KEY_ESCAPE:
			resume_game() if paused else show_pause()
			get_viewport().set_input_as_handled()
			return
		if paused:
			return
		if key == KEY_SPACE:
			set_pipes(not playing)
		elif key == KEY_J:
			show_journal()
		elif playing and key in [KEY_Q,KEY_W,KEY_E,KEY_R,KEY_T]:
			play_note([KEY_Q,KEY_W,KEY_E,KEY_R,KEY_T].find(key))
		elif key == KEY_E:
			rest()
	if paused:
		return
	if event is InputEventMouseButton and event.pressed:
		if event.button_index == MOUSE_BUTTON_WHEEL_UP:
			camera_distance = maxf(8,camera_distance-1)
		elif event.button_index == MOUSE_BUTTON_WHEEL_DOWN:
			camera_distance = minf(32,camera_distance+1)
		elif event.button_index in [MOUSE_BUTTON_LEFT,MOUSE_BUTTON_RIGHT]:
			dragging = true
	if event is InputEventMouseMotion and dragging:
		camera_yaw -= event.relative.x*0.006
		camera_pitch = clampf(camera_pitch-event.relative.y*0.003,-1.08,-0.28)

func _notification(what: int) -> void:
	if what == NOTIFICATION_WM_CLOSE_REQUEST:
		save_game()
		get_tree().quit()
	if what == NOTIFICATION_APPLICATION_FOCUS_OUT and started and not paused:
		show_pause()

func new_game(resume: bool = false) -> void:
	music.stop()
	state = State.new()
	state.definitions = valley.definitions
	if resume:
		var stored: Variant = JSON.parse_string(FileAccess.get_file_as_string(save_path)) if FileAccess.file_exists(save_path) else null
		if not stored is Dictionary and FileAccess.file_exists(save_path+".bak"):
			stored = JSON.parse_string(FileAccess.get_file_as_string(save_path+".bak"))
		state.restore(stored)
	elif not resume:
		state.player.yaw = camera_yaw+PI
	if not valley.is_clear(float(state.player.x),float(state.player.z)):
		state.player.x = 0.0
		state.player.z = 4.0
	started = true
	paused = false
	playing = false
	warned_restart = false
	waypoint = ""
	heart_phrase.clear()
	menu.hide()
	modal.hide()
	hud.show()
	valley.set_healed(state.healed)
	music.restoration = float(state.healed.size())/9.0
	set_pipes(false)
	body.position = Vector3(float(state.player.x),Valley.height_at(float(state.player.x),float(state.player.z)),float(state.player.z))
	body.rotation.y = float(state.player.yaw)
	_update_camera(1.0)
	save_game()
	_toast("Follow a pale path to a wounded place. Space raises your pipes.")

func set_pipes(value: bool) -> void:
	playing = value
	state.resting = 0
	heart_phrase.clear()
	state.sequence.clear()
	state.active_site = ""
	pipe_button.text = "Space · Lower pipes" if playing else "Space · Raise pipes"
	update_hud()

func _at_heart() -> bool:
	return state.healed.size()==9 and Vector2(float(state.player.x),float(state.player.z)).length()<4 and not state.won

func play_note(index: int) -> void:
	if not started or paused:
		return
	if not playing:
		set_pipes(true)
	music.play_note(PITCHES[index])
	note_buttons[index].modulate = Color("#efce88")
	create_tween().tween_property(note_buttons[index],"modulate",Color.WHITE,0.25)
	_burst(body.position,3)
	if _at_heart():
		if index == HEART[heart_phrase.size()]:
			heart_phrase.append(index)
		else:
			heart_phrase.clear()
			if index == HEART[0]: heart_phrase.append(index)
		if heart_phrase.size() == HEART.size():
			state.won = true
			save_game()
			_burst(Vector3(0,Valley.height_at(0,0),0),55)
			show_ending()
		update_hud()
		return
	var result: Dictionary = state.play_note(index)
	if result.type == "healed":
		valley.set_healed(state.healed)
		music.restoration = float(state.healed.size())/9.0
		var site: Dictionary = result.site
		_burst(Vector3(float(site.x),Valley.height_at(float(site.x),float(site.z)),float(site.z)),32)
		_toast(str(site.name)+" is alive again. %d of 9 sanctuaries restored." % state.healed.size())
		if state.healed.size()==9:
			_toast("All nine sanctuaries are awake. Return to the heart tree.")
		save_game()
	elif result.type == "wrong":
		_toast("Begin the phrase again. There is no hurry.")
	update_hud()

func _burst(origin: Vector3, count: int) -> void:
	for i in count:
		var node := _gem(Color("#e9d898"),0.045)
		node.position = origin+Vector3(randf_range(-0.3,0.3),0.8,randf_range(-0.3,0.3))
		add_child(node)
		particles.append({"node":node,"age":0.0,"velocity":Vector3(randf_range(-0.6,0.6),randf_range(0.4,1.1),randf_range(-0.6,0.6))})

func rest() -> void:
	if not started or paused:
		return
	if state.start_rest():
		playing = false
		pipe_button.text = "Space · Raise pipes"
		_toast("Rest beside the lantern for four seconds.")

func _target() -> Dictionary:
	var best: Dictionary = {}
	var distance: float = INF
	for site in state.definitions:
		if state.healed.has(str(site.id)):
			continue
		if str(site.id)==waypoint:
			return site
		var d: float = Vector2(float(site.x)-float(state.player.x),float(site.z)-float(state.player.z)).length()
		if d<distance:
			distance = d
			best = site
	return best

func update_hud() -> void:
	if not is_instance_valid(goal_panel) or state == null:
		return
	var site: Dictionary = state.nearest()
	var target: Dictionary = _target()
	var kind: String = str(site.get("kind",""))
	if kind.is_empty():
		if float(state.player.x)<-6 and float(state.player.z)<0:
			kind = "corruption"
		elif float(state.player.x)>7 and float(state.player.z)<3:
			kind = "pollution"
		elif float(state.player.z)>9:
			kind = "scorch"
	region.text = {"corruption":"THE HOLLOW WOOD","pollution":"THE BITTER MARSH","scorch":"THE EMBER ORCHARD"}.get(kind,"THE LANTERN CLEARING")
	objective.text = "The valley sings again" if state.won else "Return to the heart tree" if state.healed.size()==9 else "Let the land hear you" if not site.is_empty() else "Find the wounded sanctuaries"
	objective_hint.text = str(site.name)+" · Space raises your pipes" if not site.is_empty() else str(target.name)+" · follow your map" if not target.is_empty() else "Play freely in the restored valley."
	progress.value = state.healed.size()
	count_label.text = "%d / 9 sanctuaries" % state.healed.size()
	energy.value = float(state.player.energy)
	comfort.value = float(state.player.comfort)
	mood.text = state.mood()
	var expected: Array = []
	var matched: int = 0
	if _at_heart():
		song.text = "The Heart Song"
		description.text = "All the valley’s melodies return to one root."
		expected = HEART
		matched = heart_phrase.size()
	elif not site.is_empty():
		song.text = {"corruption":"Rootsong","pollution":"Clearwater Round","scorch":"Ember Lullaby"}[kind]
		description.text = site.description
		expected = site.sequence
		matched = state.sequence.size() if state.active_site==str(site.id) else 0
	else:
		song.text = "A song for the open air" if playing else "Carry a little music"
		description.text = "Find a floating light. Raise your pipes and answer its melody."
	var letters := PackedStringArray()
	for i in expected.size():
		letters.append(("✓ " if i<matched else "")+NOTE_NAMES[int(expected[i])])
	phrase.text = "  ·  ".join(letters) if not letters.is_empty() else "Five pipes. A valley to wake."
	listen_button.visible = not expected.is_empty()
	rest_button.visible = Vector2(float(state.player.x),float(state.player.z)-4.0).length()<=3
	rest_button.text = "Resting… %ds" % ceili(state.resting) if state.resting>0 else "E · Rest by the lantern"
	context.text = "Q W E R T play · Space lowers pipes" if playing else "W A S D / arrows walk · Drag to look · Wheel to zoom · J journal"

func listen() -> void:
	var notes: Array = []
	var site: Dictionary = state.nearest()
	var expected: Array = HEART if _at_heart() else site.get("sequence",[])
	for index in expected:
		notes.append(PITCHES[int(index)])
	music.melody(notes)

func save_game() -> void:
	if not started or not save_enabled:
		return
	var file := FileAccess.open(save_path+".tmp",FileAccess.WRITE)
	if file == null:
		_toast("Could not save this journey. Keep the game open to continue.")
		return
	file.store_string(JSON.stringify(state.serialize()))
	file.close()
	var absolute: String = ProjectSettings.globalize_path(save_path)
	if FileAccess.file_exists(save_path):
		if FileAccess.file_exists(save_path+".bak"):
			DirAccess.remove_absolute(absolute+".bak")
		DirAccess.rename_absolute(absolute,absolute+".bak")
	if DirAccess.rename_absolute(absolute+".tmp",absolute)!=OK:
		if FileAccess.file_exists(save_path+".bak"):
			DirAccess.rename_absolute(absolute+".bak",absolute)
		_toast("Could not complete the save. Your previous journey is preserved.")

func _panel_style() -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.06,0.18,0.14,0.95)
	style.content_margin_left = 18
	style.content_margin_right = 18
	style.content_margin_top = 10
	style.content_margin_bottom = 10
	return style

func _panel(parent: Node, at: Vector2, size: Vector2) -> PanelContainer:
	var panel := PanelContainer.new()
	panel.position = at
	panel.size = size
	panel.add_theme_stylebox_override("panel",_panel_style())
	parent.add_child(panel)
	return panel

func _label(parent: Node, text: String, font_size: int = 15, color: Color = Color("#eee8d5")) -> Label:
	var label := Label.new()
	label.text = text
	label.add_theme_font_size_override("font_size",font_size)
	label.add_theme_color_override("font_color",color)
	label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	parent.add_child(label)
	return label

func _button(parent: Node, text: String, callback: Callable) -> Button:
	var button := Button.new()
	button.text = text
	button.custom_minimum_size = Vector2(0,36)
	button.focus_mode = Control.FOCUS_NONE
	button.pressed.connect(callback)
	parent.add_child(button)
	return button

func _meter(parent: Node, caption: String, maximum: float = 1.0) -> ProgressBar:
	_label(parent,caption,12,Color("#becbad"))
	var meter := ProgressBar.new()
	meter.max_value = maximum
	meter.value = maximum
	meter.show_percentage = false
	meter.custom_minimum_size.y = 6
	parent.add_child(meter)
	return meter

func _build_ui() -> void:
	var layer := CanvasLayer.new()
	add_child(layer)
	hud = Control.new()
	hud.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	hud.mouse_filter = Control.MOUSE_FILTER_IGNORE
	layer.add_child(hud)
	title = _label(hud,"PROJECT NVS\nThe Quiet Bloom",18)
	title.position = Vector2(26,18)
	title.size = Vector2(220,55)
	goal_panel = _panel(hud,Vector2(24,90),Vector2(290,178))
	var goals := VBoxContainer.new()
	goal_panel.add_child(goals)
	region = _label(goals,"THE LANTERN CLEARING",11,Color("#d4bc7f"))
	objective = _label(goals,"Find the wounded sanctuaries",23)
	objective_hint = _label(goals,"",12)
	count_label = _label(goals,"0 / 9 sanctuaries",12)
	progress = _meter(goals,"Valley restored",9)
	needs_panel = _panel(hud,Vector2.ZERO,Vector2(175,112))
	var needs := VBoxContainer.new()
	needs_panel.add_child(needs)
	mood = _label(needs,"Happy",14)
	energy = _meter(needs,"Energy")
	comfort = _meter(needs,"Comfort")
	buttons_row = HBoxContainer.new()
	hud.add_child(buttons_row)
	_button(buttons_row,"Journal · J",show_journal)
	sound_button = _button(buttons_row,"Sound on",func() -> void:
		music.muted = not music.muted
		music.stop()
		sound_button.text = "Sound off" if music.muted else "Sound on")
	_button(buttons_row,"Pause · Esc",show_pause)
	map = Map.new()
	map.game = self
	map.mouse_filter = Control.MOUSE_FILTER_IGNORE
	hud.add_child(map)
	music_panel = _panel(hud,Vector2.ZERO,Vector2(840,174))
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation",24)
	music_panel.add_child(row)
	var info := VBoxContainer.new()
	info.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	info.custom_minimum_size.x = 400
	row.add_child(info)
	_label(info,"THE LAND IS LISTENING",10,Color("#d4bc7f"))
	song = _label(info,"Carry a little music",24)
	description = _label(info,"",12)
	phrase = _label(info,"",18,Color("#e6cc8d"))
	var instrument := VBoxContainer.new()
	instrument.custom_minimum_size.x = 280
	row.add_child(instrument)
	var keys := HBoxContainer.new()
	instrument.add_child(keys)
	for i in 5:
		var index: int = i
		var button := _button(keys,NOTE_NAMES[i]+"\n"+["C","D","E","G","A"][i],func() -> void: play_note(index))
		button.custom_minimum_size = Vector2(49,70-i*4)
		button.add_theme_color_override("font_color",Color("#f1d99d"))
		note_buttons.append(button)
	pipe_button = _button(instrument,"Space · Raise pipes",func() -> void: set_pipes(not playing))
	listen_button = _button(instrument,"♪ Hear the melody",listen)
	context = _label(hud,"",12)
	context.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	rest_button = _button(hud,"E · Rest by the lantern",rest)
	toast_label = _label(hud,"",17)
	toast_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	toast_label.add_theme_stylebox_override("normal",_panel_style())
	toast_label.hide()
	menu = Control.new()
	menu.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	layer.add_child(menu)
	var menu_panel := _panel(menu,Vector2(65,130),Vector2(410,475))
	var menu_list := VBoxContainer.new()
	menu_list.add_theme_constant_override("separation",18)
	menu_panel.add_child(menu_list)
	_label(menu_list,"PROJECT NVS · GODOT EDITION",12,Color("#d8bf7e"))
	_label(menu_list,"The Quiet Bloom",45)
	_label(menu_list,"The valley has forgotten its song.\nYou are a faun. Play it back to life.",19)
	if FileAccess.file_exists(save_path) or FileAccess.file_exists(save_path+".bak"):
		_button(menu_list,"Continue your journey",func() -> void: new_game(true))
	var begin_button := _button(menu_list,"Begin the journey",func() -> void: _confirm_new_game())
	begin_button.set_meta("new_game_button",true)
	_label(menu_list,"W A S D / arrows · Walk\nDrag · Look    Wheel · Zoom\nSpace · Raise pipes    Q W E R T · Play\nE · Rest    J · Journal    Esc · Pause",13,Color("#c4cfb5"))
	_label(menu_list,"Native Godot 4.7.2 · Press F5 in the editor",12)
	modal = Control.new()
	modal.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	layer.add_child(modal)
	var screen := ColorRect.new()
	screen.color = Color(0.02,0.07,0.05,0.8)
	screen.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	modal.add_child(screen)
	var sheet := _panel(modal,Vector2(385,90),Vector2(510,605))
	sheet.name = "Sheet"
	var scroll := ScrollContainer.new()
	sheet.add_child(scroll)
	modal_box = VBoxContainer.new()
	modal_box.custom_minimum_size.x = 465
	modal_box.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	modal_box.add_theme_constant_override("separation",12)
	scroll.add_child(modal_box)
	modal.hide()
	move_controls = Control.new()
	hud.add_child(move_controls)
	for entry in [["↑",Vector2(0,1),Vector2(40,0)],["←",Vector2(-1,0),Vector2(0,40)],["↓",Vector2(0,-1),Vector2(40,40)],["→",Vector2(1,0),Vector2(80,40)]]:
		var move: Vector2 = entry[1]
		var button := _button(move_controls,str(entry[0]),func() -> void: pass)
		button.position = entry[2]
		button.size = Vector2(38,38)
		button.button_down.connect(func() -> void:
			if playing: set_pipes(false)
			touch_move = move)
		button.button_up.connect(func() -> void: touch_move = Vector2.ZERO)
	move_controls.visible = DisplayServer.is_touchscreen_available()
	_layout_ui()

func _layout_ui() -> void:
	if hud == null:
		return
	var size: Vector2 = get_viewport().get_visible_rect().size
	music_panel.position = Vector2((size.x-840)/2,size.y-194)
	needs_panel.position = Vector2(24,size.y-326)
	buttons_row.position = Vector2(size.x-345,24)
	map.position = Vector2(size.x-194,88)
	map.size = Vector2(166,166)
	context.position = Vector2((size.x-840)/2,size.y-218)
	context.size = Vector2(840,20)
	rest_button.position = Vector2(size.x/2-112,size.y-260)
	rest_button.size = Vector2(224,36)
	toast_label.position = Vector2(size.x/2-260,80)
	toast_label.size = Vector2(520,60)
	move_controls.position = Vector2(24,size.y-420)
	if modal != null:
		modal.get_node("Sheet").position = Vector2((size.x-510)/2,maxf(25,(size.y-605)/2))

func _clear_modal() -> void:
	for child in modal_box.get_children():
		modal_box.remove_child(child)
		child.queue_free()

func _show_menu() -> void:
	hud.hide()
	menu.show()
	update_hud()

func _confirm_new_game() -> void:
	if (FileAccess.file_exists(save_path) or FileAccess.file_exists(save_path+".bak")) and not warned_restart:
		warned_restart = true
		for button in menu.find_children("*","Button",true,false):
			if button.has_meta("new_game_button"):
				button.text = "Replace saved journey? Click again"
		return
	warned_restart = false
	new_game(false)

func _open_modal() -> void:
	paused = true
	warned_restart = false
	touch_move = Vector2.ZERO
	music.stop()
	save_game()
	_clear_modal()
	modal.show()

func resume_game() -> void:
	paused = false
	modal.hide()

func show_pause() -> void:
	_open_modal()
	_label(modal_box,"The valley can wait.",31)
	_label(modal_box,"Your journey is saved as you explore.",16)
	_button(modal_box,"Return to the valley",resume_game)
	var restart := _button(modal_box,"Start a new journey",_restart_from_pause)
	restart.name = "RestartJourney"

func _restart_from_pause() -> void:
	if not warned_restart:
		warned_restart = true
		modal_box.get_node("RestartJourney").text = "Replace saved journey? Click again"
	else:
		new_game(false)

func show_journal() -> void:
	_open_modal()
	_label(modal_box,"The living valley",31)
	_label(modal_box,"Walk to a sanctuary. Listen, then play its displayed keys at your own pace.",16)
	for site in state.definitions:
		var id: String = site.id
		var restored: bool = state.healed.has(id)
		_button(modal_box,("✓ " if restored else "◇ ")+str(site.name),func() -> void:
			waypoint = id
			resume_game()
			update_hud())
	_button(modal_box,"Return to the valley",resume_game)

func show_ending() -> void:
	_open_modal()
	_label(modal_box,"A valley, singing again.",34)
	_label(modal_box,"You restored every sanctuary and returned its music to the heart. The valley is yours to wander, and the pipes are yours to play.",19)
	_label(modal_box,"9 sanctuaries · %d minutes" % maxi(1,roundi(state.elapsed/60.0)),16)
	_button(modal_box,"Stay a little longer",resume_game)

func _toast(text: String) -> void:
	if toast_label == null:
		return
	toast_label.text = text
	toast_label.show()
	toast_clock = 5.0
