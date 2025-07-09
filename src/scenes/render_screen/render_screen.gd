extends VSplitContainer


const USER_PROFILES_PATH: String = "user://render_profiles/"


@export var render_profiles_hbox: HBoxContainer
@export var grid_audio: GridContainer

@export_group("Path")
@export var path_line_edit: LineEdit

@export_group("Video")
@export var video_codec_option_button: OptionButton
@export var video_quality_hslider: HSlider
@export var video_gop_spin_box: SpinBox
@export_subgroup("H264 options")
@export var video_speed_label: Label
@export var video_speed_hslider: HSlider

@export_group("Audio")
@export var audio_codec_option_button: OptionButton

@export_group("Threads")
@export var threads_spin_box: SpinBox

@export_group("Chapters")
@export var chapters_text_edit: TextEdit

var button_group: ButtonGroup = ButtonGroup.new()
var status_indicator_id: int 

var progress_overlay: ProgressOverlay
var progress_frame_increase: float = 0.0
var current_progress: float = 0.0



func _ready() -> void:
	Toolbox.connect_func(RenderManager.update_encoder_status, update_encoder_status)
	Toolbox.connect_func(Project.project_ready, _set_default_path)
	Toolbox.connect_func(Project._markers_updated, _on_chapters_updated)

	# Setup the codec option buttons.
	_setup_codec_option_buttons()

	# Adding render profiles
	_add_default_profiles()

	if DirAccess.dir_exists_absolute(USER_PROFILES_PATH):
		# Dir existed so there might be profiles inside. We go over the files
		# alphabetically and check if they are valid RenderProfile classes.
		var files: PackedStringArray = DirAccess.get_files_at(USER_PROFILES_PATH)
		if files.size() != 0:
			render_profiles_hbox.add_child(HSeparator.new())

		for file_name: String in files:
			add_profile(load(USER_PROFILES_PATH + file_name) as RenderProfile)
	elif DirAccess.make_dir_recursive_absolute(USER_PROFILES_PATH):
		# Else we create the directory in case we need to save a profile to it.
		printerr("Couldn't create folder at %s!" % USER_PROFILES_PATH)

	# Setting "YouTube" to the default loaded profile
	var first_profile: Button = render_profiles_hbox.get_child(0)
	first_profile.button_pressed = true
	first_profile.pressed.emit()

	# Setting thread count to all threads minus 1.
	threads_spin_box.value = OS.get_processor_count() - 1
	threads_spin_box.max_value = OS.get_processor_count()

	# Render audio by default.
	_on_render_audio_check_button_toggled(true)


func _set_default_path() -> void:
	path_line_edit.text = Project.get_project_path().get_basename() + _get_current_extension()


func _get_current_extension() -> String:
	return Toolbox.get_video_extension(video_codec_option_button.get_selected_id())


func _add_default_profiles() -> void:
	# Default projects should appear in this order. User profiles get added
	# after these default profiles separated by a line.
	add_profile(preload("uid://bp6oahvgcklvc")) # YouTube
	add_profile(preload("uid://f5ffyfe5gb5b"))  # YouTube HQ
	add_profile(preload("uid://du35gfskoijp"))  # AV1
	add_profile(preload("uid://b8lmmvi0gnujr")) # VP9
	add_profile(preload("uid://drlbs008bf7so")) # VP8
	add_profile(preload("uid://bcktb6d5bti7t")) # HEVC


