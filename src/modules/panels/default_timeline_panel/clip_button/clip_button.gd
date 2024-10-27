extends Button


var is_dragging: bool = false
var is_resizing_left: bool = false
var is_resizing_right: bool = false



func _ready() -> void:
	_on_renamed()


func _on_button_down() -> void:
	if Input.is_key_pressed(KEY_SPACE):
		return
	else:
		is_dragging = true
		get_viewport().set_input_as_handled()


func _on_button_up() -> void:
	pass


func _on_pressed() -> void:
	CoreEffects.open_clip_effects(name.to_int())

	if CoreTimeline.selected_clips.append(name.to_int()):
		printerr("Couldn't append clip id to selected clips! ", name)


func _get_drag_data(a_pos: Vector2) -> Variant:
	if is_dragging:
		modulate = Color(1, 1, 1, 0.1)
		return Draggable.new(Draggable.MOVE_CLIP, [name.to_int()], a_pos.x)
	return null


func _notification(a_notification_type: int) -> void:
	match a_notification_type:
		NOTIFICATION_DRAG_END:
			if is_dragging:
				is_dragging = false
				modulate = Color(1, 1, 1, 1)


func _on_renamed() -> void:
	var l_file: File = Project.files[Project.get_clip_file_id(name.to_int())]
	var l_label: Label = $Margin/Label

	self_modulate = l_file.get_color()
	l_label.text = l_file.nickname


