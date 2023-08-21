extends Node
## Window Manager
##
## Mainly handles the resize handles of the window.
## NOTE: Because of a Godot bug, borderless mode causes trouble!

signal _on_window_mode_switch


enum {RIGHT,BOTTOM,BOTTOM_RIGHT}


const HANDLE_SIZE := Vector2i(5,5)


var resizing: bool = false
var resize_node: Control

var handler: Control
var h_right: Control
var h_left: Control
var h_bottom: Control
var h_top: Control
var h_bottom_right: Control
var h_bottom_left: Control
var h_top_right: Control
var h_top_left: Control


func _ready() -> void:
	get_window().min_size = Vector2i(600,600)
	WindowManager._on_window_mode_switch.connect(_on_window_switch)
	
	# Setting up resize handler for resizing the main window
	await get_tree().current_scene.ready
	# Main handler setup
	handler = Control.new()
	handler.set_name("ResizeHandler")
	handler.set_mouse_filter(Control.MOUSE_FILTER_IGNORE)
	handler.set_anchors_preset(Control.PRESET_FULL_RECT)
	
	# Right handle setup
	h_right = Control.new()
	h_right.set_name("Right")
	h_right.mouse_default_cursor_shape = Control.CURSOR_HSIZE
	h_right.custom_minimum_size = HANDLE_SIZE
	h_right.position.x -= HANDLE_SIZE.x
	h_right.set_anchors_preset(Control.PRESET_RIGHT_WIDE)
	h_right.gui_input.connect(_on_gui_input.bind(h_right))
	
	# Left handle setup
	h_left = Control.new()
	h_left.set_name("Left")
	h_left.mouse_default_cursor_shape = Control.CURSOR_HSIZE
	h_left.custom_minimum_size = HANDLE_SIZE
	h_left.set_anchors_preset(Control.PRESET_LEFT_WIDE)
	h_left.gui_input.connect(_on_gui_input.bind(h_left))
	
	# Bottom handle setup
	h_bottom = Control.new()
	h_bottom.set_name("Bottom")
	h_bottom.mouse_default_cursor_shape = Control.CURSOR_VSIZE
	h_bottom.custom_minimum_size = HANDLE_SIZE
	h_bottom.position.y -= HANDLE_SIZE.y
	h_bottom.set_anchors_preset(Control.PRESET_BOTTOM_WIDE)
	h_bottom.gui_input.connect(_on_gui_input.bind(h_bottom))
	
	# Top handle setup
	h_top = Control.new()
	h_top.set_name("Top")
	h_top.mouse_default_cursor_shape = Control.CURSOR_VSIZE
	h_top.custom_minimum_size = HANDLE_SIZE
	h_top.set_anchors_preset(Control.PRESET_TOP_WIDE)
	h_top.gui_input.connect(_on_gui_input.bind(h_top))
	
	# Bottom right handle setup
	h_bottom_right = Control.new()
	h_bottom_right.set_name("BottomRight")
	h_bottom_right.mouse_default_cursor_shape = Control.CURSOR_FDIAGSIZE
	h_bottom_right.custom_minimum_size = HANDLE_SIZE
	h_bottom_right.position.x -= HANDLE_SIZE.x
	h_bottom_right.position.y -= HANDLE_SIZE.y
	h_bottom_right.set_anchors_preset(Control.PRESET_BOTTOM_RIGHT)
	h_bottom_right.gui_input.connect(_on_gui_input.bind(h_bottom_right))
	
	# Bottom left handle setup
	h_bottom_left = Control.new()
	h_bottom_left.set_name("BottomLeft")
	h_bottom_left.mouse_default_cursor_shape = Control.CURSOR_BDIAGSIZE
	h_bottom_left.custom_minimum_size = HANDLE_SIZE
	h_bottom_left.position.y -= HANDLE_SIZE.y
	h_bottom_left.set_anchors_preset(Control.PRESET_BOTTOM_LEFT)
	h_bottom_left.gui_input.connect(_on_gui_input.bind(h_bottom_left))
	
	# Top right handle setup
	h_top_right = Control.new()
	h_top_right.set_name("TopRight")
	h_top_right.mouse_default_cursor_shape = Control.CURSOR_BDIAGSIZE
	h_top_right.custom_minimum_size = HANDLE_SIZE
	h_top_right.position.x -= HANDLE_SIZE.x
	h_top_right.set_anchors_preset(Control.PRESET_TOP_RIGHT)
	h_top_right.gui_input.connect(_on_gui_input.bind(h_top_right))
	
	# Top left handle setup
	h_top_left = Control.new()
	h_top_left.set_name("TopLeft")
	h_top_left.mouse_default_cursor_shape = Control.CURSOR_FDIAGSIZE
	h_top_left.custom_minimum_size = HANDLE_SIZE
	h_top_left.set_anchors_preset(Control.PRESET_TOP_LEFT)
	h_top_left.gui_input.connect(_on_gui_input.bind(h_top_left))
	
	for handle in [h_right, h_left, h_bottom, h_top, h_bottom_right, h_bottom_left, h_top_right, h_top_left]:
		handler.add_child(handle)
	get_tree().current_scene.add_child(handler)
	_on_window_switch()


func _process(_delta: float) -> void:
	if resizing:
		var current_scene = get_tree().current_scene
		if resize_node == h_bottom or resize_node == h_bottom_right: 
			get_window().size.y = int(current_scene.get_global_mouse_position().y)
		if resize_node == h_right or resize_node == h_bottom_right: 
			get_window().size.x = int(current_scene.get_global_mouse_position().x)
		# TODO: Implement left, top, top_left, top_right, bottom_right


func _on_gui_input(event: InputEvent, node) -> void:
	if event is InputEventMouseButton and event.button_index == 1:
		if !resizing: 
			resize_node = node
		resizing = event.is_pressed()


func _on_window_switch() -> void:
	if handler != null:
		handler.visible = get_window().mode == Window.MODE_WINDOWED
