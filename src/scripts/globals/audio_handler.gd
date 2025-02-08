extends Node

# TODO: For double speed, change mix_rate or pitch (mix rate is easier)

# Numbers are: mix_rate, stereo, 16 bits so 2 bytes per sample
const BYTES_PER_FRAME: int = 4 # Stereo (2) and 16 bits (2 * 8 bits)
var bytes_per_video_frame: int

@warning_ignore("unused_private_class_variable")
var clip_audio: Dictionary[int, Audio] = {} # { clip_id: Audio class }

var players: Array[AudioStreamPlayer] = []
var clip_ids: PackedInt64Array = []
var not_ready: PackedInt32Array = [] # List of track id's of not ready clips

var last_frame: int = -1



func _ready() -> void:
	bytes_per_video_frame = int(float(44100 * BYTES_PER_FRAME) / Project.framerate)

	for i: int in 6:
		@warning_ignore("return_value_discarded")
		clip_ids.append(-1)
		players.append(AudioStreamPlayer.new())
		add_child(players[-1])
	
	if View.play_changed.connect(_on_play_changed) +\
			View.frame_nr_changed.connect(on_frame_changed):
		printerr("Something went wrong in _ready in AudioHandler!")


func _process(_delta: float) -> void:
	for i: int in not_ready:
		set_audio(i)


func _on_play_changed(a_value: bool) -> void:
	for l_player: AudioStreamPlayer in players:
		l_player.stream_paused = !a_value


func on_frame_changed(a_frame: int) -> void:
# NOTE: if performance would be bad, use this instead of resetting all streams
	if a_frame == last_frame:
		# Update audio streams
		# Just check if each clip is still existing and if empty tracks became
		# populated instead. Effects on a clip may also have changed.
		print("oi")
		for i: int in players.size():
			clip_ids[i] = find_audio(a_frame, i)

			if clip_ids[i] != -1:
				set_audio(i)
			else:
				players[i].stop()
	elif a_frame == last_frame + 1:
		# Normal playback
		# Check the track data to see if the frame_nr matches a clip or not
		# if there's a match, we need to switch the stream
		for i: int in players.size():
			if Project.tracks[i].has(a_frame):
				clip_ids[i] = Project.tracks[i][a_frame]
				set_audio(i)
	elif a_frame != last_frame:
		# Set audio streams
		# Clean up previous streams
		print("clean")
		for i: int in players.size():
			reset_stream(i)

	last_frame = a_frame


func reset_stream(a_track_id: int) -> void:
	players[a_track_id].stop()
	clip_ids[a_track_id] = find_audio(View.frame_nr, a_track_id)

	if clip_ids[a_track_id] != -1:
		set_audio(a_track_id)


func set_audio(a_track_id: int) -> void:
	if _check_audio(clip_ids[a_track_id], a_track_id):
		if not_ready.has(a_track_id):
			not_ready.remove_at(not_ready.find(a_track_id))

		var l_position: float = View.frame_nr - Project.clips[clip_ids[a_track_id]].start_frame

		players[a_track_id].stream = clip_audio[clip_ids[a_track_id]].get_stream()
		players[a_track_id].play(l_position / Project.framerate)
		players[a_track_id].stream_paused = !View.is_playing


func _check_audio(a_clip_id: int, a_track_id: int) -> bool:
	@warning_ignore_start("return_value_discarded")
	if !clip_audio.has(a_clip_id) or clip_audio[a_clip_id].get_data_size() == 0:
		if !not_ready.has(a_track_id):
			not_ready.append(a_track_id)
		return false
	elif clip_audio[a_clip_id].get_stream().data.size() == 0:
		if !not_ready.has(a_track_id):
			not_ready.append(a_track_id)
		return false

	return true


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
				if l_track_audio.size() != l_clip.start_frame * bytes_per_video_frame:
					if l_track_audio.resize(l_clip.start_frame * bytes_per_video_frame):
						printerr("Couldn't resize l_track_audio!")
						print("resized array")

				# Add the data to l_track_audio
				l_track_audio.append_array(clip_audio[l_clip.id].get_data())

			# Check if audio is empty or not
			if l_track_audio.size() == 0:
				continue

			# check for mistakes
			if l_track_audio.size() > (Project.timeline_end + 1) * bytes_per_video_frame:
				printerr("Too much audio data!")

			# Resize the last parts to equal the size to timeline_end
			if l_track_audio.resize((Project.timeline_end + 1) * bytes_per_video_frame):
				printerr("Couldn't resize l_track_audio!")

		if l_audio.size() == 0:
			l_audio = l_track_audio
		elif l_audio.size() == l_track_audio.size():
			l_audio = Audio.combine_data(l_audio, l_track_audio)

	# Check for the total audio length
	#print((float(l_audio.size()) / AudioHandler.bytes_per_frame) / 30)
	print("Rendering audio complete")
	return l_audio

