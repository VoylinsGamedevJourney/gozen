extends TextureRect


signal zoom_changed(new_zoom: float)


enum PopupType {
	SAVE_SCREENSHOT,
	SAVE_SCREENSHOT_TO_PROJECT,
#	COPY_SCREENSHOT # TODO: Godot doesn't have the option yet to set clipboard image
	TOGGLE_SAFE_AREAS,
	TOGGLE_PREVIEW_WINDOW,
	RESET_ZOOM,
	RESET_PLAYBACK_SPEED,
}


const SIZE_CROSS: int = 20

const ZOOM_MIN: float = 0.1
const ZOOM_MAX: float = 10.0
const ZOOM_STEP: float = 1.1

const PAN_GESTURE_SPEED: float = 10.0


@onready var overlay_control: Control = get_parent()


var _is_panning: bool = false


var show_safe_areas: bool = false: set = set_show_safe_areas

var view_zoom: float = 1.0
var view_offset: Vector2 = Vector2.ZERO

var active_clip: ClipData = null
var active_effect: Effect = null
var active_overlay: EffectOverlay = null

var preview_window: Window



func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_STOP
	gui_input.connect(_on_gui_input)
	overlay_control.gui_input.connect(_on_overlay_gui_input)
	if EditorCore.viewport != null:
		texture = EditorCore.viewport.get_texture()
	else:
		printerr("ProjectViewTexture: Couldn't get viewport texture from EditorCore!")

	show_safe_areas = Settings.get_show_safe_areas_on_startup()

	set_anchors_preset(Control.PRESET_TOP_LEFT)
	overlay_control.clip_contents = true

	overlay_control.resized.connect(_update_transform)
	Project.project_ready.connect(_update_transform)
	Project.resolution_changed.connect(_update_transform)

	ClipLogic.selected.connect(_on_clip_selected)
	ClipLogic.deleted.connect(_on_clip_deleted)
	EffectsHandler.effect_selected.connect(_on_effect_selected)
	EffectsHandler.effect_removed.connect(_on_effect_removed)
	EditorCore.visual_frame_changed.connect(queue_redraw)
	EditorCore.play_changed.connect(func(_playing: bool) -> void:
			queue_redraw())

	if Project.is_loaded:
		_update_transform()


func _on_gui_input(event: InputEvent) -> void:
	if active_overlay and active_clip:
		if EditorCore.visual_frame_nr >= active_clip.start and EditorCore.visual_frame_nr < active_clip.end:
			active_overlay.input(event, self)
			if event.is_canceled() or get_viewport().is_input_handled():
				return

	if _handle_viewport_input(event, true):
		accept_event()


func _on_overlay_gui_input(event: InputEvent) -> void:
	if active_overlay and active_clip:
		if EditorCore.visual_frame_nr >= active_clip.start and EditorCore.visual_frame_nr < active_clip.end:
			var overlay_event: InputEvent = event
			if event is InputEventMouse:
				var translated_mouse_event: InputEventMouse = event.duplicate() as InputEventMouse
				translated_mouse_event.position -= position
				overlay_event = translated_mouse_event
			active_overlay.input(overlay_event, self)
			if overlay_event.is_canceled() or get_viewport().is_input_handled():
				overlay_control.accept_event()
				return

	if _handle_viewport_input(event, false):
		overlay_control.accept_event()


