extends Control


@export var label_render_time: Label
@export var label_path: Label


var path: String



## This is basically our _ready() for the popup.
func set_data(encoding_time: int, export_path: String) -> void:
	path = export_path
	label_path.text = path
	label_path.tooltip_text = path
	label_render_time.text = Format.time_str(encoding_time / 1000.0)


func _input(event: InputEvent) -> void:
	if event.is_action_pressed("ui_cancel", false, true):
		_on_close_button_pressed()


func _gui_input(event: InputEvent) -> void:
	if event is InputEventMouseButton:
		var mouse_event: InputEventMouseButton = event as InputEventMouseButton
		if mouse_event.pressed and mouse_event.button_index == MouseButton.MOUSE_BUTTON_LEFT:
			_on_close_button_pressed()


func _on_open_video_button_pressed() -> void:
	OS.shell_open(path)


func _on_close_button_pressed() -> void:
	PopupManager.close(PopupManager.RENDER_FINISHED)
