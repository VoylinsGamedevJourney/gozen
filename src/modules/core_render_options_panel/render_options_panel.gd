extends PanelContainer
# TODO: Enable the option to change Audio Bit rate (will need lots of work).


@export var button_save_render_profile: Button
@export var button_set_default_profile: Button
@export var option_button_render_profiles: OptionButton
@export var grid_audio: GridContainer
@export var button_render_draft: CheckButton

@export_category("Path")
@export var path_line_edit: LineEdit

@export_category("Video")
@export var video_codec_option_button: OptionButton
@export var video_quality_hslider: HSlider
@export var video_quality_spin_box: SpinBox
@export var video_gop_spin_box: SpinBox
@export var video_bframes_spin_box: SpinBox
@export_group("H264 options")
@export var video_speed_label: Label
@export var video_speed_hslider: HSlider
@export var video_speed_spin_box: SpinBox

@export_category("Audio")
@export var audio_codec_option_button: OptionButton
@export var audio_channels_option_button: OptionButton

@export_category("Threads")
@export var threads_spin_box: SpinBox

@export_category("Render Region")
@export var render_region_check_button: CheckButton
@export var region_start_spinbox: SpinBox
@export var region_end_spinbox: SpinBox


var button_group: ButtonGroup = ButtonGroup.new()
var status_indicator_id: int

var progress_overlay: ProgressOverlay
var progress_frame_increase: float = 0.0
var current_progress: float = 0.0
var last_displayed_progress: int = -1
var custom_profile_id_start: int = 0

var _is_loading_profile: bool = false



func _ready() -> void:
	@warning_ignore_start("return_value_discarded")
	Project.project_ready.connect(_on_project_ready)
	Project.render_region_updated.connect(_on_render_region_updated)

	video_quality_hslider.value_changed.connect(func(value: float) -> void:
			video_quality_spin_box.set_value_no_signal(absf(value))
			_on_render_settings_changed())
	video_quality_spin_box.value_changed.connect(func(value: float) -> void:
			video_quality_hslider.value = 0 - value
			_on_render_settings_changed())
	video_speed_hslider.value_changed.connect(func(value: float) -> void:
			video_speed_spin_box.set_value_no_signal(value)
			_on_render_settings_changed())
	video_speed_spin_box.value_changed.connect(func(value: float) -> void:
			video_speed_hslider.value = value
			_on_render_settings_changed())

	video_gop_spin_box.value_changed.connect(_on_render_settings_changed.unbind(1))
	video_bframes_spin_box.value_changed.connect(_on_render_settings_changed.unbind(1))
	video_codec_option_button.item_selected.connect(_on_render_settings_changed.unbind(1))
	audio_codec_option_button.item_selected.connect(_on_render_settings_changed.unbind(1))
	audio_channels_option_button.item_selected.connect(_on_render_settings_changed.unbind(1))

	button_set_default_profile.pressed.connect(_on_set_default_profile_button_pressed)
	@warning_ignore_restore("return_value_discarded")

	button_save_render_profile.visible = false

	_setup_codec_option_buttons()
	_add_default_profiles()

	option_button_render_profiles.add_separator("Custom render profiles")
	if DirAccess.dir_exists_absolute(get_user_profiles_path()):
		# Dir existed so there might be profiles inside. We go over the files
		# alphabetically and check if they are valid RenderProfile classes.
		for file_name: String in DirAccess.get_files_at(get_user_profiles_path()):
			file_name = file_name.trim_suffix(".remap")
			if !file_name.ends_with(".tres") and !file_name.ends_with(".res"): continue

			var path: String = get_user_profiles_path() + file_name
			var profile: RenderProfile = load(path)
			if profile:
				add_profile(profile, path)
	elif DirAccess.make_dir_recursive_absolute(get_user_profiles_path()):
		# Else we create the directory in case we need to save a profile to it.
		printerr("RenderScreen: Couldn't create folder at %s!" % get_user_profiles_path())

	# Setting thread count to all threads minus 1.
	threads_spin_box.set_value_no_signal(OS.get_processor_count() - 1)
	threads_spin_box.max_value = OS.get_processor_count()

	_on_render_audio_check_button_toggled(true)

	var default_profile: String = Settings.get_default_render_profile()
	var default_index: int = 0
	for i: int in option_button_render_profiles.item_count:
		if option_button_render_profiles.get_item_text(i) == default_profile:
			default_index = i
			break

	option_button_render_profiles.select(default_index)
	_on_render_profile_option_button_item_selected(default_index)
	button_save_render_profile.visible = false
	_on_project_ready()


func get_user_profiles_path() -> String: return Utils.get_config_dir() + "profiles/render/"


