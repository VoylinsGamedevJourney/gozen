extends Node


func _ready():
	var dir := DirAccess.open("user://")
	var settings_path := "globals/path/modules/%s"
	var types := ["layout_modules", "modules", "effects", "transitions", "render_profiles"]
	
	# Load all custom modules
	for type: String in types:
		var _path: String = ProjectSettings.get_setting(settings_path % type)
		if !dir.dir_exists(_path):
			dir.make_dir(_path)
			continue
		dir = dir.open(_path)
		for pck_file: String in dir.get_files():
			ProjectSettings.load_resource_pack(pck_file, false)
	
	# Check if all modules have an info resource
	for type: String in types:
		dir = dir.open("res://%s" % type)
		var mod_dirs := dir.get_directories()
		var mod_res := dir.get_files()
		
		# Checking for mod configs
		for mod: String in mod_res:
			if not mod.trim_suffix(".tres") in mod_dirs:
				Printer.error("No folder for config '%s'!" % mod)
				get_tree().quit() # TODO: Handle this better
		
		# Checking for mod folders
		for mod: String in mod_dirs:
			if not mod + ".tres" in mod_res:
				Printer.error("No config for mod folder '%s'!" % mod)
				get_tree().quit() # TODO: Handle this better
