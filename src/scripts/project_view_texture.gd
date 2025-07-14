extends TextureRect

enum POPUP { SAVE_SCREENSHOT, SAVE_SCREENSHOT_TO_PROJECT }


func _ready() -> void:
	Toolbox.connect_func(gui_input, _on_gui_input)

	if EditorCore.viewport != null:
		texture = EditorCore.viewport.get_texture()
	else:
		printerr("Couldn't get viewport texture from EditorCore!")


func _on_gui_input(event: InputEvent) -> void:
	if event is InputEventMouseButton:
		var mouse_event: InputEventMouseButton = event

		if mouse_event.button_index == MOUSE_BUTTON_RIGHT:
			var popup: PopupMenu = Toolbox.get_popup()

			popup.add_item("Save screenshot ...", POPUP.SAVE_SCREENSHOT)
			popup.add_item("Save screenshot to project ...", POPUP.SAVE_SCREENSHOT_TO_PROJECT)

			Toolbox.connect_func(popup.id_pressed, _on_popup_id_pressed)

			Toolbox.show_popup(popup)


func _on_popup_id_pressed(id: int) -> void:
	if id in [POPUP.SAVE_SCREENSHOT, POPUP.SAVE_SCREENSHOT_TO_PROJECT]:
		var file_dialog: FileDialog = Toolbox.get_file_dialog(
				"Save screenshot ...",
				FileDialog.FILE_MODE_SAVE_FILE,
				["*.webp", "*.png", "*.jpg", "*.jpeg"])

		if id == POPUP.SAVE_SCREENSHOT:
			Toolbox.connect_func(file_dialog.file_selected, _on_save_screenshot)
		else:
			Toolbox.connect_func(file_dialog.file_selected, _on_save_screenshot_to_project)

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
	Project._on_files_dropped([path])


func _on_save_screenshot(path: String) -> void:
	var extension: String = path.get_extension()

	# TODO: Maybe have settings for quality/lossy in editor settings for this.
	match extension:
		"png":
			if texture.get_image().save_png(path):
				printerr("Problem saving screenshot to system!")
		"webp":
			if texture.get_image().save_webp(path):
				printerr("Problem saving screenshot to system!")
		_: # JPG/JPEG
			if texture.get_image().save_jpg(path):
				printerr("Problem saving screenshot to system!")
