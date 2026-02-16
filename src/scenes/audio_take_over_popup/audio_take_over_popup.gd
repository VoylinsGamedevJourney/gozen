extends Control
# TODO: When this is done for a file with existing clips attached, we should
# show a different popup which asks if we want to update the existing clips too.
# TODO: We should show where in the audio wave where the playback is.

@export var video_file_label: Label
@export var audio_play_button: TextureButton
@export var offset_spinbox: SpinBox
@export var file_b_list: OptionButton

@export var file_a_wave: ColorRect
@export var file_b_wave: ColorRect

@export var file_a_player: AudioStreamPlayer
@export var file_b_player: AudioStreamPlayer


var current_file_id: int = -1
var current_clip_id: int = -1
var file_b_index: int = -1


func _input(event: InputEvent) -> void:
	if event.is_action_pressed("ui_cancel"):
		PopupManager.close_all()


func load_data(id: int, is_file: bool) -> void:
	var file_a_index: int
	if is_file:
		current_file_id = id
		file_a_index = Project.files.index_map[current_file_id]
		file_a_wave.set("file_id", current_file_id)
	else:
		current_clip_id = id
		var clip_index: int = Project.clips.index_map[current_clip_id]
		file_a_index = Project.data.clips_file[clip_index]
		file_a_wave.set("file_id", Project.files.index_map[file_a_index])

	var item_id: int = 0
	var audio_files: PackedInt64Array = Project.files.get_all_audio_files()

	file_b_list.clear()
	audio_files.sort()
	for audio_file: int in audio_files:
		var file_index: int = Project.files.index_map[audio_file]
		if file_index == file_a_index:
			continue
		file_b_list.add_item(Project.data.files_nickname[file_index])
		file_b_list.set_item_metadata(item_id, file_index)
		item_id += 1

	var video: GoZenVideo = Project.files.file_data[file_a_index]
	video_file_label.text = Project.data.files_nickname[file_a_index]
	file_a_player.stream = video.get_audio()


func _on_take_over_audio_button_pressed() -> void:
	var file_b_id: int = Project.data.files[file_b_index]
	if current_file_id != -1: # file
		Project.files.apply_audio_take_over(current_file_id, file_b_id, offset_spinbox.value)
	elif current_clip_id != -1: # Clip
		Project.clips.apply_audio_take_over(current_clip_id, file_b_id, offset_spinbox.value)
	PopupManager.close_all()


func _on_play_audio_button_pressed() -> void:
	# TODO: Let the user decide the start position for playback
	if file_a_player.playing:
		audio_play_button.texture_normal = load(Library.ICON_PLAY)
		file_a_player.stop()
		file_b_player.stop()
	else:
		audio_play_button.texture_normal = load(Library.ICON_PAUSE)
		file_a_player.play(0)
		file_b_player.play(0)


func _on_audio_file_offset_spin_box_value_changed(value: float) -> void:
	file_b_wave.set("wave_offset", value)


func _on_audio_file_option_button_item_selected(index: int) -> void:
	file_b_index = file_b_list.get_item_metadata(index)
	file_b_wave.set("file_id", file_b_index)
	file_b_player.stream = Project.files.file_data[file_b_index]


func _on_cancel_button_pressed() -> void:
	PopupManager.close_all()
