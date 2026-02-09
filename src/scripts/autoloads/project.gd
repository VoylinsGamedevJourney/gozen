extends Node

signal project_ready
signal timeline_end_update(new_end: int)


const EXTENSION: String = ".gozen"
const RECENT_PROJECTS_FILE: String = "user://recent_projects"


var data: ProjectData = ProjectData.new()
var is_loaded: bool = false

var unsaved_changes: bool = false
var auto_save_timer: Timer

var files: FileLogic
var clips: ClipLogic
var tracks: TrackLogic
var markers: MarkerLogic
var folders: FolderLogic



func _ready() -> void:
	get_window().close_requested.connect(_on_close)
	clips.updated.connect(update_timeline_end)


func _setup_logic() -> void:
	files = FileLogic.new(data)
	clips = ClipLogic.new(data)
	tracks = TrackLogic.new(data)
	markers = MarkerLogic.new(data)
	folders = FolderLogic.new(data)


func new_project(new_path: String, new_resolution: Vector2i, new_framerate: float) -> void:
	var loading_overlay: ProgressOverlay = PopupManager.get_popup(PopupManager.POPUP.PROGRESS)

	loading_overlay.update_title(tr("New project"))
	loading_overlay.update_progress(0, tr("Initialize new project ..."))

	set_project_path(new_path)
	set_resolution(new_resolution)
	set_framerate(new_framerate)
	_setup_logic()

	for index: int in Settings.get_tracks_amount(): tracks._add_track(index, false)
	EditorCore.loaded_clips.resize(data.tracks.size())

	loading_overlay.update_progress(50, tr("Setting up playback ..."))
	EditorCore.setup_playback()
	EditorCore.setup_audio_players()
	EditorCore.set_frame(get_playhead_position())

	loading_overlay.update_progress(99, tr("Finalizing ..."))
	get_window().title = "GoZen - %s" % new_path.get_file().get_basename()
	_update_recent_projects(new_path)
	PopupManager.close_popups()
	save()

	is_loaded = true
	_auto_save()
	project_ready.emit()


func save() -> void:
	if DataManager.save_data(get_project_path(), data):
		printerr("Project: Something went wrong whilst saving project! ", FileAccess.get_open_error())
	else:
		unsaved_changes = false


func save_as() -> void:
	var dialog: FileDialog = PopupManager.create_file_dialog(
			tr("Save project as ..."),
			FileDialog.FILE_MODE_SAVE_FILE,
			["*%s;%s" % [EXTENSION, tr("GoZen project file")]])

	dialog.file_selected.connect(_save_as)
	add_child(dialog)
	dialog.popup_centered()


func open(new_project_path: String) -> void:
	var loading_overlay: ProgressOverlay = PopupManager.get_popup(PopupManager.POPUP.PROGRESS)
	var progress_increment: float

	loading_overlay.update_title(tr("Loading project"))
	loading_overlay.update_progress(0, tr("Initializing ..."))
	loading_overlay.update_progress_bar(1, true)

	if DataManager.load_data(new_project_path, data):
		printerr("Project: Something went wrong whilst loading project! ", FileAccess.get_open_error())

	loading_overlay.update_progress(5, tr("Setting up timeline ..."))
	set_project_path(new_project_path)
	set_framerate(data.framerate)
	_setup_logic()

	EditorCore.loaded_clips.resize(data.tracks.size())

	# 7% = Timeline ready to accept clips.
	loading_overlay.update_progress(7, tr("Loading project files ..."))
	progress_increment = (1 / float(data.files.size())) * 73

	for i: int in data.files.keys():
		if !files.load_file_data(i):
			continue # File became invaled so entry got deleted.

		var type: files.TYPE = data.files[i].type

		if type in files.TYPE_VIDEOS and files.data[i].video == null:
			await files.data[i].video_loaded

		loading_overlay.increment_progress_bar(progress_increment)

	# 80% = Files loaded, setting up playback.
	loading_overlay.update_progress(80, tr("Setting up playback ..."))
	EditorCore.setup_playback()
	EditorCore.setup_audio_players()

	# 99% = Finalizing.
	loading_overlay.update_progress(99, tr("Finalizing ..."))
	_update_recent_projects(get_project_path())

	loading_overlay.update_progress_bar(100)
	get_window().title = "GoZen - %s" % get_project_path().get_file().get_basename()
	PopupManager.close_popup(PopupManager.POPUP.PROGRESS)

	is_loaded = true
	unsaved_changes = false
	project_ready.emit()
	EditorCore.set_frame(get_playhead_position())
	_auto_save()


func open_project() -> void:
	var dialog: FileDialog = PopupManager.create_file_dialog(
			tr("Open project"), FileDialog.FILE_MODE_OPEN_FILE,
			["*%s;%s" % [EXTENSION, tr("GoZen project files")]])

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

	if is_loaded:
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


func _on_close() -> void:
	if !unsaved_changes:
		get_tree().quit()
		return

	var popup: AcceptDialog = AcceptDialog.new()
	var dont_save_button: Button = popup.add_button(tr("Don't save"))
	var cancel_button: Button = popup.add_cancel_button(tr("Cancel"))

	auto_save_timer.paused = true
	popup.title = tr("Close without saving")
	popup.ok_button_text = tr("Save")

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

	for index: int in tracks.get_size():
		var clip_id: int = tracks.get_last_clip_index(index)
		if clip_id != -1:
			end = max(end, clips.get_end_frame(clip_id))

	set_timeline_end(end)
	timeline_end_update.emit(end)


func set_background_color(color: Color) -> void:
	data.background_color = color
	EditorCore.set_background_color(color)
	unsaved_changes = true


func get_background_color() -> Color:
	return data.background_color
