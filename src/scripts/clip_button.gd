extends Button

@onready var parent: Control = get_parent()


var clip_data: ClipData

var is_dragging: bool = false
var is_resizing_left: bool = false
var is_resizing_right: bool = false

var max_left_resize: int = 0 # Minimum frame
var max_right_resize: int = 0 # Maximum frame
var _original_start_frame: int = 0
var _original_duration: int = 0
var _original_begin: int = 0

var _visual_start_frame: int = 0
var _visual_duration: int = 0

var wave: bool = false



func _ready() -> void:
	clip_data = Project.get_clip(name.to_int())

	_original_start_frame = clip_data.start_frame
	_original_duration = clip_data.duration
	_original_begin = clip_data.begin

	_visual_start_frame = _original_start_frame
	_visual_duration = _original_duration

	_add_resize_button(PRESET_LEFT_WIDE, true)
	_add_resize_button(PRESET_RIGHT_WIDE, false)

	Toolbox.connect_func(button_down, _on_button_down)
	Toolbox.connect_func(gui_input, _on_gui_input)
	Toolbox.connect_func(Timeline.instance.zoom_changed, queue_redraw)

	if Project.get_file(clip_data.file_id).type in Editor.AUDIO_TYPES:
		wave = true
		Toolbox.connect_func(Project.get_file_data(clip_data.file_id).update_wave, queue_redraw)


func _process(_delta: float) -> void:
	if is_resizing_left or is_resizing_right:
		var l_mouse_x: float = parent.get_local_mouse_position().x
		var l_zoom: float = Timeline.get_zoom()
		var l_potential_frame: int = floori(l_mouse_x / l_zoom)

		if is_resizing_left:
			l_potential_frame = clamp(l_potential_frame, max_left_resize, max_right_resize)
			_visual_start_frame = l_potential_frame
			_visual_duration = _original_start_frame + _original_duration - _visual_start_frame
		else:
			l_potential_frame = clamp(l_potential_frame, max_left_resize, max_right_resize)
			_visual_start_frame = _original_start_frame
			_visual_duration = l_potential_frame - _visual_start_frame

		position.x = Timeline.get_frame_pos(_visual_start_frame)
		size.x = Timeline.get_frame_pos(_visual_duration)

		queue_redraw()


func _draw() -> void:
	if not wave:
		return

	var l_full_wave_data: PackedFloat32Array = Project.get_file_data(clip_data.file_id).audio_wave_data

	if l_full_wave_data.is_empty():
		return

	var l_display_duration: int
	var l_display_begin_offset: int

	if is_resizing_left or is_resizing_right:
		l_display_duration = _visual_duration
		l_display_begin_offset = _original_begin + (_visual_start_frame - _original_start_frame)
	else:
		l_display_duration = clip_data.duration
		l_display_begin_offset = clip_data.begin

	if l_display_duration <= 0 or size.x <= 0:
		return

	var l_block_width: float = size.x / float(l_display_duration)
	var l_panel_height: float = size.y

	for i: int in l_display_duration:
		var wave_data_index: int = l_display_begin_offset + i

		if wave_data_index >= 0 and wave_data_index < l_full_wave_data.size():
			var l_normalized_height: float = l_full_wave_data[wave_data_index]
			var l_block_height: float = l_normalized_height * l_panel_height

			var l_block_rect: Rect2 = Rect2(
					i * l_block_width, (l_panel_height - l_block_height) / 2.0,
					l_block_width, l_block_height)

			draw_rect(l_block_rect, Color.LIGHT_GRAY)


func _on_button_down() -> void:
	if is_resizing_left or is_resizing_right:
		return

	is_dragging = true
	get_viewport().set_input_as_handled()	


func _input(a_event: InputEvent) -> void:
	# TODO: Make it so only selected clips can be cut
	# Timeline.selected_clips
	if a_event.is_action_pressed("clip_split"):
		# Check if playhead is inside of clip, else we skip creating undo and
		# redo entries.
		if Editor.frame_nr <= clip_data.start_frame or Editor.frame_nr >= clip_data.end_frame:
			return # Playhead is left/right of the clip

		InputManager.undo_redo.create_action("Deleting clip on timeline")

		InputManager.undo_redo.add_do_method(_cut_clip.bind(Editor.frame_nr, clip_data))
		InputManager.undo_redo.add_do_method(queue_redraw)

		InputManager.undo_redo.add_undo_method(_uncut_clip.bind(Editor.frame_nr, clip_data))
		InputManager.undo_redo.add_undo_method(queue_redraw)

		InputManager.undo_redo.commit_action()


