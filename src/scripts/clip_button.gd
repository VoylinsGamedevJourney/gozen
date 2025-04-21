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
		var mouse_x: float = parent.get_local_mouse_position().x
		var zoom: float = Timeline.get_zoom()
		var potential_frame: int = floori(mouse_x / zoom)

		if is_resizing_left:
			potential_frame = clamp(potential_frame, max_left_resize, max_right_resize)
			_visual_start_frame = potential_frame
			_visual_duration = _original_start_frame + _original_duration - _visual_start_frame
		else:
			potential_frame = clamp(potential_frame, max_left_resize, max_right_resize)
			_visual_start_frame = _original_start_frame
			_visual_duration = potential_frame - _visual_start_frame

		position.x = Timeline.get_frame_pos(_visual_start_frame)
		size.x = Timeline.get_frame_pos(_visual_duration)

		queue_redraw()


func _draw() -> void:
	if not wave:
		return

	var full_wave_data: PackedFloat32Array = Project.get_file_data(clip_data.file_id).audio_wave_data

	if full_wave_data.is_empty():
		return

	var display_duration: int
	var display_begin_offset: int

	if is_resizing_left or is_resizing_right:
		display_duration = _visual_duration
		display_begin_offset = _original_begin + (_visual_start_frame - _original_start_frame)
	else:
		display_duration = clip_data.duration
		display_begin_offset = clip_data.begin

	if display_duration <= 0 or size.x <= 0:
		return

	var block_width: float = size.x / float(display_duration)
	var panel_height: float = size.y

	for i: int in display_duration:
		var wave_data_index: int = display_begin_offset + i

		if wave_data_index >= 0 and wave_data_index < full_wave_data.size():
			var normalized_height: float = full_wave_data[wave_data_index]
			var block_height: float = normalized_height * panel_height

			var block_rect: Rect2 = Rect2(
					i * block_width, (panel_height - block_height) / 2.0,
					block_width, block_height)

			draw_rect(block_rect, Color.LIGHT_GRAY)


func _on_button_down() -> void:
	if is_resizing_left or is_resizing_right:
		return

	is_dragging = true
	get_viewport().set_input_as_handled()	


func _input(event: InputEvent) -> void:
	# TODO: Make it so only selected clips can be cut
	# Timeline.selected_clips
	if event.is_action_pressed("clip_split"):
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


func _on_gui_input(event: InputEvent) -> void:
	# We need mouse passthrough to allow for clip dragging without issues
	# But when clicking on clips we do not want the playhead to keep jumping.
	# Maybe later on we can allow for clip clicking and playhead moving by
	# holding alt or something.
	if event is InputEventMouseButton:
		var mouse_event: InputEventMouseButton = event

		if mouse_event.pressed:
			EffectsPanel.instance.on_clip_pressed(name.to_int())
			get_viewport().set_input_as_handled()

		if mouse_event.button_index in [MOUSE_BUTTON_WHEEL_UP, MOUSE_BUTTON_WHEEL_DOWN]:
			return
#		if !(l_event as InputEventWithModifiers).alt_pressed and l_event.is_pressed():
#			EffectsPanel.instance.open_clip_effects(name.to_int())
#			get_viewport().set_input_as_handled()

	if event.is_action_pressed("delete_clip"):
		InputManager.undo_redo.create_action("Deleting clip on timeline")

		InputManager.undo_redo.add_do_method(Timeline.instance.delete_clip.bind(clip_data))
		InputManager.undo_redo.add_undo_method(Timeline.instance.undelete_clip.bind(clip_data))

		InputManager.undo_redo.add_do_method(Editor.set_frame.bind(Editor.frame_nr))
		InputManager.undo_redo.add_undo_method(Editor.set_frame.bind(Editor.frame_nr))
		InputManager.undo_redo.commit_action()


func _get_drag_data(_pos: Vector2) -> Draggable:
	if is_resizing_left or is_resizing_right:
		return null

	var draggable: Draggable = Draggable.new()

	# Add clip id to array
	if draggable.ids.append(name.to_int()):
		printerr("Something went wrong appending to draggable ids!")

	draggable.files = false
	draggable.duration = clip_data.duration
	draggable.offset = int(get_local_mouse_position().x / Timeline.get_zoom())

	draggable.ignores.append(Vector2i(clip_data.track_id, clip_data.start_frame))
	draggable.clip_buttons.append(self)

	modulate = Color(1, 1, 1, 0.1)
	return draggable


func _notification(notification_type: int) -> void:
	match notification_type:
		NOTIFICATION_DRAG_END:
			is_dragging = false
			modulate = Color(1, 1, 1, 1)


