extends Node

signal _on_file_explorer_cancel
signal _on_file_explorer_ok(data)


# File Explorer Modes
enum FE_MODES { OPEN_FILE, OPEN_FILES, OPEN_DIRECTORY }


const PATH_SAVE := "user://module_settings"
const PATH_MODULE := "res://modules/|/%s/|.tscn"


## Modules dictionary
##
## Contains the selected module information for each module type
## and all the available modules which get updated on startup.
var modules := {
	command_bar = {
		"selected": "default",
		"available": ["default"]
	},
	editor = {
		"selected": "default",
		"available": ["default"]
	},
	effects_view = {
		"selected": "default",
		"available": ["default"]
	},
	media_pool = {
		"selected": "default",
		"available": ["default"]
	},
	file_explorer = {
		"selected": "default",
		"available": ["default"]
	},
	project_view = {
		"selected": "default",
		"available": ["default"]
	},
	startup = {
		"selected": "default",
		"available": ["default"]
	},
	status_bar = {
		"selected": "default",
		"available": ["default"]
	},
	timeline = {
		"selected": "default",
		"available": ["default"]
	},
	top_bar = {
		"selected": "default",
		"available": ["default"]
	},
}


## Setting up the Module Manager
##
## First we check the available and afterwards we save/load
## the data according to wether the save file exists or not.
func _ready() -> void:
	_get_available()
	_load() if FileAccess.file_exists(PATH_SAVE) else _save()


## Saving selected modules
##
## We only need the 'selected' information as the available
## modules get found on startup anyway and should be up to date.
func _save() -> void:
	var selected_data := {}
	for module in modules:
		selected_data[module] = modules[module].selected
	FileManager.save_data(selected_data, PATH_SAVE)


## Loading selected modules from save file
##
## We first check if the module is still available or not,
## if not we change the value to "default".
func _load() -> void:
	var data: Dictionary = str_to_var(FileManager.load_data(PATH_SAVE))
	for module in data:
		if !modules.has(module):
			return
		var available := (modules[module].available as Array).has(data[module])
		modules[module].selected = data[module] if available else "default"


## Getting the module node
##
## This function takes the information from the modules dic
## and returns the module for the specified module type.
func get_module(module: String) -> Node:
	return load(PATH_MODULE.replace('|', module) % modules[module].selected).instantiate()

## Getting all available modules
##
## It is important that we get all modules from the start.
## Else get_module() won't be functioning properly and
## cause crashes. It would be helpful to still have a check
## inside of get_module() just in case, but thats a TODO
## for later.
func _get_available() -> void:
	var error: int
	# Check if the modules dir exists
	var dir := DirAccess.open("user://")
	if !dir.dir_exists("modules"):
		error = dir.make_dir("modules")
		printerr("Could not make 'modules' dir!\n\tError: %s" % error)
	
	# Create missing modules folders if needed and
	# gets all available modules
	dir.change_dir("modules")
	for module in modules:
		if !dir.dir_exists(module):
			error = dir.make_dir(module)
			printerr("Could not make '%s' dir!\n\tError: %s" % [module, error])
		dir.change_dir(module)
		for file in dir.get_files():
			# TODO: Check if file has correct extension.
			modules[module].available.append(file)
		dir.change_dir("..")


# FILE EXPLORER STUFF  #######################################

func open_file_explorer(mode: FE_MODES, title: String, extensions: Array = []) -> void:
	var explorer = get_module("file_explorer")
	get_tree().current_scene.add_child(explorer)
	explorer.open(mode, title, extensions)
