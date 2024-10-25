extends Control


const TRACK_HEIGHT: int = 40
const TRACK_PADDING: int = 3000

const ZOOM_MIN: float = 0.1
const ZOOM_MAX: float = 6

const SIDEBAR_WIDTH: int = 64


@export var sidebar: VBoxContainer
@export var scroll_container: ScrollContainer

@export var main_control: Control
@export var lines_control: Control
@export var clips_control: Control

@export var playhead: Panel
@export var preview: PanelContainer

var playhead_moving: bool = false
var was_playing: bool = false

var zoom: float = 1.0
var pre_mouse_pos: int = 0
var pre_scroll_pos: int = 0
var pre_zoom: float = 1.0

var snap_limit: float = 100:
	get: return snap_limit * zoom



func _ready() -> void:
	CoreLoader.append_after("Preparing timeline module", _prepare_timeline)

	CoreError.err_connect([
			Project._on_track_added.connect(add_track),
			Project._on_track_removed.connect(remove_track),
			Project._on_clip_added.connect(add_clip),
			Project._on_clip_resized.connect(resize_clip),
			Project._on_clip_moved.connect(move_clip),
			Project._on_end_pts_changed.connect(_on_pts_changed),
	], "Couldn't connect Project signals to Timeline module!")
	CoreError.err_connect([
			GoZenServer._on_current_frame_changed.connect(_on_current_frame_changed),
			get_viewport().size_changed.connect(on_zoom),
			mouse_exited.connect(func()->void: preview.visible = false),
	], "Couldn't connect signals to Timeline module!")


func _process(_delta: float) -> void:
	if playhead_moving:
		var l_temp: float = main_control.get_local_mouse_position().x
		
		playhead.position.x = snappedf(l_temp, zoom) - zoom
		if playhead.position.x < 0:
			playhead.position.x = 0

		Project.playhead_pos = round(playhead.position.x / zoom)

		# TODO: Update displayed frame ever 1/4 of a second for performance if 'was_playing equals true'

	
func _input(a_event: InputEvent) -> void:
	if a_event is InputEventMouseButton and preview.visible and a_event.is_released():
		preview.visible = false


func _prepare_timeline() -> void:
	sidebar.custom_minimum_size.x = SIDEBAR_WIDTH

	for l_track_id: int in Project.tracks.size():
		add_track()
		for l_clip_id: int in Project.tracks[l_track_id].keys():
			add_clip(l_clip_id)

	on_zoom()
	preview.visible = false
	preview.size.y = TRACK_HEIGHT
	preview.mouse_filter = Control.MOUSE_FILTER_IGNORE


func _on_scroll_gui_input(a_event: InputEvent) -> void:
	if (a_event as InputEventWithModifiers).ctrl_pressed:
		get_viewport().set_input_as_handled()


func _on_main_gui_input(a_event: InputEvent) -> void:
	if a_event is InputEventMouseButton and (a_event as InputEventMouseButton).button_index == MOUSE_BUTTON_LEFT:
		if a_event.is_released():
			playhead_moving = false
			GoZenServer.current_frame = max(pos_to_frame(main_control.get_local_mouse_position().x), 0)
			if was_playing:
				GoZenServer._on_play_pressed()
		elif a_event.is_pressed():
			playhead_moving = true
			was_playing = GoZenServer.is_playing
			if was_playing:
				GoZenServer._on_play_pressed()
	
	if a_event.is_action_pressed("zoom_in", true):
		get_viewport().set_input_as_handled()
		on_zoom(zoom + 0.05)
	elif a_event.is_action_pressed("zoom_out", true):
		get_viewport().set_input_as_handled()
		on_zoom(zoom - 0.05)


func _on_current_frame_changed(a_frame: int) -> void:
	playhead.position.x = a_frame * zoom


#------------------------------------------------ TRACK HANDLING
func add_track() -> void:
	var l_header: VBoxContainer = preload("res://modules/panels/default_timeline_panel/header/header.tscn").instantiate()
	sidebar.add_child(l_header)
	l_header.custom_minimum_size.y = TRACK_HEIGHT

	var l_track_line: HSeparator = preload("res://modules/panels/default_timeline_panel/track_separator/track_line.tscn").instantiate()
	lines_control.add_child(l_track_line)
	l_track_line.position.y = ((l_track_line.get_index() + 1) * TRACK_HEIGHT) - l_track_line.size.y

	_on_tracks_changed()


