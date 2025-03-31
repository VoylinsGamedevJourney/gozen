class_name AudioPlayer
extends Node


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
	stop_frame = -1
	clip_id = -1
	player.stream_paused = true


func is_playing() -> bool:
	return player.playing


func set_audio(audio_clip_id: int) -> void:
	if audio_clip_id == -1:
		return

	var data: ClipData = Project.get_clip(audio_clip_id)
	var old_file_id: int = file_id

	clip_id = audio_clip_id
	file_id = data.file_id
	stop_frame = data.end_frame

	set_effects(data)

	# Setting stream
	var position: float = float(Editor.frame_nr - data.start_frame + data.begin) / Project.get_framerate()

	if old_file_id != file_id:
		player.stream = Project.get_file_data(file_id).audio
	else:
		if abs(player.get_playback_position() - position) > 0.09:
			return

	player.play(position / Project.get_framerate())
	player.stream_paused = !Editor.is_playing


func set_effects(_data: ClipData = Project.get_clip(clip_id)) -> void:
	for i: int in AudioServer.get_bus_effect_count(bus_index):
		AudioServer.remove_bus_effect(bus_index, 0)

	# TODO: Implement audio effects
#	if _set_bus_mute(data.default_audio_effects.mute):
#		return
#	_set_volume(data.default_audio_effects.gain)


func update_effects(_data: ClipData = Project.get_clip(clip_id)) -> void:
	# TODO: Implement this, we don't need to remove/add any effects,
	# just change the value of them
	pass


func _set_bus_mute(value: bool) -> bool:
	AudioServer.set_bus_mute(bus_index, value)
	return value


func _set_volume(gain: int) -> void:
	AudioServer.set_bus_volume_db(bus_index, gain)

