extends PanelContainer
# TODO: Add an indicater for files which are using a proxy clip.

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

	# Folder actions
	FOLDER_CREATE,
	FOLDER_RENAME,
	FOLDER_DELETE,
}

const IMAGE_FORMATS: PackedStringArray = ["*.png", "*.jpg", "*.webp"]


@export var tree: Tree
@export var file_menu_button: MenuButton

var folder_items: Dictionary[String, TreeItem] = {}
var file_items: Dictionary[int, TreeItem] = {} # { file_id: tree_item }



func _ready() -> void:
	Project.files.added.connect(_on_added)
	Project.files.deleted.connect(_on_deleted)
	Project.files.moved.connect(_on_moved)
	Project.files.path_updated.connect(_on_path_updated)
	Project.files.nickname_changed.connect(_on_nickname_changed)
	Project.folders.folder_added.connect(_on_folder_added)
	Project.folders.folder_deleted.connect(_on_folder_deleted)
	Project.folders.folder_renamed.connect(_on_folder_renamed)

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
		_on_popup_option_pressed(POPUP_ACTION.DELETE)


func _on_project_ready() -> void:
	for folder: String in Project.data.folders:
		if !folder_items.has(folder):
			_add_folder_to_tree(folder)

	for id: int in Project.files.get_ids():
		_add_file_to_tree(id)


func _file_menu_pressed(id: int) -> void:
	match id:
		0: # Add file(s)
			var dialog: FileDialog = PopupManager.create_file_dialog(
					tr("Add files ..."), FileDialog.FILE_MODE_OPEN_FILES)

			add_child(dialog)
			dialog.files_selected.connect(Project.files.dropped)
			dialog.popup_centered()
		1: pass # TODO: Add text
		2: PopupManager.open_popup(PopupManager.POPUP.COLOR)


func _tree_item_clicked(_mouse_pos: Vector2, button_index: int, empty: bool = false) -> void:
	if button_index != MOUSE_BUTTON_RIGHT: return
	var file_item: TreeItem = folder_items["/"] if empty else tree.get_selected()
	var metadata: Variant = file_item.get_metadata(0)
	var popup: PopupMenu = PopupManager.create_menu()

	if str(metadata).is_valid_int(): # - File
		var id: int = int(metadata)
		var index: int = Project.files.get_index(id)
		var path: String = Project.files.get_path(index)
		var proxy_path: String = Project.files.get_proxy_path(index)
		var type: FileLogic.TYPE = Project.files.get_type(index)

		popup.add_item(tr("Rename"), POPUP_ACTION.RENAME)
		popup.add_item(tr("Reload"), POPUP_ACTION.RELOAD)
		popup.add_item(tr("Delete"), POPUP_ACTION.DELETE)

		if type == FileLogic.TYPE.IMAGE:
			if path.contains("temp://"):
				popup.add_separator(tr("Image options"))
				popup.add_item(tr("Save image as ..."), POPUP_ACTION.SAVE_TEMP_AS)
		elif type == FileLogic.TYPE.VIDEO:
			popup.add_separator(tr("Video options"))

			if Settings.get_use_proxies():
				if proxy_path == "":
					popup.add_item(tr("Create proxy"), POPUP_ACTION.CREATE_PROXY)
				else:
					popup.add_item(tr("Re-create proxy"), POPUP_ACTION.RECREATE_PROXY)
					popup.add_item(tr("Remove proxy"), POPUP_ACTION.REMOVE_PROXY)

			if Project.files.has_audio():
				popup.add_item(tr("Audio-take-over"), POPUP_ACTION.AUDIO_TAKE_OVER)
				if Project.files.has_ato(id):
					if Project.files.get_ato_active(id):
						popup.add_item(tr("Disable audio-take-over"), POPUP_ACTION.AUDIO_TAKE_OVER_DISABLE)
					else:
						popup.add_item(tr("Enable audio-take-over"), POPUP_ACTION.AUDIO_TAKE_OVER_ENABLE)

			popup.add_item(tr("Extract audio to file ..."), POPUP_ACTION.EXTRACT_AUDIO)
		elif type == FileLogic.TYPE.VIDEO_ONLY:
			popup.add_separator(tr("Video options"))

			if Settings.get_use_proxies():
				if !proxy_path.is_empty():
					popup.add_item(tr("Re-create proxy"), POPUP_ACTION.RECREATE_PROXY)
					popup.add_item(tr("Remove proxy"), POPUP_ACTION.REMOVE_PROXY)
				else: popup.add_item(tr("Create proxy"), POPUP_ACTION.CREATE_PROXY)

			if Project.files.has_audio():
				popup.add_item(tr("Audio-take-over"), POPUP_ACTION.AUDIO_TAKE_OVER)
				if Project.files.has_ato(id):
					if Project.files.get_ato_active(id):
						popup.add_item(tr("Disable audio-take-over"), POPUP_ACTION.AUDIO_TAKE_OVER_DISABLE)
					else: popup.add_item(tr("Enable audio-take-over"), POPUP_ACTION.AUDIO_TAKE_OVER_ENABLE)
		elif type == FileLogic.TYPE.TEXT:
			popup.add_separator(tr("Text options"))
			popup.add_item(tr("Duplicate"), POPUP_ACTION.DUPLICATE)

			if path.contains("temp://"):
				popup.add_item(tr("Save file as ..."), POPUP_ACTION.SAVE_TEMP_AS)

		popup.add_separator(tr("Folder options"))
		popup.add_item(tr("Create folder"), POPUP_ACTION.FOLDER_CREATE)
	else: # Folder
		var folder_path: String = str(metadata)
		popup.add_item(tr("Create folder"), POPUP_ACTION.FOLDER_CREATE)

		if folder_path != "/":
			popup.add_item(tr("Rename folder"), POPUP_ACTION.FOLDER_RENAME)
			popup.add_item(tr("Delete folder"), POPUP_ACTION.FOLDER_DELETE)

	popup.id_pressed.connect(_on_popup_option_pressed)
	PopupManager.show_popup_menu(popup)


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
		POPUP_ACTION.AUDIO_TAKE_OVER_ENABLE: _on_popup_action_audio_take_over_toggle()
		POPUP_ACTION.AUDIO_TAKE_OVER_DISABLE: _on_popup_action_audio_take_over_toggle()

		POPUP_ACTION.FOLDER_CREATE: _on_popup_action_folder_create()
		POPUP_ACTION.FOLDER_RENAME: _on_popup_action_folder_rename()
		POPUP_ACTION.FOLDER_DELETE: _on_popup_action_folder_delete()


