extends PanelContainer


@export var title_label: Label
@export var match_project_button: Button
@export var separator_bottom: VSeparator

@export_group("General")
@export var grid_general: GridContainer
@export var label_path: Label
@export var label_type: Label
@export var label_size: Label
@export var label_resolution: Label
@export var label_framerate: Label
@export var label_duration: Label

@export_group("Video")
@export var grid_video: GridContainer
@export var label_video_codec: Label
@export var label_color_space: Label
@export var label_pixel_format: Label
@export var label_aspect_ratio: Label
@export var label_video_bitrate: Label
@export var label_b_frames: Label
@export var label_scanning: Label

@export_group("Audio")
@export var grid_audio: GridContainer
@export var label_audio_codec: Label
@export var label_audio_streams: Label
@export var label_audio_bitrate: Label
@export var label_audio_duration: Label


var file: FileData
var resolution: Vector2i
var framerate: float



func load_data(file_id: int) -> void:
	file = FileLogic.get_data(file_id)

	title_label.text = file.nickname
	label_path.text = Format.path_remove_middle(file.path, 50)
	label_path.tooltip_text = file.path

	var type: String
	match file.type:
		Type.VIDEO: label_type.text = "Video"
		Type.AUDIO: label_type.text = "Audio"
		Type.IMAGE: label_type.text = "Image"
		Type.TEXT: label_type.text = "Text"
		Type.COLOR: label_type.text = "Color"
		Type.PCK: label_type.text = "PCK"

	if not file.path.begins_with("temp://"):
		label_size.text = String.humanize_size(
				FileAccess.get_size(ProjectSettings.globalize_path(file.path)))
	else:
		label_size.text = "In memory"

	grid_video.visible = false
	grid_audio.visible = false
	match_project_button.visible = false
	separator_bottom.visible = false

	if file.type == Type.VIDEO:
		grid_video.visible = true
		grid_audio.visible = true
		match_project_button.visible = true
		separator_bottom.visible = true

		# We could try to look if there's an instance open already but ...
		# opening it again is easier XD
		var video: Video = Video.new()
		if video.open(file.path) == OK:
			resolution = video.get_resolution()
			framerate = video.get_framerate()

			label_resolution.text = "%dx%d" % [resolution.x, resolution.y]
			label_framerate.text = str(snappedf(framerate, 0.01)) + " fps"
			label_duration.text = Format.time_str(file.duration / Project.data.framerate, false)

			label_video_codec.text = video.get_video_codec().to_upper()

			var video_bitrate: int = video.get_video_bitrate()
			if video_bitrate > 0:
				label_video_bitrate.text = String.humanize_size(video_bitrate) + "/s"
			else:
				label_video_bitrate.text = "Unknown"

			label_b_frames.text = str(video.get_b_frames())

			label_pixel_format.text = video.get_pixel_format().to_upper()
			label_color_space.text = video.get_color_profile().to_upper()
			label_aspect_ratio.text = str(snappedf(video.get_sar(), 0.01))
			label_scanning.text = "Interlaced" if video.get_interlaced() else "Progressive"

			var audio: AudioStream = video.get_audio()
			label_audio_codec.text = audio.get_audio_codec().to_upper()
			var audio_bitrate: int = audio.get_audio_bitrate()
			if audio_bitrate > 0:
				label_audio_bitrate.text = String.humanize_size(audio_bitrate) + "/s"
			else:
				label_audio_bitrate.text = "Unknown"
			label_audio_duration.text = Format.time_str(file.duration / Project.data.framerate, false)
			label_audio_streams.text = str(maxi(1, file.audio_streams.size()))
			video.close()
	elif file.type == Type.AUDIO:
		grid_audio.visible = true
		# TODO: This duration is not accurate! We should get a more correct duration from the file itself!
		label_audio_duration.text = Format.time_str(file.duration / Project.data.framerate, false)
		label_audio_streams.text = str(maxi(1, file.audio_streams.size()))

		var audio_stream: AudioStreamFFmpeg = AudioStreamFFmpeg.new()
		if audio_stream.open(file.path) == OK:
			var audio_bitrate: int = audio_stream.get_audio_bitrate()
			label_audio_codec.text = audio_stream.get_audio_codec().to_upper()
			if audio_bitrate > 0:
				label_audio_bitrate.text = String.humanize_size(audio_bitrate) + "/s"
			else:
				label_audio_bitrate.text = "Unknown"
	elif file.type == Type.IMAGE:
		match_project_button.visible = true
		label_duration.text = "-"
		label_framerate.text = "-"
		var image: Image = Image.load_from_file(file.path)
		if image:
			resolution = image.get_size()
			label_resolution.text = "%dx%d" % [resolution.x, resolution.y]
		else:
			label_resolution.text = "Unknown"


func _on_match_project_button_pressed() -> void:
	if file.type == Type.VIDEO:
		var video: Video = Video.new()
		if video.open(file.path) == OK:
			Project.set_resolution(resolution)
			Project.set_framerate(framerate)
			video.close()
			_on_close_button_pressed()
	elif file.type == Type.IMAGE:
		var image: Image = Image.load_from_file(file.path)
		if image:
			Project.set_resolution(resolution)
			_on_close_button_pressed()


func _input(event: InputEvent) -> void:
	if event.is_action_pressed("ui_cancel"):
		_on_close_button_pressed()


func _on_close_button_pressed() -> void:
	PopupManager.close(PopupManager.FILE_INFO)
