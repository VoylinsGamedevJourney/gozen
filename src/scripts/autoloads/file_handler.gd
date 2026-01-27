extends Node

signal file_added(id: int)
signal file_deleted(id: int)
signal file_nickname_changed(id: int)
signal file_path_updated(id: int)
signal file_moved(id: int)
signal file_reloaded(id: int)

signal folder_added(folder_name: String)
signal folder_deleted(folder_name: String)
signal folder_renamed(old_folder_name: String, new_folder_name: String)

signal error_file_too_big(id: int)


enum STATUS {
	ALREADY_LOADED = -2,
	PROBLEM = -1,
	LOADING = 0,
	LOADED = 1,
}
enum TYPE {
	EMPTY = -1,
	IMAGE,
	AUDIO,
	VIDEO,
	VIDEO_ONLY, # No audio
	TEXT,
	COLOR,
	PCK
}

const TYPE_VIDEOS: Array = [TYPE.VIDEO, TYPE.VIDEO_ONLY]


var files: Dictionary[int, File] = {}
var data: Dictionary [int, FileData] = {}



#--- File Manager functions ---
func _ready() -> void:
	get_tree().root.focus_entered.connect(_on_window_focus_entered)
	get_window().files_dropped.connect(_on_files_dropped)
	error_file_too_big.connect(_on_file_too_big)


func _on_window_focus_entered() -> void:
	FileHandler.check_modified_files()


func _on_files_dropped(file_paths: PackedStringArray) -> void:
	# Only allow files to be dropped in non-empty projects.
	if data == null: return

	var dropped_files: Array[FileDrop] = []
	var dropped_overlay: ProgressOverlay
	var progress_increment: float

	# Find files inside of subfolders.
	file_paths = Utils.find_subfolder_files(file_paths)

	# Check for file duplicates.
	for path: String in get_file_paths():
		if path not in file_paths: continue

		file_paths.erase(path)
		Print.info("Duplicate file was dropped from path: %s", path)

	# Add files for processing.
	for path: String in file_paths:
		dropped_files.append(FileDrop.new(path))
	if file_paths.size() == 0: return

	dropped_overlay = PopupManager.get_popup(PopupManager.POPUP.PROGRESS)
	progress_increment = (1 / float(dropped_files.size())) * 50
	dropped_overlay.set_state_file_loading(dropped_files.size())
	dropped_overlay.update_title("title_files_dropped")
	dropped_overlay.update_progress(0, "")
	await RenderingServer.frame_post_draw

	# Updating the overlay to show all files in the list for files to load.
	for file: FileDrop in dropped_files:
		dropped_overlay.update_file(file)

	while dropped_files.size() != 0:
		for file: FileDrop in dropped_files:
			if file.id == -1:
				add_file(file)
				dropped_overlay.update_file(file)
				dropped_overlay.increment_progress_bar(progress_increment)
				await RenderingServer.frame_post_draw

			if file.status == STATUS.ALREADY_LOADED:
				dropped_overlay.update_file(file)
				dropped_overlay.increment_progress_bar(progress_increment)
				dropped_files.erase(file)
				await RenderingServer.frame_post_draw
				continue

			if get_file_data(file.id) == null: continue

			if get_file(file.id).type in TYPE_VIDEOS:
				if !has_file(file.id): file.status = STATUS.PROBLEM
				elif get_file_data(file.id).video == null: continue
				elif !get_file_data(file.id).video.is_open(): continue

			if file.status != STATUS.PROBLEM:
				file.status = STATUS.LOADED
				file_added.emit(file.id)

			dropped_overlay.update_file(file)
			dropped_overlay.increment_progress_bar(progress_increment)
			await RenderingServer.frame_post_draw

			dropped_files.erase(file)

	Project.unsaved_changes = true
	await RenderingServer.frame_post_draw
	PopupManager.close_popup(PopupManager.POPUP.PROGRESS)


func reset_data() -> void:
	data = {}


func load_file_data(file_id: int) -> bool:
	var temp_file_data: FileData = FileData.new()

	if !temp_file_data.init_data(file_id):
		_delete_file(file_id)
		return false

	data[file_id] = temp_file_data
	return true


