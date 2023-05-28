extends Node

const settings_path := "user://settings.dat"

# Save-able data
var projects := [] # List of all saved project paths
var sel_modules := {
	"project_manager": "default"
}


func _ready() -> void:
	if FileAccess.file_exists(settings_path): 
		load_settings()
	else:
		save_settings()
	
	_update_module_tree()


func save_settings() -> void:
	var data := {
		"projects": projects,
		"sel_modules": sel_modules
	}
	var file := FileAccess.open_compressed(settings_path, FileAccess.WRITE)
	file.store_var(data)
	file.close()


func load_settings() -> void:
	var file := FileAccess.open_compressed(settings_path, FileAccess.READ)
	var temp_data: Dictionary = file.get_var()
	file.close()
	for x in temp_data:
		if get(x) != null: set(x, temp_data[x])


func _update_module_tree() -> void:
	# Updating the module paths in user://
	var dir := DirAccess.open("user://")
	if !dir.dir_exists("modules"): dir.make_dir("modules")
	dir.change_dir("modules")
	for module_dir in DirAccess.get_directories_at("res://modules"):
		if !dir.dir_exists(module_dir):
			dir.make_dir(module_dir)
