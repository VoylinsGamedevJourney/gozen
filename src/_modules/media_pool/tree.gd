extends Tree
# NOTE: if item.get_text(1) in get_file_data()

enum POPUP_TYPE { MINIMAL, FULL }

@export var global: bool = false

var icon_folder := preload("res://assets/icons/icon_folder.png")
var icon_max_width := 20

var folder_items := {}
var file_items := {}


func _ready() -> void:
	# Creating the root item
	var root := create_item()
	root.set_text(0, "root")
	root.set_icon(0, icon_folder)
	root.set_icon_max_width(0, icon_max_width)
	
	# Loading structure
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
		current_folder = _new_folder(current_folder, folder, path)
	_load_files(current_folder, files)


func _load_files(folder: TreeItem, files: PackedStringArray) -> void:
	# Adding all files to the folder structure
	for file_id: String in files:
		var file_data: File = get_file_data()[file_id]
		_new_file(folder, file_id, file_data)


func _new_folder(parent: TreeItem, folder_name: String, folder_path: String) -> TreeItem:
	var item := create_item(parent)
	item.set_text(0, folder_name)
	item.set_icon(0, icon_folder)
	item.set_icon_max_width(0, icon_max_width)
	folder_items[item] = folder_path
	return item


func _new_file(parent: TreeItem, file_id: String, data: File) -> TreeItem:
	var item := create_item(parent)
	item.set_text(0, data.nickname)
	item.set_icon(0, data.get_icon())
	item.set_icon_max_width(0, icon_max_width)
	if data is FileActual:
		item.set_tooltip_text(0, data.file_path)
	file_items[item] = file_id
	return item


func create_popup(type: POPUP_TYPE, item: TreeItem) -> PopupMenu:
	var popup := PopupMenu.new()
	popup.id_pressed.connect(_on_item_clicked.bind(popup, item))
	popup.mouse_exited.connect(func(): popup.queue_free())
	popup.position = get_global_mouse_position() as Vector2i
	popup.size = Vector2i(160, 10)
	popup.add_item("Add file(s)", 0)
	popup.add_item("Add folder", 1)
	if type == POPUP_TYPE.MINIMAL:
		return popup
	popup.add_separator()
	popup.add_item("Rename", 2)
	return popup


func _on_empty_clicked(_mouse_position: Vector2, mouse_button_index: int) -> void:
	if mouse_button_index == MOUSE_BUTTON_RIGHT:
		var popup := create_popup(POPUP_TYPE.MINIMAL, get_root())
		add_child(popup)
		popup.popup()


func _on_item_mouse_selected(_position: Vector2, mouse_button_index: int) -> void:
	# TODO: Double click = rename
	if mouse_button_index == MOUSE_BUTTON_RIGHT:
		var item: TreeItem = get_selected()
		var popup := create_popup(POPUP_TYPE.FULL, item)
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
	var dialog := DialogManager.get_file_import_dialog()
	dialog.files_selected.connect(add_files.bind(folder))
	dialog.file_selected.connect(add_file.bind(folder))
	dialog.canceled.connect(func() -> void: dialog.queue_free())
	add_child(dialog)
	dialog.popup_centered(Vector2i(500,600))


func add_folder(folder: TreeItem) -> void:
	# Creating path
	var path := "new_folder"
	var current_folder := folder
	while true:
		path = "%s/%s" % [current_folder.get_text(0), path]
		current_folder = current_folder.get_parent()
		if !current_folder:
			if path.split('/')[0] == "root":
				path = path.trim_prefix("root/")
			break
	
	# Checking if folder name is taken already or not
	var keys: PackedStringArray = get_folder_data().keys()
	while path in keys:
		for folder_path: String in keys:
			if path != folder_path:
				break; # Early break out if path is unique
			if int(path[-1]) in range(10):
				var nr: int = path.split("_")[-1].to_int()
				path = "%s_%s" % [path.trim_suffix('_' + str(nr)), str(nr + 1)]
			else:
				path += "_1" # TODO: Fix this later to increment number instead
	
	_new_folder(folder, path.split('/')[-1], path)
	FileManager.add_folder(path, FileManager.folder_data if global else ProjectManager.folder_data)
	# TODO: Directly focus on renaming and only saving new folder after
	# by calling a rename_item function?


func add_file(path: String, folder: TreeItem) -> void:
	print(path)
	print(folder)
	pass


func add_files(paths: PackedStringArray, folder: TreeItem) -> void:
	for path: String in paths:
		add_file(path, folder)


func rename_item(_item: TreeItem) -> void:
	pass # TODO: Make this work
