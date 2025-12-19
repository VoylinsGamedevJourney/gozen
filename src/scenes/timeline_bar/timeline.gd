class_name Timeline
extends PanelContainer

# TODO: Remove timestampbox and timeline bar stuff from files.
# TODO: DrawManager needs a lot of re-work, or maybe will be unnecessary after changes.
# TODO: DrawManager line 106 for drawing audio waves.
# TODO: DrawManager line 150 for drawing fades.

# TODO: Effects panel line 316, fix fading feedback

# TODO: Implement multi clip select with draggable rectangle

const TIMELINE_PADDING: int = 3000 # Amount of frames after timeline_end.

const TRACK_HEIGHT: int = 30
const TRACK_LINE_HEIGHT: int = 1
const TOTAL_TRACK_HEIGHT: int = TRACK_HEIGHT + TRACK_LINE_HEIGHT

const PLAYHEAD_WIDTH: int = 2

const DRAG_FLEXIBILITY: int = 30

const STYLE_BOX_PREVIEW: StyleBox = preload("uid://dx2v44643hfvy")
const STYLE_BOXES: Dictionary[File.TYPE, Array] = {
    File.TYPE.IMAGE: [preload(Library.STYLE_BOX_CLIP_IMAGE_NORMAL), preload(Library.STYLE_BOX_CLIP_IMAGE_FOCUS)],
    File.TYPE.AUDIO: [preload(Library.STYLE_BOX_CLIP_AUDIO_NORMAL), preload(Library.STYLE_BOX_CLIP_AUDIO_FOCUS)],
    File.TYPE.VIDEO: [preload(Library.STYLE_BOX_CLIP_VIDEO_NORMAL), preload(Library.STYLE_BOX_CLIP_VIDEO_FOCUS)],
    File.TYPE.COLOR: [preload(Library.STYLE_BOX_CLIP_COLOR_NORMAL), preload(Library.STYLE_BOX_CLIP_COLOR_FOCUS)],
    File.TYPE.TEXT:  [preload(Library.STYLE_BOX_CLIP_TEXT_NORMAL), preload(Library.STYLE_BOX_CLIP_TEXT_FOCUS)],
}
const TEXT_OFFSET: Vector2 = Vector2(5, 20)

@onready var scroll_container: ScrollContainer = self.get_parent()

var track_line_heights: PackedInt64Array = []
var drag_previews: Array[Rect2] = []
var visible_clip_ids: PackedInt64Array = []
var selected_clip_ids: PackedInt64Array = []
var zoom: float = 1.0

var _drag_offset: int = 0
var _drag_offset_track: int = 0



func _ready() -> void:
	Project.project_ready.connect(_project_ready)
	Project.timeline_end_update.connect(_timeline_end_update)
	ClipHandler.clip_added.connect(_force_refresh)
	ClipHandler.clip_deleted.connect(_force_refresh)
	TrackHandler.updated.connect(update_track_count)
	EditorCore.frame_changed.connect(queue_redraw)

	set_drag_forwarding(_drag, _can_drop_data, _drop_data)


func _input(event: InputEvent) -> void:
	if event.is_action_pressed("delete_clips"):
		ClipHandler.delete_clips(selected_clip_ids)


func _on_gui_input(event: InputEvent) -> void:
	if !Project.loaded:
		return
	elif !Input.is_mouse_button_pressed(MOUSE_BUTTON_LEFT):
		drag_previews = []
		queue_redraw()

	if event is InputEventMouseButton:
		get_window().gui_release_focus()
		_on_gui_input_mouse(event)


func _on_gui_input_mouse(event: InputEventMouseButton) -> void:
	if event.is_pressed() and event.button_index == MOUSE_BUTTON_LEFT:
		# Check if clip is pressed or not.
		var clip: ClipData = _get_clip_on_mouse()

		if clip != null:
			if event.shift_pressed:
				selected_clip_ids.append(clip.id)
			else:
				selected_clip_ids = [clip.id]
		else:
			selected_clip_ids = []
	elif event.is_pressed() and event.button_index == MOUSE_BUTTON_RIGHT:
		# TODO: Right click menu
		pass


func _get_clip_on_mouse() -> ClipData:
	var mouse_track: int = get_track_from_mouse_pos()
	var mouse_frame: int = get_frame_from_mouse_pos()

	return TrackHandler.get_clip_at(mouse_track, mouse_frame)


