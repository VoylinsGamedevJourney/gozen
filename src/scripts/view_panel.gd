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
	var marker_positions: PackedInt64Array = Project.get_marker_positions()
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
	var marker_positions: PackedInt64Array = Project.get_marker_positions()
	var next_marker_pos: int = Project.get_timeline_end()
	var frame_nr: int = EditorCore.frame_nr

	marker_positions.sort()

	for marker_pos: int in marker_positions:
		if marker_pos > frame_nr:
			next_marker_pos = marker_pos
			break
	
	EditorCore.set_frame(mini(0, next_marker_pos))


func _on_frame_changed(frame_nr: int) -> void:
	frame_label.text = tr("TEXT_FRAME") + ": " + str(frame_nr)
	time_label.text = Toolbox.format_time_str_from_frame(frame_nr)
	
