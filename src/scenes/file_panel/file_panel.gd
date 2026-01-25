extends PanelContainer

enum POPUP_ACTION {
	# File actions
	FILE_RENAME,
	FILE_DELETE,
	FILE_RELOAD,
	FILE_SAVE_TEMP_AS,
	FILE_EXTRACT_AUDIO,
	FILE_DUPLICATE,
	# Folder actions
	FOLDER_CREATE,
	FOLDER_RENAME,
	FOLDER_DELETE,
}


@export var tree: Tree
@export var file_menu_button: MenuButton

var folder_items: Dictionary[String, TreeItem] = {}
var file_items: Dictionary[int, TreeItem] = {} # { file_id: tree_item }



func _ready() -> void:
	FileHandler.file_added.connect(_on_file_added)
	FileHandler.file_deleted.connect(_on_file_deleted)
	FileHandler.file_moved.connect(_on_file_moved)
	FileHandler.file_path_updated.connect(_on_file_path_updated)
	FileHandler.file_nickname_changed.connect(_on_file_nickname_changed)
	FileHandler.folder_added.connect(_on_folder_added)
	FileHandler.folder_deleted.connect(_on_folder_deleted)
	FileHandler.folder_renamed.connect(_on_folder_renamed)

	Project.project_ready.connect(_on_project_ready)

	Thumbnailer.thumb_generated.connect(_on_update_thumb)

	tree.item_mouse_selected.connect(_tree_item_clicked)
	tree.empty_clicked.connect(_tree_item_clicked.bind(true))
	tree.gui_input.connect(_on_tree_gui_input)

	tree.set_drag_forwarding(_get_list_drag_data, _can_drop_list_data, _drop_list_data)
	folder_items["/"] = tree.create_item()

	# Setting the max width needs to be done in this way.
	for i: int in file_menu_button.item_count:
		file_menu_button.get_popup().set_item_icon_max_width(i, 21)

	file_menu_button.get_popup().id_pressed.connect(_file_menu_pressed)


func _on_tree_gui_input(event: InputEvent) -> void:
	if tree.get_selected() != null and event.is_action("delete_file"):
		_on_popup_option_pressed(POPUP_ACTION.FILE_DELETE)


func _on_project_ready() -> void:
	for folder: String in Project.data.folders:
		if !folder_items.has(folder):
			_add_folder_to_tree(folder)

	for file: File in FileHandler.get_file_objects():
		_add_file_to_tree(file)


func _file_menu_pressed(id: int) -> void:
	match id:
		0: # Add file(s)
			var dialog: FileDialog = PopupManager.create_file_dialog(
					"file_dialog_title_add_files",
					FileDialog.FILE_MODE_OPEN_FILES)

			dialog.files_selected.connect(FileHandler._on_files_dropped)
			add_child(dialog)
			dialog.popup_centered()
		1: # TODO: Add text
			pass
		2: PopupManager.open_popup(PopupManager.POPUP.COLOR)


