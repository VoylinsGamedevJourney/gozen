class_name DefaultFile extends Node

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


var vars: PackedStringArray = [
		"file_type",
		"duration",
		"nickname",
		"folder",
		"effects",
	]


var file_type: FILE_TYPE
var duration: int
var nickname: String
var folder: String # full path
var effects: Array


func get_data() -> Dictionary:
	var dic := {}
	for variable: String in vars:
		if get(variable) == null:
			printerr("'%s' can not be empty!" % variable)
		else:
			dic[variable] = get(variable)
	return dic
