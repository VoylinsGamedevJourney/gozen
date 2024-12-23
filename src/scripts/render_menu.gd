extends Window

@export var main_menu: VBoxContainer
@export var render_label: Label
@export var close_button: Button

@export_category("Options")
@export var render_path: LineEdit


var renderer: Renderer = Renderer.new()
var err: int = 0



func _ready() -> void:
	main_menu.visible = true
	render_label.visible = false
	close_button.visible = false


func _on_render_button_pressed() -> void:
	var l_start_time: int = Time.get_ticks_usec()

	main_menu.visible = false
	render_label.visible = true

	# Setting renderer options
	var l_path: String = render_path.text

	if !l_path.ends_with(".mp4"):
		l_path += ".mp4"

	renderer.set_path(l_path)
	renderer.set_bit_rate(80000000)
	renderer.set_framerate(30)
	renderer.set_resolution(Vector2i(1920, 1080))
	renderer.set_video_codec_id(renderer.V_H264)

	err = renderer.open()
	if err:
		GoZenError.print_error(err) # TODO: Do something to handle the error

	# Render logic
	for i: int in Project.timeline_end:
		print("handling frame ", i)
		if i == 0:
			ViewPanel.instance._force_set_frame(0)
		else:
			ViewPanel.instance._set_frame()

		# We need to wait else getting the image doesn't work
		await RenderingServer.frame_post_draw
		err = renderer.send_frame(ViewPanel.instance.get_view_image())
		if err:
			GoZenError.print_error(err) # TODO: Do something to handle the error

	await RenderingServer.frame_post_draw

	# TODO: Add audio

	renderer.close()

	# After rendering show button
	render_label.visible = false
	close_button.visible = true
	print("Rendering video (", float(Project.timeline_end) / float(Project.framerate),
			" seconds) took ", Time.get_ticks_usec() - l_start_time)


func _on_close_button_pressed() -> void:
	_on_close_requested()


func _on_close_requested() -> void:
	self.queue_free()

