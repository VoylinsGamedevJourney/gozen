class_name RenderLayout extends VBoxContainer

@export var render_path: LineEdit

static var is_rendering: bool = false

var renderer: Renderer = Renderer.new()
@onready var frame_texture: ViewportTexture = View.main_view.get_texture() 



func _on_render_button_pressed() -> void:
	var l_start_time: int = Time.get_ticks_usec()
	is_rendering = true

	# Setting renderer options
	var l_path: String = render_path.text

	if !l_path.ends_with(".mp4"):
		l_path += ".mp4"

	renderer.set_path(l_path)
	renderer.set_framerate(30)
	renderer.set_resolution(Vector2i(1920, 1080))
	renderer.configure_for_youtube()
	renderer.set_sample_rate(44100)

	# Rendering the audio
	print("Creating audio ...")
	var l_audio: PackedByteArray = AudioHandler.render_audio()

	if l_audio.size() != 0:
		renderer.set_audio_codec_id(Renderer.A_AAC)

	if renderer.open():
		printerr("Couldn't open renderer!")
		return
		
	if l_audio.size() != 0:
		if !renderer.send_audio(l_audio):
			printerr("Something went wrong sending audio to renderer!")
			return
	else:
		renderer.disable_audio()

	# Render logic for visuals
	print("Generating frames ...")
	for i: int in Project.timeline_end:
		View._set_frame(i, true)

		# We need to wait else getting the image doesn't work
		await RenderingServer.frame_post_draw
		if !renderer.send_frame(frame_texture.get_image()):
			printerr("Couldn't send frame to renderer!")
			return

	await RenderingServer.frame_post_draw

	renderer.close()
	is_rendering = false

	print("Rendering video (", "%.2f" % (float(Project.timeline_end) / float(Project.framerate)),
			" seconds) took ", "%.2f" % (float(Time.get_ticks_usec() - l_start_time) / 1000000), " seconds.")

