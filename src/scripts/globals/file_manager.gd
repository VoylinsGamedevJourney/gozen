extends Node

signal file_added(id: int)
signal file_deleted(id: int)
signal file_nickname_changed(id: int)
signal file_path_updated(id: int)

signal error_file_too_big(id: int)


enum STATUS {
	ALREADY_LOADED = -2,
	PROBLEM = -1,
	LOADING = 0,
	LOADED = 1,
}


var data: Dictionary [int, FileData] = {}



#--- File Manager functions ---
func _ready() -> void:
	Utils.connect_func(get_window().files_dropped, files_dropped)
	Utils.connect_func(error_file_too_big, _on_file_too_big)


func files_dropped(file_paths: PackedStringArray) -> void:
	# Only allow files to be dropped in non-empty projects.
	if data == null:
		return

	var files: Array[FileDrop] = []

	# Find files inside of subfolders.
	file_paths = Utils.find_subfolder_files(file_paths)

	# Check for file duplicates.
	for path: String in get_file_paths():
		if path in file_paths and !file_paths.erase(path):
			Print.erase_error()
			continue

	# Add files for processing.
	for path: String in file_paths:
		files.append(FileDrop.new(path))

	if file_paths.size() == 0:
		return

	var dropped_overlay: ProgressOverlay = preload(Library.SCENE_PROGRESS_OVERLAY).instantiate()
	var progress_increment: float = (1 / float(files.size())) * 50

	get_tree().root.add_child(dropped_overlay)
	dropped_overlay.set_state_file_loading(files.size())
	dropped_overlay.update_title("title_files_dropped")
	dropped_overlay.update_progress(0, "")
	await RenderingServer.frame_post_draw

	# Updating the overlay to show all files in the list for files to load.
	for file: FileDrop in files:
		dropped_overlay.update_file(file)

	while files.size() != 0:
		for file: FileDrop in files:
			if file.id == -1:
				add_file(file)
				dropped_overlay.update_file(file)
				dropped_overlay.increment_progress_bar(progress_increment)
				await RenderingServer.frame_post_draw

			if file.status == STATUS.ALREADY_LOADED:
				dropped_overlay.update_file(file)
				dropped_overlay.increment_progress_bar(progress_increment)
				files.erase(file)
				await RenderingServer.frame_post_draw
				continue

			if get_file_data(file.id) != null:
				if get_file(file.id).type == File.TYPE.VIDEO:
					if !has_file(file.id):
						file.status = STATUS.PROBLEM
					elif get_file_data(file.id).video == null or !get_file_data(file.id).video.is_open():
						continue

				if file.status != STATUS.PROBLEM:
					file.status = STATUS.LOADED
					file_added.emit(file.id)

				dropped_overlay.update_file(file)
				dropped_overlay.increment_progress_bar(progress_increment)
				await RenderingServer.frame_post_draw

				files.erase(file)

	Project._unsaved_changes = true
	await RenderingServer.frame_post_draw
	dropped_overlay.queue_free()


func reset_data() -> void:
	data = {}


func load_file_data(file_id: int) -> bool:
	var temp_file_data: FileData = FileData.new()

	if !temp_file_data.init_data(file_id):
		delete_file(file_id)
		return false

	data[file_id] = temp_file_data
	return true


func reload_file_data(id: int) -> void:
	data[id].queue_free()
	await RenderingServer.frame_pre_draw
	if !load_file_data(id):
		delete_file(id)
		print("File became invalid!")


func add_file(file_drop: FileDrop) -> void:
	# Check if file already exists inside of the project.
	for existing: File in get_files().values():
		if existing.path == file_drop.path:
			print("File already loaded with path '%s'!" % file_drop.path)
			file_drop.status = STATUS.ALREADY_LOADED
			return

	var file: File = File.create(file_drop.path)

	if file == null:
		file_drop.status = STATUS.PROBLEM
		return

	set_file(file.id, file)
	if !load_file_data(file.id):
		printerr("Problem happened adding file!")
		file_drop.status = STATUS.PROBLEM
		return
	else:
		file_drop.id = file.id


