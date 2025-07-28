extends Node


signal file_added(id: int)
signal file_deleted(id: int)
signal file_nickname_changed(id: int)
signal file_path_updated(id: int)

signal error_file_too_big(id: int)

signal _markers_updated # Used for chapters


const EXTENSION: String = ".gozen"
const RECENT_PROJECTS_FILE: String = "user://recent_projects"


var data: ProjectData
var file_data: Dictionary [int, FileData] = {}

var auto_save_timer: Timer
var unsaved_changes: bool = false
var editor_closing: bool = false # This is needed for tasks running in threads.


func _ready() -> void:
	Toolbox.connect_func(get_window().files_dropped, _on_files_dropped)
	Toolbox.connect_func(get_window().close_requested, _on_close_requested)
	Toolbox.connect_func(error_file_too_big, _on_file_too_big)


func _on_actual_close() -> void:
	# Cleaning up is necessary to not have leaked memory and to not have
	# a very slow shutdown of GoZen.
	data.queue_free()
	auto_save_timer.queue_free()

	for file_data_object: FileData in file_data.values():
		file_data_object.queue_free()
	file_data.clear()

	editor_closing = true
	get_tree().root.propagate_call("_on_closing_editor")
	get_tree().quit()


func _auto_save() -> void:
	if auto_save_timer == null:
		auto_save_timer = Timer.new()
		add_child(auto_save_timer)
		Toolbox.connect_func(auto_save_timer.timeout, _auto_save)

	if data != null:
		save()
	auto_save_timer.start(5*60) # Default time is every 5 minutes


func _update_recent_projects(new_path: String) -> void:
	var content: String = ""
	var file: FileAccess

	if FileAccess.file_exists(RECENT_PROJECTS_FILE):
		file = FileAccess.open(RECENT_PROJECTS_FILE, FileAccess.READ)
		content = file.get_as_text()
		file.close()
		
	file = FileAccess.open(RECENT_PROJECTS_FILE, FileAccess.WRITE)
	if !file.store_string(new_path + "\n" + content):
		printerr("Error storing String for recent_projects!")


func _open_project(file_path: String) -> void:
	if OS.execute(OS.get_executable_path(), [file_path]) != OK:
		printerr("ProjectManager: Something went wrong opening project from file dialog!")


func _save_as(new_project_path: String) -> void:
	set_project_path(new_project_path)
	save()


func _modified_files_check() -> void:
	# Check to see if a file needs reloading or not.
	if Project.data == null:
		return

	for file: File in Project.get_files().values():
		# Temp files can't change.
		if file.path.begins_with("temp://"):
			continue

		# File doesn't exist anymore, removing file.
		if !FileAccess.file_exists(file.path):
			print("File %s at %s doesn't exist anymore!" % [file.id, file.path])
			delete_file(file.id)
			continue

		# Check if an actual file, maybe wasn't updated yet.
		if file.modified_time == -1: 
			file.modified_time = FileAccess.get_modified_time(file.path)

		var new_modified_time: int = FileAccess.get_modified_time(file.path)
		if file.modified_time != new_modified_time:
			file.modified_time = new_modified_time
			Project.reload_file_data(file.id)


func _save_image_to_file(path: String, file: File) -> void:
	# We save the image, and replace the path to the new file
	var extension: String = path.get_extension().to_lower()

	if extension == "png" and file.temp_file.image_data.get_image().save_png(path):
		printerr("Couldn't save image to png!\n", get_stack())
		return
	elif extension == "webp" and file.temp_file.image_data.get_image().save_webp(path, false, 1.0):
		printerr("Couldn't save image to webp!\n", get_stack())
		return
	elif file.temp_file.image_data.get_image().save_jpg(path, 1.0):
		printerr("Couldn't save image to jpg!\n", get_stack())
		return

	file.path = path
	file.temp_file.free()
	file.temp_file = null

	if !load_file_data(file.id):
		printerr("Something went wrong loading file '%s' after saving temp image to real image!" % path)

	file_path_updated.emit(file.id)


