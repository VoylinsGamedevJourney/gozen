class_name AudioPlayer
extends RefCounted


var player: AudioStreamPlayer = AudioStreamPlayer.new()
var bus_index: int = -1

var stop_frame: int = -1
var file_id: int = -1
var clip_id: int = -1



func _init() -> void:
	AudioServer.add_bus()
	bus_index = AudioServer.bus_count - 1
	player.bus = AudioServer.get_bus_name(bus_index)


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
		if player.playing:
			player.stop()
		stop()
		return

	# No audio playback needed during rendering.
	if RenderManager.encoder != null and RenderManager.encoder.is_open():
		return

	var data: ClipData = ClipHandler.get_clip(audio_clip_id)
	var old_file_id: int = file_id
	var old_clip_id: int = clip_id

	if FileHandler.get_file_data(data.file_id).audio == null:
		return

	clip_id = audio_clip_id
	file_id = data.file_id
	stop_frame = data.end_frame

	if old_clip_id != clip_id or AudioServer.get_bus_effect_count(bus_index) != data.effects_sound.size():
		_setup_bus_effects(data.effects_sound)
	
	update_effects(data.effects_sound)

	# Getting timings in seconds.
	var position: float = float(EditorCore.frame_nr - data.start_frame + data.begin)
	position /= Project.get_framerate()

	# Set stream if changed.
	if old_file_id != file_id or !player.stream:
		var file_data: FileData = FileHandler.get_file_data(file_id)
		#_setup_bus_effects(data.effects_sound)

		if file_data and file_data.audio:
			player.stream = file_data.audio
			player.play(position)
			player.stream_paused = !EditorCore.is_playing
			#update_effects(data.effects_sound)
			return
		return stop()

	# Check if playback is close enough ONLY if stream is the same.
	var frame_duration: float = 1.0 / Project.get_framerate()
	if abs(player.get_playback_position() - position) < frame_duration:
		if player.playing:
			player.stream_paused = !EditorCore.is_playing
		return

	# Play audio from the position otherwise.
	player.play(position)
	player.stream_paused = !EditorCore.is_playing


func update_effects(effects: Array[SoundEffect]) -> void:
	return
#	var start_frame: int = ClipHandler.get_start_frame(clip_id)
#	var begin_frame: int = ClipHandler.get_clip(clip_id).begin
#	var current_frame: int = EditorCore.frame_nr - start_frame + begin_frame
#
#	for i: int in effects.size():
#		var effect: SoundEffect = effects[i]
#		var effect_instance: AudioEffect = AudioServer.get_bus_effect(bus_index, i)
#
#		for param: EffectParam in effect.params:
#			var value: Variant = effect.get_param_value(param.param_id, current_frame)
#
#			effect_instance.set(param.param_id, value)


func _setup_bus_effects(effects: Array[SoundEffect]) -> void:
	var effect_count: int = AudioServer.get_bus_effect_count(bus_index)

	# Cleaning all previous effects
	for i: int in range(effect_count - 1, -1, -1):
		AudioServer.remove_bus_effect(bus_index, i)

	# Creating all effects
	for i: int in effects.size():
		var effect: SoundEffect = effects[i]

		AudioServer.add_bus_effect(bus_index, effect.base_effect)
		AudioServer.set_bus_effect_enabled(bus_index, i, effect.enabled)