func _add_resize_button(preset: LayoutPreset, left: bool) -> void:
	var button: Button = Button.new()
	add_child(button)

	button.add_theme_stylebox_override("normal", StyleBoxEmpty.new())
	button.add_theme_stylebox_override("pressed", StyleBoxEmpty.new())
	button.add_theme_stylebox_override("hover", StyleBoxEmpty.new())
	button.add_theme_stylebox_override("focus", StyleBoxEmpty.new())
	button.mouse_default_cursor_shape = Control.CURSOR_HSIZE
	button.set_anchors_and_offsets_preset(preset)
	button.custom_minimum_size.x = 3
	if !left:
		button.position.x -= 3
	button.mouse_filter = Control.MOUSE_FILTER_PASS

	button.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND

	if button.button_down.connect(_on_resize_engaged.bind(left)):
		printerr("Couldn't connect button_down to _on_resize_engaged!")
	if button.button_up.connect(_on_commit_resize):
		printerr("Couldn't connect button_down to _on_resize_engaged!")


func _on_resize_engaged(left: bool) -> void:
	var previous: int = -1

	_original_start_frame = clip_data.start_frame
	_original_duration = clip_data.duration
	_original_begin = clip_data.begin

	_visual_start_frame = _original_start_frame
	_visual_duration = _original_duration

	max_left_resize = 0
	max_right_resize = -1

	# First calculate spacing left of handle to other clips
	if left:
		for i: int in Project.get_track_keys(clip_data.track_id):
			if i >= clip_data.start_frame:
				break
			previous = max(0, i - 1)

		if previous != -1:
			max_left_resize = clip_data.duration + previous
		max_right_resize = clip_data.end_frame
	else:
		for i: int in Project.get_track_keys(clip_data.track_id):
			if i > clip_data.start_frame:
				previous = i
				break

		max_left_resize = clip_data.start_frame + 1
		max_right_resize = maxi(previous, -1)

	# Check if audio/video how much space is left to extend, take minimum
	if Project.get_clip_type(name.to_int()) in [File.TYPE.VIDEO, File.TYPE.AUDIO]:
		if left:
			max_left_resize = max(max_left_resize, clip_data.start_frame - clip_data.begin)
		else:
			var duration_left: int = Project.get_file(clip_data.file_id).duration

			duration_left -= clip_data.begin
			duration_left += clip_data.start_frame

			if max_right_resize == -1:
				max_right_resize = duration_left
			else:
				max_right_resize = min(max_right_resize, duration_left)
				
	is_resizing_left = left
	is_resizing_right = !left
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


func _set_resize_data(new_start: int, new_duration: int) -> void:
	if clip_data.start_frame != new_start:
		clip_data.begin += new_start - clip_data.start_frame

	position.x = new_start * Timeline.get_zoom()
	size.x = new_duration * Timeline.get_zoom()

	Project.erase_track_entry(clip_data.track_id, clip_data.start_frame)
	Project.set_track_data(clip_data.track_id, new_start, name.to_int())

	clip_data.start_frame = new_start
	clip_data.duration = new_duration

	Timeline.instance.update_end()


func _cut_clip(playhead: int, current_clip_data: ClipData) -> void:
	var new_clip: ClipData = ClipData.new()
	var frame: int = playhead - current_clip_data.start_frame

	new_clip.clip_id = Toolbox.get_unique_id(Project.get_clip_ids())
	new_clip.file_id = current_clip_data.file_id

	new_clip.start_frame = playhead
	new_clip.duration = abs(current_clip_data.duration - frame)
	new_clip.begin = current_clip_data.begin + frame
	new_clip.track_id = current_clip_data.track_id
	new_clip.effects_video = clip_data.effects_video.duplicate()
	new_clip.effects_audio = clip_data.effects_audio.duplicate()

	current_clip_data.duration -= new_clip.duration + 1
	size.x = current_clip_data.duration * Timeline.get_zoom()

	Project.set_clip(new_clip.clip_id, new_clip)
	Project.set_track_data(new_clip.track_id, new_clip.start_frame, new_clip.clip_id)

	Timeline.instance.add_clip(new_clip)


func _uncut_clip(playhead: int, current_clip: ClipData) -> void:
	var track: int = Timeline.get_track_id(position.y)
	var split_clip: ClipData = Project.get_clip(Project.get_track_data(track)[playhead])

	current_clip.duration += split_clip.duration
	size.x = Timeline.get_frame_pos(current_clip.duration)

	Timeline.instance.delete_clip(split_clip)

