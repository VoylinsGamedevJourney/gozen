class_name ClipData extends Resource


var id: int
var file_id: int
var type: File.TYPE

var start_frame: int # Timeline begin of clip
var duration: int
var begin: int = 0 # Only for video files

var audio_data: PackedByteArray = []



func update_audio_data() -> void:
	if type not in [File.TYPE.AUDIO, File.TYPE.VIDEO]:
		return

	var l_file_data: FileData = Project._files_data[file_id]

	# Trim beginning of audio
	audio_data = l_file_data.audio.data.slice(
			begin * AudioHandler.bytes_per_frame,
			(begin + duration) * AudioHandler.bytes_per_frame)

	# TODO: Add all the effects in here as well