func _tree_item_clicked(_mouse_pos: Vector2, button_index: int, empty: bool = false) -> void:
	var file_item: TreeItem = folder_items["/"] if empty else tree.get_selected()

	if button_index != MOUSE_BUTTON_RIGHT:
		return

	var file: File = null
	var popup: PopupMenu = PopupManager.create_popup_menu()
	var metadata: Variant = file_item.get_metadata(0)

	if str(metadata).is_valid_int(): # File
		var file_id: int = int(metadata)

		file = FileHandler.get_file(file_id)

		popup.add_item("popup_item_rename", POPUP_ACTION.FILE_RENAME)
		popup.add_item("popup_item_reload", POPUP_ACTION.FILE_RELOAD)
		popup.add_item("popup_item_delete", POPUP_ACTION.FILE_DELETE)

		# TODO: Add VIDEO_ONLY when we have more video options
		if file.type == FileHandler.TYPE.IMAGE:
			if file.path.contains("temp://"):
				popup.add_separator("popup_separator_image_options")
				popup.add_item("popup_item_save_as_file", POPUP_ACTION.FILE_SAVE_TEMP_AS)
		elif file.type == FileHandler.TYPE.VIDEO:
			popup.add_separator("popup_separator_video_options")
			popup.add_item("popup_item_extract_audio", POPUP_ACTION.FILE_EXTRACT_AUDIO)
		elif file.type == FileHandler.TYPE.TEXT:
			popup.add_separator("popup_separator_text_options")
			popup.add_item("popup_item_duplicate", POPUP_ACTION.FILE_DUPLICATE)

			if file.path.contains("temp://"):
				popup.add_item("popup_item_save_as_file", POPUP_ACTION.FILE_SAVE_TEMP_AS)

		popup.add_separator("popup_separator_folder_options")
		popup.add_item("popup_item_create_folder", POPUP_ACTION.FOLDER_CREATE)
	else: # Folder
		var folder_path: String = str(metadata)

		popup.add_item("popup_item_create_folder", POPUP_ACTION.FOLDER_CREATE)

		if folder_path != "/":
			popup.add_item("popup_item_rename_folder", POPUP_ACTION.FOLDER_RENAME)
			popup.add_item("popup_item_delete_folder", POPUP_ACTION.FOLDER_DELETE)

	popup.id_pressed.connect(_on_popup_option_pressed)
	PopupManager.show_popup_menu(popup)


## For the right click presses of the file popup menu's.
func _on_popup_option_pressed(option_id: int) -> void:
	match option_id:
		POPUP_ACTION.FOLDER_CREATE: _on_popup_action_folder_create()
		POPUP_ACTION.FOLDER_RENAME: _on_popup_action_folder_rename()
		POPUP_ACTION.FOLDER_DELETE: _on_popup_action_folder_delete()
		POPUP_ACTION.FILE_RENAME: _on_popup_action_file_rename()
		POPUP_ACTION.FILE_RELOAD: _on_popup_action_file_reload()
		POPUP_ACTION.FILE_DELETE: _on_popup_action_file_delete()
		POPUP_ACTION.FILE_SAVE_TEMP_AS: _on_popup_action_file_save_temp_as()
		POPUP_ACTION.FILE_EXTRACT_AUDIO: _on_popup_action_file_extract_audio()
		POPUP_ACTION.FILE_DUPLICATE: _on_popup_action_file_duplicate()


func _on_popup_action_folder_create() -> void:
	_show_create_folder_dialog()


func _on_popup_action_folder_rename() -> void:
	var selected_item: TreeItem = tree.get_selected()
	var folder_path: String = str(selected_item.get_metadata(0))

	# Ensure it is a folder and not root
	if not folder_path.ends_with("/") or folder_path == "/":
		return
	
	var current_name: String = folder_path.trim_suffix("/").get_file()

	var dialog: AcceptDialog = PopupManager.create_accept_dialog("popup_item_rename")
	var vbox: VBoxContainer = VBoxContainer.new()
	var line_edit: LineEdit = LineEdit.new()
	var label: Label = Label.new()

	label.text = "accept_dialog_text_folder_name" 
	line_edit.text = current_name
	line_edit.select_all()

	vbox.add_child(label)
	vbox.add_child(line_edit)
	dialog.add_child(vbox)

	var confirm_lambda: Callable = func(_t: String = "") -> void:
		var new_folder_name: String = line_edit.text.strip_edges()

		if new_folder_name not in ["", "/"] and new_folder_name != current_name:
			var parent_path: String = folder_path.trim_suffix("/").get_base_dir()
			var new_folder_path: String = ""

			if parent_path == "/":
				new_folder_path = "/" + new_folder_name + "/"
			else:
				new_folder_path = parent_path + "/" + new_folder_name + "/"

			FileHandler.rename_folder(folder_path, new_folder_path)
		dialog.queue_free()

	dialog.confirmed.connect(confirm_lambda)
	line_edit.text_submitted.connect(confirm_lambda)

	add_child(dialog)
	dialog.popup_centered(Vector2(300, 100))
	line_edit.grab_focus()


