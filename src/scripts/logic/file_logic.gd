class_name FileLogic
extends RefCounted
## TODO: Improve _rebuild_map so it doesn't keep rebuilding every single time.

signal added(file: int)
signal moved(file: int)
signal deleted(file: int)
signal reloaded(file: int)
signal path_updated(file: int)
signal nickname_changed(file: int)
signal ato_changed(file: int)
signal audio_wave_generated(file: int)

signal video_loaded(file: int)


const MAX_16_BIT_VALUE: float = 32767.0 ## For the audio 16 bits/2 (stereo)


var project_data: ProjectData

# Runtime file data
var file_data: Array = [] ## Can be GoZenVideo, AudioStreamFFmpeg, Texture2D, Color, or PCK
var pck_instances: Dictionary[int, Node] = {} ## { file: PKC instance }
var audio_wave: Dictionary[int, PackedFloat32Array] = {} ## { file: wave_data }
var video_pools: Dictionary[int, Array] = {} ## { file: [GoZenVideo] }
var audio_pools: Dictionary[int, Array] = {} ## { file: [AudioStreamFFmpeg] }

var index_map: Dictionary[int, int] = {} ## { file: index }



# --- Main ---

func _init(data: ProjectData) -> void:
	project_data = data
	Project.get_window().files_dropped.connect(dropped)
	Settings.on_video_cache_size_changed.connect(_update_video_cache_size)
	Settings.on_video_smart_seek_threshold.connect(_update_video_smart_seek_threshold)
	_rebuild_map()


func _rebuild_map() -> void:
	index_map.clear()
	for index: int in project_data.files.size():
		index_map[project_data.files[index]] = index


## Load everything on startup and give user indication of the progress.
func _startup_loading(progress: ProgressOverlay, amount: float) -> void:
	for index: int in index_map.size():
		load_data(index)
		progress.increment_bar(amount)


## For undo/redo system.
func _create_snapshot(index: int) -> Dictionary:
	var file: int = project_data.files[index]
	return {
		"file": file,
		"path": project_data.files_path[index],
		"nickname": project_data.files_nickname[index],
		"proxy_path": project_data.files_proxy_path[index],
		"folder": project_data.files_folder[index],
		"type": project_data.files_type[index],
		"duration": project_data.files_duration[index],
		"modified_time": project_data.files_modified_time[index],

		"temp_file": project_data.files_temp_file.get(file),
		"ato_active": project_data.files_ato_active.get(file),
		"ato_offset": project_data.files_ato_offset.get(file),
		"ato_file": project_data.files_ato_file.get(file)
	}


## For undo/redo system. (for when creating a pasted temp image)
func _create_snapshot_temp_image(file: int, temp_file: TempFile) -> Dictionary:
	return {
		"file": file,
		"path": "temp://image",
		"nickname": "Image %s" % file,
		"proxy_path": "",
		"folder": "/",
		"type": EditorCore.TYPE.IMAGE,
		"duration": Settings.get_image_duration(),
		"modified_time": -1,

		"temp_file": temp_file,
		"ato_active": null, "ato_offset": null, "ato_file": null
	}


func _create_snapshot_temp_text(file: int, temp_file: TempFile) -> Dictionary:
	return {
		"file": file,
		"path": "temp://text",
		"nickname": "Text %s" % file,
		"proxy_path": "",
		"folder": "/",
		"type": EditorCore.TYPE.TEXT,
		"duration": Settings.get_text_duration(),
		"modified_time": -1,

		"temp_file": temp_file,
		"ato_active": null, "ato_offset": null, "ato_file": null
	}


# --- Handling ---

func add(paths: PackedStringArray) -> void:
	InputManager.undo_redo.create_action("Add file")
	var file_paths: PackedStringArray = project_data.files_path
	for path: String in paths:
		if path in file_paths:
			continue # Duplication check.

		InputManager.undo_redo.add_do_method(_add.bind(path))
		InputManager.undo_redo.add_undo_method(_delete.bind(path))
	InputManager.undo_redo.add_do_method(_rebuild_map)
	InputManager.undo_redo.add_undo_method(_rebuild_map)
	InputManager.undo_redo.commit_action()


