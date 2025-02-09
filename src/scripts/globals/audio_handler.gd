extends Node

# TODO: For double speed, change mix_rate or pitch (mix rate is easier)

# Numbers are: mix_rate, stereo, 16 bits so 2 bytes per sample
const SAMPLE_SIZE: int = 4 # Stereo (2) and 16 bits (2 * 8 bits)


var players: Array[Player] = []
var last_frame: int = -1



func _ready() -> void:
	@warning_ignore_start("return_value_discarded")
	View.play_changed.connect(_on_play_changed)
	View.frame_nr_changed.connect(on_frame_changed)
	@warning_ignore_restore("return_value_discarded")

	for i: int in 6:
		AudioServer.add_bus()
		players.append(Player.new(AudioServer.bus_count - 1))
		add_child(players[-1])
		add_child(players[-1].player)
	

func get_sample_count(a_frame_count: int) -> int :
	var l_seconds: float = float(a_frame_count) / Project.framerate
	return int(44100 * SAMPLE_SIZE * l_seconds)


func get_audio_duration(a_stream: AudioStreamWAV) -> int:
	# Returns the audio duration in video frames
	var l_seconds: float = float(a_stream.data.size()) / (SAMPLE_SIZE * 44100)
	return floor(l_seconds * Project.framerate)


func _on_play_changed(a_value: bool) -> void:
	for l_player: Player in players:
		l_player.play(a_value)

	
func audio_effect_update(a_clip_id: int) -> void:
	for l_player: Player in players:
		if l_player.clip_id == a_clip_id:
			# TODO: .update_effects() is not implemented yet.
			l_player.set_effects()


func audio_effect_added(a_clip_id: int) -> void:
	# TODO: Find a better way to just add that specific effect in the correct
	# position.
	for l_player: Player in players:
		if l_player.clip_id == a_clip_id:
			l_player.set_effects()


func audio_effect_removed(a_clip_id: int) -> void:
	# TODO: Find a better way to just remove that specific effect
	for l_player: Player in players:
		if l_player.clip_id == a_clip_id:
			l_player.set_effects()


func audio_effect_repositioned(a_clip_id: int) -> void:
	# TODO: Find a better way to just reposition that specific effect
	for l_player: Player in players:
		if l_player.clip_id == a_clip_id:
			l_player.set_effects()


func audio_effect_update_file(a_file_id: int) -> void:
	for l_player: Player in players:
		if l_player.file_id == a_file_id:
			l_player.set_effects()


func audio_effect_added_file(a_file_id: int) -> void:
	# TODO: Find a better way to just add that specific effect in the correct
	# position.
	for l_player: Player in players:
		if l_player.file_id == a_file_id:
			l_player.set_effects()


func audio_effect_removed_file(a_file_id: int) -> void:
	# TODO: Find a better way to just remove that specific effect
	for l_player: Player in players:
		if l_player.file_id == a_file_id:
			l_player.set_effects()


func audio_effect_repositioned_file(a_file_id: int) -> void:
	# TODO: Find a better way to just reposition that specific effect
	for l_player: Player in players:
		if l_player.file_id == a_file_id:
			l_player.set_effects()


func on_frame_changed(a_frame: int) -> void:
	if a_frame == last_frame + 1:
		# Normal playback
		for i: int in players.size():
			if Project.tracks[i].has(a_frame):
				players[i].set_audio(Project.tracks[i][a_frame] as int)
			elif players[i].stop_frame == a_frame:
				players[i].stop()
	else:
		# Reset players
		for i: int in players.size():
			players[i].stop()
			print("oi")
			players[i].set_audio(find_audio(a_frame, i))

	last_frame = a_frame


func find_audio(a_frame_nr: int, a_track_id: int) -> int:
	var l_positions: PackedInt64Array = Project.tracks[a_track_id].keys()
	var l_last: int = -1
	l_positions.sort()

	for i: int in l_positions:
		if i <= a_frame_nr:
			l_last = i
			continue
		break

	if l_last == -1:
		return -1

	l_last = Project.tracks[a_track_id][l_last]
	if a_frame_nr <= Project.clips[l_last].get_end_frame():
		return l_last
	else:
		return -1


