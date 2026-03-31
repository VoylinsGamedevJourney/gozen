extends Node


signal added(file: FileData)
signal moved(file: FileData)
signal deleted(file_id: int)
signal reloaded(file: FileData)
signal path_updated(file: FileData)
signal nickname_changed(file: FileData)
signal ato_changed(file: FileData)
signal audio_wave_generated(file: FileData)

signal video_loaded(file: FileData)


const MAX_16_BIT_VALUE: float = 32767.0 ## For the audio 16 bits/2 (stereo)


var files: Dictionary[int, FileData]

# Runtime file data
var file_data: Dictionary[int, Variant] = {} ## Can be Video, AudioStreamFFmpeg, Texture2D, Color, or PCK
var pck_instances: Dictionary[int, Node] = {} ## { file: PKC instance }
var audio_wave: Dictionary[int, PackedFloat32Array] = {} ## { file: wave_data }
var video_pools: Dictionary[int, Array] = {} ## { file: [Video] }
var audio_pools: Dictionary[int, Array] = {} ## { file: [AudioStreamFFmpeg] }

var files_dropping: bool = false

var wave_folder: String = "%s/gozen/waves/" % OS.get_cache_dir()



func _ready() -> void:
	if !DirAccess.dir_exists_absolute(wave_folder):
		DirAccess.make_dir_recursive_absolute(wave_folder)

	Project.get_window().files_dropped.connect(dropped)
	Settings.on_video_cache_size_changed.connect(_update_video_cache_size)
	Settings.on_video_smart_seek_threshold.connect(_update_video_smart_seek_threshold)


## Load everything on startup and give user indication of the progress.
func _startup_loading() -> void:
	for file: FileData in files.values():
		load_data(file)


# --- Handling ---

func add(paths: PackedStringArray) -> void:
	var existing_file_paths: PackedStringArray = []
	for file: FileData in files.values():
		existing_file_paths.append(file.path)

	InputManager.undo_redo.create_action("Add file(s)")
	for path: String in paths:
		if path in existing_file_paths and not path.begins_with("temp://"):
			continue # Duplication check.
		var file: FileData = _create_file(path)
		if file:
			InputManager.undo_redo.add_do_method(_restore.bind(file))
			InputManager.undo_redo.add_undo_method(_delete.bind(file))
	InputManager.undo_redo.commit_action()


func _create_file(path: String) -> FileData:
	var extension: String = path.get_extension().to_lower()
	var file: FileData = FileData.new()
	file.id = Utils.get_unique_id(files.keys())
	file.path = path
	file.nickname = path.get_file()

	if extension in ProjectSettings.get_setting("extensions/image"):
		file.type = EditorCore.TYPE.IMAGE
		file.duration = Settings.get_image_duration()
		file.modified_time = FileAccess.get_modified_time(path)
	elif extension in ProjectSettings.get_setting("extensions/audio"):
		file.type = EditorCore.TYPE.AUDIO
		file.duration = floori(Video.get_duration(path) * Project.data.framerate)
		file.modified_time = FileAccess.get_modified_time(path)
	elif extension in ProjectSettings.get_setting("extensions/video"):
		file.type = EditorCore.TYPE.VIDEO # We check later if the video is audio only.
		file.duration = floori(Video.get_duration(path) * Project.data.framerate)
		file.modified_time = FileAccess.get_modified_time(path)
	elif extension == "pck":
		file.type = EditorCore.TYPE.PCK
	elif !path.contains("temp://"):
		printerr("FileLogic: Invalid file:", path)

	if path.contains("temp://"):
		file.temp_file = TempFile.new()
		var temp_nickname: String = path.trim_prefix("temp://").capitalize()
		var time_dict: Dictionary = Time.get_datetime_dict_from_system()
		if path == "temp://text":
			file.type = EditorCore.TYPE.TEXT
			file.duration = Settings.get_text_duration()
			file.nickname = "Text: Empty text"
			file.temp_file.text_effect = load(Library.EFFECT_TEXT).duplicate(true)
			file.temp_file.text_effect.set_default_keyframe()
		elif path == "temp://image":
			file.type = EditorCore.TYPE.IMAGE
			file.duration = Settings.get_image_duration()
			file.nickname = "Image %04d-%02d-%02d %02d:%02d:%02d" % [
					time_dict.year, time_dict.month, time_dict.day,
					time_dict.hour, time_dict.minute, time_dict.second]
		elif path.begins_with("temp://color"):
			var splits: PackedStringArray = path.split("#")
			file.type = EditorCore.TYPE.COLOR
			file.duration = Settings.get_color_duration()
			file.nickname = temp_nickname.replace("#", " #")
			file.temp_file.color = Color(splits[1])
	return null if file.type == EditorCore.TYPE.EMPTY else file


