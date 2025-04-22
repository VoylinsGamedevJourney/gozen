class_name RenderingWindow
extends PanelContainer

# TODO: Create a way to save custom render profiles


const DEFAULT_RENDER_PROFILES_PATH: String = "res://render_profiles/"
const RENDER_PROFILES_PATH: String = "user://render_profiles/"


static var instance: RenderingWindow


@export var path_line_edit: LineEdit
@export var render_profiles_option_button: OptionButton
@export var render_progress_bar: ProgressBar
@export var render_progress_label: Label

@export_group("Audio")
@export var audio_codec_option_button: OptionButton

@export_group("Video")
@export var video_grid: GridContainer
@export var video_codec_option_button: OptionButton

@export var video_quality_slider: HSlider
@export var video_speed_label: Label
@export var video_speed_slider: HSlider
@export var video_gop_spinbox: SpinBox

@export_group("Metadata")
@export var render_metadata_toggle: CheckButton
@export var metadata_grid: GridContainer

@export var title_line_edit: LineEdit
@export var comment_text_edit: TextEdit
@export var author_line_edit: LineEdit
@export var copyright_line_edit: LineEdit


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



func _ready() -> void:
	instance = self
	viewport = Editor.viewport.get_texture()
	if viewport == null:
		printerr("Renderer: viewport is null!")

	if !DirAccess.dir_exists_absolute(RENDER_PROFILES_PATH):
		if DirAccess.make_dir_recursive_absolute(RENDER_PROFILES_PATH):
			printerr("Couldn't create folder at %s!" % RENDER_PROFILES_PATH)

	show_window(0)

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
	# TODO: Improve this so it doesn't trigger when trying to "esc" a line edit.
	if event.is_action_pressed("ui_cancel"):
		_on_cancel_button_pressed()


func load_render_profile(profile: RenderProfile) -> void:
	render_profile = profile.duplicate()

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
	self.queue_free()


func _on_render_button_pressed() -> void:
	var start_time: int = Time.get_ticks_usec()

	render_progress_bar.max_value = Project.get_timeline_end()
	render_progress_bar.value = 0
	render_progress_label.text = "Setting up renderer ..."

	show_window(1)

	is_rendering = true
	renderer = Renderer.new()
	renderer.enable_debug()

	renderer.set_file_path(path_line_edit.text)
	renderer.set_resolution(Project.get_resolution())
	renderer.set_audio_codec_id(render_profile.audio_codec)
	renderer.set_video_codec_id(render_profile.video_codec)
	renderer.set_gop_size(render_profile.gop)
	renderer.set_crf(render_profile.crf) # Slider has a negative value
	renderer.set_sws_quality(Renderer.SWS_QUALITY_BILINEAR)

	if render_profile.video_codec == Renderer.VIDEO_CODEC.V_H264:
		renderer.set_h264_preset(render_profile.h264_preset)

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

	if !renderer.open():
		printerr("Something went wrong and rendering isn't possible!")
		return

	render_progress_bar.max_value = Project.get_timeline_end() + 4
	render_progress_bar.value = 0
	render_progress_label.text = "Setting up renderer ..."

	if render_profile.audio_codec != Renderer.AUDIO_CODEC.A_NONE:
		render_progress_label.text = "Compiling audio data ..."
		if !renderer.send_audio(render_audio()):
			printerr("Something went wrong sending audio!")

	render_progress_label.text = "Creating & sending frame data ..."
	Editor.set_frame(0)

	for i: int in Project.get_timeline_end() + 1:
		await RenderingServer.frame_post_draw
		
		if !renderer.send_frame(viewport.get_image()):
			printerr("Something went wrong sending frame!")
		render_progress_bar.value += 1
		Editor.set_frame() # Getting the next frame in line.
		
	render_progress_label.text = "Sending last frames ..."
	render_progress_bar.value += 1
	render_progress_bar.value += 1
	render_progress_label.text = "Finalizing render ..."
	renderer.close()

	is_rendering = false
	print("Rendering took: ", float(float(Time.get_ticks_usec() - start_time) / 1000000))

	# TODO: Create a new screen to say that render was successfull or unsuccessful.
	show_window(0)


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

	printerr("Unrecognized codec!")
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

			# Checking if audio is empty or not
			if track_audio.size() == 0:
				continue

		# Making the audio data the correct length
		if track_audio.resize(get_sample_count(Project.get_timeline_end() + 1)):
			Toolbox.print_resize_error()

		if audio.size() == 0:
			audio = track_audio
		elif audio.size() == track_audio.size():
			audio = Audio.combine_data(audio, track_audio)

	return audio


func show_window(nr: int) -> void:
	for i: int in get_child_count():
		(get_child(i) as PanelContainer).visible = nr == i


static func get_sample_count(frames: int) -> int:
	return int(44100 * 4 * float(frames) / Project.get_framerate())

