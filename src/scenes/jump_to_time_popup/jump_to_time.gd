extends Control


signal confirmed(new_frame: float)


@export var line_edit: LineEdit


var current_frame: int = 0
var max_frame: int = 0



## This is basically our _ready() for the popup.
func set_data(frame: int = EditorCore.frame_nr, max_frame_nr: int = Project.data.timeline_end) -> void:
	max_frame = maxi(0, max_frame_nr)
	current_frame = clampi(frame, 0, max_frame)
	line_edit.text = Format.time_str_from_frame(current_frame, Project.data.framerate, false)
	line_edit.grab_focus()
	line_edit.select_all()
	line_edit.text_submitted.connect(_on_enter_pressed.unbind(1))


func _input(event: InputEvent) -> void:
	if event.is_action_pressed("ui_cancel", false, true):
		_on_close_button_pressed()


func _gui_input(event: InputEvent) -> void:
	if event is InputEventMouseButton:
		var mouse_event: InputEventMouseButton = event as InputEventMouseButton
		if mouse_event.pressed and mouse_event.button_index == MouseButton.MOUSE_BUTTON_LEFT:
			_on_close_button_pressed()


func _on_enter_pressed() -> void:
	_on_apply_button_pressed.call_deferred()


func _on_apply_button_pressed() -> void:
	var target_frame: int = _parse_time_to_frame(line_edit.text)
	if target_frame == -1:
		line_edit.text = Format.time_str_from_frame(current_frame, Project.data.framerate, false)
		line_edit.grab_focus()
		line_edit.select_all()
		return

	confirmed.emit(float(target_frame))
	EditorCore.set_frame(target_frame)
	Timeline.focus_on_playhead()
	_on_close_button_pressed()


func _on_close_button_pressed() -> void:
	PopupManager.close(PopupManager.JUMP_TO_TIME)


func _parse_time_to_frame(time_text: String) -> int:
	var cleaned_text: String = time_text.strip_edges().replace(",", ".")
	if cleaned_text.is_empty():
		return -1

	var parts: PackedStringArray = cleaned_text.split(":", true)
	if parts.size() < 1 or parts.size() > 3:
		return -1

	for part_index: int in parts.size() - 1:
		if !parts[part_index].is_valid_int() or parts[part_index].to_int() < 0:
			return -1

	var seconds_part: String = parts[parts.size() - 1]
	if !seconds_part.is_valid_float() or seconds_part.to_float() < 0.0:
		return -1

	var total_seconds: float = 0.0
	match parts.size():
		1:
			total_seconds = parts[0].to_float()
		2:
			total_seconds = (parts[0].to_int() * 60.0) + parts[1].to_float()
		3:
			total_seconds = (parts[0].to_int() * 3600.0) + (parts[1].to_int() * 60.0) + parts[2].to_float()

	var target_frame: int = roundi(total_seconds * Project.data.framerate)
	return clampi(target_frame, 0, max_frame)