func _setup_codec_option_buttons() -> void:
	video_codec_option_button.add_item("HEVC", GoZenEncoder.VIDEO_CODEC.V_HEVC)
	video_codec_option_button.add_item("H264", GoZenEncoder.VIDEO_CODEC.V_H264)
	video_codec_option_button.add_item("MPEG4", GoZenEncoder.VIDEO_CODEC.V_MPEG4)
	video_codec_option_button.add_item("MPEG2", GoZenEncoder.VIDEO_CODEC.V_MPEG2)
	video_codec_option_button.add_item("MPEG1", GoZenEncoder.VIDEO_CODEC.V_MPEG1)
	video_codec_option_button.add_item("MJPEG", GoZenEncoder.VIDEO_CODEC.V_MJPEG)
	video_codec_option_button.add_item("AV1", GoZenEncoder.VIDEO_CODEC.V_AV1)
	video_codec_option_button.add_item("VP9", GoZenEncoder.VIDEO_CODEC.V_VP9)
	video_codec_option_button.add_item("VP8", GoZenEncoder.VIDEO_CODEC.V_VP8)

	audio_codec_option_button.add_item("WAV", GoZenEncoder.AUDIO_CODEC.A_WAV)
	audio_codec_option_button.add_item("PCM", GoZenEncoder.AUDIO_CODEC.A_PCM)
	audio_codec_option_button.add_item("MP2", GoZenEncoder.AUDIO_CODEC.A_MP2)
	audio_codec_option_button.add_item("MP3", GoZenEncoder.AUDIO_CODEC.A_MP3)
	audio_codec_option_button.add_item("AAC", GoZenEncoder.AUDIO_CODEC.A_AAC)
	audio_codec_option_button.add_item("Opus", GoZenEncoder.AUDIO_CODEC.A_OPUS)
	audio_codec_option_button.add_item("Vorbis", GoZenEncoder.AUDIO_CODEC.A_VORBIS)
	audio_codec_option_button.add_item("FLAC", GoZenEncoder.AUDIO_CODEC.A_FLAC)
	audio_codec_option_button.add_item("NONE", GoZenEncoder.AUDIO_CODEC.A_NONE)


func add_profile(profile: RenderProfile) -> void:
	var button: Button = Button.new()

	button.icon = profile.icon
	button.icon_alignment = HORIZONTAL_ALIGNMENT_CENTER
	button.expand_icon = true
	button.custom_minimum_size.x = 70

	button.toggle_mode = true
	button.button_group = button_group
	button.theme_type_variation = "render_profile_button"
	button.tooltip_text = "Profile: %s" % profile.profile_name
	Toolbox.connect_func(button.pressed, load_profile.bind(profile))

	render_profiles_hbox.add_child(button)


func load_profile(profile: RenderProfile) -> void:
	# Set all the render settings correct.
	for index: int in video_codec_option_button.item_count:
		if video_codec_option_button.get_item_id(index) == profile.video_codec:
			video_codec_option_button.selected = index
			break

	video_quality_hslider.value = profile.crf
	video_gop_spin_box.value = profile.gop

	if profile.video_codec == GoZenEncoder.VIDEO_CODEC.V_H264:
		video_speed_label.visible = true
		video_speed_hslider.visible = true
		video_speed_hslider.value = profile.h264_preset
	else:
		video_speed_label.visible = false
		video_speed_hslider.visible = false

	for index: int in audio_codec_option_button.item_count:
		if audio_codec_option_button.get_item_id(index) == profile.audio_codec:
			audio_codec_option_button.selected = index
			break


func _on_render_audio_check_button_toggled(toggled_on:bool) -> void:
	grid_audio.visible = toggled_on


func _on_chapters_updated() -> void:
	var chapters: Dictionary[int, String] = Project.get_markers()
	chapters_text_edit.text = ""

	for i: int in chapters:
		var time: String = Toolbox.format_time_str_from_frame(i)
		chapters_text_edit.text += "%s %s\n" % [time, chapters[i]]


func _on_copy_chapters_button_pressed() -> void:
	DisplayServer.clipboard_set(chapters_text_edit.text)


func _on_select_save_path_button_pressed() -> void:
	var dialog: FileDialog = Toolbox.get_file_dialog(
			"file_dialog_title_select_save_path",
			FileDialog.FileMode.FILE_MODE_SAVE_FILE,
			["*" +_get_current_extension()])

	dialog.current_dir = Project.get_project_base_folder()
	dialog.current_file = Project.get_project_name()
	Toolbox.connect_func(dialog.file_selected, _save_path_selected)

	add_child(dialog)
	dialog.popup_centered()


func _save_path_selected(file_path: String) -> void:
	path_line_edit.text = file_path


