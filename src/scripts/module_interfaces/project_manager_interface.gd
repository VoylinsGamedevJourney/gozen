class_name ProjectManagerInterface
extends Control

## Project Manager Interface is the core interface for project manager
## modules. 
## 
## The Project Manager is the startup view of the editor. If you want 
## to make your own project manager module, you will be required to 
## use this interace to keep compatibility with the
## default core functionalities of the editor..


## A list which contains all saved projects.
var projects := []


## Initialize project manager:
##
## When a project manager module gets loaded on starup, all currently saved
## project locations will be searched to create the projects list.
func _init() -> void:
	load_projects()


## Loading all saved project paths:
##
## All paths for the created projects get saved into a file.
## This loads in all essential project data which may be 
## useful to use inside of the project manager.
func load_projects() -> void:
	if !FileAccess.file_exists(Globals.PATH_PROJECT_LIST): return
	var file := FileAccess.open_compressed(
		Globals.PATH_PROJECT_LIST, FileAccess.READ)
	if file.get_open_error():
		printerr("Could not open project list file, error: %s" % file.get_open_error())
		return
	var project_paths: PackedStringArray = file.get_var()
	for project_path in project_paths:
		import_project(project_path, false)


## We add an entry to the projects array, and if necesarry we save the data.
func import_project(project_path: String, save_paths: bool = true) -> void:
	projects.append(Project.get_project_manager_data(project_path))
	if save_paths: save_projects()


## When saving we only take the projects paths and put these in a file.
func save_projects() -> void:
	var project_paths: PackedStringArray = []
	for project in projects: project_paths.append(project.p_path)
	var file := FileAccess.open_compressed(Globals.PATH_PROJECT_LIST, FileAccess.WRITE)
	if file.get_open_error():
		printerr("Could not open project list at path: %s\n\tError: %s" % [
			Globals.PATH_PROJECT_LIST, file.get_open_error()])
		return
	file.store_var(project_paths)


## Creates a new project, add it to the project list, and saves the list
func add_project(project_name: String, project_folder: String) -> void:
	var project_data := Project.create_new_project(project_name, project_folder)
	if project_data == {}:
		printerr("Could not create project!")
		return
	projects.append(project_data)
	save_projects()








## Creating a project requires only a name and a location.
## !! Required info may change as the editor evolves !!
func create_project(p_name: String, p_location: String) -> void:
	if !DirAccess.dir_exists_absolute(p_location):
		printerr("'%s' is not a valid directory for a gozen project!")
		return
	
	# Check if project name is valid (no special characters)
	# This is important as Operating Systems don't always
	# accept these characters
	for character in ['<','>',':','"','/','\\','|','?','*']:
		if character in p_name:
			printerr("No special characters are allowed in project names!")
			return
	
	var full_path: String = "%s/%s.gozen" % [p_location, p_name]
	var new_project: Project = Project.new()
	new_project.p_name = p_name
	new_project.p_path = full_path
	new_project.p_creation = TimeManager.date_to_int()
	new_project.p_edit = TimeManager.date_to_int()
	
	var dir := DirAccess.open(p_location)
	if !dir:
		printerr("Could not create file at '%s'!" % full_path)
		printerr("\t# We possibly don't have write access in this folder!")
		return 
	
	if FileAccess.file_exists(full_path):
		printerr("Project file already exists at location '%s'!" % full_path)
		return
	
	new_project.save_project()
	
	# Checking if project with this path has not been added yet
	var file := FileAccess.open_compressed(Globals.PATH_PROJECT_LIST, FileAccess.READ)
	var projects_paths: Array = file.get_var()
	file.close()
	if new_project.p_path in projects_paths:
		printerr("Project with path '%s' is already in the list!" % new_project.p_path)
		return
#
#	projects_list.append(new_project)
#	save_projects_list()
#
#
#func remove_project(project_entry: Project) -> void:
#	projects_list.erase(project_entry)
#	save_projects_list()
#
#
#func remove_missing_projects() -> void:
#	for project in projects_list.duplicate():
#		if project.p_creation == 0: projects_list.erase(project)
#	save_projects_list()


func open_editor_layout(_project: Project) -> void:
	if _project.p_creation == 0:
		printerr("Can't open missing project!")
		return
	get_parent().add_child(ModuleManager.get_module("editor_layout"))
	Globals.current_project = _project
	queue_free()
