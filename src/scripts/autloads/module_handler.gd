extends Node

## Handles modules (importing them )
##
## Modules get loaded on startup in the correct folder inside of res. 
## The way that modules get added to the editor is manually by putting them
## in the correct folder or by importing them through the settings.


func _ready() -> void:
	_load_modules()
	
	# On startup we need the project manager to popup
	show_window_module(Globals.MODULES.PROJECT_MANAGER)


func _load_modules() -> void:
	# Loading all modules (pck files)
	var dir := DirAccess.open(Globals.MODULE_USER_PATH)
	var pck_paths := []
	for type in Globals.MODULES.values():
		if !dir.dir_exists(Globals.MODULE_PATHS[type]):
			print("No modules in: %s!" % Globals.MODULE_PATHS[type])
			continue
		dir.change_dir(Globals.MODULE_PATHS[type])
		for module in dir.get_directories():
			pck_paths.append(_get_user_pck_path(type, module))
		dir.change_dir("../")
	for pck_path in pck_paths:
		if !ProjectSettings.load_resource_pack(pck_path):
			printerr("Could not load PCK file at path: %s!" % pck_path)


func import_module(type: Globals.MODULES, pck_path: String) -> void:
	# TODO: Importing modules through settings is not implemented yet.
	var dir := DirAccess.open(Globals.MODULE_USER_PATH)
	dir.change_dir(Globals.MODULE_PATHS[type])
	dir.copy(pck_path, "./")
	_load_modules()


func _get_user_pck_path(pck_type: Globals.MODULES, pck_name: String) -> String:
	var pck_path := Globals.MODULE_USER_PATH
	pck_path += "/%s/" % Globals.MODULE_PATHS[pck_type]
	pck_path += "%s/%s.pck" % [pck_name, pck_name]
	return pck_path


func show_window_module(type: Globals.MODULES) -> void:
	var module_path := Globals.MODULE_RES_PATH
	module_path += "/%s/" % Globals.MODULE_PATHS[type]
	module_path += "%/%.tscn".replace('%', SettingsHandler.selected_modules[type])
	var module_node := load(module_path)
	if module_node == null:
		printerr("Could not load module at path: %s!" % module_path)
	Globals.main.add_child(module_node.instantiate())
