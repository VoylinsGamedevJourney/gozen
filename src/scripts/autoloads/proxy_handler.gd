extends Node
# TODO: We should make it possible to have a UI to see all the proxy clips
# with how much data they use and maybe with when they were last accessed.


signal proxy_loading(file: FileData, progress: int) ## Progess is 0/100.


const PROXY_HEIGHT: int = 540



func _ready() -> void:
	var proxy_path: String = Settings.get_proxies_path()
	if !DirAccess.dir_exists_absolute(proxy_path):
		DirAccess.make_dir_absolute(proxy_path)


func request_generation(file: FileData) -> void:
	var proxy_path: String = Settings.get_proxies_path()
	if file.type != EditorCore.TYPE.VIDEO:
		return # Only proxies for videos possible.
	var new_path: String = proxy_path.path_join(_create_proxy_name(file.path))

	# Check if already exists, if yes, we link.
	if !FileAccess.file_exists(new_path):
		return Threader.add_task(
				_generate_proxy_task.bind(file, new_path),
				_on_proxy_finished.bind(file))

	FileLogic.set_proxy_path(file, new_path)
	if Settings.get_use_proxies():
		FileLogic.reload(file)


func delete_proxy(file: FileData) -> void:
	if !file.proxy_path.is_empty():
		DirAccess.remove_absolute(file.proxy_path)
		FileLogic.set_proxy_path(file, "")


func _generate_proxy_task(file: FileData, output_path: String) -> void:
	var global_output_path: String = ProjectSettings.globalize_path(output_path)
	var global_input_path: String = ProjectSettings.globalize_path(file.path)
	var encoder: Encoder = Encoder.new()
	var video: Video = Video.new()
	if video.open(global_input_path) != OK:
		return printerr("ProxyHandler: Failed to open source!")

	var original_resolution: Vector2i = video.get_resolution()
	var scale: float = float(PROXY_HEIGHT) / float(original_resolution.y)
	var target_resolution: Vector2i = Vector2i(int(original_resolution.x * scale), PROXY_HEIGHT)
	if target_resolution.x % 2 != 0:
		target_resolution.x += 1 # Width needs to be equal

	# Encoder setup
	encoder.set_file_path(global_output_path)
	encoder.set_resolution(target_resolution)
	encoder.set_framerate(video.get_framerate())
	encoder.set_audio_codec_id(Encoder.AUDIO_CODEC.A_NONE) # Only visual is needed
	encoder.set_video_codec_id(Encoder.VIDEO_CODEC.V_H264)
	encoder.set_h264_preset(Encoder.H264_PRESETS.H264_PRESET_ULTRAFAST)
	encoder.set_crf(32)

	if !encoder.open(true):
		printerr("ProxyHandler: Failed to open encoder!")
		return video.close()

	# Encoding
	var total_frames: float = float(video.get_frame_count())
	var loaded_amount: int = 0
	video.seek_frame(0)

	for i: int in video.get_frame_count():
		var image: Image = video.generate_thumbnail_at_current_frame() # RGBA Image
		if image:
			image.resize(target_resolution.x, target_resolution.y, Image.INTERPOLATE_BILINEAR)
			# TODO: encoder.send_frame(image)

		# We skip decoding since generate_thumbnail_at_frame handles that.
		if !video.next_frame(true):
			break
		loaded_amount += 1
		proxy_loading.emit.call_deferred(file, int((loaded_amount / total_frames) * 100.0))

	proxy_loading.emit.call_deferred(file, 100)
	encoder.close()
	video.close()
	FileLogic.set_proxy_path(file, output_path)


func _create_proxy_name(file_path: String) -> String:
	return  "%s_%s_proxy.mp4" % [FileAccess.get_md5(file_path).left(6), file_path.get_file().get_basename()]


func _on_proxy_finished(file: FileData) -> void:
	if Settings.get_use_proxies():
		FileLogic.reload(file)
	FileLogic.nickname_changed.emit(file) # To update the name
