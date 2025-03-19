class_name Timeline
extends PanelContainer


signal zoom_changed


const TRACK_HEIGHT: int = 30
const LINE_HEIGHT: int = 4

const STYLE_BOXES: Dictionary[File.TYPE, StyleBoxFlat] = {
    File.TYPE.IMAGE: preload("uid://dlxa6tecfxvwa"),
    File.TYPE.AUDIO: preload("uid://b4hr3qnksucav"),
    File.TYPE.VIDEO: preload("uid://dvjs7m2ktd528")
}

static var instance: Timeline

@export var lines: VBoxContainer
@export var scroll_bar: ScrollContainer
@export var scroll_main: ScrollContainer
@export var main_control: Control
@export var clips: Control
@export var preview: Control
@export var playhead: Panel

var playhead_moving: bool = false
var selected_clips: Array[int] = [] # An array of all selected clip id's


var playback_before_moving: bool = false
var zoom: float = 1.0 : set = _set_zoom # How many pixels 1 frame takes

var _offset: int = 0 # Offset for moving/placing clips



func _ready() -> void:
	instance = self
	main_control.set_drag_forwarding(Callable(), _main_control_can_drop_data, _main_control_drop_data)

	@warning_ignore_start("return_value_discarded")
	Editor.frame_changed.connect(move_playhead)
	mouse_exited.connect(func() -> void: preview.visible = false)
	Project.project_ready.connect(_on_project_loaded)



func _on_project_loaded() -> void:
	print("Loading timeline ...")

	for l_child: Node in clips.get_children():
		l_child.queue_free()

	for l_clip: ClipData in Project.get_clip_ids():
		add_clip(l_clip)

	lines.add_child(Control.new())
	lines.add_theme_constant_override("separation", TRACK_HEIGHT)
	main_control.custom_minimum_size.y = (TRACK_HEIGHT + LINE_HEIGHT) * Project.get_track_count()

	for i: int in Project.get_track_count() - 1:
		var l_line: HSeparator = HSeparator.new()

		l_line.add_theme_stylebox_override("separator", load("uid://ccq8hdcqq8xrc") as StyleBoxLine)
		l_line.size.y = LINE_HEIGHT
		lines.add_child(l_line)


	update_end()


func _process(_delta: float) -> void:
	if playhead_moving:
		var l_new_frame: int = clampi(
				floori(main_control.get_local_mouse_position().x / zoom),
				0, Project.get_timeline_end())
		if l_new_frame != Editor.frame_nr:
			Editor.set_frame(l_new_frame)


func _input(a_event: InputEvent) -> void:
	if a_event.is_action_pressed("timeline_zoom_in", false, true):
		zoom += 0.06 if zoom < 1 else 0.2
		get_viewport().set_input_as_handled()
	elif a_event.is_action_pressed("timeline_zoom_out", false, true):
		zoom -= 0.06 if zoom < 1 else 0.2
		get_viewport().set_input_as_handled()


func _on_main_gui_input(a_event: InputEvent) -> void:
	if a_event is not InputEventMouseButton:
		return

	if (a_event as InputEventMouseButton).button_index == MOUSE_BUTTON_LEFT:
		if a_event.is_pressed():
			playhead_moving = true
			playback_before_moving = Editor.is_playing

			if playback_before_moving:
				Editor._on_play_pressed()
		elif a_event.is_released():
			playhead_moving = false

			if playback_before_moving:
				Editor._on_play_pressed()


func _set_zoom(a_new_zoom: float) -> void:
	var l_prev_mouse: int = round(main_control.get_local_mouse_position().x / zoom)

	zoom = clampf(a_new_zoom, 0.2, 10.0)
	move_playhead(Editor.frame_nr)

	# Get all clips, update their size and position
	for l_clip_button: Button in clips.get_children():
		var l_data: ClipData = Project.get_clip(l_clip_button.name.to_int())

		l_clip_button.position.x = l_data.start_frame * zoom
		l_clip_button.size.x = l_data.duration * zoom
		l_clip_button.call("_update_wave")

	update_end()
	var l_now_mouse: int = round(main_control.get_local_mouse_position().x / zoom)

	scroll_main.scroll_horizontal += round((l_prev_mouse - l_now_mouse) * zoom)
	zoom_changed.emit()


