extends Node


signal update_encoder_status(status: STATUS)


enum STATUS { ## The progress amounts.
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


const MIX_RATE: float = 44100.0
const AUDIO_MIN: int = -32768
const AUDIO_MAX: int = 32767


var project_data: ProjectData
var encoder: Encoder
var viewport: ViewportTexture

var cancel_encoding: bool = false
var start_time: int = 0
var encoding_time: int = 0

var buffer_size: int = 5
var proxies_used: bool

var _original_vsync_mode: DisplayServer.VSyncMode = DisplayServer.VSYNC_ENABLED




func _ready() -> void:
	Project.project_ready.connect(_on_project_ready)


func _on_project_ready() -> void:
	project_data = Project.data


# --- Render logic ---

func start_encoder() -> void:
	if encoder != null and encoder.is_open():
		return printerr("RenderManager: Can't encode whilst another encoder is still busy!")
	if viewport == null:
		viewport = EditorCore.viewport.get_texture()

	# VSync stuff.
	_original_vsync_mode = DisplayServer.window_get_vsync_mode()
	DisplayServer.window_set_vsync_mode(DisplayServer.VSYNC_DISABLED)

	# Making certain proxies aren't being used for this
	proxies_used = Settings.get_use_proxies()
	if proxies_used:
		Settings.set_use_proxies(false)
		# Necessary waiting time to make certain all clips are ready.
		await RenderingServer.frame_post_draw
		await get_tree().process_frame

	# Setup encoder.
	update_encoder_status.emit(STATUS.SETUP)
	await RenderingServer.frame_post_draw
	start_time = Time.get_ticks_msec()
	encoding_time = 0

	if !encoder.open(viewport.get_image().get_format() == Image.FORMAT_RGBA8):
		stop_encoder()
		update_encoder_status.emit(STATUS.ERROR_OPEN)
		await RenderingServer.frame_post_draw
		return printerr("RenderManager: Couldn't open encoder!")

	# Creating + sending audio.
	if encoder.audio_codec_set():
		update_encoder_status.emit(STATUS.COMPILING_AUDIO)
		await RenderingServer.frame_post_draw
		if !encoder.send_audio(encode_audio()):
			stop_encoder()
			update_encoder_status.emit(STATUS.ERROR_AUDIO)
			await RenderingServer.frame_post_draw
			return printerr("RenderManager: Something went wrong sending audio!")

	# Sending the video frame data.
	update_encoder_status.emit(STATUS.SENDING_FRAMES)

	var thread: Thread = Thread.new()
	var frame_pos: int = 0
	var frame_array: Array[Image] = []
	frame_array.resize(buffer_size)

	# Because of labels and other draw() stuff which takes a frame to show, we
	# need to prepare the data in one frame and show it in the next frame.
	EditorCore.set_frame(0) # We set the first frame data ready.
	await EditorCore.frame_changed # View should be ready.
	EditorCore.set_frame(1) # We prepare the second frame data directly.

	for i: int in project_data.timeline_end + 1:
		if cancel_encoding:
			break
		elif frame_pos == buffer_size:
			if thread.is_started():
				await thread.wait_to_finish()
			if thread.start(_send_frames.bind(frame_array.duplicate())):
				printerr("RenderManager: Something with encoder thread went wrong!")

			update_encoder_status.emit(STATUS.FRAMES_SEND)
			frame_array.fill(null)
			frame_pos = 0

		await get_tree().process_frame
		frame_array[frame_pos] = viewport.get_image()
		frame_pos += 1

		if i + 1 <= project_data.timeline_end:
			await EditorCore.frame_changed
			if i + 2 <= project_data.timeline_end:
				EditorCore.set_frame(i + 2)

	# Flushing the system.
	if thread.is_alive() or thread.is_started():
		await thread.wait_to_finish()
	if !frame_array.is_empty():
		if thread.start(_send_frames.bind(frame_array.duplicate())):
			printerr("RenderManager: Something with encoder thread went wrong!")
		await thread.wait_to_finish()

	if cancel_encoding:
		update_encoder_status.emit(STATUS.ERROR_CANCELED)
		await RenderingServer.frame_post_draw
		return stop_encoder()

	update_encoder_status.emit(STATUS.LAST_FRAMES)
	await RenderingServer.frame_post_draw
	encoder.close()