func _on_video_codec_option_button_item_selected(index: int) -> void:
	var video_codec_id: int = video_codec_option_button.get_item_id(index)
	var extension: String = Toolbox.get_video_extension(video_codec_id)
	var is_h264: bool = video_codec_id == GoZenEncoder.VIDEO_CODEC.V_H264
	var path: String = path_line_edit.text
	var allowed: PackedInt64Array = []

	# Hide speed if not H264.
	video_speed_label.visible = is_h264
	video_speed_hslider.visible = is_h264

	# Changing the extension in path line edit.
	path_line_edit.text = path.trim_suffix(path.get_extension()) + extension

	# First option is also the option it will select in case the currently
	# selected audio codec does not fit the selected video codec.
	match extension:
		".mp4":
			allowed = [
				GoZenEncoder.AUDIO_CODEC.A_AAC,
				GoZenEncoder.AUDIO_CODEC.A_MP3,
				GoZenEncoder.AUDIO_CODEC.A_FLAC,
				GoZenEncoder.AUDIO_CODEC.A_OPUS,
				GoZenEncoder.AUDIO_CODEC.A_VORBIS,
			]
		".mpg":
			allowed = [
				GoZenEncoder.AUDIO_CODEC.A_MP2,
				GoZenEncoder.AUDIO_CODEC.A_MP3,
			]
		".mov":
			allowed = [
				GoZenEncoder.AUDIO_CODEC.A_AAC,
				GoZenEncoder.AUDIO_CODEC.A_PCM,
				GoZenEncoder.AUDIO_CODEC.A_WAV,
				GoZenEncoder.AUDIO_CODEC.A_MP3,
				GoZenEncoder.AUDIO_CODEC.A_FLAC,
			]
		".webm":
			allowed = [
				GoZenEncoder.AUDIO_CODEC.A_OPUS,
				GoZenEncoder.AUDIO_CODEC.A_VORBIS,
			]
		".ogg":
			allowed = [
				GoZenEncoder.AUDIO_CODEC.A_OPUS,
				GoZenEncoder.AUDIO_CODEC.A_VORBIS,
				GoZenEncoder.AUDIO_CODEC.A_FLAC,
			]

	for i: int in audio_codec_option_button.item_count:
		var value: bool = audio_codec_option_button.get_item_id(i) in allowed

		audio_codec_option_button.set_item_disabled(i, !value)

	if audio_codec_option_button.get_selected_id() not in allowed:
		var audio_codec_index: int = audio_codec_option_button.get_item_index(allowed[0])
		audio_codec_option_button.select(audio_codec_index)


func _render_finished() -> void:
	var dialog: AcceptDialog = AcceptDialog.new()

	dialog.title = tr("title_rendering_finished")
	dialog.dialog_text = "Path: %s\n" % path_line_edit.text
	dialog.dialog_text += "Render time: %s" % Toolbox.format_time_str(
			RenderManager.encoding_time / 1000.0)
	dialog.exclusive = true
	
	add_child(dialog)
	dialog.popup_centered()
	progress_overlay.queue_free()
	progress_overlay = null


func _cancel_render() -> void:
	RenderManager.cancel_encoding = true


func _show_error(message: String) -> void:
	var dialog: AcceptDialog = AcceptDialog.new()

	dialog.title = tr("title_rendering_error")
	dialog.dialog_text = tr(message)
	dialog.exclusive = true
	
	add_child(dialog)
	dialog.popup_centered()
	progress_overlay.queue_free()
	progress_overlay = null


