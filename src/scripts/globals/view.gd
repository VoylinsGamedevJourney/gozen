extends Node
# Current frame_nr should be gotten from the Playhead class

const VISUAL_TYPES: PackedInt64Array = [ File.TYPE.IMAGE, File.TYPE.VIDEO ]
const AUDIO_TYPES: PackedInt64Array = [ File.TYPE.AUDIO, File.TYPE.VIDEO ]


var main_view: SubViewport
var views: Array[TextureRect] = []

var is_playing: bool = false
var loaded_clips: Array[ClipData] = []

var time_elapsed: float = 0.0
var frame_time: float = 0.0
var skips: int = 0



func _ready() -> void:
	main_view = SubViewport.new()
	main_view.size = Project.resolution
	add_child(main_view)

	frame_time = 1.0 / Project.framerate

	for i: int in 6: # 6 static tracks
		var l_new_view: TextureRect = TextureRect.new()

		l_new_view.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		l_new_view.set_anchors_preset(Control.PRESET_FULL_RECT)
		l_new_view.material = ShaderMaterial.new()
		
		main_view.add_child(l_new_view)
		views.append(l_new_view)
		loaded_clips.append(null)
	
	var l_background: ColorRect = ColorRect.new()
	
	l_background.name = "Background"
	l_background.color = Color.BLACK

	main_view.add_child(l_background)

	


func _process(a_delta: float) -> void:
	if is_playing:
		# Check if enough time has passed for next frame or not
		# move playhead as well
		skips = 0
		time_elapsed += a_delta

		if time_elapsed < frame_time:
			return

		while time_elapsed >= frame_time:
			time_elapsed -= frame_time
			skips += 1

		if skips <= 1:
			_set_frame(Playhead.instance.skip(skips))
			# TODO: We have to adjust the audio playback as well when skipping happens
		else:
			_set_frame()


func _on_play_button_pressed() -> void:
	if Playhead.frame_nr == Project.timeline_end:
		AudioHandler.instance.stop_all_audio()
		return _on_end_reached()

	is_playing = !is_playing

	if is_playing:
		AudioHandler.instance.play_all_audio()
	else:
		AudioHandler.instance.stop_all_audio()


func _on_end_reached() -> void:
	is_playing = false


func _update_frame() -> void:
	_set_frame(Playhead.frame_nr, true)


func _set_frame(a_frame_nr: int = Playhead.instance.step(), a_force_playhead: bool = false) -> void:
	# WARN: We need to take in mind frame skipping! We can skip over the moment
	# that a frame is supposed to appear or start playing!
	for i: int in loaded_clips.size():
		# Check if current clip is correct
		if _check_clip(i, a_frame_nr, a_force_playhead):
			update_view(i, a_frame_nr)
			continue

		# Getting the next frame if possible
		var l_clip_id: int = _get_next_clip(a_frame_nr, i)

		if l_clip_id == -1:
			loaded_clips[i] = null
			AudioHandler.instance.stop_audio(i)
		else:
			loaded_clips[i] = Project.clips[l_clip_id]
			AudioHandler.instance.set_audio(
					i, loaded_clips[i].get_audio(),
					a_frame_nr - loaded_clips[i].start_frame)
		set_view(i)
		update_view(i, a_frame_nr)
	
	if a_force_playhead:
		Playhead.instance.move(a_frame_nr)


