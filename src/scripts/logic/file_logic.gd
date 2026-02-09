class_name FileLogic
extends RefCounted

signal added(id: int)
signal moved(id: int)
signal deleted(id: int)
signal reloaded(id: int)
signal path_updated(id: int)
signal nickname_changed(id: int)
signal ato_changed(id: int)

signal video_loaded(id: int)


enum TYPE { EMPTY = -1, IMAGE, AUDIO, VIDEO, VIDEO_ONLY, TEXT, COLOR, PCK }


const TYPE_VIDEOS: Array = [TYPE.VIDEO, TYPE.VIDEO_ONLY]
const MAX_16_BIT_VALUE: float = 32767.0 ## For the audio 16 bits/2 (stereo)


var project_data: ProjectData

# Runtime file data
var file_data: Array = [] ## Can be GoZenVideo, AudioStreamFFmpeg, Texture2D, Color, or PCK
var pck_instances: Dictionary[int, Node] = {} ## { file_id: PKC instance }
var audio_wave: Dictionary[int, PackedFloat32Array] = {} ## { file_id: wave_data }
var clip_video_instances: Dictionary[int, GoZenVideo] = {} ## { clip_id: GoZenVideo }

var _id_map: Dictionary[int, int] = {} ## { file_id: index }



func _init(data: ProjectData) -> void:
	project_data = data
	Project.get_tree().root.focus_entered.connect(check)
	Project.get_window().files_dropped.connect(dropped)

	_rebuild_map()


func _rebuild_map() -> void:
	_id_map.clear()
	for index: int in size():
		_id_map[get_id(index)] = index
		load_data(index)


func _create_snapshot(index: int, id: int = get_id(index)) -> Dictionary:
	return {
		"id": id,
		"path": project_data.files_path[index],
		"nickname": project_data.files_nickname[index],
		"proxy_path": project_data.files_proxy_path[index],
		"folder": project_data.files_folder[index],
		"type": project_data.files_type[index],
		"duration": project_data.files_duration[index],
		"modified_time": project_data.files_modified_time[index],
		"clip_only_video_ids": project_data.files_clip_only_video_ids[index].duplicate(),

		"temp_file": project_data.files_temp_file.get(id),
		"ato_active": project_data.files_ato_active.get(id),
		"ato_offset": project_data.files_ato_offset.get(id),
		"ato_id": project_data.files_ato_id.get(id)
	}


# --- Handling ---

func add(paths: PackedStringArray) -> void:
	InputManager.undo_redo.create_action("Add file")
	for path: String in paths:
		if path in get_paths(): continue # Duplication check.
		InputManager.undo_redo.add_do_method(_add.bind(path))
		InputManager.undo_redo.add_undo_method(_delete.bind(path))
	InputManager.undo_redo.add_do_method(_rebuild_map)
	InputManager.undo_redo.add_undo_method(_rebuild_map)
	InputManager.undo_redo.commit_action()


func _add(path: String) -> int:
	var extension: String = path.get_extension().to_lower()
	var index: int = size()
	var id: int = Utils.get_unique_id(get_ids())
	var type: TYPE = TYPE.EMPTY
	var duration: int = -1 # Video and audio first need to be loaded.
	var nickname: String = path.get_file()
	var modified_time: int = -1

	if extension in ProjectSettings.get_setting("extensions/image"):
		type = TYPE.IMAGE
		duration = Settings.get_image_duration()
		modified_time = FileAccess.get_modified_time(path)
	elif extension in ProjectSettings.get_setting("extensions/audio"):
		type = TYPE.AUDIO
		duration = floori(GoZenVideo.get_duration(path) / Project.data.framerate)
		modified_time = FileAccess.get_modified_time(path)
	elif extension in ProjectSettings.get_setting("extensions/video"):
		type = TYPE.VIDEO # We check later if the video is audio only.
		duration = floori(GoZenVideo.get_duration(path) / Project.data.framerate)
		modified_time = FileAccess.get_modified_time(path)
	elif extension == "pck": type = TYPE.PCK
	else: printerr("FileHandler: Invalid file: ", path)

	if path.contains("temp://"):
		if path == "temp://text":
			type = TYPE.TEXT
			duration = Settings.get_text_duration()
		elif path == "temp://image":
			type = TYPE.IMAGE
			duration = Settings.get_image_duration()
		elif path == "temp://color":
			type = TYPE.COLOR
			duration = Settings.get_color_duration()
		nickname = "%s %s" % [path.trim_prefix("temp://").capitalize(), id]
	if type == TYPE.EMPTY: return -1 # Invalid file, don't bother with it.

	project_data.files_id.append(id)
	project_data.files_path.append(path)
	project_data.files_nickname.append(nickname)
	project_data.files_proxy_path.append("")
	project_data.files_folder.append("/")
	project_data.files_type.append(type)
	project_data.files_duration.append(duration)
	project_data.files_modified_time.append(modified_time)
	project_data.files_clip_only_video_ids.append([])
	_id_map[id] = index

	load_data(id)
	return id


