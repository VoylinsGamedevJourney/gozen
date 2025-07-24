class_name ClipButton
extends Button

# TODO: Move this to settings
var color_wave: Color = Color(0.82, 0.82, 0.82, 0.8)
var color_video_fade: Color = Color(0.76, 1, 0.18, 0.3)
var color_audio_fade: Color = Color(0.80, 0.36, 0.36, 0.3)
var color_video_fade_line: Color = Color(0.76, 1, 0.18, 0.5)
var color_audio_fade_line: Color = Color(0.80, 0.36, 0.36, 0.5)


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
	Toolbox.connect_func(pressed, _on_pressed)
	Toolbox.connect_func(gui_input, _on_gui_input)
	Toolbox.connect_func(Timeline.instance.zoom_changed, queue_redraw)

	if Project.get_file(clip_data.file_id).type in EditorCore.AUDIO_TYPES:
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
			if max_right_resize != -1:
				potential_frame = clamp(potential_frame, max_left_resize, max_right_resize)
			else:
				potential_frame = maxi(potential_frame, max_left_resize)
			_visual_start_frame = _original_start_frame
			_visual_duration = potential_frame - _visual_start_frame

		position.x = Timeline.get_frame_pos(_visual_start_frame)
		size.x = Timeline.get_clip_size(_visual_duration)
		queue_redraw()


func _draw() -> void:
	# Draw wave.
	if wave:
		var full_wave_data: PackedFloat32Array = Project.get_file_data(clip_data.file_id).audio_wave_data
		var display_duration: int
		var display_begin_offset: int

		if full_wave_data.is_empty():
			return

		if is_resizing_left or is_resizing_right:
			display_duration = _visual_duration
			display_begin_offset = _original_begin + (_visual_start_frame - _original_start_frame)
		else:
			display_duration = clip_data.duration
			display_begin_offset = clip_data.begin

		if display_duration <= 0 or size.x <= 0:
			return

		var block_width: float = Timeline.get_zoom()
		var panel_height: float = size.y

		for i: int in display_duration:
			var wave_data_index: int = display_begin_offset + i

			if wave_data_index >= 0 and wave_data_index < full_wave_data.size():
				var normalized_height: float = full_wave_data[wave_data_index]
				var block_height: float = clampf(normalized_height * (panel_height * 2), 0, panel_height)
				var block_pos_y: float = 0.0

				match Settings.get_audio_waveform_style():
					SettingsData.AUDIO_WAVEFORM_STYLE.CENTER:
						block_pos_y = (panel_height - block_height) / 2.0
					SettingsData.AUDIO_WAVEFORM_STYLE.BOTTOM_TO_TOP:
						block_pos_y = panel_height - block_height

				var block_rect: Rect2 = Rect2(
						i * block_width, block_pos_y,
						block_width, block_height)

				draw_rect(block_rect, color_wave)

	# Draw video fade in.
	if clip_data.effects_video.fade_in != 0:
		var video_fade_in_pos: PackedVector2Array = [
				Vector2(0, 0), Vector2(0, size.y),
				Vector2(Timeline.get_frame_pos(clip_data.effects_video.fade_in), size.y)]
		draw_colored_polygon(video_fade_in_pos, color_video_fade)
		draw_polyline(video_fade_in_pos, color_video_fade_line, 3, true)

	# Draw audio fade in.
	if clip_data.effects_audio.fade_in != 0:
		var audio_fade_in_pos: PackedVector2Array = [
				Vector2(0, 0), Vector2(0, size.y),
				Vector2(Timeline.get_frame_pos(clip_data.effects_audio.fade_in), 0)]

		draw_colored_polygon(audio_fade_in_pos, color_audio_fade)
		draw_polyline(audio_fade_in_pos, color_audio_fade_line, 3, true)

	# Draw video fade out.
	if clip_data.effects_video.fade_out != 0:
		var video_fade_out_pos: PackedVector2Array = [
				Vector2(size.x, 0), Vector2(size.x, size.y),
				Vector2(size.x - Timeline.get_frame_pos(clip_data.effects_video.fade_out), size.y)]
		draw_colored_polygon(video_fade_out_pos, color_video_fade)
		draw_polyline(video_fade_out_pos, color_video_fade_line, 3, true)

	# Draw audio fade in.
	if clip_data.effects_audio.fade_out != 0:
		var audio_fade_out_pos: PackedVector2Array = [
				Vector2(size.x, 0), Vector2(size.x, size.y),
				Vector2(size.x - Timeline.get_frame_pos(clip_data.effects_audio.fade_out), 0)]

		draw_colored_polygon(audio_fade_out_pos, color_audio_fade)
		draw_polyline(audio_fade_out_pos, color_audio_fade_line, 3, true)


func _on_button_down() -> void:
	if is_resizing_left or is_resizing_right:
		return

	is_dragging = true
	get_viewport().set_input_as_handled()	


