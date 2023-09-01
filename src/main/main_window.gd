extends Control
## NOTE: Because of a Godot bug, borderless mode causes trouble!

signal _on_window_mode_switch


var resizing: bool = false
var resize_node: Control


func _ready() -> void:
	get_window().min_size = Vector2i(600,600)
	_on_window_mode_switch.connect(_on_window_switch)
	_on_window_switch()


func _process(_delta: float) -> void:
	if resizing:
		var current_scene = get_tree().current_scene
		if resize_node in [$Handles/Bottom, $Handles/Corner]:
			get_window().size.y = int(current_scene.get_global_mouse_position().y)
		if resize_node in [$Handles/Right, $Handles/Corner]:
			get_window().size.x = int(current_scene.get_global_mouse_position().x)


func _on_gui_input(event: InputEvent, node: NodePath) -> void:
	if event is InputEventMouseButton and event.button_index == 1:
		if !resizing: 
			resize_node = get_node(node)
		resizing = event.is_pressed()


## Disable handles when window is not in windowed mode
func _on_window_switch() -> void:
	$Handles.visible = get_window().mode == Window.MODE_WINDOWED
