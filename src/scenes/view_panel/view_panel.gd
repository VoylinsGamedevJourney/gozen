extends PanelContainer
# TODO: Make it possible to detach the view panel into a floating window.
# TODO: Add option to preview at lower quality (performance, needs to be done through EditorCore)
# TODO: Make frame_label and time_label into line inputs instead to quickly go to specific times.

@export var button_play: TextureButton
@export var button_pause: TextureButton

@export var frame_label: Label
@export var time_label: Label


func _ready() -> void:
	EditorCore.play_changed.connect(_on_play_changed)
	EditorCore.frame_changed.connect(_on_frame_changed)


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
	time_label.text = Utils.format_time_str_from_frame(EditorCore.frame_nr, Project.get_framerate(), false)