func delete(ids: PackedInt64Array) -> void:
	InputManager.undo_redo.create_action("Delete file")
	for clip: ClipData in ClipLogic.clips.values():
		if clip.file in ids:
			InputManager.undo_redo.add_do_method(ClipLogic._delete.bind(clip))
			InputManager.undo_redo.add_undo_method(ClipLogic._restore_clip.bind(clip))

	for file_id: int in ids:
		InputManager.undo_redo.add_do_method(_delete.bind(files[file_id]))
		InputManager.undo_redo.add_undo_method(_restore.bind(files[file_id]))
	InputManager.undo_redo.add_do_method(Project.update_timeline_end)
	InputManager.undo_redo.add_undo_method(Project.update_timeline_end)
	InputManager.undo_redo.commit_action()


func _delete(file: FileData) -> void:
	# TODO: We should check if some other file relies on using this one as ATO.
	files.erase(file.id)
	file_data.erase(file.id)

	if video_pools.has(file.id):
		for video: Video in video_pools[file.id]:
			video.close()
		video_pools.erase(file.id)

	audio_pools.erase(file.id)
	audio_wave.erase(file.id)
	Project.unsaved_changes = true
	deleted.emit(file.id)


func _restore(snapshot: FileData) -> void:
	files[snapshot.id] = snapshot
	load_data(snapshot)
	Project.unsaved_changes = true
	added.emit(snapshot)


func move(files_to_move: Array[FileData], target: String) -> void:
	InputManager.undo_redo.create_action("Move file(s)")
	for file: FileData in files_to_move:
		InputManager.undo_redo.add_do_method(_move.bind(file, target))
		InputManager.undo_redo.add_undo_method(_move.bind(file, file.folder))
	InputManager.undo_redo.commit_action()


func _move(file: FileData, target: String) -> void:
	file.folder = target
	Project.unsaved_changes = true
	moved.emit(file)


func change_nickname(file: FileData, new_name: String) -> void:
	InputManager.undo_redo.create_action("Change file nickname")
	InputManager.undo_redo.add_do_method(_change_nickname.bind(file, new_name))
	InputManager.undo_redo.add_undo_method(_change_nickname.bind(file, file.nickname))
	InputManager.undo_redo.commit_action()


func _change_nickname(file: FileData, new_name: String) -> void:
	file.nickname = new_name
	Project.unsaved_changes = true
	nickname_changed.emit(file)


## Pasting from clipboard (through InputManager).
func paste_image(image: Image) -> void:
	InputManager.undo_redo.create_action("Paste Image")
	var file: FileData = FileData.new()
	file.id = Utils.get_unique_id(files.keys())
	file.path = "temp://image"
	file.type = EditorCore.TYPE.IMAGE
	file.duration = Settings.get_image_duration()
	file.temp_file = TempFile.new()

	if image.get_format() != Image.FORMAT_RGBA8:
		image.convert(Image.FORMAT_RGBA8)
	if image.get_size() != Project.data.resolution:
		image.resize(Project.data.resolution.x, Project.data.resolution.y, Image.INTERPOLATE_BILINEAR)
	file.temp_file.image_data = ImageTexture.create_from_image(image)

	var time_dict: Dictionary = Time.get_datetime_dict_from_system()
	file.nickname = "Image %04d-%02d-%02d %02d:%02d:%02d" % [
			time_dict.year, time_dict.month, time_dict.day,
			time_dict.hour, time_dict.minute, time_dict.second]

	InputManager.undo_redo.add_do_method(_restore.bind(file))
	InputManager.undo_redo.add_undo_method(_delete.bind(file))
	InputManager.undo_redo.commit_action()


