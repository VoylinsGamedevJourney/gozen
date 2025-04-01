extends Node


signal frame_changed(nr: int)
signal play_changed(value: bool)


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


func _process(delta: float) -> void:
	if !is_playing:
		return

	# Check if enough time has passed for next frame or not move playhead as well
	skips = 0
	time_elapsed += delta

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


func on_play_pressed() -> void:
	is_playing = false if frame_nr == Project.get_timeline_end() else !is_playing


func _set_frame_nr(value: int) -> void:
	if value >= Project.get_timeline_end():
		is_playing = false
		frame_nr = Project.get_timeline_end()

		for i: int in audio_players.size():
			audio_players[i].stop()
		return

	if value == prev_frame + 1:
		for i: int in audio_players.size():
			var track_data: PackedInt64Array = Project.get_track_keys(i)

			if track_data.has(value):
				audio_players[i].set_audio(track_data[value])
			elif audio_players[i].stop_frame == value:
				audio_players[i].stop()
	else:  # Reset all audio players
		for i: int in audio_players.size():
			audio_players[i].stop()
			audio_players[i].set_audio(find_audio(value, i))
	
	frame_nr = value
	prev_frame = frame_nr
		

func _set_is_playing(value: bool) -> void:
	is_playing = value

	for player: AudioPlayer in audio_players:
		player.play(value)

	play_changed.emit(value)


func set_frame(nr: int = frame_nr + 1) -> void:
	# TODO: Implement frame skipping
	frame_nr = nr

	for i: int in loaded_clips.size():
		# Check if current clip is correct
		if _check_clip(i, frame_nr):
			update_view(i, frame_nr)
			continue

		# Getting the next frame if possible
		var clip_id: int = _get_next_clip(frame_nr, i)

		if clip_id == -1:
			loaded_clips[i] = null
			continue
		else:
			loaded_clips[i] = Project.get_clip(clip_id)

		set_view(i)
		update_view(i, frame_nr)
	
	if frame_nr == Project.get_timeline_end():
		is_playing = false

	frame_changed.emit(frame_nr)


func _get_next_clip(new_frame_nr: int, track: int) -> int:
	var clip_id: int = -1

	if Project.get_track_keys(track).size() == 0:
		return -1

	# Looking for the correct clip
	for frame: int in Project.get_track_keys(track):
		if frame <= new_frame_nr:
			clip_id = Project.get_track_data(track)[frame]
		else:
			break

	if clip_id != -1 and _check_clip_end(new_frame_nr, clip_id):
		return clip_id

	return -1


func _check_clip_end(new_frame_nr: int, id: int) -> bool:
	var clip: ClipData = Project.get_clip(id)

	return false if !clip else new_frame_nr < clip.start_frame + clip.duration


# Audio stuff  ----------------------------------------------------------------
func _setup_audio_players() -> void:
	audio_players = []

	for i: int in 6:
		audio_players.append(AudioPlayer.new())
		add_child(audio_players[i].player)


func find_audio(frame: int, track: int) -> int:
	var pos: PackedInt64Array = Project.get_track_keys(track)
	var last: int = -1
	pos.sort()

	for i: int in pos:
		if i <= frame:
			last = i
			continue
		break

	if last == -1:
		return -1

	last = Project.get_track_data(track)[last]
	if frame <= Project.get_clip(last).get_end_frame():
		return last
	else:
		return -1


func get_sample_count(frames: int) -> int:
	return int(44100 * 4 * float(frames) / Project.get_framerate())

	
func render_audio() -> PackedByteArray:
	var audio: PackedByteArray = []

	for i: int in Project.get_track_count():
		var track_audio: PackedByteArray = []
		var track_data: Dictionary[int, int] = Project.get_track_data(i)


		for frame_point: int in Project.get_track_keys(i):
			var clip: ClipData = Project.get_clip(track_data[frame_point])
			var file: File = Project.get_file(clip.file_id)

			if file.type in AUDIO_TYPES:
				var sample_count: int = get_sample_count(clip.start_frame)

				if track_audio.size() != sample_count:
					if track_audio.resize(sample_count):
						Toolbox.print_resize_error()
				
				track_audio.append_array(clip.get_clip_audio_data())

			# Checking if audio is empty or not
			if track_audio.size() == 0:
				continue

		# Making the audio data the correct length
		if track_audio.resize(get_sample_count(Project.get_timeline_end() + 1)):
			Toolbox.print_resize_error()

		if audio.size() == 0:
			audio = track_audio
		elif audio.size() == track_audio.size():
			audio = Audio.combine_data(audio, track_audio)

	# Check for the total audio length
	#print((float(audio.size()) / AudioHandler.bytes_per_frame) / 30)
	print("Rendering audio complete")
	return audio

			
# Video stuff  ----------------------------------------------------------------
func set_view(_id: int) -> void: # id is track id
	pass
	#print("set_view ", id)


func update_view(_id: int, _new_frame_nr: int) -> void:
	pass
	#print("update_view ", id, " ", frame_nr)


## Update display/audio and continue if within clip bounds.
func _check_clip(id: int, new_frame_nr: int) -> bool:
	if loaded_clips[id] == null:
		return false

	# Check if clip really still exists or not.
	if !Project.get_clips().has(loaded_clips[id].clip_id):
		loaded_clips[id] = null
		return false

	# Track check
	if loaded_clips[id].track_id != id:
		return false

	if loaded_clips[id].start_frame > new_frame_nr:
		return false

	if frame_nr > loaded_clips[id].start_frame + loaded_clips[id].duration:
		return false

	return true

