extends PanelContainer


enum POPUP_ACTION {
	# File actions
	RENAME,
	DELETE,
	RELOAD,
	SAVE_TEMP_AS,
	EXTRACT_AUDIO,
	DUPLICATE,
	CREATE_PROXY,
	RECREATE_PROXY,
	REMOVE_PROXY,
	AUDIO_TAKE_OVER,
	AUDIO_TAKE_OVER_ENABLE,
	AUDIO_TAKE_OVER_DISABLE,
	OPEN_IN_FILE_MANAGER,
	COPY_PATH,

	# Folder actions
	FOLDER_CREATE,
	FOLDER_RENAME,
	FOLDER_DELETE }

const IMAGE_FORMATS: Array[String] = ["*.png", "*.jpg", "*.webp"]


@export var tree: Tree
@export var file_menu_button: MenuButton


var folder_items: Dictionary[String, TreeItem] = {} ## { folder_path: tree_item }
var file_items: Dictionary[int, TreeItem] = {} ## { file: tree_item }



func _ready() -> void:
	tree.set_drag_forwarding(_get_list_drag_data, _can_drop_list_data, _drop_list_data)
	folder_items["/"] = tree.create_item()
	folder_items["/"].set_metadata(0, "/")

	# Setting the max width needs to be done in this way.
	for i: int in file_menu_button.item_count:
		file_menu_button.get_popup().set_item_icon_max_width(i, 21)

	@warning_ignore_start("return_value_discarded")
	Project.project_ready.connect(_on_project_ready)
	Thumbnailer.thumb_generated.connect(_on_update_thumb)

	FileLogic.added.connect(_on_added)
	FileLogic.deleted.connect(_on_deleted)
	FileLogic.moved.connect(_on_moved)
	FileLogic.path_updated.connect(_on_path_updated)
	FileLogic.nickname_changed.connect(_on_nickname_changed)
	FolderLogic.added.connect(_on_folder_added)
	FolderLogic.deleted.connect(_on_folder_deleted)
	FolderLogic.path_changed.connect(_on_folder_renamed)

	tree.item_mouse_selected.connect(_tree_item_clicked)
	tree.empty_clicked.connect(_tree_item_clicked.bind(true))

	file_menu_button.get_popup().id_pressed.connect(_file_menu_pressed)
	@warning_ignore_restore("return_value_discarded")


func _input(event: InputEvent) -> void:
	if get_global_rect().has_point(get_global_mouse_position()):
		if tree.get_selected() and event.is_action_pressed("delete_file", false, true):
			_on_popup_option_pressed(POPUP_ACTION.DELETE)
			accept_event()


func _on_project_ready() -> void:
	for folder: String in Project.data.folders:
		if !folder_items.has(folder):
			_add_folder_to_tree(folder)
	for file: FileData in FileLogic.files.values():
		_add_file_to_tree(file)


func _file_menu_pressed(id: int) -> void:
	match id:
		0: # Add file(s).
			var dialog: FileDialog = PopupManager.create_file_dialog(
					tr("Add files ..."), FileDialog.FILE_MODE_OPEN_FILES)
			add_child(dialog)
			@warning_ignore("return_value_discarded")
			dialog.files_selected.connect(FileLogic.dropped)
			dialog.popup_centered()
		1: FileLogic.add(["temp://text"])
		2: PopupManager.open(PopupManager.COLOR)