func delete(ids: PackedInt64Array) -> void:
	InputManager.undo_redo.create_action("Delete file")
	for id: int in ids:
		if !has(id): continue
		var index: int = get_index(id)
		var snapshot: Dictionary = _create_snapshot(index)
		InputManager.undo_redo.add_do_method(_delete.bind(id))
		InputManager.undo_redo.add_undo_method(_restore_from_snapshot.bind(snapshot))
	InputManager.undo_redo.add_do_method(_rebuild_map)
	InputManager.undo_redo.add_undo_method(_rebuild_map)
	InputManager.undo_redo.commit_action()


func _delete(id: int) -> void:
	var index: int = get_index(id)

	project_data.files_id.remove_at(index)
	project_data.files_path.remove_at(index)
	project_data.files_nickname.remove_at(index)
	project_data.files_proxy_path.remove_at(index)
	project_data.files_folder.remove_at(index)
	project_data.files_type.remove_at(index)
	project_data.files_duration.remove_at(index)
	project_data.files_modified_time.remove_at(index)
	project_data.files_clip_only_video_ids.remove_at(index)

	if has_temp_file(id):
		project_data.files_temp_file.erase(index)
	if has_ato(id):
		project_data.files_ato_active.erase(index)
		project_data.files_ato_offset.erase(index)
		project_data.files_ato_id.erase(index)

	_rebuild_map()
	deleted.emit(id)
	Project.unsaved_changes = true


func _restore_from_snapshot(snapshot: Dictionary) -> void:
	var index: int = size()
	var id: int = snapshot.id
	project_data.files_id.append(id)
	project_data.files_path.append(snapshot.path)
	project_data.files_nickname.append(snapshot.nickname)
	project_data.files_proxy_path.append(snapshot.proxy_path)
	project_data.files_folder.append(snapshot.folder)
	project_data.files_type.append(snapshot.type)
	project_data.files_duration.append(snapshot.duration)
	project_data.files_modified_time.append(snapshot.modified_time)
	project_data.files_clip_only_video_ids.append(snapshot.clip_only_video_ids)

	# Restore sparse data
	if snapshot.temp_file != null: project_data.files_temp_file[id] = snapshot.temp_file
	if snapshot.ato_active != null: project_data.files_ato_active[id] = snapshot.ato_active
	if snapshot.ato_offset != null: project_data.files_ato_offset[id] = snapshot.ato_offset
	if snapshot.ato_id != null: project_data.files_ato_id[id] = snapshot.ato_id

	_id_map[id] = index
	load_data(index)
	added.emit(id)


func move(ids: PackedInt64Array, target: String) -> void:
	InputManager.undo_redo.create_action("Move file(s)")
	for id: int in ids:
		var index: int = get_index(id)
		var folder: String = get_folder(index)
		InputManager.undo_redo.add_do_method(_move.bind(id, target))
		InputManager.undo_redo.add_undo_method(_move.bind(id, folder))
	InputManager.undo_redo.add_do_method(_rebuild_map)
	InputManager.undo_redo.add_undo_method(_rebuild_map)
	InputManager.undo_redo.commit_action()


func _move(id: int, target: String) -> void:
	var index: int = get_index(id)
	project_data.files_folder[index] = target
	moved.emit(id)
	Project.unsaved_changes = true


