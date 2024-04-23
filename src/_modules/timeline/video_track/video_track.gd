extends Panel


var timeline_node: Control
var track_id: int
var panel: Panel


func _ready() -> void:
	Printer.connect_error(mouse_exited.connect(_mouse_exited))
	Printer.connect_error(mouse_entered.connect(_mouse_entered))
	panel = timeline_node.preview_panel.duplicate()


func _mouse_exited() -> void:
	if get_viewport().gui_is_dragging():
		remove_child(panel)


func _mouse_entered() -> void:
	if !panel.is_inside_tree() and get_viewport().gui_is_dragging():
		var l_data: Dictionary = get_viewport().gui_get_drag_data()
		if l_data.file_type == File.TYPE.AUDIO:
			return
		panel.size = Vector2(l_data.duration * timeline_node.frame_size, size.y)
		add_child(panel)


func _can_drop_data(a_at_position: Vector2, a_data: Variant) -> bool:
	# check if space available at location
	panel.position.x = a_at_position.x
	return true


func _drop_data(_at_position: Vector2, a_data: Variant) -> void:
	remove_child(panel)
	print(a_data)