func _on_popup_action_folder_create() -> void: _show_create_folder_dialog()
func _on_popup_action_folder_rename() -> void:
	var selected_item: TreeItem = tree.get_selected()
	var folder_path: String = str(selected_item.get_metadata(0))
	if not folder_path.ends_with("/") or folder_path == "/": return # Ensure it is a folder and not root
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

			if parent_path == "/": new_path = "/" + new_folder_name + "/"
			else: new_path = parent_path + "/" + new_folder_name + "/"

			var folder_index: int = Project.folders.get_index(folder_path)
			Project.folders.rename(folder_index, new_path)
		dialog.queue_free()

	dialog.confirmed.connect(confirm_lambda)
	line_edit.text_submitted.connect(confirm_lambda)

	add_child(dialog)
	dialog.popup_centered(Vector2(300, 100))
	line_edit.grab_focus()


func _on_popup_action_folder_delete() -> void:
	Project.folders.delete(str(tree.get_selected().get_metadata(0)))


func _on_popup_action_file_rename() -> void:
	var rename_dialog: FileRenameDialog = preload(Library.SCENE_RENAME_DIALOG).instantiate()
	rename_dialog.prepare(tree.get_selected().get_metadata(0))
	add_child(rename_dialog)


func _on_popup_action_file_reload() -> void:
	var id: int = tree.get_selected().get_metadata(0)
	Project.files._load_data(Project.files.get_id(id))


func _on_popup_action_file_delete() -> void:
	Project.files.delete(tree.get_selected().get_metadata(0))


func _on_popup_action_file_save_temp_as() -> void:
	var id: int = tree.get_selected().get_metadata(0)
	var type: FileLogic.TYPE = Project.files.get_type(id)

	if type == FileLogic.TYPE.TEXT: # TODO: Implement duplicating text files
		printerr("FilePanel: Not implemented yet!")
	elif type == FileLogic.TYPE.IMAGE:
		var dialog: FileDialog = PopupManager.create_file_dialog(
				tr("Save image to file"), FileDialog.FILE_MODE_SAVE_FILE, IMAGE_FORMATS)
		dialog.file_selected.connect(func(path: String) -> void:
				Project.files.save_image_to_file(id, path))
		add_child(dialog)
		dialog.popup_centered()


