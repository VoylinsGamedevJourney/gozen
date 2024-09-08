extends DataManager


enum MENU {
	SETTINGS_EDITOR,
	SETTINGS_PROJECT,
}

const PATH: String = "user://module_settings"
const MODULE_DATA_PATH: String = "user://module_data/"
const MODULES_PATH: String = "res://modules/"


var _modules: Dictionary = {}


var layouts: PackedStringArray = []
var modules: Dictionary = { # Selected modules to use
	MENU.SETTINGS_EDITOR: "default_editor_settings_menu-0",
	MENU.SETTINGS_PROJECT: "default_project_settings_menu-0"
}


func _ready() -> void:
	GoZenServer.add_loadables_to_front([
		Loadable.new("Checking modules", _check_modules),
		Loadable.new("Load module data", load_data),
	])


func _check_modules() -> void:
	var module_types: PackedStringArray = DirAccess.get_directories_at(MODULES_PATH)
	for l_type: String in module_types:
		for l_module_name: String in DirAccess.get_directories_at(MODULES_PATH + l_type):
			var l_path: String = MODULES_PATH + "%s/%s/module.tres" % [l_type, l_module_name] 
			if !FileAccess.file_exists(l_path):
				printerr("Couldn't find module resource! ", l_path)
				continue
			
			var l_module: Module = load(l_path)
			if l_module.title == "": 
				printerr("No title set! ", l_path)
			elif l_module.icon == null:
				printerr("No icon set! ", l_path)
			elif l_module.scene == null:
				printerr("No scene set! ", l_path)
			else:
				_modules["%s/%s" % [l_type, l_module_name]] = l_module



func load_data() -> void:
	if FileAccess.file_exists(PATH):
		if _load_data(PATH):
			printerr("Loading data for ModuleManager failed!")
	else:
		# Setting default main panels
		layouts.append_array([
			"default_editor_panel-0",
			"default_render_panel-0",
		])
		if _save_data(PATH):
			printerr("Saving data for ModuleManager failed!")
		


func open_popup(_menu: MENU) -> void:
	print("STILL WIP")


func create_module_id(a_module_name: String) -> String:
	var l_name: String = "%s-%s" % [a_module_name, randi_range(100000,999999)]
	while l_name in DirAccess.get_files_at(MODULE_DATA_PATH):
		l_name = "%s-%s" % [a_module_name, randi_range(100000,999999)]
	return l_name


func get_layout_scene(l_id: int) -> PackedScene:
	return _modules["layouts/" + layouts[l_id].get_slice('-', 0)].scene


func get_layout_icon(l_id: int) -> Texture2D:
	return _modules["layouts/" + layouts[l_id].get_slice('-', 0)].icon


func get_layout_title(l_id: int) -> String:
	return _modules["layouts/" + layouts[l_id].get_slice('-', 0)].title

