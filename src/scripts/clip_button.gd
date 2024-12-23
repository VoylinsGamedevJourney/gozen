extends Button

var is_dragging: bool = false


func _ready() -> void:
	if button_down.connect(_on_button_down):
		printerr("Couldn't connect to button_down!")
	if gui_input.connect(_on_gui_input):
		printerr("Couldn't connect to gui_input!")
	

func _on_button_down() -> void:
	is_dragging = true
	get_viewport().set_input_as_handled()	


func _on_gui_input(a_event: InputEvent) -> void:
	# We need mouse passthrough to allow for clip dragging without issues
	# But when clicking on clips we do not want the playhead to keep jumping.
	# Maybe later on we can allow for clip clicking and playhead moving by
	# holding alt or something.
	if a_event is InputEventMouse:
		if !(a_event as InputEventWithModifiers).alt_pressed and a_event.is_released():
			EffectsPanel.instance.open_clip_effects(name.to_int())
			get_viewport().set_input_as_handled()
	if a_event.is_action_pressed("delete_clip"):
		Project.undo_redo.create_action("Deleting clip on timeline")
		Project.undo_redo.add_do_method(TimelineClips.instance.delete_clip.bind(
				TimelineClips.get_track_id(position.y),
				TimelineClips.get_frame_nr(position.x)))
		Project.undo_redo.add_undo_method(TimelineClips.instance.undelete_clip.bind(
				Project.get_clip_data(
						TimelineClips.get_track_id(position.y),
						TimelineClips.get_frame_nr(position.x)),
				TimelineClips.get_track_id(position.y)))
		Project.undo_redo.add_do_method(ViewPanel.instance._force_set_frame)
		Project.undo_redo.add_undo_method(ViewPanel.instance._force_set_frame)
		Project.undo_redo.commit_action()


func _get_drag_data(_pos: Vector2) -> Draggable:
	var l_draggable: Draggable = Draggable.new()
	var l_ignore: Vector2i = Vector2i(
			TimelineClips.get_track_id(position.y),
			TimelineClips.get_frame_nr(position.x))

	# Add clip id to array
	if l_draggable.ids.append(name.to_int()):
		printerr("Something went wrong appending to draggable ids!")

	l_draggable.files = false
	l_draggable.duration = Project.get_clip_data(l_ignore.x, l_ignore.y).duration
	l_draggable.mouse_offset = TimelineClips.get_frame_nr(get_local_mouse_position().x)

	l_draggable.ignore.append(l_ignore)
	l_draggable.clip_buttons.append(self)

	modulate = Color(1, 1, 1, 0.1)
	return l_draggable


func _notification(a_notification_type: int) -> void:
	match a_notification_type:
		NOTIFICATION_DRAG_END:
			if is_dragging:
				is_dragging = false
				modulate = Color(1, 1, 1, 1)