func _on_start_render_button_pressed() -> void:
	# Printing info about the rendering process.
	print("--------------------")
	Toolbox.print_header("Rendering process started")
	Toolbox.print_info("Path", path_line_edit.text)
	Toolbox.print_info("Resolution", Project.get_resolution())
	Toolbox.print_info("Framerate", Project.get_framerate())
	Toolbox.print_info("Video codec", video_codec_option_button.get_selected_id())
	Toolbox.print_info("CRF", int(0 - video_quality_hslider.value))
	Toolbox.print_info("GOP", int(video_gop_spin_box.value))
	if video_codec_option_button.get_selected_id() == GoZenEncoder.VIDEO_CODEC.V_H264:
		Toolbox.print_info("h264 preset", int(video_speed_hslider.value))
	Toolbox.print_info("Audio codec", audio_codec_option_button.get_selected_id())
	Toolbox.print_info("Cores/threads", threads_spin_box.value)
	Toolbox.print_info("Frames to process", Project.get_timeline_end() + 1)
	print("--------------------")

	# Resetting progress values.
	progress_frame_increase = (97.0 / Project.get_timeline_end()) * RenderManager.buffer_size
	current_progress = 0.0

	# Changing icon to indicate that GoZen is rendering.
	var gozen_icon: CompressedTexture2D = preload("uid://cwv5gaisvmwv7")
	var rendering_icon: CompressedTexture2D = preload("uid://b6r37nt1xhvq6")

	if OS.get_name().to_lower() == "windows":
		DisplayServer.set_icon(rendering_icon.get_image())
		status_indicator_id = DisplayServer.create_status_indicator(
				rendering_icon, tr("title_rendering"), Callable())

	# Display the progress popup.
	if progress_overlay != null:
		progress_overlay.queue_free()
		progress_overlay = null

	progress_overlay = preload("uid://d4h7t8ccus0yv").instantiate()
	progress_overlay.update_title("title_rendering")
	progress_overlay.update_progress(0, "")

	var button: Button = Button.new()

	button.text = tr("button_cancel_rendering")
	Toolbox.connect_func(button.pressed, _cancel_render)

	get_tree().root.add_child(progress_overlay)
	var status_label: Label = progress_overlay.status_hbox.get_child(0)
	status_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
	progress_overlay.status_hbox.add_child(button)

	if OS.get_name().to_lower() == "windows":
		DisplayServer.set_icon(gozen_icon.get_image())
		DisplayServer.delete_status_indicator(status_indicator_id)

	RenderManager.encoder = GoZenEncoder.new()
	RenderManager.encoder.set_resolution(Project.get_resolution())
	RenderManager.encoder.set_framerate(Project.get_framerate())
	RenderManager.encoder.set_file_path(path_line_edit.text)
	RenderManager.encoder.set_video_codec_id(video_codec_option_button.get_selected_id())
	RenderManager.encoder.set_crf(int(0 - video_quality_hslider.value))
	RenderManager.encoder.set_h264_preset(int(video_speed_hslider.value))
	RenderManager.encoder.set_gop_size(int(video_gop_spin_box.value))
	RenderManager.encoder.set_audio_codec_id(audio_codec_option_button.get_selected_id())
	RenderManager.encoder.set_threads(int(threads_spin_box.value))
	RenderManager.start()


func update_encoder_status(status: RenderManager.STATUS) -> void:
	if progress_overlay == null:
		printerr("ProgressOverlay is null!")
		return

	var status_str: String = ""

	match status:
		# Errors, something went wrong.
		RenderManager.STATUS.ERROR_OPEN: _show_error("encoding_progress_text_open_error")
		RenderManager.STATUS.ERROR_AUDIO: _show_error("encoding_progress_text_sending_audio_error")
		RenderManager.STATUS.ERROR_CANCELED:
			progress_overlay.queue_free()
			progress_overlay = null

		# Normal progress.
		RenderManager.STATUS.SETUP: status_str = "encoding_progress_text_setup"
		RenderManager.STATUS.COMPILING_AUDIO: status_str = "encoding_progress_text_compiling_audio"
		RenderManager.STATUS.SENDING_AUDIO: status_str = "encoding_progress_text_compiling_audio"
		RenderManager.STATUS.SENDING_FRAMES: status_str = "encoding_progress_text_creating_sending_data"
		RenderManager.STATUS.FRAMES_SEND: status_str = "encoding_progress_text_creating_sending_data"
		RenderManager.STATUS.LAST_FRAMES: status_str = "encoding_progress_text_last_frame"
		RenderManager.STATUS.FINISHED: _render_finished()

	if status >= 0:
		if status == RenderManager.STATUS.FRAMES_SEND:
			current_progress += progress_frame_increase # Update bar from 6 to 99.
		else:
			current_progress = status
	if progress_overlay != null:
		progress_overlay.update_progress(floori(current_progress), status_str)

