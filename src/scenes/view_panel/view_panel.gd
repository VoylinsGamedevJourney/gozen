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


func _on_skip_prev_button_pressed() -> void:
	var marker_positions: PackedInt64Array = MarkerHandler.get_marker_positions()
	var prev_marker_pos: int = -1
	var frame_nr: int = EditorCore.frame_nr

	for marker_pos: int in marker_positions:
		if marker_pos < frame_nr:
			prev_marker_pos = marker_pos
		else: break

	EditorCore.set_frame(maxi(0, prev_marker_pos))


func _on_play_button_pressed() -> void:
	EditorCore.on_play_pressed()


func _on_pause_button_pressed() -> void:
	EditorCore.is_playing = false


func _on_skip_next_button_pressed() -> void:
	var marker_positions: PackedInt64Array = MarkerHandler.get_marker_positions()
	var next_marker_pos: int = Project.get_timeline_end()
	var frame_nr: int = EditorCore.frame_nr

	for marker_pos: int in marker_positions:
		if marker_pos > frame_nr:
			next_marker_pos = marker_pos
			break

	EditorCore.set_frame(next_marker_pos)


func _on_frame_changed() -> void:
	frame_label.text = tr("text_frame") + ": %s" % EditorCore.frame_nr
	time_label.text = Utils.format_time_str_from_frame(EditorCore.frame_nr, Project.get_framerate(), false)
