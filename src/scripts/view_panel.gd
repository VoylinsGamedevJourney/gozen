extends PanelContainer


@export var button_play: TextureButton
@export var button_pause: TextureButton

@export var frame_label: Label
@export var time_label: Label



func _ready() -> void:
	Toolbox.connect_func(EditorCore.play_changed, _on_play_changed)
	Toolbox.connect_func(EditorCore.frame_changed, _on_frame_changed)


func _on_play_changed(value: bool) -> void:
	button_play.visible = !value
	button_pause.visible = value


func _on_skip_prev_button_pressed() -> void:
	# TODO: Make this go to the previous marker!
	pass # Replace with function body.


func _on_play_button_pressed() -> void:
	EditorCore.on_play_pressed()


func _on_pause_button_pressed() -> void:
	EditorCore.is_playing = false


func _on_skip_next_button_pressed() -> void:
	# TODO: Make this go to the next marker!
	pass # Replace with function body.


func _on_frame_changed(frame_nr: int) -> void:
	frame_label.text = tr("Frame") + ": " + str(frame_nr)
	time_label.text = Toolbox.format_time_str_from_frame(frame_nr)
	
