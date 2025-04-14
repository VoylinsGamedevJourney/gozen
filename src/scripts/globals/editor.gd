extends Node


signal frame_changed(nr: int)
signal play_changed(value: bool)


enum SHADER_ID { EMPTY, YUV, YUV_FULL, IMAGE }

const VISUAL_TYPES: PackedInt64Array = [ File.TYPE.IMAGE, File.TYPE.VIDEO ]
const AUDIO_TYPES: PackedInt64Array = [ File.TYPE.AUDIO, File.TYPE.VIDEO ]


var viewport: SubViewport
var view_textures: Array[TextureRect] = []
var audio_players: Array[AudioPlayer] = []

var frame_nr: int = 0: set = _set_frame_nr
var prev_frame: int = -1

var is_playing: bool = false: set = _set_is_playing
var loaded_clips: Array[ClipData] = []
var loaded_shaders: Array[SHADER_ID] = []

var default_effects_video: EffectsVideo = EffectsVideo.new()
var color_correction_default: Array[bool] = [] # is true if default colors are loaded.

var y_textures: Array[ImageTexture] = []
var u_textures: Array[ImageTexture] = []
var v_textures: Array[ImageTexture] = []

var time_elapsed: float = 0.0
var frame_time: float = 0.0  # Get's set when changing framerate
var skips: int = 0



func _ready() -> void:
	Toolbox.connect_func(Project.project_ready, _setup_playback)
	Toolbox.connect_func(Project.project_ready, _setup_audio_players)
	Toolbox.connect_func(Project.project_ready, set_frame.bind(frame_nr))


func _process(delta: float) -> void:
	if !is_playing:
		return

	skips = 0
	time_elapsed += delta

	# Check if enough time has passed for next frame or not.
	if time_elapsed < frame_time:
		return

	while time_elapsed >= frame_time:
		time_elapsed -= frame_time
		skips += 1

	frame_nr += skips
	set_frame(frame_nr)


func on_play_pressed() -> void:
	is_playing = false if frame_nr == Project.get_timeline_end() else !is_playing


func _set_frame_nr(value: int) -> void:
	if value >= Project.get_timeline_end():
		is_playing = false
		frame_nr = Project.get_timeline_end()

		for i: int in audio_players.size():
			audio_players[i].stop()

		return

	frame_nr = value
	if frame_nr == prev_frame + 1:
		for i: int in audio_players.size():
			var track_data: Dictionary[int, int] = Project.get_track_data(i)

			if track_data.keys().has(frame_nr):
				audio_players[i].set_audio(track_data[frame_nr])
			elif audio_players[i].stop_frame == frame_nr:
				audio_players[i].stop()
		return
	
	# Reset/update all audio players
	for i: int in audio_players.size():
		if loaded_clips[i] != null:
			audio_players[i].set_audio(find_audio(frame_nr, i))
	
	prev_frame = frame_nr
		

func _set_is_playing(value: bool) -> void:
	is_playing = value

	for player: AudioPlayer in audio_players:
		player.play(value)

	play_changed.emit(value)


func set_frame(new_frame: int = frame_nr + 1) -> void:
	# TODO: Implement frame skipping
	if frame_nr != new_frame:
		frame_nr = new_frame

	for i: int in loaded_clips.size():
		# Check if current clip is correct
		if _check_clip(i, frame_nr):
			update_view(i)
			continue

		# Getting the next frame if possible
		var clip_id: int = _get_next_clip(frame_nr, i)

		if clip_id == -1:
			loaded_clips[i] = null

			if view_textures[i].texture != null:
				view_textures[i].texture = null
				(view_textures[i].get_material() as ShaderMaterial).shader = null
				loaded_shaders[i] = SHADER_ID.EMPTY
			continue
		else:
			loaded_clips[i] = Project.get_clip(clip_id)

		update_view(i)
	
	if frame_nr == Project.get_timeline_end():
		is_playing = false

	frame_changed.emit(frame_nr)


func _get_next_clip(new_frame_nr: int, track: int) -> int:
	var clip_id: int = -1

	if Project.get_track_keys(track).size() == 0:
		return -1

	# Looking for the correct clip
	for frame: int in Project.get_track_keys(track):
		if frame <= new_frame_nr:
			clip_id = Project.get_track_data(track)[frame]
		else:
			break

	if clip_id != -1 and _check_clip_end(new_frame_nr, clip_id):
		return clip_id

	return -1


func _check_clip_end(new_frame_nr: int, id: int) -> bool:
	var clip: ClipData = Project.get_clip(id)

	return false if !clip else new_frame_nr < clip.start_frame + clip.duration


# Audio stuff  ----------------------------------------------------------------
func _setup_audio_players() -> void:
	audio_players = []

	for i: int in 6:
		audio_players.append(AudioPlayer.new())
		add_child(audio_players[i].player)


func find_audio(frame: int, track: int) -> int:
	var pos: PackedInt64Array = Project.get_track_keys(track)
	var last: int = -1
	pos.sort()

	for i: int in pos:
		if i <= frame:
			last = i
			continue
		break

	if last == -1:
		return -1

	last = Project.get_track_data(track)[last]
	if frame <= Project.get_clip(last).get_end_frame():
		return last
	else:
		return -1


func get_sample_count(frames: int) -> int:
	return int(44100 * 4 * float(frames) / Project.get_framerate())

	
