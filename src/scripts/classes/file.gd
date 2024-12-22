class_name File extends Node

enum TYPE { IMAGE, VIDEO, AUDIO }

var path: String
var nickname: String
var type: TYPE

var duration: int = -1



static func create(a_path: String) -> File:
	var l_file: File = File.new()
	var l_extension: String = a_path.split('.')[-1].to_lower()

	l_file.path = a_path
	l_file.nickname = a_path.split('/')[-1]

	if l_extension in ["wav", "mp3", "ogg"]:
		l_file.type = TYPE.AUDIO
	elif l_extension in ["jpg", "jpeg", "png", "svg", "webp"]:
		l_file.type = TYPE.IMAGE
	elif l_extension in ["mpeg", "mp4", "mkv", "mlt",
			"ogv", "webm", "vp9", "av1"]:
		l_file.type = TYPE.VIDEO
	else:
		printerr("Unrecognized file at '%s' with extension '%s'!" % 
				[a_path, l_extension] )
		return null

	return l_file