func _on_pressed() -> void:
	if Input.is_key_pressed(KEY_SHIFT):
		Timeline.instance.selected_clips.append(clip_data.clip_id)
	else:
		Timeline.instance.selected_clips = [clip_data.clip_id]


func _input(event: InputEvent) -> void:
	if has_focus() and event.is_action_pressed("ctrl_click", false, true):
		print("---")
		print("Clip id: ", clip_data.clip_id)
		print("Clip track: ", clip_data.track_id, "\n")
		print("Clip duration: ", clip_data.duration)
		print("Clip start frame: ", clip_data.start_frame)
		print("Clip end frame: ", clip_data.end_frame)
		print("Clip begin: ", clip_data.begin)


func _on_gui_input(event: InputEvent) -> void:
	# We need mouse passthrough to allow for clip dragging without issues
	# But when clicking on clips we do not want the playhead to keep jumping.
	# Maybe later on we can allow for clip clicking and playhead moving by
	# holding alt or something.
	if event is InputEventMouseButton:
		var mouse_event: InputEventMouseButton = event

		if mouse_event.pressed and mouse_event.button_index == MOUSE_BUTTON_LEFT:
			EffectsPanel.instance.on_clip_pressed(name.to_int())

		if mouse_event.button_index in [MOUSE_BUTTON_WHEEL_UP, MOUSE_BUTTON_WHEEL_DOWN]:
			return

		if mouse_event.button_index == MOUSE_BUTTON_RIGHT:
			var popup: PopupMenu = Toolbox.get_popup()

			popup.add_theme_constant_override("icon_max_width", 20)

			if Project.get_clip_type(clip_data.clip_id) == File.TYPE.VIDEO:
				popup.add_check_item("Clip only video instance", 0)
				popup.set_item_checked(0, Project.get_file_data(clip_data.file_id).clip_only_video.has(clip_data.clip_id))
				Toolbox.connect_func(popup.id_pressed, _on_clip_popup_menu_pressed.bind(popup))

			Toolbox.show_popup(popup)


	if event.is_action_pressed("delete_clip"):
		InputManager.undo_redo.create_action("Deleting clip on timeline")

		InputManager.undo_redo.add_do_method(Timeline.instance.delete_clip.bind(clip_data))
		InputManager.undo_redo.add_undo_method(Timeline.instance.undelete_clip.bind(clip_data))

		InputManager.undo_redo.add_do_method(EditorCore.set_frame.bind(EditorCore.frame_nr))
		InputManager.undo_redo.add_undo_method(EditorCore.set_frame.bind(EditorCore.frame_nr))
		InputManager.undo_redo.commit_action()


func _on_clip_popup_menu_pressed(id: int, popup_menu: PopupMenu) -> void:
	# 0 = Clip video only instance
	if !popup_menu.is_item_checked(id):
		Project.get_file(clip_data.file_id).enable_clip_only_video(clip_data.clip_id)
	else:
		Project.get_file(clip_data.file_id).disable_clip_only_video(clip_data.clip_id)


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
		# Left resize can't go further than end frame.
		max_right_resize = clip_data.end_frame
		max_left_resize = clip_data.start_frame - clip_data.begin

		for i: int in Project.get_track_keys(clip_data.track_id):
			if i < clip_data.start_frame:
				previous = i
				continue

			if previous == -1:
				break

			var front_clip_id: int = Project.get_track_data(clip_data.track_id)[previous]
			max_left_resize = maxi(Project.get_clip(front_clip_id).get_end_frame(), max_left_resize)
	else:
		# Right resize can't go further than frame beginning
		max_left_resize = clip_data.start_frame + 1

		for i: int in Project.get_track_keys(clip_data.track_id):
			if i > clip_data.start_frame:
				previous = i
				break
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
			_visual_start_frame, _visual_duration))
	InputManager.undo_redo.add_do_method(EditorCore.set_frame.bind(EditorCore.frame_nr))
	InputManager.undo_redo.add_do_method(queue_redraw)

	InputManager.undo_redo.add_undo_method(_set_resize_data.bind(clip_data.start_frame, clip_data.duration))
	InputManager.undo_redo.add_undo_method(EditorCore.set_frame.bind(EditorCore.frame_nr))
	InputManager.undo_redo.add_undo_method(queue_redraw)

	InputManager.undo_redo.commit_action()


func _set_resize_data(new_start: int, new_duration: int) -> void:
	if clip_data.start_frame != new_start:
		clip_data.begin += new_start - clip_data.start_frame

	position.x = Timeline.get_frame_pos(new_start)
	size.x = Timeline.get_clip_size(new_duration)

	Project.erase_track_entry(clip_data.track_id, clip_data.start_frame)
	Project.set_track_data(clip_data.track_id, new_start, name.to_int())

	clip_data.start_frame = new_start
	clip_data.duration = new_duration

	Project.update_timeline_end()


func on_fade_changed() -> void:
	queue_redraw()

