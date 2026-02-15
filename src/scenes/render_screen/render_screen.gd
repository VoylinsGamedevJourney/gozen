extends HSplitContainer
# TODO: Add render range (in - out points)
# TODO: Enable the option to change Audio Bit rate (will need lots of work).

const USER_PROFILES_PATH: String = "user://render_profiles/"


@export var button_save_render_profile: Button
@export var option_button_render_profiles: OptionButton
@export var grid_audio: GridContainer
@export var button_render_draft: CheckButton

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


var button_group: ButtonGroup = ButtonGroup.new()
var status_indicator_id: int

var progress_overlay: ProgressOverlay
var progress_frame_increase: float = 0.0
var current_progress: float = 0.0
var custom_profile_id_start: int = 0


func _ready() -> void:
	RenderManager.update_encoder_status.connect(update_encoder_status)
	button_save_render_profile.visible = false

	# Setup the codec option buttons.
	_setup_codec_option_buttons()

	# Adding render profiles
	_add_default_profiles()

	# Adding custom render profiles
	option_button_render_profiles.add_separator("Custom render profiles")
	if DirAccess.dir_exists_absolute(USER_PROFILES_PATH):
		# Dir existed so there might be profiles inside. We go over the files
		# alphabetically and check if they are valid RenderProfile classes.
		for file_name: String in DirAccess.get_files_at(USER_PROFILES_PATH):
			var path: String = USER_PROFILES_PATH + file_name
			add_profile(load(path) as RenderProfile, path)
	elif DirAccess.make_dir_recursive_absolute(USER_PROFILES_PATH):
		# Else we create the directory in case we need to save a profile to it.
		printerr("RenderScreen: Couldn't create folder at %s!" % USER_PROFILES_PATH)

	# Setting thread count to all threads minus 1.
	threads_spin_box.set_value_no_signal(OS.get_processor_count() - 1)
	threads_spin_box.max_value = OS.get_processor_count()

	# Render audio by default.
	_on_render_audio_check_button_toggled(true)

	option_button_render_profiles.select(0) # Setting "YouTube" as default.
	button_save_render_profile.visible = false


func _on_project_ready() -> void:
	path_line_edit.text = Project.get_project_path().get_basename() + _get_current_extension()


func _get_current_extension() -> String:
	return Utils.get_video_extension(video_codec_option_button.get_selected_id())


func _add_default_profiles() -> void:
	# Default projects should appear in this order. User profiles get added
	# after these default profiles separated by a line.
	add_profile(preload(Library.RENDER_PROFILE_YOUTUBE))
	add_profile(preload(Library.RENDER_PROFILE_YOUTUBE_HQ))
	add_profile(preload(Library.RENDER_PROFILE_AV1))
	add_profile(preload(Library.RENDER_PROFILE_VP9))
	add_profile(preload(Library.RENDER_PROFILE_VP8))
	add_profile(preload(Library.RENDER_PROFILE_HEVC))
	custom_profile_id_start = option_button_render_profiles.item_count


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


func _delete_custom_profile(index: int) -> void:
	var path: String = option_button_render_profiles.get_item_metadata(index)

	option_button_render_profiles.remove_item(index)
	if path != "" and FileAccess.file_exists(path):
		DirAccess.remove_absolute(path)
	_on_render_settings_changed()


func add_profile(profile: RenderProfile, save_path: String = "") -> void:
	var id: int = option_button_render_profiles.item_count
	var tooltip: String = "Profile: %s" % profile.profile_name
	option_button_render_profiles.add_item(profile.profile_name, id)

	if !save_path.is_empty(): # Custom
		tooltip += "\n\nShift click to delete."
		option_button_render_profiles.set_item_metadata(id, save_path)
	else:
		option_button_render_profiles.set_item_metadata(id, profile.resource_path)

	option_button_render_profiles.set_item_tooltip(id, tooltip)
	option_button_render_profiles.set_item_icon(id, profile.icon)


func load_profile(profile: RenderProfile) -> void:
	if !profile:
		printerr("RenderScreen: Render profile is null!")
		return

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
	button_save_render_profile.visible = false


func _on_render_audio_check_button_toggled(toggled_on:bool) -> void:
	grid_audio.visible = toggled_on


func _on_select_save_path_button_pressed() -> void:
	var dialog: FileDialog = PopupManager.create_file_dialog(
			tr("Select export path"),
			FileDialog.FileMode.FILE_MODE_SAVE_FILE,
			["*" +_get_current_extension()])

	dialog.current_dir = Project.get_project_base_folder()
	dialog.current_file = Project.get_project_name()
	dialog.file_selected.connect(_save_path_selected)

	add_child(dialog)
	dialog.popup_centered()


func _save_path_selected(file_path: String) -> void:
	path_line_edit.text = file_path


