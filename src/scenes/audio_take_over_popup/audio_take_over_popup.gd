extends Control

const PREVIEW_DURATION: float = 10.0


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
	if event.is_action_pressed("timeline_play_pause"):
		var is_playing: bool = file_a_player.playing
		if !is_playing:
			_start_playback(file_a_wave.get("playback_position") as float)
		else:
			_stop_playback()
		get_viewport().set_input_as_handled()


func _process(_delta: float) -> void:
	if !file_a_player.playing:
		return

	var playback_position: float = file_a_player.get_playback_position()
	if playback_position >= PREVIEW_DURATION:
		_stop_playback()
		playback_position = 0.0

	file_a_wave.set("playback_position", playback_position)
	file_b_wave.set("playback_position", playback_position)
	file_a_wave.queue_redraw()
	file_b_wave.queue_redraw()


func load_data(id: int, is_file: bool) -> void:
	var file_a_index: int
	if is_file:
		current_file_id = id
		file_a_index = Project.files.index_map[current_file_id]
		file_a_wave.set("file_id", current_file_id)
	else:
		current_clip_id = id
		var clip_index: int = Project.clips.index_map[current_clip_id]
		var file_a: int = Project.data.clips_file[clip_index]
		file_a_index = Project.files.index_map[file_a]
		file_a_wave.set("file_id", file_a)

	var item_id: int = 1 # We start at 1 due to adding "None".
	var audio_files: PackedInt64Array = Project.files.get_all_audio_files()
	file_b_list.clear()

	# Add none option. (For deleting ATO)
	file_b_list.add_item(tr("None"))
	file_b_list.set_item_metadata(0, -1)

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
	var file_b_id: int = -1
	if file_b_index != -1:
		file_b_id = Project.data.files[file_b_index]
	if current_file_id != -1: # file
		Project.files.apply_audio_take_over(current_file_id, file_b_id, offset_spinbox.value)
	elif current_clip_id != -1: # Clip
		Project.clips.apply_audio_take_over(current_clip_id, file_b_id, offset_spinbox.value)
	PopupManager.close_all()


func _on_play_audio_button_pressed() -> void:
	if file_a_player.playing or file_b_player.playing:
		_stop_playback()
	else:
		_start_playback(file_a_wave.get("playback_position") as float)


func _on_audio_file_offset_spin_box_value_changed(value: float) -> void:
	file_b_wave.set("wave_offset", value)
	if file_a_player.playing:
		var playback_position: float = file_a_player.get_playback_position()
		_stop_playback()
		_start_playback(playback_position)


func _on_audio_file_option_button_item_selected(index: int) -> void:
	file_b_index = file_b_list.get_item_metadata(index)
	if file_b_index == -1:
		file_b_wave.set("file_id", -1)
		file_b_player.stream = null
	else:
		var file: int = Project.data.files[file_b_index]
		file_b_wave.set("file_id", file)
		file_b_player.stream = Project.files.file_data[file_b_index]


func _on_cancel_button_pressed() -> void:
	_stop_playback()
	PopupManager.close_all()


func _start_playback(start_time: float) -> void:
	audio_play_button.texture_normal = load(Library.ICON_PAUSE)
	file_a_player.play(start_time)

	if file_b_index != -1: # Start B only if valid and time is past offset.
		var offset: float = offset_spinbox.value
		var b_time: float = start_time - offset
		if b_time >= 0:
			file_b_player.play(b_time)
		else:
			file_b_player.stop()


func _stop_playback() -> void:
	audio_play_button.texture_normal = load(Library.ICON_PLAY)
	file_a_player.stop()
	file_b_player.stop()


func _on_wave_seek_request(playback_position: float) -> void:
	var is_playing: bool = file_a_player.playing or file_b_player.playing
	if is_playing:
		_stop_playback()

	file_a_wave.set("playback_position", playback_position)
	file_b_wave.set("playback_position", playback_position)
	file_a_wave.queue_redraw()
	file_b_wave.queue_redraw()

	if is_playing:
		_start_playback(playback_position)
