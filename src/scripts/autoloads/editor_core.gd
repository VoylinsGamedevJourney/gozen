extends Node

signal frame_changed
signal visual_frame_changed
signal play_changed(value: bool)


## File/Clip types.
enum TYPE { EMPTY = -1, IMAGE, AUDIO, VIDEO, TEXT, COLOR, PCK }


const AUDIO_TYPES: PackedInt64Array = [ TYPE.AUDIO, TYPE.VIDEO ]
const VISUAL_TYPES: PackedInt64Array = [ TYPE.IMAGE, TYPE.COLOR, TYPE.TEXT, TYPE.VIDEO ]


var viewport: SubViewport
var text_viewports: Array[SubViewport]

var view_textures: Array[TextureRect] = []
var audio_players: Array[AudioPlayer] = []
var compositors: Array[VisualCompositor] = []
var background: ColorRect

var frame_nr: int = 0: set = set_frame_nr
var visual_frame_nr: int = 0
var prev_frame: int = -1

var is_playing: bool = false: set = set_is_playing
var loaded_clips: Array[ClipData] = [] ## Currently visible clips.
var clips_to_update: Array[bool] = []
var clips_instance_index: Array[int] = []

var playback_speed: float = 1.0: set = set_playback_speed
var pitch_shift_effect: AudioEffectPitchShift

var time_elapsed: float = 0.0
var frame_time: float = 0.0 ## Get's set when changing framerate.
var skips: int = 0

var data_ready: bool = true
var data_set_frame: int = 0

var clip_instances: Dictionary = {} ## { clip id: instance index }
var active_tasks: Dictionary = {} ## { video instance id: task_id }

var _scrub_frame: int = -1
var _last_scrub_time: int = 0




func _ready() -> void:
	Project.project_ready.connect(_on_project_ready)
	EffectsHandler.effects_updated.connect(_on_clips_updated)
	EffectsHandler.effect_values_updated.connect(_on_clips_updated)

	ClipLogic.updated.connect(_on_clips_updated)
	TrackLogic.updated.connect(_rebuild_structure)
	FileLogic.reloaded.connect(_on_clips_updated.unbind(1))
	FileLogic.video_loaded.connect(_on_clips_updated.unbind(1))
	FileLogic.ato_changed.connect(_on_clips_updated.unbind(1))

	tree_exiting.connect(_on_closing_editor)

	# TODO: Find out why FFT_SIZE_4096 and FFT_SIZE_MAX don't work.
	pitch_shift_effect = AudioEffectPitchShift.new()
	pitch_shift_effect.fft_size = AudioEffectPitchShift.FFT_SIZE_2048
	AudioServer.add_bus_effect(0, pitch_shift_effect)

	# Preparing viewport.
	viewport = SubViewport.new()
	viewport.size = Vector2i(1920, 1080) # Just a default size, get's changed later.
	viewport.size_2d_override_stretch = true
	viewport.render_target_update_mode = SubViewport.UPDATE_ONCE
	background = ColorRect.new()
	background.color = Color("#000000") # Just a default color, get's changed later.
	background.size = viewport.size
	viewport.add_child(background)

	add_child(viewport)


func _process(delta: float) -> void:
	var completed: Array[int] = []
	for video_id: int in active_tasks:
		if WorkerThreadPool.is_task_completed(active_tasks[video_id] as int):
			WorkerThreadPool.wait_for_task_completion(active_tasks[video_id] as int)
			completed.append(video_id)
	for video_id: int in completed:
		active_tasks.erase(video_id)

	if _scrub_frame != -1:
		if Time.get_ticks_msec() - _last_scrub_time > 50:
			if frame_nr != _scrub_frame:
				set_frame(_scrub_frame)
			_last_scrub_time = Time.get_ticks_msec()
			_scrub_frame = -1

	if data_ready:
		var needs_delay: bool = false
		for clip: ClipData in loaded_clips:
			if clip and clip.type in [TYPE.TEXT, TYPE.PCK]:
				needs_delay = true
				break
		if !needs_delay or data_set_frame != Engine.get_process_frames():
			update_views()

	if is_playing:
		_prefetch_upcoming_clips()
		time_elapsed += delta * playback_speed
		if time_elapsed >= frame_time:
			skips = int(time_elapsed / frame_time)
			time_elapsed -= skips * frame_time
			set_frame(frame_nr + skips)


func _on_project_ready() -> void:
	_rebuild_structure()
	set_frame(Project.data.playhead)


