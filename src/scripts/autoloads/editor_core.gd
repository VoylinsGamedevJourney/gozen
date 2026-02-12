extends Node

signal frame_changed
signal play_changed(value: bool)


## File/Clip types.
enum TYPE { EMPTY = -1, IMAGE, AUDIO, VIDEO, VIDEO_ONLY, TEXT, COLOR, PCK }


const AUDIO_TYPES: PackedInt64Array = [ TYPE.AUDIO, TYPE.VIDEO ]
const VISUAL_TYPES: PackedInt64Array = [
		TYPE.IMAGE, TYPE.COLOR, TYPE.TEXT,
		TYPE.VIDEO, TYPE.VIDEO_ONLY]
const TYPE_VIDEOS: Array[TYPE] = [TYPE.VIDEO, TYPE.VIDEO_ONLY]


var viewport: SubViewport
var view_textures: Array[TextureRect] = []
var audio_players: Array[AudioPlayer] = []
var compositors: Array[VisualCompositor] = []
var background: ColorRect

var frame_nr: int = 0: set = set_frame_nr
var prev_frame: int = -1

var is_playing: bool = false: set = set_is_playing
var loaded_clips: PackedInt64Array = [] ## Currently visible clip id's.

var time_elapsed: float = 0.0
var frame_time: float = 0.0 ## Get's set when changing framerate.
var skips: int = 0


func _ready() -> void:
	Project.project_ready.connect(_on_project_ready)
	EffectsHandler.effects_updated.connect(_on_clips_updated)
	EffectsHandler.effect_values_updated.connect(_on_clips_updated)

	# Preparing viewport.
	viewport = SubViewport.new()
	viewport.size = Vector2i(1920, 1080) # Just a default size, get's changed later.
	viewport.size_2d_override_stretch = true
	background = ColorRect.new()
	background.color = Color("#000000") # Just a default color, get's changed later.
	background.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	viewport.add_child(background)
	add_child(viewport)


func _process(delta: float) -> void:
	if !is_playing:
		return
	skips = 0
	time_elapsed += delta
	if time_elapsed < frame_time:
		return # Check if enough time has passed.

	while time_elapsed >= frame_time:
		time_elapsed -= frame_time
		skips += 1
	frame_nr += skips
	set_frame(frame_nr)


func _on_project_ready() -> void:
	Project.clips.updated.connect(_on_clips_updated)
	Project.tracks.updated.connect(_rebuild_structure)
	Project.files.reloaded.connect(_on_clips_updated.unbind(1))
	_rebuild_structure()
	frame_nr = Project.data.playhead_position


func _rebuild_structure() -> void:
	var track_size: int = Project.data.tracks_is_muted.size()
	# Loaded clips setup.
	loaded_clips.resize(track_size)
	loaded_clips.fill(-1)

	# Audio setup.
	for player: AudioPlayer in audio_players:
		remove_child(player.player)
	audio_players.resize(track_size) # RefCounted so should be fine. (I hope :p)
	for i: int in track_size:
		audio_players.append(AudioPlayer.new())
		add_child(audio_players[i].player)

	# Visual setup.
	for texture_rect: TextureRect in view_textures:
		texture_rect.queue_free()
	view_textures.resize(track_size)
	for i: int in track_size:
		compositors.append(VisualCompositor.new())
		view_textures.append(TextureRect.new())
		view_textures[i].stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		view_textures[i].expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		view_textures[i].set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
		viewport.add_child(view_textures[i])
		viewport.move_child(view_textures[i], 1)
	viewport.size = Project.get_resolution()


func _on_closing_editor() -> void:
	for tex: TextureRect in view_textures:
		tex.queue_free()
	for player: AudioPlayer in audio_players:
		player.free()
	view_textures.clear()
	audio_players.clear()
	viewport.queue_free()


func _on_clips_updated() -> void:
	update_audio()
	update_frame()


## Update display/audio and continue if within clip bounds.
func _check_clip(track_id: int, new_frame_nr: int) -> bool:
	var clip_id: int = loaded_clips[track_id]
	if clip_id == -1:
		if audio_players[track_id].clip_id != -1:
			audio_players[track_id].stop()
		return false

	# Check if clip really still exists or not.
	if !Project.clips.index_map.has(clip_id):
		loaded_clips[track_id] = -1
		return false

	# Track check.
	var clip_index: int = Project.clips.index_map[clip_id]
	if Project.data.clips_track[clip_index] != track_id:
		return false
	var start: int = Project.data.clips_start[clip_index]
	var end: int = Project.data.clips_duration[clip_index] + start
	return new_frame_nr >= start and new_frame_nr < end