func _save_audio_to_wav(path: String, file: File) -> void:
	if get_file_data(file.id).audio.save_to_wav(path):
		printerr("Error occured when saving to WAV!")


func new_project(path: String, res: Vector2i, framerate: float) -> void:
	var new_project_overlay: ProgressOverlay = preload(Library.SCENE_PROGRESS_OVERLAY).instantiate()
	data = ProjectData.new()
	file_data = {}

	get_tree().root.add_child(new_project_overlay)
	new_project_overlay.update_title("title_new_project")
	new_project_overlay.update_progress(0, "status_new_project_init")

	set_project_path(path)
	set_resolution(res)
	set_framerate(framerate)
	for i: int in Settings.get_tracks_amount():
		data.tracks.append({})
	if EditorCore.loaded_clips.resize(get_track_count()):
		Toolbox.print_resize_error()

	new_project_overlay.update_progress(50, "status_project_playback_setup")
	EditorCore._setup_playback()
	EditorCore._setup_audio_players()
	EditorCore.set_frame(data.playhead_position)

	new_project_overlay.update_progress(98, "status_project_finalizing")

	get_tree().root.propagate_call("_on_project_ready")
	_update_recent_projects(path)
	save()
	new_project_overlay.update_progress_bar(99)
	get_window().title = "GoZen - %s" % path.get_file().get_basename()
	new_project_overlay.queue_free()

	_auto_save()


func save() -> void:
	if data.save_data(data.project_path):
		printerr("Something went wrong whilst saving project! ", data.error)
	else:
		unsaved_changes = false


func save_as() -> void:
	var dialog: FileDialog = Toolbox.get_file_dialog(
			tr("Save project as ..."),
			FileDialog.FILE_MODE_SAVE_FILE,
			["*%s;GoZen project files" % EXTENSION])

	Toolbox.connect_func(dialog.file_selected, _save_as)
	add_child(dialog)
	dialog.popup_centered()

	
func open(project_path: String) -> void:
	var loading_overlay: ProgressOverlay = preload(Library.SCENE_PROGRESS_OVERLAY).instantiate()
	
	get_tree().root.add_child(loading_overlay)
	loading_overlay.update_title("title_loading_project")
	loading_overlay.update_progress(0, "status_project_loading_init")

	data = ProjectData.new()
	file_data = {}

	# 1% = Loading has started.
	loading_overlay.update_progress_bar(1, true)

	if data.load_data(project_path):
		printerr("Something went wrong whilst loading project!", data.error)

	# 5% = Loading has started
	loading_overlay.update_progress(5, "status_project_preparing_timeline")

	set_project_path(project_path)
	set_framerate(data.framerate)
	if EditorCore.loaded_clips.resize(get_track_count()):
		Toolbox.print_resize_error()

	# 7% = Timeline ready to accept clips.
	loading_overlay.update_progress(7, "status_project_loading_files")

	var progress_increment: float = (1 / float(get_file_ids().size())) * 73
	for i: int in get_file_ids():
		if !load_file_data(i):
			continue # File became invaled so entry got deleted.

		var type: File.TYPE = data.files[i].type

		if type == File.TYPE.VIDEO and file_data[i].video == null:
			await file_data[i].video_loaded
		loading_overlay.increment_progress_bar(progress_increment)

	# 80% = Files loaded, setting up playback.
	loading_overlay.update_progress(80, "status_project_playback_setup")
	EditorCore._setup_playback()
	EditorCore._setup_audio_players()
	EditorCore.set_frame(data.playhead_position)

	# 99% = Finalizing.
	loading_overlay.update_progress(99, "status_project_finalizing")
	_update_recent_projects(project_path)
	get_tree().root.propagate_call("_on_project_ready")

	loading_overlay.update_progress_bar(100)
	get_window().title = "GoZen - %s" % project_path.get_file().get_basename()
	loading_overlay.queue_free()

	_auto_save()


func open_project() -> void:
	var dialog: FileDialog = Toolbox.get_file_dialog(
			tr("Open project"),
			FileDialog.FILE_MODE_OPEN_FILE,
			["*%s;GoZen project files" % EXTENSION])

	Toolbox.connect_func(dialog.file_selected, _open_project)
	add_child(dialog)
	dialog.popup_centered()


