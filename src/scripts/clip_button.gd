extends Button


@onready var parent: Control = get_parent()

var is_dragging: bool = false
var is_resizing_left: bool = false
var is_resizing_right: bool = false

var max_left_resize: int = 0 # Minimum frame
var max_right_resize: int = 0 # Maximum frame
var start_frame: int = 0
var duration: int = 0


# TODO: Resize TODO's
# - Don't go over video/audio length;

# TODO: Cutting TODO's
# - Take in mind the start point of the audio/video



func _ready() -> void:
	_add_resize_button(PRESET_LEFT_WIDE, true)
	_add_resize_button(PRESET_RIGHT_WIDE, false)

	if button_down.connect(_on_button_down):
		printerr("Couldn't connect to button_down!")
	if gui_input.connect(_on_gui_input):
		printerr("Couldn't connect to gui_input!")


func _process(_delta: float) -> void:
	if is_resizing_left or is_resizing_right:
		var l_new_frame: int = clampi(
			TimelineClips.get_frame_nr(parent.get_local_mouse_position().x),
			max_left_resize,
			max_right_resize if max_right_resize != -1 else 900000000000)

		if is_resizing_right:
			size.x  = (l_new_frame - start_frame) * Project.timeline_scale
		elif is_resizing_left:
			position.x = l_new_frame * Project.timeline_scale
			size.x = (duration - (l_new_frame - start_frame)) * Project.timeline_scale


func _on_button_down() -> void:
	is_dragging = true
	get_viewport().set_input_as_handled()	


func _input(a_event: InputEvent) -> void:
	if button_pressed and a_event.is_action_pressed("clip_split"):
		Project.undo_redo.create_action("Deleting clip on timeline")

		Project.undo_redo.add_do_method(_cut_clip.bind(Playhead.frame_nr))
		Project.undo_redo.add_undo_method(_uncut_clip.bind(Playhead.frame_nr))

		Project.undo_redo.add_do_method(ViewPanel.instance._update_frame)
		Project.undo_redo.add_undo_method(ViewPanel.instance._update_frame)
		Project.undo_redo.commit_action()


func _on_gui_input(a_event: InputEvent) -> void:
	# We need mouse passthrough to allow for clip dragging without issues
	# But when clicking on clips we do not want the playhead to keep jumping.
	# Maybe later on we can allow for clip clicking and playhead moving by
	# holding alt or something.
	if a_event is InputEventMouse:
		if !(a_event as InputEventWithModifiers).alt_pressed and a_event.is_released():
			EffectsPanel.instance.open_clip_effects(name.to_int())
			get_viewport().set_input_as_handled()

	if a_event.is_action_pressed("delete_clip"):
		Project.undo_redo.create_action("Deleting clip on timeline")

		Project.undo_redo.add_do_method(TimelineClips.instance.delete_clip.bind(
				TimelineClips.get_track_id(position.y),
				TimelineClips.get_frame_nr(position.x)))

		Project.undo_redo.add_undo_method(TimelineClips.instance.undelete_clip.bind(
				Project.get_clip_data(
						TimelineClips.get_track_id(position.y),
						TimelineClips.get_frame_nr(position.x)),
				TimelineClips.get_track_id(position.y)))

		Project.undo_redo.add_do_method(ViewPanel.instance._update_frame)
		Project.undo_redo.add_undo_method(ViewPanel.instance._update_frame)
		Project.undo_redo.commit_action()


func _get_drag_data(_pos: Vector2) -> Draggable:
	if is_resizing_left or is_resizing_right:
		return null

	var l_draggable: Draggable = Draggable.new()
	var l_ignore: Vector2i = Vector2i(
			TimelineClips.get_track_id(position.y),
			TimelineClips.get_frame_nr(position.x))

	# Add clip id to array
	if l_draggable.ids.append(name.to_int()):
		printerr("Something went wrong appending to draggable ids!")

	l_draggable.files = false
	l_draggable.duration = Project.clips[name.to_int()].duration
	l_draggable.mouse_offset = TimelineClips.get_frame_nr(get_local_mouse_position().x)

	l_draggable.ignore.append(l_ignore)
	l_draggable.clip_buttons.append(self)

	modulate = Color(1, 1, 1, 0.1)
	return l_draggable


func _notification(a_notification_type: int) -> void:
	match a_notification_type:
		NOTIFICATION_DRAG_END:
			if is_dragging:
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
	l_button.size.x = 3
	if !a_left:
		l_button.position.x -= 3
	l_button.mouse_filter = Control.MOUSE_FILTER_PASS

	if l_button.button_down.connect(_on_resize_engaged.bind(a_left)):
		printerr("Couldn't connect button_down to _on_resize_engaged!")
	if l_button.button_up.connect(_on_commit_resize):
		printerr("Couldn't connect button_down to _on_resize_engaged!")


