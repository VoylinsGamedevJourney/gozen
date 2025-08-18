extends Node


signal frame_changed(nr: int)
signal play_changed(value: bool)


enum SHADER_ID { EMPTY, YUV, YUV_FULL, IMAGE }

const VISUAL_TYPES: PackedInt64Array = [
		File.TYPE.IMAGE, File.TYPE.COLOR, File.TYPE.TEXT, File.TYPE.VIDEO ]
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
var default_effects_audio: EffectsAudio = EffectsAudio.new()
var color_correction_default: Array[bool] = [] # is true if default colors are loaded.

var y_textures: Array[ImageTexture] = []
var u_textures: Array[ImageTexture] = []
var v_textures: Array[ImageTexture] = []

var time_elapsed: float = 0.0
var frame_time: float = 0.0  # Get's set when changing framerate
var skips: int = 0



func _ready() -> void:
	viewport = SubViewport.new()
	viewport.size = Vector2i(1920, 1080)
	viewport.size_2d_override_stretch = true

	var background: ColorRect = ColorRect.new()

	background.color = Color("#000000")
	background.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	viewport.add_child(background)
	add_child(viewport)


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


func _on_closing_editor() -> void:
	viewport.queue_free()

	for tex: TextureRect in view_textures:
		tex.queue_free()
	view_textures.clear()

	for player: AudioPlayer in audio_players:
		player.queue_free()
	audio_players.clear()
	
	loaded_clips.clear()
	default_effects_video.queue_free()
	
	y_textures.clear()
	u_textures.clear()
	v_textures.clear()


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


func update_frame() -> void:
	set_frame(frame_nr)


func set_frame(new_frame: int = frame_nr + 1) -> void:
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

	if !clip:
		print("clip false")
		return false
	else:
		return new_frame_nr <= clip.get_end_frame()


# Audio stuff  ----------------------------------------------------------------
func _setup_audio_players() -> void:
	audio_players = []

	for i: int in 6:
		audio_players.append(AudioPlayer.new())
		add_child(audio_players[i].player)


func find_audio(frame: int, track: int) -> int:
	var pos: PackedInt64Array = Project.get_track_keys(track)
	var last: int = Toolbox.get_previous(frame, pos)

	if last == -1: return -1
	last = Project.get_track_data(track)[last]

	if frame < Project.get_clip(last).get_end_frame():
		return last
	return -1

			
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

	var file_data: FileData = FileManager.get_file_data(loaded_clips[track_id].file_id)
	var material: ShaderMaterial = view_textures[track_id].get_material()
	var updated: bool = false

	view_textures[track_id].texture = loaded_clips[track_id].get_frame(frame_nr)

	# Check if correct shader is applied or not, if not, set correct shader.
	if file_data.video != null:
		var interlaced: int = file_data.video.get_interlaced() 

		if file_data.video.get_full_color_range():
			if loaded_shaders[track_id] != SHADER_ID.YUV_FULL:
				if interlaced != 0:
					material.shader = preload(Library.SHADER_DEINTERLACE_YUV420P_FULL)
					material.set_shader_parameter("interlaced", interlaced)
				else:
					material.shader = preload(Library.SHADER_DEINTERLACE_YUV420P)

				loaded_shaders[track_id] = SHADER_ID.YUV_FULL
				_init_video_textures(track_id, file_data.video, material)
				updated = true
		elif loaded_shaders[track_id] != SHADER_ID.YUV:
			if interlaced != 0:
				material.shader = preload(Library.SHADER_YUV420P_FULL)
				material.set_shader_parameter("interlaced", interlaced)
			else:
				material.shader = preload(Library.SHADER_YUV420P)

			loaded_shaders[track_id] = SHADER_ID.YUV
			_init_video_textures(track_id, file_data.video, material)
			updated = true

		if !updated:
			var video: GoZenVideo

			if file_data.clip_only_video.has(loaded_clips[track_id].clip_id):
				video = file_data.clip_only_video[loaded_clips[track_id].clip_id]
			else:
				video = file_data.video

			y_textures[track_id].update(video.get_y_data())
			u_textures[track_id].update(video.get_u_data())
			v_textures[track_id].update(video.get_v_data())
		material.set_shader_parameter("resolution", file_data.video.get_actual_resolution() as Vector2)
		material.set_shader_parameter("rotation", deg_to_rad(float(file_data.video.get_rotation())))

		material.set_shader_parameter("color_profile", file_data.color_profile)
	elif file_data.image != null:
		material.shader = preload(Library.SHADER_IMAGE)
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

	if effects_video.enable_chroma_key:
		effects_video.apply_chroma_key(material)
	elif effects_video.enable_chroma_key:
		default_effects_video.apply_color_correction(material)

	effects_video.apply_transform(view_textures[track_id], material)


func _init_video_textures(track_id: int, video_data: GoZenVideo, material: ShaderMaterial) -> void:
	y_textures[track_id] = ImageTexture.create_from_image(video_data.get_y_data())
	u_textures[track_id] = ImageTexture.create_from_image(video_data.get_u_data())
	v_textures[track_id] = ImageTexture.create_from_image(video_data.get_v_data())
	material.set_shader_parameter("y_data", y_textures[track_id])
	material.set_shader_parameter("u_data", u_textures[track_id])
	material.set_shader_parameter("v_data", v_textures[track_id])


## Update display/audio and continue if within clip bounds.
func _check_clip(id: int, new_frame_nr: int) -> bool:
	if loaded_clips[id] == null:
		if audio_players[id].clip_id != -1:
			audio_players[id].stop()
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

	if frame_nr > loaded_clips[id].get_end_frame():
		return false

	return true


func set_background_color(color: Color) -> void:
	var background: ColorRect = viewport.get_node("Background")

	background.color = color

