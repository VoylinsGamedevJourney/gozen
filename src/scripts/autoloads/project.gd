extends Node


signal project_ready

signal folder_added(folder_name: String)

signal timeline_end_update(new_end: int)

signal clip_deleted(clip_id: int)

signal marker_added(frame_nr: int)
signal marker_updated(old_frame_nr: int, new_frame_nr: int)
signal marker_removed(frame_nr: int)


const EXTENSION: String = ".gozen"
const RECENT_PROJECTS_FILE: String = "user://recent_projects"


# Private variables
var _data: ProjectData = ProjectData.new()
var _auto_save_timer: Timer

# Public variables
var loaded: bool = false
var unsaved_changes: bool = false



func _ready() -> void:
	Utils.connect_func(get_window().close_requested, _on_close_requested)


func new_project(new_path: String, new_resolution: Vector2i, new_framerate: float) -> void:
	var loading_overlay: ProgressOverlay = PopupManager.get_popup(PopupManager.POPUP.PROGRESS)

	loading_overlay.update_title("title_new_project")
	loading_overlay.update_progress(0, "status_new_project_init")

	set_project_path(new_path)
	set_resolution(new_resolution)
	set_framerate(new_framerate)

	# Prepare tracks
	_data.tracks.resize(Settings.get_tracks_amount())
	_data.tracks.fill(TrackData.new())
	EditorCore.loaded_clips.resize(get_track_count())

	loading_overlay.update_progress(50, "status_project_playback_setup")
	EditorCore.setup_playback()
	EditorCore.setup_audio_players()
	EditorCore.set_frame(get_playhead_position())

	loading_overlay.update_progress(99, "status_project_finalizing")
	get_window().title = "GoZen - %s" % new_path.get_file().get_basename()
	_update_recent_projects(new_path)
	PopupManager.close_popups()
	save()

	loaded = true
	_auto_save()
	project_ready.emit()


func save() -> void:
	if DataManager.save_data(get_project_path(), _data):
		printerr("Something went wrong whilst saving project! ", FileAccess.get_open_error())
	else:
		unsaved_changes = false


func save_as() -> void:
	var dialog: FileDialog = PopupManager.create_file_dialog(
			"file_dialog_title_save_project_as",
			FileDialog.FILE_MODE_SAVE_FILE,
			["*%s;%s" % [EXTENSION, tr("file_dialog_tooltip_gozen_project_files")]])

	Utils.connect_func(dialog.file_selected, _save_as)
	add_child(dialog)
	dialog.popup_centered()

	
func open(new_project_path: String) -> void:
	var loading_overlay: ProgressOverlay = preload(Library.SCENE_PROGRESS_OVERLAY).instantiate()
	
	get_tree().root.add_child(loading_overlay)
	loading_overlay.update_title("title_loading_project")
	loading_overlay.update_progress(0, "status_project_loading_init")
	loading_overlay.update_progress_bar(1, true)

	if DataManager.load_data(new_project_path, _data):
		printerr("Something went wrong whilst loading project! ", FileAccess.get_open_error())

	loading_overlay.update_progress(5, "status_project_preparing_timeline")

	set_project_path(new_project_path)
	set_framerate(_data.framerate)
	EditorCore.loaded_clips.resize(get_track_count())

	# 7% = Timeline ready to accept clips.
	loading_overlay.update_progress(7, "status_project_loading_files")

	var progress_increment: float = (1 / float(FileManager.get_file_ids().size())) * 73
	for i: int in FileManager.get_file_ids():
		if !FileManager.load_file_data(i):
			continue # File became invaled so entry got deleted.

		var type: File.TYPE = _data.files[i].type

		if type == File.TYPE.VIDEO and FileManager.data[i].video == null:
			await FileManager.data[i].video_loaded
		loading_overlay.increment_progress_bar(progress_increment)

	# 80% = Files loaded, setting up playback.
	loading_overlay.update_progress(80, "status_project_playback_setup")
	EditorCore.setup_playback()
	EditorCore.setup_audio_players()
	EditorCore.set_frame(get_playhead_position())

	# 99% = Finalizing.
	loading_overlay.update_progress(99, "status_project_finalizing")
	_update_recent_projects(get_project_path())

	loading_overlay.update_progress_bar(100)
	get_window().title = "GoZen - %s" % get_project_path().get_file().get_basename()
	loading_overlay.queue_free()

	loaded = true
	unsaved_changes = false
	project_ready.emit()
	_auto_save()


func open_project() -> void:
	var dialog: FileDialog = PopupManager.create_file_dialog(
			"file_dialog_title_open_project", FileDialog.FILE_MODE_OPEN_FILE,
			["*%s;%s" % [EXTENSION, tr("file_dialog_tooltip_gozen_project_files")]])

	Utils.connect_func(dialog.file_selected, _open_project)
	add_child(dialog)
	dialog.popup_centered()


func open_settings_menu() -> void:
	PopupManager.open_popup(PopupManager.POPUP.PROJECT_SETTINGS)


