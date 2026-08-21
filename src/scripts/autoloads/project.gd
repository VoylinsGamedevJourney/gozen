extends Node

signal project_ready
signal timeline_end_update(new_end: int)
signal render_region_updated

signal resolution_changed
signal framerate_changed


const EXTENSION: String = ".gozen"
const RECENT_PROJECTS_FILE: String = "user://recent_projects"


var data: ProjectData = ProjectData.new()
var is_loaded: bool = false

var unsaved_changes: bool = false : set = _unsaved_changes
var auto_save_timer: Timer



func _ready() -> void:
	@warning_ignore("return_value_discarded")
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


func new_project(request: RequestProjectNew) -> void:
	var loading_overlay: ProgressOverlay = PopupManager.get_popup(PopupManager.PROGRESS)

	loading_overlay.update_title(tr("New project"))
	loading_overlay.update(0, tr("Initialize new project ..."))

	set_project_path(request.project_path)
	set_resolution(request.resolution)
	set_framerate(request.framerate, true)
	data.render_region = Vector2i(0, int(request.framerate * 60.0))
	_setup_logic()

	loading_overlay.update(50, tr("Setting up playback ..."))
	for index: int in request.track_amount:
		TrackLogic._add_track(index)

	loading_overlay.update(99, tr("Finalizing ..."))
	get_window().title = "GoZen - %s" % get_project_name()
	_update_recent_projects(get_project_path())
	PopupManager.close_all()
	if !data.project_path.is_empty(): save()

	set_background_color(request.background_color)

	is_loaded = true
	if !data.project_path.is_empty(): _auto_save()
	project_ready.emit()


func save(auto_saved: bool = false) -> void:
	if data.project_path.is_empty(): save_as()

	data.playhead = EditorCore.frame_nr
	var was_unsaved: bool = unsaved_changes
	unsaved_changes = false
	if DataManager.save_data(get_project_path(), data):
		unsaved_changes = was_unsaved
		if auto_saved:
			printerr("Project: Something went wrong whilst auto-saving project! ", FileAccess.get_open_error())
			NotificationManager.info("Something went wrong whilst auto-saving project! " + str(FileAccess.get_open_error()))
		else:
			printerr("Project: Something went wrong whilst saving project! ", FileAccess.get_open_error())
			NotificationManager.info("Something went wrong whilst saving project! " + str(FileAccess.get_open_error()))
		return
	elif was_unsaved and auto_saved:
		NotificationManager.info("Project auto-saved successfully!")
	elif !auto_saved:
		NotificationManager.info("Project saved successfully!")


func save_as() -> void:
	var dialog: FileDialog = PopupManager.create_file_dialog(
			tr("Save project as ..."),
			FileDialog.FILE_MODE_SAVE_FILE,
			["*%s;%s" % [EXTENSION, tr("GoZen project file")]])

	@warning_ignore("return_value_discarded")
	dialog.file_selected.connect(_save_as)
	add_child(dialog)
	dialog.popup_centered()


func archive_as() -> void:
	var dialog: FileDialog = PopupManager.create_file_dialog(
			tr("Archive project as ..."),
			FileDialog.FILE_MODE_SAVE_FILE,
			["*.zip;" + tr("ZIP Archive")])

	@warning_ignore("return_value_discarded")
	dialog.file_selected.connect(_archive_project)
	add_child(dialog)
	dialog.popup_centered()


func _archive_project(zip_path: String) -> void:
	if not zip_path.ends_with(".zip"):
		zip_path += ".zip"

	var loading_overlay: ProgressOverlay = PopupManager.get_popup(PopupManager.PROGRESS)
	loading_overlay.update_title(tr("Archiving project"))
	loading_overlay.update(0, tr("Preparing files ..."))

	var archive_data: Dictionary = data.serialize()
	var file_count: int = data.files.size()

	Threader.add_task(
			_archive_task.bind(zip_path, archive_data, file_count, loading_overlay),
			_on_archive_finished)


