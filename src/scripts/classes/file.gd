class_name File extends Node

enum TYPE { EMPTY = -1, IMAGE, VIDEO, AUDIO }

var id: int
var path: String
var nickname: String
var type: TYPE = TYPE.EMPTY

var duration: int = -1

var default_audio_effects: EffectAudioDefault = EffectAudioDefault.new(id, false)
var audio_effects: Array[EffectAudio] = []



static func create(a_path: String) -> File:
	var l_file: File = File.new()
	var l_extension: String = a_path.get_extension().to_lower()

	l_file.id = Utils.get_unique_id(Project.files.keys())
	l_file.path = a_path
	l_file.nickname = a_path.get_file()

	match l_extension:
		"wav", "mp3", "ogg":
			l_file.type = TYPE.AUDIO
		"jpg", "jpeg", "png", "svg", "webp":
			l_file.type = TYPE.IMAGE
		"mpeg", "mp4", "mkv", "mlt", "ogv", "webm", "vp9", "av1", "mov":
			l_file.type = TYPE.VIDEO
		_:
			printerr("Unrecognized file at '%s' with extension '%s'!" %
				[a_path, l_extension] )
			return null

	return l_file
