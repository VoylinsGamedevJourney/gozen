extends Node


signal update_encoder_status(status: Status)


enum Status { ## The progress amounts.
	ERROR_OPEN = -1,
	ERROR_AUDIO = -2,
	ERROR_CANCELED = -3,
	SETUP = 0,
	COMPILING_AUDIO = 3,
	SENDING_AUDIO = 4,
	SENDING_FRAMES = 5,
	FRAMES_SEND = 6,
	LAST_FRAMES = 99,
	FINISHED = 100,
}


const RENDER_PROFILE_YOUTUBE: String = "uid://bp6oahvgcklvc"
const RENDER_PROFILE_YOUTUBE_HQ: String = "uid://f5ffyfe5gb5b"
const RENDER_PROFILE_AV1: String = "uid://du35gfskoijp"
const RENDER_PROFILE_VP9: String = "uid://b8lmmvi0gnujr"
const RENDER_PROFILE_VP8: String = "uid://drlbs008bf7so"
const RENDER_PROFILE_HEVC: String = "uid://bcktb6d5bti7t"

const MIX_RATE: float = 44100.0
const AUDIO_MIN: int = -32768
const AUDIO_MAX: int = 32767


var project_data: ProjectData
var encoder: Encoder
var viewport: ViewportTexture

var is_encoding: bool = false
var cancel_encoding: bool = false
var start_time: int = 0
var encoding_time: int = 0

var buffer_size: int = 5
var frame_queue: Array[PackedByteArray] = []
var thread: Thread

var rendering_device: RenderingDevice
var yuv_shader: RID
var yuv_pipeline: RID
var yuv_output_tex: RID
var yuv_sampler: RID
var yuv_params_buffer: RID
var yuv_input_texture: RID

var proxies_used: bool
var original_vsync_mode: DisplayServer.VSyncMode = DisplayServer.VSYNC_ENABLED
var original_video_frame_cache_size: int = 30

var stop_encoding: bool = false

var progress_overlay: ProgressOverlay = null
var progress_frame_increase: float = 0.0
var current_progress: float = 0.0
var last_displayed_progress: int = -1
var status_indicator_id: int



func _ready() -> void:
	if Project.project_ready.connect(func() -> void: project_data = Project.data): print_stack()
	if update_encoder_status.connect(_on_update_encoder_status): print_stack()


#--- Render logic ---

func get_render_profile(profile_name: String) -> RenderProfile:
	var defaults: Array[String] = [
		RENDER_PROFILE_YOUTUBE,
		RENDER_PROFILE_YOUTUBE_HQ,
		RENDER_PROFILE_AV1,
		RENDER_PROFILE_VP9,
		RENDER_PROFILE_VP8,
		RENDER_PROFILE_HEVC
	]
	for path: String in defaults:
		var profile: RenderProfile = load(path)
		if profile and profile.profile_name == profile_name:
			return profile

	var user_path: String = Utils.get_config_dir() + "profiles/render/"
	if DirAccess.dir_exists_absolute(user_path):
		for file_name: String in DirAccess.get_files_at(user_path):
			file_name = file_name.trim_suffix(".remap")
			if not file_name.ends_with(".tres") and not file_name.ends_with(".res"): continue
			var profile: RenderProfile = load(user_path.path_join(file_name))
			if profile and profile.profile_name == profile_name:
				return profile
	return null


func start_cli_render(export_path: String, profile_name: String) -> void:
	if profile_name.is_empty():
		profile_name = Settings.get_default_render_profile()

	var profile: RenderProfile = get_render_profile(profile_name)
	if not profile:
		profile = get_render_profile("YouTube")
		printerr("RenderManager: Profile '%s' not found, falling back to 'YouTube'." % profile_name)

	var ext: String = Utils.get_video_extension(profile.video_codec)
	if export_path.is_empty():
		export_path = Project.get_project_path().get_basename() + ext
	elif not export_path.ends_with(ext):
		export_path += ext

	var start_frame: int = 0
	var end_frame: int = Project.data.timeline_end
	if Project.data.use_render_region:
		start_frame = Project.data.render_region.x
		end_frame = Project.data.render_region.y
		if start_frame > end_frame:
			printerr("RenderManager: Render region start frame cannot be after the end frame.")
			return

	await start_render(export_path, profile, OS.get_processor_count() - 1, start_frame, end_frame, false)