func render_audio() -> PackedByteArray:
	var audio: PackedByteArray = []

	for i: int in Project.get_track_count():
		var track_audio: PackedByteArray = []
		var track_data: Dictionary[int, int] = Project.get_track_data(i)


		for frame_point: int in Project.get_track_keys(i):
			var clip: ClipData = Project.get_clip(track_data[frame_point])
			var file: File = Project.get_file(clip.file_id)

			if file.type in AUDIO_TYPES:
				var sample_count: int = get_sample_count(clip.start_frame)

				if track_audio.size() != sample_count:
					if track_audio.resize(sample_count):
						Toolbox.print_resize_error()
				
				track_audio.append_array(clip.get_clip_audio_data())

			# Checking if audio is empty or not
			if track_audio.size() == 0:
				continue

		# Making the audio data the correct length
		if track_audio.resize(get_sample_count(Project.get_timeline_end() + 1)):
			Toolbox.print_resize_error()

		if audio.size() == 0:
			audio = track_audio
		elif audio.size() == track_audio.size():
			audio = Audio.combine_data(audio, track_audio)

	# Check for the total audio length
	#print((float(audio.size()) / AudioHandler.bytes_per_frame) / 30)
	print("Rendering audio complete")
	return audio

			
# Video stuff  ----------------------------------------------------------------
func _setup_playback() -> void:
	viewport.size = Project.get_resolution()

	for i: int in Project.get_track_count():
		var texture_rect: TextureRect = TextureRect.new()

		texture_rect.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		texture_rect.expand_mode = TextureRect.EXPAND_IGNORE_SIZE

		view_textures.append(texture_rect)
		loaded_shaders.append(SHADER_ID.EMPTY)

		color_correction_default.append(false)

		texture_rect.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
		texture_rect.material = ShaderMaterial.new()
		y_textures.append(null)
		u_textures.append(null)
		v_textures.append(null)
		
		viewport.add_child(texture_rect)
		viewport.move_child(texture_rect, 1)


func update_view(track_id: int) -> void:
	if loaded_clips[track_id] == null:
		return

	var file_data: FileData = Project.get_file_data(loaded_clips[track_id].file_id)
	var material: ShaderMaterial = view_textures[track_id].get_material()

	view_textures[track_id].texture = loaded_clips[track_id].get_frame(frame_nr)

	# Check if correct shader is applied or not, if not, set correct shader.
	if file_data.video != null:
		if file_data.video.get_is_full_color_range():
			if loaded_shaders[track_id] != SHADER_ID.YUV_FULL:
				material.shader = preload("uid://btyavn64bvbu2")
				loaded_shaders[track_id] = SHADER_ID.YUV_FULL
				_init_video_textures(track_id, file_data.video, material)
		elif loaded_shaders[track_id] != SHADER_ID.YUV:
			material.shader = preload("uid://do37k5eu6tfbc")
			loaded_shaders[track_id] = SHADER_ID.YUV
			_init_video_textures(track_id, file_data.video, material)
		else:
			y_textures[track_id].update(file_data.video.get_y_data())
			u_textures[track_id].update(file_data.video.get_u_data())
			v_textures[track_id].update(file_data.video.get_v_data())

		if material.get_shader_parameter("resolution") != Vector2(file_data.video.get_resolution()):
			material.set_shader_parameter("resolution", file_data.video.get_resolution() as Vector2)
		if material.get_shader_parameter("color_profile") != file_data.color_profile:
			material.set_shader_parameter("color_profile", file_data.color_profile)
	elif file_data.image != null:
		material.shader = preload("uid://vc1lwmduyaub")
		loaded_shaders[track_id] = SHADER_ID.IMAGE

		if material.get_shader_parameter("resolution") != file_data.image.get_size():
			material.set_shader_parameter("resolution", file_data.image.get_size())
	else:
		# Just in case we remove the shader.
		material.shader = null
		loaded_shaders[track_id] = SHADER_ID.EMPTY
		return
	
	var effects_video: EffectsVideo = loaded_clips[track_id].effects_video
	material.set_shader_parameter("alpha", effects_video.alpha)
 
	if effects_video.enable_color_correction:
		effects_video.apply_color_correction(material)
		color_correction_default[track_id] = false
	elif !color_correction_default[track_id]:
		default_effects_video.apply_color_correction(material)
		color_correction_default[track_id] = true

	effects_video.apply_chroma_key(material)
	effects_video.apply_transform(view_textures[track_id])


func _init_video_textures(track_id: int, video_data: Video, material: ShaderMaterial) -> void:
	y_textures[track_id] = ImageTexture.create_from_image(video_data.get_y_data())
	u_textures[track_id] = ImageTexture.create_from_image(video_data.get_u_data())
	v_textures[track_id] = ImageTexture.create_from_image(video_data.get_v_data())
	material.set_shader_parameter("y_data", y_textures[track_id])
	material.set_shader_parameter("u_data", u_textures[track_id])
	material.set_shader_parameter("v_data", v_textures[track_id])


## Update display/audio and continue if within clip bounds.
func _check_clip(id: int, new_frame_nr: int) -> bool:
	if loaded_clips[id] == null:
		return false

	# Check if clip really still exists or not.
	if !Project.get_clips().has(loaded_clips[id].clip_id):
		loaded_clips[id] = null
		return false

	# Track check
	if loaded_clips[id].track_id != id:
		return false

	if loaded_clips[id].start_frame > new_frame_nr:
		return false

	if frame_nr > loaded_clips[id].start_frame + loaded_clips[id].duration:
		return false

	return true


func set_background_color(color: Color) -> void:
	var background: ColorRect = viewport.get_node("Background")

	background.color = color

