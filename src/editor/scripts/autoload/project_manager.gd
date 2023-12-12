extends Node
## Project Manager
##
## Here all data related to the actual project is being stored and 
## handled. Remember to always use the setter and getter functions 
## when dealing with this data.
##
## TODO: Change out the FileDialog by native or custom one in the future

#region Signals
signal _on_project_loaded
signal _on_project_saved
signal _on_unsaved_changes

signal _on_title_changed(new_title)
signal _on_resolution_changed(new_resolution)
signal _on_framerate_changed(new_framerate)
#endregion

#region variable
const PATH_RECENT_PROJECTS := "user://recent_projects"


var project_title : String
var project_path  : String
var resolution : Vector2i
var framerate: float = 30.0
#endregion


## On startup we need to check the arguments to see what needs to happen.
## If arguments are correct, we either load the project file, or set
## the variable to the argument values to create a new project.
func _ready() -> void:
	if OS.has_feature("editor"):
		print("Running from Godot editor")
		return
	
	# Getting all custom arguments which were passed from startup
	var arguments = {}
	for argument: String in OS.get_cmdline_args():
		if argument.find("=") > -1:
			var key_value = argument.split("=")
			arguments[key_value[0].lstrip("--")] = key_value[1]
	
	# Check if file got opened with the editor directly
	if arguments.size() == 0:
		# First argument should be the file path
		var path: String = OS.get_cmdline_args()[0]
		load_project(path)
		return
	elif !arguments.has("type"):
		printerr("No project path given as argument, nor type given!")
		get_tree().quit()
	
	match arguments.type:
		"open":
			load_project(arguments.project_path)
		"new":
			project_title = arguments.title
			resolution = arguments.resolution
		_:
			printerr("No valid type detected!\n\t'%s' is not a valid type!" % arguments.type)
			get_tree().quit()


###############################################################
#region Data handlers  ########################################
###############################################################

func _input(event: InputEvent) -> void:
	if event.is_action_pressed("save_project"):
		save_project()


func load_project(path: String) -> void:
	# Check to see if path actually exists
	if !FileAccess.file_exists(path):
		printerr("No valid file found at given path '%s'!" % path)
		get_tree().quit()
	
	# Check if file extension is correct or not
	if project_path.split('.')[-1].to_lower() != "gozen":
		printerr("File path '%s' does not have '.gozen' extension!" % path)
		get_tree().quit()
	
	# If checks are successful, open file and load data
	var file := FileAccess.open(path, FileAccess.READ)
	var data: Dictionary = file.get_var()
	for key: String in data:
		if get(key): # Check if variable still exists or not
			set(key, data[key])
	
	_on_project_loaded.emit()
	update_recent_project()


func save_project(add_to_recent: bool = false) -> void:
	if project_path.is_empty():
		var explorer := FileDialog.new()
		explorer.title = tr("FILE_EXPLORER_TITLE_SELECT_FOLDER")
		explorer.file_mode = FileDialog.FILE_MODE_OPEN_ANY
		explorer.cancel_button_text = tr("FILE_EXPLORER_CLOSE")
		explorer.ok_button_text = tr("FILE_EXPLORER_SELECT")
		explorer.file_selected.connect(func(value: String): 
				project_path = value
				save_project(true))
		explorer.dir_selected.connect(func(value: String):
				project_path = "%s/%s.gozen" % [value, project_title]
				save_project(true))
		get_tree().root.add_child(explorer)
		explorer.popup_centered(Vector2i(700,600))
	
	# Save the actual data
	var data: Dictionary = {}
	for x: Dictionary in get_property_list():
		if x.usage == 4096:
			data[x.name] = get(x.name)
	var file := FileAccess.open(project_path, FileAccess.WRITE)
	file.store_var(data, false)
	
	_on_project_saved.emit()
	
	if add_to_recent:
		update_recent_project()


## Updates the recent projects file with current project in first place.
## Checking if recent projects file is correct and if previously added
## projects still exists and if there are no duplicates is being checked
## by the startup window. 
func update_recent_project() -> void:
	const PATH := "user://recent_projects.dat"
	var file := FileAccess.open(PATH, FileAccess.READ)
	var data: String = file.get_as_text()
	data = "%s||%s||%s\n%s" % [
			project_title, 
			project_path, 
			Time.get_datetime_string_from_system(),
			data]
	file = FileAccess.open(PATH, FileAccess.WRITE)
	file.store_string(data)

#endregion
###############################################################

#     GETTERS AND SETTERS     #################################

###############################################################
#region Project title  ########################################
###############################################################

func get_project_title() -> String:
	return project_title


func set_project_title(new_title: String) -> void:
	project_title = new_title
	save_project(true)
	_on_title_changed.emit(project_title)

#endregion
###############################################################
#region Project path  ########################################
###############################################################

func get_project_path() -> String:
	return project_path


func set_project_path(new_path: String) -> void:
	project_path = new_path
	save_project(true)

#endregion
###############################################################
#region Resolution  #################################################
###############################################################

func get_resoltion() -> Vector2i:
	return resolution


func set_size(new_resolution: Vector2i) -> void:
	resolution = new_resolution
	save_project()
	_on_resolution_changed.emit(resolution)

#endregion
###############################################################
#region Framerate  ############################################
###############################################################

func get_framerate() -> float:
	return framerate


func set_framerate(new_framerate: float) -> void:
	framerate = new_framerate
	save_project()
	_on_framerate_changed.emit(framerate)

#endregion
###############################################################
