extends Control


const TRACK_HEIGHT: int = 40
const SIDEBAR_WIDTH: int = 64
const ICON_SIZE: int = 20


@export var sidebar: VBoxContainer
@export var lines: Control
@export var clips: Control



func _ready() -> void:
	GoZenServer.add_after_loadable(
		Loadable.new("Preparing timeline tracks", _prepare_tracks))


func _prepare_tracks() -> void:
	sidebar.custom_minimum_size.x = SIDEBAR_WIDTH
	print(sidebar.custom_minimum_size)

	for l_track_id: int in Project.tracks.size():
		_add_track()

	for l_clip: ClipData in Project.clips:
		# TODO: Add clips
		pass


func _add_track() -> void:
	# TODO: Add header in side panel
	var l_header: VBoxContainer = VBoxContainer.new()
	var l_header_hbox: HBoxContainer = HBoxContainer.new()
	var l_header_separator: HSeparator = HSeparator.new()
	var l_mute_button: TextureButton = TextureButton.new()
	var l_hide_button: TextureButton = TextureButton.new()
	var l_separator: HSeparator = HSeparator.new()

	l_header_hbox.add_child(l_mute_button)
	l_header_hbox.add_child(l_hide_button)
	l_header.add_child(l_header_hbox)
	l_header.add_child(l_header_separator)
	sidebar.add_child(l_header)

	l_mute_button.texture_normal = preload("res://assets/icons/sound_on.png")
	l_hide_button.texture_normal = preload("res://assets/icons/visibility_on.png")

	for l_button: TextureButton in [l_mute_button, l_hide_button]:
		l_button.stretch_mode = TextureButton.STRETCH_KEEP_ASPECT_CENTERED
		l_button.ignore_texture_size = true
		l_button.custom_minimum_size.x = ICON_SIZE

	l_header_separator.set_anchors_preset(PRESET_BOTTOM_WIDE)
	l_header_hbox.custom_minimum_size.y = TRACK_HEIGHT - l_header_separator.size.y
	l_header_hbox.alignment = BoxContainer.ALIGNMENT_CENTER
	l_header.add_theme_constant_override("separation", 0)

	lines.add_child(l_separator)

	l_separator.set_anchors_preset(PRESET_TOP_WIDE)
	l_separator.position.y = ((l_header.get_index() + 1) * TRACK_HEIGHT) - l_separator.size.y



