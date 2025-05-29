class_name RenderingWindow
extends PanelContainer


const DEFAULT_RENDER_PROFILES_PATH: String = "res://render_profiles/"
const RENDER_PROFILES_PATH: String = "user://render_profiles/"


static var instance: RenderingWindow


@export var path_line_edit: LineEdit
@export var render_profiles_option_button: OptionButton
@export var render_progress_bar: ProgressBar
@export var render_warning_label: Label
@export var render_progress_label: Label
@export var advanced_render_settings: ScrollContainer

@export_group("Audio")
@export var audio_codec_option_button: OptionButton

@export_group("Video")
@export var video_grid: GridContainer
@export var video_codec_option_button: OptionButton

@export var video_quality_slider: HSlider
@export var video_speed_label: Label
@export var video_speed_slider: HSlider
@export var video_gop_spinbox: SpinBox

@export_group("Threads")
@export var threads_spinbox: SpinBox

@export_group("Metadata")
@export var render_metadata_toggle: CheckButton
@export var metadata_grid: GridContainer

@export var title_line_edit: LineEdit
@export var comment_text_edit: TextEdit
@export var author_line_edit: LineEdit
@export var copyright_line_edit: LineEdit

@export_group("Render results")
@export var render_path_label: Label
@export var render_time_taken_label: Label
@export var render_video_length_label: Label


var viewport: ViewportTexture

var renderer: Renderer = null
var render_profile: RenderProfile

var profiles: Array[RenderProfile] = []
var audio_codecs: Dictionary[Renderer.AUDIO_CODEC, String] = {
	Renderer.AUDIO_CODEC.A_WAV: "WAV",
	Renderer.AUDIO_CODEC.A_PCM: "PCM",
	Renderer.AUDIO_CODEC.A_MP3: "MP3",
	Renderer.AUDIO_CODEC.A_AAC: "AAC",
	Renderer.AUDIO_CODEC.A_OPUS: "Opus",
	Renderer.AUDIO_CODEC.A_VORBIS: "Vorbis",
	Renderer.AUDIO_CODEC.A_FLAC: "FLAC",
	Renderer.AUDIO_CODEC.A_NONE: "NONE",
}
var video_codecs: Dictionary[Renderer.VIDEO_CODEC, String] = {
	Renderer.VIDEO_CODEC.V_HEVC: "HEVC",
	Renderer.VIDEO_CODEC.V_H264: "H264",
	Renderer.VIDEO_CODEC.V_MPEG4: "MPEG4",
	Renderer.VIDEO_CODEC.V_MPEG2: "MPEG2",
	Renderer.VIDEO_CODEC.V_MPEG1: "MPEG1",
	Renderer.VIDEO_CODEC.V_MJPEG: "MJPEG",
	Renderer.VIDEO_CODEC.V_AV1: "AV1",
	Renderer.VIDEO_CODEC.V_VP9: "VP9",
	Renderer.VIDEO_CODEC.V_VP8: "VP8",
}

var is_rendering: bool = false
var cancel_rendering: bool = false



func _ready() -> void:
	instance = self
	viewport = Editor.viewport.get_texture()
	if viewport == null:
		printerr("Renderer: viewport is null!")

	if !DirAccess.dir_exists_absolute(RENDER_PROFILES_PATH):
		if DirAccess.make_dir_recursive_absolute(RENDER_PROFILES_PATH):
			printerr("Couldn't create folder at %s!" % RENDER_PROFILES_PATH)

	show_window(0)
	advanced_render_settings.visible = false
	threads_spinbox.max_value = OS.get_processor_count()

	# Loading default render profiles.
	var id_youtube_profile: int = -1
	for profile_file: String in ResourceLoader.list_directory(DEFAULT_RENDER_PROFILES_PATH):
		# In exported builds, there are more files than only the .tres files.
		profiles.append(ResourceLoader.load(DEFAULT_RENDER_PROFILES_PATH + profile_file))
		render_profiles_option_button.add_item(profiles[-1].profile_name)

		if profiles[-1].profile_name.to_lower() == "youtube":
			id_youtube_profile = profiles.size() -1

	# Loading audio codecs.
	for id: Renderer.AUDIO_CODEC in audio_codecs.keys():
		audio_codec_option_button.add_item(audio_codecs[id], id)
	
	# Loading video codecs.
	for id: Renderer.VIDEO_CODEC in video_codecs.keys():
		video_codec_option_button.add_item(video_codecs[id], id)

	# Setting default render profile (YouTube).
	render_profiles_option_button.selected = id_youtube_profile

	load_render_profile(profiles[id_youtube_profile])
	_on_enable_metadata_check_button_toggled(false)