func set_view(a_id: int) -> void: # a_id is track id
	var l_material: ShaderMaterial = views[a_id].material

	# Resetting the texture and shader when no clip is set
	if loaded_clips[a_id] == null:
		views[a_id].texture = null
		l_material.shader = null
		return

	# When clip is an image, set the shader which gives access to the effects
	if loaded_clips[a_id].type == File.TYPE.IMAGE:
		var l_file_data: FileData = Project._files_data[loaded_clips[a_id].file_id]

		views[a_id].texture = l_file_data.image
		l_material.shader = preload("res://shaders/rgb.gdshader")

	elif loaded_clips[a_id].type == File.TYPE.VIDEO:
		var l_video: Video = Project._files_data[loaded_clips[a_id].file_id].video[a_id]
		var l_tex: PlaceholderTexture2D = PlaceholderTexture2D.new()

		# Set the correct shader for the video file
		if l_video.is_full_color_range():
			l_material.shader = preload("res://shaders/yuv420p_full.gdshader")
		else:
			l_material.shader = preload("res://shaders/yuv420p_standard.gdshader")

		# Set resolution
		l_tex.size = l_video.get_resolution()
		views[a_id].texture = l_tex

		l_material.set_shader_parameter("resolution", l_video.get_resolution())

		# Set color profile
		match l_video.get_color_profile():
			"bt601", "bt470":
				l_material.set_shader_parameter(
						"color_profile", Vector4(1.402, 0.344136, 0.714136, 1.772))
			"bt2020", "bt2100":
				l_material.set_shader_parameter(
						"color_profile", Vector4(1.4746, 0.16455, 0.57135, 1.8814))
			_: # bt709 and unknown
				l_material.set_shader_parameter(
						"color_profile", Vector4(1.5748, 0.1873, 0.4681, 1.8556))


func update_view(a_id: int, a_frame_nr: int) -> void:
	# Setting all effects and settings to clips
	var l_material: ShaderMaterial = views[a_id].material

	if loaded_clips[a_id] == null or loaded_clips[a_id].type not in VISUAL_TYPES:
		return

	if loaded_clips[a_id].type == File.TYPE.IMAGE:
		# Set effects
		pass
	elif loaded_clips[a_id].type == File.TYPE.VIDEO:
		var l_data: FileData = Project._files_data[loaded_clips[a_id].file_id]
		var l_video: Video = l_data.video[a_id]
		var l_res: Vector2i = l_data.resolution
		var l_uv_res: Vector2i = l_data.uv_resolution
		var l_padding: int = l_data.padding

		# Get correct frame from video
		loaded_clips[a_id].load_video_frame(a_id, a_frame_nr)

		# Take Y U V data and create ImageTexture to send to shader
		l_material.set_shader_parameter("y_data", ImageTexture.create_from_image(
				Image.create_from_data(l_res.x + l_padding, l_res.y, false, Image.FORMAT_R8, l_video.get_y_data())))
		l_material.set_shader_parameter("u_data", ImageTexture.create_from_image(
				Image.create_from_data(l_uv_res.x, l_uv_res.y, false, Image.FORMAT_R8, l_video.get_u_data())))
		l_material.set_shader_parameter("v_data", ImageTexture.create_from_image(
				Image.create_from_data(l_uv_res.x, l_uv_res.y, false, Image.FORMAT_R8, l_video.get_v_data())))


## Update display/audio and continue if within clip bounds.
func _check_clip(a_id: int, a_frame_nr: int, a_set_audio: bool) -> bool:
	if loaded_clips[a_id] == null:
		return false

	# Check if clip really still exists or not.
	if !Project.clips.has(loaded_clips[a_id].id):
		loaded_clips[a_id] = null
		return false


	if loaded_clips[a_id].start_frame > a_frame_nr:
		return false

	if a_frame_nr > loaded_clips[a_id].start_frame + loaded_clips[a_id].duration:
		return false

	# Setting the audio to the correct position
	if a_set_audio:
		AudioHandler.instance.set_audio(
			a_id, loaded_clips[a_id].get_audio(), a_frame_nr - loaded_clips[a_id].start_frame)

	return true


func _get_next_clip(a_frame_nr: int, a_track: int) -> int:
	var l_clip_id: int = -1

	# Looking for the correct clip
	for l_frame: int in Project.tracks[a_track].keys():
		if l_frame <= a_frame_nr:
			l_clip_id = Project.tracks[a_track][l_frame]
		else:
			break

	if _check_clip_end(a_frame_nr, l_clip_id):
		return l_clip_id

	return -1

 
func _check_clip_end(a_frame_nr: int, a_clip_id: int) -> bool:
	var l_clip: ClipData = Project.clips.get(a_clip_id)

	return false if !l_clip else a_frame_nr < l_clip.start_frame + l_clip.duration

