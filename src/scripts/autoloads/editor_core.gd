extends Node

signal frame_changed
signal play_changed(value: bool)


## File/Clip types.
enum TYPE { EMPTY = -1, IMAGE, AUDIO, VIDEO, TEXT, COLOR, PCK }


const AUDIO_TYPES: PackedInt64Array = [ TYPE.AUDIO, TYPE.VIDEO ]
const VISUAL_TYPES: PackedInt64Array = [ TYPE.IMAGE, TYPE.COLOR, TYPE.TEXT, TYPE.VIDEO ]


var project_data: ProjectData
var project_clips: ClipLogic
var project_files: FileLogic
var project_tracks: TrackLogic

var viewport: SubViewport
var text_viewports: Array[SubViewport]

var view_textures: Array[TextureRect] = []
var audio_players: Array[AudioPlayer] = []
var compositors: Array[VisualCompositor] = []
var background: ColorRect

var frame_nr: int = 0: set = set_frame_nr
var prev_frame: int = -1

var is_playing: bool = false: set = set_is_playing
var loaded_clips: Array[int] = [] ## Currently visible clip id's.
var clips_to_update: Array[bool] = []
var clips_instance_index: Array[int] = []

var playback_speed: float = 1.0: set = set_playback_speed
var pitch_shift_effect: AudioEffectPitchShift

var time_elapsed: float = 0.0
var frame_time: float = 0.0 ## Get's set when changing framerate.
var skips: int = 0

var data_ready: bool = true
var data_set_frame: int = 0



func _ready() -> void:
	Project.project_ready.connect(_on_project_ready)
	EffectsHandler.effects_updated.connect(_on_clips_updated)
	EffectsHandler.effect_values_updated.connect(_on_clips_updated)

	# TODO: Find out why FFT_SIZE_4096 and FFT_SIZE_MAX don't work.
	pitch_shift_effect = AudioEffectPitchShift.new()
	pitch_shift_effect.fft_size = AudioEffectPitchShift.FFT_SIZE_2048
	AudioServer.add_bus_effect(0, pitch_shift_effect)

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
	if data_ready and data_set_frame != Engine.get_process_frames():
		update_views()
		return

	if !is_playing:
		return
	skips = 0
	time_elapsed += delta * playback_speed
	if time_elapsed < frame_time:
		return # Check if enough time has passed.

	while time_elapsed >= frame_time:
		time_elapsed -= frame_time
		skips += 1
	frame_nr += skips
	set_frame(frame_nr)


func _on_project_ready() -> void:
	project_data = Project.data
	project_clips = Project.clips
	project_files = Project.files
	project_tracks = Project.tracks
	project_clips.updated.connect(_on_clips_updated)
	project_tracks.updated.connect(_rebuild_structure)
	project_files.reloaded.connect(_on_clips_updated.unbind(1))
	project_files.video_loaded.connect(_on_clips_updated.unbind(1))
	project_files.ato_changed.connect(_on_clips_updated.unbind(1))
	_rebuild_structure()
	set_frame(project_data.playhead)


func _rebuild_structure() -> void:
	var track_size: int = project_data.tracks_is_muted.size()
	viewport.size = project_data.resolution
	background.size = project_data.resolution

	# Loaded clips setup.
	loaded_clips.resize(track_size)
	loaded_clips.fill(-1)
	clips_to_update.resize(track_size)
	clips_to_update.fill(false)
	clips_instance_index.resize(track_size)
	clips_instance_index.fill(-1)

	# Audio setup.
	for player: AudioPlayer in audio_players:
		remove_child(player.player)
	audio_players.resize(track_size) # RefCounted so should be fine. (I hope :p)

	for index: int in track_size:
		audio_players[index] = AudioPlayer.new()
		add_child(audio_players[index].player)

	# Visual setup.
	for texture_rect: TextureRect in view_textures:
		texture_rect.queue_free()
	for text_viewport: SubViewport in text_viewports:
		text_viewport.queue_free()

	view_textures.resize(track_size)
	compositors.resize(track_size)
	text_viewports.resize(track_size)

	for index: int in track_size:
		compositors[index] = VisualCompositor.new()

		# View stuff.
		var texture_rect: TextureRect = TextureRect.new()
		texture_rect.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		texture_rect.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		texture_rect.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
		viewport.add_child(texture_rect)
		viewport.move_child(texture_rect, 1)
		view_textures[index] = texture_rect

		# Text stuff.
		var text_viewport: SubViewport = SubViewport.new()
		var settings: LabelSettings = LabelSettings.new()
		var text_label: Label = Label.new()
		text_label.label_settings = settings
		text_viewport.size = Vector2i(1920, 1080)
		text_viewport.transparent_bg = true
		text_viewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS
		text_viewport.add_child(text_label)
		add_child(text_viewport)
		text_viewports[index] = text_viewport