func move_playhead(a_frame_nr: int) -> void:
	playhead.position.x = zoom * a_frame_nr


func _main_control_can_drop_data(_pos: Vector2, a_data: Variant) -> bool:
	var l_data: Draggable = a_data
	var l_pos: Vector2 = main_control.get_local_mouse_position()

	# Clear previous preview just in case
	for l_child: Node in preview.get_children():
		l_child.queue_free()

	if l_data.files:
		preview.visible = _can_drop_new_clips(l_pos, l_data)
	else:
		preview.visible = _can_move_clips(l_pos, l_data)

	# Set previews for new clip positions
	return preview.visible


func _can_drop_new_clips(a_pos: Vector2, a_draggable: Draggable) -> bool:
	var l_track: int = clampi(get_track_id(a_pos.y), 0, Project.get_track_count() - 1)
	var l_frame: int = maxi(int(a_pos.x / zoom) - a_draggable.offset, 0)
	var l_region: Vector2i = get_drop_region(l_track, l_frame, a_draggable.ignores)

	var l_end: int = l_frame
	var l_duration: int = 0
	_offset = 0

	# Calculate total duration of all clips together
	for l_file_id: int in a_draggable.ids:
		l_duration += Project.get_file(l_file_id).duration
	l_end = l_frame + l_duration

	# Create a preview
	var l_panel: PanelContainer = PanelContainer.new()

	l_panel.size = Vector2(get_frame_pos(l_duration), TRACK_HEIGHT)
	l_panel.position = Vector2(get_frame_pos(l_frame), get_track_pos(l_track))
	l_panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	l_panel.add_theme_stylebox_override("panel", preload("uid://dx2v44643hfvy"))

	preview.add_child(l_panel)

	# Check if highest
	if l_region.x < l_frame and l_region.y == -1:
		return true

	# Check if clips fits
	if l_region.x < l_frame and l_end < l_region.y:
		return true
	if l_duration > l_region.y - l_region.x:
		if l_region.x != -1 and l_region.y != -1:
			return false

	# Check if overlapping works
	if l_frame <= l_region.x:
		_offset = l_region.x - l_frame

		if l_frame + _offset < l_region.y or l_region.y == -1:
			l_panel.position.x += _offset
			return true
	elif l_end >= l_region.y:
		_offset = l_region.y - l_end

		if l_frame - _offset > l_region.x and l_frame + _offset >= 0:
			l_panel.position.x += _offset
			return true

	preview.remove_child(l_panel)
	return false


