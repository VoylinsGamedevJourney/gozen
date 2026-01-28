class_name AudioPlayer
extends RefCounted


var player: AudioStreamPlayer = AudioStreamPlayer.new()

var bus_name: String
var bus_index: int = -1

var stop_frame: int = -1
var file_id: int = -1
var clip_id: int = -1



func _init() -> void:
	AudioServer.add_bus()
	bus_index = AudioServer.bus_count - 1
	bus_name = "TrackBus_%d" % bus_index
	AudioServer.set_bus_name(bus_index, bus_name)
	player.bus = bus_name


func play(value: bool) -> void:
	if stop_frame != -1 or clip_id != -1:
		player.stream_paused = !value


func stop() -> void:
	if player.playing:
		player.stop()

	stop_frame = -1
	clip_id = -1
	player.stream_paused = true


func is_playing() -> bool:
	return player.playing


func set_audio(audio_clip_id: int) -> void:
	if audio_clip_id == -1:
		if player.playing: player.stop()
		stop()
		return

	# No audio playback needed during rendering.
	if RenderManager.encoder != null and RenderManager.encoder.is_open(): return

	var clip_data: ClipData = ClipHandler.get_clip(audio_clip_id)
	var target_file_id: int = clip_data.file_id
	var time_offset: float = 0.0

	if clip_data.ato_active and clip_data.ato_file_id != -1:
		target_file_id = clip_data.ato_file_id
		time_offset = clip_data.ato_offset

	var old_file_id: int = file_id
	var old_clip_id: int = clip_id
	var file_data: FileData = FileHandler.get_file_data(target_file_id)
	if !file_data or !file_data.audio:
		if player.playing: player.stop()
		return

	clip_id = audio_clip_id
	file_id = target_file_id
	stop_frame = clip_data.end_frame

	if old_clip_id != clip_id: _setup_bus_effects(clip_data.effects_audio)
	elif AudioServer.get_bus_effect_count(bus_index) != clip_data.effects_audio.size():
		_setup_bus_effects(clip_data.effects_audio)

	update_effects(clip_data.effects_audio)

	# Apply fade
	var clip_frame: int = EditorCore.frame_nr - clip_data.start_frame
	var fade_volume: float = Utils.calculate_fade(clip_frame, clip_data, false)
	player.volume_db = linear_to_db(max(fade_volume, 0.0001))

	# Boundary check variables.
	var current_relative_frame: float = EditorCore.frame_nr - clip_data.start_frame + clip_data.begin
	var audio_file: File = FileHandler.get_file(target_file_id)
	var audio_duration: float = audio_file.duration / Project.get_framerate()
	var position: float = (current_relative_frame / Project.get_framerate()) + time_offset

	# Boundary check
	if position < 0.0 or position >= audio_duration:
		if !player.playing: return
		player.stream_paused = true

	# Set stream if changed.
	if old_file_id != file_id or !player.stream:
		if !file_data or !file_data.audio: return stop()
		player.stream = file_data.audio
		player.play(position)
		player.stream_paused = !EditorCore.is_playing
		return

	# Check if playback is close enough ONLY if stream is the same.
	var frame_duration: float = 1.0 / Project.get_framerate()
	if abs(player.get_playback_position() - position) < frame_duration:
		if !player.playing: return
		player.stream_paused = !EditorCore.is_playing

	player.play(position) # Play audio from the position otherwise.
	player.stream_paused = !EditorCore.is_playing


func update_effects(effects: Array[GoZenEffectAudio]) -> void:
	if clip_id == 1: return
	var clip_data: ClipData = ClipHandler.get_clip(clip_id)
	var current_relative_frame: int = EditorCore.frame_nr - clip_data.start_frame

	for i: int in effects.size():
		var effect: GoZenEffectAudio = effects[i]
		if i >= AudioServer.get_bus_effect_count(bus_index): break

		var effect_instance: AudioEffect = AudioServer.get_bus_effect(bus_index, i)
		AudioServer.set_bus_effect_enabled(bus_index, i, effect.is_enabled)
		if not effect.is_enabled: continue

		for effect_param: EffectParam in effect.params:
			var value: Variant = effect.get_value(effect_param, current_relative_frame)

			effect_instance.set(effect_param.param_id, value)


func _setup_bus_effects(effects: Array[GoZenEffectAudio]) -> void:
	for i: int in range(AudioServer.get_bus_effect_count(bus_index) - 1, -1, -1):
		AudioServer.remove_bus_effect(bus_index, i)
	for i: int in effects.size():
		AudioServer.add_bus_effect(bus_index, effects[i].audio_effect)
		AudioServer.set_bus_effect_enabled(bus_index, i, effects[i].is_enabled)
