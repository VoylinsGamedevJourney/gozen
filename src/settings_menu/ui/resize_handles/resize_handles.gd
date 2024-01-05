extends Control


var resizing: bool = false  ## Bool to check if currently resizing.
var resize_node: Control    ## Handle used for deciding how to resize.


###############################################################
#region Resizing logic  #######################################
###############################################################

func _gui_input_handling(event: InputEvent, node: Control) -> void:
	if event.button_index == 1:
		if !resizing:
			resize_node = node
		resizing = event.is_pressed()


func _process(_delta: float) -> void:
	if resizing:
		var current_scene = get_tree().current_scene
		if resize_node in [%Bottom, %Corner]:
			get_window().size.y = int(current_scene.get_global_mouse_position().y)
		if resize_node in [%Right, %Corner]:
			get_window().size.x = int(current_scene.get_global_mouse_position().x)


#endregion
###############################################################
#region GUI input  ############################################
###############################################################

func _on_right_gui_input(event: InputEvent) -> void:
	if event is InputEventMouseButton:
		_gui_input_handling(event, %Right)


func _on_bottom_gui_input(event: InputEvent) -> void:
	if event is InputEventMouseButton:
		_gui_input_handling(event, %Bottom)


func _on_corner_gui_input(event: InputEvent) -> void:
	if event is InputEventMouseButton:
		_gui_input_handling(event, %Corner)

#endregion
###############################################################
