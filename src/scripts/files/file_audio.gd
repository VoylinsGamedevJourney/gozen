class_name FileAudio extends File


const EXTENSIONS: PackedStringArray = ["ogg", "wav", "mp3"]


var file_path: String = ""
var sha256: String = ""



func _init() -> void:
	type = FILE_AUDIO


static func create(a_file_path: String) -> FileAudio:
	if not a_file_path.split('.')[-1].to_lower() in EXTENSIONS:
		printerr("File is not an audio file!")
		return FileAudio.new()
	var l_file: FileAudio = FileAudio.new()
	l_file.file_path = a_file_path
	l_file.sha256 = FileAccess.get_sha256(a_file_path)
	l_file.nickname = a_file_path.split('/')[-1].split('.')[0]
	
	# TODO: Add this to Project settings during data loading
	var l_audio: AudioStream
	match a_file_path.split('.')[-1].to_lower():
		"ogg": l_audio = AudioStreamOggVorbis.new()
		"wav": l_audio = AudioStreamWAV.new()
		"mp3": l_audio = AudioStreamMP3.new()
	l_audio.load_from_file(a_file_path)
	l_file.duration = l_audio.get_length()
	
	return l_file