func _handle_viewport_input(event: InputEvent, from_texture: bool) -> bool:
	if event is InputEventMouseButton:
		var mouse_event: InputEventMouseButton = event as InputEventMouseButton
		if mouse_event.button_index == MOUSE_BUTTON_MIDDLE:
			if mouse_event.pressed and view_zoom > 1.0:
				_is_panning = true
				mouse_default_cursor_shape = Control.CURSOR_DRAG
				overlay_control.mouse_default_cursor_shape = Control.CURSOR_DRAG
				return true
			elif !mouse_event.pressed and _is_panning:
				_is_panning = false
				mouse_default_cursor_shape = Control.CURSOR_ARROW
				overlay_control.mouse_default_cursor_shape = Control.CURSOR_ARROW
				return true
		elif mouse_event.pressed and mouse_event.button_index == MOUSE_BUTTON_RIGHT:
			_open_context_menu()
			return true
		elif mouse_event.ctrl_pressed and mouse_event.pressed:
			var overlay_mouse_pos: Vector2 = mouse_event.position + position if from_texture else mouse_event.position
			if mouse_event.button_index == MOUSE_BUTTON_WHEEL_UP:
				zoom_at(ZOOM_STEP, overlay_mouse_pos)
				return true
			elif mouse_event.button_index == MOUSE_BUTTON_WHEEL_DOWN:
				zoom_at(1.0 / ZOOM_STEP, overlay_mouse_pos)
				return true
	elif event is InputEventMouseMotion and _is_panning:
		var motion_event: InputEventMouseMotion = event as InputEventMouseMotion
		if motion_event.button_mask & MOUSE_BUTTON_MASK_MIDDLE:
			view_offset += motion_event.relative
			_update_transform()
			return true
		else:
			_is_panning = false
			mouse_default_cursor_shape = Control.CURSOR_ARROW
			overlay_control.mouse_default_cursor_shape = Control.CURSOR_ARROW
	elif event is InputEventMagnifyGesture:
		var magnify_event: InputEventMagnifyGesture = event as InputEventMagnifyGesture
		var overlay_mouse_pos: Vector2 = magnify_event.position + position if from_texture else magnify_event.position
		if !is_equal_approx(magnify_event.factor, 1.0):
			zoom_at(magnify_event.factor, overlay_mouse_pos)
		return true
	elif event is InputEventPanGesture:
		var pan_event: InputEventPanGesture = event as InputEventPanGesture
		if pan_event.ctrl_pressed:
			var pan_delta: float = pan_event.delta.y if absf(pan_event.delta.y) >= absf(pan_event.delta.x) else pan_event.delta.x
			var overlay_mouse_pos: Vector2 = pan_event.position + position if from_texture else pan_event.position
			if !is_zero_approx(pan_delta):
				zoom_at(pow(ZOOM_STEP, clampf(-pan_delta, -3.0, 3.0)), overlay_mouse_pos)
			return true
		elif view_zoom > 1.0:
			view_offset -= pan_event.delta * PAN_GESTURE_SPEED
			_update_transform()
			return true
	return false


func _draw() -> void:
	if not is_equal_approx(view_zoom, 1.0):
		draw_rect(Rect2(Vector2.ZERO, size).grow(1.0), Color(1, 1, 1, 0.5), false, 2.0)
	if show_safe_areas:
		var width: float = size.x
		var height: float = size.y
		var view_rect: Rect2 = Rect2(0, 0, width, height)
		var center: Vector2i = view_rect.get_center()
		var color: Color = Color(1, 1, 1, 0.4)
		var first_border: Rect2 = view_rect.grow(-width * 0.05)
		var second_border: Rect2 = view_rect.grow(-width * 0.10)

		draw_rect(first_border, color, false, 1.0)
		draw_rect(second_border, color, false, 1.0)
		draw_line(Vector2(center.x - SIZE_CROSS, center.y), Vector2(center.x + SIZE_CROSS, center.y), color, 1.0)
		draw_line(Vector2(center.x, center.y - SIZE_CROSS), Vector2(center.x, center.y + SIZE_CROSS), color, 1.0)

	if active_overlay and active_clip:
		if EditorCore.visual_frame_nr >= active_clip.start and EditorCore.visual_frame_nr < active_clip.end:
			active_overlay.draw(self)



func set_show_safe_areas(value: bool) -> void:
	show_safe_areas = value
	queue_redraw()


func toggle_safe_areas() -> void:
	show_safe_areas = !show_safe_areas


#--- Zoom logic ---

func zoom_view(factor: float) -> void:
	zoom_at(factor, overlay_control.size / 2.0)