func _can_move_clips(a_pos: Vector2, a_draggable: Draggable) -> bool:
	var l_first_clip: ClipData = a_draggable.get_clip_data(0)
	var l_track: int = clampi(get_track_id(a_pos.y), 0, Project.get_track_count() - 1)
	var l_frame: int = maxi(int(a_pos.x / zoom) - a_draggable.offset, 0)

	# Calculate differences of track + frame based on first clip
	a_draggable.differences.y = l_track - l_first_clip.track_id
	a_draggable.differences.x = l_frame - l_first_clip.start_frame

	# Initial boundary check (Track only)
	for l_id: int in a_draggable.ids:
		if !Toolbox.in_range(
				Project.get_clip(l_id).track_id + a_draggable.differences.y as int,
				0, Project.get_track_count()):
			return false

	# Initial region for first clip
	var l_first_new_track: int = l_first_clip.track_id + a_draggable.differences.y
	var l_first_new_frame: int = l_first_clip.start_frame + a_draggable.differences.x
	var l_region: Vector2i = get_drop_region(
			l_first_new_track, l_first_new_frame, a_draggable.ignores)

	# Calculate possible offsets
	var l_offset_range: Vector2i = Vector2i.ZERO

	if l_region.x != -1 and l_first_new_frame <= l_region.x:
		l_offset_range.x = l_region.x - l_first_new_frame
	if l_region.y != -1 and l_first_new_frame + l_first_clip.duration >= l_region.y:
		l_offset_range.y = l_region.y - (l_first_new_frame + l_first_clip.duration)

	# Check all other clips
	for i: int in range(1, a_draggable.ids.size()):
		var l_clip: ClipData = a_draggable.get_clip_data(i)
		var l_new_track: int = l_clip.track_id + a_draggable.differences.y
		var l_new_frame: int = l_clip.start_frame + a_draggable.differences.x
		var l_clip_offsets: Vector2i = Vector2i.ZERO
		var l_clip_region: Vector2i = get_drop_region(
				l_new_track, l_new_frame, a_draggable.ignores)

		# Calculate possible offsets for clip
		if l_clip_region.x != -1 and l_new_frame <= l_clip_region.x:
			l_clip_offsets.x = l_clip_region.x - l_new_frame
		if l_clip_region.y != -1 and l_new_frame + l_clip.duration >= l_clip_region.y:
			l_clip_offsets.y = l_clip_region.y - (l_new_frame + l_clip.duration)

		# Update offset range based on clip offsets
		l_offset_range.x = maxi(l_offset_range.x, l_clip_offsets.x)
		l_offset_range.y = mini(l_offset_range.y, l_clip_offsets.y)

		if l_offset_range.x > l_offset_range.y:
			return false

	# Set final offset
	if l_offset_range.x > 0:
		_offset = l_offset_range.x
	elif l_offset_range.y < 0:
		_offset = l_offset_range.y
	else:
		_offset = 0

	# 0 frame check
	if l_first_new_frame + _offset < 0:
		return false

	# Create preview
	for l_node: Node in preview.get_children():
		preview.remove_child(l_node)

	var l_main_control: Control = Control.new()

	l_main_control.mouse_filter = Control.MOUSE_FILTER_IGNORE
	l_main_control.position.x = get_frame_pos(a_draggable.differences.x + _offset)
	l_main_control.position.y = get_track_pos(a_draggable.differences.y)
	preview.add_child(l_main_control)

	for l_button: Button in a_draggable.clip_buttons:
		var l_new_button: Button = Button.new()

		l_new_button.size = l_button.size
		l_new_button.position = l_button.position
		l_new_button.mouse_filter = Control.MOUSE_FILTER_IGNORE
		l_new_button.clip_children = CanvasItem.CLIP_CHILDREN_AND_DRAW
		l_new_button.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
		# NOTE: Modulate alpha does not work when texture has alpha layers :/
		#		l_new_button.modulate = Color(255,255,255,130)
		l_new_button.modulate = Color(240,240,240)

		if l_button.get_child_count() >= 3:
			l_new_button.add_child(l_button.get_child(2).duplicate()) # Wave Texture rect
			@warning_ignore("unsafe_property_access")

		l_main_control.add_child(l_new_button)

	return true


func _main_control_drop_data(_pos: Vector2, a_data: Variant) -> void:
	var l_draggable: Draggable = a_data
	preview.visible = false

	if l_draggable.files:
		_handle_drop_new_clips(l_draggable)
	else:
		_handle_drop_existing_clips(l_draggable)

	InputManager.undo_redo.add_do_method(Editor.set_frame.bind(Editor.frame_nr))
	InputManager.undo_redo.add_do_method(update_end)

	InputManager.undo_redo.add_undo_method(Editor.set_frame.bind(Editor.frame_nr))
	InputManager.undo_redo.add_undo_method(update_end)

	InputManager.undo_redo.commit_action()


