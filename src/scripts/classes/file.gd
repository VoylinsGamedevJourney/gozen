class_name File
extends Node


enum TYPE { EMPTY = -1, IMAGE, AUDIO, VIDEO, TEXT, COLOR, PCK }


var id: int
var path: String # Temporary files start with "temp://".
var nickname: String
var type: TYPE = TYPE.EMPTY
var folder: String = "/" # Folder inside the editor.

var modified_time: int = -1

var duration: int = -1

var temp_file: TempFile = null # Only filled when file is a temp file.



static func create(file_path: String) -> File:
	var file: File = File.new()
	var extension: String = file_path.get_extension().to_lower()

	if extension in ProjectSettings.get_setting("extensions/image"):
		file.type = TYPE.IMAGE
		file.modified_time = FileAccess.get_modified_time(file_path)
	elif extension in ProjectSettings.get_setting("extensions/audio"):
		file.type = TYPE.AUDIO
		file.modified_time = FileAccess.get_modified_time(file_path)
	elif extension in ProjectSettings.get_setting("extensions/video"):
		file.type = TYPE.VIDEO
		file.modified_time = FileAccess.get_modified_time(file_path)
	elif file_path == "temp://image":
		file.type = TYPE.IMAGE
	elif file_path == "temp://text":
		file.type = TYPE.TEXT
	elif file_path == "temp://color":
		file.type = TYPE.COLOR
	elif extension == "pck":
		file.type = TYPE.PCK
	else:
		printerr("Invalid file: ", file_path)
		return null

	file.id = Toolbox.get_unique_id(Project.get_file_ids())
	file.path = file_path

	if file_path.contains("temp://"):
		var file_type: String = file_path.trim_prefix("temp://").capitalize()
		file.nickname = "%s %s" % [file_type, file.id]
	else:
		file.nickname = file_path.get_file()

	return file


static func check_valid(file_path: String) -> bool:
	# Only for real files, not temp ones.
	if !FileAccess.file_exists(file_path):
		return false
	var ext: String = file_path.get_extension()

	if ext in ProjectSettings.get_setting("extensions/image"):
		return true
	elif ext in ProjectSettings.get_setting("extensions/audio"):
		return true
	elif ext in ProjectSettings.get_setting("extensions/video"):
		return true

	return false

