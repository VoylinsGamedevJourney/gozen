class_name MainWindow extends Control
## Main Window
##
## The main window for GoZen, contains the place where the content
## "editor screen, command bar, startup, ..." is being displayed.
## The main window also handles the resizing and main window controls.

signal _on_window_mode_switch


## Bool to check if currently resizing.
var resizing: bool = false
## Handle used for deciding how to resize.
var resize_node: Control


func _ready() -> void:
	get_window().min_size = Vector2i(600,600)
	
	_on_window_mode_switch.connect(_on_window_switch)
	_on_window_switch()
	
	SettingsManager._on_zen_switched.connect(_on_zen_switch)
	_on_zen_switch(SettingsManager.get_zen_mode())


func _on_right_gui_input(event: InputEvent) -> void:
	if event is InputEventMouseButton:
		_gui_input_handling(event, $Handles/Right)


func _on_bottom_gui_input(event: InputEvent) -> void:
	if event is InputEventMouseButton:
		_gui_input_handling(event, $Handles/Bottom)


func _on_corner_gui_input(event: InputEvent) -> void:
	if event is InputEventMouseButton:
		_gui_input_handling(event, $Handles/Corner)


func _gui_input_handling(event: InputEvent, node: Control) -> void:
	if event.button_index == 1:
		if !resizing:
			resize_node = node
		resizing = event.is_pressed()


func _process(_delta: float) -> void:
	if resizing:
		var current_scene = get_tree().current_scene
		if resize_node in [$Handles/Bottom, $Handles/Corner]:
			get_window().size.y = int(current_scene.get_global_mouse_position().y)
		if resize_node in [$Handles/Right, $Handles/Corner]:
			get_window().size.x = int(current_scene.get_global_mouse_position().x)


## Disable handles when window is not in windowed mode.
func _on_window_switch() -> void:
	$Handles.visible = get_window().mode == Window.MODE_WINDOWED


## What needs to happen/change in zen mode
func _on_zen_switch(value: bool) -> void:
	%StatusBar.visible = !value


func add_to_content(node: Node) -> void:
	%Content.add_child(node)