# --- Playback logic ---


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
			var id: int = Project.tracks.get_clip_id_at(i, frame_nr)
			if id != -1:
				audio_players[i].set_audio(id)
			elif audio_players[i].stop_frame == frame_nr:
				audio_players[i].stop()
	else: # Reset/update all audio players. (full seek)
		for i: int in audio_players.size():
			if loaded_clips.size() > i and loaded_clips[i] != -1:
				audio_players[i].set_audio(find_audio(frame_nr, i))
	prev_frame = frame_nr


func update_frame() -> void: set_frame(frame_nr)
func set_frame(new_frame: int = frame_nr + 1) -> void:
	if frame_nr != new_frame:
		frame_nr = new_frame
	for i: int in loaded_clips.size():
		# Check if current clip is correct.
		if _check_clip(i, frame_nr):
			update_view(i, false)
			continue

		# Getting the next frame if possible.
		var id: int = Project.tracks.get_clip_id_at(i, frame_nr)
		if id != -1:
			loaded_clips[i] = id
			update_view(i, true)
		else:
			loaded_clips[i] = -1
			if view_textures[i].texture != null:
				view_textures[i].texture = null

	if frame_nr == Project.get_timeline_end():
		is_playing = false
	frame_changed.emit()


# --- Audio handling ---

func find_audio(frame: int, track_id: int) -> int:
	var clip_id: int = Project.tracks.get_clip_id_at(track_id, frame)
	if clip_id == -1:
		return 1

	var clip_index: int = Project.clips.index_map[clip_id]
	var file_id: int = Project.data.clips_file[clip_index]
	var file_index: int = Project.files.index_map[file_id]
	return clip_id if Project.data.files_type[file_index] in AUDIO_TYPES else -1


func update_audio() -> void:
	for player: AudioPlayer in audio_players:
		var clip_id: int = player.clip_id
		if clip_id == -1:
			return
		elif !Project.clips.index_map.has(clip_id):
			return player.stop()

		var clip_index: int = Project.clips.index_map[clip_id]
		var clip_start: int = Project.data.clips_start[clip_index]
		var clip_end: int = Project.data.clips_duration[clip_index] + clip_start

		player.stop_frame = clip_end
		if frame_nr < clip_start or frame_nr >= clip_end:
			player.stop()


# --- Video stuff ---

func update_view(track_id: int, update: bool) -> void:
	if loaded_clips[track_id] == -1:
		return
	var clip_id: int = loaded_clips[track_id]
	var clip_index: int = Project.clips.index_map[clip_id]
	var file_id: int = Project.data.clips_file[clip_index]
	var file_index: int = Project.files.index_map[file_id]

	var raw_data: Variant = Project.files.get_data(file_index)
	if raw_data == null:
		return

	var start: int = Project.data.clips_start[clip_index]
	var begin: int = Project.data.clips_begin[clip_index]
	var relative_frame: int = frame_nr - start + begin
	var clip_frame: int = frame_nr - start

	var fade_alpha: float = Utils.calculate_fade(clip_frame, clip_index, true)
	var effects: Array[GoZenEffectVisual] = Project.data.clips_effects[clip_index].video
	Project.clips.load_frame(loaded_clips[track_id], relative_frame)

	if raw_data is GoZenVideo:
		var video: GoZenVideo = raw_data
		var clip_instance: GoZenVideo = Project.files.get_video_clip_instance(clip_id)
		if clip_instance:
			video = clip_instance

		update = !update and compositors[track_id].resolution != video.get_resolution()
		if update:
			compositors[track_id].initialize_video(video)

		compositors[track_id].process_video_frame(video, effects, relative_frame, fade_alpha)
		view_textures[track_id].texture = compositors[track_id].display_texture
	elif raw_data is Texture2D:
		var image: Texture2D = raw_data
		if update:
			compositors[track_id].initialize_image(image)

		compositors[track_id].process_image_frame(effects, relative_frame, fade_alpha)
		view_textures[track_id].texture = compositors[track_id].display_texture


# --- Setters ---

func set_is_playing(value: bool) -> void:
	is_playing = value
	for player: AudioPlayer in audio_players:
		player.play(value)
	play_changed.emit(value)


func set_background_color(color: Color) -> void:
	background.color = color