func _on_gui_input(a_event: InputEvent) -> void:
	# We need mouse passthrough to allow for clip dragging without issues
	# But when clicking on clips we do not want the playhead to keep jumping.
	# Maybe later on we can allow for clip clicking and playhead moving by
	# holding alt or something.
	if a_event is InputEventMouseButton:
		var l_event: InputEventMouseButton = a_event

		if l_event.pressed:
			get_viewport().set_input_as_handled()

		if l_event.button_index in [MOUSE_BUTTON_WHEEL_UP, MOUSE_BUTTON_WHEEL_DOWN]:
			return
#		if !(l_event as InputEventWithModifiers).alt_pressed and l_event.is_pressed():
#			EffectsPanel.instance.open_clip_effects(name.to_int())
#			get_viewport().set_input_as_handled()

	if a_event.is_action_pressed("delete_clip"):
		InputManager.undo_redo.create_action("Deleting clip on timeline")

		InputManager.undo_redo.add_do_method(Timeline.instance.delete_clip.bind(clip_data))
		InputManager.undo_redo.add_undo_method(Timeline.instance.undelete_clip.bind(clip_data))

		InputManager.undo_redo.add_do_method(Editor.set_frame.bind(Editor.frame_nr))
		InputManager.undo_redo.add_undo_method(Editor.set_frame.bind(Editor.frame_nr))
		InputManager.undo_redo.commit_action()


func _get_drag_data(_pos: Vector2) -> Draggable:
	if is_resizing_left or is_resizing_right:
		return null

	var l_draggable: Draggable = Draggable.new()

	# Add clip id to array
	if l_draggable.ids.append(name.to_int()):
		printerr("Something went wrong appending to draggable ids!")

	l_draggable.files = false
	l_draggable.duration = clip_data.duration
	l_draggable.offset = int(get_local_mouse_position().x / Timeline.get_zoom())

	l_draggable.ignores.append(Vector2i(clip_data.track_id, clip_data.start_frame))
	l_draggable.clip_buttons.append(self)

	modulate = Color(1, 1, 1, 0.1)
	return l_draggable


func _notification(a_notification_type: int) -> void:
	match a_notification_type:
		NOTIFICATION_DRAG_END:
			is_dragging = false
			modulate = Color(1, 1, 1, 1)


func _add_resize_button(a_preset: LayoutPreset, a_left: bool) -> void:
	var l_button: Button = Button.new()
	add_child(l_button)

	l_button.add_theme_stylebox_override("normal", StyleBoxEmpty.new())
	l_button.add_theme_stylebox_override("pressed", StyleBoxEmpty.new())
	l_button.add_theme_stylebox_override("hover", StyleBoxEmpty.new())
	l_button.add_theme_stylebox_override("focus", StyleBoxEmpty.new())
	l_button.mouse_default_cursor_shape = Control.CURSOR_HSIZE
	l_button.set_anchors_and_offsets_preset(a_preset)
	l_button.custom_minimum_size.x = 3
	if !a_left:
		l_button.position.x -= 3
	l_button.mouse_filter = Control.MOUSE_FILTER_PASS

	if l_button.button_down.connect(_on_resize_engaged.bind(a_left)):
		printerr("Couldn't connect button_down to _on_resize_engaged!")
	if l_button.button_up.connect(_on_commit_resize):
		printerr("Couldn't connect button_down to _on_resize_engaged!")


