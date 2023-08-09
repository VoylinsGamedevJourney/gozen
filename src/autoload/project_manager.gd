extends Node


var title := "Untitled project": 
	set(new_title): 
		# TODO: Remove invalid chars
		# TODO: Change file path + file name
		title = new_title 
		Globals._on_project_title_change.emit()
var path: String # user://project_folder

var resolution := Vector2i(1920, 1080):
	set(x):
		resolution = x
		Globals._on_project_resolution_change.emit()


func get_full_path() -> String:
	return "%s/%s.gozen" % [path, title]


## A quick check to see if a project file is actually valid
func check_project_file(project_path: String) -> bool:
	if !FileAccess.file_exists(project_path): return false
	var project_file := FileAccess.open_compressed(project_path, FileAccess.READ)
	if FileAccess.get_open_error() != OK: return false
	var file_data = project_file.get_var()
	if not file_data is Dictionary: return false
	if !(file_data as Dictionary).has("title"): return false
	if !(file_data as Dictionary).has("path"): return false
	return true


func load_project(project_path: String) -> void:
	# TODO: Make this work
	pass


func save_project() -> void:
	# TODO: Check if there is a path or not
	# If there was no path, we should add this to top of recent projects
	# TODO: Make this work
	pass