func open_settings_menu() -> void:
	var settings_panel: SettingsPanel = preload(Library.SCENE_SETTINGS).instantiate()

	settings_panel.set_mode_project_settings()
	EditorUI.instance.add_child(settings_panel)


func load_file_data(id: int) -> bool:
	var temp_file_data: FileData = FileData.new()

	if !temp_file_data.init_data(id):
		delete_file(id)
		return false
		
	file_data[id] = temp_file_data
	return true


func reload_file_data(id: int) -> void:
	file_data[id].queue_free()
	await RenderingServer.frame_pre_draw
	if !load_file_data(id):
		delete_file(id)
		print("File became invalid!")


func add_file(file_path: String) -> int:
	# Check if file already exists inside of the project.
	for existing: File in get_files().values():
		if existing.path == file_path:
			print("File already loaded with path '%s'!" % file_path)
			return -2

	var file: File = File.create(file_path)

	if file == null:
		return -1

	set_file(file.id, file)
	if !load_file_data(file.id):
		printerr("Problem happened adding file!")
		return -1

	unsaved_changes = true
	return file.id


func add_file_object(file: File) -> void:
	# Used for adding temp files.
	set_file(file.id, file)

	if !load_file_data(file.id):
		print("Something went wrong loading file '", file.path, "'!")

	# We only emit this one since for dropped/selected actual files this gets
	# called inside of _on_files_dropped.
	file_added.emit(file.id)
	unsaved_changes = true


func _add_clip(clip_data: ClipData) -> void:
	# Used for undoing the deletion of a file.
	data.clips[clip_data.clip_id] = clip_data
	unsaved_changes = true

	
func delete_file(id: int) -> void:
	for clip: ClipData in data.clips.values():
		if clip.file_id == id:
			Timeline.instance.delete_clip(clip)

	if file_data.has(id):
		if !file_data.erase(id):
			Toolbox.print_erase_error()
	if data.files.has(id):
		if !data.files.erase(id):
			Toolbox.print_erase_error()

	await RenderingServer.frame_pre_draw
	file_deleted.emit(id)
	unsaved_changes = true


func _on_files_dropped(files: PackedStringArray) -> void:
	# Only allow files to be dropped in non-empty projects.
	if data == null:
		return

	var dropped_overlay: ProgressOverlay = preload(Library.SCENE_PROGRESS_OVERLAY).instantiate()
	var file_status: Dictionary = {}
	var file_ids: Dictionary = {}
	var still_loading: PackedInt64Array = []
	var progress_increment: float = 0.0

	for file_path: String in Toolbox.find_subfolder_files(files):
		file_status[file_path] = 0
	for file_path: String in files:
		if FileAccess.file_exists(file_path):
			file_status[file_path] = 0

	progress_increment = (1 / float(file_status.keys().size())) * 50

	get_tree().root.add_child(dropped_overlay)
	dropped_overlay.update_title("title_files_dropped")
	dropped_overlay.update_progress(0, "")
	dropped_overlay.update_files(file_status)
	await RenderingServer.frame_post_draw

	for file_path: String in file_status.keys():
		var id: int = add_file(file_path)
		file_ids[id] = file_path
		dropped_overlay.increment_progress_bar(progress_increment)
		await RenderingServer.frame_post_draw

		if id in [-2, -1]: # -2 = Already loaded, -1 = Problem loading.
			file_status[file_path] = id
			dropped_overlay.update_files(file_status)
			dropped_overlay.increment_progress_bar(progress_increment)
			continue

		if get_file_data(id) == null or get_file(id).type == File.TYPE.VIDEO:
			if still_loading.append(id):
				Toolbox.print_append_error()
		else:
			file_status[file_path] = 1
			dropped_overlay.update_files(file_status)
			dropped_overlay.increment_progress_bar(progress_increment)
			file_added.emit(id)

	while still_loading.size() != 0:
		for id: int in still_loading:
			if !has_file(id):
				# Error, file was most likely too big.
				file_status[file_ids[id]] = -3 # Too big error code.
				dropped_overlay.update_files(file_status)
				dropped_overlay.increment_progress_bar(progress_increment)
				still_loading.remove_at(still_loading.find(id))
			elif get_file(id).type != File.TYPE.VIDEO:
				printerr("This should not happen! File is type: ", get_file(id).type)
				dropped_overlay.increment_progress_bar(progress_increment)
				still_loading.remove_at(still_loading.find(id))
			elif get_file_data(id).video != null and get_file_data(id).video.is_open():
				file_status[get_file(id).path] = 1
				dropped_overlay.update_files(file_status)
				dropped_overlay.increment_progress_bar(progress_increment)
				file_added.emit(id)
				still_loading.remove_at(still_loading.find(id))

		await RenderingServer.frame_post_draw

	dropped_overlay.queue_free()


