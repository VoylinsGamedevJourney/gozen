class_name ClipData extends Resource


var id: int
var file_id: int
var type: File.TYPE

var start_frame: int # Timeline begin of clip
var duration: int
var begin: int = 0 # Only for video + audio files



func get_audio_data() -> PackedByteArray:
	# TODO: Add all the effects in here as well
	var l_file_data: FileData = Project._files_data[file_id]
	var l_audio: PackedByteArray = l_file_data.audio.data.duplicate()

	# Trim end if needed
	if l_audio.resize((begin + duration) * AudioHandler.bytes_per_frame):
		printerr("Couldn't resize audio data of clip!")

	# Only send beginning of audio
	return l_audio.slice(begin * AudioHandler.bytes_per_frame)