func _on_video_codec_option_button_item_selected(index: int) -> void:
	var video_codec_id: int = video_codec_option_button.get_item_id(index)
	var extension: String = Utils.get_video_extension(video_codec_id)
	var is_h264: bool = video_codec_id == GoZenEncoder.VIDEO_CODEC.V_H264
	var path: String = path_line_edit.text
	var allowed: PackedInt64Array = []

	# Hide speed if not H264.
	video_speed_label.visible = is_h264
	video_speed_hslider.visible = is_h264

	# Changing the extension in path line edit.
	path_line_edit.text = path.trim_suffix("." + path.get_extension()) + extension

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

	button_save_render_profile.visible = true


func _render_finished() -> void:
	var dialog: AcceptDialog = AcceptDialog.new()

	dialog.title = tr("Rendering finished")
	dialog.dialog_text = "Path: %s\n" % path_line_edit.text
	dialog.dialog_text += "Render time: %s" % Utils.format_time_str(
			RenderManager.encoding_time / 1000.0)
	dialog.exclusive = true

	add_child(dialog)
	dialog.popup_centered()

	PopupManager.close(PopupManager.PROGRESS)
	progress_overlay = null


func _cancel_render() -> void:
	RenderManager.cancel_encoding = true


func _show_error(message: String) -> void:
	var dialog: AcceptDialog = AcceptDialog.new()

	dialog.title = tr("Error whilst rendering video")
	dialog.dialog_text = message
	dialog.exclusive = true

	add_child(dialog)
	dialog.popup_centered()

	PopupManager.close(PopupManager.PROGRESS)
	progress_overlay = null


func _on_start_render_button_pressed() -> void:
	# Disk space check
	# NOTE: This needs to improve later on to create an estimate instead of 500MB.
	var dir: DirAccess = DirAccess.open(path_line_edit.text.get_base_dir())
	if dir.get_space_left() < 500 * 1024 * 1024:
		return _show_error("Warning: Low disk space! Less than 500MB available in export location..")

	var draft: bool = button_render_draft.button_pressed
	var render_resolution: Vector2i = Project.data.resolution
	var end: int = Project.data.timeline_end

	if draft:
		var target_height: int = 480
		var aspect: float = float(render_resolution.x) / float(render_resolution.y)

		render_resolution =	Vector2i(int(target_height * aspect), target_height)
		if render_resolution.x % 2 != 0:
			render_resolution.x += 1
		print("RenderManager: Draft mode enabled. Scaling to ", render_resolution)

	# Printing info about the rendering process.
	print("--------------------")
	Print.header("Rendering process started")
	Print.info("Path", path_line_edit.text)
	Print.info("Resolution", render_resolution)
	Print.info("Framerate", Project.data.framerate)
	Print.info("Video codec", video_codec_option_button.get_selected_id())
	Print.info("CRF", int(0 - video_quality_hslider.value))
	Print.info("GOP", int(video_gop_spin_box.value))
	if video_codec_option_button.get_selected_id() == GoZenEncoder.VIDEO_CODEC.V_H264:
		Print.info("h264 preset", int(video_speed_hslider.value))
	Print.info("Audio codec", audio_codec_option_button.get_selected_id())
	Print.info("Cores/threads", threads_spin_box.value)
	Print.info("Frames to process", end + 1)
	print("--------------------")

	# Resetting progress values.
	progress_frame_increase = (97.0 / end) * RenderManager.buffer_size
	current_progress = 0.0

	# Changing icon to indicate that GoZen is rendering.
	var gozen_icon: CompressedTexture2D = preload(Library.ICON_GOZEN)
	var rendering_icon: CompressedTexture2D = preload(Library.ICON_RENDERING)

	if OS.get_name().to_lower() == "windows":
		DisplayServer.set_icon(rendering_icon.get_image())
		status_indicator_id = DisplayServer.create_status_indicator(
				rendering_icon, tr("Rendering"), Callable())

	# Display the progress popup.
	if progress_overlay != null:
		PopupManager.close(PopupManager.PROGRESS)
		progress_overlay = null

	progress_overlay = PopupManager.get_popup(PopupManager.PROGRESS)
	progress_overlay.update_title(tr("Rendering"))
	await progress_overlay.update(0, "")

	var button: Button = Button.new()
	var status_hbox: HBoxContainer = progress_overlay.get("status_hbox")
	var status_label: Label = status_hbox.get_child(0)

	button.text = tr("Cancel rendering")
	button.pressed.connect(_cancel_render)
	status_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
	status_hbox.add_child(button)

	if OS.get_name().to_lower() == "windows":
		DisplayServer.set_icon(gozen_icon.get_image())
		DisplayServer.delete_status_indicator(status_indicator_id)

	RenderManager.encoder = GoZenEncoder.new()
	RenderManager.encoder.set_resolution(render_resolution)
	RenderManager.encoder.set_framerate(Project.data.framerate)
	RenderManager.encoder.set_file_path(path_line_edit.text)
	RenderManager.encoder.set_video_codec_id(video_codec_option_button.get_selected_id())
	RenderManager.encoder.set_crf(int(0 - video_quality_hslider.value))
	RenderManager.encoder.set_h264_preset(int(video_speed_hslider.value))
	RenderManager.encoder.set_gop_size(int(video_gop_spin_box.value))
	RenderManager.encoder.set_audio_codec_id(audio_codec_option_button.get_selected_id())
	RenderManager.encoder.set_threads(int(threads_spin_box.value))
	await RenderManager.start_encoder()