func remove_track(a_track_id: int) -> void:
	sidebar.get_children()[a_track_id].queue_free()
	lines_control.get_children()[-1].queue_free()

	_on_tracks_changed()


#------------------------------------------------ CLIP HANDLING
func add_clip(a_clip_id: int) -> void:
	if Project._clip_nodes.has(a_clip_id):
		for l_node: Control in Project._clip_nodes[a_clip_id]:
			if l_node.get_parent() == clips_control:
				return # Already added
		
	var l_clip_button: Button = preload("res://modules/panels/default_timeline_panel/clip_button/clip_button.tscn").instantiate()

	l_clip_button.name = str(a_clip_id)
	l_clip_button.size = Vector2(frame_to_pos(Project.get_clip_duration(a_clip_id)), TRACK_HEIGHT)
	l_clip_button.position = Vector2(Project.get_clip_pts(a_clip_id) * zoom, Project.get_clip_track(a_clip_id) * TRACK_HEIGHT)

	clips_control.add_child(l_clip_button)

	if !Project._clip_nodes.has(a_clip_id):
		Project._clip_nodes[a_clip_id] = [l_clip_button]
	else:
		var l_array: Array = Project._clip_nodes[a_clip_id]
		l_array.append(l_clip_button)


func move_clip(a_track: int, a_clip_id: int) -> void:
	var l_clip_node: Button = clips_control.get_node(str(a_clip_id))
	l_clip_node.position = Vector2(frame_to_pos(Project.get_clip_pts(a_clip_id)), a_track * TRACK_HEIGHT)


func resize_clip(a_clip_id: int) -> void:
	var l_clip_button: Button = clips_control.get_node(str(a_clip_id))
	l_clip_button.size.x = frame_to_pos(Project.get_clip_duration(a_clip_id))
	l_clip_button.position.x = frame_to_pos(Project.get_clip_pts(a_clip_id))


#------------------------------------------------ RESIZE HANDLING
func _on_pts_changed(a_value: float = Project._end_pts) -> void:
	main_control.custom_minimum_size.x = frame_to_pos((a_value + TRACK_PADDING + scroll_container.size.x) as int)


func _on_tracks_changed() -> void:
	main_control.size.y = max(TRACK_HEIGHT * Project.tracks.size(), scroll_container.size.y)


func on_zoom(a_new_zoom: float = zoom) -> void:
	pre_mouse_pos = main_control.get_local_mouse_position().x as int
	pre_scroll_pos = scroll_container.scroll_horizontal
	pre_zoom = zoom

	zoom = clamp(a_new_zoom, ZOOM_MIN, ZOOM_MAX)

	# Resizing main control
	_on_pts_changed() # Resizing X
	_on_tracks_changed()  # Resizing Y

	# Correcting horizontal scroll
	if scroll_container.scroll_horizontal != 0:
		scroll_container.scroll_horizontal = abs(((pre_mouse_pos - pre_zoom) * zoom) - pre_mouse_pos - pre_scroll_pos)

	# Correcting playhead position
	if playhead.position.x != 0 and pre_zoom != 0:
		playhead.position.x = frame_to_pos((playhead.position.x / pre_zoom) as int)

	for l_clip_button: Button in clips_control.get_children():
		resize_clip(l_clip_button.name.to_int())


