class_name ProjectData
extends Node

var project_name: String = "new_project"
var project_path: String = ""

var local_files := []
var line_data := { "video": [], "audio": [] }


func get_data() -> Dictionary:
	var temp_data: Dictionary = {}
	for x in get_property_list():
		if x.usage == 4096: temp_data[x.name] = get(x.name)
	return temp_data

func set_data(data: Dictionary) -> void:
	for x in data:
		if get(x) != null: set(x, data[x])