func reload_file_data(id: int) -> void:
	if data.has(id): data.erase(id)

	await RenderingServer.frame_pre_draw
	if !load_file_data(id):
		_delete_file(id)
		print_debug("File became invalid!")
	file_reloaded.emit(id)


func reload_all_video_files() -> void:
	for id: int in files:
		if files[id].type in TYPE_VIDEOS:
			reload_file_data(id)


func add_file(file_drop: FileDrop) -> void:
	# Check if file already exists inside of the project.
	for existing: File in files.values():
		if existing.path == file_drop.path:
			print("FileHandler: File already loaded with path '%s'!" % file_drop.path)
			file_drop.status = STATUS.ALREADY_LOADED
			return

	var file: File = create_file(file_drop.path)

	if file == null:
		file_drop.status = STATUS.PROBLEM
		return

	set_file(file.id, file)
	if !load_file_data(file.id):
		printerr("FileHandler: Problem happened adding file!")
		file_drop.status = STATUS.PROBLEM
		return
	else:
		file_drop.id = file.id


func delete_file(file_id: int) -> void:
	InputManager.undo_redo.create_action("Delete file")
	var file: File = FileHandler.get_file(file_id)

	# Deleting file from tree and project data.
	InputManager.undo_redo.add_do_method(_delete_file.bind(file_id))
	InputManager.undo_redo.add_do_method(file_deleted.emit.bind(file_id))

	InputManager.undo_redo.add_undo_method(add_file_object.bind(file))
	InputManager.undo_redo.add_undo_method(file_added.emit.bind(file_id))

	# Making certain clips will be returned when deleting of file is un-done.
	for clip_data: ClipData in ClipHandler.clips.values():
		if clip_data.file_id == file.id:
			InputManager.undo_redo.add_do_method(ClipHandler._delete_clip.bind(clip_data))
			InputManager.undo_redo.add_undo_method(ClipHandler._add_clip.bind(clip_data))

	InputManager.undo_redo.commit_action()


func move_files(file_ids: PackedInt64Array, target_folder: String) -> void:
	InputManager.undo_redo.create_action("Move file(s)")

	for file_id: int in file_ids:
		var file: File = get_file(file_id)

		InputManager.undo_redo.add_do_method(_move_file.bind(file_id, target_folder))
		InputManager.undo_redo.add_undo_method(_move_file.bind(file_id, file.folder))

	InputManager.undo_redo.commit_action()


func _move_file(file_id: int, target_folder: String) -> void:
	files[file_id].folder = target_folder
	file_moved.emit(file_id)
	Project.unsaved_changes = true


func create_file(file_path: String) -> File:
	var file: File = File.new()
	var extension: String = file_path.get_extension().to_lower()

	if extension in ProjectSettings.get_setting("extensions/image"):
		file.type = TYPE.IMAGE
		file.modified_time = FileAccess.get_modified_time(file_path)
	elif extension in ProjectSettings.get_setting("extensions/audio"):
		file.type = TYPE.AUDIO
		file.modified_time = FileAccess.get_modified_time(file_path)
	elif extension in ProjectSettings.get_setting("extensions/video"):
		file.type = TYPE.VIDEO # We check later if the video is audio only.
		file.modified_time = FileAccess.get_modified_time(file_path)
	elif file_path == "temp://image":
		file.type = TYPE.IMAGE
	elif file_path == "temp://text":
		file.type = TYPE.TEXT
	elif file_path == "temp://color":
		file.type = TYPE.COLOR
	elif extension == "pck":
		file.type = TYPE.PCK
	else:
		printerr("FileHandler: Invalid file: ", file_path)
		return null

	file.id = Utils.get_unique_id(FileHandler.get_file_ids())
	file.path = file_path

	if file_path.contains("temp://"):
		file.nickname = "%s %s" % [file_path.trim_prefix("temp://").capitalize(), file.id]
	else:
		file.nickname = file_path.get_file()

	return file


func check_valid(file_path: String) -> bool:
	if !FileAccess.file_exists(file_path): return false # Probably a temp file.

	var ext: String = file_path.get_extension().to_lower()
	return (
		ext in ProjectSettings.get_setting("extensions/image") or
		ext in ProjectSettings.get_setting("extensions/audio") or
		ext in ProjectSettings.get_setting("extensions/video"))


