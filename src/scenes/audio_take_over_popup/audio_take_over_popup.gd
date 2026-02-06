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
var file_b_id: int = -1


func _input(event: InputEvent) -> void:
	if event.is_action_pressed("ui_cancel"):
		PopupManager.close_popups()


func load_data(id: int, is_file: bool) -> void:
	if is_file:
		current_file_id = id
		file_a_wave.file_id = current_file_id
	else:
		current_clip_id = id
		file_a_wave.file_id = ClipHandler.get_file(current_clip_id).id

	var item_id: int = 0
	var audio_files: Dictionary[String, int] = FileHandler.get_all_audio_files()

	file_b_list.clear()
	audio_files.sort()
	for audio_file: String in audio_files:
		file_b_list.add_item(audio_file)
		file_b_list.set_item_metadata(item_id, audio_files[audio_file])
		item_id += 1

	video_file_label.text = FileHandler.get_file(current_file_id).nickname
	file_a_player.stream = FileHandler.get_file_data(current_file_id).audio


func _on_take_over_audio_button_pressed() -> void:
	if current_file_id != -1: # file
		#FileHandler.apply_audio_take_over(current_file_id, file_b_id, offset_spinbox.value)
		pass # TODO:
	else: # Clip
		#ClipHandler.apply_audio_take_over(current_clip_id, file_b_id, offset_spinbox.value)
		pass # TODO:

	PopupManager.close_popups()


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
	file_b_wave.wave_offset = value


func _on_audio_file_option_button_item_selected(index: int) -> void:
	file_b_id = file_b_list.get_item_metadata(index)
	file_b_wave.file_id = file_b_id
	file_b_player.stream = FileHandler.get_file_data(file_b_id).audio


func _on_cancel_button_pressed() -> void:
	PopupManager.close_popups()
