class_name AudioPlayer
extends RefCounted

var player: AudioStreamPlayer

var bus_name: String
var bus_index: int = -1

var stop_frame: int = -1
var file: int = -1
var clip: int = -1

var project_data: ProjectData



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
	if stop_frame != -1 or clip != -1:
		player.stream_paused = !value


func stop() -> void:
	if player.playing:
		player.stop()
	player.stream_paused = true
	stop_frame = -1
	clip = -1


func set_audio(audio_clip: int, instance_index: int = 0) -> void:
	if audio_clip == -1:
		return stop()
	if RenderManager.encoder != null and RenderManager.encoder.is_open():
		return stop()
	if !project_data.clips.has(audio_clip):
		return stop()

	var clip_index: int = Project.clips.index_map[audio_clip]
	var clip_effects: ClipEffects = project_data.clips_effects[clip_index]
	var clip_speed: float = project_data.clips_speed[clip_index]
	var clip_file: int = project_data.clips_file[clip_index]
	var clip_start: int = project_data.clips_start[clip_index]
	var clip_duration: int = project_data.clips_duration[clip_index]
	var clip_begin: int = project_data.clips_begin[clip_index]
	var clip_end: int = clip_start + clip_duration

	# Audio-take-over logic.
	var target_file: int = clip_file
	var time_offset: float = 0.0
	if clip_effects.ato_active and clip_effects.ato_id != -1:
		target_file = clip_effects.ato_id
		time_offset = clip_effects.ato_offset
	elif project_data.files_ato_active.get(clip_file, false):
		var file_ato_id: int = project_data.files_ato_file.get(clip_file, -1)
		if file_ato_id != -1:
			target_file = file_ato_id
			time_offset = project_data.files_ato_offset.get(clip_file, 0.0)

	# Getting file data.
	if !Project.files.index_map.has(target_file):
		return stop()
	var stream: AudioStream = Project.files.get_audio_stream(target_file, instance_index)
	if stream == null:
		return stop() # No valid data found for stream.

	# Managing state.
	var old_file: int = file
	var old_clip: int = clip
	file = target_file
	clip = audio_clip
	stop_frame = clip_end

	# Effecs setup.
	if old_clip != clip:
		_setup_bus_effects(clip_effects.audio)
	elif AudioServer.get_bus_effect_count(bus_index) != clip_effects.audio.size():
		_setup_bus_effects(clip_effects.audio)
	update_effects(clip_index)
	player.pitch_scale = clip_speed * EditorCore.playback_speed

	# Boundary check.
	var framerate: float = project_data.framerate
	var audio_duration: float = stream.get_length()
	var time_from_start: float = float(EditorCore.frame_nr - clip_start) / framerate
	var position: float = (time_from_start * clip_speed) + (float(clip_begin) / framerate) + time_offset
	if position < 0.0 or position >= audio_duration:
		if !player.playing:
			return
		player.stream_paused = true
		return # No seeking out of bounds.

	# Set stream if changed.
	if old_file != file or player.stream != stream:
		player.stream = stream
		player.play(position)
		player.stream_paused = !EditorCore.is_playing
		return

	# Check if playback is close enough ONLY if stream is the same.
	var frame_duration: float = 1.0 / framerate
	var sync_threshold: float = max(frame_duration * 4 * clip_speed, 0.15) # (4 frame buffer at normal speed)
	if player.playing and abs(player.get_playback_position() - position) < sync_threshold:
		player.stream_paused = !EditorCore.is_playing
		return

	player.play(position) # Play audio from the position otherwise.
	player.stream_paused = !EditorCore.is_playing


func update_effects(clip_index: int) -> void:
	var effects: Array[EffectAudio] = project_data.clips_effects[clip_index].audio
	var relative_frame_nr: int = EditorCore.frame_nr - project_data.clips_start[clip_index]

	# Apply fade.
	var fade_volume: float = Utils.calculate_fade(relative_frame_nr, clip_index, false)
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
		AudioServer.add_bus_effect(bus_index, effects[i].effect)
		AudioServer.set_bus_effect_enabled(bus_index, i, effects[i].is_enabled)
