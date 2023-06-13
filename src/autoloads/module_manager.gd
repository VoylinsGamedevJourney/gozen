extends Node

const USER_DATA_PATH := "user://module_user_data.dat"
const USER_CUSTOM_MODULES_PATH := "user://modules/"

# TODO: Add a way for people to select their module name for each module type
# Empty = default
var user_data := {}


func _ready() -> void:
	# Checking to see if the modules dir exists
	var dir := DirAccess.open("user://")
	if !dir.dir_exists(USER_CUSTOM_MODULES_PATH): 
		dir.make_dir(USER_CUSTOM_MODULES_PATH)
	
	_load_custom_modules()
	load_user_module_data()


func get_module(module_type: String) -> Node:
	var module_path := "res://modules/%s/%s/%s.tscn"
	var module_name := _get_module_name(module_type)
	# TODO: if module_name isn't default and custom module can not be found,
	# change module_name to default, give a warning to the user and save 
	# user_data with that entry removed from user_data so it's back to default.
	module_path = module_path % [module_type, module_name, module_type]
	
	var module := load(module_path)
	return module.instantiate()


## Gets the user selected module name for the correct module type
func _get_module_name(module_type: String) -> String:
	if user_data.has(module_type):
		return user_data[module_type]
	return "default"


func save_user_module_data() -> void:
	var file := FileAccess.open_compressed(USER_DATA_PATH, FileAccess.WRITE)
	file.store_var(user_data)
	file.close()


func load_user_module_data() -> void:
	if !FileAccess.file_exists(USER_DATA_PATH):
		save_user_module_data()
		return
	var file := FileAccess.open_compressed(USER_DATA_PATH, FileAccess.READ)
	user_data = file.get_var()
	file.close()


func add_module() -> void:
	# TODO: Give option for users to add modules
	pass


func _load_custom_modules() -> void:
	# TODO: Load custom modules on startup
	var dir := DirAccess.open(USER_CUSTOM_MODULES_PATH)
	for module_dir in dir.get_directories():
		print(module_dir) # TODO: Requires more work
		# Maybe just look for all pck files and load them in directly
	pass

