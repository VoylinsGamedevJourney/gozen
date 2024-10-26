extends DataManager


enum {
	MENU_EDITOR_SETTINGS = 1,
	MENU_PROJECT_SETTINGS = 2,
	MENU_CUSTOM = 99,

	PANEL_VIEW = 101,
	PANEL_FILES = 102,
	PANEL_EFFECTS = 103,
	PANEL_TIMELINE = 104,
	PANEL_CUSTOM = 199,

	EXTRA_MODULE_CUSTOM = 999,
}

const PATH_SETTINGS: String = "user://modules_settings"

const PATH_MODULES_DATA: String = "user://modules_data/"
const PATH_CUSTOM_MODULES: String = "user://modules/"

const PATH_MODULES_SCENES: String = "res://modules/"



var modules: Dictionary = {}
var _existing_modules: Dictionary = {}



func _ready() -> void:
	CoreLoader.append_to_front("Load module data", load_data)
	CoreLoader.append_to_front("Checking modules", _check_modules)
	CoreLoader.append_to_front("Load custom modules", _load_custom_modules)


func save_data() -> void:
	_save_data_err(PATH_SETTINGS, "Saving data for CoreModules failed!")


func load_data() -> void:
	if FileAccess.file_exists(PATH_SETTINGS):
		_load_data_err(PATH_SETTINGS, "Loading data for CoreModules failed!")
	else:
		modules = {
			MENU_EDITOR_SETTINGS: "default_editor_settings_menu",
			MENU_PROJECT_SETTINGS: "default_project_settings_menu",

			PANEL_VIEW: "default_view_panel",
			PANEL_FILES: "default_files_panel",
			PANEL_EFFECTS: "default_effects_panel",
			PANEL_TIMELINE: "default_timeline_panel",
		}
		save_data()


func _check_modules() -> void:
	for l_type: String in DirAccess.get_directories_at(PATH_MODULES_SCENES):
		for l_module: String in DirAccess.get_directories_at(PATH_MODULES_SCENES + l_type):
			var l_path: String = PATH_MODULES_SCENES + "%s/%s/module.tres" % [l_type, l_module] 

			if !FileAccess.file_exists(l_path):
				printerr("Couldn't find module resource! ", l_path)
				continue
			
			var l_module_node: Module = load(l_path)
			if _check_module(l_module_node):
				_existing_modules[l_module] = l_module_node
			else:
				printerr("Module '%s' has incomplete data!" % l_module)

	
func _check_module(a_module: Module) -> bool:
	if a_module == null:
		return false

	return !(a_module.title == "" or a_module.icon == null or a_module.scene == null)


func _load_custom_modules() -> void:
	# TODO: Implement this!
	# The way it should work is to first check the files PATH_MODULES_DATA, to
	# see if the pck files don't override already existing files, and to see if
	# they don't add anything outside of their modules folder.
	# If everything checks out we can add it to the project, but we also need to
	# run _check_module on it's Module file!
	print("Loading custom modules isn't implemented yet!")


func _create_module_id(a_module_name: String) -> String:
	var l_name: String = "%s-%s" % [a_module_name, randi_range(100000,999999)]

	while l_name in DirAccess.get_files_at(PATH_MODULES_DATA):
		l_name = "%s-%s" % [a_module_name, randi_range(100000,999999)]

	return l_name


func _check_existence(a_name: String) -> bool:
	if a_name not in _existing_modules.keys():
		printerr("Requested module does not exist!")
		return false

	if a_name.contains('-'):
		printerr("Module names can't have an '-', if it has one it could indicate that this is an existing module!")
		return false

	return true


func create_new_menu_instance(a_menu_name: String) -> Popup:
	if _check_existence(a_menu_name):
		var l_scene: PackedScene = _existing_modules[a_menu_name].scene
		var l_instance: Popup = l_scene.instantiate()

		l_instance.name = _create_module_id(a_menu_name)

		return l_instance
	return null


func create_new_menu_instance_from_id(a_id: int) -> Popup:
	if modules.has(a_id):
		var l_module_name: String = modules[a_id]
		return create_new_menu_instance(l_module_name)

	printerr("No saved setting for module id '%s'!" % a_id)
	return null


func create_new_panel_instance(a_panel_name: String) -> Control:
	if _check_existence(a_panel_name):
		var l_scene: PackedScene = _existing_modules[a_panel_name].scene
		var l_instance: Control = l_scene.instantiate()

		l_instance.name = _create_module_id(a_panel_name)

		return l_instance
	return null


func create_new_panel_instance_from_id(a_id: int) -> Control:
	if modules.has(a_id):
		var l_module_name: String = modules[a_id]
		return create_new_panel_instance(l_module_name)

	printerr("No saved setting for module id '%s'!" % a_id)
	return null


func create_new_extra_module_instance(a_name: String) -> Control:
	if _check_existence(a_name):
		var l_scene: PackedScene = _existing_modules[a_name].scene
		var l_instance: Control = l_scene.instantiate()

		l_instance.name = _create_module_id(a_name)

		return l_instance
	return null


func create_new_extra_module_instance_from_id(a_id: int) -> Control:
	if modules.has(a_id):
		var l_module_name: String = modules[a_id]
		return create_new_extra_module_instance(l_module_name)

	printerr("No saved setting for module id '%s'!" % a_id)
	return null


func get_existing_menu_instance(a_menu_name: String) -> Popup:
	if _check_existence(a_menu_name.get_slice('-', 0)):
		var l_scene: PackedScene = _existing_modules[a_menu_name.get_slice('-', 0)].scene
		var l_instance: Popup = l_scene.instantiate()

		l_instance.name = a_menu_name

		return l_instance
	return null


func get_existing_panel_instance(a_panel_name: String) -> Control:
	if _check_existence(a_panel_name.get_slice('-', 0)):
		var l_scene: PackedScene = _existing_modules[a_panel_name.get_slice('-', 0)].scene
		var l_instance: Control = l_scene.instantiate()

		l_instance.name = a_panel_name

		return l_instance
	return null


func get_existing_extra_module_instance(a_name: String) -> Control:
	if _check_existence(a_name.get_slice('-', 0)):
		var l_scene: PackedScene = _existing_modules[a_name.get_slice('-', 0)].scene
		var l_instance: Control = l_scene.instantiate()

		l_instance.name = a_name

		return l_instance
	return null

