class_name AudioPlayer
extends RefCounted

var player: AudioStreamPlayer

var bus_name: String
var bus_index: int = -1

var stop_frame: int = -1
var file: FileData = null
var clip: ClipData = null

var project_data: ProjectData

var _last_seek_time: int = 0



func _init() -> void:
	player = AudioStreamPlayer.new()
	project_data = Project.data
	AudioServer.add_bus()
	bus_index = AudioServer.bus_count - 1
	bus_name = "TrackBus_%d" % bus_index
	AudioServer.set_bus_name(bus_index, bus_name)
	player.bus = bus_name


func is_playing() -> bool:
	return player.playing


func play(value: bool) -> void:
	if stop_frame != -1 or clip:
		player.stream_paused = !value


func stop() -> void:
	if player.playing:
		player.stop()
	player.stream_paused = true
	stop_frame = -1
	clip = null


func set_audio(audio_clip: ClipData, instance_index: int = 0) -> void:
	if !audio_clip or TrackLogic.tracks[audio_clip.track].is_muted:
		return stop()
	elif RenderManager.encoder != null and RenderManager.encoder.is_open():
		return stop()
	elif !ClipLogic.clips.has(audio_clip.id):
		return stop()

	# Audio-take-over logic.
	var target_file: FileData = FileLogic.files[audio_clip.file]
	var time_offset: float = 0.0
	if audio_clip.effects.ato_active and audio_clip.effects.ato_file != -1:
		target_file = FileLogic.files[audio_clip.effects.ato_file]
		time_offset = audio_clip.effects.ato_offset
	elif target_file.ato_active:
		if target_file.ato_file != -1:
			time_offset = target_file.ato_offset
			target_file = FileLogic.files[target_file.ato_file]

	# Getting file_id data.
	if !FileLogic.files.has(target_file.id):
		return stop()
	var stream: AudioStream = FileLogic.get_audio_stream(target_file, instance_index)
	if stream == null:
		return stop() # No valid data found for stream.

	# Managing state.
	var old_file: FileData = file
	var old_clip: ClipData = clip
	file = target_file
	clip = audio_clip
	stop_frame = clip.end

	var contiguous: bool = false
	if old_file == file and old_clip != null and old_clip.end == clip.start:
		var expected_begin: int = old_clip.begin + int(old_clip.duration * old_clip.speed)
		if expected_begin == clip.begin:
			contiguous = true

	# Effects setup.
	var need_rebuild: bool = false
	if AudioServer.get_bus_effect_count(bus_index) != clip.effects.audio.size():
		need_rebuild = true
	else:
		for i: int in clip.effects.audio.size():
			var current_effect: AudioEffect = AudioServer.get_bus_effect(bus_index, i)
			var target_effect: AudioEffect = clip.effects.audio[i].effect
			if current_effect.get_class() != target_effect.get_class():
				need_rebuild = true
				break

	if need_rebuild:
		_setup_bus_effects(clip.effects.audio)
	update_effects()
	player.pitch_scale = clip.speed * EditorCore.playback_speed

	# Boundary check.
	var framerate: float = project_data.framerate
	var audio_duration: float = stream.get_length()
	var time_from_start: float = float(EditorCore.frame_nr - clip.start) / framerate
	var position: float = (time_from_start * clip.speed) + (float(clip.begin) / framerate) - time_offset
	if position < 0.0 or position >= audio_duration:
		if !player.playing:
			return
		player.stream_paused = true
		return # No seeking out of bounds.

	# Set stream if changed.
	if old_file != file or player.stream != stream:
		player.stream = stream
		player.play(position)
		_last_seek_time = Time.get_ticks_msec()
		player.stream_paused = !EditorCore.is_playing
		return

	if Time.get_ticks_msec() - _last_seek_time < 150:
		player.stream_paused = !EditorCore.is_playing
		return

	var frame_duration: float = 1.0 / framerate
	var sync_threshold: float = max(frame_duration * 2 * clip.speed, 0.15)
	if player.playing and (contiguous or abs(player.get_playback_position() - position) < sync_threshold):
		player.stream_paused = !EditorCore.is_playing
		return

	player.play(position)
	_last_seek_time = Time.get_ticks_msec()
	player.stream_paused = !EditorCore.is_playing


func update_effects() -> void:
	var effects: Array[EffectAudio] = clip.effects.audio
	var relative_frame_nr: int = EditorCore.frame_nr - clip.start

	# Apply fade.
	var fade_volume: float = Utils.calculate_fade(relative_frame_nr, clip, false)
	player.volume_db = linear_to_db(maxf(fade_volume, 0.0001)) # Just 0 can give issues.

	# Apply other effects.
	for i: int in effects.size():
		var effect: EffectAudio = effects[i]
		if i >= AudioServer.get_bus_effect_count(bus_index):
			break

		var effect_instance: AudioEffect = AudioServer.get_bus_effect(bus_index, i)
		AudioServer.set_bus_effect_enabled(bus_index, i, effect.is_enabled)
		if not effect.is_enabled:
			continue

		for effect_param: EffectParam in effect.params:
			var value: Variant = effect.get_value(effect_param, relative_frame_nr)
			effect_instance.set(effect_param.id, value)


func _setup_bus_effects(effects: Array[EffectAudio]) -> void:
	for i: int in range(AudioServer.get_bus_effect_count(bus_index) - 1, -1, -1):
		AudioServer.remove_bus_effect(bus_index, i)
	for i: int in effects.size():
		AudioServer.add_bus_effect(bus_index, effects[i].effect.duplicate() as AudioEffect)
		AudioServer.set_bus_effect_enabled(bus_index, i, effects[i].is_enabled)
