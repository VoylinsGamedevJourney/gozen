extends PanelContainer


var previous_paths: PackedStringArray
var current_path: String

## Don't add extensions for adding files
var extensions: PackedStringArray = [] 
var multi_select: bool = false # TODO: make this work!


func _ready() -> void:
	self.visible = false
	_on_system_path_button_pressed("home")
	show_file_explorer() # TODO: REMOVE THIS LINE


func set_title(title: String) -> void:
	find_child("TitleLabel").text = title
	go_to_folder(current_path)


func add_extension(extension: String) -> void:
	extensions.append(extension)
func add_extensions(array: PackedStringArray) -> void:
	extensions.append_array(array)


func enable_multi_select() -> void:
	multi_select = true


func show_file_explorer() -> void:
	self.visible = true


func _input(event: InputEvent) -> void:
	# Function to go back to the previous folder
	if get_viewport().gui_get_focus_owner() == null and event.is_action_pressed("file_explorer_previous_path"):
		if previous_paths.size() == 0: return
		if previous_paths.size() == 1:
			go_to_folder("/home/%s" % Globals.system_username, true)
		else:
			go_to_folder(previous_paths[-1], true)
			previous_paths.remove_at(previous_paths.size()-1)


func close_file_explorer() -> void:
	self.queue_free()


func go_to_folder(path: String, previous: bool = false) -> void:
	path = path.replace("//","/")
	if !previous and current_path != null:
		previous_paths.append(current_path)
	current_path = path
	%PathLineEdit.text = path
	%ErrorLabel.visible = !DirAccess.dir_exists_absolute(path)
	populate_folder_files()


func populate_folder_files() -> void:
	for item in %FoldersFileContent.get_children(): item.queue_free()
	if !DirAccess.dir_exists_absolute(current_path):
		return printerr("Folder does not exist")
	var dir := DirAccess.open(current_path)
	# First adding directories
	var folders := dir.get_directories()
	for folder in folders:
		var item := preload("res://ui/file_explorer/item.tscn").instantiate()
		item.set_info(folder, Color(0,255,100,255))
		%FoldersFileContent.add_child(item)
		item.connect(
			"pressed", 
			go_to_folder.bind("%s/%s" % [current_path, folder]))
	var files := dir.get_files()
	for file in files:
		if not file.split('.')[-1] in extensions: continue
		var item := preload("res://ui/file_explorer/item.tscn").instantiate()
		item.set_info(file, Color(250,100,100,255))
		%FoldersFileContent.add_child(item)


func _on_system_path_button_pressed(folder_name: String) -> void:
	match folder_name:
		"home": go_to_folder("/home/%s" % Globals.system_username)
		"documents": go_to_folder("/home/%s/Documents" % Globals.system_username)
		"downloads": go_to_folder("/home/%s/Downloads" % Globals.system_username)
		"pictures": go_to_folder("/home/%s/Pictures" % Globals.system_username)
		"music": go_to_folder("/home/%s/Music" % Globals.system_username)
		"videos": go_to_folder("/home/%s/Videos" % Globals.system_username)
		_: print("incorrect system path")
