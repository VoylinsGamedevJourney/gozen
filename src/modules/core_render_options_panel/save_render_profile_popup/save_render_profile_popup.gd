extends Control


@export var name_line_edit: LineEdit
@export var icon_preview_button: TextureButton
@export var reset_icon_button: Button


var callback: Callable
var _icon_path: String = Library.ICON_CUSTOM_RENDER_PROFILE
var _active_file_dialog: FileDialog = null



func set_data(function: Callable) -> void:
	callback = function
	_reset_icon()
	name_line_edit.text = ""
	name_line_edit.grab_focus()


#--- Input handling ---

func _input(event: InputEvent) -> void:
	if _active_file_dialog != null:
		return
	if event.is_action_pressed("ui_cancel", false, true):
		_on_cancel_button_pressed()
		get_viewport().set_input_as_handled()


func _gui_input(event: InputEvent) -> void:
	if _active_file_dialog != null:
		return
	if event is InputEventMouseButton:
		var mouse_event: InputEventMouseButton = event as InputEventMouseButton
		if mouse_event.pressed and mouse_event.button_index == MouseButton.MOUSE_BUTTON_LEFT:
			_on_cancel_button_pressed()


#--- Button handling ---

func _on_name_line_edit_text_submitted(_new_text: String) -> void:
	_on_save_render_profile_button_pressed()


func _on_select_icon_button_pressed() -> void:
	if _active_file_dialog != null:
		return

	var dialog: FileDialog = PopupManager.create_file_dialog(
			tr("Select profile icon ..."),
			FileDialog.FILE_MODE_OPEN_FILE,
			["*.png,*.jpg,*.jpeg,*.webp,*.svg;" + tr("Image files")])
	dialog.current_dir = Project.get_picker_path(OS.SYSTEM_DIR_PICTURES)
	_active_file_dialog = dialog

	dialog.file_selected.connect(func(selected_path: String) -> void:
			_clear_active_file_dialog.call_deferred(dialog)
			var image: Image = Image.load_from_file(selected_path)
			if image and not image.is_empty():
				_icon_path = selected_path
				icon_preview_button.texture_normal = ImageTexture.create_from_image(image)
				reset_icon_button.visible = true)
	dialog.canceled.connect(_clear_active_file_dialog.bind(dialog), CONNECT_DEFERRED)
	dialog.visibility_changed.connect(func() -> void:
			if not dialog.visible:
				_clear_active_file_dialog.call_deferred(dialog))

	add_child(dialog)
	dialog.popup_centered()


func _on_reset_icon_button_pressed() -> void:
	_reset_icon()


func _on_save_render_profile_button_pressed() -> void:
	var profile_name: String = name_line_edit.text.strip_edges()
	if profile_name.is_empty():
		profile_name = "Custom"

	var pending_callback: Callable = callback
	var selected_icon_path: String = _icon_path
	PopupManager.close(PopupManager.RENDER_PROFILE_SAVE_CUSTOM)
	if pending_callback.is_valid():
		pending_callback.call(profile_name, selected_icon_path)


func _on_cancel_button_pressed() -> void:
	PopupManager.close(PopupManager.RENDER_PROFILE_SAVE_CUSTOM)


func _reset_icon() -> void:
	_icon_path = Library.ICON_CUSTOM_RENDER_PROFILE
	icon_preview_button.texture_normal = load(_icon_path) as Texture2D
	reset_icon_button.visible = false


func _clear_active_file_dialog(dialog: FileDialog) -> void:
	if _active_file_dialog == dialog:
		_active_file_dialog = null