func update_encoder_status(status: RenderManager.STATUS) -> void:
	if progress_overlay == null:
		return printerr("RenderScreen: ProgressOverlay is null!")

	var status_str: String = ""
	match status:
		# Errors, something went wrong.
		RenderManager.STATUS.ERROR_OPEN: _show_error(tr("Error opening file"))
		RenderManager.STATUS.ERROR_AUDIO: _show_error(tr("Error whilst sending audio"))
		RenderManager.STATUS.ERROR_CANCELED:
			PopupManager.close(PopupManager.PROGRESS)
			progress_overlay = null

		# Normal progress.
		RenderManager.STATUS.SETUP: status_str = tr("Setting up ...")
		RenderManager.STATUS.COMPILING_AUDIO: status_str = tr("Compiling audio ...")
		RenderManager.STATUS.SENDING_AUDIO: status_str = tr("Compiling audio ...")
		RenderManager.STATUS.SENDING_FRAMES: status_str = tr("Sending data ...")
		RenderManager.STATUS.FRAMES_SEND: status_str = tr("Sending data ...")
		RenderManager.STATUS.LAST_FRAMES: status_str = tr("Sending final frame ...")
		RenderManager.STATUS.FINISHED: _render_finished()

	if status >= 0:
		if status == RenderManager.STATUS.FRAMES_SEND:
			current_progress += progress_frame_increase # Update bar from 6 to 99.
		else:
			current_progress = status
	if progress_overlay != null:
		await progress_overlay.update(floori(current_progress), status_str)


func _on_render_settings_changed() -> void:
	button_save_render_profile.visible = true
	option_button_render_profiles.selected = -1


func _on_save_custom_profile_button_pressed() -> void:
	var packed_scene: PackedScene = load("uid://cxfdfmbkkwt51")
	var dialog: ConfirmationDialog = packed_scene.instantiate()
	var _err: int = dialog.call("_connect_save_profile", _save_custom_profile)
	add_child(dialog)
	dialog.popup_centered()


func _save_custom_profile(profile_name: String, icon_path: String) -> void:
	var new_profile: RenderProfile = RenderProfile.new()
	var icon: Image = Image.load_from_file(icon_path)

	icon.resize(32, 32, Image.INTERPOLATE_CUBIC)
	new_profile.profile_name = profile_name
	new_profile.icon = ImageTexture.create_from_image(icon)
	new_profile.video_codec = video_codec_option_button.get_selected_id() as GoZenEncoder.VIDEO_CODEC
	new_profile.audio_codec = audio_codec_option_button.get_selected_id() as GoZenEncoder.AUDIO_CODEC
	new_profile.crf = abs(video_quality_hslider.value)
	new_profile.gop = int(video_gop_spin_box.value)
	new_profile.h264_preset = int(video_speed_hslider.value) as GoZenEncoder.H264_PRESETS

	if !DirAccess.dir_exists_absolute(USER_PROFILES_PATH):
		DirAccess.make_dir_recursive_absolute(USER_PROFILES_PATH)

	# Fix filename to not cause issues
	var save_name: String = profile_name.to_lower().validate_filename()
	var save_path: String = USER_PROFILES_PATH.path_join(save_name + ".tres")
	var _err: int = ResourceSaver.save(new_profile, save_path)
	if _err != OK:
		return printerr("RenderScreen: Failed to save custom profile to '%s' - %s" % [save_path, _err])
	add_profile(new_profile, save_path)

	var id: int = option_button_render_profiles.item_count - 1
	option_button_render_profiles.selected = id
	button_save_render_profile.visible = false


func _on_render_profile_option_button_item_selected(index: int) -> void:
	if Input.is_key_pressed(KEY_SHIFT) and index > custom_profile_id_start:
		var current_id: int = option_button_render_profiles.get_selected_id()
		var current_index: int = option_button_render_profiles.get_item_index(current_id)

		_delete_custom_profile(index)
		if current_index != index:
			option_button_render_profiles.select(index)
		else:
			_on_render_settings_changed()
	else:
		var render_profile: RenderProfile = load(option_button_render_profiles.get_item_metadata(index) as String)
		load_profile(render_profile)