func _rebuild_structure() -> void:
	var track_size: int = TrackLogic.tracks.size()
	background.size = Project.data.resolution
	viewport.size = background.size

	# Loaded clips setup.
	loaded_clips.resize(track_size)
	loaded_clips.fill(null)
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
		texture_rect.size = Project.data.resolution
		viewport.add_child(texture_rect)
		viewport.move_child(texture_rect, 1)
		view_textures[index] = texture_rect

		# Text stuff.
		var text_viewport: SubViewport = SubViewport.new()
		var settings: LabelSettings = LabelSettings.new()
		var text_label: Label = Label.new()
		text_label.label_settings = settings
		text_viewport.size = Project.data.resolution
		text_viewport.transparent_bg = true
		text_viewport.render_target_update_mode = SubViewport.UPDATE_ONCE
		text_label.size = Project.data.resolution
		text_viewport.add_child(text_label)
		add_child(text_viewport)
		text_viewports[index] = text_viewport


func _get_instance_for_clip(clip: ClipData) -> int:
	if clip_instances.has(clip.id):
		return clip_instances[clip.id]

	var file_id: int = clip.file
	var used_indices: Array[int] = []
	for clip_id: int in clip_instances:
		var clip_data: ClipData = ClipLogic.clips.get(clip_id)
		if clip_data and clip_data.file == file_id:
			used_indices.append(clip_instances[clip_id])

	var index: int = 0
	while index in used_indices:
		index += 1

	clip_instances[clip.id] = index
	return index


func _cleanup_unused_instances(current_frame: int) -> void:
	var needed_clips: Array[int] = []
	var look_ahead: int = int(Project.data.framerate * 2.0)

	for track: int in TrackLogic.tracks.size():
		var clip_data: ClipData = TrackLogic.get_clip_at_overlap(track, current_frame)
		if clip_data: needed_clips.append(clip_data.id)

		var next_clips: Array[ClipData] = TrackLogic.get_clips_in_range(track, current_frame, current_frame + look_ahead)
		for next_clip: ClipData in next_clips:
			if next_clip.id not in needed_clips:
				needed_clips.append(next_clip.id)

	var keys: Array = clip_instances.keys()
	for key: int in keys:
		if key not in needed_clips:
			clip_instances.erase(key)


func _prefetch_upcoming_clips() -> void:
	var look_ahead: int = int(Project.data.framerate * 1.3)
	for track: int in TrackLogic.tracks.size():
		var current_clip: ClipData = TrackLogic.get_clip_at_overlap(track, frame_nr)
		var upcoming: Array[ClipData] = TrackLogic.get_clips_in_range(track, frame_nr + 1, frame_nr + look_ahead)
		for upcoming_clip: ClipData in upcoming:
			if upcoming_clip == current_clip or upcoming_clip.type != TYPE.VIDEO:
				continue

			var index: int = _get_instance_for_clip(upcoming_clip)
			var file: FileData = FileLogic.files[upcoming_clip.file]
			var video: Video = FileLogic.get_video_reader(file, index)
			var video_id: int = video.get_instance_id()
			if active_tasks.has(video_id):
				continue

			var target: int = roundi((float(upcoming_clip.begin) / Project.data.framerate) * video.get_framerate())
			target = clampi(target, 0, maxi(0, video.get_frame_count() - 1))
			if video.get_current_frame() != target:
				active_tasks[video_id] = WorkerThreadPool.add_task(video.seek_frame.bind(target))


func _on_closing_editor() -> void:
	view_textures.clear()
	audio_players.clear()
	text_viewports.clear()
	for compositor: VisualCompositor in compositors:
		if compositor != null:
			compositor.cleanup()
	compositors.clear()


func _on_clips_updated() -> void:
	prev_frame = -1
	loaded_clips.fill(null)
	clips_to_update.fill(false)
	clips_instance_index.fill(-1)
	set_frame_nr(frame_nr)


## Update display/audio and continue if within clip bounds.
func _check_clip(track: int, new_frame_nr: int) -> bool:
	var clip: ClipData = loaded_clips[track]
	if !clip:
		if audio_players[track].clip:
			audio_players[track].stop()
		return false
	elif !ClipLogic.clips.has(clip.id): # Check if clip really still exists or not.
		loaded_clips[track] = null
		return false
	elif clip.track != track: # Track check.
		return false
	return Utils.in_range(new_frame_nr, clip.start, clip.end, false)


# --- Playback logic ---

func on_play_pressed() -> void:
	is_playing = false if frame_nr == Project.data.timeline_end else !is_playing
	if !is_playing:
		Project.data.playhead = frame_nr