func _on_file_too_big(file_id: int) -> void:
	# TODO: Show popup.
	var dialog: AcceptDialog = AcceptDialog.new()
	var file_path: String = data.files[file_id].path

	dialog.title = tr("title_dialog_file_too_big")
	dialog.dialog_text = file_path
	add_child(dialog)
	dialog.popup_centered()

	if !data.files.erase(file_id):
		Toolbox.print_erase_error()
	if !file_data.erase(file_id):
		Toolbox.print_erase_error()


func _on_close_requested() -> void:
	if data != null and unsaved_changes:
		var popup: AcceptDialog = AcceptDialog.new()
		var dont_save_button: Button = popup.add_button(tr("button_dont_save"))
		var cancel_button: Button = popup.add_cancel_button(tr("button_cancel"))

		auto_save_timer.paused = true
		popup.title = tr("title_close_without_saving")
		popup.ok_button_text = tr("button_save")

		Toolbox.connect_func(popup.confirmed, _on_save_close)
		Toolbox.connect_func(cancel_button.pressed, _on_cancel_close)
		Toolbox.connect_func(dont_save_button.pressed, _on_actual_close)

		get_tree().root.add_child(popup)
		popup.popup_centered()
	else:
		editor_closing = true
		get_tree().root.propagate_call("_on_closing_editor")
		await RenderingServer.frame_post_draw
		get_tree().quit()


func _on_save_close() -> void:
	save()
	_on_actual_close()


func _on_cancel_close() -> void:
	if Settings.get_auto_save():
		auto_save_timer.start()



# Setters and Getters  --------------------------------------------------------
func set_project_path(project_path: String) -> void:
	data.project_path = project_path
	unsaved_changes = true


func get_project_path() -> String:
	return data.project_path


func get_project_name() -> String:
	var p_path: String = data.project_path.get_file()
	return p_path.trim_suffix("." + p_path.get_extension())


func get_project_base_folder() -> String:
	return data.project_path.get_base_dir()

 
func set_file(file_id: int, file: File) -> void:
	data.files[file_id] = file
	unsaved_changes = true


func set_file_nickname(file_id: int, nickname: String) -> void:
	data.files[file_id].nickname = nickname
	file_nickname_changed.emit(file_id)
	unsaved_changes = true


func has_file(file_id: int) -> bool:
	return data.files.has(file_id)


func get_files() -> Dictionary[int, File]:
	return data.files


func get_file_ids() -> PackedInt64Array:
	return data.files.keys()


func get_file(id: int) -> File:
	return data.files[id]
	

func get_file_data(id: int) -> FileData:
	return file_data[id]


func set_resolution(res: Vector2i) -> void:
	data.resolution = res
	unsaved_changes = true


func get_resolution() -> Vector2i:
	return data.resolution


func set_framerate(framerate: float) -> void:
	data.framerate = framerate
	EditorCore.frame_time = 1.0 / data.framerate
	unsaved_changes = true


func get_framerate() -> float:
	return data.framerate


func get_timeline_end() -> int:
	return data.timeline_end


func set_timeline_end(value: int) -> void:
	data.timeline_end = value
	unsaved_changes = true