	encoding_time = Time.get_ticks_msec() - start_time
	update_encoder_status.emit(STATUS.FINISHED)
	await RenderingServer.frame_post_draw

	if proxies_used:
		Settings.set_use_proxies(true) # Might give a second or so lag.
	DisplayServer.window_set_vsync_mode(_original_vsync_mode)


func stop_encoder() -> void:
	if encoder.is_open():
		encoder.close()
	if proxies_used:
		Settings.set_use_proxies(true)
	cancel_encoding = false


func _send_frames(frame_array: Array[Image]) -> void:
	for frame: Image in frame_array:
		if frame == null:
			break # No more frames to be send.
		if !encoder.send_frame(frame):
			stop_encoder()
			return printerr("RenderManager: Something went wrong sending frame(s)!")


# --- Audio handling ---

func encode_audio() -> PackedByteArray:
	var audio: PackedByteArray = []
	var frames: int = project_data.timeline_end + 1
	var framerate: float = project_data.framerate
	var length: int = Utils.get_sample_count(frames, framerate)
	audio.resize(length)

	for track: int in TrackLogic.tracks.size():
		if TrackLogic.tracks[track].is_muted:
			continue
		_add_track_audio(audio, track, length)
	return audio


func _add_track_audio(audio: PackedByteArray, track: int, length: int) -> void:
	var track_audio: PackedByteArray = []
	track_audio.resize(length)
	for clip: ClipData in TrackLogic.track_clips[track].clips:
		if clip.type not in EditorCore.AUDIO_TYPES:
			continue
		_handle_audio(clip, track_audio)
	audio = Audio.combine_data(audio, track_audio)


func _handle_audio(clip: ClipData, track_audio: PackedByteArray) -> void:
	var framerate: float = project_data.framerate
	var samples_per_frame: float = MIX_RATE / framerate
	var audio_data: PackedByteArray = ClipLogic.get_audio_data(clip)
	if audio_data.is_empty():
		return

	var fade_in: int = clip.effects.fade_audio.x
	var fade_out: int = clip.effects.fade_audio.y

	# First apply fades.
	if fade_in > 0 or fade_out > 0:
		var fade_in_samples: int = floori(fade_in * samples_per_frame)
		var fade_out_samples: int = floori(fade_out * samples_per_frame)
		audio_data = Audio.apply_fade(audio_data, fade_in_samples, fade_out_samples)

	# Apply all other effects to the clip audio data.
	for effect: EffectAudio in clip.effects.audio:
		if !effect.is_enabled:
			continue

		match effect.id:
			"volume": audio_data = _apply_effect_volume(audio_data, effect)
			_: printerr("RenderManager: Unknown effect '%s'!" % effect.nickname)

	# Place in correct position
	var clip_start: int = clip.start
	var start_sample: int = Utils.get_sample_count(clip_start, framerate)
	if start_sample + audio_data.size() > track_audio.size(): # Shouldn't happen.
		var extra: int = (start_sample + audio_data.size()) - track_audio.size()
		audio_data.resize(audio_data.size() - extra)
		printerr("RenderManager: It happened!")

	# TODO: Do this in C++!
	for i: int in audio_data.size():
		if start_sample + i < track_audio.size():
			track_audio[start_sample + i] = audio_data[i]


func _apply_effect_volume(audio_data: PackedByteArray, effect: EffectAudio) -> PackedByteArray:
	# TODO: Move this to the GDExtension
	var stream: StreamPeerBuffer = StreamPeerBuffer.new()
	stream.data_array = audio_data

	var sample_count: int = floori(audio_data.size() / 4.0) # 16 bit stereo
	var framerate: float = project_data.framerate
	var volume_param: EffectParam = effect.params[0]

	for i: int in sample_count:
		var current_sample_time_sec: float = float(i) / MIX_RATE
		var relative_frame: int = int(current_sample_time_sec * framerate)
		var volume_db: float = effect.get_value(volume_param, relative_frame)
		var volume_linear: float = db_to_linear(volume_db)

		stream.seek(i * 4) # Read samples
		var left: int = stream.get_16()
		var right: int = stream.get_16()

		# Apply volume
		left = clampi(int(left * volume_linear), AUDIO_MIN, AUDIO_MAX)
		right = clampi(int(right * volume_linear), AUDIO_MIN, AUDIO_MAX)

		# Write changes
		stream.seek(i * 4)
		stream.put_16(left)
		stream.put_16(right)

	return stream.data_array