func add_file_object(file: File) -> void:
	# Used for adding temp files.
	set_file(file.id, file)

	if !load_file_data(file.id):
		print("FileHandler: Something went wrong loading file '", file.path, "'!")

	# We only emit this one since for dropped/selected actual files this gets
	# called inside of _on_files_dropped.
	file_added.emit(file.id)
	Project.unsaved_changes = true


func _delete_file(id: int) -> void:
	for clip: ClipData in ClipHandler.clips.values():
		if clip.file_id == id: ClipHandler._delete_clip(clip)

	if data.has(id):
		data.erase(id)
	if files.has(id):
		files.erase(id)

	await RenderingServer.frame_pre_draw
	file_deleted.emit(id)
	Project.unsaved_changes = true


## Check to see if a file needs reloading or not.
func check_modified_files() -> void:
	if !Project.loaded: return

	for file: File in files.values():
		if !_check_if_file_modified(file):
			continue

		# File modified, adjust time/date
		var new_modified_time: int = FileAccess.get_modified_time(file.path)

		if file.modified_time != new_modified_time or file.modified_time == -1:
			file.modified_time = new_modified_time
			reload_file_data(file.id)


func get_file_type(file_id: int) -> TYPE:
	return get_file(file_id).type


func get_file_name(file_id: int) -> String:
	return get_file(file_id).nickname


#-- File creators ---
## Save the image and replace the path in the file object to the new image file.
func save_image_to_file(path: String, file: File) -> void:
	const ERROR_MESSAGE: String = "FileHandler: Couldn't save image to %s!\n"
	var extension: String = path.get_extension().to_lower()
	var image: Image = file.temp_file.image_data.get_image()

	match extension:
		"png":
			if image.save_png(path):
				printerr(ERROR_MESSAGE % "png", get_stack())
				return
		"webp":
			if image.save_webp(path, false, 1.0):
				printerr(ERROR_MESSAGE % "webp", get_stack())
				return
		_: # JPG is default.
			if image.save_jpg(path, 1.0):
				printerr(ERROR_MESSAGE % "jpg", get_stack())
				return

	file.path = path
	file.temp_file.free()
	file.temp_file = null

	if !load_file_data(file.id):
		printerr("FileHandler: Something went wrong loading file '%s' after saving temp image to real image!" % path)

	file_path_updated.emit(file.id)


func save_audio_to_wav(path: String, file: File) -> void:
	if get_file_data(file.id).audio.save_to_wav(path):
		printerr("FileHandler: Error occured when saving to WAV!")


#-- File setters & getters --- 
func has_file(id: int) -> bool:
	return files.has(id)


func set_file(id: int, file: File) -> void:
	files[id] = file
	Project.unsaved_changes = true


func set_file_nickname(id: int, nickname: String) -> void:
	files[id].nickname = nickname
	Project.unsaved_changes = true
	file_nickname_changed.emit(id)


func update_file_duration(id: int) -> int:
	data[id]._update_duration()
	return get_file_duration(id)


func get_file_paths() -> PackedStringArray:
	var paths: PackedStringArray = []

	for file: File in files.values():
		paths.append(file.path)
	return paths


func get_file_ids() -> PackedInt64Array:
	return files.keys()


func get_file_objects() -> Array[File]:
	return files.values()


func get_file(id: int) -> File:
	return files[id]


func get_file_path(id: int) -> String:
	return get_file(id).path


func get_file_duration(id: int) -> int:
	return get_file(id).duration


func get_file_data(id: int) -> FileData:
	if data.has(id): return data[id]
	return data[id]


func add_folder(folder: String) -> void:
	if Project.data.folders.has(folder):
		print("FileHandler: Folder %s already exists!")
		return

	InputManager.undo_redo.create_action("Create folder")

	InputManager.undo_redo.add_do_method(_add_folder.bind(folder))
	InputManager.undo_redo.add_undo_method(_delete_folder.bind(folder))

	InputManager.undo_redo.commit_action()