func _on_popup_action_folder_delete() -> void:
	FileHandler.delete_folder(str(tree.get_selected().get_metadata(0)))


func _on_popup_action_file_rename() -> void: 
	var file: File = FileHandler.get_file(tree.get_selected().get_metadata(0))
	var rename_dialog: FileRenameDialog = preload(Library.SCENE_RENAME_DIALOG).instantiate()

	rename_dialog.prepare(file.id)
	add_child(rename_dialog)


func _on_popup_action_file_reload() -> void:
	var file: File = FileHandler.get_file(tree.get_selected().get_metadata(0))

	FileHandler.reload_file_data(file.id)


func _on_popup_action_file_delete() -> void:
	FileHandler.delete_file(tree.get_selected().get_metadata(0))


func _on_popup_action_file_save_temp_as() -> void:
	var file: File = FileHandler.get_file(tree.get_selected().get_metadata(0))

	if file.type == FileHandler.TYPE.TEXT: # TODO: Implement duplicating text files
		printerr("FilePanel: Not implemented yet!")
	elif file.type == FileHandler.TYPE.IMAGE:
		var dialog: FileDialog = PopupManager.create_file_dialog(
				"title_save_image_to_file",
				FileDialog.FILE_MODE_SAVE_FILE,
				["*.png", "*.jpg", "*.webp"])

		dialog.file_selected.connect(FileHandler.save_image_to_file.bind(file))
		add_child(dialog)
		dialog.popup_centered()


func _on_popup_action_file_extract_audio() -> void:
	var file: File = FileHandler.get_file(tree.get_selected().get_metadata(0))
	var dialog: FileDialog = PopupManager.create_file_dialog(
		"title_save_video_audio_to_wav",
		FileDialog.FILE_MODE_SAVE_FILE,
		["*.wav"])

	dialog.file_selected.connect(FileHandler.save_audio_to_wav.bind(file))
	add_child(dialog)
	dialog.popup_centered()


func _on_popup_action_file_duplicate() -> void:
	# Only for text. TODO: Implement duplicating text files
	var _file: File = FileHandler.get_file(tree.get_selected().get_metadata(0))

	printerr("FilePanel: Duplicating text not implemented yet!")


func _get_list_drag_data(_pos: Vector2) -> Draggable:
	var draggable: Draggable = Draggable.new()
	var selected: TreeItem = tree.get_next_selected(folder_items["/"])

	if selected == null:
		return

	draggable.files = true

	while true:
		var metadata: Variant = selected.get_metadata(0)
		var file_ids: PackedInt64Array = []

		if str(metadata).is_valid_int(): # Single file
			file_ids.append(int(metadata))
		else: # Folder
			file_ids = _get_recursive_file_ids(selected)

		for file_id: int in file_ids:
			if file_id in draggable.ids:
				continue

			var file_duration: int = FileHandler.get_file_duration(file_id) 

			if file_duration <= 0:
				file_duration = FileHandler.update_file_duration(file_id)

			draggable.ids.append(file_id)
			draggable.duration += file_duration

		selected = tree.get_next_selected(selected)

		if selected == null:
			break # End of selected TreeItem's.

	return draggable


func _add_folder_to_tree(folder: String) -> void:
	if folder_items.has(folder):
		print("FilePanel: Folder '%s' already exists!" % folder)
		return

	# Check if all parent folders exist or not.
	var folders: PackedStringArray = folder.split('/', false)
	var check_path: String = "/"
	var previous_folder: TreeItem = folder_items["/"]

	for i: int in folders.size():
		check_path += folders[i] + "/"

		if !folder_items.has(check_path):
			folder_items[check_path] = tree.create_item(previous_folder)
			folder_items[check_path].set_text(0, folders[i])
			folder_items[check_path].set_icon(0, preload(Library.ICON_FOLDER))
			folder_items[check_path].set_icon_max_width(0, 20)
			folder_items[check_path].set_metadata(0, check_path)
			_sort_folder(check_path)
			
		previous_folder = folder_items[check_path]


