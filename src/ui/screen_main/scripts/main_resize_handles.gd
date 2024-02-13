extends Control

var resizing: bool = false  ## Bool to check if currently resizing.
var resize_node: Control    ## Handle used for deciding how to resize.


func _ready() -> void:
	get_window().min_size = Vector2i(700,600)
	
	$Right.gui_input.connect(_on_gui_input.bind($Right))
	$Bottom.gui_input.connect(_on_gui_input.bind($Bottom))
	$Corner.gui_input.connect(_on_gui_input.bind($Corner))


###############################################################
#region Resizing logic  #######################################
###############################################################

func _on_gui_input(event: InputEvent, node: Control):
	if event is InputEventMouseButton and event.button_index == 1:
		if !resizing:
			resize_node = node
		resizing = event.is_pressed()


func _process(_delta: float) -> void:
	if resizing:
		var current_scene = get_tree().current_scene
		if resize_node in [$Bottom, $Corner]:
			get_window().size.y = int(current_scene.get_global_mouse_position().y)
		if resize_node in [$Right, $Corner]:
			get_window().size.x = int(current_scene.get_global_mouse_position().x)

#endregion
###############################################################