func _tree_item_clicked(_mouse_pos: Vector2, button_index: int, empty: bool = false) -> void:
	if button_index != MOUSE_BUTTON_RIGHT:
		return
	var file_item: TreeItem = folder_items["/"] if empty else tree.get_selected()
	var metadata: Variant = file_item.get_metadata(0)
	var popup: PopupMenu = PopupManager.create_menu()

	if str(metadata).is_valid_int(): # - File
		var file: FileData = FileLogic.files[metadata as int]
		popup.add_item(tr("Rename"), POPUP_ACTION.RENAME)
		popup.add_item(tr("Reload"), POPUP_ACTION.RELOAD)
		popup.add_item(tr("Delete"), POPUP_ACTION.DELETE)

		if file.type == EditorCore.TYPE.IMAGE:
			if file.path.contains("temp://"):
				popup.add_separator(tr("Image options"))
				popup.add_item(tr("Save image as ..."), POPUP_ACTION.SAVE_TEMP_AS)
		elif file.type == EditorCore.TYPE.VIDEO:
			popup.add_separator(tr("Video options"))

			if Settings.get_use_proxies():
				if file.proxy_path == "":
					popup.add_item(tr("Create proxy"), POPUP_ACTION.CREATE_PROXY)
				else:
					popup.add_item(tr("Re-create proxy"), POPUP_ACTION.RECREATE_PROXY)
					popup.add_item(tr("Remove proxy"), POPUP_ACTION.REMOVE_PROXY)
			popup.add_item(tr("Audio-take-over"), POPUP_ACTION.AUDIO_TAKE_OVER)
			popup.add_item(tr("Extract audio to file ..."), POPUP_ACTION.EXTRACT_AUDIO)
		elif file.type == EditorCore.TYPE.TEXT:
			popup.add_separator(tr("Text options"))
			popup.add_item(tr("Duplicate"), POPUP_ACTION.DUPLICATE)

			if file.path.contains("temp://"):
				popup.add_item(tr("Save file as ..."), POPUP_ACTION.SAVE_TEMP_AS)

		if not file.path.begins_with("temp://"):
			popup.add_separator()
			popup.add_item(tr("Open in file manager"), POPUP_ACTION.OPEN_IN_FILE_MANAGER)
			popup.add_item(tr("Copy file path"), POPUP_ACTION.COPY_PATH)

		popup.add_separator(tr("Folder options"))
		popup.add_item(tr("Create folder"), POPUP_ACTION.FOLDER_CREATE)
	else: # Folder
		var folder_path: String = str(metadata)
		popup.add_item(tr("Create folder"), POPUP_ACTION.FOLDER_CREATE)

		if folder_path != "/":
			popup.add_item(tr("Rename folder"), POPUP_ACTION.FOLDER_RENAME)
			popup.add_item(tr("Delete folder"), POPUP_ACTION.FOLDER_DELETE)

	@warning_ignore("return_value_discarded")
	popup.id_pressed.connect(_on_popup_option_pressed)
	PopupManager.show_menu(popup)


## For the right click presses of the file popup menu's.
func _on_popup_option_pressed(option_id: int) -> void:
	match option_id:
		POPUP_ACTION.RENAME: _on_popup_action_file_rename()
		POPUP_ACTION.RELOAD: _on_popup_action_file_reload()
		POPUP_ACTION.DELETE: _on_popup_action_file_delete()
		POPUP_ACTION.SAVE_TEMP_AS: _on_popup_action_file_save_temp_as()
		POPUP_ACTION.EXTRACT_AUDIO: _on_popup_action_file_extract_audio()
		POPUP_ACTION.DUPLICATE: _on_popup_action_file_duplicate()
		POPUP_ACTION.CREATE_PROXY: _on_popup_action_file_create_proxy()
		POPUP_ACTION.RECREATE_PROXY: _on_popup_action_file_recreate_proxy()
		POPUP_ACTION.REMOVE_PROXY: _on_popup_action_file_remove_proxy()
		POPUP_ACTION.AUDIO_TAKE_OVER: _on_popup_action_audio_take_over()
		POPUP_ACTION.OPEN_IN_FILE_MANAGER: _on_popup_action_open_in_file_manager()
		POPUP_ACTION.COPY_PATH: _on_popup_action_copy_path()

		POPUP_ACTION.FOLDER_CREATE: _on_popup_action_folder_create()
		POPUP_ACTION.FOLDER_RENAME: _on_popup_action_folder_rename()
		POPUP_ACTION.FOLDER_DELETE: _on_popup_action_folder_delete()


func _on_popup_action_folder_create() -> void:
	_show_create_folder_dialog()


func _on_popup_action_folder_rename() -> void:
	var selected_item: TreeItem = tree.get_selected()
	var folder_path: String = str(selected_item.get_metadata(0))
	if not folder_path.ends_with("/") or folder_path == "/":
		return # Ensure it is a folder and not root
	var current_name: String = folder_path.trim_suffix("/").get_file()

	var dialog: AcceptDialog = PopupManager.create_accept_dialog(tr("Rename file"))
	var vbox: VBoxContainer = VBoxContainer.new()
	var line_edit: LineEdit = LineEdit.new()
	var label: Label = Label.new()

	label.text = tr("Folder name")
	line_edit.text = current_name
	line_edit.select_all()

	vbox.add_child(label)
	vbox.add_child(line_edit)
	dialog.add_child(vbox)

	var confirm_lambda: Callable = func(_t: String = "") -> void:
		var new_folder_name: String = line_edit.text.strip_edges()
		if new_folder_name not in ["", "/"] and new_folder_name != current_name:
			var parent_path: String = folder_path.trim_suffix("/").get_base_dir()
			var new_path: String = ""

			if parent_path == "/":
				new_path = "/" + new_folder_name + "/"
			else:
				new_path = parent_path + "/" + new_folder_name + "/"
			FolderLogic.rename(folder_path, new_path)
		dialog.queue_free()

	@warning_ignore_start("return_value_discarded")
	dialog.confirmed.connect(confirm_lambda)
	line_edit.text_submitted.connect(confirm_lambda)
	@warning_ignore_restore("return_value_discarded")

	add_child(dialog)
	dialog.popup_centered(Vector2(300, 100))
	line_edit.grab_focus()