func change_nickname(index: int, new_name: String) -> void:
	var id: int = get_id(index)
	var old_name: String = get_nickname(index)

	InputManager.undo_redo.create_action("Change file nickname")
	InputManager.undo_redo.add_do_method(_change_nickname.bind(id, new_name))
	InputManager.undo_redo.add_undo_method(_change_nickname.bind(id, old_name))
	InputManager.undo_redo.commit_action()


func _change_nickname(id: int, new_name: String) -> void:
	var index: int = get_index(id)
	project_data.files_nickname[index] = new_name
	nickname_changed.emit(id)
	Project.unsaved_changes = true


# --- File dropping ---

## File dropping can't be un-done with the undo_redo system!
func dropped(dropped_file_paths: PackedStringArray) -> void:
	var paths: PackedStringArray = []
	for path: String in Utils.find_subfolder_files(dropped_file_paths):
		if path not in get_paths(): paths.append(path) # Duplicate check.
	if paths.size() == 0: return # Early return check

	var progress: ProgressOverlay = PopupManager.get_popup(PopupManager.POPUP.PROGRESS)
	var progress_increment: float = (1 / float(paths.size())) * 50
	progress.set_state_file_loading(paths.size())
	progress.update_title(tr("Files dropped"))
	progress.update_progress(0, "")

	var error_occured: bool = false
	var indexes: PackedInt64Array = []
	for path: String in paths:
		var index: int = _add(path)
		if index != -1:
			indexes.append(index)
			progress.update_file(path, 0)
		else:
			progress.update_file(path, -1)
			error_occured = true
	progress.update_progress(10, tr("Files loading ..."))

	while indexes.size() != 0: # Looping till all files are loaded
		await RenderingServer.frame_post_draw
		for index: int in indexes:
			if file_data[index] != null:
				progress.update_file(get_path(index), 1)
				progress.increment_progress_bar(progress_increment)
				indexes.remove_at(indexes.find(index))

	Project.unsaved_changes = true
	await RenderingServer.frame_post_draw

	if !error_occured:
		PopupManager.close_popup(PopupManager.POPUP.PROGRESS)
	else: progress.show_close()


# --- Data loading ---

## (Re)load the data of a file.
func load_data(index: int) -> void:
	if index == -1: # Should normally not happen
		return printerr("FileLogic: Can't init data as file %s is null!")

	var id: int = get_id(index)
	var path: String = get_path(index)
	var type: TYPE = get_type(index)

	# Create new slot if new file, else copy over existing slot.
	if file_data.size() -1 != index: file_data.append(null)
	else: file_data[id] = null

	if path.begins_with("temp://"): # TODO: Add text
		var temp_file: TempFile = TempFile.new()
		if path == "temp://color":
			temp_file.load_image_from_color()
			file_data[index] = temp_file.image_data
		elif path == "temp://image":
			file_data[index] = temp_file.image_data
		project_data.files_temp_file[id] = temp_file
	elif type == FileLogic.TYPE.IMAGE:
		file_data[index] = ImageTexture.create_from_image(Image.load_from_file(path))
	elif type in FileLogic.TYPE_VIDEOS:
		Threader.add_task(_load_video.bind(id), video_loaded.emit)
	elif type == FileLogic.TYPE.PCK:
		if !ProjectSettings.load_resource_pack(path):
			printerr("FileData: Something went wrong loading pck data from '%s'!" % path)
			return _delete(path)
		var pck_path: String = PCK.MODULES_PATH + path.get_basename().to_lower()
		pck_instances[id] = load(pck_path).scene.instantiate()

	if type in EditorCore.AUDIO_TYPES:
		if !_load_audio(id) and type == FileLogic.TYPE.VIDEO:
			type = FileLogic.TYPE.VIDEO_ONLY
		else:
			Threader.add_task(_create_wave.bind(path), Callable())


func _load_audio(id: int) -> bool:
	var index: int = get_index(id)
	var path: String = get_path(index)
	var stream: AudioStreamFFmpeg = AudioStreamFFmpeg.new()
	var error: int = stream.open(path)

	if error != OK:
		printerr("FileData: Failed to open audio '%s'! - %s" % [path, error])
		return false # No audio was found, might be invalid codec, so we change type to VIDEO_ONLY
	elif stream.get_length() == 0:
		return false # Video without audio so we change the TYPE to VIDEO_ONLY as well

	file_data[index] = stream
	return true