func _archive_task(zip_path: String, archive_data: Dictionary, file_count: int, loading_overlay: ProgressOverlay) -> void:
	var packer: ZIPPacker = ZIPPacker.new()
	var err: int = packer.open(zip_path)
	if err != OK:
		printerr("Failed to open zip packer at ", zip_path)
		loading_overlay.call_deferred("update", 0, "Failed to open zip packer!")
		return

	var current_file: int = 0
	var project_name: String = get_project_name() + EXTENSION
	archive_data["project_path"] = "./" + project_name

	for file_id: int in archive_data["files"]:
		var file_dict: Dictionary = archive_data["files"][file_id]
		var old_path: String = file_dict["path"]
		if not old_path.begins_with("temp://"):
			var new_name: String = str(file_id) + "_" + old_path.get_file()
			var new_path: String = "./raw/" + new_name
			file_dict["path"] = new_path

			err = packer.start_file("raw/" + new_name)
			var file: FileAccess = FileAccess.open(old_path, FileAccess.READ)
			if file:
				var chunk_size: int = 1024 * 1024 * 10 # 10MB chunks.
				var file_len: int = file.get_length()
				var bytes_read: int = 0

				while true:
					var buffer: PackedByteArray = file.get_buffer(chunk_size)
					if buffer.size() > 0:
						err = packer.write_file(buffer)
						bytes_read += buffer.size()

						var file_progress: float = float(bytes_read) / float(maxi(1, file_len))
						var total_progress: int = int(((float(current_file) + file_progress) / float(maxi(1, file_count))) * 90)
						loading_overlay.call_deferred("update", total_progress, "Zipping: " + new_name)

					if buffer.size() < chunk_size:
						break
				file.close()
			err = packer.close_file()

		current_file += 1
		loading_overlay.call_deferred("update", int((float(current_file) / float(maxi(1, file_count))) * 90), "Zipping files ...")
	err = packer.start_file(project_name)

	var project_str: String = var_to_str(archive_data)
	err = packer.write_file(project_str.to_utf8_buffer())
	err = packer.close_file()
	err = packer.close()
	loading_overlay.call_deferred("update", 100, "Archive complete!")


func _on_archive_finished() -> void:
	await get_tree().create_timer(1.0).timeout
	NotificationManager.info("Archiving finished")
	PopupManager.close(PopupManager.PROGRESS)


func open(new_project_path: String) -> void:
	var loading_overlay: ProgressOverlay = PopupManager.get_popup(PopupManager.PROGRESS)

	loading_overlay.update_title(tr("Loading project"))
	loading_overlay.update(0, tr("Initializing ..."))
	loading_overlay.update_bar(1)

	data = ProjectData.new()

	if DataManager.load_data(new_project_path, data):
		printerr("Project: Something went wrong whilst loading project! ", FileAccess.get_open_error())

	set_project_path(new_project_path)
	var base_dir: String = new_project_path.get_base_dir()
	for file: FileData in data.files.values():
		if file.path.begins_with("./"):
			file.path = base_dir.path_join(file.path.trim_prefix("./"))

	loading_overlay.update(5, tr("Setting up timeline ..."))
	set_framerate(data.framerate, true)
	_setup_logic()

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
			if file.type in [EditorCore.Type.VIDEO, EditorCore.Type.AUDIO]:
				if not FileLogic.file_data.has(file.id):
					all_loaded = false
					break
		if not all_loaded:
			await get_tree().process_frame

	EffectsHandler.sync_project_effects(data.clips, data.files)

	# 99% = Finalizing.
	loading_overlay.update(99, tr("Finalizing ..."))
	_update_recent_projects(get_project_path())

	loading_overlay.set_bar(100)
	get_window().title = "GoZen - %s" % get_project_path().get_file().get_basename()
	PopupManager.close(PopupManager.PROGRESS)

	is_loaded = true
	project_ready.emit()
	update_timeline_end()
	unsaved_changes = false
	_auto_save()
	await get_tree().process_frame
	EditorCore.set_frame(data.playhead)


