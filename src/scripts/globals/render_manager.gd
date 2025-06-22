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


var encoder: Encoder
var viewport: ViewportTexture

var cancel_encoding: bool = false
var start_time: int = 0
var encoding_time: int = 0

var buffer_size: int = 5



func stop_encoder() -> void:
	if encoder.is_open():
		encoder.close()
	cancel_encoding = false


func start() -> void:
	if encoder != null and encoder.is_open():
		printerr("Can't encode whilst another encoder is still busy!")
		return
	if viewport == null:
		viewport = EditorCore.viewport.get_texture()

	print("Encoder is preparing ...")
	update_encoder_status.emit(STATUS.SETUP)
	await RenderingServer.frame_post_draw
	start_time = Time.get_ticks_msec()
	encoding_time = 0

	if !encoder.open():
		stop_encoder()
		printerr("Couldn't open encoder!")
		update_encoder_status.emit(STATUS.ERROR_OPEN)
		await RenderingServer.frame_post_draw
		return

	# Creating + sending audio
	if encoder.audio_codec_set():
		print("Encoder is compiling audio ...")
		update_encoder_status.emit(STATUS.COMPILING_AUDIO)
		await RenderingServer.frame_post_draw

		var audio_data: PackedByteArray = encode_audio()

		if !encoder.send_audio(audio_data):
			stop_encoder()
			update_encoder_status.emit(STATUS.ERROR_AUDIO)
			await RenderingServer.frame_post_draw
			printerr("Something went wrong sending audio!")
			return

	# Sending the frame data.
	EditorCore.set_frame(0)
	print("Encoder starts sending frames ...")
	update_encoder_status.emit(STATUS.SENDING_FRAMES)

	var frame_array: Array[Image] = []
	var frame_pos: int = 0
	var thread: Thread = Thread.new()

	if frame_array.resize(buffer_size):
		Toolbox.print_resize_error()

	for i: int in Project.get_timeline_end() + 1:
		if cancel_encoding: break

		if frame_pos == buffer_size:
			if thread.is_started():
				await thread.wait_to_finish()
			if thread.start(_send_frames.bind(frame_array.duplicate())):
				printerr("Something with encoder thread went wrong!")
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
			printerr("Something with encoder thread went wrong!")
		await thread.wait_to_finish()

	if cancel_encoding:
		print("Encoding got canceled.")
		update_encoder_status.emit(STATUS.ERROR_CANCELED)
		await RenderingServer.frame_post_draw
		stop_encoder()
		return

	print("Encoder processing last frame.")
	update_encoder_status.emit(STATUS.LAST_FRAMES)
	await RenderingServer.frame_post_draw
	encoder.close()

	encoding_time = Time.get_ticks_msec() - start_time
	update_encoder_status.emit(STATUS.FINISHED)
	await RenderingServer.frame_post_draw

	print("Encoding finished. Time taken (msec): ", encoding_time)


func _send_frames(frame_array: Array[Image]) -> void:
	for frame: Image in frame_array:
		if frame == null: break # No more frames to be send.
		if !encoder.send_frame(frame):
			stop_encoder()
			printerr("Something went wrong sending frame(s)!")
			return


func encode_audio() -> PackedByteArray:
	var audio: PackedByteArray = []

	if audio.resize(Toolbox.get_sample_count(Project.get_timeline_end() + 1)):
		Toolbox.print_resize_error()

	for i: int in Project.get_track_count():
		var track_audio: PackedByteArray = []
		var track_data: Dictionary[int, int] = Project.get_track_data(i)

		if track_data.size() == 0:
			continue

		for frame_point: int in Project.get_track_keys(i):
			var clip: ClipData = Project.get_clip(track_data[frame_point])
			var file: File = Project.get_file(clip.file_id)

			if file.type in EditorCore.AUDIO_TYPES:
				var sample_count: int = Toolbox.get_sample_count(clip.start_frame)

				if track_audio.size() != sample_count:
					if track_audio.resize(sample_count):
						Toolbox.print_resize_error()
				
				track_audio.append_array(clip.get_clip_audio_data())

		# Making the audio data the correct length
		if track_audio.resize(Toolbox.get_sample_count(Project.get_timeline_end() + 1)):
			Toolbox.print_resize_error()

		audio = Audio.combine_data(audio, track_audio)

	return audio