func set_frame_nr(value: int) -> void:
	if !Project.is_loaded:
		return
	var end: int = Project.data.timeline_end
	if value > end:
		is_playing = false
		value = end
		for i: int in audio_players.size():
			audio_players[i].stop()

	var audio_file_counter: Dictionary[int, int] = {}
	frame_nr = value
	visual_frame_nr = value
	visual_frame_changed.emit()
	var is_seek: bool = frame_nr != prev_frame + 1
	for track: int in TrackLogic.tracks.size():
		var audio_clip: ClipData = find_audio(frame_nr, track)
		if audio_clip:
			var file_id: int = audio_clip.file
			var instance_index: int = audio_file_counter.get(file_id, 0)
			audio_file_counter[file_id] = instance_index + 1
			audio_players[track].set_audio(audio_clip, instance_index)
		elif is_seek or audio_players[track].stop_frame == frame_nr:
			# Stop track on seek, or if we naturally reached the end of the clip.
			audio_players[track].stop()
	prev_frame = frame_nr
	update_frame()


func update_frame() -> void:
	set_frame(frame_nr)


func set_frame(new_frame: int = frame_nr + 1) -> void:
	if frame_nr != new_frame:
		self.frame_nr = new_frame
		return
	_cleanup_unused_instances(frame_nr)

	for track: int in TrackLogic.tracks.size():
		# Check if current clip is correct.
		var clip: ClipData = loaded_clips[track]
		if _check_clip(track, frame_nr):
			clips_instance_index[track] = _get_instance_for_clip(clip)
			update_data(track)
			continue

		# Getting the next frame if possible.
		clip = TrackLogic.get_clip_at_overlap(track, frame_nr)
		if clip:
			loaded_clips[track] = clip
			clips_to_update[track] = true
			clips_instance_index[track] = _get_instance_for_clip(clip)
			update_data(track)
			continue

		# No clip at position.
		loaded_clips[track] = null
		if view_textures[track].texture != null:
			view_textures[track].texture = null
	if frame_nr == Project.data.timeline_end:
		is_playing = false

	data_ready = true
	data_set_frame = Engine.get_process_frames()


func scrub_to_frame(frame_target: int) -> void:
	if frame_target != visual_frame_nr:
		visual_frame_nr = frame_target
		visual_frame_changed.emit()
		_scrub_frame = frame_target


func finish_scrub() -> void:
	if _scrub_frame != -1:
		if frame_nr != _scrub_frame:
			set_frame(_scrub_frame)
		_scrub_frame = -1


# --- Audio handling ---

func find_audio(frame: int, track: int) -> ClipData:
	var clip: ClipData = TrackLogic.get_clip_at_overlap(track, frame)
	return clip if clip and clip.type in AUDIO_TYPES else null


# --- Video stuff ---

func update_data(track: int) -> void:
	var clip: ClipData = loaded_clips[track]
	var raw_data: Variant = FileLogic.file_data.get(clip.file)
	var clip_frame: int = frame_nr - clip.start

	if clip.type == TYPE.TEXT:
		var temp_file: TempFile = raw_data
		var text_effect: EffectVisual = temp_file.text_effect

		var text_data: String = text_effect.get_value(text_effect.params[0], clip_frame)
		var text_font: String = text_effect.get_value(text_effect.params[1], clip_frame)
		var text_h_align: int = text_effect.get_value(text_effect.params[2], clip_frame)
		var text_v_align: int = text_effect.get_value(text_effect.params[3], clip_frame)
		var text_size: int = text_effect.get_value(text_effect.params[4], clip_frame)
		var text_color: Color = text_effect.get_value(text_effect.params[5], clip_frame)
		var text_outline_size: int = text_effect.get_value(text_effect.params[6], clip_frame)
		var text_outline_color: Color = text_effect.get_value(text_effect.params[7], clip_frame)
		var text_shadow_size: int = text_effect.get_value(text_effect.params[8], clip_frame)
		var text_shadow_offset: Vector2i = text_effect.get_value(text_effect.params[9], clip_frame)
		var text_shadow_color: Color = text_effect.get_value(text_effect.params[10], clip_frame)

		var font: Font = Settings.get_system_font(text_font) if text_font != "" else ThemeDB.fallback_font

		var text_viewport: SubViewport = text_viewports[track]
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

		if text_label.size != Vector2(Project.data.resolution):
			text_label.size = Project.data.resolution
		if text_viewport.size != Project.data.resolution:
			text_viewport.size = Project.data.resolution
		text_label.label_settings = text_label_settings

		text_viewport.render_target_update_mode = SubViewport.UPDATE_ONCE
	elif clip.type == TYPE.PCK:
		# TODO: Add PCK files here
		pass


func update_views() -> void:
	for track_id: int in loaded_clips.size():
		if TrackLogic.tracks[track_id].is_visible and loaded_clips[track_id]:
			update_view(track_id, clips_to_update[track_id], clips_instance_index[track_id])
			clips_to_update[track_id] = false
		elif view_textures[track_id].texture != null:
			view_textures[track_id].texture = null
	data_ready = false
	viewport.render_target_update_mode = SubViewport.UPDATE_ONCE
	frame_changed.emit()