func _draw() -> void:
	var mouse_track: int = get_track_from_mouse_pos()
	var mouse_frame: int = get_frame_from_mouse_pos()
	var playhead_pos_x: float = EditorCore.frame_nr * zoom

	_get_visible_clips()

	# - Track lines
	for i: int in track_line_heights:
		draw_dashed_line(
				Vector2(0, i), Vector2(size.x, i),
				Color(0.3,0.3,0.3), TRACK_LINE_HEIGHT)

	# - Playhead
	draw_line(
			Vector2(playhead_pos_x, 0), Vector2(playhead_pos_x, size.y),
			Color(0.4, 0.4, 0.4), PLAYHEAD_WIDTH)

	# - Clip preview(s) - moving or dragging new clip
	for preview: Rect2 in drag_previews:
		var new_preview: Rect2 = preview.grow_side(SIDE_BOTTOM, TRACK_HEIGHT)

		new_preview.position.y += TOTAL_TRACK_HEIGHT * mouse_track
		new_preview.position.x = max(0, mouse_frame - _drag_offset)
		draw_style_box(STYLE_BOX_PREVIEW, new_preview)

	# - Clip blocks
	for clip_id: int in visible_clip_ids:
		var clip: ClipData = ClipHandler.get_clip(clip_id)
		var box_type: int = 1 if clip.id in selected_clip_ids else 0
		var pos: Vector2 = Vector2(clip.start_frame * zoom, TOTAL_TRACK_HEIGHT * clip.track_id)
		var new_clip: Rect2 = Rect2(pos, Vector2(clip.duration * zoom, TRACK_HEIGHT))

		draw_style_box(STYLE_BOXES[ClipHandler.get_clip_type(clip)][box_type], new_clip)
		draw_string(
				get_theme_default_font(),
				pos + TEXT_OFFSET,
				FileHandler.get_file_name(clip.file_id),
				HORIZONTAL_ALIGNMENT_LEFT, 0,
				11, # Font size
				Color(0.9, 0.9, 0.9))
		
	# TODO: - Audio waves

	# TODO: - Fading handles + amount


func _on_mouse_exited() -> void:
	# Making sure drag previews dissapear when mouse leaves the timeline.
	drag_previews = []
	queue_redraw()

	
func _get_visible_clips() -> void:
	var visible_start: int = floori(scroll_container.scroll_horizontal * zoom)
	var visible_end: int = floori(visible_start + (scroll_container.size.x / zoom))

	visible_clip_ids = []

	for track_id: int in TrackHandler.get_tracks_size():
		for clip: ClipData in TrackHandler.get_clips_in(track_id, visible_start, visible_end):
			visible_clip_ids.append(clip.id)


func _project_ready() -> void:
	update_track_count()


func _timeline_end_update(new_end: int) -> void:
	custom_minimum_size.x = max(ceili(new_end * zoom), TIMELINE_PADDING)


func _drag(_at_position: Vector2) -> void:
	# TODO:
	# Decide if I'm in an empty space on the timeline to create a selection box.
	# Also check if I'm not dragging a fade handle.
	# If not, check if selected clip is part of selected group and move the selected clip(s)
	pass


func _can_drop_data(pos: Vector2, data: Variant) -> bool:
	var draggable: Draggable = data

	drag_previews = []

	if draggable.files:
		if !_can_drop_new_clips(pos, draggable):
			queue_redraw()
			return false
	elif !_can_move_clips(pos, draggable):
		queue_redraw()
		return false
	
	drag_previews = draggable.rects
	queue_redraw()
	return true


func _can_drop_new_clips(_p: Vector2, draggable: Draggable) -> bool:
	var track_id: int = get_track_from_mouse_pos()
	var frame_nr: int = max(0, get_frame_from_mouse_pos() - draggable.offset)
	var duration: int = draggable.duration
	var difference: int = 0
	var region: Vector2i = TrackHandler.get_free_region(track_id, frame_nr)
	var region_space: int = region.y - region.x

	if region_space < duration:
		return false # No space for the clip(s)

	_drag_offset = draggable.offset

	if frame_nr < region.x:
		difference = frame_nr - region.x
	elif frame_nr + duration > region.y:
		difference = frame_nr + duration - region.y

	_drag_offset += difference
	return abs(difference) <= DRAG_FLEXIBILITY


