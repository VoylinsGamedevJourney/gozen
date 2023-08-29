extends Node
## Project Manager
##
## Here all signals and functions are located which have to
## do with the the project data.

signal _on_open_project_settings

signal _on_project_loaded
signal _on_unsaved_changes
signal _on_saved

signal _on_title_changed(new_title)
signal _on_resolution_changed(new_resolution)
signal _on_file_added(new_file)


const PATH_RECENT_PROJECTS := "user://recent_projects"


## The "project" var is a Project class variable
##
## The Project class basically has all the variables inside
## of it, all functions to handle those vars are here in the
## autoload for handling project related stuff.
var project: Project:
	set(x):
		project = x
		_on_project_loaded.emit()


## Check for keyboard shortcuts
##
## At this moment only used for the save shortcut.
func _input(event: InputEvent) -> void:
	if event.is_action_pressed("save_project"):
		Logger.ln("Saving project shortcut pressed")
		save_project()


func load_project(project_path: String) -> void:
	Logger.ln("Loading project from path '%s'" % project_path)
	var data: String = FileManager.load_data(get_full_project_path())
	if data != "": # TODO: Improve this check (sometimes data is invalid but not "")
		project = str_to_var(data)
	print("Project not at path: '%s'" % project_path)
	erase_recent_project(project_path)
	return


func save_project() -> void:
	if project == null:
		Logger.ln("Can't save project as 'project' is null")
		return # No project here so nothing to save
	Logger.ln("Saving project")
	if project.path != "": # Existing project
		FileManager.save_data(project, get_full_project_path())
	# New project
	ModuleManager.open_file_explorer(
			ModuleManager.FE_MODES.OPEN_FILE, "Select save path for project", ["*.gozen"])
	ModuleManager._on_file_explorer_ok.connect(_on_new_project_path_selected)
	return


func _on_new_project_path_selected(new_path: String) -> void:
	Logger.ln("New project path '%s'" % new_path)
	project.title = new_path.split("/")[-1].replace(".gozen",'')
	project.path = new_path.replace("%s.gozen" % project.title, '')
	add_recent_project(project.path)
	save_project()


##############################################################
# Recent Projects  ###########################################
##############################################################

func get_recent_projects() -> Array:
	Logger.ln("Getting array of recent projects")
	if !FileAccess.file_exists(PATH_RECENT_PROJECTS):
		FileManager.save_data([], PATH_RECENT_PROJECTS)
	return str_to_var(FileManager.load_data(PATH_RECENT_PROJECTS))


func add_recent_project(project_path: String) -> void:
	Logger.ln("Adding '%s' to recent projects" % project_path)
	var recent_projects: Array = [project_path]
	var old_recent_projects := get_recent_projects()
	old_recent_projects.erase(project_path)
	recent_projects.append_array(old_recent_projects)
	FileManager.save_data(recent_projects, PATH_RECENT_PROJECTS)


func erase_recent_project(project_path: String) -> void:
	Logger.ln("Erasing '%s' from recent projects" % project_path)
	var recent_projects := get_recent_projects()
	recent_projects.erase(project_path)
	FileManager.save_data(recent_projects, PATH_RECENT_PROJECTS)


##############################################################
# Getters and setters  #######################################
##############################################################

# TITLE  #####################################################

func get_title() -> String:
	Logger.ln("Getting project title") 
	return project.title


func set_title(new_title: String) -> void:
	Logger.ln("Setting project title to '%s'" % new_title) 
	# TODO: Remove invalid chars
	project.title = new_title
	ProjectManager._on_title_change.emit(new_title)


# PATH  ######################################################

func get_project_path() -> String:
	Logger.ln("Getting project path") 
	return project.path


func get_full_project_path() -> String:
	Logger.ln("Getting full project path") 
	return "%s/%s.gozen" % [project.path, project.title]


func set_project_path(new_path: String) -> void:
	Logger.ln("Setting project path to '%s'" % new_path) 
	# If new_path is "", it means the project will try to save under a new path
	# Todo: Make certain new_path is not full path
	project.path = new_path


# RESOLUTION  ################################################

func get_resolution() -> Vector2i:
	Logger.ln("Getting project resolution") 
	return project.resolution


func set_resolution(new_resolution: Vector2i) -> void:
	Logger.ln("Setting project resolution to '%s'" % new_resolution) 
	project.resolution = new_resolution
	_on_resolution_changed.emit(new_resolution)


# FILES  #####################################################

func get_files() -> Dictionary:
	Logger.ln("Getting project files") 
	return project.files


func get_file(id: int) -> File:
	Logger.ln("Getting project file with id '%s'" % id) 
	return project.files[id]


func add_file(new_file: File) -> void:
	Logger.ln("Adding new project file with id '%s'" % project.files_id) 
	project.files[project.files_id] = new_file
	project.files_id += 1
	_on_file_added.emit(new_file)
