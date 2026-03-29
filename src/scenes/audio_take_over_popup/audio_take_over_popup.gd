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
var file_b_id: int = -1

var _scrub_time: float = -1.0



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
	if _scrub_time != -1.0:
		var is_playing: bool = file_a_player.playing or file_b_player.playing
		if is_playing:
			_stop_playback()

		file_a_wave.set("playback_position", _scrub_time)
		file_b_wave.set("playback_position", _scrub_time)
		file_a_wave.queue_redraw()
		file_b_wave.queue_redraw()

		if is_playing:
			_start_playback(_scrub_time)
		_scrub_time = -1.0

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
	var file_a: FileData
	if is_file:
		current_file_id = id
		file_a = FileLogic.files[current_file_id]
		file_a_wave.set("file_id", current_file_id)
	else:
		current_clip_id = id
		var clip: ClipData = ClipLogic.clips[current_clip_id]
		file_a = FileLogic.files[clip.file]
		file_a_wave.set("file_id", file_a.id)

	var item_id: int = 1 # We start at 1 due to adding "None".
	var audio_files: Array[FileData] = FileLogic.get_all_audio_files()
	file_b_list.clear()

	# Add none option. (For deleting ATO)
	file_b_list.add_item(tr("None"))
	file_b_list.set_item_metadata(0, -1)

	for audio_file: FileData in audio_files:
		if audio_file.id == file_a.id:
			continue
		file_b_list.add_item(audio_file.nickname)
		file_b_list.set_item_metadata(item_id, audio_file.id)
		item_id += 1

	var video: Video = FileLogic.file_data.get(file_a.id)
	video_file_label.text = file_a.nickname
	if video:
		file_a_player.stream = video.get_audio()


func _on_take_over_audio_button_pressed() -> void:
	var file_b: FileData = FileLogic.files.get(file_b_id)
	if file_b == null:
		file_b = FileData.new()
		file_b.id = -1

	if current_file_id != -1: # file
		var file_a: FileData = FileLogic.files.get(current_file_id)
		if file_a:
			FileLogic.apply_audio_take_over(file_a, file_b, offset_spinbox.value)
	elif current_clip_id != -1: # Clip
		var clip: ClipData = ClipLogic.clips.get(current_clip_id)
		if clip:
			ClipLogic.apply_audio_take_over(clip, file_b_id, offset_spinbox.value)
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
	file_b_id = file_b_list.get_item_metadata(index)
	if file_b_id == -1:
		file_b_wave.set("file_id", -1)
		file_b_player.stream = null
	else:
		file_b_wave.set("file_id", file_b_id)
		var file_b: FileData = FileLogic.files[file_b_id]
		file_b_player.stream = FileLogic.get_audio_stream(file_b, 0)


func _on_cancel_button_pressed() -> void:
	_stop_playback()
	PopupManager.close_all()


func _start_playback(start_time: float) -> void:
	audio_play_button.texture_normal = load(Library.ICON_PAUSE)
	file_a_player.play(start_time)

	if file_b_id != -1: # Start B only if valid and time is past offset.
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
	_scrub_time = playback_position