func _can_move_clips(_pos: Vector2, _draggable: Draggable) -> bool:
#	var first_clip: ClipData = draggable.get_clip_data(0)
#	var track: int = clampi(get_track_id(pos.y), 0, Project.get_track_count() - 1)
#	var frame: int = maxi(int(pos.x / zoom) - draggable.offset, 0)
#
#	# Calculate differences of track + frame based on first clip
#	draggable.differences.y = track - first_clip.track_id
#	draggable.differences.x = frame - first_clip.start_frame
#
#	# Initial boundary check (Track only)
#	for id: int in draggable.ids:
#		if !Utils.in_range(
#				Project.get_clip(id).track_id + draggable.differences.y as int,
#				0, Project.get_track_count()):
#			return false
#
#	# Initial region for first clip
#	var first_new_track: int = first_clip.track_id + draggable.differences.y
#	var first_new_frame: int = first_clip.start_frame + draggable.differences.x
#	var region: Vector2i = get_drop_region(
#			first_new_track, first_new_frame, draggable.ignores)
#
#	if region.x == first_clip.end_frame and region.y == -1:
#		# This means the drop is at the original clip's location
#		_offset = 0
#		return true
#
#	# Checking if the clip actually fits in the space or not
#	var region_duration: int = region.x + region.y
#
#	if region.y != -1:
#		if region_duration > 0 and region_duration < first_clip.duration:
#			return false
#	
#	# Calculate possible offsets
#	var offset_range: Vector2i = Vector2i.ZERO
#
#	if region.x != -1 and first_new_frame <= region.x:
#		offset_range.x = region.x - first_new_frame
#	if region.y != -1 and first_new_frame + first_clip.duration - 1 >= region.y:
#		offset_range.y = region.y - (first_new_frame + first_clip.duration - 1)
#
#	# Check all other clips
#	for i: int in range(1, draggable.ids.size()):
#		var clip: ClipData = draggable.get_clip_data(i)
#		var new_track: int = clip.track_id + draggable.differences.y
#		var new_frame: int = clip.start_frame + draggable.differences.x
#		var clip_offsets: Vector2i = Vector2i.ZERO
#		var clip_region: Vector2i = get_drop_region(
#				new_track, new_frame, draggable.ignores)
#
#		# Calculate possible offsets for clip
#		if clip_region.x != -1 and new_frame <= clip_region.x:
#			clip_offsets.x = clip_region.x - new_frame
#		if clip_region.y != -1 and new_frame + clip.duration >= clip_region.y:
#			clip_offsets.y = clip_region.y - clip.get_end_frame()
#
#		# Update offset range based on clip offsets
#		offset_range.x = maxi(offset_range.x, clip_offsets.x)
#		offset_range.y = mini(offset_range.y, clip_offsets.y)
#
#		if offset_range.x > offset_range.y:
#			return false
#
#	# Set final offset
#	if offset_range.x > 0:
#		_offset = offset_range.x
#	elif offset_range.y < 0:
#		_offset = offset_range.y
#	else:
#		_offset = 0
#
#	# 0 frame check
#	if first_new_frame + _offset < 0:
#		return false
#
#	# Create preview
#	for node: Node in preview.get_children():
#		preview.remove_child(node)
#
#	var control: Control = Control.new()
#
#	control.mouse_filter = Control.MOUSE_FILTER_IGNORE
#	control.position.x = get_frame_pos(draggable.differences.x + _offset)
#	control.position.y = get_track_pos(draggable.differences.y)
#	preview.add_child(control)
#
#	for button: Button in draggable.clip_buttons:
#		var new_button: PreviewAudioWave = PreviewAudioWave.new()
#
#		new_button.clip_data = Project.get_clip(int(button.name))
#
#		new_button.size = button.size
#		new_button.position = button.position
#		new_button.mouse_filter = Control.MOUSE_FILTER_IGNORE
#		new_button.clip_children = CanvasItem.CLIP_CHILDREN_AND_DRAW
#		new_button.add_theme_stylebox_override("normal", preload(Library.STYLE_BOX_CLIP_PREVIEW))
#		# NOTE: Modulate alpha does not work when texture has alpha layers :/
#		#		new_button.modulate = Color(255,255,255,130)
#		new_button.modulate = Color(240,240,240)
#
#		new_button.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
#
#		if button.get_child_count() >= 3:
#			new_button.add_child(button.get_child(2).duplicate()) # Wave Texture rect
#
#		control.add_child(new_button)
#
	return true


