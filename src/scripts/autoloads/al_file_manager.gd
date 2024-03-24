extends Node
## File Manager

var folder_data := {} # Full_path: Array of files
var file_data   := {} # File_id: File class object
var current_id := 0 # File ID's for global start with 'G_' and for project with 'P_'


func _ready():
	## Loading data on startup if exists
	if FileAccess.file_exists(Globals.PATH_FILE_MANAGER):
		var file := FileAccess.open(Globals.PATH_FILE_MANAGER, FileAccess.READ)
		var temp: Dictionary = str_to_var(file.get_as_text())
		folder_data = temp.folder_data
		file_data = temp.file_data
		current_id = temp.current_id


func save_data() -> void:
	var file := FileAccess.open(Globals.PATH_FILE_MANAGER, FileAccess.WRITE)
	file.store_string(var_to_str({
		"folder_data": folder_data, 
		"file_data": file_data,
		"current_id": current_id}))


func add_file(file: File, folder: String, _file_data: Dictionary, _folder_data: Dictionary, _current_id: int) -> void:
	var prefix := "G_%s" if _folder_data == folder_data else "P_%"
	_file_data[prefix % _current_id] = file
	if !_folder_data.has(folder):
		add_folder(folder, _folder_data)
	_folder_data[folder].append(prefix % _current_id)
	_current_id += 1
	if _folder_data == folder_data:
		save_data()


func add_folder(folder_path: String, _folder_data: Dictionary) -> void:
	_folder_data[folder_path] = PackedStringArray()
	if _folder_data == _folder_data:
		save_data()


func remove_file(folder: String, file_id: String, _file_data: Dictionary, _folder_data: Dictionary) -> void:
	_file_data.erase(file_id)
	_folder_data[folder].erase(file_id)
	if _folder_data == folder_data:
		save_data()


func remove_folder(folder_path: String, _file_data: Dictionary, _folder_data: Dictionary) -> void:
	# Getting all subfolders so we can delete them whilst making list of all files
	var file_ids: PackedStringArray = []
	for folder: String in _folder_data:
		if folder_path in folder:
			file_ids.append_array(_folder_data[folder])
			_folder_data.erase(folder)
	# Deleting all files from the deleted folder and subfolders
	for file_id: String in file_ids:
		_file_data.erase(file_id)
	if _folder_data == folder_data:
		save_data()
