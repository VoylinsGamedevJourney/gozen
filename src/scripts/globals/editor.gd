extends Node


signal frame_changed(a_nr: int)
signal play_changed(a_value: bool)


const VISUAL_TYPES: PackedInt64Array = [ File.TYPE.IMAGE, File.TYPE.VIDEO ]
const AUDIO_TYPES: PackedInt64Array = [ File.TYPE.AUDIO, File.TYPE.VIDEO ]


var audio_players: Array[AudioPlayer]

var frame_nr: int = 0: set = _set_frame_nr
var prev_frame: int = -1

var is_playing: bool = false: set = _set_is_playing
var loaded_clips: Array[ClipData] = []

var time_elapsed: float = 0.0
var frame_time: float = 0.0  # Get's set when changing framerate
var skips: int = 0



func _ready() -> void:
	Toolbox.connect_func(Project.project_ready, _setup_audio_players)
	Toolbox.connect_func(Project.project_ready, set_frame.bind(frame_nr))


func _process(a_delta: float) -> void:
	if !is_playing:
		return

	# Check if enough time has passed for next frame or not move playhead as well
	skips = 0
	time_elapsed += a_delta

	if time_elapsed < frame_time:
		return

	while time_elapsed >= frame_time:
		time_elapsed -= frame_time
		skips += 1

	if skips <= 1:
		# TODO: We have to adjust the audio playback as well when skipping happens
		frame_nr += skips
		set_frame(frame_nr)
	else:
		set_frame()


func _on_play_pressed() -> void:
	is_playing = false if frame_nr == Project.get_timeline_end() else !is_playing


func _set_frame_nr(a_value: int) -> void:
	if a_value >= Project.get_timeline_end():
		is_playing = false
		frame_nr = Project.get_timeline_end()

		for i: int in audio_players.size():
			audio_players[i].stop()
		return

	if a_value == prev_frame + 1:
		for i: int in audio_players.size():
			var l_track_data: PackedInt64Array = Project.get_track_keys(i)

			if l_track_data.has(a_value):
				audio_players[i].set_audio(l_track_data[a_value])
			elif audio_players[i].stop_frame == a_value:
				audio_players[i].stop()
	else:  # Reset all audio players
		for i: int in audio_players.size():
			audio_players[i].stop()
			audio_players[i].set_audio(find_audio(a_value, i))
	
	frame_nr = a_value
	prev_frame = frame_nr
		

func _set_is_playing(a_value: bool) -> void:
	is_playing = a_value

	for l_player: AudioPlayer in audio_players:
		l_player.play(a_value)

	play_changed.emit(a_value)


func set_frame(a_nr: int = frame_nr + 1) -> void:
	# TODO: Implement frame skipping
	frame_nr = a_nr

	for i: int in loaded_clips.size():
		# Check if current clip is correct
		if _check_clip(i, frame_nr):
			update_view(i, frame_nr)
			continue

		# Getting the next frame if possible
		var l_clip_id: int = _get_next_clip(frame_nr, i)

		if l_clip_id == -1:
			loaded_clips[i] = null
			continue
		else:
			loaded_clips[i] = Project.get_clip(l_clip_id)

		set_view(i)
		update_view(i, frame_nr)
	
	if frame_nr == Project.get_timeline_end():
		is_playing = false

	frame_changed.emit(frame_nr)


func _get_next_clip(a_frame_nr: int, a_track: int) -> int:
	var l_clip_id: int = -1

	if Project.get_track_keys(a_track).size() == 0:
		return -1

	# Looking for the correct clip
	for l_frame: int in Project.get_track_keys(a_track):
		if l_frame <= a_frame_nr:
			l_clip_id = Project.get_track_data(a_track)[l_frame]
		else:
			break

	if l_clip_id != -1 and _check_clip_end(a_frame_nr, l_clip_id):
		return l_clip_id

	return -1


func _check_clip_end(a_frame_nr: int, a_id: int) -> bool:
	var l_clip: ClipData = Project.get_clip(a_id)

	return false if !l_clip else a_frame_nr < l_clip.start_frame + l_clip.duration


# Audio stuff  ----------------------------------------------------------------
func _setup_audio_players() -> void:
	audio_players = []

	for i: int in 6:
		audio_players.append(AudioPlayer.new())
		add_child(audio_players[i].player)


func find_audio(a_frame: int, a_track: int) -> int:
	var l_pos: PackedInt64Array = Project.get_track_keys(a_track)
	var l_last: int = -1
	l_pos.sort()

	for i: int in l_pos:
		if i <= a_frame:
			l_last = i
			continue
		break

	if l_last == -1:
		return -1

	l_last = Project.get_track_data(a_track)[l_last]
	if a_frame <= Project.get_clip(l_last).get_end_frame():
		return l_last
	else:
		return -1


func get_sample_count(a_frames: int) -> int:
	return int(44100 * 4 * float(a_frames) / Project.get_framerate())

	
func render_audio() -> PackedByteArray:
	var l_audio: PackedByteArray = []

	for i: int in Project.get_track_count():
		var l_track_audio: PackedByteArray = []
		var l_track_data: Dictionary[int, int] = Project.get_track_data(i)


		for l_frame_point: int in Project.get_track_keys(i):
			var l_clip: ClipData = Project.get_clip(l_track_data[l_frame_point])
			var l_file: File = Project.get_file(l_clip.file_id)

			if l_file.type in AUDIO_TYPES:
				var l_sample_count: int = get_sample_count(l_clip.start_frame)

				if l_track_audio.size() != l_sample_count:
					if l_track_audio.resize(l_sample_count):
						Toolbox.print_resize_error()
				
				l_track_audio.append_array(l_clip.get_clip_audio_data())

			# Checking if audio is empty or not
			if l_track_audio.size() == 0:
				continue

		# Making the audio data the correct length
		if l_track_audio.resize(get_sample_count(Project.get_timeline_end() + 1)):
			Toolbox.print_resize_error()

		if l_audio.size() == 0:
			l_audio = l_track_audio
		elif l_audio.size() == l_track_audio.size():
			l_audio = Audio.combine_data(l_audio, l_track_audio)

	# Check for the total audio length
	#print((float(l_audio.size()) / AudioHandler.bytes_per_frame) / 30)
	print("Rendering audio complete")
	return l_audio

			
# Video stuff  ----------------------------------------------------------------
func set_view(a_id: int) -> void: # a_id is track id
	pass
	#print("set_view ", a_id)


func update_view(a_id: int, a_frame_nr: int) -> void:
	pass
	#print("update_view ", a_id, " ", a_frame_nr)


## Update display/audio and continue if within clip bounds.
func _check_clip(a_id: int, a_frame_nr: int) -> bool:
	if loaded_clips[a_id] == null:
		return false

	# Check if clip really still exists or not.
	if !Project.get_clips().has(loaded_clips[a_id].clip_id):
		loaded_clips[a_id] = null
		return false

	# Track check
	if loaded_clips[a_id].track_id != a_id:
		return false

	if loaded_clips[a_id].start_frame > a_frame_nr:
		return false

	if a_frame_nr > loaded_clips[a_id].start_frame + loaded_clips[a_id].duration:
		return false

	return true

