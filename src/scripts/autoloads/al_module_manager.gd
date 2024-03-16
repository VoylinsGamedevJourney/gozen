extends Node
## Module manager
##
## This autoload is responsible for loading in and checking all custom modules
## to make certain they were made correctly. 

const types := ["layout_modules", "modules", "effects", "transitions", "render_profiles"]


func _ready() -> void:
	## Creating necessary structures and loading/checking all custom modules
	_create_folder_structure()
	_load_custom_modules()
	_check_custom_modules()


func _create_folder_structure() -> void:
	## Function for creating the folders for saving module configs to and
	## for creating the folders to save custom modules in to load on startup.
	var existing_folders := DirAccess.get_directories_at("user://")
	for folder_type: String in types:
		var paths: PackedStringArray = [
			ProjectSettings.get_setting("globals/path/configs/%s" % folder_type),
			ProjectSettings.get_setting("globals/path/modules/%s" % folder_type)] 
		for path: String in paths:
			if not path in existing_folders:
				DirAccess.make_dir_absolute(path)


func _load_custom_modules() -> void:
	## Loading custom modules from the user file system at 'user://*'
	for type: String in types:
		var module_folder: String = ProjectSettings.get_setting("globals/path/modules/%s" % type)
		var module_files := DirAccess.get_files_at(module_folder)
		if module_files.size() == 0:
			continue # Skipping when no modules are present
		for module: String in module_files:
			ProjectSettings.load_resource_pack(module_folder + module, false)


func _check_custom_modules() -> void:
	## Check if all modules have an 'info' resource
	for type: String in types:
		var module_folders := DirAccess.get_directories_at("res://_%s" % type)
		for module_folder: String in module_folders:
			if !FileAccess.file_exists("res://_%s/%s/info.tres" % [type, module_folder]):
				Printer.error("No info file found for mod folder '%s'!" % module_folder)


func get_config_path(type: String, instance_name: String) -> String:
	return "%s%s.cfg" % [
		ProjectSettings.get_setting("globals/path/configs/%s" % type), 
		instance_name]


func remove_config_layout(type: String, instance_name: String) -> void:
	DirAccess.remove_absolute("%s%s.cfg" % [
		ProjectSettings.get_setting("globals/path/configs/%s" % type), 
		instance_name])