func add_file_object(file: File) -> void:
	# Used for adding temp files.
	set_file(file.id, file)

	if !load_file_data(file.id):
		print("Something went wrong loading file '", file.path, "'!")

	# We only emit this one since for dropped/selected actual files this gets
	# called inside of _on_files_dropped.
	file_added.emit(file.id)
	Project._unsaved_changes = true


func delete_file(id: int) -> void:
	for clip: ClipData in Project.get_clip_datas():
		if clip.file_id == id:
			Timeline.instance.delete_clip(clip)

	if (data.has(id) and !data.erase(id)) or (get_files().has(id) and !get_files().erase(id)):
		Print.erase_error()

	await RenderingServer.frame_pre_draw
	file_deleted.emit(id)
	Project._unsaved_changes = true


## Check to see if a file needs reloading or not.
func check_modified_files() -> void:
	# TODO: Run function on re-focussing on the editor.
	for file: File in get_files().values():
		if _check_if_file_modified(file):
			var new_modified_time: int = FileAccess.get_modified_time(file.path)

			if file.modified_time != new_modified_time or file.modified_time == -1:
				file.modified_time = new_modified_time
				reload_file_data(file.id)



#-- File creators ---
## Save the image and replace the path in the file object to the new image file.
func save_image_to_file(path: String, file: File) -> void:
	var extension: String = path.get_extension().to_lower()
	var image: Image = file.temp_file.image_data.get_image()

	match extension:
		"png":
			if image.save_png(path):
				printerr("Couldn't save image to png!\n", get_stack())
				return
		"webp":
			if image.save_webp(path, false, 1.0):
				printerr("Couldn't save image to webp!\n", get_stack())
				return
		_: # JPG is default.
			if image.save_jpg(path, 1.0):
				printerr("Couldn't save image to jpg!\n", get_stack())
				return

	file.path = path
	file.temp_file.free()
	file.temp_file = null

	if !load_file_data(file.id):
		printerr("Something went wrong loading file '%s' after saving temp image to real image!" % path)

	file_path_updated.emit(file.id)


func save_audio_to_wav(path: String, file: File) -> void:
	if get_file_data(file.id).audio.save_to_wav(path):
		printerr("Error occured when saving to WAV!")



#-- File setters & getters --- 
func has_file(file_id: int) -> bool:
	return get_files().has(file_id)


func set_file(file_id: int, file: File) -> void:
	get_files()[file_id] = file
	Project._unsaved_changes = true


func set_file_nickname(file_id: int, nickname: String) -> void:
	get_files()[file_id].nickname = nickname
	Project._unsaved_changes = true

	file_nickname_changed.emit(file_id)


func get_files() -> Dictionary[int, File]:
	return Project.get_files()


func get_file_paths() -> PackedStringArray:
	var paths: PackedStringArray = []

	for file: File in get_files().values():
		if paths.append(file.path):
			Print.append_error()

	return paths


func get_file_ids() -> PackedInt64Array:
	return get_files().keys()


func get_file(id: int) -> File:
	return get_files()[id]


func get_file_data(id: int) -> FileData:
	return data[id]



#--- Private functions ---
func _check_if_file_modified(file: File) -> bool:
	# Temp files can't change.
	if file.path.begins_with("temp://"):
		return false

	# File doesn't exist anymore, removing file.
	if !FileAccess.file_exists(file.path):
		print("File %s at %s doesn't exist anymore!" % [file.id, file.path])
		delete_file(file.id)
		return false

	return true


func _on_file_too_big(file_id: int) -> void:
	var dialog: AcceptDialog = AcceptDialog.new()
	var file_path: String = get_files()[file_id].path

	dialog.title = "title_dialog_file_too_big"
	dialog.dialog_text = file_path
	add_child(dialog)
	dialog.popup_centered()

	if !get_files().erase(file_id) or !data.erase(file_id):
		Print.erase_error()



#-- Classes ---
class FileDrop:
	var id: int = -1
	var path: String = ""
	var status: FileManager.STATUS = FileManager.STATUS.LOADING


	func _init(_path: String) -> void:
		path = _path

