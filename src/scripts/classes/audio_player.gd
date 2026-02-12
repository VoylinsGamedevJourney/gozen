class_name AudioPlayer
extends RefCounted

var player: AudioStreamPlayer = AudioStreamPlayer.new()

var bus_name: String
var bus_index: int = -1

var stop_frame: int = -1
var file_id: int = -1
var clip_id: int = -1

var project_data: ProjectData = Project.data



func _init() -> void:
	AudioServer.add_bus()
	bus_index = AudioServer.bus_count - 1
	bus_name = "TrackBus_%d" % bus_index
	AudioServer.set_bus_name(bus_index, bus_name)
	player.bus = bus_name


func is_playing() -> bool:
	return player.playing


func play(value: bool) -> void:
	if stop_frame != -1 or clip_id != -1:
		player.stream_paused = !value


func stop() -> void:
	if player.playing:
		player.stop()
	player.stream_paused = true
	stop_frame = -1
	clip_id = -1


func set_audio(audio_clip_id: int) -> void:
	if audio_clip_id == -1:
		return stop()
	if RenderManager.encoder != null and RenderManager.encoder.is_open():
		return
	if !project_data.clips_id.has(audio_clip_id):
		return stop()

	var clip_index: int = Project.clips._id_map[audio_clip_id]
	var clip_effects: ClipEffects = project_data.clips_effects[clip_index]
	var clip_file_id: int = project_data.clips_file_id[clip_index]
	var clip_start: int = project_data.clips_start[clip_index]
	var clip_duration: int = project_data.clips_duration[clip_index]
	var clip_begin: int = project_data.clips_begin[clip_index]
	var clip_end: int = clip_start + clip_duration

	# Audio-take-over logic.
	var target_file_id: int = clip_file_id
	var time_offset: float = 0.0
	if clip_effects.ato_active and clip_effects.ato_id != -1:
		target_file_id = clip_effects.ato_id
		time_offset = clip_effects.ato_offset

	# Getting file data.
	if !Project.files.has(target_file_id):
		return stop()
	var file_index: int = Project.files._id_map[target_file_id]
	var file_data: Variant = Project.files.file_data[file_index]
	var stream: AudioStream = null

	if file_data is AudioStream:
		stream = file_data
	elif file_data and "audio" in file_data:
		stream = file_data.audio

	if stream == null:
		return stop() # No valid data found for stream.

	# Managing state.
	var old_file_id: int = file_id
	var old_clip_id: int = clip_id

	file_id = target_file_id
	clip_id = audio_clip_id
	stop_frame = clip_end

	# Effecs setup.
	if old_clip_id != clip_id:
		_setup_bus_effects(clip_effects.audio)
	elif AudioServer.get_bus_effect_count(bus_index) != clip_effects.audio.size():
		_setup_bus_effects(clip_effects.audio)
	update_effects(clip_index)

	# Apply fade.
	var clip_frame: int = EditorCore.frame_nr - clip_start
	var fade_volume: float = Utils.calculate_fade(clip_frame, clip_index, false)
	player.volume_db = linear_to_db(maxf(fade_volume, 0.0001)) # Just 0 can give issues.

	# Boundary check.
	var framerate: float = Project.get_framerate()
	var relative_frame_nr: float = EditorCore.frame_nr - clip_start + clip_begin
	var audio_duration: float = stream.get_length()
	var position: float = (relative_frame_nr / framerate) + time_offset
	if position < 0.0 or position >= audio_duration:
		if !player.playing:
			return
		player.stream_paused = true
		return # No seeking out of bounds.

	# Set stream if changed.
	if old_file_id != file_id or player.stream != stream:
		player.stream = stream
		player.play(position)
		player.stream_paused = !EditorCore.is_playing
		return

	# Check if playback is close enough ONLY if stream is the same.
	var frame_duration: float = 1.0 / framerate
	var sync_threshold: float = max(frame_duration * 4, 0.15) # (4 frame buffer)
	if player.playing and abs(player.get_playback_position() - position) < sync_threshold:
		player.stream_paused = !EditorCore.is_playing
		return

	player.play(position) # Play audio from the position otherwise.
	player.stream_paused = !EditorCore.is_playing


func update_effects(clip_index: int) -> void:
	if clip_id == -1 or clip_index == -1:
		return
	var effects: Array[GoZenEffectAudio] = project_data.clips_effects[clip_index].audio
	var relative_frame_nr: int = EditorCore.frame_nr - project_data.clips_start[clip_index]

	for i: int in effects.size():
		var effect: GoZenEffectAudio = effects[i]
		if i >= AudioServer.get_bus_effect_count(bus_index):
			break

		var effect_instance: AudioEffect = AudioServer.get_bus_effect(bus_index, i)
		AudioServer.set_bus_effect_enabled(bus_index, i, effect.is_enabled)
		if not effect.is_enabled:
			continue

		for effect_param: EffectParam in effect.params:
			var value: Variant = effect.get_value(effect_param, relative_frame_nr)
			effect_instance.set(effect_param.id, value)


func _setup_bus_effects(effects: Array[GoZenEffectAudio]) -> void:
	for i: int in range(AudioServer.get_bus_effect_count(bus_index) - 1, -1, -1):
		AudioServer.remove_bus_effect(bus_index, i)
	for i: int in effects.size():
		AudioServer.add_bus_effect(bus_index, effects[i].effect)
		AudioServer.set_bus_effect_enabled(bus_index, i, effects[i].is_enabled)