func _on_resize_engaged(a_left: bool) -> void:
	var l_previous: int = -1

	_original_start_frame = clip_data.start_frame
	_original_duration = clip_data.duration
	_original_begin = clip_data.begin

	_visual_start_frame = _original_start_frame
	_visual_duration = _original_duration

	max_left_resize = 0
	max_right_resize = -1

	# First calculate spacing left of handle to other clips
	if a_left:
		for i: int in Project.get_track_keys(clip_data.track_id):
			if i >= clip_data.start_frame:
				break
			l_previous = max(0, i - 1)

		if l_previous != -1:
			max_left_resize = clip_data.duration + l_previous
		max_right_resize = clip_data.end_frame
	else:
		for i: int in Project.get_track_keys(clip_data.track_id):
			if i > clip_data.start_frame:
				l_previous = i
				break

		max_left_resize = clip_data.start_frame + 1
		max_right_resize = maxi(l_previous, -1)

	# Check if audio/video how much space is left to extend, take minimum
	if Project.get_clip_type(name.to_int()) in [File.TYPE.VIDEO, File.TYPE.AUDIO]:
		if a_left:
			max_left_resize = max(max_left_resize, clip_data.start_frame - clip_data.begin)
		else:
			var l_duration_left: int = Project.get_file(clip_data.file_id).duration

			l_duration_left -= clip_data.begin
			l_duration_left += clip_data.start_frame

			if max_right_resize == -1:
				max_right_resize = l_duration_left
			else:
				max_right_resize = min(max_right_resize, l_duration_left)
				
	is_resizing_left = a_left
	is_resizing_right = !a_left
	get_viewport().set_input_as_handled()


func _on_commit_resize() -> void:
	is_resizing_left = false
	is_resizing_right = false

	InputManager.undo_redo.create_action("Resizing clip on timeline")

	InputManager.undo_redo.add_do_method(_set_resize_data.bind(
			Timeline.get_frame_id(position.x), Timeline.get_frame_id(size.x)))
	InputManager.undo_redo.add_do_method(Editor.set_frame.bind(Editor.frame_nr))
	InputManager.undo_redo.add_do_method(queue_redraw)

	InputManager.undo_redo.add_undo_method(_set_resize_data.bind(clip_data.start_frame, clip_data.duration))
	InputManager.undo_redo.add_undo_method(Editor.set_frame.bind(Editor.frame_nr))
	InputManager.undo_redo.add_undo_method(queue_redraw)

	InputManager.undo_redo.commit_action()


func _set_resize_data(a_new_start: int, a_new_duration: int) -> void:
	if clip_data.start_frame != a_new_start:
		clip_data.begin += a_new_start - clip_data.start_frame

	position.x = a_new_start * Timeline.get_zoom()
	size.x = a_new_duration * Timeline.get_zoom()

	Project.erase_track_entry(clip_data.track_id, clip_data.start_frame)
	Project.set_track_data(clip_data.track_id, a_new_start, name.to_int())

	clip_data.start_frame = a_new_start
	clip_data.duration = a_new_duration

	Timeline.instance.update_end()


func _cut_clip(a_playhead: int, a_clip_data: ClipData) -> void:
	var l_new_clip: ClipData = ClipData.new()
	var l_frame: int = a_playhead - a_clip_data.start_frame

	l_new_clip.clip_id = Toolbox.get_unique_id(Project.get_clip_ids())
	l_new_clip.file_id = a_clip_data.file_id

	l_new_clip.start_frame = a_playhead
	l_new_clip.duration = abs(a_clip_data.duration - l_frame)
	l_new_clip.begin = a_clip_data.begin + l_frame
	l_new_clip.track_id = a_clip_data.track_id

	a_clip_data.duration -= l_new_clip.duration
	size.x = a_clip_data.duration * Timeline.get_zoom()

	Project.set_clip(l_new_clip.clip_id, l_new_clip)
	Project.set_track_data(l_new_clip.track_id, l_new_clip.start_frame, l_new_clip.clip_id)

	Timeline.instance.add_clip(l_new_clip)


func _uncut_clip(a_playhead: int, a_current_clip: ClipData) -> void:
	var l_track: int = Timeline.get_track_id(position.y)
	var l_split_clip: ClipData = Project.get_clip(Project.get_track_data(l_track)[a_playhead])

	a_current_clip.duration += l_split_clip.duration
	size.x = Timeline.get_frame_pos(a_current_clip.duration)

	Timeline.instance.delete_clip(l_split_clip)

