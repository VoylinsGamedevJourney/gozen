extends Node
# TODO: We should make it possible to have a UI to see all the proxy clips
# with how much data they use and maybe with when they were last accessed.

const PROXY_PATH: String = "user://proxies/" # TODO: Make this path a setting
const PROXY_HEIGHT: int = 540



func _ready() -> void:
	if !DirAccess.dir_exists_absolute(PROXY_PATH):
		DirAccess.make_dir_absolute(PROXY_PATH)


func request_proxy_generation(file_id: int) -> void:
	var file: File = FileHandler.get_file(file_id)
	var file_name: String
	var new_path: String 

	if file.type not in FileHandler.TYPE_VIDEOS: return # Only proxies for videos possible

	file_name = file.path.get_file().get_basename() + "_proxy.mp4"
	new_path = PROXY_PATH + file_name

	# Check if already exists, if yes, we link
	if FileAccess.file_exists(new_path):
		file.proxy_path = new_path
		return

	Threader.add_task(_generate_proxy_task.bind(file_id, new_path), _on_proxy_finished.bind(file_id))


func _generate_proxy_task(file_id: int, output_path: String) -> void:
	var file: File = FileHandler.get_file(file_id)
	var video: GoZenVideo = GoZenVideo.new()
	var encoder: GoZenEncoder = GoZenEncoder.new()
	output_path = ProjectSettings.globalize_path(output_path)

	if !file:
		printerr("ProxyHandler: Failed to find file!")
		return
	elif video.open(file.path) != OK:
		printerr("ProxyHandler: Failed to open source!")
		return
	
	var original_resolution: Vector2i = video.get_resolution()
	var scale: float = float(PROXY_HEIGHT) / float(original_resolution.y)
	var new_width: int = int(original_resolution.x * scale)
	if new_width % 2 != 0: new_width += 1 # Width needs to be equal

	var target_resolution: Vector2i = Vector2i(new_width, PROXY_HEIGHT)
	
	# Encoder setup
	encoder.set_file_path(output_path)
	encoder.set_resolution(target_resolution)
	encoder.set_framerate(video.get_framerate())
	encoder.set_audio_codec_id(GoZenEncoder.AUDIO_CODEC.A_NONE) # Only visual is needed
	encoder.set_video_codec_id(GoZenEncoder.VIDEO_CODEC.V_H264)
	encoder.set_h264_preset(GoZenEncoder.H264_PRESETS.H264_PRESET_ULTRAFAST)
	encoder.set_crf(32)

	if !encoder.open(false): # false = input is RGB (Image), not RGBA
		printerr("ProxyHandler: Failed to open encoder!")
		return
		
	# Encoding
	# TODO: Maybe show a progress bar on clips to show encoding process.
	video.seek_frame(0)
	
	for i: int in video.get_frame_count():
		var image: Image = video.generate_thumbnail_at_current_frame() # RGBA Image
		
		if image:
			image.resize(target_resolution.x, target_resolution.y, Image.INTERPOLATE_BILINEAR)
			encoder.send_frame(image)
			
		# We skip decoding since generate_thumbnail_at_frame handles that.
		if !video.next_frame(true): break
			 
	encoder.close()
	video.close()
	file.proxy_path = output_path


func _on_proxy_finished(file_id: int) -> void:
	print("ProxyHandler: Proxy generation finished for file ", file_id)

	if Settings.get_use_proxies():
		FileHandler.reload_file_data(file_id) # Switch to proxy directly.

