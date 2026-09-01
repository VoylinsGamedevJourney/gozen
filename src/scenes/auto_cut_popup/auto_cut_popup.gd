extends Control

@export var threshold_spinbox: SpinBox
@export var min_duration_spinbox: SpinBox
@export var padding_spinbox: SpinBox
@export var apply_group_checkbox: CheckButton
@export var ripple_checkbox: CheckButton
@export var wave_preview: AutoCutWave
@export var audio_play_button: TextureButton
@export var audio_player: AudioStreamPlayer

@export var waveform_amplifier: SpinBox

var current_clip_id: int = -1
var target_file_id: int = -1
var _scrub_time: float = -1.0
var local_ranges: Array[Vector2i] = []



func _ready() -> void:
	if wave_preview.zoom_requested.connect(_on_wave_zoom_requested): Print.stack_connect()


func _on_wave_zoom_requested(new_duration: float) -> void:
	wave_preview.set("preview_duration", new_duration)
	wave_preview.queue_redraw()


func _input(event: InputEvent) -> void:
	if event.is_action_pressed("ui_cancel"):
		PopupManager.close_all()
		get_viewport().set_input_as_handled()
	elif event.is_action_pressed("timeline_play_pause"):
		if !audio_player.playing:
			_start_playback(wave_preview.get("playback_position") as float)
		else:
			_stop_playback()
		get_viewport().set_input_as_handled()


func _process(_delta: float) -> void:
	var is_playing: bool = audio_player.playing
	if _scrub_time != -1.0:
		if is_playing: _stop_playback()
		wave_preview.set("playback_position", _scrub_time)
		wave_preview.queue_redraw()
		if is_playing: _start_playback(_scrub_time)
		_scrub_time = -1.0
	is_playing = audio_player.playing
	if !is_playing: return

	var playback_position: float = audio_player.get_playback_position()

	var clip_offset_sec: float = wave_preview.get("clip_offset_sec")
	var clip_duration_sec: float = wave_preview.get("clip_duration_sec")
	var max_duration: float = clip_offset_sec + clip_duration_sec

	if playback_position >= max_duration:
		_stop_playback()
		playback_position = clip_offset_sec

	wave_preview.set("playback_position", playback_position)
	wave_preview.queue_redraw()


func load_data(id: int) -> void:
	current_clip_id = id
	var clip: ClipData = ClipLogic.clips[current_clip_id]
	var file: FileData = FileLogic.files[clip.file]

	target_file_id = file.id
	var time_offset: float = 0.0
	if clip.effects.ato_active and clip.effects.ato_file != -1:
		target_file_id = clip.effects.ato_file
		time_offset = clip.effects.ato_offset
	elif file.ato_active and file.ato_file != -1:
		target_file_id = file.ato_file
		time_offset = file.ato_offset

	wave_preview.set("file_id", target_file_id)

	var framerate: float = Project.data.framerate
	var start_sec: float = float(clip.begin) / framerate - time_offset
	var duration_sec: float = float(clip.duration * clip.speed) / framerate

	wave_preview.set("clip_offset_sec", start_sec)
	wave_preview.set("clip_duration_sec", duration_sec)
	wave_preview.set("playback_position", start_sec)

	var target_file: FileData = FileLogic.files[target_file_id]
	var stream_index: int = clip.effects.audio_stream_index
	wave_preview.set("audio_stream_index", stream_index)
	audio_player.stream = FileLogic.get_audio_stream(target_file, 0, stream_index)

	_calculate_silences()


func _calculate_silences() -> void:
	local_ranges.clear()
	var silences_sec: Array[Vector2] = []

	var wave_streams: Dictionary = FileLogic.audio_wave.get(target_file_id, {})
	var stream_index: int = ClipLogic.clips[current_clip_id].effects.audio_stream_index
	var wave_dict: Dictionary = wave_streams.get(stream_index, wave_streams.get(-1, wave_streams.values()[0] if wave_streams.size() > 0 else {}))
	if wave_dict.is_empty():
		wave_preview.set("silences", silences_sec)
		return

	var wave_data: PackedFloat32Array = wave_dict.get(1, PackedFloat32Array())
	if wave_data.is_empty():
		wave_preview.set("silences", silences_sec)
		return

	var framerate: float = Project.data.framerate
	var clip: ClipData = ClipLogic.clips[current_clip_id]

	var start_sec: float = wave_preview.get("clip_offset_sec")
	var duration_sec: float = wave_preview.get("clip_duration_sec")

	var start_frame: int = floori(start_sec * framerate)
	var end_frame: int = floori((start_sec + duration_sec) * framerate)

	start_frame = clampi(start_frame, 0, wave_data.size())
	end_frame = clampi(end_frame, 0, wave_data.size())

	var threshold_linear: float = db_to_linear(threshold_spinbox.value)
	var min_duration_frames: int = floori(min_duration_spinbox.value * framerate)
	var padding_frames: int = floori(padding_spinbox.value)

	var in_silence: bool = false
	var silence_start: int = start_frame

	var raw_silences: Array[Vector2i] = []

	for i: int in range(start_frame, end_frame):
		if wave_data[i] <= threshold_linear:
			if not in_silence:
				in_silence = true
				silence_start = i
		elif in_silence:
			in_silence = false
			if i - silence_start >= min_duration_frames:
				raw_silences.append(Vector2i(silence_start, i))

	if in_silence and end_frame - silence_start >= min_duration_frames:
		raw_silences.append(Vector2i(silence_start, end_frame))

	for silence: Vector2i in raw_silences:
		var padded_start: int = silence.x + padding_frames
		var padded_end: int = silence.y - padding_frames

		if padded_end - padded_start > 0:
			var silence_start_sec: float = float(padded_start) / framerate
			var silence_end_sec: float = float(padded_end) / framerate
			silences_sec.append(Vector2(silence_start_sec, silence_end_sec))

			var start: int = roundi(float(padded_start - start_frame) / clip.speed)
			var end: int = roundi(float(padded_end - start_frame) / clip.speed)
			local_ranges.append(Vector2i(start, end))

	wave_preview.set("silences", silences_sec)
	wave_preview.queue_redraw()


func _on_play_audio_button_pressed() -> void:
	if audio_player.playing:
		_stop_playback()
	else:
		_start_playback(wave_preview.get("playback_position") as float)


func _start_playback(start_time: float) -> void:
	var clip_offset_sec: float = wave_preview.get("clip_offset_sec")
	var clip_duration_sec: float = wave_preview.get("clip_duration_sec")
	if start_time < clip_offset_sec or start_time >= clip_offset_sec + clip_duration_sec:
		start_time = clip_offset_sec

	audio_play_button.texture_normal = load(Library.ICON_PAUSE)
	if audio_player.stream:
		audio_player.play(start_time)


func _stop_playback() -> void:
	audio_play_button.texture_normal = load(Library.ICON_PLAY)
	audio_player.stop()


func _on_wave_seek_request(playback_position: float) -> void:
	_scrub_time = playback_position


func _on_audio_wave_modifier_spin_box_value_changed(value: float) -> void:
	wave_preview.wave_modifier = int(value)


func _on_settings_changed(_value: float) -> void:
	_calculate_silences()


func _on_cancel_pressed() -> void:
	_stop_playback()
	PopupManager.close_all()


func _on_confirm_pressed() -> void:
	_stop_playback()
	var clip: ClipData = ClipLogic.clips[current_clip_id]
	ClipLogic.auto_cut_silence(clip, local_ranges, apply_group_checkbox.button_pressed, ripple_checkbox.button_pressed)
	PopupManager.close_all()
