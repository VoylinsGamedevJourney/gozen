extends Node


signal _markers_updated # Used for chapters


const EXTENSION: String = ".gozen"
const RECENT_PROJECTS_FILE: String = "user://recent_projects"


var data: ProjectData

var auto_save_timer: Timer
var unsaved_changes: bool = false
var editor_closing: bool = false # This is needed for tasks running in threads.



#--- Project Manager functions ---
func _ready() -> void:
	Toolbox.connect_func(get_window().close_requested, _on_close_requested)


func new_project(path: String, res: Vector2i, framerate: float) -> void:
	var new_project_overlay: ProgressOverlay = PopupManager.get_popup(PopupManager.POPUP.PROGRESS)

	data = ProjectData.new()
	FileManager.reset_data()

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
	PopupManager.close_popups()

	_auto_save()


func save() -> void:
	if data.save_data(data.project_path):
		printerr("Something went wrong whilst saving project! ", data.error)
	else:
		unsaved_changes = false


func save_as() -> void:
	var dialog: FileDialog = Toolbox.get_file_dialog(
			"Save project as ...", # TODO: Localize
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
	FileManager.reset_data()

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

	var progress_increment: float = (1 / float(FileManager.get_file_ids().size())) * 73
	for i: int in FileManager.get_file_ids():
		if !FileManager.load_file_data(i):
			continue # File became invaled so entry got deleted.

		var type: File.TYPE = data.files[i].type

		if type == File.TYPE.VIDEO and FileManager.data[i].video == null:
			await FileManager.data[i].video_loaded
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
			"Open project", # TODO: Localize
			FileDialog.FILE_MODE_OPEN_FILE,
			["*%s;GoZen project files" % EXTENSION])

	Toolbox.connect_func(dialog.file_selected, _open_project)
	add_child(dialog)
	dialog.popup_centered()


func open_settings_menu() -> void:
	PopupManager.show_popup(PopupManager.POPUP.PROJECT_SETTINGS)


func _add_clip(clip_data: ClipData) -> void:
	# Used for undoing the deletion of a file.
	data.clips[clip_data.clip_id] = clip_data
	unsaved_changes = true


func _on_actual_close() -> void:
	# Cleaning up is necessary to not have leaked memory and to not have
	# a very slow shutdown of GoZen.
	data.queue_free()
	auto_save_timer.queue_free()

	for file_data_object: FileData in FileManager.data.values():
		file_data_object.queue_free()
	FileManager.reset_data()

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



func _on_close_requested() -> void:
	if data != null and unsaved_changes:
		var popup: AcceptDialog = AcceptDialog.new()
		var dont_save_button: Button = popup.add_button("button_dont_save")
		var cancel_button: Button = popup.add_cancel_button("button_cancel")

		auto_save_timer.paused = true
		popup.title = "title_close_without_saving"
		popup.ok_button_text = "button_save"

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



#--- Project setters & getters ---
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


func add_marker(frame_nr: int, marker: MarkerData) -> void:
	if data.markers.has(frame_nr):
		update_marker(frame_nr, frame_nr, marker)
	else:
		data.markers[frame_nr] = marker
		_markers_updated.emit()
		unsaved_changes = true
		propagate_call("_on_marker_added", [frame_nr, marker])


func update_marker(old_frame_nr: int, new_frame_nr: int, marker: MarkerData) -> void:
	data.markers[new_frame_nr] = marker
	if !data.markers.erase(old_frame_nr):
		Toolbox.print_erase_error()

	_markers_updated.emit()
	unsaved_changes = true
	propagate_call("_on_marker_updated", [old_frame_nr, new_frame_nr, marker])


func remove_marker(frame_nr: int) -> void:
	if !data.markers.has(frame_nr):
		printerr("No marker at %s!" % frame_nr)
	elif !data.markers.erase(frame_nr):
		Toolbox.print_erase_error()
	else:
		_markers_updated.emit()
		unsaved_changes = true
		propagate_call("_on_marker_removed", [frame_nr])


func get_marker(frame_nr: int) -> MarkerData:
	return data.markers[frame_nr]


func get_marker_positions() -> PackedInt64Array:
	var markers: PackedInt64Array = data.markers.keys()
	markers.sort()
	return markers


func get_markers() -> Dictionary[int, MarkerData]:
	return data.markers