func start_render(export_path: String, profile: RenderProfile, threads: int, start_frame: int = 0, end_frame: int = -1, draft: bool = false) -> void:
	if end_frame == -1:
		end_frame = project_data.timeline_end

	var render_resolution: Vector2i = project_data.resolution
	if draft:
		var target_height: int = 480
		var aspect: float = float(render_resolution.x) / float(render_resolution.y)
		render_resolution = Vector2i(int(target_height * aspect), target_height)
		Print.info("RenderManager", "Draft mode enabled. Scaling to ", render_resolution)

	if render_resolution.x % 2 != 0:
		render_resolution.x += 1
	if render_resolution.y % 2 != 0:
		render_resolution.y += 1

	print("--------------------")
	Print.header("Rendering process started")
	Print.info("Path", export_path)
	Print.info("Resolution", render_resolution)
	Print.info("Framerate", project_data.framerate)
	Print.info("Video codec", profile.video_codec)
	Print.info("CRF", profile.crf)
	Print.info("GOP", profile.gop)
	Print.info("B-frames", profile.b_frames)
	if profile.video_codec == Encoder.VideoCodec.V_H264:
		Print.info("h264 preset", profile.h264_preset)
	Print.info("Audio codec", profile.audio_codec)
	Print.info("Audio channels", profile.audio_channels)
	Print.info("Cores/threads", threads)
	Print.info("Frames to process", end_frame - start_frame + 1)
	print("--------------------")

	# Resetting progress values.
	progress_frame_increase = 90.0 / maxi(1, end_frame - start_frame)
	current_progress = 0.0

	var gozen_icon: CompressedTexture2D = load(Library.ICON_GOZEN)
	var rendering_icon: CompressedTexture2D = load(Library.ICON_RENDERING)

	if OS.get_name().to_lower() == "windows":
		DisplayServer.set_icon(rendering_icon.get_image())
		status_indicator_id = DisplayServer.create_status_indicator(
				rendering_icon, tr("Rendering"), Callable())

	if progress_overlay != null:
		PopupManager.close(PopupManager.PROGRESS)
		progress_overlay = null

	progress_overlay = PopupManager.get_popup(PopupManager.PROGRESS) as ProgressOverlay
	progress_overlay.update_title(tr("Rendering"))
	progress_overlay.update(0, "")

	var button: Button = Button.new()
	var status_hbox: HBoxContainer = progress_overlay.get("status_hbox")
	var status_label: Label = status_hbox.get_child(0)

	button.text = tr("Cancel rendering")
	@warning_ignore("return_value_discarded")
	button.pressed.connect(_cancel_render)
	status_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
	status_hbox.add_child(button)

	if OS.get_name().to_lower() == "windows":
		DisplayServer.set_icon(gozen_icon.get_image())
		DisplayServer.delete_status_indicator(status_indicator_id)

	encoder = Encoder.new()
	encoder.set_resolution(render_resolution)
	encoder.set_framerate(project_data.framerate)
	encoder.set_file_path(export_path)
	encoder.set_video_codec_id(profile.video_codec)
	encoder.set_crf(profile.crf)
	encoder.set_h264_preset(profile.h264_preset)
	encoder.set_gop_size(profile.gop)
	encoder.set_b_frames(profile.b_frames)
	encoder.set_audio_codec_id(profile.audio_codec)
	encoder.set_audio_channels(profile.audio_channels)
	encoder.set_threads(threads)

	await start_encoder(start_frame, end_frame)


