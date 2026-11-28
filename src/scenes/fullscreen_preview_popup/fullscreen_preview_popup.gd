extends Control


@export var aspect_container: AspectRatioContainer
@export var video_view_rect: TextureRect



func _ready() -> void:
	aspect_container.stretch_mode = AspectRatioContainer.STRETCH_FIT
	if EditorCore.viewport != null:
		video_view_rect.texture = EditorCore.viewport.get_texture()
	else:
		printerr("FullscreenPreview: Couldn't get viewport texture from EditorCore!")

	Project.resolution_changed.connect(_update_aspect_ratio)
	_update_aspect_ratio()


func _input(event: InputEvent) -> void:
	if event.is_action_pressed("toggle_fullscreen", false, true) or event.is_action_pressed("ui_cancel", false, true):
		_close()
		get_viewport().set_input_as_handled()
	elif event.is_action_pressed("timeline_play_pause", false, true):
		EditorCore.on_play_pressed()
		get_viewport().set_input_as_handled()
	elif event.is_action_pressed("next_frame", true, true):
		EditorCore.frame_nr = clampi(EditorCore.frame_nr + 1, 0, Project.data.timeline_end)
		get_viewport().set_input_as_handled()
	elif event.is_action_pressed("prev_frame", true, true):
		EditorCore.frame_nr = clampi(EditorCore.frame_nr - 1, 0, Project.data.timeline_end)
		get_viewport().set_input_as_handled()
	elif event.is_action_pressed("go_to_first_frame", false, true):
		EditorCore.frame_nr = 0
		Timeline.focus_on_playhead()
		get_viewport().set_input_as_handled()
	elif event.is_action_pressed("go_to_last_frame", false, true):
		EditorCore.frame_nr = Project.data.timeline_end
		Timeline.focus_on_playhead()
		get_viewport().set_input_as_handled()


func _gui_input(event: InputEvent) -> void:
	if event is InputEventMouseButton:
		var mouse_event: InputEventMouseButton = event as InputEventMouseButton
		if mouse_event.pressed and mouse_event.button_index == MouseButton.MOUSE_BUTTON_LEFT:
			_close()


func _update_aspect_ratio() -> void:
	if Project.is_loaded and Project.data.resolution.y > 0:
		aspect_container.ratio = float(Project.data.resolution.x) / float(Project.data.resolution.y)


func _close() -> void:
	PopupManager.close(PopupManager.FULLSCREEN_PREVIEW)
