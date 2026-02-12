class_name FolderLogic
extends RefCounted

signal added(index: int)
signal deleted(path: String)
signal renamed(old_path: String, new_path: String)


var project_data: ProjectData


# --- Main ---

func _init(data: ProjectData) -> void:
	project_data = data

# --- Handling ---

func add(folder: String) -> void:
	if project_data.folders.has(folder):
		return printerr("FolderLogic: Folder %s already exists!")

	InputManager.undo_redo.create_action("Add folder")
	InputManager.undo_redo.add_do_method(_add.bind(folder))
	InputManager.undo_redo.add_undo_method(_delete.bind(folder))
	InputManager.undo_redo.commit_action()


func _add(folder: String) -> void:
	var index: int = project_data.folders.size()
	project_data.folders.append(folder)
	Project.unsaved_changes = true
	added.emit(index)


func delete(folder: String) -> void:
	var folder_index: int = project_data.folders.find(folder)
	if folder_index == -1:
		return printerr("FolderLogic: No folder '%s' could be found!" % folder)

	# Get all subfolders to delete.
	var folders_to_delete: PackedInt64Array = []
	for i: int in project_data.folders.size():
		if project_data.folders[i].begins_with(folder):
			folders_to_delete.append(i)
	folders_to_delete.sort()
	folders_to_delete.reverse()

	# Get all files from the folder and subfolders to delete.
	var files_to_delete: PackedInt64Array = []
	var file_ids: PackedInt64Array = []
	for i: int in project_data.files_folder.size():
		if project_data.files_folder[i].begins_with(folder):
			files_to_delete.append(i)
			file_ids.append(project_data.files_id[i])
	files_to_delete.sort()
	files_to_delete.reverse()

	# Get all the clips to delete.
	var clips_to_delete: PackedInt64Array = []
	for i: int in project_data.clips_file_id.size():
		if project_data.clips_file_id[i] in files_to_delete:
			clips_to_delete.append(i)
	clips_to_delete.sort()
	clips_to_delete.reverse()

	InputManager.undo_redo.create_action("Delete folder")

	# Start by deleting folders.
	for index: int in folders_to_delete:
		var folder_path: String = project_data.folders[index]
		InputManager.undo_redo.add_do_method(_delete.bind(index))
		InputManager.undo_redo.add_undo_method(_add.bind(folder_path))

	# And remove files from the folder + subfolders.
	for index: int in files_to_delete:
		InputManager.undo_redo.add_do_method(Project.files._delete.bind(index))
		InputManager.undo_redo.add_undo_method(Project.files._add.bind(index))

	# End by deleting all clips.
	for clip_index: int in clips_to_delete:
		var clips: ClipLogic = Project.clips
		var snapshot: Dictionary = clips._create_snapshot(clip_index)
		InputManager.undo_redo.add_do_method(clips._delete.bind(clip_index))
		InputManager.undo_redo.add_undo_method(clips._restore_clip_from_snapshot.bind(snapshot))
	InputManager.undo_redo.commit_action()


func _delete(index: int) -> void:
	var folder_path: String = project_data.folders[index]
	project_data.folders.remove_at(index)
	Project.unsaved_changes = true
	deleted.emit(folder_path)


func rename(index: int, new_name: String) -> void:
	var old_root: String = project_data.folders[index]
	if old_root == "/" or project_data.folders.has(new_name):
		return

	var folders_to_rename: PackedInt64Array = []
	var old_names: PackedStringArray = []
	var new_names: PackedStringArray = []
	for i: int in project_data.folders.size():
		var path: String = project_data.folders[index]
		if path.begins_with(old_root):
			folders_to_rename.append(i)
			old_names.append(path)
			new_names.append(new_name + path.trim_prefix(old_root))

	InputManager.undo_redo.create_action("Rename folder")
	for i: int in folders_to_rename:
		InputManager.undo_redo.add_do_method(_rename.bind(folders_to_rename[i], new_names[i]))
		InputManager.undo_redo.add_undo_method(_rename.bind(folders_to_rename[i], old_names[i]))
	InputManager.undo_redo.commit_action()


func _rename(folder_index: int, new_path: String) -> void:
	var old_path: String = project_data.folders[folder_index]
	project_data.folders[folder_index] = new_path
	renamed.emit(old_path, new_path)

	for file_index: int in Project.files.size(): # Update files.
		if Project.data.files_folder[file_index] != old_path:
			continue
		project_data.files_folder[file_index] = new_path