func _on_project_ready() -> void:
	path_line_edit.text = Project.get_project_path().get_basename() + _get_current_extension()
	_on_render_region_updated()


func _on_render_region_updated() -> void:
	render_region_check_button.set_pressed_no_signal(Project.data.use_render_region)
	region_start_spinbox.set_value_no_signal(Project.data.render_region.x)
	region_end_spinbox.set_value_no_signal(Project.data.render_region.y)


func _on_render_region_toggled(toggled_on: bool) -> void:
	Project.set_render_toggle(toggled_on)
	_on_render_settings_changed()


func _on_region_start_changed(value: float) -> void:
	Project.set_render_region_in(int(value))
	_on_render_settings_changed()


func _on_region_end_changed(value: float) -> void:
	Project.set_render_region_out(int(value))
	_on_render_settings_changed()


func _get_current_extension() -> String:
	return Utils.get_video_extension(video_codec_option_button.get_selected_id())


func _add_default_profiles() -> void:
	# Default projects should appear in this order. User profiles get added
	# after these default profiles separated by a line.
	add_profile(load(RenderManager.RENDER_PROFILE_YOUTUBE) as RenderProfile)
	add_profile(load(RenderManager.RENDER_PROFILE_YOUTUBE_HQ) as RenderProfile)
	add_profile(load(RenderManager.RENDER_PROFILE_AV1) as RenderProfile)
	add_profile(load(RenderManager.RENDER_PROFILE_VP9) as RenderProfile)
	add_profile(load(RenderManager.RENDER_PROFILE_VP8) as RenderProfile)
	custom_profile_id_start = option_button_render_profiles.item_count


func _setup_codec_option_buttons() -> void:
	video_codec_option_button.add_item("H264", Encoder.VideoCodec.V_H264) # NO_TRANSLATE
	video_codec_option_button.add_item("MPEG4", Encoder.VideoCodec.V_MPEG4) # NO_TRANSLATE
	video_codec_option_button.add_item("MPEG2", Encoder.VideoCodec.V_MPEG2) # NO_TRANSLATE
	video_codec_option_button.add_item("MPEG1", Encoder.VideoCodec.V_MPEG1) # NO_TRANSLATE
	video_codec_option_button.add_item("MJPEG", Encoder.VideoCodec.V_MJPEG) # NO_TRANSLATE
	video_codec_option_button.add_item("AV1", Encoder.VideoCodec.V_AV1) # NO_TRANSLATE
	video_codec_option_button.add_item("VP9", Encoder.VideoCodec.V_VP9) # NO_TRANSLATE
	video_codec_option_button.add_item("VP8", Encoder.VideoCodec.V_VP8) # NO_TRANSLATE

	audio_codec_option_button.add_item("WAV", Encoder.AudioCodec.A_WAV) # NO_TRANSLATE
	audio_codec_option_button.add_item("PCM", Encoder.AudioCodec.A_PCM) # NO_TRANSLATE
	audio_codec_option_button.add_item("MP2", Encoder.AudioCodec.A_MP2) # NO_TRANSLATE
	audio_codec_option_button.add_item("MP3", Encoder.AudioCodec.A_MP3) # NO_TRANSLATE
	audio_codec_option_button.add_item("AAC", Encoder.AudioCodec.A_AAC) # NO_TRANSLATE
	audio_codec_option_button.add_item("Opus", Encoder.AudioCodec.A_OPUS) # NO_TRANSLATE
	audio_codec_option_button.add_item("Vorbis", Encoder.AudioCodec.A_VORBIS) # NO_TRANSLATE
	audio_codec_option_button.add_item("FLAC", Encoder.AudioCodec.A_FLAC) # NO_TRANSLATE
	audio_codec_option_button.add_item("None", Encoder.AudioCodec.A_NONE)

	audio_channels_option_button.add_item("Stereo", 2)
	audio_channels_option_button.add_item("Mono", 1)


func _on_set_default_profile_button_pressed() -> void:
	var index: int = option_button_render_profiles.selected
	if index != -1:
		var profile_name: String = option_button_render_profiles.get_item_text(index)
		Settings.set_default_render_profile(profile_name)
		Settings.save()
		NotificationManager.info("Default render profile set to '%s'." % profile_name)


func apply_profile_by_name(profile_name: String) -> void:
	var found_index: int = -1
	for i: int in option_button_render_profiles.item_count:
		if option_button_render_profiles.get_item_text(i) == profile_name:
			found_index = i
			break

	if found_index != -1:
		option_button_render_profiles.select(found_index)
		_on_render_profile_option_button_item_selected(found_index)
	else:
		printerr("RenderOptionsPanel: Profile '%s' not found, using default." % profile_name)


