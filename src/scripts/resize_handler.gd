extends Control

# TODO: make handles invisible when in maximized window mode



enum {RIGHT,BOTTOM,BOTTOM_RIGHT}

var resizing: bool = false
var resize_node: int

@onready var handles := {
	RIGHT : $Right,
	BOTTOM : $Bottom,
	BOTTOM_RIGHT : $BottomRight }

var tiling_window_managers: PackedStringArray = ["I3SOCK"]


func _ready() -> void:
	Globals._on_window_mode_switch.connect(_on_window_switch)
	
	# We check if people are running a tiling window manager.
	# If tiling window manager is detected, we disable resizing.
	if OS.get_name() == "Linux":
		for wm in tiling_window_managers:
			if OS.get_environment(wm) != "": 
#				queue_free()
				pass # TODO: UPDATE THIS AFTER TESTING
	
	for control in handles:
		handles[control].gui_input.connect(_on_gui_input.bind(control))
	_on_window_switch()


func _on_gui_input(event: InputEvent, id: int) -> void:
	if event is InputEventMouseButton and event.button_index == 1:
		if !resizing: resize_node = id
		resizing = event.is_pressed()


func _process(delta: float) -> void:
	if resizing:
		if resize_node == BOTTOM or resize_node == BOTTOM_RIGHT: 
			get_window().size.y = get_global_mouse_position().y
		if resize_node == RIGHT or resize_node == BOTTOM_RIGHT: 
			get_window().size.x = get_global_mouse_position().x


func _on_window_switch() -> void:
	self.visible = get_window().mode == Window.MODE_WINDOWED