func apply_audio_take_over(file: FileData, audio_file: FileData, offset: float) -> void:
	var active: bool = audio_file.id != -1
	var affected_clips: Array[ClipData] =[]
	for clip: ClipData in ClipLogic.clips.values():
		if clip.file == file.id:
			affected_clips.append(clip)

	if affected_clips.is_empty():
		_commit_ato(file, active, audio_file.id, offset, false,[])
		return

	var dialog: ConfirmationDialog = PopupManager.create_confirmation_dialog(
		tr("Update existing clips?"),
		tr("This file is currently used by '%d' clip(s).\nDo you want to apply the Audio-Take-Over changes to all existing clips?") % affected_clips.size())
	dialog.get_ok_button().text = tr("Apply to All")
	dialog.get_cancel_button().text = tr("Cancel")
	dialog.add_button(tr("Apply to File Only"), true, "file_only")
	dialog.confirmed.connect(func() -> void:
		_commit_ato(file, active, audio_file.id, offset, true, affected_clips))
	dialog.custom_action.connect(func(action: String) -> void:
		if action == "file_only":
			_commit_ato(file, active, audio_file.id, offset, false,[])
			dialog.hide())
	dialog.popup_centered()


func _commit_ato(file: FileData, active: bool, audio_file_id: int, offset: float, update_clips: bool, clips: Array[ClipData]) -> void:
	var old_active: bool = file.ato_active
	var old_file: int = file.ato_file
	var old_offset: float = file.ato_offset

	InputManager.undo_redo.create_action("Set file audio-take-over")
	InputManager.undo_redo.add_do_method(_apply_audio_take_over.bind(file, active, audio_file_id, offset))
	InputManager.undo_redo.add_undo_method(_apply_audio_take_over.bind(file, old_active, old_file, old_offset))

	if update_clips: # Clips Undo/Redo
		for clip: ClipData in clips:
			var effects: ClipEffects = clip.effects
			InputManager.undo_redo.add_do_method(ClipLogic._apply_audio_take_over.bind(
					clip, active, audio_file_id, offset))
			InputManager.undo_redo.add_undo_method(ClipLogic._apply_audio_take_over.bind(
					clip, effects.ato_active, effects.ato_file, effects.ato_offset))
	InputManager.undo_redo.commit_action()


func _apply_audio_take_over(file: FileData, active: bool, audio_file_id: int, offset: float) -> void:
	file.ato_active = active
	file.ato_file = audio_file_id
	file.ato_offset = offset
	Project.unsaved_changes = true
	ato_changed.emit(file)


func duplicate_text(file: FileData) -> void:
	var new_file: FileData = file.duplicate_deep(Resource.DEEP_DUPLICATE_ALL)
	new_file.id = Utils.get_unique_id(files.keys())

	InputManager.undo_redo.create_action("Duplicate Text File")
	InputManager.undo_redo.add_do_method(_restore.bind(file))
	InputManager.undo_redo.add_undo_method(_delete.bind(new_file))
	InputManager.undo_redo.commit_action()


# --- File dropping ---

## File dropping can't be un-done with the undo_redo system!
func dropped(dropped_file_paths: PackedStringArray) -> void:
	files_dropping = true
	var existing_paths: Array[String] = []
	for file: FileData in files.values():
		existing_paths.append(file.path)

	var paths: PackedStringArray = []
	for path: String in Utils.find_subfolder_files(dropped_file_paths):
		if path not in existing_paths:
			paths.append(path) # Duplicate check.
	if paths.size() == 0:
		files_dropping = false
		return # Early return check

	var progress: ProgressOverlay = PopupManager.get_popup(PopupManager.PROGRESS)
	var progress_increment: float = (1 / float(paths.size())) * 50
	progress.set_state_file_loading(paths.size())
	progress.update_title(tr("Files dropped"))
	progress.update(0, "")

	var error_occured: bool = false
	var dropped_files: Array[FileData] = []
	for path: String in paths:
		var file: FileData = _create_file(path)
		if file:
			_restore(file)
			progress.update_file(path, 0)
			dropped_files.append(file)
		else:
			progress.update_file(path, -1)
			error_occured = true
	progress.update(10, tr("Files loading ..."))

	while !dropped_files.is_empty(): # Looping till all files are loaded.
		await get_tree().process_frame
		for file: FileData in dropped_files:
			if file_data.has(file.id) and file_data[file.id]:
				progress.update_file(file.path, 1)
				progress.increment_bar(progress_increment)
				dropped_files.erase(file)
				break
			elif !file_data.has(file.id) and !Threader.check_tasks(file):
				progress.update_file(file.path, -1)
				dropped_files.erase(file)
				break
	Project.unsaved_changes = true
	await RenderingServer.frame_post_draw
	if !error_occured:
		PopupManager.close(PopupManager.PROGRESS)
	else:
		progress.show_close()