func _on_closing_editor() -> void:
	for texture_rect: TextureRect in view_textures:
		texture_rect.queue_free()
	for text_viewport: SubViewport in text_viewports:
		text_viewport.queue_free()
	view_textures.clear()
	audio_players.clear()
	viewport.queue_free()
	text_viewports.clear()


func _on_clips_updated() -> void:
	prev_frame = -1
	for i: int in audio_players.size():
		audio_players[i].stop()
	loaded_clips.fill(-1)
	clips_to_update.fill(false)
	clips_instance_index.fill(-1)
	set_frame_nr(frame_nr)


## Update display/audio and continue if within clip bounds.
func _check_clip(track_id: int, new_frame_nr: int) -> bool:
	var clip_id: int = loaded_clips[track_id]
	if clip_id == -1:
		if audio_players[track_id].clip != -1:
			audio_players[track_id].stop()
		return false

	# Check if clip really still exists or not.
	if !project_clips.index_map.has(clip_id):
		loaded_clips[track_id] = -1
		return false

	# Track check.
	var clip_index: int = project_clips.index_map[clip_id]
	if project_data.clips_track[clip_index] != track_id:
		return false
	var start: int = project_data.clips_start[clip_index]
	var end: int = project_data.clips_duration[clip_index] + start
	return new_frame_nr >= start and new_frame_nr < end


# --- Playback logic ---

func on_play_pressed() -> void:
	is_playing = false if frame_nr == project_data.timeline_end else !is_playing
	if !is_playing:
		project_data.playhead = frame_nr


func set_frame_nr(value: int) -> void:
	var end: int = project_data.timeline_end
	if value >= end:
		is_playing = false
		frame_nr = end
		for i: int in audio_players.size():
			audio_players[i].stop()
		return

	var audio_file_counter: Dictionary[int, int] = {}
	frame_nr = value
	for i: int in audio_players.size():
		var clip: int = -1
		if frame_nr != prev_frame + 1: # Reset/update all audio players. (full seek)
			if loaded_clips.size() > i and loaded_clips[i] != -1:
				clip = find_audio(frame_nr, i)
				if clip == -1:
					continue
				var file: int = project_data.clips_file[project_clips.index_map[clip]]
				if audio_file_counter.has(file):
					audio_file_counter[file] += 1
				else:
					audio_file_counter[file] = 1
				audio_players[i].set_audio(clip, audio_file_counter[file])
			continue

		# Next frame.
		clip = project_tracks.get_clip_id_at(i, frame_nr)
		if clip != -1:
			var file: int = project_data.clips_file[project_clips.index_map[clip]]
			if audio_file_counter.has(file):
				audio_file_counter[file] += 1
			else:
				audio_file_counter[file] = 1
			audio_players[i].set_audio(clip, audio_file_counter[file])
		elif audio_players[i].stop_frame == frame_nr:
			audio_players[i].stop()
	prev_frame = frame_nr
	update_frame()


func update_frame() -> void:
	set_frame(frame_nr)


