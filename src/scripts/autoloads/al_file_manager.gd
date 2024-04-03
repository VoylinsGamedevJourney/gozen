extends Node
## File Manager

var folder_data := {} # Full_path: Array of files
var files_data   := {} # File_id: File class object
var current_id := 0 # File ID's for global start with 'G_' and for project with 'P_'


func _ready() -> void:
	## Loading data on startup if exists
	if FileAccess.file_exists(Globals.PATH_FILE_MANAGER):
		var l_file: FileAccess = FileAccess.open(Globals.PATH_FILE_MANAGER, FileAccess.READ)
		var l_temp: Dictionary = str_to_var(l_file.get_as_text())
		
		folder_data = l_temp.folder_data
		files_data = l_temp.file_data
		current_id = l_temp.current_id


func get_files_data(a_global: bool) -> Dictionary:
	return FileManager.files_data if a_global else ProjectManager.files_data


func get_folder_data(a_global: bool) -> Dictionary:
	return FileManager.folder_data if a_global else ProjectManager.folder_data


func save_data(a_global: bool) -> void:
	if !a_global:
		ProjectManager.unsaved_changes = true
		return
	
	var file := FileAccess.open(Globals.PATH_FILE_MANAGER, FileAccess.WRITE)
	var l_data: Dictionary = {
		"folder_data": folder_data,
		"files_data": files_data,
		"current_id": current_id }
	
	file.store_string(var_to_str(l_data))


func add_file_actual(a_file_path: String, a_folder: String, a_global: bool) -> String:
	# Creating of the file id
	var l_prefix: String = "G_%s" if a_global else "P_%s"
	var l_file_id: String = l_prefix % (current_id if a_global else ProjectManager.current_id)
	
	# Creating the File object
	match FileActual.get_file_type(a_file_path):
		File.TYPE.VIDEO: get_files_data(a_global)[l_file_id] = FileVideo.new(a_file_path)
		File.TYPE.AUDIO: get_files_data(a_global)[l_file_id] = FileAudio.new(a_file_path)
		File.TYPE.IMAGE: get_files_data(a_global)[l_file_id] = FileImage.new(a_file_path)
		_: 
			Printer.error(Globals.ERROR_INVALID_FILE_TYPE % a_file_path)
			return ""
	
	if !get_folder_data(a_global).has(a_folder):
		add_folder(a_folder, a_global)
	
	get_folder_data(a_global)[a_folder].append(l_file_id)
	
	if a_global:
		current_id += 1
	else:
		ProjectManager.current_id += 1
	
	save_data(a_global)
	return l_file_id


func add_folder(a_folder_path: String, a_global: bool) -> void:
	var l_folder_data := get_folder_data(a_global)
	l_folder_data[a_folder_path] = PackedStringArray()
	save_data(a_global)


func remove_file(a_folder: String, a_file_id: String, a_global: bool) -> void:
	var l_folder_data := get_folder_data(a_global)
	var l_files_data := get_files_data(a_global)
	
	l_files_data.erase(a_file_id)
	l_folder_data[a_folder].erase(a_file_id)
	
	save_data(a_global)


func remove_folder(a_folder_path: String, a_global: bool) -> void:
	# Getting all subfolders so we can delete them whilst making list of all files
	var l_folder_data := get_folder_data(a_global)
	var l_files_data := get_files_data(a_global)
	var l_file_ids: PackedStringArray = []
	
	# Deleting all files from the deleted folder and subfolders
	for l_folder: String in l_folder_data:
		if a_folder_path in l_folder:
			l_file_ids.append_array(l_folder_data[l_folder])
			l_folder_data.erase(l_folder)
	
	for l_file_id: String in l_file_ids:
		l_files_data.erase(l_file_id)
	
	save_data(a_global)


func get_file_obj(a_file_id: String, a_global: bool) -> File:
	return get_files_data(a_global)[a_file_id]
