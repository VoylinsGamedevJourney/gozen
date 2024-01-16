extends Node
## Project Manager

#region Signals
signal _on_project_loaded
signal _on_project_saved
signal _on_unsaved_changes

signal _on_title_changed(new_title)
signal _on_resolution_changed(new_resolution)
signal _on_framerate_changed(new_framerate)
signal _on_files_changed(new_files)
#endregion


const PATH_RECENT_PROJECTS := "user://recent_projects"
const PATH_MENU_CFG := "user://project_settings_data.cfg"


var config := ConfigFile.new()

var project_title : String
var project_path  : String


func _ready() -> void:
	if OS.has_feature("editor"):
		print("check")
		return
	var arguments := get_startup_arguments()
	load_defaults()
	load_settings(arguments)


###############################################################
#region Startup  ##############################################
###############################################################

func get_startup_arguments() -> Dictionary:
	var arguments = {}
	for argument: String in OS.get_cmdline_args():
		if argument.find("=") > -1:
			var key_value = argument.split("=")
			arguments[key_value[0].lstrip("--")] = key_value[1]
	
	# Check if file got opened with the editor directly, first (only) should be project path
	if arguments.size() == 2 and OS.get_cmdline_args()[1].contains(".gozen"):
		project_path = OS.get_cmdline_args()[1]
		arguments.type = "open"
		return arguments
	elif !arguments.has("type"):
		printerr("No project path given as argument, nor type given!")
		get_tree().quit()
	return {}


## Only for the settings
func load_defaults() -> void:
	var settings := {
		"general": [
			"project_title",
			"project_path",
			"resolution",
			"framerate",
		]
	}
	
	# Generate defaults + settings menu config file
	var settings_menu_config := ConfigFile.new()
	for section: String in settings:
		for setting: String in settings[section]:
			var setting_meta: Dictionary = call("get_%s_meta" % setting)
			call("set_%s" % setting, call("get_%s_meta" % setting).default)
			settings_menu_config.set_value(section, setting, setting_meta)
	settings_menu_config.save(PATH_MENU_CFG)


func load_settings(arguments: Dictionary) -> void:
	match arguments.type:
		"open":
			project_title = arguments.project_path.split('/')[-1].replace(".gozen", "")
			project_path  = arguments.project_path
		"new":
			project_title = arguments.title
			project_path = arguments.project_path
			config.set_value("general", "resolution", arguments.resolution)
		_:
			printerr("Invalid type '%s'!" % arguments.type)
			get_tree().quit()
	
	# Loading actual data file 
	if !FileAccess.file_exists(project_path):
		# When no file exists, create new file
		config.save(project_path)
		_on_project_loaded.emit()
		return
	# Load in user defined settings
	var user_config := ConfigFile.new()
	user_config.load(project_path)
	for section: String in user_config.get_sections():
		for setting in user_config.get_section_keys(section):
			if config.has_section_key(section, setting):
				config.set_value(section, setting, user_config.get_value(section, setting))
	config.save(project_path)
	_on_project_loaded.emit()

#endregion
###############################################################
#region Input handler  ########################################
###############################################################

func _input(event: InputEvent) -> void:
	if event.is_action_pressed("save_project"):
		save_project()


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


###############################################################
##
##     GETTERS AND SETTERS
##
###############################################################

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

func set_resolution(new_value: Vector2i) -> void:
	config.set_value("general", "resolution", new_value)
	_on_resolution_changed.emit(new_value)


func get_resolution() -> Vector2i:
	return config.get_value("general", "resolution", get_resolution_meta().default)


func get_resolution_meta() -> Dictionary:
	return {
		"default": Vector2i(1920, 1080),
		"type": "vector2i"
		# TODO
	}

#endregion
###############################################################
#region Framerate  ############################################
###############################################################

func set_framerate(new_value: Vector2i) -> void:
	config.set_value("general", "framerate", new_value)
	_on_framerate_changed.emit(new_value)


func get_framerate() -> float:
	return config.get_value("general", "framerate", get_framerate_meta().default)


func get_framerate_meta() -> Dictionary:
	return {
		"default": 30,
		"type": "float",
		"step": 0.1,
		"min_value": 1,
		"max_value": 240
	}

#endregion
###############################################################


###############################################################
##
##     FILES HANDLER
##
###############################################################

func add_file(file: DefaultFile) -> void:
	var data := file.get_data()

#endregion
###############################################################