func _on_popup_action_file_extract_audio() -> void:
	var id: int = tree.get_selected().get_metadata(0)
	var dialog: FileDialog = PopupManager.create_file_dialog(
		tr("Save video audio to WAV"), FileDialog.FILE_MODE_SAVE_FILE, ["*.wav"])

	dialog.file_selected.connect(func(path: String) -> void:
			Project.files.save_audio_to_wav(id, path))
	add_child(dialog)
	dialog.popup_centered()


func _on_popup_action_file_duplicate() -> void: # Only for text.
	var id: int = tree.get_selected().get_metadata(0)
	var index: int = Project.files.get_index(id)
	var type: FileLogic.TYPE = Project.files.get_type(index)

	if type != FileLogic.TYPE.TEXT:
		return printerr("FilePanel: Duplicating only supported for text files right now!")
	# TODO: Implement this! Project.files.duplicate_text_file(id)


func _on_popup_action_file_create_proxy() -> void:
	ProxyHandler.request_generation(tree.get_selected().get_metadata(0))


func _on_popup_action_file_recreate_proxy() -> void:
	var file_id: int = tree.get_selected().get_metadata(0)

	ProxyHandler.delete_proxy(file_id)
	ProxyHandler.request_generation(file_id)


func _on_popup_action_file_remove_proxy() -> void:
	var id: int = tree.get_selected().get_metadata(0)
	Project.files.load_data(id)
	Project.files.nickname_changed.emit(id) # To update the name
	ProxyHandler.delete_proxy(id)


func _on_popup_action_audio_take_over() -> void:
	# TODO: Add this to undo_redo
	var file_id: int = tree.get_selected().get_metadata(0)
	var popup: Control = PopupManager.get_popup(PopupManager.POPUP.AUDIO_TAKE_OVER)
	popup.load_data(file_id, true)


func _on_popup_action_audio_take_over_toggle() -> void:
	Project.files.toggle_ato(tree.get_selected().get_metadata(0))


func _get_list_drag_data(_pos: Vector2) -> Draggable:
	var draggable: Draggable = Draggable.new()
	var selected: TreeItem = tree.get_next_selected(folder_items["/"])

	if selected == null: return
	draggable.files = true

	while true:
		var metadata: Variant = selected.get_metadata(0)
		var file_ids: PackedInt64Array = []

		if str(metadata).is_valid_int(): file_ids.append(int(metadata)) # Single file
		else: file_ids = _get_recursive_ids(selected) # Folder

		for file_id: int in file_ids:
			if file_id in draggable.ids: continue
			draggable.ids.append(file_id)
			draggable.duration += Project.files.get_duration_by_id(file_id)

		selected = tree.get_next_selected(selected)
		if selected == null: break # End of selected TreeItem's.
	return draggable


func _add_folder_to_tree(folder: String) -> void:
	if folder_items.has(folder): return print("FilePanel: Folder '%s' already exists!" % folder)

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


func _add_file_to_tree(id: int) -> void:
	var index: int = Project.files.get_index(id)
	var path: String = Project.files.get_path(index)
	var folder: String = Project.files.get_folder(index)
	var nickname: String = Project.files.get_nickname(index)

	# Create item for the file panel tree.
	if !folder_items.keys().has(folder): _add_folder_to_tree(folder)

	if Settings.get_use_proxies():
		var proxy_path: String = Project.files.get_nickname(index)
		if !proxy_path.is_empty() and FileAccess.file_exists(proxy_path):
			nickname += " [P]"

	file_items[id] = tree.create_item(folder_items[folder])
	file_items[id].set_text(0, nickname)
	file_items[id].set_tooltip_text(0, path)
	file_items[id].set_metadata(0, id)
	file_items[id].set_icon(0, Thumbnailer.get_thumb(id))
	file_items[id].set_icon_max_width(0, 70)

	# TODO: Use set_icon_modulate to indicate when a file is still loading,
	# this would make the files loading overlay obsolete. Just make certain
	# that the files with a modulate can't be selected yet and change their
	# tooltip to have "Loading ..." on it.
	_sort_folder(folder)


