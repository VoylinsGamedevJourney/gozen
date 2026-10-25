extends Node

signal added(path: String)
signal deleted(path: String)
signal path_changed(old_path: String, new_path: String)


var folders: Array[String]



#--- Handling ---

func add(folder: String) -> void:
	if !folders.has(folder):
		UndoManager.create_action("Add folder")
		UndoManager.add_do(_add.bind(folder))
		UndoManager.add_undo(_delete.bind(folder))
		UndoManager.commit_action()


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
	# Get all files from the folder and subfolders to delete.
	var files_to_delete: Array[FileData] = []
	var file_ids_to_delete: Array[int] = []
	for file: FileData in FileLogic.files.values():
		if file.folder.begins_with(folder):
			files_to_delete.append(file)
			file_ids_to_delete.append(file.id)
	files_to_delete.sort()
	files_to_delete.reverse()

	# Get all the clips to delete.
	var clips_to_delete: Array[ClipData] = []
	for clip: ClipData in ClipLogic.clips.values():
		if clip.file in file_ids_to_delete:
			clips_to_delete.append(clip)
	clips_to_delete.sort()
	clips_to_delete.reverse()

	UndoManager.create_action("Delete folder")

	# Start by deleting all clips.
	for clip: ClipData in clips_to_delete:
		UndoManager.add_do(ClipLogic._delete.bind(clip))
		UndoManager.add_undo(ClipLogic._restore_clip.bind(clip))

	# Remove files from the folder + subfolders.
	for file: FileData in files_to_delete:
		UndoManager.add_do(FileLogic._delete.bind(file))
		UndoManager.add_undo(FileLogic._restore.bind(file))

	# End by deleting folders.
	for path: String in folders_to_delete:
		UndoManager.add_do(_delete.bind(path))
		UndoManager.add_undo(_add.bind(path))

	UndoManager.commit_action()


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

	UndoManager.create_action("Rename folder")
	for i: int in folders_to_rename.size():
		UndoManager.add_do(_rename.bind(folders_to_rename[i], new_names[i]))
		UndoManager.add_undo(_rename.bind(new_names[i], folders_to_rename[i]))
	UndoManager.commit_action()


func _rename(old_path: String, new_path: String) -> void:
	var folder_index: int = folders.find(old_path)
	if folder_index != -1:
		folders[folder_index] = new_path
	path_changed.emit(old_path, new_path)

	for file: FileData in FileLogic.files.values():
		if file.folder == old_path:
			file.folder = new_path
