class_name Project
extends Node

signal update_files_interface_tree


var p_name: String = "Missing project file"
var p_path: String
var p_creation: int = 0
var p_edit: int = 0



## Get only the essential data for using inside of the project manager
static func get_project_manager_data(project_path: String) -> Dictionary:
	var project_dic := {
		"p_name": "Missing project file",
		"p_path": project_path,
		"p_creation": 0,
		"p_edit": 0 }
	if !FileAccess.file_exists(project_path): return project_dic
	var project_file := FileAccess.open_compressed(project_path, FileAccess.READ)
	if project_file.get_open_error():
		printerr("Could not open project file at %s.\n\tError: %s" % [project_path, project_file.get_open_error()])
		return project_dic
	var project_data: Dictionary = project_file.get_var()
	project_dic.p_name = project_data.p_name
	project_dic.p_creation = project_data.p_creation
	project_dic.p_edit = project_data.p_edit
	return project_dic


## Creates a new project at the desired location
static func create_new_project(project_name: String, project_folder: String) -> Dictionary:
	if DirAccess.dir_exists_absolute(project_folder):
		printerr("Folder does not exist at path: %s" % project_folder)
		return {}
	var file_correct_name: String = "" 
	var invalid_characters := ['<','>',':','"','/','\\','|','?','*']
	for char in project_name:
		file_correct_name += "_" if char in invalid_characters else char
	var project := Project.new()
	project.p_name = project_name
	project.p_path = "%s/%s.gozen" % [project_folder, file_correct_name]
	project.p_creation = TimeManager.date_to_int()
	project.p_edit = project.p_creation
	project.save_project()
	return get_project_manager_data(project.p_path)


## Saves the project data to the correct file
func save_project() -> void:
	var data := {}
	data["p_name"] = p_name
	data["p_path"] = p_path
	data["p_creation"] = p_creation
	data["p_edit"] = p_edit
	var file := FileAccess.open_compressed(p_path, FileAccess.WRITE)
	file.store_var(data)
	file.close()
#	I AM HERE!!!







func load_project(project_path: String) -> void:
	p_path = project_path # In case the saved path has changed
	if !FileAccess.file_exists(project_path):
		return
	var file := FileAccess.open_compressed(project_path, FileAccess.READ)
	var project_data = file.get_var()
	file.close()
	
	p_name = project_data.p_name
	p_creation = project_data.p_creation
	p_edit = project_data.p_edit
#	p_files_id = project_data.p_files_id
	
#	for project_file in project_data.p_files:
#		var new_file: File = File.new()
#		new_file.load_data(project_file)
#		p_files[new_file.f_id] = new_file


