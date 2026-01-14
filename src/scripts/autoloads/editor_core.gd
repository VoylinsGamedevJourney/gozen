extends Node


signal frame_changed
signal play_changed(value: bool)


enum SHADER_ID { EMPTY, YUV_STANDARD, YUV_FULL, IMAGE }

const VISUAL_TYPES: PackedInt64Array = [
		FileHandler.TYPE.IMAGE, FileHandler.TYPE.COLOR, FileHandler.TYPE.TEXT, FileHandler.TYPE.VIDEO ]
const AUDIO_TYPES: PackedInt64Array = [ FileHandler.TYPE.AUDIO, FileHandler.TYPE.VIDEO ]


var viewport: SubViewport
var view_textures: Array[TextureRect] = []
var audio_players: Array[AudioPlayer] = []

var visual_compositors: Array[VisualCompositor] = []

var frame_nr: int = 0: set = set_frame_nr
var prev_frame: int = -1

var is_playing: bool = false: set = _set_is_playing
var loaded_clips: PackedInt64Array = []
var loaded_shaders: Array[SHADER_ID] = []

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

	ClipHandler.clips_updated.connect(_on_clips_updated)


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


func on_play_pressed() -> void:
	is_playing = false if frame_nr == Project.get_timeline_end() else !is_playing

	if !is_playing:
		Project.set_playhead_position(frame_nr)


func set_frame_nr(value: int) -> void:
	if value >= Project.get_timeline_end():
		is_playing = false
		frame_nr = Project.get_timeline_end()

		for i: int in audio_players.size():
			audio_players[i].stop()
		return
	
	frame_nr = value
	if frame_nr == prev_frame + 1:
		for i: int in audio_players.size():
			if TrackHandler.has_frame_nr(i, frame_nr):
				audio_players[i].set_audio(TrackHandler.get_clip_id(i, frame_nr))
			elif audio_players[i].stop_frame == frame_nr:
				audio_players[i].stop()
		return
	
	# Reset/update all audio players
	for i: int in audio_players.size():
		if loaded_clips[i] != -1:
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
			update_view(i, false)
			continue

		# Getting the next frame if possible
		var id: int = _get_next_clip(frame_nr, i)

		if id == -1:
			loaded_clips[i] = -1

			if view_textures[i].texture != null:
				view_textures[i].texture = null
				loaded_shaders[i] = SHADER_ID.EMPTY
			continue
		else:
			loaded_clips[i] = id

		update_view(i, true)
	
	if frame_nr == Project.get_timeline_end():
		is_playing = false

	frame_changed.emit()


func _get_next_clip(new_frame_nr: int, track_id: int) -> int:
	var id: int = -1

	if TrackHandler.get_clips_size(track_id) == 0:
		return -1

	# Looking for the correct clip
	for frame: int in TrackHandler.get_frame_nrs(track_id):
		if frame <= new_frame_nr:
			id = TrackHandler.get_clip_id(track_id, frame)
		else:
			break

	if id != -1 and _check_clip_end(new_frame_nr, id):
		return id

	return -1


func _check_clip_end(new_frame_nr: int, clip_id: int) -> bool:
	if !ClipHandler.has_clip(clip_id):
		return false
	return new_frame_nr <= ClipHandler.get_end_frame(clip_id)
	

func _on_clips_updated() -> void:
	update_audio()
	update_frame()


# Audio stuff  ----------------------------------------------------------------
func setup_audio_players() -> void:
	audio_players = []

	for i: int in 6:
		audio_players.append(AudioPlayer.new())
		add_child(audio_players[i].player)


func find_audio(frame: int, track_id: int) -> int:
	var pos: PackedInt64Array = TrackHandler.get_frame_nrs(track_id)
	var last: int = Utils.get_previous(frame, pos)

	if last == -1:
		return -1

	var clip_data: ClipData = TrackHandler.get_clip_at(track_id, last)

	if clip_data == null:
		printerr("EditorCore: Clip empty at: ", last)
		return -1

	last = clip_data.id

	if frame < ClipHandler.get_end_frame(last):
		return last

	return -1


func update_audio() -> void:
	for player: AudioPlayer in audio_players:
		if player.clip_id != -1:
			if !ClipHandler.has_clip(player.clip_id):
				player.stop()
			else:
				var clip: ClipData = ClipHandler.get_clip(player.clip_id)
				player.stop_frame = clip.end_frame
				
				if frame_nr < clip.start_frame or frame_nr > clip.end_frame:
					player.stop()

			
# Video stuff  ----------------------------------------------------------------
func setup_playback() -> void:
	viewport.size = Project.get_resolution()

	for i: int in Project.data.tracks.size():
		var texture_rect: TextureRect = TextureRect.new()
		var visual_compositor: VisualCompositor = VisualCompositor.new()
		
		texture_rect.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		texture_rect.expand_mode = TextureRect.EXPAND_IGNORE_SIZE

		view_textures.append(texture_rect)
		loaded_shaders.append(SHADER_ID.EMPTY)

		texture_rect.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
		visual_compositors.append(visual_compositor)
		
		viewport.add_child(texture_rect)
		viewport.move_child(texture_rect, 1)


func update_view(track_id: int, update: bool) -> void:
	if loaded_clips[track_id] == -1:
		return

	var file_data: FileData = ClipHandler.get_clip_file_data(loaded_clips[track_id])
	var clip_data: ClipData = ClipHandler.get_clip(loaded_clips[track_id])

	ClipHandler.load_frame(loaded_clips[track_id], frame_nr)

	if file_data.video != null:
		if update:
			visual_compositors[track_id].initialize_video(file_data.video)

		visual_compositors[track_id].process_video_frame(file_data.video, clip_data.effects_video, frame_nr)
		view_textures[track_id].texture = visual_compositors[track_id].display_texture
	elif file_data.image != null:
		if update:
			visual_compositors[track_id].initialize_image(file_data.image)

		visual_compositors[track_id].process_image_frame(clip_data.effects_video, frame_nr)
		view_textures[track_id].texture = visual_compositors[track_id].display_texture


## Update display/audio and continue if within clip bounds.
func _check_clip(track_id: int, new_frame_nr: int) -> bool:
	if loaded_clips[track_id] == -1:
		if audio_players[track_id].clip_id != -1:
			audio_players[track_id].stop()
		return false

	# Check if clip really still exists or not.
	if !ClipHandler.has_clip(loaded_clips[track_id]):
		loaded_clips[track_id] = -1
		return false

	# Track check
	if ClipHandler.get_clip_track_id(loaded_clips[track_id]) != track_id:
		return false
	elif ClipHandler.get_start_frame(loaded_clips[track_id]) > new_frame_nr:
		return false
	elif frame_nr > ClipHandler.get_end_frame(loaded_clips[track_id]):
		return false

	return true


func set_background_color(color: Color) -> void:
	var background: ColorRect = viewport.get_node("Background")

	background.color = color