func _on_popup_action_folder_delete() -> void:
	FolderLogic.delete(str(tree.get_selected().get_metadata(0)))


func _on_popup_action_file_rename() -> void:
	var rename_dialog: FileRenameDialog = preload(Library.SCENE_RENAME_DIALOG).instantiate()
	rename_dialog.prepare(FileLogic.files[tree.get_selected().get_metadata(0) as int])
	add_child(rename_dialog)


func _on_popup_action_file_reload() -> void:
	FileLogic.load_data(FileLogic.files[tree.get_selected().get_metadata(0)])


func _on_popup_action_file_delete() -> void:
	FileLogic.delete([tree.get_selected().get_metadata(0) as int])


func _on_popup_action_file_save_temp_as() -> void:
	var file: FileData = FileLogic.files[tree.get_selected().get_metadata(0)]
	if file.type == EditorCore.TYPE.TEXT: # TODO: Implement duplicating text files
		printerr("FilePanel: Not implemented yet!")
	elif file.type == EditorCore.TYPE.IMAGE:
		var dialog: FileDialog = PopupManager.create_file_dialog(
				tr("Save image to file"),
				FileDialog.FILE_MODE_SAVE_FILE,
				IMAGE_FORMATS)
		@warning_ignore("return_value_discarded")
		dialog.file_selected.connect(func(path: String) -> void:
				FileLogic.save_image_to_file(file, path))
		add_child(dialog)
		dialog.popup_centered()


func _on_popup_action_file_extract_audio() -> void:
	var file: FileData = FileLogic.files[tree.get_selected().get_metadata(0)]
	var dialog: FileDialog = PopupManager.create_file_dialog(
			tr("Save video audio to WAV"), FileDialog.FILE_MODE_SAVE_FILE, ["*.wav"])

	@warning_ignore("return_value_discarded")
	dialog.file_selected.connect(func(path: String) -> void:
			FileLogic.save_audio_to_wav(file, path))
	add_child(dialog)
	dialog.popup_centered()


func _on_popup_action_file_duplicate() -> void: # Only for text.
	var file: FileData = FileLogic.files[tree.get_selected().get_metadata(0)]
	if file.type != EditorCore.TYPE.TEXT:
		return printerr("FilePanel: Duplicating only supported for text files right now!")
	FileLogic.duplicate_text(file)


func _on_popup_action_file_create_proxy() -> void:
	var file: FileData = FileLogic.files[tree.get_selected().get_metadata(0)]
	ProxyHandler.request_generation(file)


func _on_popup_action_file_recreate_proxy() -> void:
	var file: FileData = FileLogic.files[tree.get_selected().get_metadata(0)]
	ProxyHandler.delete_proxy(file)
	ProxyHandler.request_generation(file)


func _on_popup_action_file_remove_proxy() -> void:
	var file: FileData = FileLogic.files[tree.get_selected().get_metadata(0)]
	FileLogic.load_data(file)
	FileLogic.nickname_changed.emit(file)
	ProxyHandler.delete_proxy(file)


func _on_popup_action_audio_take_over() -> void:
	# TODO: Add this to undo_redo!
	var popup: Control = PopupManager.get_popup(PopupManager.AUDIO_TAKE_OVER)
	popup.call("load_data", tree.get_selected().get_metadata(0), true)


func _on_popup_action_open_in_file_manager() -> void:
	var file: FileData = FileLogic.files[tree.get_selected().get_metadata(0)]
	@warning_ignore("return_value_discarded")
	OS.shell_show_in_file_manager(ProjectSettings.globalize_path(file.path))


func _on_popup_action_copy_path() -> void:
	var file: FileData = FileLogic.files[tree.get_selected().get_metadata(0)]
	DisplayServer.clipboard_set(ProjectSettings.globalize_path(file.path))