func _delete_custom_profile(index: int) -> void:
	var path: String = option_button_render_profiles.get_item_metadata(index)

	option_button_render_profiles.remove_item(index)
	if path != "" and FileAccess.file_exists(path) and DirAccess.remove_absolute(path):
		printerr("RenderScreen: Couldn't remove directory '%s'!" % path)
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
	_is_loading_profile = true

	# Set all the render settings correct.
	for index: int in video_codec_option_button.item_count:
		if video_codec_option_button.get_item_id(index) == profile.video_codec:
			video_codec_option_button.selected = index
			_on_video_codec_option_button_item_selected(index)
			break

	video_quality_hslider.value = 0 - profile.crf
	video_quality_spin_box.set_value_no_signal(profile.crf)
	video_gop_spin_box.value = profile.gop
	video_bframes_spin_box.value = profile.b_frames

	if profile.video_codec == Encoder.VideoCodec.V_H264:
		video_speed_label.visible = true
		(video_speed_hslider.get_parent() as HBoxContainer).visible = true
		video_speed_hslider.value = profile.h264_preset
		video_speed_spin_box.set_value_no_signal(profile.h264_preset)
	else:
		video_speed_label.visible = false
		(video_speed_hslider.get_parent() as HBoxContainer).visible = false

	for index: int in audio_codec_option_button.item_count:
		if audio_codec_option_button.get_item_id(index) == profile.audio_codec:
			audio_codec_option_button.selected = index
			break

	for index: int in audio_channels_option_button.item_count:
		if audio_channels_option_button.get_item_index(index) == profile.audio_channels:
			audio_channels_option_button.selected = index
			break

	button_save_render_profile.visible = false
	_is_loading_profile = false


func _on_render_audio_check_button_toggled(toggled_on:bool) -> void:
	grid_audio.visible = toggled_on


func _on_select_save_path_button_pressed() -> void:
	var dialog: FileDialog = PopupManager.create_file_dialog(
			tr("Select export path"),
			FileDialog.FileMode.FILE_MODE_SAVE_FILE,
			["*" +_get_current_extension()])

	dialog.current_dir = Project.get_picker_path(OS.SYSTEM_DIR_MOVIES)
	dialog.current_file = Project.get_project_name()

	@warning_ignore("return_value_discarded")
	dialog.file_selected.connect(_save_path_selected)

	add_child(dialog)
	dialog.popup_centered()


func _save_path_selected(file_path: String) -> void:
	path_line_edit.text = file_path


func _on_video_codec_option_button_item_selected(index: int) -> void:
	var video_codec_id: int = video_codec_option_button.get_item_id(index)
	var extension: String = Utils.get_video_extension(video_codec_id)
	var is_h264: bool = video_codec_id == Encoder.VideoCodec.V_H264
	var path: String = path_line_edit.text
	var allowed: Array[int] = []

	# Hide speed if not H264.
	video_speed_label.visible = is_h264
	(video_speed_hslider.get_parent() as HBoxContainer).visible = is_h264

	# Changing the extension in path line edit.
	path_line_edit.text = path.trim_suffix("." + path.get_extension()) + extension

	# First option is also the option it will select in case the currently
	# selected audio codec does not fit the selected video codec.
	match extension:
		".mp4":
			allowed = [
				Encoder.AudioCodec.A_AAC,
				Encoder.AudioCodec.A_MP3,
				Encoder.AudioCodec.A_FLAC,
				Encoder.AudioCodec.A_OPUS,
				Encoder.AudioCodec.A_VORBIS,
			]
		".mpg":
			allowed = [
				Encoder.AudioCodec.A_MP2,
				Encoder.AudioCodec.A_MP3,
			]
		".mov":
			allowed = [
				Encoder.AudioCodec.A_AAC,
				Encoder.AudioCodec.A_PCM,
				Encoder.AudioCodec.A_WAV,
				Encoder.AudioCodec.A_MP3,
				Encoder.AudioCodec.A_FLAC,
			]
		".webm":
			allowed = [
				Encoder.AudioCodec.A_OPUS,
				Encoder.AudioCodec.A_VORBIS,
			]
		".ogg":
			allowed = [
				Encoder.AudioCodec.A_OPUS,
				Encoder.AudioCodec.A_VORBIS,
				Encoder.AudioCodec.A_FLAC,
			]

	for i: int in audio_codec_option_button.item_count:
		var value: bool = audio_codec_option_button.get_item_id(i) in allowed

		audio_codec_option_button.set_item_disabled(i, !value)

	if audio_codec_option_button.get_selected_id() not in allowed:
		var audio_codec_index: int = audio_codec_option_button.get_item_index(allowed[0])
		audio_codec_option_button.select(audio_codec_index)