func _drop_data(_pos: Vector2, data: Variant) -> void:
	var draggable: Draggable = data

	drag_previews = []

	if draggable.files: # Creating new clips
		var track_id: int = get_track_from_mouse_pos()
		var frame_nr: int = get_frame_from_mouse_pos() - _drag_offset
		var new_clips: Array[CreateClipRequest] = []

		for file_id: int in draggable.ids:
			new_clips.append(CreateClipRequest.new(file_id, track_id, frame_nr))
			frame_nr += FileHandler.get_file(file_id).duration

		ClipHandler.add_clips(new_clips)
	else:
		var clips: Array[MoveClipRequest] = []

		for clip_id: int in draggable.ids:
			clips.append(MoveClipRequest.new(clip_id, _drag_offset, _drag_offset_track))

		ClipHandler.move_clips(clips)

	queue_redraw()


func _force_refresh(_v: Variant) -> void:
	queue_redraw() # Function is needed to avoid errors `queue_redraw()`.




#var playhead_moving: bool = false
#var selected_clips: Array[int] = [] # An array of all selected clip id's
#
#var track_overlays: Array[ColorRect] = [] # Indicator if a track is (in)visible
#
#var playback_before_moving: bool = false
#var zoom: float = 1.0 : set = _set_zoom # How many pixels 1 frame takes
#
#var _offset: int = 0 # Offset for moving/placing clips
#var _syncing_scroll: bool = false
#
#
#
#func _ready() -> void:
#	instance = self
#	main_control.set_drag_forwarding(Callable(), _main_control_can_drop_data, _main_control_drop_data)
#
#	EditorCore.frame_changed.connect(move_playhead)
#	mouse_exited.connect(func() -> void: preview.visible = false)
#	FileHandler.file_deleted.connect(_check_clips)
#	scroll_main.get_h_scroll_bar().connect(alue_changed, _on_h_scroll.bind(true))
#	scroll_bar.get_h_scroll_bar().connect(alue_changed, _on_h_scroll.bind(false))
#
#
#func _process(_delta: float) -> void:
#	if playhead_moving:
#		var new_frame: int = clampi(
#				floori(main_control.get_local_mouse_position().x / zoom),
#				0, Project.get_timeline_end())
#
#		if new_frame != EditorCore.frame_nr:
#			EditorCore.set_frame(new_frame)
#			new_frame = -1
#
#	
#func _input(event: InputEvent) -> void:
#	if !Project.is_loaded():
#		return
#
#	if !EditorCore.is_playing:
#		if event.is_action_pressed("ui_left"):
#			EditorCore.set_frame(EditorCore.frame_nr - 1)
#		elif event.is_action_pressed("ui_right"):
#			EditorCore.set_frame(EditorCore.frame_nr + 1)
#
#	if event.is_action_pressed("clip_split"):
#		_clips_split(EditorCore.frame_nr)
#		get_viewport().set_input_as_handled()
#
#	if event is InputEventMouseButton and (event as InputEventMouseButton).is_released():
#		if preview.visible:
#			preview.visible = false
#		
#	if !main_control.get_global_rect().has_point(get_global_mouse_position()):
#		return
#	if event is InputEventMouseButton and (event as InputEventMouseButton).double_click:
#		var mod: int = Settings.get_delete_empty_modifier()
#
#		if mod == KEY_NONE or Input.is_key_pressed(mod):
#			_delete_empty_space()
#			get_viewport().set_input_as_handled()
#
#
#func _on_timeline_scroll_gui_input(event: InputEvent) -> void:
#	if Project.is_loaded() == null:
#		return
#
#	if event.is_action_pressed("timeline_zoom_in", false, true):
#		zoom *= 1.15
#		get_viewport().set_input_as_handled()
#	elif event.is_action_pressed("timeline_zoom_out", false, true):
#		zoom /= 1.15
#		get_viewport().set_input_as_handled()
#	
#	if event.is_action("scroll_up", true):
#		scroll_main.scroll_vertical -= int(scroll_main.scroll_vertical_custom_step * zoom)
#		get_viewport().set_input_as_handled()
#	elif event.is_action("scroll_down", true):
#		scroll_main.scroll_vertical += int(scroll_main.scroll_vertical_custom_step * zoom)
#		get_viewport().set_input_as_handled()
#	elif event.is_action("scroll_left", true):
#		scroll_main.scroll_horizontal -= int(scroll_main.scroll_horizontal_custom_step * zoom)
#		get_viewport().set_input_as_handled()
#	elif event.is_action("scroll_right", true):
#		scroll_main.scroll_horizontal += int(scroll_main.scroll_horizontal_custom_step * zoom)
#		get_viewport().set_input_as_handled()
#			
#
#func _on_main_gui_input(event: InputEvent) -> void:
#	if event is not InputEventMouseButton:
#		return
#
#	if (event as InputEventMouseButton).button_index == MOUSE_BUTTON_LEFT:
#		if event.is_pressed() and !Input.is_key_pressed(KEY_SHIFT) and !Input.is_key_pressed(KEY_CTRL):
#			if Settings.get_pause_after_drag() and EditorCore.is_playing:
#				EditorCore.on_play_pressed()
#
#			playhead_moving = true
#			playback_before_moving = EditorCore.is_playing
#
#			if playback_before_moving:
#				EditorCore.on_play_pressed()
#		elif event.is_released():
#			playhead_moving = false
#
#			if playback_before_moving:
#				EditorCore.on_play_pressed()
#
#
#func _set_zoom(new_zoom: float) -> void:
#	if zoom == new_zoom:
#		return
#
#	# We need to await to get the correct get_local_mouse_position
#	await RenderingServer.frame_post_draw
#
#	var prev_mouse_x: float = main_control.get_local_mouse_position().x
#	var prev_scroll: int = scroll_main.scroll_horizontal
#	var prev_mouse_frame: int = get_frame_id(prev_mouse_x)
#
#	zoom = clampf(new_zoom, 0.001, 40.0)
#
#	# TODO: Make this better
#	if zoom > 30:
#		scroll_main.scroll_horizontal_custom_step = 1
#	elif zoom > 20:
#		scroll_main.scroll_horizontal_custom_step = 2
#	elif zoom > 10:
#		scroll_main.scroll_horizontal_custom_step = 4
#	elif zoom > 5:
#		scroll_main.scroll_horizontal_custom_step = 8
#	elif zoom > 1:
#		scroll_main.scroll_horizontal_custom_step = 18
#	elif zoom > 0.4:
#		scroll_main.scroll_horizontal_custom_step = 40
#	else:
#		scroll_main.scroll_horizontal_custom_step = 100
#
#	move_playhead(EditorCore.frame_nr)
#
#	# Get all clips, update their size and position
#	for clip_button: Button in clips.get_children():
#		var data: ClipData = Project.get_clip(clip_button.name.to_int())
#
#		clip_button.position.x = get_frame_pos(data.start_frame)
#		clip_button.size.x = get_clip_size(data.duration)
#
#	var new_mouse_x: float = prev_mouse_frame * zoom
#	scroll_main.scroll_horizontal = int(new_mouse_x - (prev_mouse_x - prev_scroll))
#
#	main_control.custom_minimum_size.x = (Project.get_timeline_end() * zoom) + TIMELINE_PADDING
#	lines.custom_minimum_size.x = (Project.get_timeline_end() * zoom) + TIMELINE_PADDING
#
#	Project.set_timeline_scroll_h(scroll_main.scroll_horizontal)
#	Project.set_zoom(zoom)
#
#	propagate_call("_on_timeline_zoom_changed")
#
#
#func _on_project_ready() -> void:
#	for child: Node in clips.get_children():
#		child.queue_free()
#
#	for clip: ClipData in Project.get_clip_datas():
#		add_clip(clip)
#		if clip.effects_video != null and clip.effects_video.clip_id == -1:
#			clip.effects_video.clip_id = clip.clip_id
#		if clip.effects_audio != null and clip.effects_audio.clip_id == -1:
#			clip.effects_audio.clip_id = clip.clip_id
#
#	main_control.custom_minimum_size.y = (TRACK_HEIGHT + LINE_HEIGHT) * Project.get_track_count()
#
#	for i: int in Project.get_track_count() - 1:
#		var overlay: ColorRect = ColorRect.new()
#		var line: HSeparator = HSeparator.new()
#
#		overlay.mouse_filter = Control.MOUSE_FILTER_IGNORE
#		overlay.color = Color.DARK_GRAY
#		overlay.self_modulate = Color("ffffff00")
#		overlay.custom_minimum_size.y = TRACK_HEIGHT
#		track_overlays.append(overlay)
#
#		line.mouse_filter = Control.MOUSE_FILTER_IGNORE
#		line.add_theme_stylebox_override("separator", load(Library.STYLE_LINE_TRACK) as StyleBoxLine)
#		line.size.y = LINE_HEIGHT
#
#		lines.add_child(overlay)
#		lines.add_child(line)
#
#	Project.update_timeline_end()
#	_set_zoom(Project.get_zoom())
#
#	scroll_main.scroll_horizontal = Project.get_timeline_scroll_h()
#
#
#func _check_clips(_id: int = -1) -> void:
#	# Get's called after deleting of a file.
#	var ids: PackedInt64Array = Project.get_clip_ids()
#
#	# Check for buttons which need to be deleted.
#	for clip_button: Button in clips.get_children():
#		var clip_id: int = int(clip_button.name)
#
#		if clip_id not in ids:
#			clip_button.queue_free()
#		else:
#			ids.remove_at(ids.find(clip_id))
#			
#	# Check for buttons which need to be added.
#	for clip_id: int in ids:
#		add_clip(Project.get_clip(clip_id))
#
#
#
#
#func _main_control_drop_data(_pos: Vector2, data: Variant) -> void:
#
#
#func _move_clips(draggable: Draggable, track_diff: int, frame_diff: int) -> void:
#	# Go over each clip to update its data
#	for i: int in draggable.ids.size():
#		var data: ClipData = Project.get_clip(draggable.ids[i])
#		var track: int = data.track_id + track_diff
#		var frame: int = data.start_frame + frame_diff
#
#		Project.erase_track_entry(data.track_id, data.start_frame)
#
#		# Change clip data
#		data.track_id = track
#		data.start_frame = frame
#		Project.set_track_data(track, frame, draggable.ids[i])
#
#		# Change clip button position
#		draggable.clip_buttons[i].position = Vector2(
#				get_frame_pos(frame), get_track_pos(track))
#
#
#func _add_new_clips(draggable: Draggable) -> void:
#	for clip_data: ClipData in draggable.new_clips:
#		Project.set_clip(clip_data.clip_id, clip_data)
#		Project.set_track_data(clip_data.track_id, clip_data.start_frame, clip_data.clip_id)
#
#		add_clip(clip_data)
#
#
#func _remove_new_clips(draggable: Draggable) -> void:
#	for clip_data: ClipData in draggable.new_clips:
#		var id: int = clip_data.clip_id
#		Project.erase_clip(id)
#		remove_clip(id)
#
#
#func _on_h_scroll(value: float, main: bool = true) -> void:
#	if !_syncing_scroll:
#		_syncing_scroll = true
#
#		if main:
#			scroll_bar.scroll_horizontal = int(value)
#		else:
#			scroll_main.scroll_horizontal = int(value)
#
#		_syncing_scroll = false
#
#
#func add_clip(clip_data: ClipData) -> void:
#	var button: Button = Button.new()
#
#	button.clip_text = true
#	button.name = str(clip_data.clip_id)
#	button.text = " " + FileHandler.get_file(clip_data.file_id).nickname
#	button.size.x = get_clip_size(clip_data.duration)
#	button.size.y = TRACK_HEIGHT
#	button.alignment = HORIZONTAL_ALIGNMENT_LEFT
#	button.position.x = zoom * clip_data.start_frame
#	button.position.y = clip_data.track_id * (LINE_HEIGHT + TRACK_HEIGHT)
#	button.mouse_filter = Control.MOUSE_FILTER_PASS
#	button.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
#
#	@warning_ignore_start("unsafe_call_argument")
#	button.add_theme_stylebox_override("normal", STYLE_BOXES[FileHandler.get_file(clip_data.file_id).type][0])
#	button.add_theme_stylebox_override("focus", STYLE_BOXES[FileHandler.get_file(clip_data.file_id).type][1])
#	button.add_theme_stylebox_override("hover", STYLE_BOXES[FileHandler.get_file(clip_data.file_id).type][0])
#	button.add_theme_stylebox_override("pressed", STYLE_BOXES[FileHandler.get_file(clip_data.file_id).type][0])
#	@warning_ignore_restore("unsafe_call_argument")
#
#	button.set_script(preload(Library.BUTTON_CLIP))
#	clips.add_child(button)
#
#
#func remove_clip(clip_id: int) -> void:
#	clips.get_node(str(clip_id)).queue_free()
#
#
#func get_drop_region(track: int, frame: int, ignores: Array[Vector2i]) -> Vector2i:
#	# X = lowest, Y = highest
#	var region: Vector2i = Vector2i(-1, -1)
#	var keys: PackedInt64Array = Project.get_track_keys(track)
#
#	for track_frame: int in keys:
#		if track_frame < frame and Vector2i(track, track_frame) not in ignores:
#			region.x = track_frame
#		elif track_frame > frame and Vector2i(track, track_frame) not in ignores:
#			region.y = track_frame
#			break
#
#	# Getting the correct end frame
#	if region.x != -1:
#		region.x = Project.get_clip(Project.get_track_data(track)[region.x]).end_frame + 1
#
#	return region
#
#
#func get_lowest_frame(track_id: int, frame_nr: int, ignore: Array[Vector2i] = []) -> int:
#	var lowest: int = -1
#
#	if track_id > Project.get_track_count() - 1:
#		return -1
#
#	for i: int in Project.get_track_keys(track_id):
#		if i < frame_nr:
#			if ignore.size() >= 1:
#				if i == ignore[0].y and track_id == ignore[0].x:
#					continue
#			lowest = i
#		elif i >= frame_nr:
#			break
#
#	if lowest == -1:
#		return -1
#
#	var clip: ClipData = Project.get_clip(Project.get_track_data(track_id)[lowest])
#	return clip.duration + lowest
#
#
#func get_highest_frame(track_id: int, frame_nr: int, ignore: Array[Vector2i] = []) -> int:
#	for i: int in Project.get_track_keys(track_id):
#		# TODO: Change the ignore when moving multiple clips
#		if i > frame_nr:
#			if ignore.size() >= 1:
#				if i == ignore[0].y and track_id == ignore[0].x:
#					continue
#			return i
#
#	return -1
#
#
#func _on_timeline_end_update(new_end: int) -> void:
#	main_control.custom_minimum_size.x = (new_end * zoom) + TIMELINE_PADDING
#	lines.custom_minimum_size.x = (new_end * zoom) + TIMELINE_PADDING
#	propagate_call("_on_timeline_update")
#
#
#func delete_clip(clip_data: ClipData) -> void:
#	var id: int = Project.get_track_data(clip_data.track_id)[clip_data.start_frame]
#
#	Project.erase_clip(id)
#	remove_clip(id)
#	Project.update_timeline_end()
#
#
#func undelete_clip(clip_data: ClipData) -> void:
#	Project.set_clip(clip_data.clip_id, clip_data)
#	Project.set_track_data(clip_data.track_id, clip_data.start_frame, clip_data.clip_id)
#
#	add_clip(clip_data)
#	Project.update_timeline_end()
#
#
#func move_playhead(frame_nr: int) -> void:
#	playhead.position.x = zoom * frame_nr
#
#
#static func get_clip_size(duration: int) -> float:
#	return instance.zoom * duration
#
#
#func _delete_empty_space() -> void:
#	var mouse_track: int = get_track_id(main_control.get_local_mouse_position().y)
#	var mouse_frame: int = get_frame_id(main_control.get_local_mouse_position().x)
#	var lowest_frame: int = get_lowest_frame(mouse_track, mouse_frame)
#	var highest_frame: int = get_highest_frame(mouse_track,mouse_frame)
#
#	if highest_frame < 0:
#		return # Nothing to erase
#
#	var draggable: Draggable = Draggable.new()
#	draggable.differences = Vector2i(highest_frame - lowest_frame, 0)
#
#	var track_data: Dictionary[int, int] = Project.get_track_data(mouse_track)
#	for frame_nr: int in track_data.keys():
#		if frame_nr < highest_frame:
#			continue
#
#		draggable.clip_buttons.append(clips.get_node(str(track_data[frame_nr])))
#		if draggable.ids.append(track_data[frame_nr]):
#			Print.append_error()
#			continue
#
#	InputManager.undo_redo.create_action("Delete empty space")
#
#	InputManager.undo_redo.add_do_method(_move_clips.bind(
#			draggable,
#			draggable.differences.y,
#			-draggable.differences.x))
#	InputManager.undo_redo.add_do_method(EditorCore.update_frame)
#
#	InputManager.undo_redo.add_undo_method(_move_clips.bind(
#			draggable,
#			draggable.differences.y,
#			draggable.differences.x))
#	InputManager.undo_redo.add_undo_method(EditorCore.update_frame)
#
#	InputManager.undo_redo.commit_action()
#
#
#func _clips_split(frame_nr: int) -> void:
#	# TODO: We need to do a couple of things:
#	# - Check which clips, if any, from the selected clips are in the cut zone;
#	# - If none in the cut zone, cut all found clips;
#	# - If one or more of selected clips in cut zone, cut only those.
#
#	# I probably need to redo this entire function, with a variable for 
#	#	possible clips, and check those possible clips if there's any inside of selected clips
#	#	than do the cutting.
#
#	var clips_at_playhead: Array[ClipData] = []
#	
#	for track_id: int in Project.get_track_count():
#		var last_start_frame: int = -1
#		var clip_data: ClipData = null
#
#		# Get the last clip before the frame_nr.
#		for start_frame: int in Project.get_track_keys(track_id):
#			if start_frame <= frame_nr:
#				last_start_frame = start_frame
#			else: break
#
#		if last_start_frame == -1:
#			continue
#
#		var clip_id: int = Project.get_track_data(track_id)[last_start_frame]
#		clip_data = Project.get_clip(clip_id)
#
#		# Check if frame_nr is within the clip length.
#		if frame_nr <= clip_data.get_end_frame():
#			clips_at_playhead.append(clip_data)
#
#
#	# After getting the clips at the playhead, we need to check if any of the
#	# clips are inside of the selected_clips.
#	var in_selected_clips: bool = false
#	for clip_data: ClipData in clips_at_playhead:
#		if clip_data.clip_id in selected_clips:
#			in_selected_clips = true
#			break
#
#	# If selected clips have been found, we only cut those clips, so we remove
#	# the other clips.
#	var clips_to_cut: Array[ClipData] = []
#	if in_selected_clips:
#		for clip_data: ClipData in clips_at_playhead:
#			if selected_clips.has(clip_data.clip_id):
#				clips_to_cut.append(clip_data)
#	else:
#		clips_to_cut = clips_at_playhead
#
#	
#	InputManager.undo_redo.create_action("Deleting clip on timeline")
#
#	for clip_data: ClipData in clips_to_cut:
#		InputManager.undo_redo.add_do_method(_cut_clip.bind(frame_nr, clip_data))
#	InputManager.undo_redo.add_do_method(queue_redraw)
#
#	for clip_data: ClipData in clips_to_cut:
#		InputManager.undo_redo.add_undo_method(_uncut_clip.bind(frame_nr, clip_data))
#	InputManager.undo_redo.add_undo_method(queue_redraw)
#
#	InputManager.undo_redo.commit_action()
#
#
#func _cut_clip(frame_nr: int, current_clip_data: ClipData) -> void:
#	var new_clip: ClipData = ClipData.new()
#	var frame: int = frame_nr - current_clip_data.start_frame
#
#	new_clip.clip_id = Utils.get_unique_id(Project.get_clip_ids())
#	new_clip.file_id = current_clip_data.file_id
#
#	new_clip.start_frame = frame_nr
#	new_clip.duration = abs(current_clip_data.duration - frame)
#	new_clip.begin = current_clip_data.begin + frame
#	new_clip.track_id = current_clip_data.track_id
#	new_clip.effects_video = current_clip_data.effects_video.duplicate()
#	new_clip.effects_audio = current_clip_data.effects_audio.duplicate()
#
#	current_clip_data.duration -= new_clip.duration
#	_update_clip_size(current_clip_data.clip_id, get_clip_size(current_clip_data.duration))
#
#	Project.set_clip(new_clip.clip_id, new_clip)
#	Project.set_track_data(new_clip.track_id, new_clip.start_frame, new_clip.clip_id)
#
#	add_clip(new_clip)
#
#
#func _uncut_clip(frame_nr: int, current_clip: ClipData) -> void:
#	var clip_button: Control = clips.get_node(str(current_clip.clip_id))
#	var track: int = get_track_id(clip_button.position.y)
#	var split_clip: ClipData = Project.get_clip(Project.get_track_data(track)[frame_nr])
#
#	current_clip.duration += split_clip.duration
#	_update_clip_size(current_clip.clip_id, Timeline.get_frame_pos(current_clip.duration))
#
#	delete_clip(split_clip)


func get_track_from_mouse_pos() -> int:
	return min(floor(get_local_mouse_position().y / (TRACK_HEIGHT + TRACK_LINE_HEIGHT)), TrackHandler.get_tracks_size() - 1)


func get_frame_from_mouse_pos() -> int:
	return floori(get_local_mouse_position().x / zoom)


func update_track_count() -> void:
	var track_count: int = TrackHandler.get_tracks_size()

	track_line_heights.clear()
	custom_minimum_size.x = track_count * TOTAL_TRACK_HEIGHT

	for i: int in track_count:
		track_line_heights.append((i+1) * TOTAL_TRACK_HEIGHT)
	
	_timeline_end_update(Project.get_timeline_end())
	queue_redraw()