func _get_list_drag_data(_pos: Vector2) -> Draggable:
	var draggable: Draggable = Draggable.new()
	var selected: TreeItem = tree.get_next_selected(folder_items["/"])
	if selected == null:
		return
	draggable.is_file = true

	while true:
		var metadata: Variant = selected.get_metadata(0)
		var file_ids: Array[int] = []

		if str(metadata).is_valid_int():
			file_ids.append(metadata as int) # Single file.
		else:
			file_ids = _get_recursive_ids(selected) # Folder.

		for file_id: int in file_ids:
			if file_id in draggable.ids:
				continue
			if !draggable.ids.append(file_id):
				printerr("FilePanel: Couldn't add '%s' to draggable ids!" % file_id)
			draggable.duration += FileLogic.files[file_id].duration
		selected = tree.get_next_selected(selected)
		if selected == null:
			break # End of selected TreeItem's.
	draggable.mouse_offset = mini(floori(draggable.duration / 2.0), draggable.mouse_offset)
	return draggable


func _add_folder_to_tree(folder: String) -> void:
	if folder_items.has(folder): return print("FilePanel:
		Folder '%s' already exists!" % folder)

	# Check if all parent folders exist or not.
	var folders: Array[String] = folder.split('/', false)
	var check_path: String = "/"
	var previous_folder: TreeItem = folder_items["/"]

	for i: int in folders.size():
		var parent_path: String = check_path
		check_path += folders[i] + "/"

		if !folder_items.has(check_path):
			folder_items[check_path] = tree.create_item(previous_folder)
			folder_items[check_path].set_custom_minimum_height(26)
			folder_items[check_path].set_text(0, folders[i])
			folder_items[check_path].set_icon(0, preload(Library.ICON_FOLDER))
			folder_items[check_path].set_icon_max_width(0, 20)
			folder_items[check_path].set_metadata(0, check_path)
			_sort_folder(parent_path)

		previous_folder = folder_items[check_path]


func _add_file_to_tree(file: FileData) -> void:
	# Create item for the file panel tree.
	var file_nickname: String = file.nickname
	if !folder_items.keys().has(file.folder):
		_add_folder_to_tree(file.folder)

	if Settings.get_use_proxies():
		if !file.proxy_path.is_empty() and FileAccess.file_exists(file.proxy_path):
			file_nickname += " [P]"

	file_items[file.id] = tree.create_item(folder_items[file.folder])
	file_items[file.id].set_text(0, file_nickname)
	file_items[file.id].set_tooltip_text(0, file.path)
	file_items[file.id].set_metadata(0, file.id)
	file_items[file.id].set_icon(0, Thumbnailer.get_thumb(file))
	file_items[file.id].set_icon_max_width(0, 70)

	if not Thumbnailer.data.has(file.path) and file.type != EditorCore.TYPE.AUDIO and not file.path.begins_with("temp://"):
		file_items[file.id].set_icon_modulate(0, Color(1, 1, 1, 0.4))
		file_items[file.id].set_tooltip_text(0, file.path + "\n" + tr("(Loading thumbnail...)"))
	_sort_folder(file.folder)


func _on_update_thumb(file: FileData) -> void:
	if !FileLogic.files.has(file.id):
		return _on_deleted(file.id)
	file_items[file.id].set_icon(0, Thumbnailer.get_thumb(file))
	file_items[file.id].set_icon_modulate(0, Color.WHITE)
	file_items[file.id].set_tooltip_text(0, file.path)


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

	var first_child: TreeItem = folder_item.get_first_child()
	var last_item: TreeItem = null
	var folder_order: Array[String] = folders.keys()
	var files_order: Array[String] = files.keys()
	folder_order.sort_custom(func(a: String, b: String) -> bool: return a.naturalnocasecmp_to(b) < 0)
	files_order.sort_custom(func(a: String, b: String) -> bool: return a.naturalnocasecmp_to(b) < 0)

	for folder_name: String in folder_order:
		var item: TreeItem = folders[folder_name]
		if last_item != null:
			item.move_after(last_item)
		elif item != first_child:
			item.move_before(first_child)
		last_item = item

	for file_name: String in files_order:
		var item: TreeItem = files[file_name]
		if last_item != null:
			item.move_after(last_item)
		elif item != first_child:
			item.move_before(first_child)
		last_item = item


func _on_added(file: FileData) -> void:
	# There's a possibility that the file was too large
	# and that it did not get added.
	_add_file_to_tree(file)


func _on_deleted(file_id: int) -> void:
	if file_items.has(file_id):
		file_items[file_id].get_parent().remove_child(file_items[file_id])
		if !file_items.erase(file_id):
			printerr("FilePanel: Couldn't erase '%s' from file_items!" % file_id)


func _on_moved(file: FileData) -> void:
	if file_items.has(file.id):
		_on_deleted(file.id)
		_add_file_to_tree(file)


func _on_path_updated(file: FileData) -> void:
	file_items[file.id].set_tooltip_text(0, file.path)


func _on_nickname_changed(file: FileData) -> void:
	var file_nickname: String = file.nickname

	if Settings.get_use_proxies():
		if !file.proxy_path.is_empty() and FileAccess.file_exists(file.proxy_path):
			file_nickname += " [P]"

	file_items[file.id].set_text(0, file_nickname)
	_sort_folder(file.folder)


func _on_folder_added(path: String) -> void:
	if !folder_items.has(path):
		_add_folder_to_tree(path)


func _on_folder_deleted(path: String) -> void:
	if folder_items.has(path):
		var item: TreeItem = folder_items[path]
		item.free()
		if !folder_items.erase(path):
			printerr("FilePanel: Couldn't erase '%s' from folder_items!" % path)


func _on_folder_renamed(old_path: String, new_path: String) -> void:
	var paths_to_update: Array[String] = []
	var length: int = old_path.length()

	for folder_path: String in folder_items.keys():
		if folder_path.begins_with(old_path):
			paths_to_update.append(folder_path)

	# Update items mapping and metadata.
	for folder_path: String in paths_to_update:
		var updated_path: String = new_path + folder_path.substr(length)
		var item: TreeItem = folder_items[folder_path]

		if !folder_items.erase(folder_path):
			printerr("FilePanel: Couldn't erase '%s' to folder_items!" % folder_path)
		folder_items[updated_path] = item
		item.set_metadata(0, updated_path)

		# Rename the actual path of the exact folder
		if folder_path == old_path:
			var new_folder_name: String = new_path.trim_suffix("/").get_file()
			item.set_text(0, new_folder_name)

	var parent_path: String = new_path.trim_suffix("/").get_base_dir()
	if parent_path in ["", "/"]:
		parent_path = "/"
	else:
		parent_path += "/"
	_sort_folder(parent_path)


func _get_recursive_ids(item: TreeItem) -> PackedInt64Array:
	var ids: Array[int] = []
	var child: TreeItem = item.get_first_child()

	while child:
		var metadata: Variant = child.get_metadata(0)
		if str(metadata).is_valid_int():
			ids.append(metadata as int) # File.
		else:
			ids.append_array(_get_recursive_ids(child)) # Folder.
		child = child.get_next()
	return ids


func _show_create_folder_dialog() -> void:
	var dialog: AcceptDialog = PopupManager.create_accept_dialog(tr("Create folder"))
	var vbox: VBoxContainer = VBoxContainer.new()
	var line_edit: LineEdit = LineEdit.new()
	var label: Label = Label.new()

	label.text = tr("Folder name")
	vbox.add_child(label)
	vbox.add_child(line_edit)
	dialog.add_child(vbox)

	var confirm_lambda: Callable = func(_t: String = "") -> void:
		var new_folder_name: String = line_edit.text.strip_edges()
		if new_folder_name not in ["", "/"]:
			_create_folder_at_selected(new_folder_name)
		dialog.queue_free()

	@warning_ignore_start("return_value_discarded")
	dialog.confirmed.connect(confirm_lambda)
	line_edit.text_submitted.connect(confirm_lambda)
	@warning_ignore_restore("return_value_discarded")

	add_child(dialog)
	dialog.popup_centered(Vector2(300, 100))
	line_edit.grab_focus()


func _create_folder_at_selected(folder_name: String) -> void:
	var selected_item: TreeItem = tree.get_selected()
	var parent_path: String = "/"

	if selected_item:
		var metadata: Variant = selected_item.get_metadata(0)
		if str(metadata).is_valid_int(): # File
			var file: FileData = FileLogic.files[metadata as int]
			parent_path = file.folder
		else:
			parent_path = str(metadata)
	if not parent_path.ends_with("/"):
		parent_path += "/"

	var full_path: String = parent_path + folder_name + "/"
	if full_path not in folder_items:
		FolderLogic.add(full_path)


func _can_drop_list_data(at_position: Vector2, data: Variant) -> bool:
	if not data is Draggable:
		return false
	var item: TreeItem = tree.get_item_at_position(at_position)
	var section: int = tree.get_drop_section_at_position(at_position)

	tree.drop_mode_flags = Tree.DROP_MODE_ON_ITEM | Tree.DROP_MODE_INBETWEEN
	return not (item and section == 0 and str(item.get_metadata(0)).is_valid_int()) # Can't drop in files


func _drop_list_data(at_position: Vector2, data: Variant) -> void:
	if not data is Draggable:
		return
	var draggable: Draggable = data
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

	var files: Array[FileData] = []
	for file_id: int in draggable.ids:
		files.append(FileLogic.files[file_id])
	FileLogic.move(files, target_folder)