func _input(event: InputEvent) -> void:
	if event.is_action_pressed("ui_cancel"):
		_on_cancel_button_pressed()


func load_render_profile(profile: RenderProfile) -> void:
	# Printing info about the selected rendering profile.
	var header: Callable = (func(text: String) -> void:
			print_rich("[b]", text))
	var info: Callable = (func(title: String, context: Variant) -> void:
			print_rich("[b]", title, "[/b]: ", context))

	render_profile = profile.duplicate()

	# Printing some debug info
	header.call("Render profile selected")
	info.call("Audio codec", render_profile.audio_codec)
	info.call("Video codec", render_profile.video_codec)
	info.call("GOP", render_profile.gop)
	info.call("CRF", render_profile.crf)
	if render_profile.video_codec == Renderer.VIDEO_CODEC.V_H264:
		info.call("h264 preset", render_profile.h264_preset)

	path_line_edit.text = Project.get_project_path().get_basename() + get_extension()

	audio_codec_option_button.selected = audio_codecs.keys().find(render_profile.audio_codec)
	video_codec_option_button.selected = video_codecs.keys().find(render_profile.video_codec)

	if render_profile.video_codec != Renderer.VIDEO_CODEC.V_NONE:
		video_grid.visible = true
		video_codec_option_button.selected = render_profile.video_codec
		video_quality_slider.value = 0 - render_profile.crf # Needs to be negative for the slider.
		video_gop_spinbox.value = render_profile.gop

		if render_profile.video_codec == Renderer.VIDEO_CODEC.V_H264:
			video_speed_label.visible = true
			video_speed_slider.visible = true
			video_speed_slider.value = render_profile.h264_preset
		else:
			video_speed_label.visible = false
			video_speed_slider.visible = false
	else:
		video_grid.visible = false


func _on_select_save_path_button_pressed() -> void:
	var dialog: FileDialog = Toolbox.get_file_dialog(
			"Select save path", FileDialog.FileMode.FILE_MODE_SAVE_FILE, [get_extension()])

	Toolbox.connect_func(dialog.file_selected, _save_path_selected)

	add_child(dialog)
	dialog.popup_centered()


func _save_path_selected(file_path: String) -> void:
	path_line_edit.text = file_path


func _on_save_render_profile_button_pressed() -> void:
	pass # TODO: Bring up a popup to select under what name you want to save it.
		  		# Also check if it's overriding an already existing one. Only custom profiles
		  		# can be overriden.


func _on_enable_metadata_check_button_toggled(toggled_on: bool) -> void:
	metadata_grid.visible = toggled_on


func _on_cancel_button_pressed() -> void:
	if is_rendering:
		renderer.close()

	self.queue_free()