func _on_update_encoder_status(status: Status) -> void:
	if progress_overlay == null:
		return

	var status_str: String = ""
	match status:
		Status.ERROR_OPEN: show_error(tr("Error opening file"))
		Status.ERROR_AUDIO: show_error(tr("Error whilst sending audio"))
		Status.ERROR_CANCELED:
			PopupManager.close(PopupManager.PROGRESS)
			progress_overlay = null

		Status.SETUP: status_str = tr("Setting up ...")
		Status.COMPILING_AUDIO: status_str = tr("Compiling audio ...")
		Status.SENDING_AUDIO: status_str = tr("Compiling audio ...")
		Status.SENDING_FRAMES: status_str = tr("Sending data ...")
		Status.FRAMES_SEND: status_str = tr("Sending data ...")
		Status.LAST_FRAMES: status_str = tr("Sending final frame ...")
		Status.FINISHED: _render_finished()

	if status >= 0:
		if status == Status.FRAMES_SEND:
			current_progress += progress_frame_increase
		else:
			current_progress = status

	var progress_int: int = floori(current_progress)
	if progress_int == last_displayed_progress and status == Status.FRAMES_SEND:
		return
	last_displayed_progress = progress_int

	if progress_overlay != null:
		progress_overlay.update(progress_int, status_str)


func _render_finished() -> void:
	var dialog: AcceptDialog = PopupManager.create_accept_dialog(tr("Rendering finished"))
	dialog.dialog_text = "Render time: %s" % Format.time_str(encoding_time / 1000.0)
	dialog.exclusive = true

	get_tree().root.add_child(dialog)
	dialog.popup_centered()
	PopupManager.close(PopupManager.PROGRESS)
	progress_overlay = null


func _cancel_render() -> void: cancel_encoding = true


func show_error(message: String) -> void:
	var dialog: AcceptDialog = PopupManager.create_accept_dialog(tr("Error whilst rendering video"))
	dialog.dialog_text = message
	dialog.exclusive = true

	get_tree().root.add_child(dialog)
	dialog.popup_centered()
	PopupManager.close(PopupManager.PROGRESS)
	progress_overlay = null


