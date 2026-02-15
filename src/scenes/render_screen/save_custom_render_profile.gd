extends ConfirmationDialog

signal save_profile(name: String, icon_path: String)


@export var line_edit_profile_name: LineEdit
@export var texture_button_icon: TextureButton


var selected_icon_path: String = Library.ICON_CUSTOM_RENDER_PROFILE: set = _set_icon



func _ready() -> void:
	line_edit_profile_name.select_all()
	line_edit_profile_name.grab_focus()


func _connect_save_profile(function: Callable) -> void:
	var _err: int = save_profile.connect(function)


func _set_icon(path: String) -> void:
	if !FileAccess.file_exists(path):
		path = Library.ICON_CUSTOM_RENDER_PROFILE
	texture_button_icon.texture_normal = Image.load_from_file(path).texture
	selected_icon_path = path


func _on_profile_icon_button_pressed() -> void:
	var dialog: FileDialog = PopupManager.create_file_dialog(
			tr("Select Icon"),
			FileDialog.FILE_MODE_OPEN_FILE,
			["*.svg", "*.png", "*.jpg", "*.jpeg", "*.webp"])
	dialog.file_selected.connect(_on_icon_file_selected)
	add_child(dialog)
	dialog.popup_centered()


func _on_icon_file_selected(path: String) -> void:
	selected_icon_path = path


func _on_confirmed() -> void:
	var profile_name: String = line_edit_profile_name.text
	if profile_name.is_empty():
		profile_name = "Custom profile"
	save_profile.emit(profile_name, selected_icon_path)
