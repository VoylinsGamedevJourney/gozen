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
var pre_mouse_pos: int = 0
var pre_scroll_pos: int = 0
var pre_zoom: float = 1.0



func _ready() -> void:
	GoZenServer.add_after_loadable(
	Loadable.new("Preparing timeline module", _prepare_timeline))

	var err: int = 0
	err += Project._on_track_added.connect(add_track)
	err += Project._on_track_removed.connect(remove_track)
	err += Project._on_clip_added.connect(add_track)
	err += Project._on_end_pts_changed.connect(_on_pts_changed)
	if err:
		printerr("Couldn't connect Project signals to Timeline module functions!")
		err = 0

	err += get_viewport().size_changed.connect(on_zoom)
	if err:
		printerr("Coulnd't connect to size_changed in Timeline module!")


func _process(_delta: float) -> void:
	if GoZenServer.playhead_moving and !GoZenServer.clip_moving:
		var l_temp: float = main_control.get_local_mouse_position().x
		
		playhead.position.x = snappedf(l_temp, zoom) - zoom
		if playhead.position.x < 0:
			playhead.position.x = 0

		Project.playhead_pos = round(playhead.position.x / zoom)


func _prepare_timeline() -> void:
	sidebar.custom_minimum_size.x = SIDEBAR_WIDTH

	for l_track_id: int in Project.tracks.size():
		add_track()
		for l_clip_id: int in Project.tracks[l_track_id].keys():
			add_clip(l_clip_id)

	set_pre_zoom()
	on_zoom()


func set_pre_zoom() -> void:
	pre_mouse_pos = main_control.get_local_mouse_position().x as int
	pre_scroll_pos = scroll_container.scroll_horizontal
	pre_zoom = zoom


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
		set_pre_zoom()
		on_zoom(zoom + 0.05)
	elif a_event.is_action_pressed("zoom_out", true):
		get_viewport().set_input_as_handled()
		set_pre_zoom()
		on_zoom(zoom - 0.05)


#------------------------------------------------ TRACK HANDLING
func add_track() -> void:
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

	l_mute_button.texture_normal = SettingsManager.get_icon("sound_on")
	l_hide_button.texture_normal = SettingsManager.get_icon("visibility_on")

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


func remove_track(a_track_id: int) -> void:
	sidebar.get_children()[a_track_id].queue_free()
	lines_control.get_children()[-1].queue_free()
	# TODO: Reposition all clips if removed track is not form the last line
	_on_tracks_changed()


#------------------------------------------------ CLIP HANDLING
func add_clip(a_clip_id: int) -> void:
	if Project._clip_nodes.has(a_clip_id):
		for l_node: Control in Project._clip_nodes[a_clip_id]:
			if l_node.get_parent() == clips_control:
				return # Already added
		
	var l_node: Control = Control.new()

	# TODO: create clip panel

	clips_control.add_child(l_node)

	if Project._clip_nodes.has(a_clip_id):
		Project._clip_nodes[a_clip_id] = [l_node]
	else:
		var l_array: Array = Project._clip_nodes[a_clip_id]
		l_array.append(l_node)


func resize_clip(a_clip_id: int) -> void:
	pass
	
	

#------------------------------------------------ RESIZE HANDLING
func _on_pts_changed(a_value: float = Project._end_pts) -> void:
	main_control.custom_minimum_size.x = (a_value + TRACK_PADDING + scroll_container.size.x) * zoom


func _on_tracks_changed() -> void:
	main_control.size.y = max(TRACK_HEIGHT * Project.tracks.size(), scroll_container.size.y)


func on_zoom(a_new_zoom: float = zoom) -> void:
	zoom = clamp(a_new_zoom, ZOOM_MIN, ZOOM_MAX)

	# Resizing main control
	_on_pts_changed() # Resizing X
	_on_tracks_changed()  # Resizing Y

	# Correcting horizontal scroll
	if scroll_container.scroll_horizontal != 0:
		scroll_container.scroll_horizontal = abs(((pre_mouse_pos - pre_zoom) * zoom) - pre_mouse_pos - pre_scroll_pos)

	# Correcting playhead position
	if playhead.position.x != 0 and pre_zoom != 0:
		playhead.position.x = playhead.position.x / pre_zoom * zoom

	# TODO: Resize clips