func set_nickname(file: FileData, new_nickname: String) -> void:
	InputManager.undo_redo.create_action("Renaming file")
	InputManager.undo_redo.add_do_method(_set_nickname.bind(file, new_nickname))
	InputManager.undo_redo.add_undo_method(_set_nickname.bind(file, file.nickname))
	InputManager.undo_redo.commit_action()


func _set_nickname(file: FileData, nickname: String) -> void:
	file.nickname = nickname
	Project.unsaved_changes = true
	nickname_changed.emit(file)


# --- Data loading ---

## (Re)load the data of a file.
func load_data(file: FileData) -> void:
	if not file.path.begins_with("temp://") and not FileAccess.file_exists(file.path):
		# File not available anymore. TODO: Handle this in a better way.
		file_data[file.id] = null
		return

	if file.path.begins_with("temp://"):
		if !file.temp_file:
			file.temp_file = TempFile.new()
		var temp_file: TempFile = file.temp_file

		if file.path == "temp://text":
			if temp_file.text_effect.keyframes.is_empty():
				temp_file.text_effect.set_default_keyframe()
			file_data[file.id] = temp_file
		elif file.path == "temp://image":
			file_data[file.id] = temp_file.image_data
		elif file.path.begins_with("temp://color"):
			temp_file.load_image_from_color()
			file_data[file.id] = temp_file.image_data
		return

	match file.type:
		EditorCore.TYPE.IMAGE:
			var image: Image = Image.load_from_file(file.path)
			if image.get_format() != Image.FORMAT_RGBA8:
				image.convert(Image.FORMAT_RGBA8)
			if image.get_size() != Project.data.resolution:
				image.resize(Project.data.resolution.x, Project.data.resolution.y, Image.INTERPOLATE_BILINEAR)
			file_data[file.id] = ImageTexture.create_from_image(image)
		EditorCore.TYPE.VIDEO:
			Threader.add_task(_load_video.bind(file), video_loaded.emit.bind(file))
		EditorCore.TYPE.AUDIO:
			if audio_pools.has(file.id):
				for stream: AudioStream in audio_pools[file.id]:
					stream.free()
				audio_pools[file.id] = []

			var stream: AudioStreamFFmpeg = AudioStreamFFmpeg.new()
			if stream.open(file.path) == OK and stream.get_length() != 0:
				file_data[file.id] = stream
				Threader.add_task(_create_wave.bind(file), _on_wave_ready.bind(file))
			else:
				printerr("FileLogic: Couldn't open audio stream!")
				file_data[file.id] = AudioStreamWAV.new()
		EditorCore.TYPE.PCK:
			if !ProjectSettings.load_resource_pack(file.path):
				printerr("FileData: Something went wrong loading pck data from '%s'!" % file.path)
				return _delete(file)


func _load_video(file: FileData) -> void:
	var temp_video: Video = Video.new()
	var path_to_load: String = file.path

	if Settings.get_use_proxies() and !file.proxy_path.is_empty():
		if FileAccess.file_exists(file.proxy_path):
			temp_video.open(file.proxy_path)
	if !temp_video.is_open() and temp_video.open(path_to_load) != OK:
		return printerr("FileData: Couldn't open video at path '%s'!" % file.path)

	temp_video.set_smart_seek_threshold(Settings.get_video_smart_seek_threshold())
	temp_video.set_cache_size(Settings.get_video_cache_size())
	file_data[file.id] = temp_video
	if video_pools.has(file.id):
		for video: Video in video_pools[file.id]:
			video.close()
		video_pools[file.id] = []
	Threader.add_task(_create_wave.bind(file), _on_wave_ready.bind(file))


