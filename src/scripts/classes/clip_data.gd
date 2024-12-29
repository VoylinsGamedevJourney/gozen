class_name ClipData extends Resource


const MAX_FRAME_SKIPS: int = 20


var id: int
var file_id: int
var type: File.TYPE

var start_frame: int # Timeline begin of clip
var duration: int
var begin: int = 0 # Only for video files

var effects_audio: EffectsAudio = EffectsAudio.new()



func get_audio() -> PackedByteArray:
	if type in ViewPanel.AUDIO_TYPES:
		return Project.get_clip_audio(id)
	return []


func update_audio_data() -> void:
	if type not in [File.TYPE.AUDIO, File.TYPE.VIDEO]:
		return

	var l_file_data: FileData = Project._files_data[file_id]
	
	# Trim beginning of audio
	Project._audio[id] = l_file_data.audio.slice(
		begin * AudioHandler.bytes_per_frame,
		(begin + duration) * AudioHandler.bytes_per_frame)

	# Applying Mono effect
	if effects_audio.mono != effects_audio.MONO.OFF:
		Project._audio[id] = Audio.change_to_mono(
				Project._audio[id] as PackedByteArray,
				effects_audio.mono == effects_audio.MONO.LEFT_CHANNEL)

	# Adjusting volume
	if effects_audio.db == 0:
		Project._audio[id] = Audio.change_db(
				Project._audio[id] as PackedByteArray,
				effects_audio.db)


func load_video_frame(a_track: int, a_frame_nr: int) -> void:
	# Correct frame for video framerate
	a_frame_nr = a_frame_nr - start_frame + begin
	a_frame_nr = clampi(
			roundi((float(a_frame_nr) / Project.framerate) * _get_file_data().framerate),
			0, _get_file_data().frame_duration)

	# Check if frame is already correct or not
	if a_frame_nr != 0 and a_frame_nr == _get_file_data().current_frame[a_track]:
		return # We already have the correct frame loaded

	# Setting the difference to check if frame skipping is required
	var l_skips: int = a_frame_nr - _get_file_data().current_frame[a_track]

	# Check if frame is before current one or after max skip
	if a_frame_nr < _get_file_data().current_frame[a_track] or l_skips > MAX_FRAME_SKIPS:
		_get_file_data().current_frame[a_track] = a_frame_nr
		if _get_video(a_track).seek_frame(a_frame_nr):
			printerr("Couldn't seek frame!")
		return

	# Go through skips and set frame
	for i: int in l_skips - 1:
		if !_get_video(a_track).next_frame(true):
			print("Something went wrong skipping next frame!")

	_get_file_data().current_frame[a_track] = a_frame_nr
	if !_get_video(a_track).next_frame(false):
		print("Something went wrong skipping next frame!")


func _get_file_data() -> FileData:
	return Project._files_data[file_id]


func _get_video(a_track: int) -> Video:
	return Project._files_data[file_id].video[a_track]

