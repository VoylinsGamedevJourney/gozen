extends Node


signal _markers_updated # Used for chapters


const EXTENSION: String = ".gozen"
const RECENT_PROJECTS_FILE: String = "user://recent_projects"


# Private variables
var _auto_save_timer: Timer
var _unsaved_changes: bool = false
var _editor_closing: bool = false # This is needed for tasks running in threads.
var _defaults: Dictionary[String, Variant] = {}
var _loaded: bool = false


# Project settings
var project_path: String

var files: Dictionary[int, File] = {}
var resolution: Vector2i = Vector2i(1920, 1080)
var framerate: float = 30.0

var playhead_position: int = 0
var timeline_end: int = 0

var tracks: Array[Dictionary] = []  # [{frame_nr: clip_id}]
var clips: Dictionary[int, ClipData] = {}  # {clip_id: ClipData}

var background_color: Color = Color.BLACK

# Tracking current timeline for reloading project.
var timeline_scroll_h: int = 0
var zoom: float = 1.0

var folders: PackedStringArray = []

var markers: Dictionary[int, MarkerData] = {} # { Frame: Marker }



func _ready() -> void:
	Utils.connect_func(get_window().close_requested, _on_close_requested)

	_defaults = DataManager.get_data(self)


func is_loaded() -> bool:
	return _loaded


func reset_to_defaults() -> void:
	for property_name: String in _defaults:
		set(property_name, _defaults[property_name])


func new_project(new_path: String, new_resolution: Vector2i, new_framerate: float) -> void:
	var new_project_overlay: ProgressOverlay = PopupManager.get_popup(PopupManager.POPUP.PROGRESS)

	reset_to_defaults()
	FileManager.reset_data()

	new_project_overlay.update_title("title_new_project")
	new_project_overlay.update_progress(0, "status_new_project_init")

	set_project_path(new_path)
	set_resolution(new_resolution)
	set_framerate(new_framerate)

	for i: int in Settings.get_tracks_amount():
		tracks.append({})
	if EditorCore.loaded_clips.resize(get_track_count()):
		Print.resize_error()

	new_project_overlay.update_progress(50, "status_project_playback_setup")
	EditorCore._setup_playback()
	EditorCore._setup_audio_players()
	EditorCore.set_frame(get_playhead_position())

	new_project_overlay.update_progress(98, "status_project_finalizing")

	get_tree().root.propagate_call("_on_project_ready")
	_update_recent_projects(new_path)
	save()
	new_project_overlay.update_progress_bar(99)
	get_window().title = "GoZen - %s" % new_path.get_file().get_basename()
	PopupManager.close_popups()

	_loaded = true
	_auto_save()
	get_tree().root.propagate_call("_on_project_ready")


func save() -> void:
	var error: int = DataManager.save_data(get_project_path(), self)

	if error:
		printerr("Something went wrong whilst saving project! ", error)
	else:
		_unsaved_changes = false


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

	reset_to_defaults()
	FileManager.reset_data()

	# 1% = Loading has started.
	loading_overlay.update_progress_bar(1, true)

	var error: int = DataManager.load_data(new_project_path, self)

	if error:
		printerr("Something went wrong whilst loading project! ", error)

	project_path = new_project_path

	# 5% = Loading has started
	loading_overlay.update_progress(5, "status_project_preparing_timeline")

	set_project_path(new_project_path)
	set_framerate(framerate)

	if EditorCore.loaded_clips.resize(get_track_count()):
		Print.resize_error()

	# 7% = Timeline ready to accept clips.
	loading_overlay.update_progress(7, "status_project_loading_files")

	var progress_increment: float = (1 / float(FileManager.get_file_ids().size())) * 73
	for i: int in FileManager.get_file_ids():
		if !FileManager.load_file_data(i):
			continue # File became invaled so entry got deleted.

		var type: File.TYPE = files[i].type

		if type == File.TYPE.VIDEO and FileManager.data[i].video == null:
			await FileManager.data[i].video_loaded
		loading_overlay.increment_progress_bar(progress_increment)

	# 80% = Files loaded, setting up playback.
	loading_overlay.update_progress(80, "status_project_playback_setup")
	EditorCore._setup_playback()
	EditorCore._setup_audio_players()
	EditorCore.set_frame(Project.get_playhead_position())

	# 99% = Finalizing.
	loading_overlay.update_progress(99, "status_project_finalizing")
	_update_recent_projects(project_path)
	get_tree().root.propagate_call("_on_project_ready")

	loading_overlay.update_progress_bar(100)
	get_window().title = "GoZen - %s" % project_path.get_file().get_basename()
	loading_overlay.queue_free()

	_loaded = true
	_auto_save()