func update_view(track_id: int, update: bool, instance_index: int) -> void:
	var clip: ClipData = loaded_clips[track_id]
	var file: FileData = FileLogic.files[clip.file]
	var raw_data: Variant = FileLogic.file_data.get(file.id)
	if raw_data == null:
		return

	var clip_frame: int = frame_nr - clip.start
	var relative_frame: int = int(clip_frame * clip.speed) + clip.begin

	var fade_alpha: float = Utils.calculate_fade(clip_frame, clip, true)
	var effects: Array[EffectVisual] = clip.effects.video
	load_video_frame(clip, relative_frame, instance_index)

	if clip.type == TYPE.TEXT:
		var texture_rid: RID = text_viewports[track_id].get_texture().get_rid()
		if update or Project.data.resolution != compositors[track_id].resolution:
			RenderingServer.call_on_render_thread(compositors[track_id].initialize_texture.bind(Project.data.resolution))

		RenderingServer.call_on_render_thread(compositors[track_id].process_texture_frame.bind(
				texture_rid, effects, clip_frame, fade_alpha))
		view_textures[track_id].texture = compositors[track_id].display_texture
	elif raw_data is Video:
		var video: Video = FileLogic.get_video_reader(file, instance_index)
		if update or Project.data.resolution != compositors[track_id].resolution:
			RenderingServer.call_on_render_thread(compositors[track_id].initialize_video.bind(video))

		RenderingServer.call_on_render_thread(compositors[track_id].process_video_frame.bind(
				video, effects, clip_frame, fade_alpha))
		view_textures[track_id].texture = compositors[track_id].display_texture
	elif raw_data is Texture2D:
		var image: Texture2D = raw_data
		var texture_rid: RID = image.get_rid()
		if update or Project.data.resolution != compositors[track_id].resolution:
			RenderingServer.call_on_render_thread(compositors[track_id].initialize_texture.bind(Project.data.resolution))

		RenderingServer.call_on_render_thread(compositors[track_id].process_texture_frame.bind(
				texture_rid, effects, clip_frame, fade_alpha))
		view_textures[track_id].texture = compositors[track_id].display_texture

	_apply_track_blend_mode(track_id, effects, clip_frame)


func _apply_track_blend_mode(track_id: int, effects: Array[EffectVisual], clip_frame: int) -> void:
	var target_blend_mode: int = 0
	for effect: EffectVisual in effects:
		if effect.id == "blend_mode" and effect.is_enabled:
			target_blend_mode = effect.get_value(effect.params[0], clip_frame)
			break

	var current_material: Material = view_textures[track_id].material
	if current_material == null or not current_material is CanvasItemMaterial or (current_material as CanvasItemMaterial).blend_mode != target_blend_mode:
		var canvas_material: CanvasItemMaterial = CanvasItemMaterial.new()
		canvas_material.blend_mode = target_blend_mode as CanvasItemMaterial.BlendMode
		view_textures[track_id].material = canvas_material


# --- Setters ---

func set_is_playing(value: bool) -> void:
	is_playing = value
	for player: AudioPlayer in audio_players:
		player.play(value)
	play_changed.emit(value)


func set_playback_speed(value: float) -> void:
	playback_speed = value
	for player: AudioPlayer in audio_players:
		if player.clip:
			player.player.pitch_scale = playback_speed * player.clip.speed
	pitch_shift_effect.pitch_scale = 1.0 / playback_speed


func set_background_color(color: Color) -> void:
	background.color = color
	viewport.render_target_update_mode = SubViewport.UPDATE_ONCE


# --- Playback helpers ---

func load_video_frame(clip: ClipData, frame: int, instance_index: int = 0) -> void:
	if clip and clip.type == EditorCore.TYPE.VIDEO:
		var file: FileData = FileLogic.files[clip.file]
		var video: Video = FileLogic.get_video_reader(file, instance_index)
		if video != null: # Check if video is done loading.
			var target_frame_nr: int = roundi((float(frame) / Project.data.framerate) * video.get_framerate())
			target_frame_nr = clampi(target_frame_nr, 0, maxi(0, video.get_frame_count() - 1))
			var vid_id: int = video.get_instance_id()

			# If a prefetch task is currently running on this video instance,
			# we MUST wait for it to finish to prevent multi-threading crashes in C++.
			if EditorCore.active_tasks.has(vid_id):
				var task_id: int = EditorCore.active_tasks[vid_id]
				if not WorkerThreadPool.is_task_completed(task_id):
					WorkerThreadPool.wait_for_task_completion(task_id)
				EditorCore.active_tasks.erase(vid_id)
			if video.get_current_frame() != target_frame_nr:
				if is_playing:
					EditorCore.active_tasks[vid_id] = WorkerThreadPool.add_task(func() -> void:
							video.seek_frame(target_frame_nr))
				else:
					video.seek_frame(target_frame_nr)
