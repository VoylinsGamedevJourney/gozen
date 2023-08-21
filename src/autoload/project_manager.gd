extends Node

signal _on_project_loaded
signal _on_saved
signal _on_unsaved_changes

signal _on_title_change(new_title)
signal _on_resolution_change(new_resolution)

var project: Project:
	set(x):
		project = x
		_on_project_loaded.emit()


func _input(event: InputEvent) -> void:
	if event.is_action_pressed("save_project"): save_project()


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
	if project == null: return
	if project.path == "": # New project
		# Open file explorer
		var file_explorer := ModuleManager.get_module("file_explorer")
		add_child(file_explorer)
		file_explorer.open_explorer(FileExplorerModule.MODE.OPEN_FILE, ["*.gozen"])
		file_explorer.collect_data.connect(_on_new_project_path_selected)
		return
#	bjj;doajk;dsj;ladj
	# TODO: Check if there is a path or not
	# If there 0was no path, we should add this to top of recent projects
	# TODO: Make this work
	pass


func _on_new_project_path_selected(new_path: String) -> void:
	project.title = new_path.split("/")[-1].replace(".gozen",'')
	project.path = new_path.replace("%s.gozen" % project.title, '')
	save_project()

##############################################################
# Getters and setters  #######################################
##############################################################

# TITLE  #####################################################
func get_title() -> String: 
	return project.title

func set_title(new_title: String) -> void:
	# TODO: Remove invalid chars
	project.title = new_title
	ProjectManager._on_title_change.emit(new_title)


# PATH  ######################################################
func get_project_path() -> String:
	return project.path

func get_full_project_path() -> String:
	return "%s/%s.gozen" % [project.path, project.title]

func set_project_path(new_path: String) -> void:
	# Todo: Make certain new_path is not full path
	project.path = new_path


# RESOLUTION  ################################################
func get_resolution() -> Vector2i:
	return project.resolution

func set_resolution(new_resolution: Vector2i) -> void:
	project.resolution = new_resolution
	_on_resolution_change.emit(new_resolution)


# FILES  #####################################################
func get_files() -> Dictionary:
	return project.files

func get_file(id: int) -> File:
	return project.files[id]

func add_file(new_file: File) -> void:
	project.files[project.files_id] = new_file
	project.files_id += 1
