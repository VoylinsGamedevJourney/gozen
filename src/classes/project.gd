class_name Project extends Node


var title: String
var path: String


func save_data() -> void:
	var file := FileAccess.open_compressed(path, FileAccess.WRITE)
	file.store_var({
		"title": title,
		"path": path
	})


func load_data(p_path: String) -> void:
	var file := FileAccess.open_compressed(p_path, FileAccess.READ)
	var data: Dictionary = file.get_var()
	for key in data: 
		match key:
			_: set(key, data[key])


func new_project(p_title: String, p_path: String) -> void:
	title = p_title
	path = p_path
	if path[-1] != "/":
		path += "/"
	path += "%s.gozen" % title
	save_data()
