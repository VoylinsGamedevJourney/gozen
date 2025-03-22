class_name File
extends Node


enum TYPE { EMPTY = -1, IMAGE, AUDIO, VIDEO,  TEXT, }


var id: int
var path: String # Temporary files start with "temp://"
var nickname: String
var type: TYPE = TYPE.EMPTY

var duration: int = -1

var temp_file: TempFile = null # Only filled when file is a temp file



static func create(a_path: String) -> File:
	var l_file: File = File.new()
	var l_ext: String = a_path.get_extension().to_lower()

	if l_ext in ProjectSettings.get_setting_with_override("extensions/image"):
		l_file.type = TYPE.IMAGE
	elif l_ext in ProjectSettings.get_setting_with_override("extensions/audio"):
		l_file.type = TYPE.AUDIO
	elif l_ext in ProjectSettings.get_setting_with_override("extensions/video"):
		l_file.type = TYPE.VIDEO
	elif a_path == "temp://image":
		l_file.type = TYPE.IMAGE
	elif a_path == "temp://text":
		l_file.type = TYPE.TEXT
	else:
		printerr("Invalid file: ", a_path)
		return null

	l_file.id = Toolbox.get_unique_id(Project.get_file_ids())
	l_file.path = a_path

	if a_path.contains("temp://"):
		l_file.nickname = "Image %s" % l_file.id
	else:
		l_file.nickname = a_path.get_file()

	return l_file
