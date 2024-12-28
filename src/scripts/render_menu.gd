class_name RenderMenu extends Window

@export var main_menu: VBoxContainer
@export var render_label: Label
@export var close_button: Button

@export_category("Options")
@export var render_path: LineEdit

static var is_rendering: bool = false

var renderer: Renderer = Renderer.new()
var err: int = 0



func _ready() -> void:
	main_menu.visible = true
	render_label.visible = false
	close_button.visible = false


func _on_render_button_pressed() -> void:
	var l_start_time: int = Time.get_ticks_usec()
	is_rendering = true

	main_menu.visible = false
	render_label.visible = true

	# Setting renderer options
	var l_path: String = render_path.text

	if !l_path.ends_with(".mp4"):
		l_path += ".mp4"

	renderer.set_path(l_path)
	renderer.set_framerate(30)
	renderer.set_bit_rate(80000000)
	renderer.set_resolution(Vector2i(1920, 1080))
	renderer.set_video_codec_id(renderer.V_MPEG4)

	# Rendering the audio
	var l_audio: PackedByteArray = _render_audio()

	err = renderer.open()
	if err:
		GoZenError.print_error(err) # TODO: Do something to handle the error
		
	if l_audio.size() != 0:
		err = renderer.send_audio(l_audio)
		print(err)
		if err:
			GoZenError.print_error(err)
			print("Something went wrong sending audio to renderer!")

	# Render logic for visuals
	for i: int in Project.timeline_end:
		ViewPanel.instance._set_frame(i, true)

		# We need to wait else getting the image doesn't work
		await RenderingServer.frame_post_draw
		err = renderer.send_frame(ViewPanel.instance.get_view_image())
		if err:
			GoZenError.print_error(err) # TODO: Do something to handle the error

	await RenderingServer.frame_post_draw

	renderer.close()

	# After rendering show button
	render_label.visible = false
	close_button.visible = true
	is_rendering = false

	print("Rendering video (", float(Project.timeline_end) / float(Project.framerate),
			" seconds) took ", Time.get_ticks_usec() - l_start_time)


func _on_close_button_pressed() -> void:
	_on_close_requested()


func _on_close_requested() -> void:
	is_rendering = false
	self.queue_free()


func _render_audio() -> PackedByteArray:
	var l_audio: PackedByteArray = []

	for l_track_id: int in Project.tracks.size():
		var l_track_audio: PackedByteArray = []

		for l_frame_point: int in Project.tracks[l_track_id].keys():
			var l_clip: ClipData = Project.clips[Project.tracks[l_track_id][l_frame_point]]

			if l_clip.type in ViewPanel.AUDIO_TYPES:
				# Check if we need to add empty data to track_audio
				if l_track_audio.size() != l_clip.start_frame * AudioHandler.bytes_per_frame:
					if l_track_audio.resize(l_clip.start_frame * AudioHandler.bytes_per_frame):
						printerr("Couldn't resize l_track_audio!")
						print("resized array")

				# Add the data to l_track_audio
				l_track_audio.append_array(l_clip.get_audio())

			# Check if audio is empty or not
			if l_track_audio.size() == 0:
				continue

			# check for mistakes
			if l_track_audio.size() > (Project.timeline_end + 1) * AudioHandler.bytes_per_frame:
				printerr("Too much audio data!")

			# Resize the last parts to equal the size to timeline_end
			if l_track_audio.resize((Project.timeline_end + 1) * AudioHandler.bytes_per_frame):
				printerr("Couldn't resize l_track_audio!")

		if l_audio.size() == 0:
			l_audio = l_track_audio
		elif l_audio.size() == l_track_audio.size():
			l_audio = Audio.combine_data(l_audio, l_track_audio)

	if l_audio.size() != 0:
		renderer.set_audio_codec_id(Renderer.A_AAC)
		renderer.set_sample_rate(44100)

	# Check for the total audio length
	#print((float(l_audio.size()) / AudioHandler.bytes_per_frame) / 30)
	
	return l_audio