func delete_folder(folder: String) -> void:
	InputManager.undo_redo.create_action("Delete folder")
	var files_to_delete: Array[File] = []

	for file: File in get_file_objects():
		if file.folder.begins_with(folder):
			files_to_delete.append(file)
	
	if !files_to_delete.is_empty():
		for file: File in files_to_delete:
			InputManager.undo_redo.add_do_method(_delete_file.bind(file.id))
			InputManager.undo_redo.add_undo_method(add_file_object.bind(file))
	
	InputManager.undo_redo.add_do_method(_delete_folder.bind(folder))
	InputManager.undo_redo.add_undo_method(_add_folder.bind(folder))

	InputManager.undo_redo.commit_action()


func rename_folder(old_folder: String, new_folder: String) -> void:
	if old_folder == "/" or Project.data.folders.has(new_folder): return

	InputManager.undo_redo.create_action("Rename folder")

	InputManager.undo_redo.add_do_method(_rename_folder.bind(old_folder, new_folder))
	InputManager.undo_redo.add_undo_method(_rename_folder.bind(new_folder, old_folder))

	InputManager.undo_redo.commit_action()


func _add_folder(folder: String) -> void:
	Project.data.folders.append(folder)
	folder_added.emit(folder)
	Project.unsaved_changes = true


func _delete_folder(folder: String) -> void:
	if Project.data.folders.has(folder):
		Project.data.folders.remove_at(Project.data.folders.find(folder))
		folder_deleted.emit(folder)

	Project.unsaved_changes = true


func _rename_folder(old_folder: String, new_folder: String) -> void:
	var changed_paths: Dictionary[String, String] = {}
	var length: int = old_folder.length()
	var keys: PackedStringArray

	# First changing all folder paths
	for index: int in Project.data.folders.size():
		if Project.data.folders[index].begins_with(old_folder):
			var new_path: String = new_folder + Project.data.folders[index].substr(length)

			changed_paths[Project.data.folders[index]] = new_path
			Project.data.folders[index] = new_path

	# Next up we need to update all file paths
	keys = changed_paths.keys()

	for file_id: int in FileHandler.get_file_ids():
		if files[file_id].folder in keys:
			files[file_id].folder = changed_paths[files[file_id].folder]

	folder_renamed.emit(old_folder, new_folder)
	Project.unsaved_changes = true


func enable_clip_only_video(file_id: int, clip_id: int) -> void:
	var file: File = get_file(file_id)
	var file_data: FileData = get_file_data(file_id)
	var video: GoZenVideo = GoZenVideo.new()

	if video.open(file.path):
		printerr("FileHandler: Loading video at path '%s' failed!" % file.path)
		return

	file.clip_only_video_ids.append(clip_id)
	file_data.clip_only_video[clip_id] = video


func disable_clip_only_video(file_id: int, clip_id: int) -> void:
	var file_data: FileData = FileHandler.get_file_data(file_id)

	if file_data.clip_only_video_ids.has(clip_id):
		file_data.clip_only_video_ids.remove_at(file_data.clip_only_video_ids.find(clip_id))
	if file_data.clip_only_video.has(clip_id):
		file_data.clip_only_video.erase(clip_id)


func duplicate_text_file(original_file_id: int) -> void:
	var original_file: File = get_file(original_file_id)
	if original_file.type != TYPE.TEXT: return

	var new_file: File = create_file("temp://text")

	new_file.temp_file = TempFile.new()
	new_file.temp_file.text_data = original_file.temp_file.text_data
	new_file.temp_file.font = original_file.temp_file.font
	new_file.temp_file.font_size = original_file.temp_file.font_size
	new_file.duration = original_file.duration
	add_file_object(new_file)



#--- Private functions ---
func _check_if_file_modified(file: File) -> bool:
	if file.path.begins_with("temp://"): return false # Temp files can't change.
	elif !FileAccess.file_exists(file.path):
		print("FileHandler: File %s at %s doesn't exist anymore!" % [file.id, file.path])
		_delete_file(file.id)
		return false # File doesn't exist anymore, removing file.

	return true


func _on_file_too_big(id: int) -> void:
	var dialog: AcceptDialog = AcceptDialog.new()
	var file_path: String = get_file_path(id)

	dialog.title = "title_dialog_file_too_big"
	dialog.dialog_text = file_path
	add_child(dialog)
	dialog.popup_centered()

	files.erase(id)
	data.erase(id)



#-- Classes ---
class FileDrop:
	var id: int = -1
	var path: String = ""
	var status: STATUS = STATUS.LOADING


	func _init(_path: String) -> void:
		path = _path
