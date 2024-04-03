extends Tree
# TODO: Remope folder/file in submenu

enum POPUP_TYPE { MINIMAL, FULL }


@export var global: bool = false

var icon_folder: Texture2D = preload("res://assets/icons/folder.png")
var icon_max_width: int = 20

var folder_items: Dictionary = {}
var file_items: Dictionary = {}


func _ready() -> void:
	# Creating the root item
	var l_root: TreeItem = create_item()
	l_root.set_text(0, "root")
	l_root.set_icon(0, icon_folder)
	l_root.set_icon_max_width(0, icon_max_width)
	folder_items[l_root] = '/'
	
	get_window().files_dropped.connect(files_dropped)
	
	# Loading structure
	if global:
		load_structure()
	else:
		ProjectManager._on_project_loaded.connect(load_structure)


func get_folder_data() -> Dictionary:
	return FileManager.folder_data if global else ProjectManager.folder_data


func load_structure() -> void:
	# Loading in all folders and folders
	for l_path: String in get_folder_data():
		_load_folders(l_path, get_folder_data()[l_path])


func _load_folders(a_path: String, a_files: Array) -> void:
	if a_path == "/":
		_load_files(get_root(), a_files)
		return
	
	# Creating the folder structure
	var l_current_folder: TreeItem = get_root()
	
	for l_folder: String in a_path.split('/'):
		l_current_folder = _new_folder(l_current_folder, l_folder, a_path)
	
	_load_files(l_current_folder, a_files)


func _load_files(a_folder: TreeItem, a_files: PackedStringArray) -> void:
	# Adding all files to the folder structure
	for l_file_id: String in a_files:
		var l_file_data: File = FileManager.get_files_data(global)[l_file_id]
		_new_file(a_folder, l_file_id, l_file_data)


func _new_folder(a_parent: TreeItem, a_folder_name: String, a_folder_path: String) -> TreeItem:
	var l_item := create_item(a_parent)
	
	l_item.set_text(0, a_folder_name)
	l_item.set_icon(0, icon_folder)
	l_item.set_icon_max_width(0, icon_max_width)
	
	folder_items[l_item] = a_folder_path
	return l_item


func _new_file(parent: TreeItem, file_id: String, data: File) -> TreeItem:
	var item := create_item(parent)
	
	item.set_text(0, data.nickname)
	item.set_icon(0, data.get_icon())
	item.set_icon_max_width(0, icon_max_width)
	
	if data is FileActual:
		item.set_tooltip_text(0, data.file_path)
	
	file_items[item] = file_id
	return item


func create_popup(a_type: POPUP_TYPE, a_item: TreeItem) -> PopupMenu:
	# TODO: Add to popup manager
	var l_popup := PopupMenu.new()
	
	l_popup.id_pressed.connect(_on_item_clicked.bind(l_popup, a_item))
	l_popup.mouse_exited.connect(Toolbox.free_node.bind(l_popup))
	l_popup.position = get_global_mouse_position() as Vector2i
	l_popup.size = Vector2i(160, 10)
	
	l_popup.add_item("Add file(s)", 0)
	l_popup.add_item("Add folder", 1)
	
	if a_type != POPUP_TYPE.MINIMAL:
		l_popup.add_separator()
		l_popup.add_item("Rename", 2)
	
	return l_popup


func _on_empty_clicked(_mouse_position: Vector2, a_mouse_button_index: int) -> void:
	if a_mouse_button_index == MOUSE_BUTTON_RIGHT:
		var l_popup: PopupMenu = create_popup(POPUP_TYPE.MINIMAL, get_root())
		add_child(l_popup)
		l_popup.popup()


func _on_item_mouse_selected(_position: Vector2, mouse_button_index: int) -> void:
	# TODO: Double click = rename
	if mouse_button_index == MOUSE_BUTTON_RIGHT:
		var popup := create_popup(POPUP_TYPE.FULL, get_selected())
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


func open_file_dialog(a_folder: TreeItem) -> void:
	var l_dialog: FileDialog = DialogManager.get_file_import_dialog()
	
	l_dialog.files_selected.connect(add_files.bind(a_folder))
	l_dialog.file_selected.connect(add_file.bind(a_folder))
	l_dialog.canceled.connect(Toolbox.free_node.bind(l_dialog))
	
	add_child(l_dialog)
	l_dialog.popup_centered(Vector2i(500,600))


func add_folder(a_folder: TreeItem) -> void:
	# Creating path
	var l_path: String = "new_folder"
	var l_current_folder: TreeItem = a_folder
	
	while true:
		l_path = "%s/%s" % [l_current_folder.get_text(0), l_path]
		l_current_folder = l_current_folder.get_parent()
		if !l_current_folder:
			if l_path.split('/')[0] == "root":
				l_path = l_path.trim_prefix("root/")
			break
	
	# Checking if folder name is taken already or not
	while l_path in get_folder_data().keys():
		if int(l_path[-1]) in range(10):
			var l_nr: int = l_path.split("_")[-1].to_int()
			l_path = "%s_%s" % [l_path.trim_suffix('_' + str(l_nr)), str(l_nr + 1)]
		else:
			l_path += "_1"
	
	_new_folder(a_folder, l_path.split('/')[-1], l_path)
	FileManager.add_folder(l_path, global)
	# TODO: Directly focus on renaming and only saving new folder after by calling a rename_item function?


func add_file(a_file_path: String, a_folder_item: TreeItem) -> void:
	var l_file_id: String = FileManager.add_file_actual(a_file_path, folder_items[a_folder_item], global)
	var l_file_obj: FileActual = FileManager.get_file_obj(l_file_id, global)
	var l_file_item := a_folder_item.create_child()
	
	file_items[l_file_item] = l_file_id
	l_file_item.set_text(0, l_file_obj.nickname)
	l_file_item.set_icon(0, l_file_obj.get_icon())
	l_file_item.set_icon_max_width(0, icon_max_width)


func add_files(a_file_paths: PackedStringArray, a_folder_item: TreeItem) -> void:
	for l_file_path: String in a_file_paths:
		add_file(l_file_path, a_folder_item)


func rename_item(a_item: TreeItem) -> void:
	print("not working") # TODO: Make this work


func files_dropped(a_files: PackedStringArray) -> void:
	if is_visible_in_tree():
		add_files(a_files, get_item_at_position(get_local_mouse_position()))
