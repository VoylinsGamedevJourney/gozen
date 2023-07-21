extends PanelContainer

#### TODO: DON'T USE DIALOGUE BOXES OR WINDOWS, INPUT DOES NOT GET TRANSFERED

# TODO: Make "saved paths" work

signal on_dir_selected(dir)
signal on_file_selected(file)
signal on_files_selected(files)


var previous_paths: PackedStringArray
var current_path: String
var project_path: String

var item_files_group: ButtonGroup = ButtonGroup.new()

## Don't add extensions for adding files
var extensions: PackedStringArray = [] 
var multi_select: bool = false # TODO: make this work!


func _ready() -> void:
	item_files_group.allow_unpress = true
	self.visible = false
	%ProjectFolderButton.visible = false
	%ProjectFolderButton.connect("pressed", go_to_folder.bind(project_path))
	_on_system_path_button_pressed("home")
	show_file_explorer() # TODO: REMOVE THIS LINE


func set_info(title: String, ext_array: PackedStringArray = [], select_multi: bool = false, p_path: String = "") -> void:
	find_child("TitleLabel").text = title
	go_to_folder(current_path)
	if project_path != "":
		project_path = p_path
		%ProjectFolderButton.visible = true
	extensions.append_array(ext_array)
	multi_select = select_multi


func show_file_explorer() -> void:
	self.visible = true


func _input(event: InputEvent) -> void:
	if get_viewport().gui_get_focus_owner() == null and event.is_action_pressed("file_explorer_previous_path"):
		_on_return_button_pressed()


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
	for item in %FoldersFileContent.get_children():
		item.queue_free()
	
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
			"pressed", go_to_folder.bind("%s/%s" % [current_path, folder]))
	
	# Adding files
	var files := dir.get_files()
	for file in files:
		if not file.split('.')[-1] in extensions and extensions.size() != 0:
			continue
		var item := preload("res://ui/file_explorer/item.tscn").instantiate()
		item.set_info(file, Color(250,100,100,255))
		item.button_group = item_files_group
		item.connect("pressed", file_item_pressed.bind("%s/%s" % [current_path, file]))
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


func _on_return_button_pressed() -> void:
	if previous_paths.size() == 0: return
	if previous_paths.size() == 1:
		go_to_folder("/home/%s" % Globals.system_username, true)
	else:
		go_to_folder(previous_paths[-1], true)
		previous_paths.remove_at(previous_paths.size()-1)


func _on_close_button_pressed() -> void:
	self.queue_free()


func _on_select_button_pressed() -> void:
	# Get the folder which was selected and return the value
	if extensions.size() == 0: # Directory
		on_dir_selected.emit(current_path)
	elif multi_select: # Files
		pass
	else: # File
		pass
	close_file_explorer()


func file_item_pressed(file_path) -> void:
	print(file_path)
	print(item_files_group.get_buttons())
