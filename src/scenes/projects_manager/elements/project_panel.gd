extends Panel

@onready var name_label := find_child("ProjectNameLabel")
@onready var path_label := find_child("ProjectPathLabel")


var project_name: String
var project_path: String
var last_edited: int


func load_details(project_path: String) -> void:
	var file := FileAccess.open_compressed(project_path, FileAccess.READ)
	var file_data: Dictionary = file.get_var()
	file.close()
	
	project_name = file_data.project_name
	project_path = file_data.project_path
	last_edited = file_data.last_edited
	
	name_label.text = project_name
	path_label.text = project_path
