class_name ClipButton
extends Button


#enum STATE_FADE_BUTTON {
#		NULL = -1,
#		AUDIO_IN  = 0,	# 0000
#		AUDIO_OUT = 1,	# 0001
#		VIDEO_IN  = 2,	# 0010
#		VIDEO_OUT = 3,	# 0011
#}
#
#const SIZE_FADE_BUTTON: Vector2 = Vector2(10, 10)
#
#
#
#@onready var parent: Control = get_parent()
#
#
#var clip_data: ClipData
#
#var fade_in_video_button: TextureButton = null
#var fade_in_audio_button: TextureButton = null
#var fade_out_video_button: TextureButton = null
#var fade_out_audio_button: TextureButton = null
#
#var is_dragging: bool = false
#var is_resizing_left: bool = false
#var is_resizing_right: bool = false
#
#var max_left_resize: int = 0 # Minimum frame
#var max_right_resize: int = 0 # Maximum frame
#var _original_start_frame: int = 0
#var _original_duration: int = 0
#var _original_begin: int = 0
#
#var _visual_start_frame: int = 0
#var _visual_duration: int = 0
#
#var _fade_override: int = -1
#var _fade_state: STATE_FADE_BUTTON = STATE_FADE_BUTTON.NULL
#
#var wave: bool = false
#
#
#
#func _ready() -> void:
#	clip_data = Project.get_clip(name.to_int())
#	var type: File.TYPE = FileHandler.get_file(clip_data.file_id).type
#
#	_original_start_frame = clip_data.start_frame
#	_original_duration = clip_data.duration
#	_original_begin = clip_data.begin
#
#	_visual_start_frame = _original_start_frame
#	_visual_duration = _original_duration
#
#	_add_resize_button(PRESET_LEFT_WIDE, true)
#	_add_resize_button(PRESET_RIGHT_WIDE, false)
#
#	button_down.connect(_on_button_down)
#	pressed.connect(_on_pressed)
#	gui_input.connect(_on_gui_input)
#
#	if FileHandler.get_file(clip_data.file_id).type in EditorCore.AUDIO_TYPES:
#		wave = true
#		FileHandler.get_file_data(clip_data.file_id).update_wave.connect(queue_redraw)
#
#	# Add fade buttons.
#	if type in EditorCore.VISUAL_TYPES:
#		fade_in_video_button = TextureButton.new()
#		fade_out_video_button = TextureButton.new()
#		
#		fade_in_video_button.custom_minimum_size = SIZE_FADE_BUTTON
#		fade_out_video_button.custom_minimum_size = SIZE_FADE_BUTTON
#
#		fade_in_video_button.button_down.connect(_on_fade_button_pressed.bind(true, true))
#		fade_out_video_button.button_down.connect(_on_fade_button_pressed.bind(false, true))
#		fade_in_video_button.button_up.connect(_on_fade_button_released)
#		fade_out_video_button.button_up.connect(_on_fade_button_released)
#
#		fade_in_video_button.ignore_texture_size = true
#		fade_out_video_button.ignore_texture_size = true
#
#		fade_in_video_button.stretch_mode = TextureButton.STRETCH_KEEP_ASPECT_CENTERED
#		fade_out_video_button.stretch_mode = TextureButton.STRETCH_KEEP_ASPECT_CENTERED
#
#		fade_in_video_button.texture_hover = preload(Library.ICON_BUTTON_FADE)
#		fade_out_video_button.texture_hover = preload(Library.ICON_BUTTON_FADE)
#
#		fade_in_video_button.position.y = size.y - (SIZE_FADE_BUTTON.y / 2)
#		fade_out_video_button.position.y = size.y - (SIZE_FADE_BUTTON.y / 2)
#
#		add_child(fade_in_video_button)
#		add_child(fade_out_video_button)
#
#	if type in EditorCore.AUDIO_TYPES:
#		fade_in_audio_button = TextureButton.new()
#		fade_out_audio_button = TextureButton.new()
#
#		fade_in_audio_button.custom_minimum_size = SIZE_FADE_BUTTON
#		fade_out_audio_button.custom_minimum_size = SIZE_FADE_BUTTON
#
#		fade_in_audio_button.button_down.connect(_on_fade_button_pressed.bind(true, false))
#		fade_out_audio_button.button_down.connect(_on_fade_button_pressed.bind(false, false))
#		fade_in_audio_button.button_up.connect(_on_fade_button_released)
#		fade_out_audio_button.button_up.connect(_on_fade_button_released)
#
#		fade_in_audio_button.ignore_texture_size = true
#		fade_out_audio_button.ignore_texture_size = true
#
#		fade_in_audio_button.stretch_mode = TextureButton.STRETCH_KEEP_ASPECT_CENTERED
#		fade_out_audio_button.stretch_mode = TextureButton.STRETCH_KEEP_ASPECT_CENTERED
#
#		fade_in_audio_button.texture_hover = preload(Library.ICON_BUTTON_FADE)
#		fade_out_audio_button.texture_hover = preload(Library.ICON_BUTTON_FADE)
#
#		fade_in_audio_button.position.y = -2
#		fade_out_audio_button.position.y = -2
#
#		add_child(fade_in_audio_button)
#		add_child(fade_out_audio_button)
#
#	on_fade_changed.call_deferred()
#
#
#func _process(_delta: float) -> void:
#	if _fade_state != STATE_FADE_BUTTON.NULL:
#		_fade_override = clampi(Timeline.get_frame_id(get_local_mouse_position().x), 0, clip_data.duration)
#
#		if _fade_state & 1:
#			_fade_override = clip_data.duration - _fade_override
#
#		queue_redraw()
#		_update_clip_fade()
#		EditorCore.update_frame()
#	elif is_resizing_left or is_resizing_right:
#		var mouse_x: float = parent.get_local_mouse_position().x
#		var zoom: float = Timeline.get_zoom()
#		var potential_frame: int = floori(mouse_x / zoom)
#
#		if is_resizing_left:
#			potential_frame = clamp(potential_frame, max_left_resize, max_right_resize)
#			_visual_start_frame = potential_frame
#			_visual_duration = _original_start_frame + _original_duration - _visual_start_frame
#		else:
#			if max_right_resize != -1:
#				potential_frame = clamp(potential_frame, max_left_resize, max_right_resize)
#			else:
#				potential_frame = maxi(potential_frame, max_left_resize)
#			_visual_start_frame = _original_start_frame
#			_visual_duration = potential_frame - _visual_start_frame
#
#		position.x = Timeline.get_frame_pos(_visual_start_frame)
#		size.x = Timeline.get_clip_size(_visual_duration)
#		queue_redraw()
#
#
#func _draw() -> void:
#	if wave:
#		DrawManager.draw_clip_wave(self)
#
#	if fade_in_video_button != null:
#		var fade_in: int = clip_data.effects_video.fade_in
#		var fade_out: int = clip_data.effects_video.fade_out
#
#		if _fade_state == STATE_FADE_BUTTON.VIDEO_IN:
#			fade_in = _fade_override
#		if _fade_state == STATE_FADE_BUTTON.VIDEO_OUT:
#			fade_out = _fade_override
#
#		if fade_in > 0:  DrawManager.draw_video_fade_in(self, fade_in)
#		if fade_out > 0: DrawManager.draw_video_fade_out(self, fade_out)
#	if fade_in_audio_button != null:
#		var fade_in: int = clip_data.effects_audio.fade_in
#		var fade_out: int = clip_data.effects_audio.fade_out
#
#		if _fade_state == STATE_FADE_BUTTON.AUDIO_IN:
#			fade_in = _fade_override
#		if _fade_state == STATE_FADE_BUTTON.AUDIO_OUT:
#			fade_out = _fade_override
#
#		if fade_in > 0:  DrawManager.draw_audio_fade_in(self, fade_in)
#		if fade_out > 0: DrawManager.draw_audio_fade_out(self, fade_out)
#
#
#func _on_button_down() -> void:
#	if !is_resizing_left and !is_resizing_right:
#		is_dragging = true
#		get_viewport().set_input_as_handled()	
#
#
#func _on_pressed() -> void:
#	if Input.is_key_pressed(KEY_SHIFT):
#		Timeline.instance.selected_clips.append(clip_data.clip_id)
#	else:
#		Timeline.instance.selected_clips = [clip_data.clip_id]
#
#
#func _input(event: InputEvent) -> void:
#	if has_focus() and event.is_action_pressed("ctrl_click", false, true):
#		print("---")
#		print("Clip id: ", clip_data.clip_id)
#		print("Clip track: ", clip_data.track_id, "\n")
#		print("Clip duration: ", clip_data.duration)
#		print("Clip start frame: ", clip_data.start_frame)
#		print("Clip end frame: ", clip_data.end_frame)
#		print("Clip begin: ", clip_data.begin)
#
#
#func _on_gui_input(event: InputEvent) -> void:
#	# We need mouse passthrough to allow for clip dragging without issues
#	# But when clicking on clips we do not want the playhead to keep jumping.
#	# Maybe later on we can allow for clip clicking and playhead moving by
#	# holding alt or something.
#	if event is InputEventMouseButton:
#		var mouse_event: InputEventMouseButton = event
#
#		if mouse_event.pressed and mouse_event.button_index == MOUSE_BUTTON_LEFT:
#			EffectsPanel.instance.on_clip_pressed(name.to_int())
#
#		if mouse_event.button_index in [MOUSE_BUTTON_WHEEL_UP, MOUSE_BUTTON_WHEEL_DOWN]:
#			return
#
#		if mouse_event.button_index == MOUSE_BUTTON_RIGHT:
#			var popup: PopupMenu = PopupManager.create_popup_menu()
#
#			popup.add_theme_constant_override("icon_max_width", 20)
#
#			if Project.get_clip_type(clip_data.clip_id) == File.TYPE.VIDEO:
#				popup.add_check_item("Clip only video instance", 0)
#				popup.set_item_checked(0, FileHandler.get_file_data(clip_data.file_id).clip_only_video.has(clip_data.clip_id))
#				popup.id_pressed.connect(_on_clip_popup_menu_pressed.bind(popup))
#
#			PopupManager.show_popup_menu(popup)
#
#
#	if event.is_action_pressed("delete_clip"):
#		InputManager.undo_redo.create_action("Deleting clip on timeline")
#
#		InputManager.undo_redo.add_do_method(Timeline.instance.delete_clip.bind(clip_data))
#		InputManager.undo_redo.add_undo_method(Timeline.instance.undelete_clip.bind(clip_data))
#
#		InputManager.undo_redo.add_do_method(EditorCore.set_frame.bind(EditorCore.frame_nr))
#		InputManager.undo_redo.add_undo_method(EditorCore.set_frame.bind(EditorCore.frame_nr))
#		InputManager.undo_redo.commit_action()
#
#
#func _on_clip_popup_menu_pressed(id: int, popup_menu: PopupMenu) -> void:
#	# 0 = Clip video only instance
#	if !popup_menu.is_item_checked(id):
#		FileHandler.get_file(clip_data.file_id).enable_clip_only_video(clip_data.clip_id)
#	else:
#		FileHandler.get_file(clip_data.file_id).disable_clip_only_video(clip_data.clip_id)
#
#
#func _get_drag_data(_pos: Vector2) -> Draggable:
#	if is_resizing_left or is_resizing_right:
#		return null
#
#	var draggable: Draggable = Draggable.new()
#
#	# Add clip id to array
#	if draggable.ids.append(name.to_int()):
#		printerr("Something went wrong appending to draggable ids!")
#
#	draggable.files = false
#	draggable.duration = clip_data.duration
#	draggable.offset = int(get_local_mouse_position().x / Timeline.get_zoom())
#
#	draggable.ignores.append(Vector2i(clip_data.track_id, clip_data.start_frame))
#	draggable.clip_buttons.append(self)
#
#	modulate = Color(1, 1, 1, 0.1)
#	return draggable
#
#
#func _notification(notification_type: int) -> void:
#	match notification_type:
#		NOTIFICATION_DRAG_END:
#			is_dragging = false
#			modulate = Color(1, 1, 1, 1)
#
#
#func _add_resize_button(preset: LayoutPreset, left: bool) -> void:
#	var button: Button = Button.new()
#	add_child(button)
#
#	button.add_theme_stylebox_override("normal", StyleBoxEmpty.new())
#	button.add_theme_stylebox_override("pressed", StyleBoxEmpty.new())
#	button.add_theme_stylebox_override("hover", StyleBoxEmpty.new())
#	button.add_theme_stylebox_override("focus", StyleBoxEmpty.new())
#	button.mouse_default_cursor_shape = Control.CURSOR_HSIZE
#	button.set_anchors_and_offsets_preset(preset)
#	button.custom_minimum_size.x = 4
#	if !left:
#		button.position.x -= 4
#	button.mouse_filter = Control.MOUSE_FILTER_PASS
#
#	if button.button_down.connect(_on_resize_engaged.bind(left)):
#		printerr("Couldn't connect button_down to _on_resize_engaged!")
#	if button.button_up.connect(_on_commit_resize):
#		printerr("Couldn't connect button_down to _on_resize_engaged!")
#
#
#func _on_resize_engaged(left: bool) -> void:
#	var previous: int = -1
#
#	if fade_in_video_button != null:
#		fade_in_video_button.disabled = true
#		fade_out_video_button.disabled = true
#
#	if fade_in_audio_button != null:
#		fade_in_audio_button.disabled = true
#		fade_out_audio_button.disabled = true
#
#	_original_start_frame = clip_data.start_frame
#	_original_duration = clip_data.duration
#	_original_begin = clip_data.begin
#
#	_visual_start_frame = _original_start_frame
#	_visual_duration = _original_duration
#
#	max_left_resize = 0
#	max_right_resize = -1
#
#	# First calculate spacing left of handle to other clips
#	if left:
#		# Left resize can't go further than end frame.
#		max_right_resize = clip_data.end_frame
#		max_left_resize = clip_data.start_frame - clip_data.begin
#
#		for i: int in Project.get_track_keys(clip_data.track_id):
#			if i < clip_data.start_frame:
#				previous = i
#				continue
#
#			if previous == -1:
#				max_left_resize = 0
#				break
#
#			var front_clip_id: int = Project.get_track_data(clip_data.track_id)[previous]
#			max_left_resize = maxi(Project.get_clip(front_clip_id).get_end_frame(), max_left_resize)
#	else:
#		# Right resize can't go further than frame beginning
#		max_left_resize = clip_data.start_frame + 1
#
#		for i: int in Project.get_track_keys(clip_data.track_id):
#			if i > clip_data.start_frame:
#				previous = i
#				break
#		max_right_resize = maxi(previous, -1)
#
#
#	# Check if audio/video how much space is left to extend, take minimum
#	if Project.get_clip_type(name.to_int()) in [File.TYPE.VIDEO, File.TYPE.AUDIO]:
#		if left:
#			max_left_resize = max(max_left_resize, clip_data.start_frame - clip_data.begin)
#		else:
#			var duration_left: int = FileHandler.get_file(clip_data.file_id).duration
#
#			duration_left -= clip_data.begin
#			duration_left += clip_data.start_frame
#
#			if max_right_resize == -1:
#				max_right_resize = duration_left
#			else:
#				max_right_resize = min(max_right_resize, duration_left)
#				
#	is_resizing_left = left
#	is_resizing_right = !left
#	get_viewport().set_input_as_handled()
#
#
#func _on_commit_resize() -> void:
#	is_resizing_left = false
#	is_resizing_right = false
#
#	InputManager.undo_redo.create_action("Resizing clip on timeline")
#	InputManager.undo_redo.add_do_method(_set_resize_data.bind(
#			_visual_start_frame, _visual_duration))
#	InputManager.undo_redo.add_do_method(EditorCore.set_frame.bind(EditorCore.frame_nr))
#	InputManager.undo_redo.add_do_method(update_fade_button_pos)
#	InputManager.undo_redo.add_do_method(queue_redraw)
#
#	InputManager.undo_redo.add_undo_method(_set_resize_data.bind(clip_data.start_frame, clip_data.duration))
#	InputManager.undo_redo.add_undo_method(EditorCore.set_frame.bind(EditorCore.frame_nr))
#	InputManager.undo_redo.add_undo_method(update_fade_button_pos)
#	InputManager.undo_redo.add_undo_method(queue_redraw)
#
#	if fade_in_video_button != null:
#		fade_in_video_button.disabled = false
#		fade_out_video_button.disabled = false
#
#	if fade_in_audio_button != null:
#		fade_in_audio_button.disabled = false
#		fade_out_audio_button.disabled = false
#
#	InputManager.undo_redo.commit_action()
#
#
#func _set_resize_data(new_start: int, new_duration: int) -> void:
#	if clip_data.start_frame != new_start:
#		clip_data.begin += new_start - clip_data.start_frame
#
#	position.x = Timeline.get_frame_pos(new_start)
#	size.x = Timeline.get_clip_size(new_duration)
#
#	Project.erase_track_entry(clip_data.track_id, clip_data.start_frame)
#	Project.set_track_data(clip_data.track_id, new_start, name.to_int())
#
#	clip_data.start_frame = new_start
#	clip_data.duration = new_duration
#
#	Project.update_timeline_end()
#
#
#func on_fade_changed() -> void:
#	update_fade_button_pos()
#	queue_redraw()
#
#
#func _on_timeline_zoom_changed() -> void:
#	update_fade_button_pos()
#	queue_redraw()
#
#
#func _on_fade_button_pressed(fade_in: bool, video: bool) -> void:
#	_fade_state = ((0 if fade_in else 1) | (2 if video else 0)) as STATE_FADE_BUTTON
#		
#
#func _update_clip_fade() -> void:
#	match _fade_state:
#		STATE_FADE_BUTTON.VIDEO_IN:  clip_data.effects_video.fade_in = _fade_override
#		STATE_FADE_BUTTON.VIDEO_OUT: clip_data.effects_video.fade_out = _fade_override
#		STATE_FADE_BUTTON.AUDIO_IN:  clip_data.effects_audio.fade_in = _fade_override
#		STATE_FADE_BUTTON.AUDIO_OUT: clip_data.effects_audio.fade_out = _fade_override
#
#
#func _on_fade_button_released() -> void:
#	_fade_override = -1
#	_fade_state = STATE_FADE_BUTTON.NULL
#	update_fade_button_pos()
#
#
#func update_fade_button_pos() -> void:
#	if fade_in_video_button != null:
#		fade_in_video_button.position.x = Timeline.get_frame_pos(
#				maxi(0, clip_data.effects_video.fade_in)) - (SIZE_FADE_BUTTON.x / 2)
#		fade_out_video_button.position.x = size.x - Timeline.get_frame_pos(
#				maxi(0, clip_data.effects_video.fade_out)) - (SIZE_FADE_BUTTON.x / 2)
#
#	if fade_in_audio_button != null:
#		fade_in_audio_button.position.x = Timeline.get_frame_pos(
#				maxi(0, clip_data.effects_audio.fade_in)) - (SIZE_FADE_BUTTON.x / 2)
#		fade_out_audio_button.position.x = size.x - Timeline.get_frame_pos(
#				maxi(0, clip_data.effects_audio.fade_out)) - (SIZE_FADE_BUTTON.x / 2)
#