func _auto_save() -> void:
	if _auto_save_timer == null:
		_auto_save_timer = Timer.new()
		add_child(_auto_save_timer)
		Utils.connect_func(_auto_save_timer.timeout, _auto_save)

	if loaded:
		save()

	_auto_save_timer.start(5*60) # Default time is every 5 minutes


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
	if !unsaved_changes:
		get_tree().quit()
		return

	var popup: AcceptDialog = AcceptDialog.new()
	var dont_save_button: Button = popup.add_button("button_dont_save")
	var cancel_button: Button = popup.add_cancel_button("button_cancel")

	_auto_save_timer.paused = true
	popup.title = "title_close_without_saving"
	popup.ok_button_text = "button_save"

	Utils.connect_func(popup.confirmed, _on_save_close)
	Utils.connect_func(cancel_button.pressed, _on_cancel_close)
	Utils.connect_func(dont_save_button.pressed, get_tree().quit)

	get_tree().root.add_child(popup)
	popup.popup_centered()


func _on_save_close() -> void:
	save()
	get_tree().quit()


func _on_cancel_close() -> void:
	if Settings.get_auto_save(): _auto_save_timer.start()


#--- Project setters & getters ---
func set_project_path(new_project_path: String) -> void:
	_data.project_path = new_project_path
	unsaved_changes = true


func get_project_path() -> String:
	return _data.project_path


func get_project_name() -> String:
	var p_path: String = get_project_path().get_file()

	return p_path.trim_suffix("." + p_path.get_extension())


func get_project_base_folder() -> String:
	return get_project_path().get_base_dir()


func set_resolution(res: Vector2i) -> void:
	_data.resolution = res
	unsaved_changes = true


func get_resolution() -> Vector2i:
	return _data.resolution


func set_framerate(new_framerate: float) -> void:
	_data.framerate = new_framerate
	EditorCore.frame_time = 1.0 / get_framerate()
	unsaved_changes = true


func get_framerate() -> float:
	return _data.framerate


func set_playhead_position(new_pos: int) -> void:
	# No need to set "unsaved_changes" here.
	_data.playhead_position = new_pos


func get_playhead_position() -> int:
	return _data.playhead_position


func get_timeline_end() -> int:
	return _data.timeline_end


func set_timeline_end(value: int) -> void:
	_data.timeline_end = value
	unsaved_changes = true


func update_timeline_end() -> void:
	var end: int = 0

	for track: TrackData in get_tracks():
		if track.get_size() == 0:
			continue

		end = max(end, ClipHandler.get_end_frame(track.get_last_clip_id()))
	
	set_timeline_end(end)
	timeline_end_update.emit(end)


func add_track() -> void:
	_data.tracks.append([])
	unsaved_changes = true


func get_track_count() -> int:
	return _data.tracks.size()


func get_tracks() -> Array[TrackData]:
	return _data.tracks


func get_track(track_id: int) -> TrackData:
	return _data.tracks[track_id]


func get_clips() -> Dictionary[int, ClipData]:
	return _data.clips


func get_clip_datas() -> Array[ClipData]:
	return get_clips().values()


func get_clip_ids() -> PackedInt64Array:
	return get_clips().keys()


func get_clip(id: int) -> ClipData:
	return get_clips()[id]


func get_clip_type(id: int) -> File.TYPE:
	return get_files()[get_clips()[id].file_id].type


func set_clip(id: int, clip: ClipData) -> void:
	clip.id = id
	_data.clips[id] = clip
	unsaved_changes = true


func add_clip(clip_data: ClipData) -> void:
	# Used for undoing the deletion of a file.
	_data.clips[clip_data.id] = clip_data
	unsaved_changes = true


func delete_clip(id: int) -> void:
	_data.tracks[_data.clips[id].track_id].erase(_data.clips[id].start_frame)
	_data.clips.erase(id)
	clip_deleted.emit(id)
	unsaved_changes = true


func get_files() -> Dictionary[int, File]:
	return _data.files


func set_background_color(color: Color) -> void:
	_data.background_color = color
	EditorCore.set_background_color(color)
	unsaved_changes = true


func get_background_color() -> Color:
	return _data.background_color


func add_folder(folder: String) -> void:
	if _data.folders.has(folder):
		print("Folder %s already exists!")
		return

	_data.folders.append(folder)
	folder_added.emit(folder)
	unsaved_changes = true


func get_folders() -> PackedStringArray:
	return _data.folders


func add_marker(frame_nr: int, marker: MarkerData) -> void:
	if _data.markers.has(frame_nr):
		update_marker(frame_nr, frame_nr, marker)
		return

	_data.markers[frame_nr] = marker
	marker_added.emit(frame_nr)
	unsaved_changes = true


func update_marker(old_frame_nr: int, new_frame_nr: int, marker: MarkerData) -> void:
	_data.markers[new_frame_nr] = marker
	_data.markers.erase(old_frame_nr)

	marker_updated.emit(old_frame_nr, new_frame_nr)
	unsaved_changes = true


func remove_marker(frame_nr: int) -> void:
	if !_data.markers.has(frame_nr):
		printerr("No marker at %s!" % frame_nr)
		return

	_data.markers.erase(frame_nr)
	marker_removed.emit(frame_nr)
	unsaved_changes = true


func get_marker(frame_nr: int) -> MarkerData:
	return _data.markers[frame_nr]


func get_marker_positions() -> PackedInt64Array:
	var project_markers: PackedInt64Array = _data.markers.keys()

	project_markers.sort()
	return project_markers


func get_markers() -> Dictionary[int, MarkerData]:
	return _data.markers

