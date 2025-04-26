extends PanelContainer


@export var button_play: TextureButton
@export var button_pause: TextureButton

@export var frame_label: Label
@export var time_label: Label



func _ready() -> void:
	Toolbox.connect_func(Editor.play_changed, _on_play_changed)
	Toolbox.connect_func(Editor.frame_changed, _on_frame_changed)


func _on_play_changed(value: bool) -> void:
	button_play.visible = !value
	button_pause.visible = value


func _on_skip_prev_button_pressed() -> void:
	# TODO: Make this go to the previous marker!
	pass # Replace with function body.


func _on_play_button_pressed() -> void:
	Editor.on_play_pressed()


func _on_pause_button_pressed() -> void:
	Editor.is_playing = false


func _on_skip_next_button_pressed() -> void:
	# TODO: Make this go to the next marker!
	pass # Replace with function body.


func _on_frame_changed(frame_nr: int) -> void:
	var total_seconds_float: float = float(frame_nr) / Project.get_framerate()
	var total_seconds: int = floor(total_seconds_float)

	var hours: int = int(float(total_seconds) / 3600)
	var remaining_seconds: int = total_seconds % 3600
	var minutes: int = int(float(remaining_seconds) / 60)
	var seconds: int = total_seconds % 60
	var micro: int = int(float(total_seconds_float - total_seconds) * 100)

	frame_label.text = tr("Frame") + ": " + str(frame_nr)
	time_label.text = "%02d:%02d:%02d.%02d" % [hours, minutes, seconds, micro]
	
