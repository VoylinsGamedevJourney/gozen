class_name File
extends Node


enum TYPE { EMPTY = -1, IMAGE, AUDIO, VIDEO,  TEXT, }


var id: int
var path: String # Temporary files start with "temp://"
var nickname: String
var type: TYPE = TYPE.EMPTY

var duration: int = -1

var temp_file: TempFile = null # Only filled when file is a temp file



static func create(file_path: String) -> File:
	var file: File = File.new()
	var ext: String = file_path.get_extension().to_lower()

	if ext in ProjectSettings.get_setting_with_override("extensions/image"):
		file.type = TYPE.IMAGE
	elif ext in ProjectSettings.get_setting_with_override("extensions/audio"):
		file.type = TYPE.AUDIO
	elif ext in ProjectSettings.get_setting_with_override("extensions/video"):
		file.type = TYPE.VIDEO
	elif file_path == "temp://image":
		file.type = TYPE.IMAGE
	elif file_path == "temp://text":
		file.type = TYPE.TEXT
	else:
		printerr("Invalid file: ", file_path)
		return null

	file.id = Toolbox.get_unique_id(Project.get_file_ids())
	file.path = file_path

	if file_path.contains("temp://"):
		file.nickname = "Image %s" % file.id
	else:
		file.nickname = file_path.get_file()

	return file

