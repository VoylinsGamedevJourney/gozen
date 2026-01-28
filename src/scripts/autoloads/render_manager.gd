extends Node

# TODO: https://trac.ffmpeg.org/wiki/Encode/HighQualityAudio

# The integers are for the progress bar, except for negative numbers, those are
# for indicating to the rendering menu that something went wrong.
enum STATUS {
	ERROR_OPEN = -1, # encoding_progress_text_open_error
	ERROR_AUDIO = -2, # encoding_progress_text_sending_audio_error
	ERROR_CANCELED = -3, # encoding_progress_text_canceling

	SETUP = 0, # encoding_progress_text_setup
	COMPILING_AUDIO = 3, # encoding_progress_text_compiling_audio
	SENDING_AUDIO = 4, # encoding_progress_text_compiling_audio
	SENDING_FRAMES = 5, # encoding_progress_text_creating_sending_data
	FRAMES_SEND = 6,
	LAST_FRAMES = 99, # encoding_progress_text_last_frame
	FINISHED = 100,
}

signal update_encoder_status(status: STATUS)


var encoder: GoZenEncoder
var viewport: ViewportTexture

var cancel_encoding: bool = false
var start_time: int = 0
var encoding_time: int = 0

var buffer_size: int = 5

var proxies_used: bool



func stop_encoder() -> void:
	if encoder.is_open():
		encoder.close()
	if proxies_used:
		print("RenderManager: Re-enabling proxies ...")
		Settings.set_use_proxies(true)

	cancel_encoding = false


func start() -> void:
	if encoder != null and encoder.is_open():
		printerr("RenderManager: Can't encode whilst another encoder is still busy!")
		return
	if viewport == null:
		viewport = EditorCore.viewport.get_texture()

	# Making certain proxies aren't being used for this
	proxies_used = Settings.get_use_proxies()

	if proxies_used:
		print("RenderManager: Disabling proxies for rendering ...")
		Settings.set_use_proxies(false)

		# Necessary waiting time to make certain all clips are ready.
		await RenderingServer.frame_post_draw
		await get_tree().process_frame

	# Setup encoder
	update_encoder_status.emit(STATUS.SETUP)
	await RenderingServer.frame_post_draw
	start_time = Time.get_ticks_msec()
	encoding_time = 0

	if !encoder.open(viewport.get_image().get_format() == Image.FORMAT_RGBA8):
		stop_encoder()
		printerr("RenderManager: Couldn't open encoder!")
		update_encoder_status.emit(STATUS.ERROR_OPEN)
		await RenderingServer.frame_post_draw
		return

	# Creating + sending audio
	if encoder.audio_codec_set():
		update_encoder_status.emit(STATUS.COMPILING_AUDIO)
		await RenderingServer.frame_post_draw

		var audio_data: PackedByteArray = encode_audio()

		if !encoder.send_audio(audio_data):
			stop_encoder()
			update_encoder_status.emit(STATUS.ERROR_AUDIO)
			await RenderingServer.frame_post_draw
			printerr("RenderManager: Something went wrong sending audio!")
			return

	# Sending the frame data.
	EditorCore.set_frame(0)
	update_encoder_status.emit(STATUS.SENDING_FRAMES)

	var frame_array: Array[Image] = []
	var frame_pos: int = 0
	var thread: Thread = Thread.new()

	frame_array.resize(buffer_size)

	for i: int in Project.get_timeline_end() + 1:
		if cancel_encoding: break

		if frame_pos == buffer_size:
			if thread.is_started():
				await thread.wait_to_finish()
			if thread.start(_send_frames.bind(frame_array.duplicate())):
				printerr("RenderManager: Something with encoder thread went wrong!")
			update_encoder_status.emit(STATUS.FRAMES_SEND)
			frame_array.fill(null)
			frame_pos = 0

		await RenderingServer.frame_post_draw
		frame_array[frame_pos] = viewport.get_image()
		frame_pos += 1
		EditorCore.set_frame() # Getting the next frame ready.

	if thread.is_alive() or thread.is_started():
		await thread.wait_to_finish()
	if frame_array.size() != 0:
		if thread.start(_send_frames.bind(frame_array.duplicate())):
			printerr("RenderManager: Something with encoder thread went wrong!")
		await thread.wait_to_finish()

	if cancel_encoding:
		update_encoder_status.emit(STATUS.ERROR_CANCELED)
		await RenderingServer.frame_post_draw
		stop_encoder()
		return

	update_encoder_status.emit(STATUS.LAST_FRAMES)
	await RenderingServer.frame_post_draw
	encoder.close()

	encoding_time = Time.get_ticks_msec() - start_time
	update_encoder_status.emit(STATUS.FINISHED)
	await RenderingServer.frame_post_draw

	if proxies_used:
		print("RenderManager: Re-enabling proxies ...")
		Settings.set_use_proxies(true)