func zoom_at(factor: float, overlay_mouse_pos: Vector2) -> void:
	var previous_zoom: float = view_zoom
	var new_zoom: float = clampf(view_zoom * factor, ZOOM_MIN, ZOOM_MAX)

	if (previous_zoom < 1.0 and new_zoom > 1.0) or (previous_zoom > 1.0 and new_zoom < 1.0) or absf(new_zoom - 1.0) < 0.02:
		new_zoom = 1.0

	_apply_zoom(new_zoom, overlay_mouse_pos)


func set_zoom(target_zoom: float) -> void:
	var clamped_zoom: float = clampf(target_zoom, ZOOM_MIN, ZOOM_MAX)
	_apply_zoom(clamped_zoom, overlay_control.size / 2.0)


func reset_zoom() -> void:
	view_zoom = 1.0
	view_offset = Vector2.ZERO
	_is_panning = false
	mouse_default_cursor_shape = Control.CURSOR_ARROW
	overlay_control.mouse_default_cursor_shape = Control.CURSOR_ARROW
	_update_transform()
	zoom_changed.emit(view_zoom)


func _apply_zoom(new_zoom: float, overlay_pivot: Vector2) -> void:
	var previous_zoom: float = view_zoom
	if !is_equal_approx(previous_zoom, new_zoom):
		if Project.is_loaded and overlay_control.size.y > 0.0:
			var overlay_size: Vector2 = overlay_control.size
			var base_size: Vector2 = _get_base_size(overlay_size)
			var previous_size: Vector2 = base_size * previous_zoom
			var new_size: Vector2 = base_size * new_zoom
			var previous_position: Vector2 = (overlay_size - previous_size) / 2.0 + view_offset
			var pivot: Vector2 = (overlay_pivot - previous_position) / previous_size
			view_offset = (overlay_pivot - pivot * new_size) - (overlay_size - new_size) / 2.0

		view_zoom = new_zoom
		if is_equal_approx(view_zoom, 1.0):
			view_zoom = 1.0
			view_offset = Vector2.ZERO

		_update_transform()
		zoom_changed.emit(view_zoom)


#--- Clip helpers ---

func _on_clip_selected(clip: ClipData) -> void:
	active_clip = clip
	active_effect = null
	active_overlay = null
	if clip and clip.type & Type.GROUP_VISUAL:
		for effect_visual: Effect in clip.effects.video:
			if effect_visual.custom_overlay_path != "":
				_set_active_effect(effect_visual)
				break
	queue_redraw()


func _on_clip_deleted(clip_id: int) -> void:
	if active_clip and active_clip.id == clip_id:
		active_clip = null
		active_effect = null
		active_overlay = null
		queue_redraw()


#--- Effect helpers ---

func _on_effect_removed(clip: ClipData, _index: int, is_visual: bool) -> void:
	if is_visual and active_clip and active_clip.id == clip.id:
		_on_clip_selected(active_clip)


func _on_effect_selected(effect: Effect) -> void:
	if effect.custom_overlay_path != "":
		_set_active_effect(effect)
		queue_redraw()


func _set_active_effect(effect: Effect) -> void:
	active_effect = effect
	active_overlay = effect.get_custom_overlay()
	if active_overlay:
		active_overlay.initialize(active_clip, active_effect)


#--- Right click menu ---

func _open_context_menu() -> void:
	var popup: PopupMenu = PopupManager.create_menu()
	popup.add_item("Save screenshot ...", PopupType.SAVE_SCREENSHOT)
	popup.add_item("Save screenshot to project ...", PopupType.SAVE_SCREENSHOT_TO_PROJECT)
	popup.add_separator()
	popup.add_check_item("Show safe areas", PopupType.TOGGLE_SAFE_AREAS)
	popup.set_item_checked(popup.get_item_index(PopupType.TOGGLE_SAFE_AREAS), show_safe_areas)
	# popup.add_item("Copy screenshot to clipboard", PopupType.COPY_SCREENSHOT) # TODO: Godot doesn't have the option yet to set clipboard image
	if not is_equal_approx(view_zoom, 1.0):
		popup.add_item("Reset zoom", PopupType.RESET_ZOOM)
	if not is_equal_approx(EditorCore.playback_speed, 1.0):
		popup.add_item("Reset playback speed", PopupType.RESET_PLAYBACK_SPEED)
	popup.add_separator()

	popup.add_item(
			"Close full screen preview" if preview_window else "Open full screen preview",
			PopupType.TOGGLE_PREVIEW_WINDOW)
	popup.id_pressed.connect(_on_popup_id_pressed)
	PopupManager.show_menu(popup)


