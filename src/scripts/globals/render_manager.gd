extends Node

# The integers are for the progress bar, except for negative numbers, those are
# for indicating to the rendering menu that something went wrong.
enum STATUS {
	ERROR_OPEN = -1, # renderer_progress_text_open_error
	ERROR_AUDIO = -2, # renderer_progress_text_sending_audio_error
	ERROR_CANCELED = -3, # renderer_progress_text_canceling

	SETUP = 0, # renderer_progress_text_setup
	COMPILING_AUDIO = 3, # renderer_progress_text_compiling_audio
	SENDING_AUDIO = 4, # renderer_progress_text_compiling_audio
	SENDING_FRAMES = 5, # renderer_progress_text_creating_sending_data
	FRAMES_SEND = 6,
	LAST_FRAMES = 99, # renderer_progress_text_last_frame
	FINISHED = 100,
}

signal renderer_status(status: STATUS)


var renderer: Renderer
var viewport: ViewportTexture

var cancel_rendering: bool = false
var start_time: int = 0
var render_time: int = 0



func stop_render() -> void:
	if renderer.is_open():
		renderer.close()
	cancel_rendering = false


func start() -> void:
	if renderer != null and renderer.is_open():
		printerr("Can't render whilst another renderer is still busy!")
		return
	if viewport == null:
		viewport = EditorCore.viewport.get_texture()

	print("Renderer are preparing ...")
	renderer_status.emit(STATUS.SETUP)
	await RenderingServer.frame_post_draw
	start_time = Time.get_ticks_msec()
	render_time = 0

	if !renderer.open():
		stop_render()
		printerr("Couldn't open renderer!")
		renderer_status.emit(STATUS.ERROR_OPEN)
		await RenderingServer.frame_post_draw
		return

	# Creating + sending audio
	if renderer.audio_codec_set():
		print("Renderer is compiling audio ...")
		renderer_status.emit(STATUS.COMPILING_AUDIO)
		await RenderingServer.frame_post_draw

		var audio_data: PackedByteArray = render_audio()

		if !renderer.send_audio(audio_data):
			stop_render()
			renderer_status.emit(STATUS.ERROR_AUDIO)
			await RenderingServer.frame_post_draw
			printerr("Something went wrong sending audio!")
			return

	# Sending the frame data.
	EditorCore.set_frame(0)
	print("Renderer starts sending frames ...")
	renderer_status.emit(STATUS.SENDING_FRAMES)

	var frame_array_size: int = floori(Project.get_framerate())
	var frame_array: Array[Image] = []
	var frame_pos: int = 0
	var thread: Thread = Thread.new()

	if frame_array.resize(frame_array_size):
		Toolbox.print_resize_error()

	for i: int in Project.get_timeline_end() + 1:
		if cancel_rendering: break
		await RenderingServer.frame_post_draw

		if frame_pos == frame_array_size:
			if thread.is_started():
				await thread.wait_to_finish()
			if thread.start(_send_frames.bind(frame_array.duplicate())):
				printerr("Something with rendering thread went wrong!")
			renderer_status.emit(STATUS.FRAMES_SEND)
			frame_array.fill(null)
			frame_pos = 0

		frame_array[frame_pos] = viewport.get_image()
		frame_pos += 1
		EditorCore.set_frame() # Getting the next frame in line.

	if thread.is_alive() or thread.is_started():
		await thread.wait_to_finish()
	if frame_array.size() != 0:
		if thread.start(_send_frames.bind(frame_array.duplicate())):
			printerr("Something with rendering thread went wrong!")
		await thread.wait_to_finish()

	if cancel_rendering:
		print("Renderer got canceled.")
		renderer_status.emit(STATUS.ERROR_CANCELED)
		await RenderingServer.frame_post_draw
		stop_render()
		return

	print("Renderer processing last frame.")
	renderer_status.emit(STATUS.LAST_FRAMES)
	await RenderingServer.frame_post_draw
	renderer.close()

	renderer_status.emit(STATUS.FINISHED)
	await RenderingServer.frame_post_draw

	render_time = Time.get_ticks_msec() - start_time
	print("Renderer finished. Time taken (msec): ", render_time)


func _send_frames(frame_array: Array[Image]) -> void:
	for frame: Image in frame_array:
		if frame == null: break # No more frames to be send.
		if !renderer.send_frame(frame):
			stop_render()
			printerr("Something went wrong sending frame(s)!")
			return


func render_audio() -> PackedByteArray:
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

