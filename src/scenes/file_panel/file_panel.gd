extends PanelContainer

enum POPUP_ACTION { RENAME, DELETE, RELOAD, SAVE_AS, EXTRACT_AUDIO, DUPLICATE }


@export var tree: Tree
@export var file_menu_button: MenuButton

var folder_items: Dictionary[String, TreeItem] = {}
var file_items: Dictionary[int, TreeItem] = {} # { file_id: tree_item }



func _ready() -> void:
	FileHandler.file_added.connect(_on_file_added)
	FileHandler.file_deleted.connect(_on_file_deleted)
	FileHandler.file_path_updated.connect(_on_file_path_updated)
	FileHandler.file_nickname_changed.connect(_on_file_nickname_changed)

	Project.project_ready.connect(_on_project_ready)

	Thumbnailer.thumb_generated.connect(_on_update_thumb)

	tree.item_mouse_selected.connect(_file_item_clicked)
	tree.gui_input.connect(_on_tree_gui_input)

	tree.set_drag_forwarding(_get_list_drag_data, Callable(), Callable())
	folder_items["/"] = tree.create_item()

	# Setting the max width needs to be done in this way.
	for i: int in file_menu_button.item_count:
		file_menu_button.get_popup().set_item_icon_max_width(i, 21)

	file_menu_button.get_popup().id_pressed.connect(_file_menu_pressed)


func _on_tree_gui_input(event: InputEvent) -> void:
	if tree.get_selected() != null and event.is_action("delete_file"):
		var file_id: int = tree.get_selected().get_metadata(0)
		_on_popup_option_pressed(POPUP_ACTION.DELETE, FileHandler.get_file(file_id))


func _on_project_ready() -> void:
	for folder: String in Project.get_folders():
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

			dialog.files_selected.connect(FileHandler.files_dropped)
			add_child(dialog)
			dialog.popup_centered()
		1: # TODO: Add text
			pass
		2: PopupManager.open_popup(PopupManager.POPUP.COLOR)


func _file_item_clicked(_mouse_pos: Vector2, button_index: int) -> void:
	# TODO: Create popup menu's and save them as scene's instead.
	var file_item: TreeItem = tree.get_selected()

	if button_index != MOUSE_BUTTON_RIGHT:
		return

	var file: File = null
	var popup: PopupMenu = PopupManager.create_popup_menu()

	if !str(file_item.get_metadata(0)).is_valid_int(): # FOLDER
		popup.add_item("popup_item_rename", POPUP_ACTION.RENAME)
		popup.add_item("popup_item_delete", POPUP_ACTION.DELETE)

		PopupManager.show_popup_menu(popup)
	else: # FILE
		var file_id: int = file_item.get_metadata(0)
		file = FileHandler.get_file(file_id)

		popup.add_item("popup_item_rename", POPUP_ACTION.RENAME)
		popup.add_item("popup_item_reload", POPUP_ACTION.RELOAD)
		popup.add_item("popup_item_delete", POPUP_ACTION.DELETE)

		if file.type == File.TYPE.IMAGE:
			if file.path.contains("temp://"):
				popup.add_separator("popup_separator_image_options")
				popup.add_item("popup_item_save_as_file", POPUP_ACTION.SAVE_AS)
		if file.type == File.TYPE.VIDEO:
			popup.add_separator("popup_separator_video_options")
			popup.add_item("popup_item_extract_audio", POPUP_ACTION.EXTRACT_AUDIO)
		if file.type == File.TYPE.TEXT:
			popup.add_separator("popup_separator_text_options")
			popup.add_item("popup_item_duplicate", POPUP_ACTION.DUPLICATE)
			if file.path.contains("temp://"):
				popup.add_item("popup_item_save_as_file", POPUP_ACTION.SAVE_AS)

	popup.id_pressed.connect(_on_popup_option_pressed.bind(file))
	PopupManager.show_popup_menu(popup)