func _create_wave(file: FileData) -> void:
	# TODO: Large audio lengths will still crash this function. Could possibly
	# use the get_audio improvements by cutting the data into pieces.
	# TODO: We should check if the amplification
	var cache_path: String = wave_folder + file.path.md5_text() + "_" + str(file.modified_time) + ".wave"
	if FileAccess.file_exists(cache_path):
		var temp_file: FileAccess = FileAccess.open(cache_path, FileAccess.READ)
		if temp_file:
			var size: int = temp_file.get_length()
			if size > 0 and size % 4 == 0:
				audio_wave[file.id] = temp_file.get_buffer(size).to_float32_array()
				call_deferred("_on_wave_ready", file)
				return

	var data: PackedByteArray = Audio.get_audio_data(file.path, -1)
	if data.is_empty():
		audio_wave[file.id] = PackedFloat32Array()
		return push_warning("Audio data is empty!")

	var bytes_size: float = 4 # 16 bit * stereo
	var total_frames: int = int(data.size() / bytes_size)
	var frames_per_block: int = floori(RenderManager.MIX_RATE / Project.data.framerate)
	var total_blocks: int = ceili(float(total_frames) / frames_per_block)
	var current_frame_index: int = 0

	var local_wave: PackedFloat32Array = PackedFloat32Array()
	local_wave.resize(total_blocks)
	audio_wave[file.id] = local_wave
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
		if local_wave.size() == 0:
			return
		local_wave[i] = clamp(max_abs_amplitude / MAX_16_BIT_VALUE, 0.0, 1.0)
		current_frame_index = end_frame

		if i % 150 == 0:
			call_deferred("_on_wave_ready", file) # Wave isn't ready, but yeah. :p

	var save_file: FileAccess = FileAccess.open(cache_path, FileAccess.WRITE)
	if save_file:
		save_file.store_buffer(local_wave.to_byte_array())
	call_deferred("_on_wave_ready", file)


func _on_wave_ready(file: FileData) -> void:
	Settings.on_waveform_update.emit()
	audio_wave_generated.emit(file)


func generate_audio_thumb(file: FileData) -> Image:
	var wave_data: PackedFloat32Array = audio_wave.get(file.id, [])
	if !wave_data or wave_data.size() <= 0:
		return null # Up to the file panel to try and fetch later.

	var thumb_size: Vector2i = Vector2i(854, 480)
	var thumb: Image = Image.create_empty(thumb_size.x, thumb_size.y, false, Image.FORMAT_RGB8)

	var data_size: int = wave_data.size()
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
			max_amp = max(max_amp, wave_data[i])

		var half_height: int = floori(max_amp * amp)
		var y_top: int = clamp(center - half_height, 0, thumb_size.y - 1)
		var y_bottom: int = clamp(center + half_height, 0, thumb_size.y - 1)

		for y_pos: int in range(y_top, y_bottom + 1):
			thumb.set_pixel(x_pos, y_pos, Color.GHOST_WHITE)

	# Center line.
	for x_pos: int in thumb_size.x:
		thumb.set_pixel(x_pos, center, Color.GRAY)
	return thumb


func reload(file: FileData) -> void:
	load_data(file)
	reloaded.emit(file)


func get_video_reader(file: FileData, instance_index: int) -> Video:
	if instance_index == 0:
		return file_data[file.id]

	if not video_pools.has(file.id):
		video_pools[file.id] = []

	var pool: Array = video_pools[file.id]
	var pool_index: int = instance_index - 1
	if pool_index < pool.size():
		var video: Video = pool[pool_index]
		return video

	# No instance found so we create a new one.
	var new_video: Video = Video.new()
	if Settings.get_use_proxies() and !file.proxy_path.is_empty() and FileAccess.file_exists(file.proxy_path):
		if new_video.open(file.proxy_path) != OK:
			printerr("FileLogic: Failed to create pool instance for '%s'!" % file.proxy_path)
			return file_data[file.id] # Return main video as fallback.
	if !new_video.is_open() and new_video.open(file.path) != OK:
			printerr("FileLogic: Failed to create pool instance for '%s'!" % file.path)
			return file_data[file.id] # Return main video as fallback.

	new_video.set_smart_seek_threshold(Settings.get_video_smart_seek_threshold())
	new_video.set_cache_size(Settings.get_video_cache_size())
	pool.append(new_video)
	return new_video