func open_project() -> void:
	var dialog: FileDialog = PopupManager.create_file_dialog(
			tr("Open project"), FileDialog.FILE_MODE_OPEN_FILE,
			["*%s;%s" % [EXTENSION, tr("GoZen project files")]])

	@warning_ignore("return_value_discarded")
	dialog.file_selected.connect(_open_project)
	add_child(dialog)
	dialog.popup_centered()


func open_settings_menu() -> void:
	PopupManager.open(PopupManager.PROJECT_SETTINGS)


func _auto_save() -> void:
	if auto_save_timer == null:
		auto_save_timer = Timer.new()
		add_child(auto_save_timer)
		@warning_ignore("return_value_discarded")
		auto_save_timer.timeout.connect(_auto_save)

	if Settings.get_auto_save():
		if is_loaded and !RenderManager.is_encoding and !data.project_path.is_empty():
			save.call_deferred(true)
		auto_save_timer.start(5 * 60) # Default time is every 5 minutes.
	else:
		auto_save_timer.stop()


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

	@warning_ignore_start("return_value_discarded")
	popup.confirmed.connect(_on_save_close)
	cancel_button.pressed.connect(_on_cancel_close)
	dont_save_button.pressed.connect(func() -> void: get_tree().quit.call_deferred())
	@warning_ignore_restore("return_value_discarded")

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


func get_project_path() -> String: return data.project_path
func get_project_name() -> String: return data.project_path.get_file().get_basename()
func get_project_base_folder() -> String: return data.project_path.get_base_dir()


func set_resolution(resolution: Vector2i) -> void:
	var old_resolution: Vector2i = data.resolution
	resolution.x += resolution.x % 2
	resolution.y += resolution.y % 2

	if old_resolution == resolution: return

	var ratio: Vector2 = Vector2(resolution) / Vector2(old_resolution)
	data.resolution = resolution

	# Made this build in as it only needs to happen here. Not clean, I know, but
	# don't care for now. XD
	var _update_effect: Callable = func(effect: Effect, new_ratio: Vector2) -> void:
		var scale_params: Array[String] = []
		if effect.id == "transform":
			scale_params = ["pivot", "position"]
		elif effect.id == "rounded_corners":
			scale_params = ["width", "height", "center_x", "center_y"]
		elif effect.id == "vignette":
			scale_params = ["center"]

		if scale_params.is_empty(): return

		for param_id: String in scale_params:
			if effect.keyframes.has(param_id):
				var frames: Dictionary = effect.keyframes[param_id]
				for frame: int in frames.keys():
					var value: Variant = frames[frame]
					if typeof(value) == TYPE_VECTOR2I or typeof(value) == TYPE_VECTOR2:
						frames[frame] = Vector2i(value as Vector2 * new_ratio)
					elif typeof(value) == TYPE_FLOAT or typeof(value) == TYPE_INT:
						if param_id.ends_with("y") or param_id == "height":
							frames[frame] = value as float * new_ratio.y
						else:
							frames[frame] = value as float * new_ratio.x

			for param: EffectParam in effect.params:
				if param.id == param_id:
					var value: Variant = param.default_value
					if typeof(value) == TYPE_VECTOR2I or typeof(value) == TYPE_VECTOR2:
						param.default_value = Vector2i(value as Vector2 * ratio)
					elif typeof(value) == TYPE_FLOAT or typeof(value) == TYPE_INT:
						if param_id.ends_with("y") or param_id == "height":
							param.default_value = value as float * ratio.y
						else:
							param.default_value = value as float * ratio.x

		effect._cache_dirty = true

	if is_loaded:
		for file: FileData in FileLogic.files.values():
			if file.temp_file and file.temp_file.text_effect:
				_update_effect.call(file.temp_file.text_effect, ratio)

		for clip: ClipData in ClipLogic.clips.values():
			for effect: Effect in clip.effects.video:
				_update_effect.call(effect, ratio)

		EffectsHandler.effect_values_updated.emit()

	unsaved_changes = true
	resolution_changed.emit()


