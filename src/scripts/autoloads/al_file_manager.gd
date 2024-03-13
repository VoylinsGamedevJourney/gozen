extends Node
## File Manager
##
## Config structure:
## [general]
##   files: {unique_file_id: {file_class_data}}
##   folders: {folder_name: {files = [file_id's], sub_folders = [...]}}


var config := ConfigFile.new()


func _ready():
	var config_path: String = ProjectSettings.get_setting("globals/path/file_manager")
	if FileAccess.file_exists(config_path):
		config.load(config_path)
	else:
		init_folder_root()


func save_config() -> void:
	config.save(ProjectSettings.get_setting("globals/path/file_manager"))


func add_file(file_path: String, folder: String, global: bool = false) -> void:
	if global:
		
		save_config()


func remove_file(path: String, global: bool = false) -> void:
	if global:
		save_config()


func init_folder_root() -> void:
	config.set_value("general", "folders", {"folder_name": "root", "sub_folders": [], "files": []})
	save_config()


func add_folder(path: String, global: bool = false) -> void:
	if global:
		save_config()


func remove_folder(path: String, global: bool = false) -> void:
	# TODO: Remove files if necesarry
	if global:
		save_config()


func get_files() -> Dictionary:
	## For getting global files
	return config.get_value("general", "files", {})


func get_folders() -> Dictionary:
	## For getting global folders
	return config.get_value("general", "folders")