func update_timeline_end() -> void:
	var new_end: int = 0

	for track: Dictionary[int, int] in Project.get_tracks():
		if track.size() == 0:
			continue

		var clip: ClipData = Project.get_clip(track[track.keys().max()])
		var value: int = clip.get_end_frame()

		if new_end < value:
			new_end = value
	
	set_timeline_end(new_end)
	get_tree().root.propagate_call("_on_timeline_end_update", [new_end])


func set_track_data(track_id: int, key: int, value: int) -> void:
	data.tracks[track_id][key] = value
	unsaved_changes = true


func erase_track_entry(track_id: int, key: int) -> void:
	if !data.tracks[track_id].erase(key):
		printerr("Could not erase ", key, " from track ", track_id, "!")
	else:
		unsaved_changes = true
	

func get_track_count() -> int:
	return data.tracks.size()


func get_track_keys(track_id: int) -> PackedInt64Array:
	var keys: PackedInt64Array = data.tracks[track_id].keys()
	keys.sort()
	return keys


func get_track_values(track_id: int) -> PackedInt64Array:
	return data.tracks[track_id].values()


func get_tracks() -> Array[Dictionary]:
	return data.tracks


func get_track_data(track_id: int) -> Dictionary[int, int]:
	var track_data: Dictionary[int, int] = {}
	var keys: PackedInt64Array = get_track_keys(track_id)

	for key: int in keys:
		track_data[key] = data.tracks[track_id][key]
		
	return track_data


func get_clips() -> Dictionary[int, ClipData]:
	return data.clips


func get_clip_datas() -> Array[ClipData]:
	return data.clips.values()


func get_clip_ids() -> PackedInt64Array:
	return data.clips.keys()


func get_clip(clip_id: int) -> ClipData:
	return data.clips[clip_id]


func get_clip_type(clip_id: int) -> File.TYPE:
	return data.files[data.clips[clip_id].file_id].type


func set_clip(id: int, clip: ClipData) -> void:
	clip.clip_id = id
	data.clips[id] = clip
	unsaved_changes = true


func erase_clip(clip_id: int) -> void:
	if !data.tracks[data.clips[clip_id].track_id].erase(data.clips[clip_id].start_frame):
		Toolbox.print_erase_error()
	elif !data.clips.erase(clip_id):
		Toolbox.print_erase_error()
	else:
		unsaved_changes = true

	get_tree().root.propagate_call("_on_clip_erased", [clip_id])


func set_background_color(color: Color) -> void:
	data.background_color = color
	EditorCore.set_background_color(color)
	unsaved_changes = true


func get_background_color() -> Color:
	return data.background_color


func set_timeline_scroll_h(value: int) -> void:
	data.timeline_scroll_h = value
	unsaved_changes = true


func get_timeline_scroll_h() -> int:
	return data.timeline_scroll_h


func set_zoom(value: float) -> void:
	data.zoom = value


func get_zoom() -> float:
	return data.zoom


func add_folder(folder: String) -> void:
	if data.folders.has(folder):
		print("Folder %s already exists!")
	elif data.folders.append(folder):
		Toolbox.print_append_error()
	else:
		unsaved_changes = true


func get_folders() -> PackedStringArray:
	return data.folders


func add_marker(frame_nr: int, marker: String) -> void:
	if data.markers.has(frame_nr):
		printerr("Already marker in postition %s!" % frame_nr)
	else:
		data.markers[frame_nr] = marker
		_markers_updated.emit()
		unsaved_changes = true


func remove_marker(frame_nr: int) -> void:
	if !data.markers.has(frame_nr):
		printerr("No marker at %s!" % frame_nr)
	elif !data.markers.erase(frame_nr):
		Toolbox.print_erase_error()
	else:
		_markers_updated.emit()
		unsaved_changes = true


func get_marker(frame_nr: int) -> String:
	return data.markers[frame_nr]


func get_marker_positions() -> PackedInt64Array:
	var markers: PackedInt64Array = data.markers.keys()
	markers.sort()
	return markers


func get_markers() -> Dictionary[int, String]:
	return data.markers