#------------------------------------------------ DROP HANDLING
func _can_drop_clip_data(a_pos: Vector2, a_data: Draggable) -> bool:
	# TODO: ADD support for NEW_CLIPS and MOVE_CLIPS
	var l_track_id: int = floor(a_pos.y / TRACK_HEIGHT)
	var l_offset: int = -1000

	if l_track_id > Project.tracks.size() -1:
		preview.visible = false
		return false

	elif a_data.type & 2:
		print("Multiple clips moving/adding not implemented yet!")
		preview.visible = false
		return false

	# NEW CLIP(S)
	elif a_data.type & 1 == 0:
		var l_file: File = Project.files[a_data.data[0]]
		var l_duration: int = l_file.duration 
		var l_pts: int = pos_to_frame(a_pos.x) - (l_duration / 2.) as int

		if l_pts < -snap_limit:
			if _fits(l_track_id, l_duration, 0):
				_set_preview(l_track_id, -1, l_duration, true)
				return true
			preview.visible = false
			return false
		elif _fits(l_track_id, l_duration, l_pts):
			_set_preview(l_track_id, a_pos.x, l_duration, true)
			return true
		else:
			for l_snap: int in snap_limit:
				if _fits(l_track_id, l_duration, l_pts + l_snap):
					l_offset = l_snap
					break
				if _fits(l_track_id, l_duration, l_pts - l_snap):
					l_offset = -l_snap
					break

			if l_offset == -1000:
				preview.visible = false
				return false
			else:
				_set_preview(l_track_id, a_pos.x + frame_to_pos(l_offset), l_duration, true)
				return true

	# MOVE CLIP(S)
	elif a_data.type & 1 == 1:
		var l_clip: ClipData = Project.clips[a_data.data[0]]
		var l_duration: int = l_clip.duration 
		var l_pts: int = Project.clips[a_data.data[0]].pts

		for l_snap: int in snap_limit:
			if _fits(l_track_id, l_duration, (l_pts - pos_to_frame(a_data.mouse_pos)) + l_snap, a_data.data[0]):
				l_offset = l_snap
				break
			if _fits(l_track_id, l_duration, (l_pts - pos_to_frame(a_data.mouse_pos)) + l_duration - l_snap, a_data.data[0]):
				l_offset = -l_snap
				break

		if l_offset == -1000:
			preview.visible = false
			return false
		else:
			_set_preview(l_track_id, a_pos.x - a_data.mouse_pos + frame_to_pos(l_offset), l_duration)
			return true
	else:
		preview.visible = false
		return false


func _drop_clip_data(a_pos: Vector2, a_data: Draggable) -> void:
	var l_track_id: int = floor(a_pos.y / TRACK_HEIGHT)
	var l_pts: int = pos_to_frame(preview.position.x)

	# TODO: Support multiple new clips and move clips
	preview.visible = false

	# NEW CLIP(S)
	if a_data.type & 1 == 0:
		Project._add_clip(a_data.data[0], maxi(l_pts, 0), l_track_id)

	# MOVE CLIP(S)
	elif a_data.type & 1 == 1:
		Project._move_clip(a_data.data[0], l_pts, l_track_id)

	GoZenServer.update_frame_forced()


func _set_preview(a_track: int, a_pos_x: float, a_duration: int, a_new: bool = false) -> void:
	preview.size.x = frame_to_pos(a_duration)

	if a_pos_x == -1:
		preview.position.x = 0
	elif a_new:
		preview.position.x = maxf(a_pos_x - frame_to_pos(a_duration) / 2, 0)	
	else:
		preview.position.x = maxf(a_pos_x, 0)
	
	preview.position.y = a_track * TRACK_HEIGHT
	preview.visible = true


func _fits(a_track: int, a_duration: int, a_pts: int, a_excluded_clip: int = -1) -> bool:
	if Project.tracks[a_track].size() == 0:
		return true

	var l_range: PackedInt64Array = range(a_pts, a_pts + a_duration)
	var l_prev_pts: int = -1

	for l_track_pts: int in Project.tracks[a_track].keys():
		if l_track_pts <= a_pts:
			l_prev_pts = l_track_pts
		elif l_track_pts in l_range:
			if a_excluded_clip == -1 or l_track_pts != Project.get_clip_pts(a_excluded_clip):
				return false
		elif l_track_pts > a_pts + a_duration + 1: # Adding a frame just in case
			break

	if l_prev_pts != -1:
		var l_track_clip: ClipData = Project.clips[Project.tracks[a_track][l_prev_pts]]
		for l_pts: int in range(l_track_clip.pts, l_track_clip.pts + l_track_clip.duration):
			if l_pts in l_range:
				return false

	return true
	

func pos_to_frame(a_pos: float) -> int:
	return floor(a_pos / zoom)


func frame_to_pos(a_frame_nr: int) -> float:
	return a_frame_nr * zoom