func open_project() -> void:
	var dialog: FileDialog = PopupManager.create_file_dialog(
			"file_dialog_title_open_project",
			FileDialog.FILE_MODE_OPEN_FILE,
			["*%s;%s" % [EXTENSION, tr("file_dialog_tooltip_gozen_project_files")]])

	Utils.connect_func(dialog.file_selected, _open_project)
	add_child(dialog)
	dialog.popup_centered()


func open_settings_menu() -> void:
	PopupManager.open_popup(PopupManager.POPUP.PROJECT_SETTINGS)


## Returns a Dictionary { Section_name: Dictionary {Settings label, Settings option node} }
func get_settings_menu_options() -> Dictionary[String, Array]:
	var data: Dictionary[String, Array] = {}
	
	data["title_appearance"] = [
		SettingsOption.create_label("setting_background_color"),
		SettingsOption.create_color_picker(
				Project.get_background_color(),
				Project.set_background_color,
				"tooltip_setting_background_color"),
	]

	return data


func _on_actual_close() -> void:
	# Cleaning up is necessary to not have leaked memory and to not have
	# a very slow shutdown of GoZen.
	_auto_save_timer.queue_free()

	for file_data_object: FileData in FileManager.data.values():
		file_data_object.queue_free()
	FileManager.reset_data()

	_editor_closing = true
	get_tree().root.propagate_call("_on_closing_editor")
	get_tree().quit()


func _auto_save() -> void:
	if _auto_save_timer == null:
		_auto_save_timer = Timer.new()
		add_child(_auto_save_timer)
		Utils.connect_func(_auto_save_timer.timeout, _auto_save)

	if _loaded:
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
	if _unsaved_changes:
		var popup: AcceptDialog = AcceptDialog.new()
		var dont_save_button: Button = popup.add_button("button_dont_save")
		var cancel_button: Button = popup.add_cancel_button("button_cancel")

		_auto_save_timer.paused = true
		popup.title = "title_close_without_saving"
		popup.ok_button_text = "button_save"

		Utils.connect_func(popup.confirmed, _on_save_close)
		Utils.connect_func(cancel_button.pressed, _on_cancel_close)
		Utils.connect_func(dont_save_button.pressed, _on_actual_close)

		get_tree().root.add_child(popup)
		popup.popup_centered()
	else:
		_editor_closing = true
		get_tree().root.propagate_call("_on_closing_editor")
		await RenderingServer.frame_post_draw
		get_tree().quit()


func _on_save_close() -> void:
	save()
	_on_actual_close()


func _on_cancel_close() -> void:
	if Settings.get_auto_save():
		_auto_save_timer.start()


#--- Project setters & getters ---
func set_project_path(new_project_path: String) -> void:
	project_path = new_project_path
	_unsaved_changes = true


func get_project_path() -> String:
	return project_path


func get_project_name() -> String:
	var p_path: String = project_path.get_file()
	return p_path.trim_suffix("." + p_path.get_extension())


func get_project_base_folder() -> String:
	return project_path.get_base_dir()


func set_resolution(res: Vector2i) -> void:
	resolution = res
	_unsaved_changes = true


func get_resolution() -> Vector2i:
	return resolution


func set_framerate(new_framerate: float) -> void:
	framerate = new_framerate
	EditorCore.frame_time = 1.0 / framerate
	_unsaved_changes = true


func get_framerate() -> float:
	return framerate


func get_playhead_position() -> int:
	return playhead_position


func get_timeline_end() -> int:
	return timeline_end


func set_timeline_end(value: int) -> void:
	timeline_end = value
	_unsaved_changes = true


func update_timeline_end() -> void:
	var new_end: int = 0

	for track: Dictionary[int, int] in get_tracks():
		if track.size() == 0:
			continue

		var clip: ClipData = get_clip(track[track.keys().max()])
		var value: int = clip.get_end_frame()

		if new_end < value:
			new_end = value
	
	set_timeline_end(new_end)
	propagate_call("_on_timeline_end_update", [new_end])


