extends Node
# At this moment, adding + removing files/folders is permanent,
# can not be undone. This may change later, but not anytime soon.


signal _on_file_added(file_id: int)
signal _on_file_removed(file_id: int)
signal _on_file_nickname_changed(file_id: int)

signal _on_folder_added(path: String)
signal _on_folder_removed(path: String)



func _ready() -> void:
	if get_window().files_dropped.connect(_on_files_dropped):
		printerr("Could not connect to files_dropped")


#------------------------------------------------ FILE HANDLING
func _on_files_dropped(a_files: PackedStringArray) -> void:
	for l_path: String in a_files:
		add_file(l_path)
		Project._changes_occurred()


func add_file(a_path: String) -> void:
	var l_file: File = File.open(a_path)
	
	var l_duplicate: bool = false
	for l_id: int in Project.files:
		if Project.files[l_id].path == l_file.path:
			l_duplicate = true
			break

		# TODO: When 4.4 comes, use typed dictionary to get rid of this Variant warning.
		if Project.files[l_id].sha256 == l_file.sha256 or a_path.get_extension() == Project.files[l_id].path.get_extension():
			l_duplicate = true
			break

	if l_duplicate:
		printerr("Files is a duplicate!")
		return
	
	l_file.id = Project.counter_file_id
	Project.files[l_file.id] = l_file
	if !Project._add_file_data(l_file.id):
		if !Project.files.erase(l_file.id):
			printerr("Couldn't erase %s from files!" % l_file.id)
		printerr("File data could not be loaded!")
		return

	Project.counter_file_id += 1

	Project._changes_occurred()
	_on_file_added.emit(l_file.id)


func remove_file(a_id: int) -> void:
	if !Project.files.erase(a_id):
		printerr("Couldn't remove file id %s from project files!" % a_id)
		return
	if Project._files_data.erase(a_id):
		printerr("Couldn't remove file data id %s from project files!" % a_id)
		return

	Project._changes_occurred()
	_on_file_removed.emit(a_id)


func change_file_nickname(a_id: int, a_nickname: String) -> void:
	Project.files[a_id].nickname = a_nickname
	Project._changes_occurred()
	_on_file_nickname_changed.emit(a_id)



#------------------------------------------------ FOLDER HANDLING
func add_folder(a_path: String) -> void:
	if !Project.folders.append(a_path):
		printerr("Error happend appending folder!")
		return

	Project._changes_occurred()
	_on_folder_added.emit(a_path)


func remove_folder(a_path: String) -> void:
	var l_paths: PackedStringArray = []

	for l_folder: String in Project.folders:
		if a_path in l_folder:
			CoreError.err_append([l_paths.append(l_folder)])
			Project.folders.remove_at(Project.folders.find(l_folder))		

	for l_file: File in Project.files.values:
		if l_file.location in l_paths:
			var l_id: int = l_file.id

			l_file.free()
			CoreError.err_erase([
					Project._files_data.erase(l_id),
					Project.files.erase(l_id)])


	Project._changes_occurred()
	_on_folder_removed.emit(a_path)

