extends PanelContainer


@export var project_view: TextureRect

@export var frame_label: Label
@export var time_label: Label

@export var button_play: TextureButton
@export var button_pause: TextureButton
@export var button_playback_speed: Button
@export var zoom_spinbox: SpinBox

@export var prefetch_waiting_screen: ColorRect



func _ready() -> void:
	frame_label.mouse_filter = Control.MOUSE_FILTER_STOP
	frame_label.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	frame_label.gui_input.connect(_on_frame_label_gui_input)

	time_label.mouse_filter = Control.MOUSE_FILTER_STOP
	time_label.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	time_label.gui_input.connect(_on_time_label_gui_input)

	EditorCore.visual_frame_changed.connect(_on_frame_changed)
	EditorCore.play_changed.connect(_on_play_changed)
	EditorCore.playback_speed_changed.connect(_on_playback_speed_changed)
	EditorCore.is_prefetching_before_play.connect(_show_prefetch_waiting_screen)
	EditorCore.done_prefetching_before_play.connect(_hide_prefetch_waiting_screen)

	Project.framerate_changed.connect(_on_frame_changed)

	zoom_spinbox.value_changed.connect(_on_zoom_spinbox_value_changed)
	zoom_spinbox.get_line_edit().gui_input.connect(_on_zoom_spinbox_line_edit_gui_input)
	(project_view.get("zoom_changed") as Signal).connect(_on_project_view_zoom_changed)
	_on_project_view_zoom_changed(project_view.get("view_zoom") as float)

	prefetch_waiting_screen.visible = false
	_on_play_changed(EditorCore.is_playing)


func _gui_input(event: InputEvent) -> void:
	if event is InputEventMouseButton:
		_gui_input_mouse_button(event as InputEventMouseButton)
	elif event is InputEventMagnifyGesture:
		_gui_input_magnify_gesture(event as InputEventMagnifyGesture)
	elif event is InputEventPanGesture:
		_gui_input_pan_gesture(event as InputEventPanGesture)


func _gui_input_mouse_button(event: InputEventMouseButton) -> void:
	if !event.pressed:
		return
	if event.button_index == MOUSE_BUTTON_MIDDLE:
		project_view.call("reset_zoom")
		accept_event()
		return
	if event.ctrl_pressed:
		return
	if event.button_index == MOUSE_BUTTON_WHEEL_UP:
		project_view.call("zoom_view", 1.1)
		accept_event()
	elif event.button_index == MOUSE_BUTTON_WHEEL_DOWN:
		project_view.call("zoom_view", 1.0 / 1.1)
		accept_event()


func _gui_input_magnify_gesture(event: InputEventMagnifyGesture) -> void:
	if !is_equal_approx(event.factor, 1.0):
		project_view.call("zoom_view", event.factor)
	accept_event()


func _gui_input_pan_gesture(event: InputEventPanGesture) -> void:
	if event.ctrl_pressed:
		var pan_delta: float = event.delta.y if absf(event.delta.y) >= absf(event.delta.x) else event.delta.x
		if !is_zero_approx(pan_delta):
			project_view.call("zoom_view", pow(1.1, clampf(-pan_delta, -3.0, 3.0)))
		accept_event()


#--- Bar Left ---

func _on_frame_label_gui_input(event: InputEvent) -> void:
	if event is InputEventMouseButton:
		var mouse_event: InputEventMouseButton = event as InputEventMouseButton
		if mouse_event.pressed and mouse_event.button_index == MOUSE_BUTTON_LEFT:
			var popup: Control = PopupManager.get_popup(PopupManager.JUMP_TO_FRAME)
			popup.call("set_data")


func _on_time_label_gui_input(event: InputEvent) -> void:
	if event is InputEventMouseButton:
		var mouse_event: InputEventMouseButton = event as InputEventMouseButton
		if mouse_event.pressed and mouse_event.button_index == MOUSE_BUTTON_LEFT:
			var popup: Control = PopupManager.get_popup(PopupManager.JUMP_TO_TIME)
			popup.call("set_data")


func _on_frame_changed() -> void:
	frame_label.text = tr("Frame") + ": %s" % EditorCore.visual_frame_nr
	time_label.text = Format.time_str_from_frame(EditorCore.visual_frame_nr, Project.data.framerate, false)


#--- Bar Middle ---

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


#--- Bar Right ---

func _on_playback_speed_button_pressed() -> void:
	var shift_pressed: bool = Input.is_key_pressed(KEY_SHIFT)

	match EditorCore.playback_speed:
		1.0: EditorCore.playback_speed = 4.0 if shift_pressed else 1.5
		1.5: EditorCore.playback_speed = 1.0 if shift_pressed else 2.0
		2.0: EditorCore.playback_speed = 1.5 if shift_pressed else 4.0
		4.0: EditorCore.playback_speed = 2.0 if shift_pressed else 1.0
	button_playback_speed.text = "x%s" % EditorCore.playback_speed


func _on_playback_speed_changed() -> void:
	button_playback_speed.text = "x%s" % EditorCore.playback_speed


func _on_zoom_spinbox_value_changed(zoom_percentage: float) -> void:
	if zoom_spinbox.get_line_edit().has_focus():
		zoom_spinbox.get_line_edit().release_focus()
	project_view.call("set_zoom", zoom_percentage / 100.0)


func _on_zoom_spinbox_line_edit_gui_input(event: InputEvent) -> void:
	if event is InputEventMouseButton:
		var mouse_event: InputEventMouseButton = event as InputEventMouseButton
		var request_reset: bool = mouse_event.pressed and mouse_event.double_click and mouse_event.button_index == MOUSE_BUTTON_LEFT
		if !request_reset:
			request_reset = mouse_event.pressed and mouse_event.button_index == MOUSE_BUTTON_MIDDLE

		if request_reset:
			var line_edit: LineEdit = zoom_spinbox.get_line_edit()
			project_view.call("reset_zoom")
			if line_edit.has_focus():
				line_edit.release_focus()
			line_edit.accept_event()


func _on_project_view_zoom_changed(new_zoom: float) -> void:
	zoom_spinbox.set_value_no_signal(roundf(new_zoom * 100.0))


#--- Extra's ---

func _show_prefetch_waiting_screen() -> void:
	prefetch_waiting_screen.visible = true


func _hide_prefetch_waiting_screen() -> void:
	prefetch_waiting_screen.visible = false