func start_encoder(start_frame: int = 0, end_frame: int = -1) -> void:
	is_encoding = true

	if end_frame == -1:
		end_frame = project_data.timeline_end
	if encoder != null and encoder.is_open():
		is_encoding = false
		return printerr("RenderManager: Can't encode whilst another encoder is still busy!")
	if viewport == null:
		viewport = EditorCore.viewport.get_texture()

	# VSync stuff.
	original_vsync_mode = DisplayServer.window_get_vsync_mode()
	DisplayServer.window_set_vsync_mode(DisplayServer.VSYNC_DISABLED)

	original_video_frame_cache_size = Settings.get_video_cache_size()
	Settings.set_video_cache_size(0)

	# Making certain proxies aren't being used for this.
	proxies_used = Settings.get_use_proxies()
	if proxies_used:
		Settings.set_use_proxies(false)

		# Wait for tasks like video loading to finish first.
		while Threader.tasks.size() > 0:
			await get_tree().process_frame

		# Necessary waiting time to make certain all clips are ready..
		await RenderingServer.frame_post_draw
		await get_tree().process_frame

	# Setup encoder.
	update_encoder_status.emit(Status.SETUP)
	await RenderingServer.frame_post_draw
	start_time = Time.get_ticks_msec()
	encoding_time = 0

	if !encoder.open(viewport.get_image().get_format() == Image.FORMAT_RGBA8):
		stop_encoder()
		update_encoder_status.emit(Status.ERROR_OPEN)
		await RenderingServer.frame_post_draw
		is_encoding = false
		return printerr("RenderManager: Couldn't open encoder!")

	var use_audio: bool = encoder.audio_codec_set()
	var active_audio_tracks: Array[Dictionary] = []
	if use_audio:
		for i: int in TrackLogic.tracks.size():
			active_audio_tracks.append({})

	# RGBA to YUV shader setup.
	if !rendering_device:
		rendering_device = RenderingServer.get_rendering_device()
	var render_resolution: Vector2i = Project.data.resolution
	var shader_file: RDShaderFile = load("uid://de0r3l6ipvr0y")
	yuv_shader = rendering_device.shader_create_from_spirv(shader_file.get_spirv())
	yuv_pipeline = rendering_device.compute_pipeline_create(yuv_shader)

	var texture_format: RDTextureFormat = RDTextureFormat.new()
	texture_format.width = render_resolution.x
	texture_format.height = int(render_resolution.y * 1.5)
	texture_format.format = RenderingDevice.DATA_FORMAT_R8_UNORM
	texture_format.usage_bits = RenderingDevice.TEXTURE_USAGE_STORAGE_BIT | RenderingDevice.TEXTURE_USAGE_CAN_COPY_FROM_BIT
	yuv_output_tex = rendering_device.texture_create(texture_format, RDTextureView.new())
	yuv_sampler = rendering_device.sampler_create(RDSamplerState.new())

	var input_format: RDTextureFormat = RDTextureFormat.new()
	input_format.width = render_resolution.x
	input_format.height = render_resolution.y
	input_format.format = RenderingDevice.DATA_FORMAT_R8G8B8A8_UNORM
	input_format.usage_bits = RenderingDevice.TEXTURE_USAGE_SAMPLING_BIT | RenderingDevice.TEXTURE_USAGE_CAN_COPY_TO_BIT
	yuv_input_texture = rendering_device.texture_create(input_format, RDTextureView.new())

	# BT709 Limited range matrix.
	var bt709_rgb_to_yuv: PackedFloat32Array = PackedFloat32Array([
		0.182586, -0.100642,  0.439216, 0.0,
		0.614231, -0.338574, -0.398942, 0.0,
		0.062007,  0.439216, -0.040276, 0.0,
		0.062745,  0.500000,  0.500000, 1.0 ])
	var params_bytes: PackedByteArray = PackedByteArray()
	if params_bytes.resize(80):
		printerr("RenderManager: Couldn't resize params_bytes array!")

	for index: int in 16:
		params_bytes.encode_float(index * 4, bt709_rgb_to_yuv[index])

	params_bytes.encode_s32(64, render_resolution.x)
	params_bytes.encode_s32(68, render_resolution.y)
	yuv_params_buffer = rendering_device.uniform_buffer_create(params_bytes.size(), params_bytes)

	# Sending the video frame data.
	update_encoder_status.emit(Status.SENDING_FRAMES)

	frame_queue.clear()
	var audio_queue: Array[PackedByteArray] = []
	stop_encoding = false
	thread = Thread.new()
	if thread.start(_encoding_loop.bind(use_audio, audio_queue)):
		printerr("RenderManager: Couldn't start encoder thread!")
		stop_encoder()
		update_encoder_status.emit(Status.ERROR_CANCELED)
		await EditorCore.frame_changed
		is_encoding = false
		return

	# Because of labels and other draw() stuff which takes a frame to show, we
	# need to prepare the data in one frame and show it in the next frame.
	EditorCore.frame_nr = start_frame # We set the first frame data ready.
	if EditorCore.data_ready:
		await EditorCore.frame_changed # View should be ready.
	EditorCore.frame_nr = start_frame + 1 # We prepare the second frame data directly.

	for i: int in range(start_frame, end_frame + 1):
		if cancel_encoding:
			break

		await get_tree().process_frame
		var frame_data: PackedByteArray = _convert_rgba_to_yuv(viewport.get_rid(), render_resolution)
		var audio_data: PackedByteArray = PackedByteArray()
		if use_audio:
			audio_data = _get_audio_for_frame(i, active_audio_tracks)

		var frame_pushed: bool = false
		while not frame_pushed and not cancel_encoding:
			if not thread.is_alive():
				break # Error happened in Encoder.

			Threader.mutex.lock()
			if frame_queue.size() < buffer_size: # Limiting RAM usage.
				frame_queue.append(frame_data)
				if use_audio:
					audio_queue.append(audio_data)
				frame_pushed = true
			Threader.mutex.unlock()
			if frame_pushed:
				Threader.semaphore.post()
			else:
				await get_tree().process_frame
		if i + 1 <= end_frame:
			if EditorCore.data_ready:
				await EditorCore.frame_changed
			if i + 2 <= end_frame:
				EditorCore.frame_nr = i + 2

	# Flushing the system.
	stop_encoding = true
	Threader.semaphore.post() # Wake up Encoder one last time to flush.
	if thread.is_started():
		while thread.is_alive():
			await get_tree().process_frame
		thread.wait_to_finish()

	if cancel_encoding:
		update_encoder_status.emit(Status.ERROR_CANCELED)
		await RenderingServer.frame_post_draw
		is_encoding = false
		return stop_encoder()

	encoding_time = Time.get_ticks_msec() - start_time
	update_encoder_status.emit(Status.FINISHED)
	await RenderingServer.frame_post_draw
	NotificationManager.info("Render finished!")
	stop_encoder()


