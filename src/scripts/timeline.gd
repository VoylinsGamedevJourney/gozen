class_name Timeline
extends PanelContainer


signal zoom_changed


const TRACK_HEIGHT: int = 30
const LINE_HEIGHT: int = 4

# Normal, Focus
const STYLE_BOXES: Dictionary[File.TYPE, Array] = {
    File.TYPE.IMAGE: [preload("uid://dlxa6tecfxvwa"),preload("uid://bwnfn42mtulgg")],
    File.TYPE.AUDIO: [preload("uid://b4hr3qnksucav"),preload("uid://dxu1itu4lip5q")],
    File.TYPE.VIDEO: [preload("uid://dvjs7m2ktd528"),preload("uid://wied1chri6pt")]
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

var track_overlays: Array[ColorRect] = [] # Indicator if a track is (in)visible

var playback_before_moving: bool = false
var zoom: float = 1.0 : set = _set_zoom # How many pixels 1 frame takes

var _offset: int = 0 # Offset for moving/placing clips



func _ready() -> void:
	instance = self
	main_control.set_drag_forwarding(Callable(), _main_control_can_drop_data, _main_control_drop_data)

	Toolbox.connect_func(Editor.frame_changed, move_playhead)
	Toolbox.connect_func(mouse_exited, func() -> void: preview.visible = false)
	Toolbox.connect_func(Project.project_ready, _on_project_loaded)
	Toolbox.connect_func(Project.file_deleted, _check_clips)


func _process(_delta: float) -> void:
	if playhead_moving:
		var new_frame: int = clampi(
				floori(main_control.get_local_mouse_position().x / zoom),
				0, Project.get_timeline_end())

		if new_frame != Editor.frame_nr:
			Editor.set_frame(new_frame)
			new_frame = -1


func _input(event: InputEvent) -> void:
	if Project.data == null:
		return

	if !Editor.is_playing:
		if event.is_action_pressed("ui_left"):
			Editor.set_frame(Editor.frame_nr - 1)
		elif event.is_action_pressed("ui_right"):
			Editor.set_frame(Editor.frame_nr + 1)

	if event is InputEventMouseButton and (event as InputEventMouseButton).is_released():
		if preview.visible:
			preview.visible = false
		

	if !main_control.get_global_rect().has_point(get_global_mouse_position()):
		return
	if event is InputEventMouseButton and (event as InputEventMouseButton).double_click:
		var mod: int = Settings.get_delete_empty_modifier()

		if mod == KEY_NONE or Input.is_key_pressed(mod):
			_delete_empty_space()
			get_viewport().set_input_as_handled()


func _on_timeline_scroll_gui_input(event: InputEvent) -> void:
	if Project.data == null:
		return

	if event.is_action_pressed("timeline_zoom_in", false, true):
		zoom *= 1.15
		get_viewport().set_input_as_handled()
	elif event.is_action_pressed("timeline_zoom_out", false, true):
		zoom /= 1.15
		get_viewport().set_input_as_handled()
	
	if event.is_action("scroll_up", true):
		scroll_main.scroll_vertical -= int(scroll_main.scroll_vertical_custom_step * zoom)
		get_viewport().set_input_as_handled()
	elif event.is_action("scroll_down", true):
		scroll_main.scroll_vertical += int(scroll_main.scroll_vertical_custom_step * zoom)
		get_viewport().set_input_as_handled()
	elif event.is_action("scroll_left", true):
		scroll_main.scroll_horizontal -= int(scroll_main.scroll_horizontal_custom_step * zoom)
		get_viewport().set_input_as_handled()
	elif event.is_action("scroll_right", true):
		scroll_main.scroll_horizontal += int(scroll_main.scroll_horizontal_custom_step * zoom)
		get_viewport().set_input_as_handled()
			

func _on_main_gui_input(event: InputEvent) -> void:
	if event is not InputEventMouseButton:
		return

	if (event as InputEventMouseButton).button_index == MOUSE_BUTTON_LEFT:
		if event.is_pressed() and !Input.is_key_pressed(KEY_SHIFT) and !Input.is_key_pressed(KEY_CTRL):
			if Settings.get_pause_after_drag() and Editor.is_playing:
				Editor.on_play_pressed()

			playhead_moving = true
			playback_before_moving = Editor.is_playing

			if playback_before_moving:
				Editor.on_play_pressed()
		elif event.is_released():
			playhead_moving = false

			if playback_before_moving:
				Editor.on_play_pressed()


func _set_zoom(new_zoom: float) -> void:
	if zoom == new_zoom:
		return

	# We need to await to get the correct get_local_mouse_position
	await RenderingServer.frame_post_draw
	var prev_mouse_x: float = main_control.get_local_mouse_position().x
	var prev_scroll: int = scroll_main.scroll_horizontal
	var prev_mouse_frame: int = get_frame_id(prev_mouse_x)

	zoom = clampf(new_zoom, 0.001, 40.0)

	# TODO: Make this better
	if zoom > 30:
		scroll_main.scroll_horizontal_custom_step = 1
	elif zoom > 20:
		scroll_main.scroll_horizontal_custom_step = 2
	elif zoom > 10:
		scroll_main.scroll_horizontal_custom_step = 4
	elif zoom > 5:
		scroll_main.scroll_horizontal_custom_step = 8
	elif zoom > 1:
		scroll_main.scroll_horizontal_custom_step = 18
	elif zoom > 0.4:
		scroll_main.scroll_horizontal_custom_step = 40
	else:
		scroll_main.scroll_horizontal_custom_step = 100

	move_playhead(Editor.frame_nr)

	# Get all clips, update their size and position
	for clip_button: Button in clips.get_children():
		var data: ClipData = Project.get_clip(clip_button.name.to_int())

		clip_button.position.x = get_frame_pos(data.start_frame)
		clip_button.size.x = get_clip_size(data.duration)

	update_end()

	var new_mouse_x: float = prev_mouse_frame * zoom
	scroll_main.scroll_horizontal = int(new_mouse_x - (prev_mouse_x - prev_scroll))

	Project.set_timeline_scroll_h(scroll_main.scroll_horizontal)
	Project.set_zoom(zoom)
	zoom_changed.emit()


func _on_project_loaded() -> void:
	for child: Node in clips.get_children():
		child.queue_free()

	for clip: ClipData in Project.get_clip_datas():
		add_clip(clip)

	main_control.custom_minimum_size.y = (TRACK_HEIGHT + LINE_HEIGHT) * Project.get_track_count()

	for i: int in Project.get_track_count() - 1:
		var overlay: ColorRect = ColorRect.new()
		var line: HSeparator = HSeparator.new()

		overlay.mouse_filter = Control.MOUSE_FILTER_IGNORE
		overlay.color = Color.DARK_GRAY
		overlay.self_modulate = Color("ffffff00")
		overlay.custom_minimum_size.y = TRACK_HEIGHT
		track_overlays.append(overlay)

		line.mouse_filter = Control.MOUSE_FILTER_PASS
		line.add_theme_stylebox_override("separator", load("uid://ccq8hdcqq8xrc") as StyleBoxLine)
		line.size.y = LINE_HEIGHT

		lines.add_child(overlay)
		lines.add_child(line)

	update_end()
	_set_zoom(Project.get_zoom())
	scroll_main.scroll_horizontal = Project.get_timeline_scroll_h()


func _check_clips() -> void:
	# Get's called after deleting of a file.
	var ids: PackedInt64Array = Project.get_clip_ids()

	# Check for buttons which need to be deleted.
	for clip_button: Button in clips.get_children():
		var clip_id: int = int(clip_button.name)

		if clip_id not in ids:
			clip_button.queue_free()
		else:
			ids.remove_at(ids.find(clip_id))
			
	# Check for buttons which need to be added.
	for clip_id: int in ids:
		add_clip(Project.get_clip(clip_id))


func _main_control_can_drop_data(_pos: Vector2, data: Variant) -> bool:
	var draggable: Draggable = data
	var pos: Vector2 = main_control.get_local_mouse_position()

	# Clear previous preview just in case
	for child: Node in preview.get_children():
		child.queue_free()

	if !main_control.get_global_rect().has_point(get_global_mouse_position()):
		preview.visible = false
	elif draggable.files:
		preview.visible = _can_drop_new_clips(pos, draggable)
	else:
		preview.visible = _can_move_clips(pos, draggable)

	# Set previews for new clip positions
	return preview.visible


func _can_drop_new_clips(pos: Vector2, draggable: Draggable) -> bool:
	var track: int = clampi(get_track_id(pos.y), 0, Project.get_track_count() - 1)
	var frame: int = maxi(int(pos.x / zoom) - draggable.offset, 0)
	var region: Vector2i = get_drop_region(track, frame, draggable.ignores)

	var end: int = frame
	var duration: int = 0
	_offset = 0

	# Calculate total duration of all clips together
	for file_id: int in draggable.ids:
		duration += Project.get_file(file_id).duration
	end = frame + duration

	# Create a preview
	var panel: PanelContainer = PanelContainer.new()

	panel.size = Vector2(get_frame_pos(duration), TRACK_HEIGHT)
	panel.position = Vector2(get_frame_pos(frame), get_track_pos(track))
	panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	panel.add_theme_stylebox_override("panel", preload("uid://dx2v44643hfvy"))

	preview.add_child(panel)

	# Check if highest
	if region.x < frame and region.y == -1:
		return true

	# Check if clips fits
	if region.x < frame and end < region.y:
		return true
	if duration > region.y - region.x:
		if region.x != -1 and region.y != -1:
			return false

	# Check if overlapping works
	if frame <= region.x:
		_offset = region.x - frame

		if frame + _offset < region.y or region.y == -1:
			panel.position.x += _offset * zoom
			return true
	elif end >= region.y:
		_offset = region.y - end

		if frame - _offset > region.x and frame + _offset >= 0:
			panel.position.x += _offset * zoom
			return true

	preview.remove_child(panel)
	return false


func _can_move_clips(pos: Vector2, draggable: Draggable) -> bool:
	var first_clip: ClipData = draggable.get_clip_data(0)
	var track: int = clampi(get_track_id(pos.y), 0, Project.get_track_count() - 1)
	var frame: int = maxi(int(pos.x / zoom) - draggable.offset, 0)

	# Calculate differences of track + frame based on first clip
	draggable.differences.y = track - first_clip.track_id
	draggable.differences.x = frame - first_clip.start_frame

	# Initial boundary check (Track only)
	for id: int in draggable.ids:
		if !Toolbox.in_range(
				Project.get_clip(id).track_id + draggable.differences.y as int,
				0, Project.get_track_count()):
			return false

	# Initial region for first clip
	var first_new_track: int = first_clip.track_id + draggable.differences.y
	var first_new_frame: int = first_clip.start_frame + draggable.differences.x
	var region: Vector2i = get_drop_region(
			first_new_track, first_new_frame, draggable.ignores)

	if region.x == first_clip.end_frame and region.y == -1:
		# This means the drop is at the original clip's location
		_offset = 0
		return true

	# Checking if the clip actually fits in the space or not
	var region_duration: int = region.x + region.y

	if region.y != -1:
		if region_duration > 0 and region_duration < first_clip.duration:
			return false
	
	# Calculate possible offsets
	var offset_range: Vector2i = Vector2i.ZERO

	if region.x != -1 and first_new_frame <= region.x:
		offset_range.x = region.x - first_new_frame
	if region.y != -1 and first_new_frame + first_clip.duration - 1 >= region.y:
		offset_range.y = region.y - (first_new_frame + first_clip.duration - 1)

	# Check all other clips
	for i: int in range(1, draggable.ids.size()):
		var clip: ClipData = draggable.get_clip_data(i)
		var new_track: int = clip.track_id + draggable.differences.y
		var new_frame: int = clip.start_frame + draggable.differences.x
		var clip_offsets: Vector2i = Vector2i.ZERO
		var clip_region: Vector2i = get_drop_region(
				new_track, new_frame, draggable.ignores)

		# Calculate possible offsets for clip
		if clip_region.x != -1 and new_frame <= clip_region.x:
			clip_offsets.x = clip_region.x - new_frame
		if clip_region.y != -1 and new_frame + clip.duration >= clip_region.y:
			clip_offsets.y = clip_region.y - clip.get_end_frame()

		# Update offset range based on clip offsets
		offset_range.x = maxi(offset_range.x, clip_offsets.x)
		offset_range.y = mini(offset_range.y, clip_offsets.y)

		if offset_range.x > offset_range.y:
			return false

	# Set final offset
	if offset_range.x > 0:
		_offset = offset_range.x
	elif offset_range.y < 0:
		_offset = offset_range.y
	else:
		_offset = 0

	# 0 frame check
	if first_new_frame + _offset < 0:
		return false

	# Create preview
	for node: Node in preview.get_children():
		preview.remove_child(node)

	var control: Control = Control.new()

	control.mouse_filter = Control.MOUSE_FILTER_IGNORE
	control.position.x = get_frame_pos(draggable.differences.x + _offset)
	control.position.y = get_track_pos(draggable.differences.y)
	preview.add_child(control)

	for button: Button in draggable.clip_buttons:
		var new_button: PreviewAudioWave = PreviewAudioWave.new()

		new_button.clip_data = Project.get_clip(int(button.name))

		new_button.size = button.size
		new_button.position = button.position
		new_button.mouse_filter = Control.MOUSE_FILTER_IGNORE
		new_button.clip_children = CanvasItem.CLIP_CHILDREN_AND_DRAW
		new_button.add_theme_stylebox_override("normal", preload("uid://dx2v44643hfvy"))
		# NOTE: Modulate alpha does not work when texture has alpha layers :/
		#		new_button.modulate = Color(255,255,255,130)
		new_button.modulate = Color(240,240,240)

		new_button.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND

		if button.get_child_count() >= 3:
			new_button.add_child(button.get_child(2).duplicate()) # Wave Texture rect

		control.add_child(new_button)

	return true


func _main_control_drop_data(_pos: Vector2, data: Variant) -> void:
	var draggable: Draggable = data
	preview.visible = false

	if draggable.files:
		_handle_drop_new_clips(draggable)
	else:
		_handle_drop_existing_clips(draggable)

	InputManager.undo_redo.add_do_method(Editor.set_frame.bind(Editor.frame_nr))
	InputManager.undo_redo.add_do_method(update_end)

	InputManager.undo_redo.add_undo_method(Editor.set_frame.bind(Editor.frame_nr))
	InputManager.undo_redo.add_undo_method(update_end)

	InputManager.undo_redo.commit_action()


func _handle_drop_new_clips(draggable: Draggable) -> void:
	InputManager.undo_redo.create_action("Adding new clips to timeline")

	var pos: Vector2 = main_control.get_local_mouse_position()
	var ids: Array = []
	var track: int = get_track_id(pos.y)
	var start_frame: int = maxi(
			get_frame_id(pos.x) - draggable.offset + _offset, 0)

	for id: int in draggable.ids:
		var new_clip_data: ClipData = ClipData.new()

		new_clip_data.clip_id = Toolbox.get_unique_id(Project.get_clip_ids())
		new_clip_data.file_id = id
		new_clip_data.start_frame = start_frame
		new_clip_data.track_id = track
		new_clip_data.duration = Project.get_file(id).duration
		new_clip_data.effects_video = EffectsVideo.new()
		new_clip_data.effects_audio = EffectsAudio.new()

		new_clip_data.effects_video.set_default_transform()

		ids.append(new_clip_data.clip_id)
		draggable.new_clips.append(new_clip_data)
		start_frame += new_clip_data.duration - 1

	draggable.ids = ids

	InputManager.undo_redo.add_do_method(_add_new_clips.bind(draggable))
	InputManager.undo_redo.add_undo_method(_remove_new_clips.bind(draggable))


func _handle_drop_existing_clips(draggable: Draggable) -> void:
	InputManager.undo_redo.create_action("Moving clips on timeline")

	InputManager.undo_redo.add_do_method(_move_clips.bind(
			draggable,
			draggable.differences.y,
			draggable.differences.x + _offset))
	InputManager.undo_redo.add_undo_method(_move_clips.bind(
			draggable,
			-draggable.differences.y,
			-(draggable.differences.x + _offset)))


func _move_clips(draggable: Draggable, track_diff: int, frame_diff: int) -> void:
	# Go over each clip to update its data
	for i: int in draggable.ids.size():
		var data: ClipData = Project.get_clip(draggable.ids[i])
		var track: int = data.track_id + track_diff
		var frame: int = data.start_frame + frame_diff

		Project.erase_track_entry(data.track_id, data.start_frame)

		# Change clip data
		data.track_id = track
		data.start_frame = frame
		Project.set_track_data(track, frame, draggable.ids[i])

		# Change clip button position
		draggable.clip_buttons[i].position = Vector2(
				get_frame_pos(frame), get_track_pos(track))


func _add_new_clips(draggable: Draggable) -> void:
	for clip_data: ClipData in draggable.new_clips:
		Project.set_clip(clip_data.clip_id, clip_data)
		Project.set_track_data(clip_data.track_id, clip_data.start_frame, clip_data.clip_id)

		add_clip(clip_data)


func _remove_new_clips(draggable: Draggable) -> void:
	for clip_data: ClipData in draggable.new_clips:
		var id: int = clip_data.clip_id
		Project.erase_clip(id)
		remove_clip(id)


func add_clip(clip_data: ClipData) -> void:
	var button: Button = Button.new()

	button.clip_text = true
	button.name = str(clip_data.clip_id)
	button.text = " " + Project.get_file(clip_data.file_id).nickname
	button.size.x = get_clip_size(clip_data.duration)
	button.size.y = TRACK_HEIGHT
	button.alignment = HORIZONTAL_ALIGNMENT_LEFT
	button.position.x = zoom * clip_data.start_frame
	button.position.y = clip_data.track_id * (LINE_HEIGHT + TRACK_HEIGHT)
	button.mouse_filter = Control.MOUSE_FILTER_PASS
	button.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND

	@warning_ignore_start("unsafe_call_argument")
	button.add_theme_stylebox_override("normal", STYLE_BOXES[Project.get_file(clip_data.file_id).type][0])
	button.add_theme_stylebox_override("focus", STYLE_BOXES[Project.get_file(clip_data.file_id).type][1])
	button.add_theme_stylebox_override("hover", STYLE_BOXES[Project.get_file(clip_data.file_id).type][0])
	button.add_theme_stylebox_override("pressed", STYLE_BOXES[Project.get_file(clip_data.file_id).type][0])
	@warning_ignore_restore("unsafe_call_argument")

	button.set_script(load("uid://cvdbyqqvy1rl1"))

	clips.add_child(button)


func remove_clip(clip_id: int) -> void:
	clips.get_node(str(clip_id)).queue_free()


func get_drop_region(track: int, frame: int, ignores: Array[Vector2i]) -> Vector2i:
	# X = lowest, Y = highest
	var region: Vector2i = Vector2i(-1, -1)
	var keys: PackedInt64Array = Project.get_track_keys(track)
	keys.sort()

	for track_frame: int in keys:
		if track_frame < frame and Vector2i(track, track_frame) not in ignores:
			region.x = track_frame
		elif track_frame > frame and Vector2i(track, track_frame) not in ignores:
			region.y = track_frame
			break

	# Getting the correct end frame
	if region.x != -1:
		region.x = Project.get_clip(Project.get_track_data(track)[region.x]).end_frame + 1

	return region


func get_lowest_frame(track_id: int, frame_nr: int, ignore: Array[Vector2i] = []) -> int:
	var lowest: int = -1

	if track_id > Project.get_track_count() - 1:
		return -1

	for i: int in Project.get_track_keys(track_id):
		if i < frame_nr:
			if ignore.size() >= 1:
				if i == ignore[0].y and track_id == ignore[0].x:
					continue
			lowest = i
		elif i >= frame_nr:
			break

	if lowest == -1:
		return -1

	var clip: ClipData = Project.get_clip(Project.get_track_data(track_id)[lowest])
	return clip.duration + lowest


func get_highest_frame(track_id: int, frame_nr: int, ignore: Array[Vector2i] = []) -> int:
	for i: int in Project.get_track_keys(track_id):
		# TODO: Change the ignore when moving multiple clips
		if i > frame_nr:
			if ignore.size() >= 1:
				if i == ignore[0].y and track_id == ignore[0].x:
					continue
			return i

	return -1


func update_end() -> void:
	var new_end: int = 0

	for track: Dictionary[int, int] in Project.get_tracks():
		if track.size() == 0:
			continue

		var clip: ClipData = Project.get_clip(track[track.keys().max()])
		var value: int = clip.get_end_frame()

		if new_end < value:
			new_end = value
	
	main_control.custom_minimum_size.x = (new_end + 1080) * zoom
	lines.custom_minimum_size.x = (new_end + 1080) * zoom
	Project.set_timeline_end(new_end)


func delete_clip(clip_data: ClipData) -> void:
	var id: int = Project.get_track_data(clip_data.track_id)[clip_data.start_frame]

	Project.erase_clip(id)
	remove_clip(id)
	update_end()


func undelete_clip(clip_data: ClipData) -> void:
	Project.set_clip(clip_data.clip_id, clip_data)
	Project.set_track_data(clip_data.track_id, clip_data.start_frame, clip_data.clip_id)

	add_clip(clip_data)
	update_end()


func move_playhead(frame_nr: int) -> void:
	playhead.position.x = zoom * frame_nr


static func get_clip_size(duration: int) -> float:
	return instance.zoom * duration


static func get_zoom() -> float:
	return instance.zoom


static func get_frame_id(pos: float) -> int:
	return floor(pos / get_zoom())


static func get_track_id(pos: float) -> int:
	return floor(pos / (TRACK_HEIGHT + LINE_HEIGHT))


static func get_frame_pos(frame_nr: int) -> float:
	return frame_nr * get_zoom()


static func get_track_pos(track_id: int) -> float:
	return track_id * (TRACK_HEIGHT + LINE_HEIGHT)


func _delete_empty_space() -> void:
	var mouse_track: int = get_track_id(main_control.get_local_mouse_position().y)
	var mouse_frame: int = get_frame_id(main_control.get_local_mouse_position().x)
	var lowest_frame: int = get_lowest_frame(mouse_track, mouse_frame)
	var highest_frame: int = get_highest_frame(mouse_track,mouse_frame)

	if highest_frame < 0:
		return # Nothing to erase

	var draggable: Draggable = Draggable.new()
	draggable.differences = Vector2i(highest_frame - lowest_frame, 0)

	var track_data: Dictionary[int, int] = Project.get_track_data(mouse_track)
	for frame_nr: int in track_data.keys():
		if frame_nr < highest_frame:
			continue

		draggable.clip_buttons.append(clips.get_node(str(track_data[frame_nr])))
		if draggable.ids.append(track_data[frame_nr]):
			Toolbox.print_append_error()
			continue

	InputManager.undo_redo.create_action("Delete empty space")

	InputManager.undo_redo.add_do_method(_move_clips.bind(
			draggable,
			draggable.differences.y,
			-draggable.differences.x))
	InputManager.undo_redo.add_do_method(Editor.update_frame)

	InputManager.undo_redo.add_undo_method(_move_clips.bind(
			draggable,
			draggable.differences.y,
			draggable.differences.x))
	InputManager.undo_redo.add_undo_method(Editor.update_frame)

	InputManager.undo_redo.commit_action()