func set_frame(new_frame: int = frame_nr + 1) -> void:
	if frame_nr != new_frame:
		frame_nr = new_frame

	var file_access_counter: Dictionary = {} ## { file: count } (Needed for videos)
	for i: int in loaded_clips.size():
		# Check if current clip is correct.
		if _check_clip(i, frame_nr):
			var clip_index: int = project_clips.index_map[loaded_clips[i]]
			var file: int = project_data.clips_file[clip_index]
			var instance_index: int = file_access_counter.get(file, 0)
			file_access_counter[file] = instance_index + 1
			clips_to_update[i] = true
			clips_instance_index[i] = instance_index
			update_data(i)
			continue

		# Getting the next frame if possible.
		var clip: int = project_tracks.get_clip_id_at(i, frame_nr)
		if clip != -1:
			var clip_index: int = project_clips.index_map[clip]
			var file: int = project_data.clips_file[clip_index]
			var instance_index: int = file_access_counter.get(file, 0)
			loaded_clips[i] = clip
			clips_to_update[i] = true
			clips_instance_index[i] = instance_index
			file_access_counter[file] = instance_index + 1
			update_data(i)
			audio_players[i].set_audio(find_audio(frame_nr, i))
			continue
		# No clip at position.
		loaded_clips[i] = -1
		if view_textures[i].texture != null:
			view_textures[i].texture = null
	if frame_nr == project_data.timeline_end:
		is_playing = false
	frame_changed.emit()
	data_ready = true
	data_set_frame = Engine.get_process_frames()


# --- Audio handling ---

func find_audio(frame: int, track_id: int) -> int:
	var clip_id: int = project_tracks.get_clip_id_at(track_id, frame)
	if clip_id == -1:
		return -1

	var clip_index: int = project_clips.index_map[clip_id]
	var file_id: int = project_data.clips_file[clip_index]
	var file_index: int = project_files.index_map[file_id]
	return clip_id if project_data.files_type[file_index] in AUDIO_TYPES else -1


func update_audio() -> void:
	for player: AudioPlayer in audio_players:
		var clip_id: int = player.clip
		if clip_id == -1:
			continue
		elif !project_clips.index_map.has(clip_id):
			player.stop()
			continue

		var clip_index: int = project_clips.index_map[clip_id]
		var clip_start: int = project_data.clips_start[clip_index]
		var clip_end: int = project_data.clips_duration[clip_index] + clip_start
		player.stop_frame = clip_end
		if frame_nr < clip_start or frame_nr >= clip_end:
			player.stop()


# --- Video stuff ---

func update_data(track_id: int) -> void:
	var clip_index: int = project_clips.index_map[loaded_clips[track_id]]
	var file_index: int = project_files.index_map[project_data.clips_file[clip_index]]
	var file_type: int = project_data.files_type[file_index]
	var raw_data: Variant = project_files.get_data(file_index)

	var start: int = project_data.clips_start[clip_index]
	var begin: int = project_data.clips_begin[clip_index]
	var speed: float = project_data.clips_speed[clip_index]
	var clip_frame: int = frame_nr - start
	var relative_frame: int = int(clip_frame * speed) + begin

	if file_type == TYPE.TEXT:
		var temp_file: TempFile = raw_data
		var text_effect: EffectVisual = temp_file.text_effect

		var text_data: String = text_effect.get_value(text_effect.params[0], relative_frame)
		var text_font: String = text_effect.get_value(text_effect.params[1], relative_frame)
		var text_h_align: int = text_effect.get_value(text_effect.params[2], relative_frame)
		var text_v_align: int = text_effect.get_value(text_effect.params[3], relative_frame)
		var text_size: int = text_effect.get_value(text_effect.params[4], relative_frame)
		var text_color: Color = text_effect.get_value(text_effect.params[5], relative_frame)
		var text_outline_size: int = text_effect.get_value(text_effect.params[6], relative_frame)
		var text_outline_color: Color = text_effect.get_value(text_effect.params[7], relative_frame)
		var text_shadow_size: int = text_effect.get_value(text_effect.params[8], relative_frame)
		var text_shadow_offset: Vector2i = text_effect.get_value(text_effect.params[9], relative_frame)
		var text_shadow_color: Color = text_effect.get_value(text_effect.params[10], relative_frame)

		var font: Font = Settings.fonts.get(text_font, ThemeDB.fallback_font)

		var text_viewport: SubViewport = text_viewports[track_id]
		var text_label: Label = text_viewport.get_child(0) as Label
		var text_label_settings: LabelSettings = text_label.label_settings

		text_label.text = text_data
		text_label.horizontal_alignment = text_h_align as HorizontalAlignment
		text_label.vertical_alignment = text_v_align as VerticalAlignment

		text_label_settings.font = font
		text_label_settings.font_size = text_size
		text_label_settings.font_color = text_color
		text_label_settings.outline_size = text_outline_size
		text_label_settings.outline_color = text_outline_color
		text_label_settings.shadow_size = text_shadow_size
		text_label_settings.shadow_offset = text_shadow_offset
		text_label_settings.shadow_color = text_shadow_color

		text_label.size = project_data.resolution
		text_viewport.size = project_data.resolution
		text_label.label_settings = text_label_settings
	elif file_type == TYPE.PCK:
		# TODO: Add PCK files here
		pass