func stop_encoder() -> void:
	if encoder.is_open():
		encoder.close()
	if proxies_used:
		Settings.set_use_proxies(true)
	cancel_encoding = false

	Threader.mutex.lock()
	frame_queue.clear()
	Threader.mutex.unlock()

	DisplayServer.window_set_vsync_mode(original_vsync_mode)
	Settings.set_video_cache_size(original_video_frame_cache_size)

	if rendering_device:
		if yuv_pipeline.is_valid():
			rendering_device.free_rid(yuv_pipeline)
			yuv_pipeline = RID()
		if yuv_shader.is_valid():
			rendering_device.free_rid(yuv_shader)
			yuv_shader = RID()
		if yuv_output_tex.is_valid():
			rendering_device.free_rid(yuv_output_tex)
			yuv_output_tex = RID()
		if yuv_sampler.is_valid():
			rendering_device.free_rid(yuv_sampler)
			yuv_sampler = RID()
		if yuv_params_buffer.is_valid():
			rendering_device.free_rid(yuv_params_buffer)
			yuv_params_buffer = RID()
		if yuv_input_texture.is_valid():
			rendering_device.free_rid(yuv_input_texture)
			yuv_input_texture = RID()
	is_encoding = false


func _encoding_loop(use_audio: bool, audio_queue: Array[PackedByteArray]) -> void:
	while true:
		Threader.semaphore.wait()
		Threader.mutex.lock()
		var has_frames: bool = not frame_queue.is_empty()
		var frame_data: PackedByteArray = PackedByteArray()
		var audio_data: PackedByteArray = PackedByteArray()
		if has_frames:
			frame_data = frame_queue.pop_front()
			if use_audio:
				audio_data = audio_queue.pop_front()
		update_encoder_status.emit.call_deferred(Status.FRAMES_SEND)
		Threader.mutex.unlock()

		if not frame_data.is_empty():
			if use_audio and not audio_data.is_empty():
				if not encoder.send_audio(audio_data):
					call_deferred("stop_encoder")
					printerr("RenderManager: Something went wrong sending audio frame!")
					break
			if not encoder.send_frame(frame_data):
				call_deferred("stop_encoder")
				printerr("RenderManager: Something went wrong sending frame(s)!")
				break # Error happened in encoder.
		if stop_encoding:
			Threader.mutex.lock()
			var is_empty: bool = frame_queue.is_empty()
			Threader.mutex.unlock()
			if is_empty:
				update_encoder_status.emit.call_deferred(Status.LAST_FRAMES)
				encoder.close()
				break


#--- Audio handling ---

func _get_clip_audio_info(clip: ClipData) -> Dictionary:
	var framerate: float = project_data.framerate
	var start_sec: float = float(clip.begin) / framerate
	var duration_sec: float = float(clip.duration) / framerate
	var file_path: String

	if clip.effects.ato_active and clip.effects.ato_file != -1:
		start_sec -= clip.effects.ato_offset
		file_path = FileLogic.files[clip.effects.ato_file].path
	else:
		var target_file: FileData = FileLogic.files[clip.file]
		if target_file.ato_active and target_file.ato_file != -1:
			start_sec -= target_file.ato_offset
			file_path = FileLogic.files[target_file.ato_file].path
		else:
			file_path = target_file.path

	return { "path": file_path, "start": start_sec, "duration": duration_sec }


