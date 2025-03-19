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


func play(a_value: bool) -> void:
	if stop_frame != -1 or clip_id != -1:
		player.stream_paused = !a_value

	
func stop() -> void:
	stop_frame = -1
	clip_id = -1
	player.stream_paused = true


func is_playing() -> bool:
	return player.playing


func set_audio(a_clip_id: int) -> void:
	if a_clip_id == -1:
		return

	var l_data: ClipData = Project.get_clip(a_clip_id)
	var l_old_file_id: int = file_id

	clip_id = a_clip_id
	file_id = l_data.file_id
	stop_frame = l_data.end_frame

	set_effects(l_data)

	# Setting stream
	var l_position: float = float(Editor.frame_nr - l_data.start_frame + l_data.begin) / Project.get_framerate()

	if l_old_file_id != file_id:
		player.stream = Project.get_file_data(file_id).audio
	else:
		if abs(player.get_playback_position() - l_position) > 0.09:
			return

	player.play(l_position / Project.get_framerate())
	player.stream_paused = !Editor.is_playing


func set_effects(_data: ClipData = Project.get_clip(clip_id)) -> void:
	for i: int in AudioServer.get_bus_effect_count(bus_index):
		AudioServer.remove_bus_effect(bus_index, 0)

	# TODO: Implement audio effects
#	if _set_bus_mute(a_data.default_audio_effects.mute):
#		return
#	_set_volume(a_data.default_audio_effects.gain)


func update_effects(_data: ClipData = Project.get_clip(clip_id)) -> void:
	# TODO: Implement this, we don't need to remove/add any effects,
	# just change the value of them
	pass


func _set_bus_mute(a_value: bool) -> bool:
	AudioServer.set_bus_mute(bus_index, a_value)
	return a_value


func _set_volume(a_gain: int) -> void:
	AudioServer.set_bus_volume_db(bus_index, a_gain)