## For the right click presses of the file popup menu's.
func _on_popup_option_pressed(option_id: int, file: File) -> void:
	# TODO: Change this with the change to make popups into separate scene's instead.

	if file == null:
		# TODO:
		printerr("Folder renaming and deleting not implemented yet!")

	match option_id:
		POPUP_ACTION.RENAME:
			var rename_dialog: FileRenameDialog = preload(Library.SCENE_RENAME_DIALOG).instantiate()

			rename_dialog.prepare(file.id)
			get_tree().root.add_child(rename_dialog)
		POPUP_ACTION.RELOAD:
			FileHandler.reload_file_data(file.id)
		POPUP_ACTION.DELETE:
			InputManager.undo_redo.create_action("Delete file")
			# Deleting file from tree and project data.
			InputManager.undo_redo.add_do_method(_on_file_deleted.bind(file.id))
			InputManager.undo_redo.add_do_method(FileHandler.delete_file.bind(file.id))

			InputManager.undo_redo.add_undo_method(FileHandler.add_file_object.bind(file))
			InputManager.undo_redo.add_undo_method(_add_file_to_tree.bind(file.id))

			# Making certain clips will be returned when deleting of file is un-done.
			for clip_data: ClipData in ClipHandler.get_clip_datas():
				if clip_data.file_id == file.id:
					InputManager.undo_redo.add_undo_method(ClipHandler.add_clip.bind(clip_data))

			InputManager.undo_redo.commit_action()
		POPUP_ACTION.SAVE_AS: # Only for temp files such as Images.
			if file.type == File.TYPE.TEXT:
				# TODO: Implement duplicating text files
				printerr("Not implemented yet!")
			elif file.type == File.TYPE.IMAGE:
				var dialog: FileDialog = PopupManager.create_file_dialog(
						"title_save_image_to_file",
						FileDialog.FILE_MODE_SAVE_FILE,
						["*.png", "*.jpg", "*.webp"])

				dialog.file_selected.connect(FileHandler.save_image_to_file.bind(file))
				add_child(dialog)
				dialog.popup_centered()
		POPUP_ACTION.EXTRACT_AUDIO:
			var dialog: FileDialog = PopupManager.create_file_dialog(
					"title_save_video_audio_to_wav",
					FileDialog.FILE_MODE_SAVE_FILE,
					["*.wav"])

			dialog.file_selected.connect(FileHandler.save_audio_to_wav.bind(file))
			add_child(dialog)
			dialog.popup_centered()
		POPUP_ACTION.DUPLICATE: # Only for text
			# TODO: Implement duplicating text files
			printerr("Duplicating text not implemented yet!")


func _get_list_drag_data(_pos: Vector2) -> Draggable:
	var draggable: Draggable = Draggable.new()
	var selected: TreeItem = tree.get_next_selected(folder_items["/"])

	if selected == null:
		return

	draggable.files = true

	# TODO: Make this work when dragging folders.
	# For this we need to make certain that when dragging folders, we don't add
	# them but their sub-files.
	while true:
		if !str(selected.get_metadata(0)).is_valid_int():
			continue # Folder

		var file_id: int = selected.get_metadata(0)
		draggable.ids.append(file_id)

		var file_duration: int = FileHandler.get_file_duration(file_id) 
		if file_duration <= 0:
			file_duration = FileHandler.update_file_duration(file_id)

		draggable.duration += file_duration

		selected = tree.get_next_selected(selected)
		if selected == null:
			break # End of selected TreeItem's.

	return draggable


func _add_folder_to_tree(folder: String) -> void:
	if folder_items.has(folder):
		print("Folder '%s' already exists!" % folder)
		return

	# Check if all parent folders exist or not.
	var folders: PackedStringArray = folder.split('/', false)
	var check_path: String = "/"
	var previous_folder: TreeItem = folder_items["/"]

	for i: int in folders.size():
		check_path += folders[i] + "/"

		if !folder_items.has(check_path):
			folder_items[check_path] = tree.create_item(previous_folder)
			folder_items[check_path].set_text(0, folders[-1])
			folder_items[check_path].set_metadata(0, check_path)
			_sort_folder(check_path)
			
		previous_folder = folder_items[check_path]


func _on_file_added(file_id: int) -> void:
	# There's a possibility that the file was too large
	# and that it did not get added.
	_add_file_to_tree(FileHandler.get_file(file_id))


func _on_file_deleted(file_id: int) -> void:
	if file_items.has(file_id):
		file_items[file_id].get_parent().remove_child(file_items[file_id])
		file_items.erase(file_id)


func _on_file_path_updated(file_id: int) -> void:
	file_items[file_id].set_tooltip_text(0, FileHandler.get_file(file_id).path)


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


func _on_file_nickname_changed(file_id: int) -> void:
	var file: File = FileHandler.get_file(file_id)

	file_items[file_id].set_text(0, file.nickname)
	_sort_folder(file.folder)
