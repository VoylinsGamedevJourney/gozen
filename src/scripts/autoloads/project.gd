extends Node


signal project_ready

signal timeline_end_update(new_end: int)


const EXTENSION: String = ".gozen"
const RECENT_PROJECTS_FILE: String = "user://recent_projects"



var data: ProjectData = ProjectData.new()
var loaded: bool = false

var unsaved_changes: bool = false
var auto_save_timer: Timer



func _ready() -> void:
	get_window().close_requested.connect(_on_close_requested)
	ClipHandler.clips_updated.connect(update_timeline_end)
	CommandManager.register(
			"command_project_settings", open_settings_menu, "open_project_settings")


func new_project(new_path: String, new_resolution: Vector2i, new_framerate: float) -> void:
	var loading_overlay: ProgressOverlay = PopupManager.get_popup(PopupManager.POPUP.PROGRESS)

	loading_overlay.update_title("title_new_project")
	loading_overlay.update_progress(0, "status_new_project_init")

	set_project_path(new_path)
	set_resolution(new_resolution)
	set_framerate(new_framerate)

	FileHandler.files = data.files
	TrackHandler.tracks = data.tracks
	ClipHandler.clips = data.clips

	# Prepare tracks
	data.tracks.resize(Settings.get_tracks_amount())
	data.tracks.fill(TrackData.new())

	for track_id: int in data.tracks.size():
		data.tracks[track_id].id = track_id

	EditorCore.loaded_clips.resize(data.tracks.size())

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
	if DataManager.save_data(get_project_path(), data):
		printerr("Project: Something went wrong whilst saving project! ", FileAccess.get_open_error())
	else:
		unsaved_changes = false


func save_as() -> void:
	var dialog: FileDialog = PopupManager.create_file_dialog(
			"file_dialog_title_save_project_as",
			FileDialog.FILE_MODE_SAVE_FILE,
			["*%s;%s" % [EXTENSION, tr("file_dialog_tooltip_gozen_project_files")]])

	dialog.file_selected.connect(_save_as)
	add_child(dialog)
	dialog.popup_centered()


func open(new_project_path: String) -> void:
	var loading_overlay: ProgressOverlay = PopupManager.get_popup(PopupManager.POPUP.PROGRESS)
	var progress_increment: float

	loading_overlay.update_title("title_loading_project")
	loading_overlay.update_progress(0, "status_project_loading_init")
	loading_overlay.update_progress_bar(1, true)

	if DataManager.load_data(new_project_path, data):
		printerr("Project: Something went wrong whilst loading project! ", FileAccess.get_open_error())

	loading_overlay.update_progress(5, "status_project_preparing_timeline")

	set_project_path(new_project_path)
	set_framerate(data.framerate)

	FileHandler.files = data.files
	TrackHandler.tracks = data.tracks
	ClipHandler.clips = data.clips

	EditorCore.loaded_clips.resize(data.tracks.size())

	# 7% = Timeline ready to accept clips.
	loading_overlay.update_progress(7, "status_project_loading_files")
	progress_increment = (1 / float(data.files.size())) * 73

	for i: int in data.files.keys():
		if !FileHandler.load_file_data(i):
			continue # File became invaled so entry got deleted.

		var type: FileHandler.TYPE = data.files[i].type

		if type in FileHandler.TYPE_VIDEOS and FileHandler.data[i].video == null:
			await FileHandler.data[i].video_loaded

		loading_overlay.increment_progress_bar(progress_increment)

	# 80% = Files loaded, setting up playback.
	loading_overlay.update_progress(80, "status_project_playback_setup")
	EditorCore.setup_playback()
	EditorCore.setup_audio_players()

	# 99% = Finalizing.
	loading_overlay.update_progress(99, "status_project_finalizing")
	_update_recent_projects(get_project_path())

	loading_overlay.update_progress_bar(100)
	get_window().title = "GoZen - %s" % get_project_path().get_file().get_basename()
	PopupManager.close_popup(PopupManager.POPUP.PROGRESS)

	loaded = true
	unsaved_changes = false
	project_ready.emit()
	EditorCore.set_frame(get_playhead_position())
	_auto_save()


func open_project() -> void:
	var dialog: FileDialog = PopupManager.create_file_dialog(
			"file_dialog_title_open_project", FileDialog.FILE_MODE_OPEN_FILE,
			["*%s;%s" % [EXTENSION, tr("file_dialog_tooltip_gozen_project_files")]])

	dialog.file_selected.connect(_open_project)
	add_child(dialog)
	dialog.popup_centered()


func open_settings_menu() -> void:
	PopupManager.open_popup(PopupManager.POPUP.PROJECT_SETTINGS)


func _auto_save() -> void:
	if auto_save_timer == null:
		auto_save_timer = Timer.new()
		add_child(auto_save_timer)
		auto_save_timer.timeout.connect(_auto_save)

	if loaded:
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
		printerr("Project: Error storing String for recent_projects!")


func _open_project(file_path: String) -> void:
	if OS.execute(OS.get_executable_path(), [file_path]) != OK:
		printerr("Project: Something went wrong opening project from file dialog!")


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

	auto_save_timer.paused = true
	popup.title = "title_close_without_saving"
	popup.ok_button_text = "button_save"

	popup.confirmed.connect(_on_save_close)
	cancel_button.pressed.connect(_on_cancel_close)
	dont_save_button.pressed.connect(get_tree().quit)

	add_child(popup)
	popup.popup_centered()


func _on_save_close() -> void:
	save()
	get_tree().quit()


func _on_cancel_close() -> void:
	if Settings.get_auto_save():
		auto_save_timer.start()


#--- Project setters & getters ---
func set_project_path(new_project_path: String) -> void:
	data.project_path = new_project_path
	unsaved_changes = true


func get_project_path() -> String:
	return data.project_path


func get_project_name() -> String:
	return data.project_path.get_file().trim_suffix("." + data.project_path.get_extension())


func get_project_base_folder() -> String:
	return data.project_path.get_base_dir()


func set_resolution(res: Vector2i) -> void:
	if res.x % 2 != 0: res.x += 1
	if res.y % 2 != 0: res.y += 1

	data.resolution = res
	unsaved_changes = true


func get_resolution() -> Vector2i:
	return data.resolution


func get_resolution_center() -> Vector2i:
	return data.resolution / 2.0


func set_framerate(new_framerate: float) -> void:
	data.framerate = new_framerate
	EditorCore.frame_time = 1.0 / data.framerate
	unsaved_changes = true


func get_framerate() -> float:
	return data.framerate


func set_playhead_position(new_pos: int) -> void:
	data.playhead_position = new_pos # No need to set "unsaved_changes" here.


func get_playhead_position() -> int:
	return data.playhead_position


func get_timeline_end() -> int:
	return data.timeline_end


func set_timeline_end(value: int) -> void:
	data.timeline_end = value
	unsaved_changes = true


func update_timeline_end() -> void:
	var end: int = 0

	for track_id: int in data.tracks.size():
		var clip: ClipData = TrackHandler.get_last_clip(track_id)
		if clip != null: end = max(end, ClipHandler.get_end_frame(clip.id))

	set_timeline_end(end)
	timeline_end_update.emit(end)


func set_background_color(color: Color) -> void:
	data.background_color = color
	EditorCore.set_background_color(color)
	unsaved_changes = true


func get_background_color() -> Color:
	return data.background_color