func _add_file_to_tree(file: File) -> void:
	# Create item for the file panel tree.
	if !folder_items.keys().has(file.folder):
		_add_folder_to_tree(file.folder)
	
	file_items[file.id] = tree.create_item(folder_items[file.folder])
	file_items[file.id].set_text(0, file.nickname)
	file_items[file.id].set_tooltip_text(0, file.path)
	file_items[file.id].set_metadata(0, file.id)
	file_items[file.id].set_icon(0, Thumbnailer.get_thumb(file.id))
	file_items[file.id].set_icon_max_width(0, 70)
	# TODO: Use set_icon_modulate to indicate when a file is still loading,
	# this would make the files loading overlay obsolete. Just make certain
	# that the files with a modulate can't be selected yet and change their
	# tooltip to have "Loading ..." on it.
	_sort_folder(file.folder)


func _on_update_thumb(file_id: int) -> void:
	if FileHandler.has_file(file_id):
		file_items[file_id].set_icon(0, Thumbnailer.get_thumb(file_id))
	else:
		_on_file_deleted(file_id)


func _sort_folder(folder: String) -> void:
	var folder_item: TreeItem = folder_items[folder]
	var folders: Dictionary[String, TreeItem] = {}
	var files: Dictionary[String, TreeItem] = {}
	var child: TreeItem = folder_item.get_first_child()

	while child:
		if str(child.get_metadata(0)).is_valid_int():
			files[child.get_text(0).to_lower()] = child
		else:
			folders[child.get_text(0).to_lower()] = child
		child = child.get_next()

	var folder_order: PackedStringArray = folders.keys()
	var files_order: PackedStringArray = files.keys()

	folder_order.sort()
	files_order.sort()

	var last_item: TreeItem = null

	for folder_name: String in folder_order:
		if last_item != null:
			folders[folder_name].move_after(last_item)
		last_item = folders[folder_name]
		

	for file_name: String in files_order:
		if last_item != null:
			files[file_name].move_after(last_item)
		last_item = files[file_name]


func _on_file_added(file_id: int) -> void:
	# There's a possibility that the file was too large
	# and that it did not get added.
	_add_file_to_tree(FileHandler.get_file(file_id))


func _on_file_deleted(file_id: int) -> void:
	if file_items.has(file_id):
		file_items[file_id].get_parent().remove_child(file_items[file_id])
		file_items.erase(file_id)


func _on_file_moved(file_id: int) -> void:
	if file_items.has(file_id):
		_on_file_deleted(file_id)
		_add_file_to_tree(FileHandler.get_file(file_id))


func _on_file_path_updated(file_id: int) -> void:
	file_items[file_id].set_tooltip_text(0, FileHandler.get_file(file_id).path)


func _on_file_nickname_changed(file_id: int) -> void:
	var file: File = FileHandler.get_file(file_id)

	file_items[file_id].set_text(0, file.nickname)
	_sort_folder(file.folder)


func _on_folder_added(folder_name: String) -> void:
	if !folder_items.has(folder_name):
		_add_folder_to_tree(folder_name)


func _on_folder_deleted(folder_path: String) -> void:
	if folder_items.has(folder_path):
		var item: TreeItem = folder_items[folder_path]

		item.free() # Remove from Tree
		folder_items.erase(folder_path)