func _on_update_thumb(file_id: int) -> void:
	if !Project.files.has(file_id): return _on_deleted(file_id)
	file_items[file_id].set_icon(0, Thumbnailer.get_thumb(file_id))


func _sort_folder(folder: String) -> void:
	var folder_item: TreeItem = folder_items[folder]
	var folders: Dictionary[String, TreeItem] = {}
	var files: Dictionary[String, TreeItem] = {}
	var child: TreeItem = folder_item.get_first_child()

	while child:
		if str(child.get_metadata(0)).is_valid_int():
			files[child.get_text(0).to_lower()] = child
		else: folders[child.get_text(0).to_lower()] = child
		child = child.get_next()

	var last_item: TreeItem = null
	var folder_order: PackedStringArray = folders.keys()
	var files_order: PackedStringArray = files.keys()
	folder_order.sort()
	files_order.sort()

	for folder_name: String in folder_order:
		if last_item != null:
			folders[folder_name].move_after(last_item)
		last_item = folders[folder_name]

	for file_name: String in files_order:
		if last_item != null: files[file_name].move_after(last_item)
		last_item = files[file_name]


func _on_added(file_id: int) -> void:
	# There's a possibility that the file was too large
	# and that it did not get added.
	_add_file_to_tree(file_id)


func _on_deleted(file_id: int) -> void:
	if file_items.has(file_id):
		file_items[file_id].get_parent().remove_child(file_items[file_id])
		file_items.erase(file_id)


func _on_moved(file_id: int) -> void:
	if file_items.has(file_id):
		_on_deleted(file_id)
		_add_file_to_tree(file_id)


func _on_path_updated(id: int) -> void:
	file_items[id].set_tooltip_text(0, Project.files.get_path_by_id(id))


func _on_nickname_changed(id: int) -> void:
	var index: int = Project.files.get_index(id)
	var proxy_path: String = Project.files.get_proxy_path(index)
	var display_name: String = Project.files.get_nickname(index)

	if Settings.get_use_proxies() and !proxy_path.is_empty() and FileAccess.file_exists(proxy_path):
		display_name += " [P]"

	file_items[id].set_text(0, display_name)
	_sort_folder(Project.files.get_folder(index))


func _on_folder_added(path: String) -> void:
	if !folder_items.has(path): _add_folder_to_tree(path)


func _on_folder_deleted(path: String) -> void:
	if folder_items.has(path):
		var item: TreeItem = folder_items[path]
		item.free()
		folder_items.erase(path)


func _on_folder_renamed(old_path: String, new_path: String) -> void:
	var paths_to_update: PackedStringArray = []
	var length: int = old_path.length()

	for folder_path: String in folder_items.keys():
		if folder_path.begins_with(old_path): paths_to_update.append(folder_path)

	# Update items mapping and metadata
	for folder_path: String in paths_to_update:
		var updated_path: String = new_path + folder_path.substr(length)
		var item: TreeItem = folder_items[folder_path]

		folder_items.erase(folder_path)
		folder_items[updated_path] = item
		item.set_metadata(0, updated_path)

		# Rename the actual path of the exact folder
		if folder_path == old_path:
			var new_folder_name: String = new_path.trim_suffix("/").get_file()
			item.set_text(0, new_folder_name)

	var parent_path: String = new_path.trim_suffix("/").get_base_dir()
	if parent_path in ["", "/"]: parent_path = "/"
	else: parent_path += "/"
	_sort_folder(parent_path)


func _get_recursive_ids(item: TreeItem) -> PackedInt64Array:
	var ids: PackedInt64Array = []
	var child: TreeItem = item.get_first_child()

	while child:
		var metadata: Variant = child.get_metadata(0)
		if str(metadata).is_valid_int(): ids.append(int(metadata)) # File
		else: ids.append_array(_get_recursive_ids(child)) # Folder
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
		if new_folder_name not in ["", "/"]: _create_folder_at_selected(new_folder_name)
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
			parent_path = Project.files.get_folder_by_id(metadata)
		else: parent_path = str(metadata)

	if not parent_path.ends_with("/"): parent_path += "/"

	var full_path: String = parent_path + folder_name + "/"
	if full_path not in folder_items: Project.foldes.add(full_path)


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

	Project.files.move(data.ids, target_folder)