func get_audio_stream(file: FileData, instance_index: int) -> AudioStreamFFmpeg:
	if file.type == EditorCore.TYPE.VIDEO:
		var empty_wave: bool = audio_wave.has(file.id) and audio_wave[file.id].is_empty()
		if empty_wave:
			return null
		var video: Video = get_video_reader(file, instance_index)
		return null if video == null else video.get_audio()
	elif instance_index == 0:
		return file_data[file.id]
	elif not audio_pools.has(file.id):
		audio_pools[file.id] = []

	var pool: Array = audio_pools[file.id]
	var pool_index: int = instance_index - 1
	if pool_index < pool.size():
		var stream: AudioStream = pool[pool_index]
		return stream

	var new_stream: AudioStreamFFmpeg = AudioStreamFFmpeg.new()
	if new_stream.open(file.path) != OK:
		printerr("FileLogic: Failed to create audio pool instance for '%s'!" % file.path)
		return file_data[file.id] # Return main audio as fallback.
	pool.append(new_stream)
	return new_stream


#-- File creators ---

## Save the image (from temp_file) and replace the path in the file data to point to the new image file.
func save_image_to_file(file: FileData, path: String) -> void:
	const ERROR_MESSAGE: String = "FileLogic: Couldn't save image to %s!\n"
	var image: Image = file.temp_file.image_data.get_image()

	match path.get_extension().to_lower():
		"png":
			if image.save_png(path):
				return printerr(ERROR_MESSAGE % "png", get_stack())
		"webp":
			if image.save_webp(path, false, 1.0):
				return printerr(ERROR_MESSAGE % "webp", get_stack())
		_: # JPG is default.
			if image.save_jpg(path, 1.0):
				return printerr(ERROR_MESSAGE % "jpg", get_stack())
	file.path = path
	file.temp_file = null
	load_data(file)
	Project.unsaved_changes = true
	path_updated.emit(file)


func save_audio_to_wav(file: FileData, save_path: String) -> void:
	var audio_stream: AudioStreamWAV = AudioStreamWAV.new()
	audio_stream.stereo = true
	audio_stream.format = AudioStreamWAV.FORMAT_16_BITS
	audio_stream.mix_rate = int(RenderManager.MIX_RATE)
	audio_stream.data = Audio.get_audio_data(file.path, -1)
	if audio_stream.save_to_wav(save_path):
		printerr("FileLogic: Error occured when saving to WAV!")


#--- Private functions ---

func _check_if_modified(file: FileData) -> void:
	if !file.path.begins_with("temp://") and !FileAccess.file_exists(file.path):
		print("FileLogic: File %s at %s doesn't exist anymore!" % [file.id, file.path])
		_delete(file)


# --- Getters ---

## Returns all audio file id's.
func get_all_audio_files() -> Array[FileData]:
	var data: Array[FileData] = []
	for file: FileData in files.values():
		if file.type == EditorCore.TYPE.AUDIO:
			data.append(file)
	return data


## Returns all video file id's.
func get_all_video_files() -> Array[FileData]:
	var data: Array[FileData] = []
	for file: FileData in files.values():
		if file.type == EditorCore.TYPE.VIDEO:
			data.append(file)
	return data


func set_proxy_path(file: FileData, path: String) -> void:
	file.proxy_path = path


func update_text_param(file: FileData, param_id: String, frame_nr: int, new_value: Variant, old_value: Variant, is_new: bool) -> void:
	InputManager.undo_redo.create_action("Update text property")
	InputManager.undo_redo.add_do_method(_set_text_keyframe.bind(file, param_id, frame_nr, new_value))
	if is_new and frame_nr != 0:
		InputManager.undo_redo.add_undo_method(_remove_text_keyframe.bind(file, param_id, frame_nr))
	else:
		InputManager.undo_redo.add_undo_method(_set_text_keyframe.bind(file, param_id, frame_nr, old_value))
	InputManager.undo_redo.commit_action()