func update_views() -> void:
	for track_id: int in loaded_clips.size():
		update_view(track_id, clips_to_update[track_id], clips_instance_index[track_id])
		clips_to_update[track_id] = false
	data_ready = false


func update_view(track_id: int, update: bool, instance_index: int) -> void:
	if loaded_clips[track_id] == -1:
		return
	var clip_id: int = loaded_clips[track_id]
	var clip_index: int = project_clips.index_map[clip_id]
	var file_id: int = project_data.clips_file[clip_index]
	var file_index: int = project_files.index_map[file_id]

	var raw_data: Variant = project_files.get_data(file_index)
	if raw_data == null:
		return

	var start: int = project_data.clips_start[clip_index]
	var begin: int = project_data.clips_begin[clip_index]
	var speed: float = project_data.clips_speed[clip_index]
	var clip_frame: int = frame_nr - start
	var relative_frame: int = int(clip_frame * speed) + begin

	var file_type: int = project_data.files_type[file_index]
	var fade_alpha: float = Utils.calculate_fade(clip_frame, clip_index, true)
	var effects: Array[EffectVisual] = project_data.clips_effects[clip_index].video
	project_clips.load_video_frame(loaded_clips[track_id], relative_frame, instance_index)

	if file_type == TYPE.TEXT:
		#var texture_rid: RID = text_viewport.get_texture().get_rid() # TODO: Switch to using the RID directly.
		var image: Image = text_viewports[track_id].get_texture().get_image()
		var image_texture: ImageTexture = ImageTexture.create_from_image(image)
		if update or Vector2i(image_texture.get_size()) != compositors[track_id].resolution:
			RenderingServer.call_on_render_thread(compositors[track_id].initialize_image.bind(image_texture))
		else:
			RenderingServer.call_on_render_thread(compositors[track_id].update_image.bind(image_texture))

		RenderingServer.call_on_render_thread(compositors[track_id].process_image_frame.bind(
				effects, relative_frame, fade_alpha))
		view_textures[track_id].texture = compositors[track_id].display_texture
	elif raw_data is Video:
		var video: Video = project_files.get_video_reader(file_id, instance_index)
		if update:
			RenderingServer.call_on_render_thread(compositors[track_id].initialize_video.bind(video))

		RenderingServer.call_on_render_thread(compositors[track_id].process_video_frame.bind(
				video, effects, relative_frame, fade_alpha))
		view_textures[track_id].texture = compositors[track_id].display_texture
	elif raw_data is Texture2D:
		var image: Texture2D = raw_data
		if update:
			RenderingServer.call_on_render_thread(compositors[track_id].initialize_image.bind(image))

		RenderingServer.call_on_render_thread(compositors[track_id].process_image_frame.bind(
				effects, relative_frame, fade_alpha))
		view_textures[track_id].texture = compositors[track_id].display_texture


# --- Setters ---

func set_is_playing(value: bool) -> void:
	is_playing = value
	for player: AudioPlayer in audio_players:
		player.play(value)
	play_changed.emit(value)


func set_playback_speed(value: float) -> void:
	playback_speed = value
	for player: AudioPlayer in audio_players:
		if player.clip != -1:
			var clip_index: int = project_clips.index_map[player.clip]
			var speed: float = project_data.clips_speed[clip_index]
			player.player.pitch_scale = playback_speed * speed
	pitch_shift_effect.pitch_scale = 1.0 / playback_speed


func set_background_color(color: Color) -> void:
	background.color = color