func _on_render_button_pressed() -> void:
	var threads: int = maxi(0, threads_spinbox.value as int)

	# Printing info about the rendering process.
	var header: Callable = (func(text: String) -> void:
			print_rich("[b]", text))
	var info: Callable = (func(title: String, context: Variant) -> void:
			print_rich("[b]", title, "[/b]: ", context))

	header.call("Rendering process started")
	info.call("Path", path_line_edit.text)
	info.call("Resolution", Project.get_resolution())
	info.call("Audio codec", render_profile.audio_codec)
	info.call("Video codec", render_profile.video_codec)
	info.call("GOP", render_profile.gop)
	info.call("CRF", render_profile.crf)
	info.call("Cores/threads", threads)
	if render_profile.video_codec == Renderer.VIDEO_CODEC.V_H264:
		info.call("h264 preset", render_profile.h264_preset)
	info.call("Frames to process", Project.get_timeline_end() + 1)

	# Preparing the UI.
	render_warning_label.visible = false
	render_progress_label.visible = true
	render_progress_bar.max_value = Project.get_timeline_end()
	render_progress_bar.value = 0
	render_progress_label.text = tr("renderer_progress_text_setup")
	print("Renderer is preparing ...")

	show_window(1)
	await RenderingServer.frame_post_draw

	var start_time: int = Time.get_ticks_usec()
	is_rendering = true
	renderer = Renderer.new()
	renderer.enable_debug()

	# Setting all data into the renderer.
	renderer.set_file_path(path_line_edit.text)
	renderer.set_resolution(Project.get_resolution())
	renderer.set_audio_codec_id(render_profile.audio_codec)
	renderer.set_video_codec_id(render_profile.video_codec)
	renderer.set_gop_size(render_profile.gop)
	renderer.set_crf(render_profile.crf) # Slider has a negative value
	renderer.set_sws_quality(Renderer.SWS_QUALITY_BILINEAR)
	renderer.set_threads(threads)
	if render_profile.video_codec == Renderer.VIDEO_CODEC.V_H264:
		renderer.set_h264_preset(render_profile.h264_preset)

	# Adding metadata if necessary.
	if render_metadata_toggle.button_pressed:
		var title: String = title_line_edit.text
		var comment: String = comment_text_edit.text
		var author: String = author_line_edit.text
		var copyright: String = copyright_line_edit.text

		if title != "":
			renderer.set_video_meta_title(title)
		if comment != "":
			renderer.set_video_meta_comment(comment)
		if author != "":
			renderer.set_video_meta_author(author)
		if copyright != "":
			renderer.set_video_meta_copyright(copyright)

	# Check if rendering is possible or not.
	if !renderer.open():
		render_warning_label.visible = true
		render_progress_label.visible = false
		render_warning_label.text = "renderer_progress_text_open_error"
		printerr("Renderer could not open!")
		printerr("Something went wrong and rendering isn't possible!")
		is_rendering = false
		return

	render_progress_bar.max_value = Project.get_timeline_end() + 8
	render_progress_bar.value = 0
	await RenderingServer.frame_post_draw

	# Adding the audio (if needed).
	if render_profile.audio_codec != Renderer.AUDIO_CODEC.A_NONE:
		render_progress_bar.value += 1
		render_progress_label.text = "renderer_progress_text_compiling_audio"
		render_progress_bar.value += 4
		print("Renderer is compiling audio ...")
		await RenderingServer.frame_post_draw

		if !renderer.send_audio(render_audio()):
			render_warning_label.visible = true
			render_progress_label.visible = false
			render_warning_label.text = "renderer_progress_text_sending_audio_error"
			renderer.close()
			printerr("Something went wrong sending audio!")
			is_rendering = false
			return

	# Sending the frame data.
	Editor.set_frame(0)
	render_progress_label.text = "renderer_progress_text_creating_sending_data"
	print("Renderer starts sending frames ...")

	for i: int in Project.get_timeline_end() + 1:
		if cancel_rendering:
			break;
		await RenderingServer.frame_post_draw

		if !renderer.send_frame(viewport.get_image()):
			render_warning_label.visible = true
			render_progress_label.visible = false
			render_warning_label.text = "renderer_progress_text_sending_data_error"
			renderer.close()
			printerr("Something went wrong sending frame!")
			is_rendering = false
			return
		render_progress_bar.value += 1
		Editor.set_frame() # Getting the next frame in line.

	if cancel_rendering:
		render_progress_label.text = "renderer_progress_text_canceling"
		print("Renderer got canceled.")
		await RenderingServer.frame_post_draw

		renderer.close()
		is_rendering = false
		cancel_rendering = false
		await RenderingServer.frame_post_draw
		show_window(0)
		return

	render_progress_label.text = "renderer_progress_text_last_frame"
	print("Renderer processing last frame.")
	await RenderingServer.frame_post_draw
	render_progress_bar.value += 1
	await RenderingServer.frame_post_draw
	render_progress_bar.value += 1
	await RenderingServer.frame_post_draw
	render_progress_label.text = "renderer_progress_text_finilizing"
	print("Renderer finalizing ...")
	await RenderingServer.frame_post_draw

	renderer.close()
	is_rendering = false

	render_path_label.text = path_line_edit.text
	render_path_label.tooltip_text = path_line_edit.text

	render_time_taken_label.text = Toolbox.format_time_str(
			float(float(Time.get_ticks_usec() - start_time) / 1000000))
	render_video_length_label.text = Toolbox.format_time_str_from_frame(
			Project.get_timeline_end() + 1)
	show_window(2)
	print("Renderer finished.")


