extends Node

signal project_ready
signal timeline_end_update(new_end: int)


const EXTENSION: String = ".gozen"
const RECENT_PROJECTS_FILE: String = "user://recent_projects"


var data: ProjectData = ProjectData.new()
var is_loaded: bool = false

var unsaved_changes: bool = false : set = _unsaved_changes
var auto_save_timer: Timer



func _ready() -> void:
	get_window().close_requested.connect(_on_close)


func _unsaved_changes(value: bool) -> void:
	if unsaved_changes != value:
		unsaved_changes = value
		if is_loaded:
			var title: String = "GoZen - " + get_project_name()
			if unsaved_changes:
				title += " (*)"
			get_window().title = title


func _setup_logic() -> void:
	FileLogic.files = data.files
	ClipLogic.clips = data.clips
	TrackLogic.tracks = data.tracks
	MarkerLogic.markers = data.markers
	FolderLogic.folders = data.folders
	TrackLogic.prepare_data()


func new_project(new_path: String, new_resolution: Vector2i, new_framerate: float) -> void:
	var loading_overlay: ProgressOverlay = PopupManager.get_popup(PopupManager.PROGRESS)

	loading_overlay.update_title(tr("New project"))
	loading_overlay.update(0, tr("Initialize new project ..."))

	set_project_path(new_path)
	set_resolution(new_resolution)
	set_framerate(new_framerate)
	_setup_logic()

	for index: int in Settings.get_tracks_amount():
		TrackLogic._add_track(index)
	EditorCore.loaded_clips.resize(TrackLogic.tracks.size())

	loading_overlay.update(50, tr("Setting up playback ..."))
	loading_overlay.update(99, tr("Finalizing ..."))
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
		NotificationManager.notify("Something went wrong whilst saving project! " + str(FileAccess.get_open_error()))
	else:
		unsaved_changes = false
		NotificationManager.notify("Project saved successfully!")


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
	loading_overlay.update(0, tr("Initializing ..."))
	loading_overlay.update_bar(1)

	if DataManager.load_data(new_project_path, data):
		printerr("Project: Something went wrong whilst loading project! ", FileAccess.get_open_error())

	loading_overlay.update(5, tr("Setting up timeline ..."))
	set_project_path(new_project_path)
	set_framerate(data.framerate)
	_setup_logic()

	EditorCore.loaded_clips.resize(TrackLogic.tracks.size())

	# 7% = Timeline ready to accept clips.
	loading_overlay.update(7, tr("Loading project files ..."))

	var missing_files: Array[String] = []
	for file: FileData in data.files.values():
		if not file.path.begins_with("temp://") and not FileAccess.file_exists(file.path):
			missing_files.append(file.nickname)
	if not missing_files.is_empty():
		var dialog: AcceptDialog = PopupManager.create_accept_dialog("Missing Files")
		dialog.dialog_text = "The following files are missing and could not be loaded:\n" + "\n\t".join(missing_files)
		add_child(dialog)
		dialog.popup_centered()

	FileLogic._startup_loading()
	loading_overlay.update_bar(98)

	var all_loaded: bool = false
	while not all_loaded:
		all_loaded = true
		for file: FileData in data.files.values():
			if file.type in [EditorCore.TYPE.VIDEO, EditorCore.TYPE.AUDIO]:
				if not FileLogic.file_data.has(file.id):
					all_loaded = false
					break
		if not all_loaded:
			await get_tree().process_frame

	# 99% = Finalizing.
	loading_overlay.update(99, tr("Finalizing ..."))
	_update_recent_projects(get_project_path())

	loading_overlay.set_bar(100)
	get_window().title = "GoZen - %s" % get_project_path().get_file().get_basename()
	PopupManager.close(PopupManager.PROGRESS)

	is_loaded = true
	unsaved_changes = false
	project_ready.emit()
	update_timeline_end()
	_auto_save()
	await get_tree().process_frame
	EditorCore.set_frame(data.playhead)


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

	auto_save_timer.start(5 * 60) # Default time is every 5 minutes.


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
	for track: int in TrackLogic.tracks.size():
		if TrackLogic.track_clips[track].clips.size() != 0:
			var clip: ClipData = TrackLogic.track_clips[track].clips[-1]
			if clip:
				end = max(end, clip.end)
	data.timeline_end = end - 1
	unsaved_changes = true
	timeline_end_update.emit(end)


func set_background_color(color: Color) -> void:
	data.background_color = color
	EditorCore.set_background_color(color)
	unsaved_changes = true