func _add(path: String) -> int:
	var extension: String = path.get_extension().to_lower()
	var file_index: int = index_map.size()
	var file: int = Utils.get_unique_id(project_data.files)
	var type: EditorCore.TYPE = EditorCore.TYPE.EMPTY
	var duration: int = -1 # Video and audio first need to be loaded.
	var nickname: String = path.get_file()
	var modified_time: int = -1

	if extension in ProjectSettings.get_setting("extensions/image"):
		type = EditorCore.TYPE.IMAGE
		duration = Settings.get_image_duration()
		modified_time = FileAccess.get_modified_time(path)
	elif extension in ProjectSettings.get_setting("extensions/audio"):
		type = EditorCore.TYPE.AUDIO
		duration = floori(GoZenVideo.get_duration(path) * Project.data.framerate)
		modified_time = FileAccess.get_modified_time(path)
	elif extension in ProjectSettings.get_setting("extensions/video"):
		type = EditorCore.TYPE.VIDEO # We check later if the video is audio only.
		duration = floori(GoZenVideo.get_duration(path) * Project.data.framerate)
		modified_time = FileAccess.get_modified_time(path)
	elif extension == "pck":
		type = EditorCore.TYPE.PCK
	else: printerr("FileLogic: Invalid file:
		", path)

	if path.contains("temp://"):
		var temp_nickname: String = path.trim_prefix("temp://").capitalize()
		if path == "temp://text":
			type = EditorCore.TYPE.TEXT
			duration = Settings.get_text_duration()
			nickname = "%s %s" % [temp_nickname, file]
		elif path == "temp://image":
			type = EditorCore.TYPE.IMAGE
			duration = Settings.get_image_duration()
			nickname = "%s %s" % [temp_nickname, file]
		elif path.begins_with("temp://color"):
			type = EditorCore.TYPE.COLOR
			duration = Settings.get_color_duration()
			nickname = temp_nickname.replace("#", " #")
			path = path.split("#")[0]
	if type == EditorCore.TYPE.EMPTY:
		return -1 # Invalid file, don't bother with it.

	project_data.files.append(file)
	project_data.files_path.append(path)
	project_data.files_nickname.append(nickname)
	project_data.files_proxy_path.append("")
	project_data.files_folder.append("/")
	project_data.files_type.append(type)
	project_data.files_duration.append(duration)
	project_data.files_modified_time.append(modified_time)
	index_map[file] = file_index

	load_data(file_index)
	added.emit(file)
	Project.unsaved_changes = true
	return file


func delete(ids: PackedInt64Array) -> void:
	InputManager.undo_redo.create_action("Delete file")
	for file: int in ids:
		if !index_map.has(file):
			continue
		var index: int = index_map[file]
		var snapshot: Dictionary = _create_snapshot(index)
		InputManager.undo_redo.add_do_method(_delete.bind(file))
		InputManager.undo_redo.add_undo_method(_restore_from_snapshot.bind(snapshot))
	InputManager.undo_redo.add_do_method(_rebuild_map)
	InputManager.undo_redo.add_undo_method(_rebuild_map)
	InputManager.undo_redo.commit_action()


func _delete(file: int) -> void:
	var file_index: int = index_map[file]

	project_data.files.remove_at(file_index)
	project_data.files_path.remove_at(file_index)
	project_data.files_nickname.remove_at(file_index)
	project_data.files_proxy_path.remove_at(file_index)
	project_data.files_folder.remove_at(file_index)
	project_data.files_type.remove_at(file_index)
	project_data.files_duration.remove_at(file_index)
	project_data.files_modified_time.remove_at(file_index)

	if project_data.files_temp_file.has(file):
		project_data.files_temp_file.erase(file)
	if project_data.files_ato_file.has(file):
		project_data.files_ato_active.erase(file)
		project_data.files_ato_offset.erase(file)
		project_data.files_ato_file.erase(file)

	if video_pools.has(file):
		for video: GoZenVideo in video_pools[file]:
			video.close()
		video_pools.erase(file)
	if audio_pools.has(file):
		for stream: AudioStream in audio_pools[file]:
			stream.free()
		audio_pools.erase(file)

	_rebuild_map()
	deleted.emit(file)
	Project.unsaved_changes = true


func _restore_from_snapshot(snapshot: Dictionary) -> void:
	var index: int = index_map.size()
	var file: int = snapshot.file
	project_data.files.append(file)
	project_data.files_path.append(snapshot.path as String)
	project_data.files_nickname.append(snapshot.nickname as String)
	project_data.files_proxy_path.append(snapshot.proxy_path as String)
	project_data.files_folder.append(snapshot.folder as String)
	project_data.files_type.append(snapshot.type as int)
	project_data.files_duration.append(snapshot.duration as int)
	project_data.files_modified_time.append(snapshot.modified_time as int)

	# Restore sparse data
	if snapshot.temp_file != null:
		project_data.files_temp_file[file] = snapshot.temp_file
	if snapshot.ato_active != null:
		project_data.files_ato_active[file] = snapshot.ato_active
	if snapshot.ato_offset != null:
		project_data.files_ato_offset[file] = snapshot.ato_offset
	if snapshot.ato_file != null:
		project_data.files_ato_file[file] = snapshot.ato_file

	index_map[file] = index
	load_data(index)
	added.emit(file)


func move(ids: PackedInt64Array, target: String) -> void:
	InputManager.undo_redo.create_action("Move file(s)")
	for file: int in ids:
		var index: int = index_map[file]
		var folder: String = project_data.files_folder[index]
		InputManager.undo_redo.add_do_method(_move.bind(file, target))
		InputManager.undo_redo.add_undo_method(_move.bind(file, folder))
	InputManager.undo_redo.add_do_method(_rebuild_map)
	InputManager.undo_redo.add_undo_method(_rebuild_map)
	InputManager.undo_redo.commit_action()


func _move(file: int, target: String) -> void:
	var index: int = index_map[file]
	project_data.files_folder[index] = target
	moved.emit(file)
	Project.unsaved_changes = true


func change_nickname(index: int, new_name: String) -> void:
	var file: int = project_data.files[index]
	var old_name: String = project_data.files_nickname[index]

	InputManager.undo_redo.create_action("Change file nickname")
	InputManager.undo_redo.add_do_method(_change_nickname.bind(file, new_name))
	InputManager.undo_redo.add_undo_method(_change_nickname.bind(file, old_name))
	InputManager.undo_redo.commit_action()


func _change_nickname(file: int, new_name: String) -> void:
	var index: int = index_map[file]
	project_data.files_nickname[index] = new_name
	nickname_changed.emit(file)
	Project.unsaved_changes = true


## Pasting from clipboard (through InputManager).
func paste_image(image: Image) -> void:
	InputManager.undo_redo.create_action("Paste Image")
	var file: int = Utils.get_unique_id(project_data.files)
	var temp_file: TempFile = TempFile.new()
	temp_file.image_data = ImageTexture.create_from_image(image)
	var snapshot: Dictionary = _create_snapshot_temp_image(file, temp_file)

	InputManager.undo_redo.add_do_method(_restore_from_snapshot.bind(snapshot))
	InputManager.undo_redo.add_do_method(_rebuild_map)
	InputManager.undo_redo.add_undo_method(_delete.bind(file))
	InputManager.undo_redo.add_undo_method(_rebuild_map)
	InputManager.undo_redo.commit_action()


func apply_audio_take_over(file: int, audio_file: int, offset: float) -> void:
	if !index_map.has(file):
		return
	var active: bool = audio_file != -1
	var affected_clips: PackedInt64Array = []
	for clip_index: int in project_data.clips_file.size():
		if project_data.clips_file[clip_index] == file:
			affected_clips.append(project_data.clips[clip_index])

	if affected_clips.is_empty():
		_commit_ato(file, active, audio_file, offset, false, [])
		return

	var dialog: ConfirmationDialog = PopupManager.create_confirmation_dialog(
		tr("Update existing clips?"),
		tr("This file is currently used by '%d' clip(s).\nDo you want to apply the Audio-Take-Over changes to all existing clips?") % affected_clips.size())
	dialog.get_ok_button().text = tr("Apply to All")
	dialog.get_cancel_button().text = tr("Cancel")
	dialog.add_button(tr("Apply to File Only"), true, "file_only")
	dialog.confirmed.connect(func() -> void:
		_commit_ato(file, active, audio_file, offset, true, affected_clips))
	dialog.custom_action.connect(func(action: String) -> void:
		if action == "file_only":
			_commit_ato(file, active, audio_file, offset, false, [])
			dialog.hide())
	dialog.popup_centered()


func _commit_ato(file: int, active: bool, audio_file: int, offset: float, update_clips: bool, clips: PackedInt64Array) -> void:
	var old_active: bool = project_data.files_ato_active.get(file, false)
	var old_file: int = project_data.files_ato_file.get(file, -1)
	var old_offset: float = project_data.files_ato_offset.get(file, 0.0)

	InputManager.undo_redo.create_action("Set file audio-take-over")
	InputManager.undo_redo.add_do_method(_apply_audio_take_over.bind(file, active, audio_file, offset))
	InputManager.undo_redo.add_undo_method(_apply_audio_take_over.bind(file, old_active, old_file, old_offset))

	if update_clips: # Clips Undo/Redo
		for clip_id: int in clips:
			var clip_index: int = Project.clips.index_map[clip_id]
			var effects: ClipEffects = project_data.clips_effects[clip_index]
			var old_clipt_ato_active: bool = effects.ato_active
			var old_clip_ato_id: int = effects.ato_id
			var old_clip_ato_offset: float = effects.ato_offset
			InputManager.undo_redo.add_do_method(
					Project.clips._apply_audio_take_over.bind(clip_id, active, audio_file, offset))
			InputManager.undo_redo.add_undo_method(
					Project.clips._apply_audio_take_over.bind(
							clip_id, old_clipt_ato_active, old_clip_ato_id, old_clip_ato_offset))
	InputManager.undo_redo.commit_action()


func _apply_audio_take_over(file: int, active: bool, audio_file_id: int, offset: float) -> void:
	project_data.files_ato_active[file] = active
	project_data.files_ato_file[file] = audio_file_id
	project_data.files_ato_offset[file] = offset
	Project.unsaved_changes = true
	ato_changed.emit(file)


func duplicate_text(file: int) -> void:
	if !index_map.has(file):
		return

	var original_temp: TempFile = project_data.files_temp_file[file]
	var new_file: int = Utils.get_unique_id(project_data.files)
	var new_temp: TempFile = TempFile.new()
	new_temp.text_data = original_temp.text_data
	new_temp.font_size = original_temp.font_size
	new_temp.font = original_temp.font
	var snapshot: Dictionary = _create_snapshot_temp_text(new_file, new_temp)

	InputManager.undo_redo.create_action("Duplicate Text File")
	InputManager.undo_redo.add_do_method(_restore_from_snapshot.bind(snapshot))
	InputManager.undo_redo.add_do_method(_rebuild_map)
	InputManager.undo_redo.add_undo_method(_delete.bind(new_file))
	InputManager.undo_redo.add_undo_method(_rebuild_map)
	InputManager.undo_redo.commit_action()


# --- File dropping ---

## File dropping can't be un-done with the undo_redo system!
func dropped(dropped_file_paths: PackedStringArray) -> void:
	var paths: PackedStringArray = []
	for path: String in Utils.find_subfolder_files(dropped_file_paths):
		if path not in project_data.files_path:
			paths.append(path) # Duplicate check.
	if paths.size() == 0:
		return # Early return check

	var progress: ProgressOverlay = PopupManager.get_popup(PopupManager.PROGRESS)
	var progress_increment: float = (1 / float(paths.size())) * 50
	progress.set_state_file_loading(paths.size())
	progress.update_title(tr("Files dropped"))
	await progress.update(0, "")

	var error_occured: bool = false
	var indexes: PackedInt64Array = []
	for path: String in paths:
		var file: int = _add(path)
		if file != -1:
			indexes.append(index_map[file])
			progress.update_file(path, 0)
		else:
			progress.update_file(path, -1)
			error_occured = true
	await progress.update(10, tr("Files loading ..."))

	while !indexes.is_empty(): # Looping till all files are loaded
		await RenderingServer.frame_post_draw
		for index: int in indexes:
			if file_data[index] != null:
				progress.update_file(project_data.files_path[index], 1)
				progress.increment_bar(progress_increment)
				indexes.remove_at(indexes.find(index))

	Project.unsaved_changes = true
	await RenderingServer.frame_post_draw
	if !error_occured:
		PopupManager.close(PopupManager.PROGRESS)
	else:
		progress.show_close()


# --- Data loading ---

## (Re)load the data of a file.
func load_data(file_index: int) -> void:
	# Should normally not happen
	if file_index == -1:
		return printerr("FileLogic: Can't init data as file %s is null!")
	var file: int = project_data.files[file_index]
	var path: String = project_data.files_path[file_index]
	var type: EditorCore.TYPE = project_data.files_type[file_index] as EditorCore.TYPE

	# Create new slot if new file, else copy over existing slot.
	if file_data.size() -1 != file_index:
		file_data.append(null)
	else:
		file_data[file] = null

	if path.begins_with("temp://"): # TODO: Add text
		var temp_file: TempFile = TempFile.new()
		if path == "temp://image":
			file_data[file_index] = temp_file.image_data
		elif path == "temp://color":
			temp_file.load_image_from_color()
			file_data[file_index] = temp_file.image_data
		project_data.files_temp_file[file] = temp_file
		return
	match type:
		EditorCore.TYPE.IMAGE:
			file_data[file_index] = ImageTexture.create_from_image(Image.load_from_file(path))
		EditorCore.TYPE.VIDEO:
			Threader.add_task(_load_video.bind(file), video_loaded.emit.bind(file))
		EditorCore.TYPE.AUDIO:
			if audio_pools.has(file):
				for stream: AudioStream in audio_pools[file]:
					stream.free()
				audio_pools[file] = []

			var stream: AudioStreamFFmpeg = AudioStreamFFmpeg.new()
			if stream.open(path) == OK and stream.get_length() != 0:
				file_data[file_index] = stream
				Threader.add_task(_create_wave.bind(file), _on_wave_ready.bind(file))
			else:
				printerr("FileLogic: Couldn't open audio stream!")
				file_data[file_index] = AudioStreamWAV.new()
		EditorCore.TYPE.PCK:
			if !ProjectSettings.load_resource_pack(path):
				printerr("FileData: Something went wrong loading pck data from '%s'!" % path)
				return _delete(file)
			#var pck_path: String = PCK.MODULES_PATH + path.get_basename().to_lower()
			#var packed_scene: PackedScene = load(pck_path).scene
			#pck_instances[file] = packed_scene.instantiate()


func _load_video(file: int) -> void:
	var index: int = index_map[file]
	var path: String = project_data.files_path[index]
	var temp_video: GoZenVideo = GoZenVideo.new()
	var path_to_load: String = path
	var proxy_path: String = project_data.files_proxy_path[index]

	if Settings.get_use_proxies():
		if !proxy_path.is_empty() and !FileAccess.file_exists(proxy_path):
			path_to_load = proxy_path
	if temp_video.open(path_to_load):
		return printerr("FileData: Couldn't open video at path '%s'!" % path)

	Threader.mutex.lock()
	temp_video.set_smart_seek_threshold(Settings.get_video_smart_seek_threshold())
	temp_video.set_cache_size(Settings.get_video_cache_size())
	file_data[index] = temp_video
	if video_pools.has(file):
		for video: GoZenVideo in video_pools[file]:
			video.close()
		video_pools[file] = []
	Threader.add_task(_create_wave.bind(file), _on_wave_ready.bind(file))
	Threader.mutex.unlock()


func _create_wave(file: int) -> void:
	# TODO: Large audio lengths will still crash this function. Could possibly
	# use the get_audio improvements by cutting the data into pieces.
	# TODO: We should check if the amplification
	var file_index: int = index_map[file]
	var file_path: String = project_data.files_path[file_index]
	var data: PackedByteArray = GoZenAudio.get_audio_data(file_path, -1)

	audio_wave[file] = PackedFloat32Array()
	if data.is_empty():
		return push_warning("Audio data is empty!")

	var bytes_size: float = 4 # 16 bit * stereo
	var total_frames: int = int(data.size() / bytes_size)
	var frames_per_block: int = floori(RenderManager.MIX_RATE / Project.data.framerate)
	var total_blocks: int = ceili(float(total_frames) / frames_per_block)
	var current_frame_index: int = 0

	audio_wave[file].resize(total_blocks)
	for i: int in total_blocks:
		var max_abs_amplitude: float = 0.0
		var start_frame: int = current_frame_index
		var end_frame: int = min(start_frame + frames_per_block, total_frames)

		for frame_index: int in range(start_frame, end_frame):
			var byte_offset: int = int(frame_index * bytes_size)
			var frame_max_abs_amplitude: float = 0.0

			if byte_offset + bytes_size > data.size():
				push_warning("Attempted to read past end of audio data at frame %d." % frame_index)
				break

			var left_sample: int = data.decode_s16(byte_offset)
			var right_sample: int = data.decode_s16(byte_offset + 2)

			frame_max_abs_amplitude = max(abs(float(left_sample)), abs(float(right_sample)))

			if frame_max_abs_amplitude > max_abs_amplitude:
				max_abs_amplitude = frame_max_abs_amplitude

		# Incase we close the editor whilst wave data is still being created.
		if audio_wave[file].size() == 0:
			return
		audio_wave[file][i] = clamp(max_abs_amplitude / MAX_16_BIT_VALUE, 0.0, 1.0)
		current_frame_index = end_frame


func _on_wave_ready(file: int) -> void:
	Settings.on_waveform_update.emit()
	audio_wave_generated.emit(file)


func generate_audio_thumb(file: int) -> Image:
	if !audio_wave.has(file) or audio_wave[file].size() <= 0:
		return null # Up to the file panel to try and fetch later.

	var thumb_size: Vector2i = Vector2i(854, 480)
	var thumb: Image = Image.create_empty(thumb_size.x, thumb_size.y, false, Image.FORMAT_RGB8)

	var data_size: int = audio_wave[file].size()
	var data_per_pixel: float = float(data_size) / thumb_size.x
	var center: int = int(float(thumb_size.y) / 2)
	var amp: int = int(float(thumb_size.y) / 2 * 0.9)

	thumb.fill(Color.DIM_GRAY) # Background color.
	for x_pos: int in thumb_size.x: # Data color.
		var start_index: int = floori(x_pos * data_per_pixel)
		var end_index: int = min(ceili((x_pos + 1) * data_per_pixel), data_size)
		var max_amp: float = 0.0

		if start_index >= end_index:
			continue # No data/End of data
		for i: int in range(start_index, end_index):
			max_amp = max(max_amp, audio_wave[file][i])

		var half_height: int = floori(max_amp * amp)
		var y_top: int = clamp(center - half_height, 0, thumb_size.y - 1)
		var y_bottom: int = clamp(center + half_height, 0, thumb_size.y - 1)

		for y_pos: int in range(y_top, y_bottom + 1):
			thumb.set_pixel(x_pos, y_pos, Color.GHOST_WHITE)

	# Center line.
	for x_pos: int in thumb_size.x:
		thumb.set_pixel(x_pos, center, Color.GRAY)
	return thumb


func reload(file: int) -> void:
	load_data(index_map[file])
	reloaded.emit(file)


func get_video_reader(file: int, instance_index: int) -> GoZenVideo:
	var file_index: int = index_map[file]
	if instance_index == 0:
		return file_data[file_index]

	Threader.mutex.lock()
	if not video_pools.has(file):
		video_pools[file] = []

	var pool: Array = video_pools[file]
	var pool_index: int = instance_index - 1
	if pool_index < pool.size():
		var video: GoZenVideo = pool[pool_index]
		Threader.mutex.unlock()
		return video
	Threader.mutex.unlock()

	# No instance found so we create a new one.
	var file_path: String = project_data.files_path[file_index]
	var file_proxy_path: String = project_data.files_proxy_path[file_index]
	var path_to_load: String = file_path
	if Settings.get_use_proxies() and !file_proxy_path.is_empty() and FileAccess.file_exists(file_proxy_path):
		path_to_load = file_proxy_path

	Threader.mutex.lock()
	var new_video: GoZenVideo = GoZenVideo.new()
	if new_video.open(path_to_load) != OK:
		printerr("FileLogic: Failed to create pool instance for '%s'!" % file_path)
		return file_data[file_index] # Return main video as fallback.
	new_video.set_smart_seek_threshold(Settings.get_video_smart_seek_threshold())
	new_video.set_cache_size(Settings.get_video_cache_size())
	pool.append(new_video)
	Threader.mutex.unlock()
	return new_video


func get_audio_stream(file: int, instance_index: int) -> AudioStreamFFmpeg:
	var file_index: int = index_map[file]
	var type: EditorCore.TYPE = project_data.files_type[file_index] as EditorCore.TYPE

	if type == EditorCore.TYPE.VIDEO:
		var video: GoZenVideo = get_video_reader(file, instance_index)
		return null if video == null else video.get_audio()
	if instance_index == 0:
		return file_data[file_index]

	Threader.mutex.lock()
	if not audio_pools.has(file):
		audio_pools[file] = []

	var pool: Array = audio_pools[file]
	var pool_index: int = instance_index - 1
	if pool_index < pool.size():
		var stream: AudioStream = pool[pool_index]
		Threader.mutex.unlock()
		return stream

	var file_path: String = project_data.files_path[file_index]
	var new_stream: AudioStreamFFmpeg = AudioStreamFFmpeg.new()
	if new_stream.open(file_path) != OK:
		printerr("FileLogic: Failed to create audio pool instance for '%s'!" % file_path)
		Threader.mutex.unlock()
		return file_data[file_index] # Return main audio as fallback.

	pool.append(new_stream)
	Threader.mutex.unlock()
	return new_stream



#-- File creators ---

## Save the image and replace the path in the file data to point to the new image file.
func save_image_to_file(file: int, path: String) -> void:
	const ERROR_MESSAGE: String = "FileLogic: Couldn't save image to %s!\n"
	var index: int = index_map[file]
	var image: Image = project_data.files_temp_file[file].image_data.get_image()
	var extension: String = path.get_extension().to_lower()

	if extension == "png":
		if image.save_png(path):
			return printerr(ERROR_MESSAGE % "png", get_stack())
	if extension == "webp":
		if image.save_webp(path, false, 1.0):
			return printerr(ERROR_MESSAGE % "webp", get_stack())
	else: # JPG is default.
		if image.save_jpg(path, 1.0):
			return printerr(ERROR_MESSAGE % "jpg", get_stack())

	project_data.files_path[index] = path
	project_data.files_temp_file.erase(file)
	load_data(index)
	path_updated.emit(file)


func save_audio_to_wav(file: int, save_path: String) -> void:
	var path: String = project_data.files_proxy_path[index_map[file]]
	var audio_stream: AudioStreamWAV = AudioStreamWAV.new()
	audio_stream.stereo = true
	audio_stream.format = AudioStreamWAV.FORMAT_16_BITS
	audio_stream.mix_rate = int(RenderManager.MIX_RATE)
	audio_stream.data = GoZenAudio.get_audio_data(path, -1)

	if audio_stream.save_to_wav(save_path):
		printerr("FileLogic: Error occured when saving to WAV!")


#--- Private functions ---

func _check_if_modified(file_index: int) -> void:
	var file_path: String = project_data.files_path[file_index]
	if !file_path.begins_with("temp://") and !FileAccess.file_exists(file_path):
		print("FileLogic: File %s at %s doesn't exist anymore!" % [file_index, file_path])
		_delete(project_data.files[file_index])


# --- Getters ---

## Returns all audio file id's.
func get_all_audio_files() -> PackedInt64Array:
	var data: PackedInt64Array = []
	for index: int in project_data.files_type.size():
		if project_data.files_type[index] in EditorCore.AUDIO_TYPES:
			data.append(project_data.files[index])
	return data


## Returns all video file id's.
func get_all_video_files() -> PackedInt64Array:
	var data: PackedInt64Array = []
	for index: int in project_data.files_type.size():
		if project_data.files_type[index] == EditorCore.TYPE.VIDEO:
			data.append(project_data.files[index])
	return data


# --- File data getters ---

func get_data(index: int) -> Variant:
	return file_data[index]


func get_data_by_id(file: int) -> Variant:
	return file_data[index_map[file]]


func get_pck_instance(file: int) -> Node:
	return pck_instances[file]


func get_audio_wave(file: int) -> PackedFloat32Array:
	if audio_wave.has(file):
		return audio_wave[file]
	return []


# --- Setters ---

func set_proxy_path(index: int, path: String) -> void:
	project_data.files_proxy_path[index] = path


func set_nickname(file: int, new_nickname: String) -> void:
	if !index_map.has(file):
		return

	var old_nickname: String = project_data.files_nickname[index_map[file]]
	InputManager.undo_redo.create_action("Renaming file")
	InputManager.undo_redo.add_do_method(_set_nickname.bind(file, new_nickname))
	InputManager.undo_redo.add_undo_method(_set_nickname.bind(file, old_nickname))
	InputManager.undo_redo.commit_action()


func _set_nickname(file: int, nickname: String) -> void:
	var index: int = index_map[file]
	project_data.files_nickname[index] = nickname
	nickname_changed.emit(file)
	Project.unsaved_changes = true


func toggle_ato(file: int) -> void:
	var ato_active: bool = project_data.files_ato_file[file]
	if ato_active:
		InputManager.undo_redo.create_action("Disable file audio take over")
	else:
		InputManager.undo_redo.create_action("Enable file audio take over")
	InputManager.undo_redo.add_do_method(_toggle_ato.bind(file, !ato_active))
	InputManager.undo_redo.add_undo_method(_toggle_ato.bind(file, ato_active))
	InputManager.undo_redo.commit_action()


func _toggle_ato(file: int, value: bool) -> void:
	project_data.files_ato_active[index_map[file]] = value
	Project.unsaved_changes = true


# --- Updaters ---

func update_audio_waves() -> void:
	for file: int in get_all_audio_files():
		var file_index: int = index_map[file]
		if project_data.files_type[file_index] in EditorCore.AUDIO_TYPES:
			load_data(file_index)


func reload_videos() -> void:
	for file: int in get_all_video_files():
		var file_index: int = index_map[file]
		if project_data.files_type[file_index] == EditorCore.TYPE.VIDEO:
			load_data(file_index)


func _update_video_cache_size(value: int) -> void:
	for file: int in get_all_video_files():
		var data: Variant = file_data[index_map[file]]
		if data is not GoZenVideo:
			continue

		(data as GoZenVideo).set_cache_size(value)
		if video_pools.has(file):
			for video: GoZenVideo in video_pools[file]:
				video.set_cache_size(value)


func _update_video_smart_seek_threshold(value: int) -> void:
	for file: int in get_all_video_files():
		var data: Variant = file_data[index_map[file]]
		if data is not GoZenVideo:
			continue

		(data as GoZenVideo).set_smart_seek_threshold(value)
		if video_pools.has(file):
			for video: GoZenVideo in video_pools[file]:
				video.set_smart_seek_threshold(value)


# --- Static ---

## Check if a file is (still) valid or not.
static func check(file_path: String) -> bool:
	if !FileAccess.file_exists(file_path):
		return false # Probably a temp file.

	var ext: String = file_path.get_extension().to_lower()
	return (
		ext in ProjectSettings.get_setting("extensions/image") or
		ext in ProjectSettings.get_setting("extensions/audio") or
		ext in ProjectSettings.get_setting("extensions/video"))