func _on_resize_engaged(a_left: bool) -> void:
	var l_clip_data: ClipData = Project.clips[name.to_int()]
	var l_track: int = TimelineClips.get_track_id(position.y)
	var l_frame: int = TimelineClips.get_frame_nr(position.x)

	var l_previous: int = -1
	start_frame = l_clip_data.start_frame
	duration = l_clip_data.duration

	# First calculate spacing left of handle to other clips
	if a_left:
		for i: int in Project.tracks[l_track]:
			if i < l_frame:
				l_previous = max(0, i - 1)
			else:
				break

		if l_previous == -1:
			max_left_resize = 0
		else:
			max_left_resize = Project.get_clip_data(l_track, l_previous).duration + l_previous
	else:
		max_left_resize = l_clip_data.start_frame + 1

	# First calculate spacing right of handle to other clips
	l_previous = -1

	if !a_left:
		for i: int in Project.tracks[l_track]:
			if i > l_frame:
				l_previous = i
				break

		max_right_resize = maxi(l_previous, -1)
	else:
		max_right_resize = l_clip_data.duration + l_clip_data.start_frame - 1

	# Check if audio/video how much space is left to extend, take minimum
	match l_clip_data.type:
		File.TYPE.VIDEO:
			pass
		File.TYPE.AUDIO:
			pass
 
	if a_left:
		is_resizing_left = true
	else:
		is_resizing_right = true

	get_viewport().set_input_as_handled()


func _on_commit_resize() -> void:
	is_resizing_left = false
	is_resizing_right = false

	Project.undo_redo.create_action("Resizing clip on timeline")

	Project.undo_redo.add_do_method(_set_resize_data.bind(
			TimelineClips.get_frame_nr(position.x),
			TimelineClips.get_frame_nr(size.x)))

	Project.undo_redo.add_undo_method(_set_resize_data.bind(
			Project.clips[name.to_int()].start_frame,
			Project.clips[name.to_int()].duration))

	Project.undo_redo.add_do_method(ViewPanel.instance._update_frame)
	Project.undo_redo.add_undo_method(ViewPanel.instance._update_frame)
	Project.undo_redo.commit_action()


func _set_resize_data(a_new_start: int, a_new_duration: int) -> void:
	var l_clip_data: ClipData = Project.clips[name.to_int()]

	if l_clip_data.start_frame != a_new_start:
		l_clip_data.begin += a_new_start - l_clip_data.start_frame

	position.x = a_new_start * Project.timeline_scale
	size.x = a_new_duration * Project.timeline_scale

	if !Project.tracks[TimelineClips.get_track_id(position.y)].erase(
			Project.clips[name.to_int()].start_frame):
		printerr("Could not erase from tracks!")
	Project.tracks[TimelineClips.get_track_id(position.y)][a_new_start] = name.to_int()

	l_clip_data.start_frame = a_new_start
	l_clip_data.duration = a_new_duration
	l_clip_data.update_audio_data()

	TimelineClips.instance.update_timeline_end()


func _cut_clip(a_playhead: int) -> void:
	var l_clip_data: ClipData = Project.clips[name.to_int()]
	var l_new_clip: ClipData = ClipData.new()

	# Check if playhead is inside of clip
	if a_playhead <= l_clip_data.start_frame:
		return # Playhead is left of the clip
	elif a_playhead >= l_clip_data.start_frame + l_clip_data.duration:
		return # Playhead is right of the clip

	var l_frame: int = a_playhead - l_clip_data.start_frame

	l_new_clip.id = Utils.get_unique_id(Project.clips.keys())
	l_new_clip.file_id = l_clip_data.file_id
	l_new_clip.type = l_clip_data.type

	l_new_clip.start_frame = a_playhead
	l_new_clip.duration = abs(l_clip_data.duration - l_frame)
	l_new_clip.begin = l_clip_data.begin + l_frame

	l_clip_data.duration -= l_new_clip.duration
	size.x = l_clip_data.duration * Project.timeline_scale

	TimelineClips.instance._add_new_clips({
			l_new_clip.id: l_new_clip}, TimelineClips.get_track_id(position.y))
	
	l_clip_data.update_audio_data()


func _uncut_clip(a_playhead: int) -> void:
	var l_track: int = TimelineClips.get_track_id(position.y)
	var l_current_clip: ClipData = Project.clips[name.to_int()]
	var l_split_clip: ClipData = Project.get_clip_data(l_track, a_playhead)

	l_current_clip.duration += l_split_clip.duration
	size.x = l_current_clip.duration * Project.timeline_scale

	TimelineClips.instance.delete_clip(l_track, a_playhead)

	l_current_clip.update_audio_data()

