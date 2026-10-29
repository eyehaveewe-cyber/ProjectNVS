extends Control
## Level journeys keep independent saves. Entering a level never resets another.
const LEVELS: Array[Dictionary] = [
	{"id":"valley","number":"01","title":"The Quiet Bloom","scene":"res://main.tscn","tag":"AN OPEN VALLEY","description":"Carry your pipes through the wounded valley and its farther woodland. Follow a squirrel, call rain, and bring the nine sanctuaries back to life.","detail":"Free wandering · Nine musical restorations · Optional discoveries"},
	{"id":"secondwood","number":"02","title":"The Returning Wood","scene":"res://secondwood.tscn","tag":"A WOOD OF WINDING WAYS","description":"Follow curling paths, find tools that heal particular wounds, and return to places you could not restore before. Mend the land to reconnect its paths.","detail":"Branching routes · Healing tools · Permanent shortcuts"}
]
var save_paths: Dictionary = {"valley":"user://journey.json","secondwood":"user://secondwood.json"}
var cards: GridContainer
var pending_new: String = ""
var new_buttons: Dictionary = {}
var status: Label

func _ready() -> void:
	var margin := MarginContainer.new()
	margin.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	for edge in ["left","right"]: margin.add_theme_constant_override("margin_"+edge,48)
	for edge in ["top","bottom"]: margin.add_theme_constant_override("margin_"+edge,30)
	add_child(margin)
	var column := VBoxContainer.new()
	column.add_theme_constant_override("separation",15)
	margin.add_child(column)
	_label(column,"PROJECT NVS",14,Color("#d5c58e"))
	_label(column,"Choose a journey",42)
	_label(column,"A faun, a set of pipes, and places waiting to live again.",18,Color("#bdcfc1"))
	var scroll := ScrollContainer.new()
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	column.add_child(scroll)
	cards = GridContainer.new()
	cards.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	cards.add_theme_constant_override("h_separation",22)
	cards.add_theme_constant_override("v_separation",18)
	scroll.add_child(cards)
	for level: Dictionary in LEVELS: _card(level)
	status = _label(column,"Each journey saves separately. Continue picks up where you left off.",15,Color("#c7d2bf"))
	_label(column,"W A S D / arrows walk · Tab raises pipes · E interacts · J opens the journal",13,Color("#a8bfae"))
	resized.connect(_layout)
	_layout()
	get_tree().auto_accept_quit = true

func _label(parent: Node, text: String, size: int, color: Color = Color("#eceddc")) -> Label:
	var label := Label.new()
	label.text = text
	label.add_theme_font_size_override("font_size",size)
	label.add_theme_color_override("font_color",color)
	label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	parent.add_child(label)
	return label

func _card(level: Dictionary) -> void:
	var panel := PanelContainer.new()
	panel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	panel.custom_minimum_size.y = 435
	var style := StyleBoxFlat.new()
	style.bg_color = Color("#193b32") if level.id=="valley" else Color("#263c3c")
	style.border_color = Color("#607e66") if level.id=="valley" else Color("#9b996b")
	style.set_border_width_all(1)
	style.set_corner_radius_all(8)
	for edge in [SIDE_LEFT,SIDE_RIGHT,SIDE_TOP,SIDE_BOTTOM]: style.set_content_margin(edge,27)
	panel.add_theme_stylebox_override("panel",style)
	cards.add_child(panel)
	var column := VBoxContainer.new()
	column.add_theme_constant_override("separation",16)
	panel.add_child(column)
	_label(column,"%s     %s" % [level.number,level.tag],13,Color("#d8c791"))
	_label(column,level.title,32)
	_label(column,level.description,19)
	_label(column,level.detail,14,Color("#b3c8b8"))
	var spacer := Control.new()
	spacer.size_flags_vertical = Control.SIZE_EXPAND_FILL
	column.add_child(spacer)
	var id: String = level.id
	var exists: bool = FileAccess.file_exists(save_paths[id]) or FileAccess.file_exists(str(save_paths[id])+".bak")
	if exists:
		var continue_button := _button(column,"Continue",func() -> void: select_level(id,true))
		continue_button.set_meta("level_id",id)
		continue_button.set_meta("resume",true)
	var begin := _button(column,"Begin this journey",func() -> void: request_new(id))
	begin.set_meta("level_id",id)
	begin.set_meta("resume",false)
	new_buttons[id] = begin
	_label(column,"Saved journey available" if exists else "Ready to begin",12,Color("#bdc8ad"))

func _button(parent: Node, text: String, action: Callable) -> Button:
	var button := Button.new()
	button.text = text
	button.custom_minimum_size.y = 42
	button.add_theme_font_size_override("font_size",17)
	button.pressed.connect(action)
	parent.add_child(button)
	return button

func request_new(id: String) -> void:
	var exists: bool = FileAccess.file_exists(save_paths[id]) or FileAccess.file_exists(str(save_paths[id])+".bak")
	if exists and pending_new!=id:
		for button: Button in new_buttons.values(): button.text = "Begin this journey"
		pending_new = id
		new_buttons[id].text = "Replace this journey? Click again"
		status.text = "Starting again replaces only this level's save. The other journey is kept."
		return
	select_level(id,false)

func select_level(id: String, resume: bool = false) -> void:
	for level: Dictionary in LEVELS:
		if level.id!=id: continue
		var scene: PackedScene = load(level.scene)
		var next: Node = scene.instantiate()
		next.save_path = save_paths[id]
		var tree := get_tree()
		var previous: Node = tree.current_scene
		tree.root.add_child(next)
		tree.current_scene = next
		if id=="valley": next.new_game(resume)
		else: next.start_level(resume)
		if previous!=null and previous!=next: previous.queue_free()
		if previous!=self: queue_free()
		return

func _layout() -> void:
	if cards==null: return
	cards.columns = 2 if size.x>=900 else 1
	queue_redraw()

func _draw() -> void:
	draw_rect(Rect2(Vector2.ZERO,size),Color("#102b28"))
	var curl := PackedVector2Array()
	for i in 160:
		var angle: float = float(i)*0.065
		var radius: float = 15.0+float(i)*3.0
		curl.append(size*Vector2(0.76,0.62)+Vector2(cos(angle),sin(angle)*0.68)*radius)
	draw_polyline(curl,Color(0.49,0.59,0.39,0.13),16,true)
