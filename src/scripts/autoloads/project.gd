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


func _setup_logic() -> void:
	files = FileLogic.new(data)
	clips = ClipLogic.new(data)
	tracks = TrackLogic.new(data)
	markers = MarkerLogic.new(data)
	folders = FolderLogic.new(data)

	clips.updated.connect(update_timeline_end)


func new_project(new_path: String, new_resolution: Vector2i, new_framerate: float) -> void:
	var loading_overlay: ProgressOverlay = PopupManager.get_popup(PopupManager.PROGRESS)

	loading_overlay.update_title(tr("New project"))
	await loading_overlay.update(0, tr("Initialize new project ..."))

	set_project_path(new_path)
	set_resolution(new_resolution)
	set_framerate(new_framerate)
	_setup_logic()

	for index: int in Settings.get_tracks_amount():
		tracks._add_track(index, false)
	EditorCore.loaded_clips.resize(data.tracks_is_muted.size())

	await loading_overlay.update(50, tr("Setting up playback ..."))
	await loading_overlay.update(99, tr("Finalizing ..."))
	get_window().title = "GoZen - %s" % new_path.get_file().get_basename()
	_update_recent_projects(new_path)
	PopupManager.close_all()
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
	var loading_overlay: ProgressOverlay = PopupManager.get_popup(PopupManager.PROGRESS)

	loading_overlay.update_title(tr("Loading project"))
	await loading_overlay.update(0, tr("Initializing ..."))
	await loading_overlay.update_bar(1, true)

	if DataManager.load_data(new_project_path, data):
		printerr("Project: Something went wrong whilst loading project! ", FileAccess.get_open_error())

	await loading_overlay.update(5, tr("Setting up timeline ..."))
	set_project_path(new_project_path)
	set_framerate(data.framerate)
	_setup_logic()

	EditorCore.loaded_clips.resize(data.tracks_is_muted.size())

	# 7% = Timeline ready to accept clips.
	await loading_overlay.update(7, tr("Loading project files ..."))
	files._startup_loading(loading_overlay, (1 / float(data.files.size())) * 85)
	# 99% = Finalizing.
	await loading_overlay.update(99, tr("Finalizing ..."))
	_update_recent_projects(get_project_path())

	await loading_overlay.update_bar(100)
	get_window().title = "GoZen - %s" % get_project_path().get_file().get_basename()
	PopupManager.close(PopupManager.PROGRESS)

	is_loaded = true
	unsaved_changes = false
	project_ready.emit()
	EditorCore.set_frame(data.playhead)
	_auto_save()


func open_project() -> void:
	var dialog: FileDialog = PopupManager.create_file_dialog(
			tr("Open project"), FileDialog.FILE_MODE_OPEN_FILE,
			["*%s;%s" % [EXTENSION, tr("GoZen project files")]])

	dialog.file_selected.connect(_open_project)
	add_child(dialog)
	dialog.popup_centered()


func open_settings_menu() -> void:
	PopupManager.open(PopupManager.PROJECT_SETTINGS)


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


func set_resolution(resolution: Vector2i) -> void:
	resolution.x += resolution.x % 2
	resolution.y += resolution.y % 2
	data.resolution = resolution
	unsaved_changes = true


func get_resolution() -> Vector2i:
	return data.resolution


func get_resolution_center() -> Vector2i:
	return data.resolution / 2.0


func set_framerate(new_framerate: float) -> void:
	data.framerate = new_framerate
	EditorCore.frame_time = 1.0 / data.framerate
	unsaved_changes = true


func update_timeline_end() -> void:
	var end: int = 0
	for index: int in data.tracks_is_muted.size():
		var clip_id: int = tracks.get_last_clip_id(index)
		if clip_id != -1:
			var clip_index: int = clips.index_map[clip_id]
			var clip_start: int = data.clips_start[clip_index]
			var clip_duration: int = data.clips_duration[clip_index]
			end = max(end, clip_start + clip_duration)
	data.timeline_end = end
	unsaved_changes = true
	timeline_end_update.emit(end)


func set_background_color(color: Color) -> void:
	data.background_color = color
	EditorCore.set_background_color(color)
	unsaved_changes = true
