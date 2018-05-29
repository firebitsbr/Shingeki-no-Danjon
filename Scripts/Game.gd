extends YSort

var leave_menu = false

var my_seed
var object_id = 0
var obj_properties = []
var object_ids = {}

var player
var map
var music

func _init():
	Res.game = self

func _ready():
	VisualServer.set_default_clear_color(Color(0.05, 0.05, 0.07))
	ProjectSettings.set_setting("rendering/environment/default_clear_color", "1a1918") ##usunąć, gdy naprawią powyższe :/
	player = $Player
	
	map = load("res://Maps/RandomMap.tscn").instance()
	add_child(map)
	map.initialize()
	
	DungeonState.emit_signal("floor_changed", DungeonState.current_floor)

func _process(delta):
	if Input.is_action_just_pressed("Menu") and !leave_menu:
		Res.ui_sample("MenuEnter")
		open_menu()
	elif Input.is_action_just_released("Menu"):
		leave_menu = false

func open_menu():
	$Player/Camera/UI.enable()
	get_tree().paused = true

func change_floor(change):
	DungeonState.visited_floors[DungeonState.current_floor] = {"seed": map.my_seed, "obj_properties": obj_properties}
	DungeonState.current_floor += change
	
	var new_map = load("res://Maps/RandomMap.tscn").instance()
	if DungeonState.visited_floors.has(DungeonState.current_floor):
		var state = DungeonState.visited_floors[DungeonState.current_floor]
		new_map.my_seed = state.seed
		obj_properties = state.obj_properties
	new_map.from = ("UP" if change > 0 else "DOWN")
	
	map.queue_free()
	map = new_map
	add_child(map)
	new_map.initialize()
	
	DungeonState.emit_signal("floor_changed", DungeonState.current_floor)

func perma_state(object, method):
	var already_saved = false
	
	for obj in obj_properties:
		if obj.id == object_id and obj.saved:
			object.call(method)
			already_saved = true
	
	if !already_saved: object_ids[object] = object_id
	object_id += 1

func save_state(object):
	obj_properties.append({"id": object_ids[object], "saved": true})

func set_music(player):
	if music: music.queue_free()
	music = player
	add_child(music)