func _on_folder_renamed(old_folder_path: String, new_folder_path: String) -> void:
	var paths_to_update: PackedStringArray = []
	var length: int = old_folder_path.length()

	for folder_path: String in folder_items.keys():
		if folder_path.begins_with(old_folder_path):
			paths_to_update.append(folder_path)
	
	# Update items mapping and metadata
	for folder_path: String in paths_to_update:
		var updated_path: String = new_folder_path + folder_path.substr(length)
		var item: TreeItem = folder_items[folder_path]
		
		folder_items.erase(folder_path)
		folder_items[updated_path] = item
		item.set_metadata(0, updated_path)

		# Rename the actual path of the exact folder
		if folder_path == old_folder_path:
			var new_folder_name: String = new_folder_path.trim_suffix("/").get_file()
			item.set_text(0, new_folder_name)
			
	var parent_path: String = new_folder_path.trim_suffix("/").get_base_dir()

	if parent_path in ["", "/"]:
		parent_path = "/"
	else:
		parent_path += "/"
	
	_sort_folder(parent_path)
	

func _get_recursive_file_ids(item: TreeItem) -> PackedInt64Array:
	var ids: PackedInt64Array = []
	var child: TreeItem = item.get_first_child()

	while child:
		var metadata: Variant = child.get_metadata(0)

		if str(metadata).is_valid_int(): # File
			ids.append(int(metadata))
		else: # Folder
			ids.append_array(_get_recursive_file_ids(child))
	
	return ids


func _show_create_folder_dialog() -> void:
	var dialog: AcceptDialog = PopupManager.create_accept_dialog("accept_dialog_title_create_folder")
	var vbox: VBoxContainer = VBoxContainer.new()
	var line_edit: LineEdit = LineEdit.new()
	var label: Label = Label.new()

	label.text = "accept_dialog_text_folder_name" # "Folder name:"

	vbox.add_child(label)
	vbox.add_child(line_edit)
	dialog.add_child(vbox)

	var confirm_lambda: Callable = func(_t: String = "") -> void:
		var new_folder_name: String = line_edit.text.strip_edges()

		if new_folder_name not in ["", "/"]:
			_create_folder_at_selected(new_folder_name)

		dialog.queue_free()

	dialog.confirmed.connect(confirm_lambda)
	line_edit.text_submitted.connect(confirm_lambda)

	add_child(dialog)
	dialog.popup_centered(Vector2(300, 100))
	line_edit.grab_focus()


func _create_folder_at_selected(folder_name: String) -> void:
	var selected_item: TreeItem = tree.get_selected()
	var parent_path: String = "/"

	if selected_item:
		var metadata: Variant = selected_item.get_metadata(0)

		if str(metadata).is_valid_int(): # File
			parent_path = FileHandler.get_file(int(metadata)).folder
		else:
			parent_path = str(metadata)

	if not parent_path.ends_with("/"):
		parent_path += "/"

	var full_path: String = parent_path + folder_name + "/" 

	if full_path not in folder_items:
		FileHandler.add_folder(full_path)


func _can_drop_list_data(at_position: Vector2, data: Variant) -> bool:
	if not data is Draggable:
		return false

	var item: TreeItem = tree.get_item_at_position(at_position)
	var section: int = tree.get_drop_section_at_position(at_position)

	tree.drop_mode_flags = Tree.DROP_MODE_ON_ITEM | Tree.DROP_MODE_INBETWEEN
	
	# Can't drop in files
	return not (item and section == 0 and str(item.get_metadata(0)).is_valid_int())


func _drop_list_data(at_position: Vector2, data: Variant) -> void:
	if not data is Draggable:
		return

	var item: TreeItem = tree.get_item_at_position(at_position)
	var section: int = tree.get_drop_section_at_position(at_position)
	var target_folder: String = "/"
	
	if item:
		var metadata: Variant = item.get_metadata(0)
		
		if section == 0: 
			target_folder = str(metadata)
		else: 
			var parent_item: TreeItem = item.get_parent()

			if parent_item:
				target_folder = str(parent_item.get_metadata(0))
	
	FileHandler.move_files(data.ids, target_folder)