func _get_audio_for_frame(frame_nr: int, active_audio_tracks: Array[Dictionary]) -> PackedByteArray:
	var framerate: float = project_data.framerate

	var global_start_sample: int = int((float(frame_nr) / framerate) * MIX_RATE)
	var global_end_sample: int = int((float(frame_nr + 1) / framerate) * MIX_RATE)
	var samples_count: int = global_end_sample - global_start_sample
	var length_bytes: int = samples_count * 4

	var master_audio: PackedByteArray = []
	if master_audio.resize(length_bytes):
		printerr("RenderManager: Couldn't resize master_audio")

	for track: int in TrackLogic.tracks.size():
		if TrackLogic.tracks[track].is_muted: continue
		var active_dict: Dictionary = active_audio_tracks[track]

		# Check if clip is still valid.
		if not active_dict.is_empty():
			var clip: ClipData = active_dict.clip
			if frame_nr >= clip.end or clip.effects.is_muted:
				active_dict.clear() # Clip ended or muted.

		if active_dict.is_empty():
			var clip: ClipData = TrackLogic.get_clip_at_overlap(track, frame_nr)
			if clip and clip.type in EditorCore.AUDIO_TYPES and not clip.effects.is_muted:
				var info: Dictionary = _get_clip_audio_info(clip)
				var clip_global_start: int = int((float(clip.start) / framerate) * MIX_RATE)
				var clip_global_end: int = int((float(clip.end) / framerate) * MIX_RATE)
				var expected_bytes: int = (clip_global_end - clip_global_start) * 4

				# Get full audio for clip.
				var fetch_duration: float = info.duration * clip.speed
				var audio_data: PackedByteArray = Audio.get_audio_data(info.path as String, clip.effects.audio_stream_index, info.start as float, fetch_duration)
				if not is_equal_approx(clip.speed, 1.0):
					audio_data = Audio.change_speed(audio_data, clip.speed)

				# Apply static effects.
				for effect: Effect in clip.effects.audio:
					if not effect.is_enabled: continue
					if effect.id == "pitch":
						var pitch_scale: float = effect.get_value(effect.params[0], 0)
						if not is_equal_approx(pitch_scale, 1.0):
							audio_data = Audio.apply_pitch(audio_data, pitch_scale)

				if audio_data.size() < expected_bytes:
					var padding: int = expected_bytes - audio_data.size()
					var zeros: PackedByteArray = []
					if zeros.resize(padding):
						printerr("RenderManager: Couldn't resize zeros array!")
					audio_data.append_array(zeros)
				elif audio_data.size() > expected_bytes:
					audio_data = audio_data.slice(0, expected_bytes)

				# Apply effects like fade, ...
				var fade_in: int = clip.effects.fade_audio.x
				var fade_out: int = clip.effects.fade_audio.y
				if fade_in > 0 or fade_out > 0:
					var total_samples: int = int(expected_bytes / 4.0)
					var fade_in_samples: int = int((float(fade_in) / framerate) * MIX_RATE)
					var fade_out_samples: int = int((float(fade_out) / framerate) * MIX_RATE)
					audio_data = Audio.apply_fade(audio_data, fade_in_samples, fade_out_samples, 0, total_samples)

				active_dict["clip"] = clip
				active_dict["audio_data"] = audio_data
				active_audio_tracks[track] = active_dict

		if not active_dict.is_empty():
			var clip: ClipData = active_dict.clip
			if frame_nr >= clip.start and frame_nr < clip.end:
				var clip_global_start: int = int((float(clip.start) / framerate) * MIX_RATE)
				var frame_global_start: int = int((float(frame_nr) / framerate) * MIX_RATE)
				var frame_global_end: int = int((float(frame_nr + 1) / framerate) * MIX_RATE)

				var start_byte: int = (frame_global_start - clip_global_start) * 4
				var bytes_to_copy: int = (frame_global_end - frame_global_start) * 4

				var clip_audio: PackedByteArray = active_dict.audio_data

				if start_byte >= 0 and start_byte < clip_audio.size():
					var slice_end: int = mini(start_byte + bytes_to_copy, clip_audio.size())
					var frame_audio: PackedByteArray = clip_audio.slice(start_byte, slice_end)

					# Add padding if needed.
					if frame_audio.size() < bytes_to_copy:
						var padding: int = bytes_to_copy - frame_audio.size()
						var zeros: PackedByteArray = []
						if zeros.resize(padding):
							printerr("RenderManager: Couldn't resize zeros array!")
						frame_audio.append_array(zeros)

					# Apply per-frame effects.
					for effect: Effect in clip.effects.audio:
						if not effect.is_enabled: continue

						var volume_db: float = 0.0
						var apply: bool = false

						if effect.id == "volume":
							var offset_in_clip_frames: int = frame_nr - clip.start
							volume_db = effect.get_value(effect.params[0], offset_in_clip_frames)
							apply = true
						elif effect.id == "normalize":
							var offset_in_clip_frames: int = frame_nr - clip.start
							var target_db: float = effect.get_value(effect.params[0], offset_in_clip_frames)
							var peak_db: float = FileLogic.get_clip_peak_db(clip)
							volume_db = target_db - peak_db
							apply = true
						elif effect.id == "pan":
							var offset_in_clip_frames: int = frame_nr - clip.start
							var pan_val: float = effect.get_value(effect.params[0], offset_in_clip_frames)
							if not is_equal_approx(pan_val, 0.0):
								frame_audio = Audio.apply_pan(frame_audio, pan_val)
						elif effect.id == "channel_swap":
							var offset_in_clip_frames: int = frame_nr - clip.start
							var swap_active: bool = effect.get_value(effect.params[0], offset_in_clip_frames)
							if swap_active:
								frame_audio = Audio.apply_channel_swap(frame_audio)
						elif effect.id == "stereo_to_mono":
							var offset_in_clip_frames: int = frame_nr - clip.start
							var mono_active: bool = effect.get_value(effect.params[0], offset_in_clip_frames)
							if mono_active:
								frame_audio = Audio.apply_stereo_to_mono(frame_audio)
						elif effect.id == "retro_filter":
							var offset_in_clip_frames: int = frame_nr - clip.start
							var depth: int = effect.get_value(effect.params[0], offset_in_clip_frames) as int
							if depth < 16:
								frame_audio = Audio.apply_retro_filter(frame_audio, depth)

						if apply:
							var volume_linear: float = db_to_linear(volume_db)
							if not is_equal_approx(volume_linear, 1.0):
								var frame_volumes: PackedFloat32Array = PackedFloat32Array([volume_linear])
								frame_audio = Audio.apply_dynamic_volume(frame_audio, frame_volumes, MIX_RATE, framerate)
					master_audio = Audio.combine_data(master_audio, frame_audio, 0)
	return master_audio


