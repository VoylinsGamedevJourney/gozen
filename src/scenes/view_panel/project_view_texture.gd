extends TextureRect


enum POPUP { SAVE_SCREENSHOT, SAVE_SCREENSHOT_TO_PROJECT }


const SIZE_CROSS: int = 20


@onready var overlay_control: Control = get_parent()


@export var show_safe_areas_button: TextureButton


var show_safe_areas: bool = true: set = set_show_safe_areas

var view_zoom: float = 1.0

var active_clip: ClipData = null
var active_effect: EffectVisual = null
var active_overlay: EffectVisualOverlay = null



func _ready() -> void:
	gui_input.connect(_on_gui_input)
	if EditorCore.viewport != null:
		texture = EditorCore.viewport.get_texture()
	else:
		printerr("ProjectViewTexture: Couldn't get viewport texture from EditorCore!")

	_update_safe_areas_button()

	set_anchors_preset(Control.PRESET_TOP_LEFT)
	overlay_control.clip_contents = true
	overlay_control.resized.connect(_update_transform)
	Project.project_ready.connect(_update_transform)
	if Project.is_loaded:
		_update_transform()

	ClipLogic.selected.connect(_on_clip_selected)
	ClipLogic.deleted.connect(_on_clip_deleted)
	EffectsHandler.effect_selected.connect(_on_effect_selected)
	EffectsHandler.effect_removed.connect(_on_effect_removed)
	EditorCore.visual_frame_changed.connect(queue_redraw)
	EditorCore.play_changed.connect(func(_playing: bool) -> void: queue_redraw())


func _update_transform() -> void:
	if not Project.is_loaded:
		return

	var overlay_size: Vector2 = overlay_control.size
	if overlay_size.y == 0:
		return

	var aspect: float = Project.data.resolution.x / float(Project.data.resolution.y)
	var base_size: Vector2 = overlay_size
	if overlay_size.x / overlay_size.y > aspect:
		base_size.x = overlay_size.y * aspect
	else:
		base_size.y = overlay_size.x / aspect

	size = base_size * view_zoom
	position = (overlay_size - size) / 2.0
	queue_redraw()


func _on_clip_selected(clip: ClipData) -> void:
	active_clip = clip
	active_effect = null
	active_overlay = null
	if clip and clip.type in EditorCore.VISUAL_TYPES:
		for effect_visual: EffectVisual in clip.effects.video:
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


func _on_effect_removed(clip: ClipData, _index: int, is_visual: bool) -> void:
	if is_visual and active_clip and active_clip.id == clip.id:
		_on_clip_selected(active_clip)


func _on_effect_selected(effect: Effect) -> void:
	if effect is not EffectVisual:
		return

	var effect_visual: EffectVisual = effect
	if effect_visual.custom_overlay_path != "":
		_set_active_effect(effect_visual)
		queue_redraw()


func _set_active_effect(effect: EffectVisual) -> void:
	active_effect = effect
	active_overlay = effect.get_custom_overlay()
	if active_overlay:
		active_overlay.initialize(active_clip, active_effect)


func _on_gui_input(event: InputEvent) -> void:
	if active_overlay:
		active_overlay.input(event, self)
		if event.is_canceled() or get_viewport().is_input_handled():
			return

	if event is InputEventMouseButton:
		var mouse_event: InputEventMouseButton = event
		if mouse_event.button_index == MOUSE_BUTTON_RIGHT:
			var popup: PopupMenu = PopupManager.create_menu()

			popup.add_item("Save screenshot ...", POPUP.SAVE_SCREENSHOT)
			popup.add_item("Save screenshot to project ...", POPUP.SAVE_SCREENSHOT_TO_PROJECT)
			popup.id_pressed.connect(_on_popup_id_pressed)
			PopupManager.show_menu(popup)

		elif mouse_event.ctrl_pressed:
			if mouse_event.button_index == MOUSE_BUTTON_WHEEL_UP:
				_zoom_view(1.05)
				accept_event()
			elif mouse_event.button_index == MOUSE_BUTTON_WHEEL_DOWN:
				_zoom_view(1.0 / 1.05)
				accept_event()


func _zoom_view(factor: float) -> void:
	view_zoom = clampf(view_zoom * factor, 0.1, 1.0)
	_update_transform()


func _draw() -> void:
	if view_zoom != 1.0:
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


func _on_popup_id_pressed(id: int) -> void:
	if id in [POPUP.SAVE_SCREENSHOT, POPUP.SAVE_SCREENSHOT_TO_PROJECT]:
		var file_dialog: FileDialog = PopupManager.create_file_dialog(
				"Save screenshot ...",
				FileDialog.FILE_MODE_SAVE_FILE,
				["*.webp", "*.png", "*.jpg", "*.jpeg"])

		if id == POPUP.SAVE_SCREENSHOT:
			file_dialog.file_selected.connect(_on_save_screenshot)
		else:
			file_dialog.file_selected.connect(_on_save_screenshot_to_project)

		var folder: String = Project.get_project_path().get_base_dir() + "/"
		var file_name: String = "image_%03d.webp"
		var nr: int = 1

		while true:
			if FileAccess.file_exists(folder + file_name % nr):
				nr += 1
			else:
				break

		file_dialog.current_path = folder + file_name % nr

		add_child(file_dialog)
		file_dialog.popup_centered()


func _on_save_screenshot_to_project(path: String) -> void:
	_on_save_screenshot(path)
	await FileLogic.dropped([path])


func _on_save_screenshot(path: String) -> void:
	var extension: String = path.get_extension()
	match extension:
		"png":
			if texture.get_image().save_png(path):
				printerr("ProjectViewTexture: Problem saving screenshot to system!")
		"webp":
			if texture.get_image().save_webp(path):
				printerr("ProjectViewTexture: Problem saving screenshot to system!")
		_: # JPG/JPEG
			if texture.get_image().save_jpg(path):
				printerr("ProjectViewTexture: Problem saving screenshot to system!")


func _update_safe_areas_button() -> void:
	if show_safe_areas:
		show_safe_areas_button.modulate = Color(1,1,1,1)
	else:
		show_safe_areas_button.modulate = Color(1,1,1,0.5)


func set_show_safe_areas(value: bool) -> void:
	show_safe_areas = value
	_update_safe_areas_button()
	queue_redraw()


func toggle_safe_areas() -> void:
	show_safe_areas = !show_safe_areas
