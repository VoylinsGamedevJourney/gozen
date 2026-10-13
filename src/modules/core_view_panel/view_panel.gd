extends PanelContainer
# TODO: Make it possible to detach the view panel into a floating window.
# TODO: Add option to preview at lower quality (performance, needs to be done through EditorCore)

@export var project_view: TextureRect

@export var button_play: TextureButton
@export var button_pause: TextureButton
@export var button_playback_speed: Button

@export var frame_label: Label
@export var time_label: Label

@export var prefetch_waiting_screen: ColorRect



func _ready() -> void:
	frame_label.mouse_filter = Control.MOUSE_FILTER_STOP
	frame_label.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND

	frame_label.gui_input.connect(_on_label_gui_input)

	EditorCore.visual_frame_changed.connect(_on_frame_changed)
	EditorCore.play_changed.connect(_on_play_changed)
	EditorCore.is_prefetching_before_play.connect(_show_prefetch_waiting_screen)
	EditorCore.done_prefetching_before_play.connect(_hide_prefetch_waiting_screen)

	Project.framerate_changed.connect(_on_frame_changed)

	prefetch_waiting_screen.visible = false
	_on_play_changed(EditorCore.is_playing)


func _gui_input(event: InputEvent) -> void:
	if event is InputEventMouseButton: _gui_input_mouse_button(event as InputEventMouseButton)


func _gui_input_mouse_button(event: InputEventMouseButton) -> void:
	if !event.ctrl_pressed:
		return
	elif event.button_index == MOUSE_BUTTON_WHEEL_UP:
		project_view.call("_zoom_view", 1.05)
		accept_event()
	elif event.button_index == MOUSE_BUTTON_WHEEL_DOWN:
		project_view.call("_zoom_view", 1.0 / 1.05)
		accept_event()


func _on_label_gui_input(event: InputEvent) -> void:
	if event is InputEventMouseButton:
		_on_label_gui_input_mouse_button(event as InputEventMouseButton)


func _on_label_gui_input_mouse_button(event: InputEventMouseButton) -> void:
	if event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		var popup: Control = PopupManager.get_popup(PopupManager.JUMP_TO_FRAME)
		popup.call("set_data", EditorCore.frame_nr, Project.data.timeline_end)


func _on_play_changed(value: bool) -> void:
	button_play.visible = !value
	button_pause.visible = value


func _on_play_button_pressed() -> void:
	EditorCore.on_play_pressed()


func _on_pause_button_pressed() -> void:
	EditorCore.is_playing = false


func _on_skip_prev_button_pressed() -> void:
	var marker: MarkerData = MarkerLogic.get_prev(EditorCore.frame_nr)
	EditorCore.set_frame(marker.frame_nr if marker else 0)


func _on_skip_next_button_pressed() -> void:
	var marker: MarkerData = MarkerLogic.get_next(EditorCore.frame_nr)
	EditorCore.set_frame(marker.frame_nr if marker else Project.data.timeline_end)


func _on_frame_changed() -> void:
	frame_label.text = tr("Frame") + ": %s" % EditorCore.visual_frame_nr
	time_label.text = Format.time_str_from_frame(EditorCore.visual_frame_nr, Project.data.framerate, false)


func _on_playback_speed_button_pressed() -> void:
	var shift_pressed: bool = Input.is_key_pressed(KEY_SHIFT)

	match EditorCore.playback_speed:
		1.0: EditorCore.playback_speed = 4.0 if shift_pressed else 1.5
		1.5: EditorCore.playback_speed = 1.0 if shift_pressed else 2.0
		2.0: EditorCore.playback_speed = 1.5 if shift_pressed else 4.0
		4.0: EditorCore.playback_speed = 2.0 if shift_pressed else 1.0
	button_playback_speed.text = "x%s" % EditorCore.playback_speed


func _show_prefetch_waiting_screen() -> void:
	prefetch_waiting_screen.visible = true


func _hide_prefetch_waiting_screen() -> void:
	prefetch_waiting_screen.visible = false