#--- RGBA to YUV handling ---

func _convert_rgba_to_yuv(input_texture_rid: RID, res: Vector2i) -> PackedByteArray:
	var rd_input_tex: RID = RenderingServer.texture_get_rd_texture(input_texture_rid)
	if rendering_device.texture_copy(rd_input_tex, yuv_input_texture, Vector3.ZERO, Vector3.ZERO, Vector3(res.x, res.y, 1), 0, 0, 0, 0):
		printerr("RenderManager: Failed to copy texture in rendering device to convert RGBA to YUV!")

	var uniform_input: RDUniform = RDUniform.new()
	uniform_input.uniform_type = RenderingDevice.UNIFORM_TYPE_SAMPLER_WITH_TEXTURE
	uniform_input.binding = 0
	uniform_input.add_id(yuv_sampler)
	uniform_input.add_id(yuv_input_texture)

	var uniform_output: RDUniform = RDUniform.new()
	uniform_output.uniform_type = RenderingDevice.UNIFORM_TYPE_IMAGE
	uniform_output.binding = 1
	uniform_output.add_id(yuv_output_tex)

	var uniform_params: RDUniform = RDUniform.new()
	uniform_params.uniform_type = RenderingDevice.UNIFORM_TYPE_UNIFORM_BUFFER
	uniform_params.binding = 2
	uniform_params.add_id(yuv_params_buffer)

	var uniform_set: RID = rendering_device.uniform_set_create([uniform_input, uniform_output, uniform_params], yuv_shader, 0)
	var compute_list: int = rendering_device.compute_list_begin()
	rendering_device.compute_list_bind_compute_pipeline(compute_list, yuv_pipeline)
	rendering_device.compute_list_bind_uniform_set(compute_list, uniform_set, 0)
	rendering_device.compute_list_dispatch(compute_list, ceili(res.x / 8.0), ceili(res.y / 8.0), 1)
	rendering_device.compute_list_end()
	rendering_device.free_rid(uniform_set)
	return rendering_device.texture_get_data(yuv_output_tex, 0)
