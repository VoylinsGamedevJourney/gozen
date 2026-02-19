extends PanelContainer
# TODO: Make it possible to detach the view panel into a floating window.
# TODO: Add option to preview at lower quality (performance, needs to be done through EditorCore)

@export var button_play: TextureButton
@export var button_pause: TextureButton

@export var frame_label: Label
@export var time_label: Label



func _ready() -> void:
	EditorCore.play_changed.connect(_on_play_changed)
	EditorCore.frame_changed.connect(_on_frame_changed)

	frame_label.mouse_filter = Control.MOUSE_FILTER_STOP
	frame_label.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	frame_label.gui_input.connect(_on_label_gui_input)


func _on_label_gui_input(event: InputEvent) -> void:
	if event is not InputEventMouseButton:
		return
	var mouse_event: InputEventMouseButton = event
	if mouse_event.pressed and mouse_event.button_index == MOUSE_BUTTON_LEFT:
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
	spinbox.get_line_edit().text_submitted.connect(func(value: String) -> void:
			EditorCore.set_frame(int(value))
			dialog.queue_free())
	dialog.add_child(spinbox)
	dialog.focus_exited.connect(dialog.queue_free)
	dialog.confirmed.connect(func() -> void: EditorCore.set_frame(int(spinbox.value)))
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
	EditorCore.set_frame(maxi(0, Project.markers.get_previous(EditorCore.frame_nr)))


func _on_skip_next_button_pressed() -> void:
	EditorCore.set_frame(maxi(0, Project.markers.get_next(EditorCore.frame_nr)))


func _on_frame_changed() -> void:
	frame_label.text = tr("Frame") + ": %s" % EditorCore.frame_nr
	time_label.text = Utils.format_time_str_from_frame(EditorCore.frame_nr, Project.data.framerate, false)
