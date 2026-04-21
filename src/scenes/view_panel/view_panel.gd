extends PanelContainer
# TODO: Make it possible to detach the view panel into a floating window.
# TODO: Add option to preview at lower quality (performance, needs to be done through EditorCore)

@export var project_view: TextureRect

@export var button_play: TextureButton
@export var button_pause: TextureButton
@export var button_playback_speed: Button

@export var frame_label: Label
@export var time_label: Label



func _ready() -> void:
	frame_label.mouse_filter = Control.MOUSE_FILTER_STOP
	frame_label.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND

	@warning_ignore_start("return_value_discarded")
	frame_label.gui_input.connect(_on_label_gui_input)

	EditorCore.play_changed.connect(_on_play_changed)
	EditorCore.visual_frame_changed.connect(_on_frame_changed)
	@warning_ignore_restore("return_value_discarded")

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
		_show_jump_to_frame_dialog()


func _show_jump_to_frame_dialog() -> void:
	var dialog: ConfirmationDialog = PopupManager.create_confirmation_dialog(tr("Jump to frame"), "")
	var spinbox: SpinBox = SpinBox.new()
	spinbox.min_value = 0
	spinbox.max_value = Project.data.timeline_end
	spinbox.value = EditorCore.frame_nr
	spinbox.allow_greater = true
	spinbox.alignment = HORIZONTAL_ALIGNMENT_CENTER
	spinbox.get_line_edit().focus_next = get_path_to(dialog.get_ok_button())

	@warning_ignore_start("return_value_discarded")
	spinbox.get_line_edit().text_submitted.connect(func(value: String) -> void:
			EditorCore.set_frame(int(value))
			dialog.queue_free())
	dialog.focus_exited.connect(dialog.queue_free)
	dialog.confirmed.connect(func() -> void: EditorCore.set_frame(int(spinbox.value)))
	@warning_ignore_restore("return_value_discarded")

	dialog.add_child(spinbox)
	dialog.popup_centered(Vector2i(200, 80))
	spinbox.get_line_edit().grab_focus()


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
	time_label.text = Utils.format_time_str_from_frame(EditorCore.visual_frame_nr, Project.data.framerate, false)


func _on_playback_speed_button_pressed() -> void:
	match EditorCore.playback_speed:
		1.0:
			EditorCore.playback_speed = 1.5
		1.5:
			EditorCore.playback_speed = 2.0
		2.0:
			EditorCore.playback_speed = 4.0
		4.0:
			EditorCore.playback_speed = 1.0
	button_playback_speed.text = "x%s" % EditorCore.playback_speed