func _send_frames(frame_array: Array[Image]) -> void:
	for frame: Image in frame_array:
		if frame == null: break # No more frames to be send.
		if !encoder.send_frame(frame):
			stop_encoder()
			printerr("RenderManager: Something went wrong sending frame(s)!")
			return


func encode_audio() -> PackedByteArray:
	var audio: PackedByteArray = []
	var full_audio_length: int = Utils.get_sample_count(
			Project.get_timeline_end() + 1, Project.get_framerate())

	audio.resize(full_audio_length)

	for i: int in Project.get_track_count():
		for clip_id: int in Project.get_track_data(i).values():
			if ClipHandler.get_type(clip_id) not in EditorCore.AUDIO_TYPES:
				continue

			# Audio is present so we can get all the track audio.
			audio = _add_track_audio(audio, i, full_audio_length)

			break

	return audio


func _add_track_audio(audio: PackedByteArray, track_id: int, full_length: int) -> PackedByteArray:
	var track_audio: PackedByteArray = []
	var track: TrackData = Project.get_track_data(track_id)

	for frame_nr: int in track.get_frame_nrs():
		var clip: ClipData = ClipHandler.get_clip(track.get_clip_id(frame_nr))
		var file: File = FileHandler.get_file(clip.file_id)

		if file.type in EditorCore.AUDIO_TYPES:
			track_audio = _handle_audio(clip, track_audio)

	# Making the audio data the correct length
	track_audio.resize(full_length)

	return GoZenAudio.combine_data(audio, track_audio)


func _handle_audio(clip_data: ClipData, track_audio: PackedByteArray) -> PackedByteArray:
	# Getting the raw clip audio data
	var audio_data: PackedByteArray = ClipHandler.get_clip_audio_data(clip_data.id, clip_data)
	var framerate: float = Project.get_framerate()

	if clip_data.fade_in_audio > 0 or clip_data.fade_out_visual > 0:
		audio_data = _apply_audio_fade(audio_data, clip_data)

	# Apply all available effects to the clip audio data
	for effect: GoZenEffectAudio in clip_data.effects_audio:
		match effect.effect_id:
			"volume": audio_data = _apply_effect_volume(audio_data, effect)
			_: printerr("RenderManager: Unknown effect '%s'!" % effect.effect_name)

	var start_sample: int = Utils.get_sample_count(clip_data.start_frame - 1, framerate)

	# Resize the audio data so we're certain the audio will be
	# added at the correct moment.
	# TODO: Check if we should do -1 of clip.start_frame in start_sample incase
	# the audio starts one sample too late
	if start_sample != 0 and track_audio.size() != start_sample:
		track_audio.resize(start_sample)

	# Add the data to the track audio and send back
	track_audio.append_array(clip_data.get_clip_audio_data())
	return track_audio


func _apply_effect_volume(audio_data: PackedByteArray, effect: GoZenEffectAudio) -> PackedByteArray:
	# TODO: Move this to the GDExtension
	var stream: StreamPeerBuffer = StreamPeerBuffer.new()
	stream.data_array = audio_data

	var sample_count: int = floori(audio_data.size() / 4.0) # 16 bit stereo
	var framerate: float = Project.get_framerate()
	var volume_param: EffectParam = effect.params[0]

	for i: int in sample_count:
		var current_sample_time_sec: float = float(i) / 44100.0
		var relative_frame: int = int(current_sample_time_sec * framerate)

		var volume_db: float = effect.get_value(volume_param, relative_frame)
		var volume_linear: float = db_to_linear(volume_db)

		# Read samples
		stream.seek(i * 4)

		var left_channel: int = stream.get_16()
		var right_channel: int = stream.get_16()

		# Apply volume
		left_channel = clampi(int(left_channel * volume_linear), -32768, 32767)
		right_channel = clampi(int(right_channel * volume_linear), -32768, 32767)

		# Write changes
		stream.seek(i * 4)
		stream.put_16(left_channel)
		stream.put_16(right_channel)

	return stream.data_array


func _apply_audio_fade(audio_data: PackedByteArray, clip: ClipData) -> PackedByteArray:
	var samples_per_frame: float = 44100.0 / Project.get_framerate()
	var fade_in_samples: int = int(clip.fade_in_audio * samples_per_frame)
	var fade_out_samples: int = int(clip.fade_out_audio * samples_per_frame)

	return GoZenAudio.apply_fade(audio_data, fade_in_samples, fade_out_samples)