func set_track_data(track_id: int, key: int, value: int) -> void:
	tracks[track_id][key] = value
	_unsaved_changes = true


func erase_track_entry(track_id: int, key: int) -> void:
	if !tracks[track_id].erase(key):
		printerr("Could not erase ", key, " from track ", track_id, "!")
	else:
		_unsaved_changes = true
	

func get_track_count() -> int:
	return tracks.size()


func get_track_keys(track_id: int) -> PackedInt64Array:
	var keys: PackedInt64Array = tracks[track_id].keys()
	keys.sort()
	return keys


func get_track_values(track_id: int) -> PackedInt64Array:
	return tracks[track_id].values()


func get_tracks() -> Array[Dictionary]:
	return tracks


func get_track_data(track_id: int) -> Dictionary[int, int]:
	var track_data: Dictionary[int, int] = {}
	var keys: PackedInt64Array = get_track_keys(track_id)

	for key: int in keys:
		track_data[key] = tracks[track_id][key]
		
	return track_data


func get_clips() -> Dictionary[int, ClipData]:
	return clips


func get_clip_datas() -> Array[ClipData]:
	return clips.values()


func get_clip_ids() -> PackedInt64Array:
	return clips.keys()


func get_clip(clip_id: int) -> ClipData:
	return clips[clip_id]


func get_clip_type(clip_id: int) -> File.TYPE:
	return files[clips[clip_id].file_id].type


func set_clip(id: int, clip: ClipData) -> void:
	clip.clip_id = id
	clips[id] = clip
	_unsaved_changes = true


func add_clip(clip_data: ClipData) -> void:
	# Used for undoing the deletion of a file.
	clips[clip_data.clip_id] = clip_data
	_unsaved_changes = true


func erase_clip(clip_id: int) -> void:
	if !tracks[clips[clip_id].track_id].erase(clips[clip_id].start_frame):
		Print.erase_error()
	elif !clips.erase(clip_id):
		Print.erase_error()
	else:
		_unsaved_changes = true

	get_tree().root.propagate_call("_on_clip_erased", [clip_id])


func get_files() -> Dictionary[int, File]:
	return files


func set_background_color(color: Color) -> void:
	background_color = color
	EditorCore.set_background_color(color)
	_unsaved_changes = true


func get_background_color() -> Color:
	return background_color


func set_timeline_scroll_h(value: int) -> void:
	timeline_scroll_h = value
	_unsaved_changes = true


func get_timeline_scroll_h() -> int:
	return timeline_scroll_h


func set_zoom(value: float) -> void:
	zoom = value


func get_zoom() -> float:
	return zoom


func add_folder(folder: String) -> void:
	if folders.has(folder):
		print("Folder %s already exists!")
	elif folders.append(folder):
		Print.append_error()
	else:
		_unsaved_changes = true


func get_folders() -> PackedStringArray:
	return folders


func add_marker(frame_nr: int, marker: MarkerData) -> void:
	if markers.has(frame_nr):
		update_marker(frame_nr, frame_nr, marker)
	else:
		_unsaved_changes = true
		markers[frame_nr] = marker
		_markers_updated.emit()
		propagate_call("_on_marker_added", [frame_nr, marker])


func update_marker(old_frame_nr: int, new_frame_nr: int, marker: MarkerData) -> void:
	markers[new_frame_nr] = marker
	if !markers.erase(old_frame_nr):
		Print.erase_error()

	_unsaved_changes = true
	_markers_updated.emit()
	propagate_call("_on_marker_updated", [old_frame_nr, new_frame_nr, marker])


func remove_marker(frame_nr: int) -> void:
	if !markers.has(frame_nr):
		printerr("No marker at %s!" % frame_nr)
	elif !markers.erase(frame_nr):
		Print.erase_error()
	else:
		_unsaved_changes = true
		_markers_updated.emit()
		propagate_call("_on_marker_removed", [frame_nr])


func get_marker(frame_nr: int) -> MarkerData:
	return markers[frame_nr]


func get_marker_positions() -> PackedInt64Array:
	var project_markers: PackedInt64Array = markers.keys()

	project_markers.sort()
	return project_markers


func get_markers() -> Dictionary[int, MarkerData]:
	return markers