func render_audio() -> PackedByteArray:
	var l_audio: PackedByteArray = []

	for l_track_id: int in Project.tracks.size():
		var l_track_audio: PackedByteArray = []

		for l_frame_point: int in Project.tracks[l_track_id].keys():
			var l_clip: ClipData = Project.clips[Project.tracks[l_track_id][l_frame_point]]

			if l_clip.type in View.AUDIO_TYPES:
				# Check if we need to add empty data to track_audio
				if l_track_audio.size() != get_sample_count(l_clip.start_frame):
					if l_track_audio.resize(get_sample_count(l_clip.start_frame)):
						printerr("Couldn't resize l_track_audio!")
						print("resized array")

				l_track_audio.append_array(_get_clip_audio_for_render(l_clip))

			# Check if audio is empty or not
			if l_track_audio.size() == 0:
				continue

			# check for mistakes
			if l_track_audio.size() > get_sample_count(Project.timeline_end + 1):
				printerr("Too much audio data!")

			# Resize the last parts to equal the size to timeline_end
			if l_track_audio.resize(get_sample_count(Project.timeline_end + 1)):
				printerr("Couldn't resize l_track_audio!")

		if l_audio.size() == 0:
			l_audio = l_track_audio
		elif l_audio.size() == l_track_audio.size():
			l_audio = Audio.combine_data(l_audio, l_track_audio)

	# Check for the total audio length
	#print((float(l_audio.size()) / AudioHandler.bytes_per_frame) / 30)
	print("Rendering audio complete")
	return l_audio


func _get_clip_audio_for_render(a_clip: ClipData) -> PackedByteArray:
	# Here we get the clip and apply both file + clip effects on the data

	# Get the data part we need
	var l_file: File = Project.files[a_clip.file_id]
	var l_file_data: FileData = Project._files_data[a_clip.file_id]

	var l_data: PackedByteArray = l_file_data.audio.data.slice(
			a_clip.begin, a_clip.begin + a_clip.duration)

	# Apply all file effects
	l_data = l_file.default_audio_effects.apply_effect(l_data)
	
	if l_file.default_audio_effects.mute:
		return l_data

	for l_effect: EffectAudio in l_file.audio_effects:
		l_data = l_effect.apply_effect(l_data)

	# Applying default effect
	l_data = a_clip.default_audio_effects.apply_effect(l_data)

	if a_clip.default_audio_effects.mute:
		return l_data

	for l_effect: EffectAudio in a_clip.audio_effects:
		l_data = l_effect.apply_effect(l_data)

	return l_data



class Player extends Node:
	var player: AudioStreamPlayer = AudioStreamPlayer.new()
	var bus_index: int = -1

	var stop_frame: int = -1
	var file_id: int = -1
	var clip_id: int = -1



	func _init(a_bus_index: int) -> void:
		bus_index = a_bus_index
		player.bus = AudioServer.get_bus_name(a_bus_index)


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

		var l_data: ClipData = Project.clips[a_clip_id]
		var l_old_file_id: int = file_id

		clip_id = a_clip_id
		file_id = l_data.file_id
		stop_frame = l_data.end_frame

		set_effects(l_data)

		# Setting stream
		var l_position: float = float(View.frame_nr - l_data.start_frame + l_data.begin) / Project.framerate

		if l_old_file_id != file_id:
			player.stream = Project._files_data[file_id].audio
		else:
			if abs(player.get_playback_position() - l_position) > 0.09:
				return

		player.play(l_position / Project.framerate)
		player.stream_paused = !View.is_playing



	func set_effects(a_data: ClipData = Project.clips[clip_id]) -> void:
		# Clear all effects on bus
		for i: int in AudioServer.get_bus_effect_count(bus_index):
			AudioServer.remove_bus_effect(bus_index, 0)

		# Apply effects to bus
		if _set_bus_mute(a_data.default_audio_effects.mute):
			return

		# Default audio effect(s)
		_set_volume(a_data.default_audio_effects.gain)


		for l_effect: EffectAudio in a_data.audio_effects:
			print("Still needs to be implemented")

	
	func update_effects(_data: ClipData = Project.clips[clip_id]) -> void:
		# TODO: Implement this, we don't need to remove/add any effects,
		# just change the value of them
		pass


	func _set_bus_mute(a_value: bool) -> bool:
		AudioServer.set_bus_mute(bus_index, a_value)
		return a_value

	
	func _set_volume(a_gain: int) -> void:
		AudioServer.set_bus_volume_db(bus_index, a_gain)
			
