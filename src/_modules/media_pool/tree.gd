extends Tree

enum POPUP_TYPE { MINIMAL, FOLDER, FILE }

@export var global: bool = false

var icon_folder := preload("res://assets/icons/icon_folder.png")


func _ready() -> void:
	# Renaming the tab
	var tab_bar: TabBar = get_parent().get_tab_bar()
	tab_bar.set_tab_title(get_index(), Toolbox.beautify_name(name))
	
	# Loading structure
	var root := create_item() # Creating the root item
	root.set_text(0, "root")
	if global:
		load_structure()
	else:
		ProjectManager._on_project_loaded.connect(load_structure)


func get_folder_data() -> Dictionary:
	return FileManager.folder_data if global else ProjectManager.folder_data


func get_file_data() -> Dictionary:
	return FileManager.folder_data if global else ProjectManager.folder_data


func load_structure() -> void:
	# Loading in all folders and folders
	var folder_data := get_folder_data()
	for path: String in folder_data:
		_load_folders(path, folder_data[path])


func _load_folders(path: String, files: Array) -> void:
	# Creating the folder structure
	var current_folder: TreeItem = get_root()
	for folder: String in path.split('/'):
		var new_folder := create_item(current_folder)
		new_folder.set_text(0, folder)
		new_folder.set_text(1, path)
		new_folder.set_icon(0, icon_folder)
		current_folder = new_folder
	_load_files(current_folder, files)


func _load_files(folder: TreeItem, files: PackedStringArray) -> void:
	# Adding all files to the folder structure
	for file_id: String in files:
		var file_data: File = get_file_data()[file_id]
		var file_item := create_item(folder)
		file_item.set_text(0, file_data.nickname)
		file_item.set_text(1, file_id)
		file_item.set_icon(0, file_data.get_icon())
		if file_data is FileActual:
			file_item.set_tooltip_text(0, file_data.file_path)


func create_popup(mouse_position: Vector2, type: POPUP_TYPE, item: TreeItem) -> PopupMenu:
	var popup := PopupMenu.new()
	popup.position = mouse_position as Vector2i + popup.size / 2
	popup.add_item("Add file(s)", 0)
	popup.add_item("Add folder", 1)
	popup.id_pressed.connect(_on_item_clicked.bind(popup, item))
	popup.mouse_exited.connect(func(): popup.queue_free())
	#if !full_menu:
		#return popup
	popup.add_separator()
	popup.add_item("Rename", 2)
	return popup


func _on_empty_clicked(mouse_position: Vector2, mouse_button_index: int) -> void:
	print("empty clicked")
	if mouse_button_index == MOUSE_BUTTON_RIGHT:
		var popup := create_popup(mouse_position, POPUP_TYPE.MINIMAL, get_root())
		add_child(popup)
		popup.popup()


func _on_button_clicked(item: TreeItem, c: int, id: int, mouse_button_index: int) -> void:
	# TODO: Double click = rename
	if mouse_button_index == MOUSE_BUTTON_RIGHT:
		var popup := create_popup(
			get_local_mouse_position(), 
			POPUP_TYPE.FILE if item.get_text(1) in get_file_data() else POPUP_TYPE.FOLDER,
			item)
		add_child(popup)
		popup.popup()


func _on_item_clicked(id: int, popup: PopupMenu, item: TreeItem) -> void:
	match id:
		0: # Add file
			open_file_dialog(item)
		1: # Add folder
			add_folder(item)
		2: # Rename file/folder
			rename_item(item)
	popup.queue_free()


func open_file_dialog(folder: TreeItem) -> void:
	pass # TODO: make this work


func add_folder(folder: TreeItem) -> void:
	var new_item := create_item(folder, 0)
	var path := "new_folder"
	new_item.set_text(0, path)
	while true:
		folder = folder.get_parent()
		if !folder:
			break
		path += folder.get_text(0)
	# TODO: Directly focus on renaming and only saving new folder after
	# by calling a rename_item function?


func rename_item(item) -> void:
	pass # TODO: Make this work