func get_resolution() -> Vector2i: 		  return data.resolution
func get_resolution_center() -> Vector2i: return data.resolution / 2.0


func set_framerate(new_framerate: float, force: bool = false) -> void:
	if !force and is_equal_approx(data.framerate, new_framerate): return

	var old_framerate: float = data.framerate
	data.framerate = new_framerate
	EditorCore.frame_time = 1.0 / data.framerate
	unsaved_changes = true

	if is_loaded:
		data.playhead = EditorCore.frame_nr
		var ratio: float = new_framerate / old_framerate

		for file: FileData in FileLogic.files.values():
			file.duration = maxi(1, roundi(file.duration * ratio))
			if file.temp_file and file.temp_file.text_effect:
				_scale_keyframes(file.temp_file.text_effect, ratio)
			if file.type in [EditorCore.Type.AUDIO, EditorCore.Type.VIDEO]:
				@warning_ignore("RETURN_VALUE_DISCARDED")
				FileLogic.audio_wave.erase(file.id)
				Threader.add_task(FileLogic._create_wave.bind(file), FileLogic._on_wave_ready.bind(file))

		for clip: ClipData in ClipLogic.clips.values():
			clip.start = roundi(clip.start * ratio)
			clip.begin = roundi(clip.begin * ratio)
			clip.duration = maxi(1, roundi(clip.duration * ratio))
			clip.effects.fade_visual = Vector2i(roundi(clip.effects.fade_visual.x * ratio), roundi(clip.effects.fade_visual.y * ratio))
			clip.effects.fade_audio = Vector2i(roundi(clip.effects.fade_audio.x * ratio), roundi(clip.effects.fade_audio.y * ratio))

			for effect: Effect in clip.effects.video:
				_scale_keyframes(effect, ratio)
			for effect: Effect in clip.effects.audio:
				_scale_keyframes(effect, ratio)

		for marker: MarkerData in MarkerLogic.markers:
			marker.frame_nr = roundi(marker.frame_nr * ratio)

		MarkerLogic.markers.sort_custom(MarkerLogic._sort)

		data.playhead = roundi(data.playhead * ratio)
		data.render_region = Vector2i(roundi(data.render_region.x * ratio), roundi(data.render_region.y * ratio))

		for track_data: TrackLogic.TrackClips in TrackLogic.track_clips:
			track_data.sort()

		Timeline.zoom = clampf(Timeline.zoom / ratio, 0.01, 200.0)

		update_timeline_end()
		EditorCore.is_playing = false
		EditorCore.frame_nr = data.playhead
		EditorCore.visual_frame_nr = data.playhead
		render_region_updated.emit()
		ClipLogic.updated.emit()

		InputManager.undo_redo.clear_history()

	framerate_changed.emit()

func _scale_keyframes(effect: Effect, ratio: float) -> void:
	for param_id: String in effect.keyframes.keys():
		var new_keys: Dictionary[int, Variant] = {}
		var frames: Dictionary = effect.keyframes[param_id]
		for frame: int in frames.keys():
			new_keys[roundi(frame * ratio)] = frames[frame]
		effect.keyframes[param_id] = new_keys
	effect._cache_dirty = true


func get_framerate() -> float:
	return data.framerate


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


func set_render_toggle(value: bool) -> void:
	data.use_render_region = value
	unsaved_changes = true
	render_region_updated.emit()


func set_render_region(region: Vector2i) -> void:
	if region.x >= region.y: # Invalid region.
		region.y = region.x + int(data.framerate)
	data.render_region = region
	unsaved_changes = true
	render_region_updated.emit()
