class_name FileDefault extends Node

enum FILE_TYPE { 
	# Actual files
	VIDEO,
	AUDIO,
	IMAGE,
	# Generated
	TEXT,
	COLOR,
	COLOR_GRADIENT_1D,
	COLOR_GRADIENT_2D
}


var file_type: FILE_TYPE
var duration: int
var nickname: String
var folder: String # full path
var file_effects: Array
var effects: Array


func get_data() -> Dictionary:
	var dic := {}
	for variable_data: Dictionary in get_property_list():
		if variable_data.usage != 4096:
			continue
		elif get(variable_data.name) == null:
			printerr("'%s' can not be empty!" % variable_data.name)
		else:
			dic[variable_data.name] = get(variable_data.name)
	return dic


static func get_file_icon(type: FileDefault.FILE_TYPE) -> Texture:
	match type:
		FILE_TYPE.VIDEO:
			return preload("res://assets/icons/video_file.png")
		FILE_TYPE.AUDIO:
			return preload("res://assets/icons/audio_file.png")
		FILE_TYPE.IMAGE:
			return preload("res://assets/icons/image_file.png")
		# Generated
		FILE_TYPE.TEXT:
			return preload("res://assets/icons/text_file.png")
		FILE_TYPE.COLOR:
			return preload("res://assets/icons/color_file.png")
		FILE_TYPE.COLOR_GRADIENT_1D:
			return preload("res://assets/icons/gradient_file.png")
		FILE_TYPE.COLOR_GRADIENT_2D:
			return preload("res://assets/icons/gradient_file.png")
	return preload("res://assets/icons/close.png")
