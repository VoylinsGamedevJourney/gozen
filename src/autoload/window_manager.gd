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
	# Changing size here so when working on modules/ui we have a 1080p
	# view of how everything would look.
	get_window().min_size = Vector2i(600,600)
#	get_window().size = Vector2i(1152, 648)
	
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
	
	# Bottom handle setup
	h_bottom = Control.new()
	h_bottom.set_name("Bottom")
	h_bottom.mouse_default_cursor_shape = Control.CURSOR_VSIZE
	h_bottom.custom_minimum_size = HANDLE_SIZE
	h_bottom.position.y -= HANDLE_SIZE.y
	h_bottom.set_anchors_preset(Control.PRESET_BOTTOM_WIDE)
	h_bottom.gui_input.connect(_on_gui_input.bind(h_bottom))
	
	# Bottom right handle setup
	h_bottom_right = Control.new()
	h_bottom_right.set_name("BottomRight")
	h_bottom_right.mouse_default_cursor_shape = Control.CURSOR_FDIAGSIZE
	h_bottom_right.custom_minimum_size = HANDLE_SIZE
	h_bottom_right.position.x -= HANDLE_SIZE.x
	h_bottom_right.position.y -= HANDLE_SIZE.y
	h_bottom_right.set_anchors_preset(Control.PRESET_BOTTOM_RIGHT)
	h_bottom_right.gui_input.connect(_on_gui_input.bind(h_bottom_right))
	
	for handle in [h_right, h_bottom, h_bottom_right]:
		handler.add_child(handle)
	get_tree().current_scene.add_child(handler)
	_on_window_switch()


func _process(_delta: float) -> void:
	if resizing:
		var current_scene = get_tree().current_scene
		if resize_node in [h_bottom, h_bottom_right]: 
			get_window().size.y = int(current_scene.get_global_mouse_position().y)
		if resize_node in [h_right, h_bottom_right]: 
			get_window().size.x = int(current_scene.get_global_mouse_position().x)


func _on_gui_input(event: InputEvent, node) -> void:
	if event is InputEventMouseButton and event.button_index == 1:
		if !resizing: 
			resize_node = node
		resizing = event.is_pressed()


func _on_window_switch() -> void:
	if handler != null:
		handler.visible = get_window().mode == Window.MODE_WINDOWED
