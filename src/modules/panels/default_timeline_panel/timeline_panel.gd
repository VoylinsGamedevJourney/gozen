extends Control


const TRACK_HEIGHT: int = 40
const TRACK_PADDING: int = 3000

const ZOOM_MIN: float = 0.1
const ZOOM_MAX: float = 6

const SIDEBAR_WIDTH: int = 64
const ICON_SIZE: int = 20


@export var sidebar: VBoxContainer
@export var scroll_container: ScrollContainer
@export var main_control: Control
@export var lines_control: Control
@export var clips_control: Control
@export var playhead: Panel


var zoom: float = 1.0
var pre_zoom: Vector3i = Vector3i.ZERO # local mouse pos, scroll pos, prev zoom



func _ready() -> void:
	var err: int = 0
	err += Project._on_track_added.connect(_add_track)
	err += Project._on_track_removed.connect(_remove_track)
	err += Project._on_clip_added.connect(_add_track)
	err += Project._on_end_pts_changed.connect(_on_pts_changed)
	if err:
		printerr("Couldn't connect Project signals to Timeline module functions!")

	GoZenServer.add_after_loadable(
		Loadable.new("Preparing timeline module", _prepare_timeline))


func _prepare_timeline() -> void:
	sidebar.custom_minimum_size.x = SIDEBAR_WIDTH

	for l_track_id: int in Project.tracks.size():
		_add_track()
		for l_clip_id: int in Project.tracks[l_track_id].keys():
			_add_clip(l_clip_id)

	_set_pre_zoom()
	_on_zoom(zoom)


func _set_pre_zoom() -> void:
	# X = local mouse pos, Y = scroll pos, Z = prev zoom
	pre_zoom.x = main_control.get_local_mouse_position().x as int
	pre_zoom.y = scroll_container.scroll_horizontal
	pre_zoom.z = zoom


func _on_scroll_gui_input(a_event: InputEvent) -> void:
	if (a_event as InputEventWithModifiers).ctrl_pressed:
		get_viewport().set_input_as_handled()


func _on_main_gui_input(a_event: InputEvent) -> void:
	if a_event is InputEventMouseButton and (a_event as InputEventMouseButton).button_index == MOUSE_BUTTON_LEFT:
		if a_event.is_released():
			GoZenServer.set_playhead_moving(false)
		elif a_event.is_pressed():
			GoZenServer.set_playhead_moving(true)
	
	if a_event.is_action_pressed("zoom_in", true):
		get_viewport().set_input_as_handled()
		_set_pre_zoom()
		_on_zoom(zoom + 0.05)
	elif a_event.is_action_pressed("zoom_out", true):
		get_viewport().set_input_as_handled()
		_set_pre_zoom()
		_on_zoom(zoom - 0.05)


#------------------------------------------------ TRACK HANDLING
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

	lines_control.add_child(l_separator)

	l_separator.set_anchors_preset(PRESET_TOP_WIDE)
	l_separator.position.y = ((l_header.get_index() + 1) * TRACK_HEIGHT) - l_separator.size.y

	_on_tracks_changed()


func _remove_track(a_track_id: int) -> void:
	sidebar.get_children()[a_track_id].queue_free()
	lines_control.get_children()[-1].queue_free()
	# TODO: Reposition all clips if removed track is not form the last line
	_on_tracks_changed()


#------------------------------------------------ CLIP HANDLING
func _add_clip(a_clip_id: int) -> void:
	if Project._clip_nodes.has(a_clip_id):
		for l_node: Control in Project._clip_nodes[a_clip_id]:
			if l_node.get_parent() == clips_control:
				return # Already added
		
	var l_node: Control = Control.new()
	clips_control.add_child(l_node)

	if Project._clip_nodes.has(a_clip_id):
		Project._clip_nodes[a_clip_id] = [l_node]
	else:
		var l_array: Array = Project._clip_nodes[a_clip_id]
		l_array.append(l_node)
	

#------------------------------------------------ RESIZE HANDLING
func _on_pts_changed(a_value: float) -> void:
	main_control.custom_minimum_size.x = (a_value + TRACK_PADDING + scroll_container.size.x) * zoom


func _on_tracks_changed() -> void:
	main_control.size.y = max(TRACK_HEIGHT * Project.tracks.size(), scroll_container.size.y)


func _on_zoom(a_new_zoom: float) -> void:
	zoom = clamp(a_new_zoom, ZOOM_MIN, ZOOM_MAX)

	# Resizing main control
	_on_pts_changed(zoom) # Resizing X
	_on_tracks_changed()  # Resizing Y

	# Correcting horizontal scroll
	if scroll_container.scroll_horizontal != 0:
		scroll_container.scroll_horizontal = abs(((pre_zoom.x - pre_zoom.z) * zoom) - pre_zoom.x - pre_zoom.y)

	# Correcting playhead position
	if playhead.position.x != 0 and pre_zoom.z != 0:
		playhead.position.x = playhead.position.x / pre_zoom.z * zoom

