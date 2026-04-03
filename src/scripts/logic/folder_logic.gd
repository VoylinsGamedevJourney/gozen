extends Node

signal added(path: String)
signal deleted(path: String)
signal path_changed(old_path: String, new_path: String)


var folders: Array[String]



# --- Handling ---

func add(folder: String) -> void:
	if !folders.has(folder):
		InputManager.undo_redo.create_action("Add folder")
		InputManager.undo_redo.add_do_method(_add.bind(folder))
		InputManager.undo_redo.add_undo_method(_delete.bind(folder))
		InputManager.undo_redo.commit_action()


func _add(folder: String) -> void:
	folders.append(folder)
	folders.sort()
	Project.unsaved_changes = true
	added.emit(folder)


func delete(folder: String) -> void:
	if folders.find(folder) == -1:
		return printerr("FolderLogic: No folder '%s' could be found!" % folder)

	# Get all subfolders to delete.
	var folders_to_delete: Array[String] = []
	for path: String in folders:
		if path.begins_with(folder):
			folders_to_delete.append(path)
	folders_to_delete.reverse() # Folders should be sorted already.

	# Get all files from the folder and subfolders to delete.
	var files_to_delete: Array[FileData] = []
	for file: FileData in FileLogic.files.values():
		if file.folder.begins_with(folder):
			files_to_delete.append(file)
	files_to_delete.sort()
	files_to_delete.reverse()

	# Get all the clips to delete.
	var clips_to_delete: Array[ClipData] = []
	for clip: ClipData in ClipLogic.clips.values():
		if clip.file in files_to_delete:
			clips_to_delete.append(clip)
	clips_to_delete.sort()
	clips_to_delete.reverse()

	InputManager.undo_redo.create_action("Delete folder")

	# Start by deleting folders.
	for path: String in folders_to_delete:
		InputManager.undo_redo.add_do_method(_delete.bind(path))
		InputManager.undo_redo.add_undo_method(_add.bind(path))

	# And remove files from the folder + subfolders.
	for file: FileData in files_to_delete:
		InputManager.undo_redo.add_do_method(FileLogic._delete.bind(file))
		InputManager.undo_redo.add_undo_method(FileLogic._restore.bind(file))

	# End by deleting all clips.
	for clip: ClipData in clips_to_delete:
		InputManager.undo_redo.add_do_method(ClipLogic._delete.bind(clip))
		InputManager.undo_redo.add_undo_method(ClipLogic._restore_clip.bind(clip))
	InputManager.undo_redo.commit_action()


func _delete(path: String) -> void:
	folders.remove_at(folders.find(path))
	Project.unsaved_changes = true
	deleted.emit(path)


func rename(old_name: String, new_name: String) -> void:
	if old_name == "/" or folders.has(new_name):
		return

	var folders_to_rename: Array[String] = []
	var new_names: Array[String] = []
	for path: String in folders:
		if path.begins_with(old_name):
			folders_to_rename.append(path)
			new_names.append(new_name + path.trim_prefix(old_name))

	InputManager.undo_redo.create_action("Rename folder")
	for i: int in folders_to_rename.size():
		InputManager.undo_redo.add_do_method(_rename.bind(folders_to_rename[i], new_names[i]))
		InputManager.undo_redo.add_undo_method(_rename.bind(new_names[i], folders_to_rename[i]))
	InputManager.undo_redo.commit_action()


func _rename(old_path: String, new_path: String) -> void:
	var folder_index: int = folders.find(old_path)
	if folder_index != -1:
		folders[folder_index] = new_path
	path_changed.emit(old_path, new_path)

	for file: FileData in FileLogic.files.values():
		if file.folder == old_path:
			file.folder = new_path