func _load_video(id: int, clip_id: int = -1) -> void:
	var index: int = get_index(id)
	var path: String = get_path(index)
	var temp_video: GoZenVideo = GoZenVideo.new()

	var path_to_load: String = path
	var proxy_path: String = get_proxy_path(index)

	if Settings.get_use_proxies():
		if !proxy_path.is_empty() and !FileAccess.file_exists(proxy_path):
			path_to_load = proxy_path

	if temp_video.open(path_to_load):
		printerr("FileData: Couldn't open video at path '%s'!" % path)
		return

	Threader.mutex.lock()
	if clip_id != -1: # Clip only video got requested
		clip_video_instances[clip_id] = temp_video
	else:
		file_data[index] = temp_video

	# TODO: Check if this is needed:
	#var placeholder: PlaceholderTexture2D = PlaceholderTexture2D.new()
	#var video_resolution: Vector2i = temp_video.get_resolution()
	#var rotated: bool = abs(temp_video.get_rotation()) == 90
	#placeholder.size.x = video_resolution.y if rotated else video_resolution.x
	#placeholder.size.y = video_resolution.x if rotated else video_resolution.y
	#image = placeholder
	Threader.mutex.unlock()


func _create_wave(id: int) -> void:
	# TODO: Large audio lengths will still crash this function. Could possibly
	# use the get_audio improvements by cutting the data into pieces.
	var index: int = get_index(id)
	var path: String = get_path(index)
	var data: PackedByteArray = GoZenAudio.get_audio_data(path, -1)

	audio_wave[id].clear()
	if data.is_empty(): return push_warning("Audio data is empty!")

	var bytes_size: float = 4 # 16 bit * stereo
	var total_frames: int = int(data.size() / bytes_size)
	var frames_per_block: int = floori(44100.0 / Project.get_framerate())
	var total_blocks: int = ceili(float(total_frames) / frames_per_block)
	var current_frame_index: int = 0

	audio_wave[id].resize(total_blocks)
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
		if audio_wave[id].size() == 0: return

		audio_wave[id][i] = clamp(max_abs_amplitude / MAX_16_BIT_VALUE, 0.0, 1.0)
		current_frame_index = end_frame


func generate_audio_thumb(id: int) -> Image:
	if audio_wave[id].size() <= 0: return null # Up to the file panel to try and fetch later.

	var thumb_size: Vector2i = Vector2i(854, 480)
	var thumb: Image = Image.create_empty(thumb_size.x, thumb_size.y, false, Image.FORMAT_RGB8)

	var data_size: int = audio_wave[id].size()
	var data_per_pixel: float = float(data_size) / thumb_size.x
	var center: int = int(float(thumb_size.y) / 2)
	var amp: int = int(float(thumb_size.y) / 2 * 0.9)

	thumb.fill(Color.DIM_GRAY) # Background color.
	for x_pos: int in thumb_size.x: # Data color.
		var start_index: int = floori(x_pos * data_per_pixel)
		var end_index: int = min(ceili((x_pos + 1) * data_per_pixel), data_size)
		var max_amp: float = 0.0

		if start_index >= end_index: continue # No data/End of data
		for i: int in range(start_index, end_index):
			max_amp = max(max_amp, audio_wave[id][i])

		var half_height: int = floori(max_amp * amp)
		var y_top: int = clamp(center - half_height, 0, thumb_size.y - 1)
		var y_bottom: int = clamp(center + half_height, 0, thumb_size.y - 1)

		for y_pos: int in range(y_top, y_bottom + 1):
			thumb.set_pixel(x_pos, y_pos, Color.GHOST_WHITE)

	# Center line.
	for x_pos: int in thumb_size.x: thumb.set_pixel(x_pos, center, Color.GRAY)
	return thumb


func reload(id: int) -> void:
	load_data(get_index(id))
	reloaded.emit(id)


#-- File creators ---

## Save the image and replace the path in the file data to point to the new image file.
func save_image_to_file(id: int, path: String) -> void:
	const ERROR_MESSAGE: String = "FileHandler: Couldn't save image to %s!\n"
	var index: int = get_index(id)
	var image: Image = get_temp_file(id).image_data.get_image()
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
	project_data.files_temp_file.erase(id)
	load_data(index)
	path_updated.emit(id)


