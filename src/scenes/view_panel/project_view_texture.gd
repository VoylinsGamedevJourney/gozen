extends TextureRect


enum POPUP { SAVE_SCREENSHOT, SAVE_SCREENSHOT_TO_PROJECT }


const SIZE_CROSS: int = 20


@export var show_safe_areas_button: TextureButton


var show_safe_areas: bool = true: set = set_show_safe_areas



func _ready() -> void:
	gui_input.connect(_on_gui_input)

	if EditorCore.viewport != null:
		texture = EditorCore.viewport.get_texture()
	else:
		printerr("ProjectViewTexture: Couldn't get viewport texture from EditorCore!")

	_update_safe_areas_button()


func _on_gui_input(event: InputEvent) -> void:
	if event is InputEventMouseButton:
		var mouse_event: InputEventMouseButton = event

		if mouse_event.button_index == MOUSE_BUTTON_RIGHT:
			var popup: PopupMenu = PopupManager.create_popup_menu()

			popup.add_item("Save screenshot ...", POPUP.SAVE_SCREENSHOT)
			popup.add_item("Save screenshot to project ...", POPUP.SAVE_SCREENSHOT_TO_PROJECT)

			popup.id_pressed.connect(_on_popup_id_pressed)

			PopupManager.show_popup_menu(popup)


func _draw() -> void:
	if not show_safe_areas:
		return

	# Calculate the ratio and apply
	var width: float = Project.data.resolution.x / (Project.data.resolution.y / size.y)
	var height: float = Project.data.resolution.y / (Project.data.resolution.x / size.x)
	var h_ratio: float = max(0, (size.y - height) / 2)
	var w_ratio: float = max(0, (size.x - width) / 2)
	var view_rect: Rect2 = Rect2(
			0.0 if w_ratio == 0 else w_ratio, 0.0 if h_ratio == 0 else h_ratio,
			width if h_ratio == 0 else size.x, height if w_ratio == 0 else size.y)
	var center: Vector2i = view_rect.get_center()
	var color: Color = Color(1, 1, 1, 0.4)

	var first_border: Rect2 = view_rect.grow(-view_rect.size.x * 0.05)
	var second_border: Rect2 = view_rect.grow(-view_rect.size.x * 0.10)

	# Drawing borders
	draw_rect(first_border, color, false, 1.0)
	draw_rect(second_border, color, false, 1.0)

	# Drawing center cross
	draw_line(Vector2(center.x - SIZE_CROSS, center.y), Vector2(center.x + SIZE_CROSS, center.y), color, 1.0)
	draw_line(Vector2(center.x, center.y - SIZE_CROSS), Vector2(center.x, center.y + SIZE_CROSS), color, 1.0)


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
	FileHandler.files_dropped([path])


func _on_save_screenshot(path: String) -> void:
	var extension: String = path.get_extension()

	# TODO: Maybe have settings for quality/lossy in editor settings for this.
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

