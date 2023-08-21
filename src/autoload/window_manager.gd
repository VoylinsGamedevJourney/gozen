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
var h_bottom: Control
var h_bottom_right: Control


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
	h_right.set_mouse_default_cursor_shape(Control.CURSOR_HSIZE)
	h_right.set_custom_minimum_size(HANDLE_SIZE)
	h_right.set_anchors_preset(Control.PRESET_RIGHT_WIDE)
	h_right.gui_input.connect(_on_gui_input.bind(h_right))
	
	# Bottom handle setup
	h_bottom = Control.new()
	h_bottom.set_name("Bottom")
	h_bottom.set_mouse_default_cursor_shape(Control.CURSOR_VSIZE)
	h_bottom.set_custom_minimum_size(HANDLE_SIZE)
	h_bottom.set_anchors_preset(Control.PRESET_BOTTOM_WIDE)
	h_bottom.gui_input.connect(_on_gui_input.bind(h_bottom))
	
	# Bottom right handle setup
	h_bottom_right = Control.new()
	h_bottom_right.set_name("BottomRight")
	h_bottom_right.set_mouse_default_cursor_shape(Control.CURSOR_FDIAGSIZE)
	h_bottom_right.set_custom_minimum_size(HANDLE_SIZE)
	h_bottom_right.set_anchors_preset(Control.PRESET_BOTTOM_RIGHT)
	h_bottom_right.gui_input.connect(_on_gui_input.bind(h_bottom_right))
	
	_on_window_switch()


func _process(_delta: float) -> void:
	if resizing:
		var window_size = get_window().size
		var current_scene = get_tree().current_scene
		if resize_node == h_bottom or resize_node == h_bottom_right: 
			window_size.y = int(current_scene.get_global_mouse_position().y)
		if resize_node == h_right or resize_node == h_bottom_right: 
			window_size.x = int(current_scene.get_global_mouse_position().x)


func _on_gui_input(event: InputEvent, node) -> void:
	if event is InputEventMouseButton and event.button_index == 1:
		if !resizing: 
			resize_node = node
		resizing = event.is_pressed()


func _on_window_switch() -> void:
	if handler != null:
		handler.visible = get_window().mode == Window.MODE_WINDOWED