func get_extension(profile: RenderProfile = render_profile) -> String:
	match profile.video_codec:
		Renderer.VIDEO_CODEC.V_HEVC: return ".mp4"
		Renderer.VIDEO_CODEC.V_H264: return ".mp4"
		Renderer.VIDEO_CODEC.V_MPEG4: return ".mp4"
		Renderer.VIDEO_CODEC.V_MPEG2: return ".mpg"
		Renderer.VIDEO_CODEC.V_MPEG1: return ".mpg"
		Renderer.VIDEO_CODEC.V_MJPEG: return ".mov"
		Renderer.VIDEO_CODEC.V_AV1: return ".webm"
		Renderer.VIDEO_CODEC.V_VP9: return ".webm"
		Renderer.VIDEO_CODEC.V_VP8: return ".webm"

	printerr("Unrecognized codec! ", profile.video_codec)
	return ""


func _on_render_profiles_option_button_item_selected(index: int) -> void:
	load_render_profile(profiles[index])


func _on_audio_codec_option_button_item_selected(index: int) -> void:
	render_profile.audio_codec = audio_codec_option_button.get_item_id(index) as Renderer.AUDIO_CODEC


func _on_video_codec_option_button_item_selected(index: int) -> void:
	render_profile.video_codec = video_codec_option_button.get_item_id(index) as Renderer.VIDEO_CODEC

	if render_profile.video_codec == Renderer.VIDEO_CODEC.V_H264:
		video_speed_label.visible = true
		video_speed_slider.visible = true
		video_speed_slider.value = render_profile.h264_preset
	else:
		video_speed_label.visible = false
		video_speed_slider.visible = false

	path_line_edit.text = path_line_edit.text.get_basename() + get_extension()


func _on_quality_h_slider_drag_ended(value_changed: bool) -> void:
	if value_changed:
		render_profile.crf = int(0 - video_quality_slider.value)


func _on_speed_h_slider_drag_ended(value_changed:bool) -> void:
	if value_changed:
		render_profile.h264_preset = int(video_speed_slider.value) as Renderer.H264_PRESETS

	
func _on_gop_size_spin_box_value_changed(value: float) -> void:
	render_profile.gop = int(value)


func render_audio() -> PackedByteArray:
	var audio: PackedByteArray = []

	if audio.resize(get_sample_count(Project.get_timeline_end() + 1)):
		Toolbox.print_resize_error()

	for i: int in Project.get_track_count():
		var track_audio: PackedByteArray = []
		var track_data: Dictionary[int, int] = Project.get_track_data(i)

		if track_data.size() == 0:
			continue

		for frame_point: int in Project.get_track_keys(i):
			var clip: ClipData = Project.get_clip(track_data[frame_point])
			var file: File = Project.get_file(clip.file_id)

			if file.type in Editor.AUDIO_TYPES:
				var sample_count: int = get_sample_count(clip.start_frame)

				if track_audio.size() != sample_count:
					if track_audio.resize(sample_count):
						Toolbox.print_resize_error()
				
				track_audio.append_array(clip.get_clip_audio_data())

		# Making the audio data the correct length
		if track_audio.resize(get_sample_count(Project.get_timeline_end() + 1)):
			Toolbox.print_resize_error()

		audio = Audio.combine_data(audio, track_audio)

	return audio


func show_window(nr: int) -> void:
	for i: int in get_child_count():
		if get_child(i) is PanelContainer:
			(get_child(i) as PanelContainer).visible = nr == i


static func get_sample_count(frames: int) -> int:
	return int(44100 * 4 * float(frames) / Project.get_framerate())


func _on_check_button_toggled(toggled_on:bool) -> void:
	advanced_render_settings.visible = toggled_on


func _on_cancel_render_button_pressed() -> void:
	cancel_rendering = true

	if !is_rendering:
		show_window(0)


func _on_close_button_pressed() -> void:
	self.queue_free()


func _on_return_button_pressed() -> void:
	show_window(0)