func _handle_drop_new_clips(l_draggable: Draggable) -> void:
	InputManager.undo_redo.create_action("Adding new clips to timeline")

	var l_pos: Vector2 = main_control.get_local_mouse_position()
	var l_ids: Array = []
	var l_track: int = get_track_id(l_pos.y)
	var l_start_frame: int = maxi(
			get_frame_id(l_pos.x) - l_draggable.offset + _offset, 0)

	for l_id: int in l_draggable.ids:
		var l_new_clip_data: ClipData = ClipData.new()

		l_new_clip_data.clip_id = Toolbox.get_unique_id(Project.get_clip_ids())
		l_new_clip_data.file_id = l_id
		l_new_clip_data.start_frame = l_start_frame
		l_new_clip_data.track_id = l_track
		l_new_clip_data.duration = Project.get_file(l_id).duration

		l_ids.append(l_new_clip_data.clip_id)
		l_draggable.new_clips.append(l_new_clip_data)
		l_start_frame += l_new_clip_data.duration

	l_draggable.ids = l_ids

	InputManager.undo_redo.add_do_method(_add_new_clips.bind(l_draggable))
	InputManager.undo_redo.add_undo_method(_remove_new_clips.bind(l_draggable))


func _handle_drop_existing_clips(l_draggable: Draggable) -> void:
	InputManager.undo_redo.create_action("Moving clips on timeline")

	InputManager.undo_redo.add_do_method(_move_clips.bind(
			l_draggable,
			l_draggable.differences.y,
			l_draggable.differences.x + _offset))
	InputManager.undo_redo.add_undo_method(_move_clips.bind(
			l_draggable,
			-l_draggable.differences.y,
			-(l_draggable.differences.x + _offset)))


func _move_clips(a_data: Draggable, a_track_diff: int, a_frame_diff: int) -> void:
	# Go over each clip to update its data
	for i: int in a_data.ids.size():
		var l_data: ClipData = Project.get_clip(a_data.ids[i])
		var l_track: int = l_data.track_id + a_track_diff
		var l_frame: int = l_data.start_frame + a_frame_diff

		# Change data in tracks
		if !Project.get_track_data(l_data.track_id).erase(l_data.start_frame):
			printerr("Could not erase ", a_data.ids[i], " from tracks!")

		# Change clip data
		l_data.track_id = l_track
		l_data.start_frame = l_frame
		Project.get_track_data(l_track)[l_frame] = a_data.ids[i]

		# Change clip button position
		a_data.clip_buttons[i].position = Vector2(
				get_frame_pos(l_frame), get_track_pos(l_track))


func _add_new_clips(a_draggable: Draggable) -> void:
	for l_clip_data: ClipData in a_draggable.new_clips:
		Project.set_clip(l_clip_data.clip_id, l_clip_data)
		Project.get_track_data(l_clip_data.track_id)[l_clip_data.start_frame] = l_clip_data.clip_id

		add_clip(l_clip_data)


func _remove_new_clips(a_draggable: Draggable) -> void:
	for l_clip_data: ClipData in a_draggable.new_clips:
		var l_id: int = l_clip_data.clip_id
		Project.erase_clip(l_id)
		remove_clip(l_id)


func add_clip(a_clip_data: ClipData) -> void:
	var l_button: Button = Button.new()
	var l_style_box: StyleBoxFlat = STYLE_BOXES[Project.get_file(a_clip_data.file_id).type]

	l_button.clip_text = true
	l_button.name = str(a_clip_data.clip_id)
	l_button.text = " " + Project.get_file(a_clip_data.file_id).nickname
	l_button.size.x = zoom * a_clip_data.duration
	l_button.alignment = HORIZONTAL_ALIGNMENT_LEFT
	l_button.position.x = zoom * a_clip_data.start_frame
	l_button.position.y = a_clip_data.track_id * (LINE_HEIGHT + TRACK_HEIGHT)
	l_button.mouse_filter = Control.MOUSE_FILTER_PASS

	l_button.add_theme_stylebox_override("normal", l_style_box)
	l_button.add_theme_stylebox_override("focus", l_style_box)
	l_button.add_theme_stylebox_override("hover", l_style_box)
	l_button.add_theme_stylebox_override("pressed", l_style_box)

	l_button.set_script(load("uid://cvdbyqqvy1rl1"))

	clips.add_child(l_button)