func _set_text_keyframe(file: FileData, param_id: String, frame_nr: int, value: Variant) -> void:
	var text_effect: EffectVisual = file.temp_file.text_effect
	if not text_effect.keyframes.has(param_id):
		var typed_dict: Dictionary = {}
		text_effect.keyframes[param_id] = typed_dict
	text_effect.keyframes[param_id][frame_nr] = value
	text_effect._cache_dirty = true

	if param_id == "text_data" and frame_nr == 0:
		var text_str: String = str(value).strip_edges().replace("\n", " ")
		if text_str == "":
			text_str = "Text: Empty text"

		if file.nickname != text_str:
			file.nickname = "Text: " + text_str
			Project.unsaved_changes = true
			ClipLogic.updated.emit()
			nickname_changed.emit(file)
	EffectsHandler.effect_values_updated.emit()


func remove_text_keyframe(file: FileData, param_id: String, frame_nr: int) -> void:
	var text_effect: EffectVisual = file.temp_file.text_effect
	var param_keyframes: Dictionary = text_effect.keyframes[param_id]
	if not text_effect.keyframes.has(param_id) or not param_keyframes.has(frame_nr):
		return
	var old_value: Variant = text_effect.keyframes[param_id][frame_nr]

	InputManager.undo_redo.create_action("Remove text keyframe")
	InputManager.undo_redo.add_do_method(_remove_text_keyframe.bind(file, param_id, frame_nr))
	InputManager.undo_redo.add_undo_method(_set_text_keyframe.bind(file, param_id, frame_nr, old_value))
	InputManager.undo_redo.commit_action()


func _remove_text_keyframe(file: FileData, param_id: String, frame_nr: int) -> void:
	var temp_file: TempFile = file.temp_file
	var text_effect: EffectVisual = temp_file.text_effect
	var param_keyframes: Dictionary = text_effect.keyframes[param_id]
	param_keyframes.erase(frame_nr)
	text_effect._cache_dirty = true
	Project.unsaved_changes = true
	ClipLogic.updated.emit()
	EffectsHandler.effect_values_updated.emit()


func toggle_ato(file: FileData) -> void:
	if file.ato_active:
		InputManager.undo_redo.create_action("Disable file audio take over")
	else:
		InputManager.undo_redo.create_action("Enable file audio take over")
	InputManager.undo_redo.add_do_method(_toggle_ato.bind(file, !file.ato_active))
	InputManager.undo_redo.add_undo_method(_toggle_ato.bind(file, file.ato_active))
	InputManager.undo_redo.commit_action()


func _toggle_ato(file: FileData, value: bool) -> void:
	file.ato_active = value
	Project.unsaved_changes = true


# --- Updaters ---

func update_audio_waves() -> void:
	for file: FileData in get_all_audio_files():
		load_data(file)


func reload_videos() -> void:
	for file: FileData in get_all_video_files():
		load_data(file)


func _update_video_cache_size(value: int) -> void:
	for file: FileData in get_all_video_files():
		if file_data[file.id] is not Video:
			continue
		var video: Video = file_data[file.id]
		video.set_cache_size(value)
		if video_pools.has(file):
			for video_instance: Video in video_pools[file.id]:
				video_instance.set_cache_size(value)


func _update_video_smart_seek_threshold(value: int) -> void:
	for file: FileData in get_all_video_files():
		if file_data[file.id] is not Video:
			continue
		var video: Video = file_data[file.id]
		video.set_smart_seek_threshold(value)
		if video_pools.has(file):
			for video_instance: Video in video_pools[file.id]:
				video_instance.set_smart_seek_threshold(value)


## Check if a file is (still) valid or not.
func check(file_path: String) -> bool:
	if !FileAccess.file_exists(file_path):
		return false # Probably a temp file.

	var ext: String = file_path.get_extension().to_lower()
	return (
		ext in ProjectSettings.get_setting("extensions/image") or
		ext in ProjectSettings.get_setting("extensions/audio") or
		ext in ProjectSettings.get_setting("extensions/video"))