func _on_popup_id_pressed(id: int) -> void:
	if id == PopupType.TOGGLE_SAFE_AREAS:
		toggle_safe_areas()
	elif id == PopupType.RESET_ZOOM:
		reset_zoom()
	elif id == PopupType.RESET_PLAYBACK_SPEED:
		EditorCore.playback_speed = 1.0
	elif id in [PopupType.SAVE_SCREENSHOT, PopupType.SAVE_SCREENSHOT_TO_PROJECT]:
		var file_dialog: FileDialog = PopupManager.create_file_dialog(
				"Save screenshot ...",
				FileDialog.FILE_MODE_SAVE_FILE,
				["*.webp", "*.png", "*.jpg", "*.jpeg"])

		if id == PopupType.SAVE_SCREENSHOT:
			file_dialog.file_selected.connect(_on_save_screenshot)
		else:
			file_dialog.file_selected.connect(_on_save_screenshot_to_project)

		var folder: String = Project.get_picker_path(OS.SYSTEM_DIR_PICTURES)
		var file_name: String = "image_%03d.webp"
		var nr: int = 1
		while true:
			if FileAccess.file_exists(folder.path_join(file_name % nr)):
				nr += 1
				continue
			break

		file_dialog.current_path = folder.path_join(file_name % nr)

		add_child(file_dialog)
		file_dialog.popup_centered()
#	elif id == PopupType.COPY_SCREENSHOT: # TODO: Godot doesn't have the option yet to set clipboard image
#		var image: Image = texture.get_image()
#		if image:
#			DisplayServer.clipboard_set_image(image)
#			NotificationManager.info("Screenshot copied to clipboard")
	elif id == PopupType.TOGGLE_PREVIEW_WINDOW:
		if preview_window:
			preview_window.queue_free()
			return
		preview_window = Window.new()
		preview_window.title = "GoZen Preview"

		var texture_rect: TextureRect = TextureRect.new()
		texture_rect.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		texture_rect.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		texture_rect.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)

		if EditorCore.viewport != null:
			texture_rect.texture = EditorCore.viewport.get_texture()

		preview_window.add_child(texture_rect)
		preview_window.close_requested.connect(func() -> void:
				preview_window.queue_free())

		add_child(preview_window)
		preview_window.popup_centered(Vector2i(1280, 720))


func _on_save_screenshot_to_project(path: String) -> void:
	_on_save_screenshot(path)
	await FileLogic.dropped([path])


func _on_save_screenshot(path: String) -> void:
	var extension: String = path.get_extension()
	if extension == "png":
		if texture.get_image().save_png(path):
			printerr("ProjectViewTexture: Problem saving screenshot to system!")
	elif extension == "webp":
		if texture.get_image().save_webp(path):
			printerr("ProjectViewTexture: Problem saving screenshot to system!")
	else: # JPG/JPEG
		if texture.get_image().save_jpg(path):
			printerr("ProjectViewTexture: Problem saving screenshot to system!")


#--- Helper functions ---

func _update_transform() -> void:
	if Project.is_loaded:
		var overlay_size: Vector2 = overlay_control.size
		if overlay_size.y != 0:
			size = _get_base_size(overlay_size) * view_zoom

			var max_offset: Vector2 = ((size - overlay_size) / 2.0).max(Vector2.ZERO)
			view_offset = view_offset.clamp(-max_offset, max_offset)
			position = (overlay_size - size) / 2.0 + view_offset
			queue_redraw()


func _get_base_size(overlay_size: Vector2) -> Vector2:
	var aspect: float = Project.data.resolution.x / float(Project.data.resolution.y)
	var base_size: Vector2 = overlay_size
	if overlay_size.x / overlay_size.y > aspect:
		base_size.x = overlay_size.y * aspect
	else:
		base_size.y = overlay_size.x / aspect
	return base_size