func remove_clip(a_clip_id: int) -> void:
	clips.get_node(str(a_clip_id)).queue_free()


func show_preview(a_track_id: int, a_frame_nr: int, a_duration: int) -> bool:
	preview.position.y = a_track_id * (TRACK_HEIGHT + LINE_HEIGHT)
	preview.position.x = zoom * a_frame_nr
	preview.size.x = zoom * a_duration
	preview.visible = true

	return true


func get_drop_region(a_track: int, a_frame: int, a_ignores: Array[Vector2i]) -> Vector2i:
	# X = lowest, Y = highest
	var l_region: Vector2i = Vector2i(-1, -1)
	var l_keys: PackedInt64Array = Project.get_track_keys(a_track)
	l_keys.sort()

	for a_track_frame: int in l_keys:
		if a_track_frame < a_frame and Vector2i(a_track, a_track_frame) not in a_ignores:
			l_region.x = a_track_frame
		elif a_track_frame > a_frame and Vector2i(a_track, a_track_frame) not in a_ignores:
			l_region.y = a_track_frame
			break

	# Getting the correct end frame
	if l_region.x != -1:
		l_region.x = Project.get_clip(Project.get_track_data(a_track)[l_region.x]).end_frame

	return l_region


func get_lowest_frame(a_track_id: int, a_frame_nr: int, a_ignore: Array[Vector2i]) -> int:
	var l_lowest: int = -1

	if a_track_id > Project.get_track_count() - 1:
		return -1

	for i: int in Project.get_track_keys(a_track_id):
		if i < a_frame_nr:
			if a_ignore.size() >= 1:
				if i == a_ignore[0].y and a_track_id == a_ignore[0].x:
					continue
			l_lowest = i
		elif i >= a_frame_nr:
			break

	if l_lowest == -1:
		return -1

	var l_clip: ClipData = Project.get_clip(Project.get_track_data(a_track_id)[l_lowest])
	return l_clip.duration + l_lowest


func get_highest_frame(a_track_id: int, a_frame_nr: int, a_ignore: Array[Vector2i]) -> int:
	for i: int in Project.get_track_keys(a_track_id):
		# TODO: Change the a_ignore when moving multiple clips
		if i > a_frame_nr:
			if a_ignore.size() >= 1:
				if i == a_ignore[0].y and a_track_id == a_ignore[0].x:
					continue
			return i

	return -1


func update_end() -> void:
	var l_new_end: int = 0

	for l_track: Dictionary[int, int] in Project.get_tracks():
		if l_track.size() == 0:
			continue

		var l_clip: ClipData = Project.get_clip(l_track[l_track.keys().max()])
		var l_value: int = l_clip.duration + l_clip.start_frame

		if l_new_end < l_value:
			l_new_end = l_value
	
	main_control.custom_minimum_size.x = (l_new_end + 1080) * zoom
	Project.set_timeline_end(l_new_end)


func delete_clip(a_clip_data: ClipData) -> void:
	var l_id: int = Project.get_track_data(a_clip_data.track_id)[a_clip_data.start_frame]

	Project.erase_clip(l_id)
	remove_clip(l_id)
	update_end()


func undelete_clip(a_clip_data: ClipData) -> void:
	Project.set_clip(a_clip_data.clip_id, a_clip_data)
	Project.get_track_data(a_clip_data.track_id)[a_clip_data.start_frame] = a_clip_data.clip_id

	add_clip(a_clip_data)
	update_end()


static func get_zoom() -> float:
	return instance.zoom


static func get_frame_id(a_pos: float) -> int:
	return floor(a_pos / get_zoom())


static func get_track_id(a_pos: float) -> int:
	return floor(a_pos / (TRACK_HEIGHT + LINE_HEIGHT))


static func get_frame_pos(a_pos: float) -> float:
	return a_pos * get_zoom()


static func get_track_pos(a_pos: float) -> float:
	return a_pos * (TRACK_HEIGHT + LINE_HEIGHT)


