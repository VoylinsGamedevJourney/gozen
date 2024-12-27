class_name ClipData extends Resource


var id: int
var file_id: int
var type: File.TYPE

var start_frame: int # Timeline begin of clip
var duration: int
var begin: int = 0 # Only for video files

var effects: Dictionary = {}
# Possible audio effects:
# - mono: bool (true = left channel only, false = right channel only)
# - change_db: int (value gets added, use negative values for subtracting)



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

	if effects.has("mono"):
		Project._audio[id] = Audio.change_to_mono(Project._audio[id], effects["mono"])

	if effects.has("change_db"):
		Project._audio[id] = Audio.change_db(Project._audio[id], effects["change_db"])