func save_audio_to_wav(id: int, save_path: String) -> void:
	var path: String = get_path(get_index(id))
	var audio_stream: AudioStreamWAV = AudioStreamWAV.new()
	audio_stream.stereo = true
	audio_stream.format = AudioStreamWAV.FORMAT_16_BITS
	audio_stream.mix_rate = 44100
	audio_stream.data = GoZenAudio.get_audio_data(path, -1)

	if audio_stream.save_to_wav(save_path):
		printerr("FileHandler: Error occured when saving to WAV!")


#--- Private functions ---
func _check_if_modified(index: int) -> void:
	var path: String = get_path(index)
	if !path.begins_with("temp://") and !FileAccess.file_exists(path):
		print("FileHandler: File %s at %s doesn't exist anymore!" % [index, path])
		_delete(path)


# --- Getters ---

func size() -> int: return _id_map.size()
func has(id: int) -> bool: return _id_map.has(id)
func has_path(path: String) -> bool: return project_data.files_path.has(path)
func has_temp_file(id: int) -> bool: return project_data.files_temp_file.has(id)
func has_ato(id: int) -> bool: return project_data.files_ato_active.has(id)
func has_audio() -> bool: return project_data.files_type.has(TYPE.AUDIO)

func get_index(id: int) -> int: return _id_map[id]
func get_id(index: int) -> int: return project_data.files_id[index]

func get_path(index: int) -> String: return project_data.files_path[index]
func get_proxy_path(index: int) -> String: return project_data.files_proxy_path[index]
func get_nickname(index: int) -> String: return project_data.files_nickname[index]
func get_folder(index: int) -> String: return project_data.files_folder[index]
func get_type(index: int) -> TYPE: return project_data.files_type[index] as TYPE
func get_duration(index: int) -> int: return project_data.files_duration[index]
func get_modified_time(index: int) -> int: return project_data.files_modified_time[index]

# Only for temporary files so is a dictionary.
func get_temp_file(id: int) -> TempFile: return null if !has_temp_file(id) else project_data.files_temp_file[id]

# Only for files with audio so they are dictionaries.
func get_ato_active(id: int) -> bool: return false if !has_ato(id) else project_data.files_ato_active[id]
func get_ato_offset(id: int) -> float: return 0.0 if !has_ato(id) else project_data.files_ato_offset[id]
func get_ato_id(id: int) -> int: return -1 if !has_ato(id) else project_data.files_ato_id[id]

# - Group getters
func get_ids() -> PackedInt64Array: return project_data.files_id
func get_paths() -> PackedStringArray: return project_data.files_path


func get_all_audio_files() -> PackedInt64Array:
	var data: PackedInt64Array = []
	for i: int in project_data.files_type.size():
		if get_type(i) != TYPE.AUDIO: data.append(get_id(i))
	return data


func get_all_video_files() -> PackedInt64Array:
	var data: PackedInt64Array = []
	for i: int in project_data.files_type.size():
		if get_type(i) in TYPE_VIDEOS: data.append(get_id(i))
	return data


# --- File data getters ---

func get_data(index: int) -> Variant: return file_data[index]
func get_pck_instance(id: int) -> Node: return pck_instances[id]
func get_audio_wave(id: int) -> PackedFloat32Array: return audio_wave[id]


# --- Setters ---

func add_proxy_path(index: int, path: String) -> void: project_data.files_proxy_path[index] = path


# --- Updaters ---

func update_audio_waves() -> void:
	for id: int in get_all_audio_files():
		var index: int = get_index(id)
		if get_type(index) in EditorCore.AUDIO_TYPES: load_data(index)


func reload_videos() -> void:
	for id: int in get_all_video_files():
		var index: int = get_index(id)
		if get_type(index) in TYPE_VIDEOS: load_data(index)


# --- Static ---

## Check if a file is (still) valid or not.
static func check(file_path: String) -> bool:
	if !FileAccess.file_exists(file_path): return false # Probably a temp file.

	var ext: String = file_path.get_extension().to_lower()
	return (
		ext in ProjectSettings.get_setting("extensions/image") or
		ext in ProjectSettings.get_setting("extensions/audio") or
		ext in ProjectSettings.get_setting("extensions/video"))
