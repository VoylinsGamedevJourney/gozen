extends PanelContainer


@export var button_play: TextureButton
@export var button_pause: TextureButton


func _ready() -> void:
	Toolbox.connect_func(Editor.play_changed, _on_play_changed)


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