func _on_start_render_button_pressed() -> void:
	var export_path: String = path_line_edit.text
	if export_path.is_empty():
		export_path = Project.get_project_path().get_basename() + _get_current_extension()

	var dir: DirAccess = DirAccess.open(export_path.get_base_dir())
	if dir and dir.get_space_left() < 500 * 1024 * 1024:
		return RenderManager.show_error("Warning: Low disk space! Less than 500MB available in export location..")

	var start_frame: int = 0
	var end_frame: int = Project.data.timeline_end
	if render_region_check_button.button_pressed:
		start_frame = int(region_start_spinbox.value)
		end_frame = int(region_end_spinbox.value)
		if start_frame > end_frame:
			return RenderManager.show_error("Render region start frame cannot be after the end frame.")

	var is_quick_render: bool = OS.get_cmdline_args().has("--render-quick")

	var profile: RenderProfile = RenderProfile.new()
	profile.video_codec = video_codec_option_button.get_selected_id() as Encoder.VideoCodec
	profile.audio_codec = audio_codec_option_button.get_selected_id() as Encoder.AudioCodec if grid_audio.visible else Encoder.AudioCodec.A_NONE
	profile.audio_channels = audio_channels_option_button.get_selected_id() as RenderProfile.AudioChannels
	profile.crf = int(video_quality_spin_box.value)
	profile.gop = int(video_gop_spin_box.value)
	profile.b_frames = int(video_bframes_spin_box.value)
	profile.h264_preset = int(video_speed_hslider.value) as Encoder.H264Presets

	var draft: bool = button_render_draft.button_pressed
	var threads: int = int(threads_spin_box.value)

	if FileAccess.file_exists(export_path) and not is_quick_render:
		var dialog: ConfirmationDialog = PopupManager.create_confirmation_dialog(
				tr("Overwrite file?"),
				tr("A file already exists at the chosen export path. Do you want to overwrite it?"))

		@warning_ignore_start("return_value_discarded")
		dialog.confirmed.connect(func() -> void:
				await RenderManager.start_render(export_path, profile, threads, start_frame, end_frame, draft))
		dialog.canceled.connect(dialog.queue_free)
		@warning_ignore_restore("return_value_discarded")
		dialog.popup_centered()
	else:
		await RenderManager.start_render(export_path, profile, threads, start_frame, end_frame, draft)

	if is_inside_tree():
		var focus_owner: Control = get_viewport().gui_get_focus_owner()
		if focus_owner:
			focus_owner.release_focus()


func _on_render_settings_changed() -> void:
	if !_is_loading_profile:
		button_save_render_profile.visible =  not OS.has_feature("demo")
		option_button_render_profiles.selected = -1
		region_start_spinbox.visible = render_region_check_button.button_pressed
		region_end_spinbox.visible = render_region_check_button.button_pressed


func _on_save_custom_profile_button_pressed() -> void:
	var packed_scene: PackedScene = load("uid://cxfdfmbkkwt51")
	var dialog: ConfirmationDialog = packed_scene.instantiate()
	var _err: int = dialog.call("_connect_save_profile", _save_custom_profile)
	add_child(dialog)
	dialog.popup_centered()


func _save_custom_profile(profile_name: String, icon_path: String) -> void:
	var new_profile: RenderProfile = RenderProfile.new()
	var icon: Image
	if icon_path.begins_with("uid://") or icon_path.begins_with("res://"):
		var icon_texture: Texture2D = load(icon_path)
		icon = icon_texture.get_image()
	else: # It's an actual file.
		icon = Image.load_from_file(icon_path)
	icon.resize(32, 32, Image.INTERPOLATE_CUBIC)

	new_profile.profile_name = profile_name
	new_profile.icon = ImageTexture.create_from_image(icon)
	new_profile.video_codec = video_codec_option_button.get_selected_id() as Encoder.VideoCodec
	new_profile.audio_codec = audio_codec_option_button.get_selected_id() as Encoder.AudioCodec
	new_profile.audio_channels = audio_channels_option_button.get_selected_id() as RenderProfile.AudioChannels
	new_profile.crf = int(video_quality_spin_box.value)
	new_profile.gop = int(video_gop_spin_box.value)
	new_profile.b_frames = int(video_bframes_spin_box.value)
	new_profile.h264_preset = int(video_speed_hslider.value) as Encoder.H264Presets

	if !DirAccess.dir_exists_absolute(get_user_profiles_path()) and DirAccess.make_dir_recursive_absolute(get_user_profiles_path()):
		printerr("RenderScreen: Couldn't create directory at '%s'!" % get_user_profiles_path())

	# Fix filename to not cause issues.
	var save_name: String = profile_name.to_lower().validate_filename()
	var save_path: String = get_user_profiles_path().path_join(save_name + ".tres")
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
