extends Node


enum POPUP {
	SETTINGS,
	PROJECT_SETTINGS,
	CREDITS,
	COLOR,
	MARKER,
	PROGRESS,
	COMMAND_BAR,
	MODULE_MANAGER,
	VERSION_CHECK,
	RECENT_PROJECTS,
	ADD_EFFECTS,
	AUDIO_TAKE_OVER,
}


var _open_popups: Dictionary [POPUP, Control] = {}
var _popup_uids: Dictionary [POPUP, String] = {
	POPUP.SETTINGS: Library.SCENE_SETTINGS,
	POPUP.PROJECT_SETTINGS: Library.SCENE_SETTINGS,
	POPUP.CREDITS: Library.SCENE_ABOUT_GOZEN,
	POPUP.COLOR: Library.SCENE_COLOR_PICKER_DIALOG,
	POPUP.MARKER: Library.SCENE_MARKER_DIALOG,
	POPUP.PROGRESS: Library.SCENE_PROGRESS_OVERLAY,
	POPUP.COMMAND_BAR: Library.SCENE_COMMAND_BAR,
	POPUP.MODULE_MANAGER: Library.SCENE_MODULE_MANAGER,
	POPUP.VERSION_CHECK: Library.SCENE_VERSION_CHECK,
	POPUP.RECENT_PROJECTS: Library.SCENE_RECENT_PROJECTS,
	POPUP.ADD_EFFECTS: Library.SCENE_ADD_EFFECTS,
	POPUP.AUDIO_TAKE_OVER: Library.SCENE_AUDIO_TAKE_OVER,
}
var _control: Control = Control.new()
var _background: PanelContainer = preload(Library.SCENE_POPUP_BACKGROUND).instantiate()



func _ready() -> void:
	get_window().size_changed.connect(_on_size_changed)

	await get_tree().root.ready
	get_tree().root.add_child(_control)
	_control.add_child(_background)
	_control.visible = false
	_control.top_level = true
	_control.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)


func open_popup(popup: POPUP) -> void:
	if popup in _open_popups: return

	_open_popups[popup] = (load(_popup_uids[popup]) as PackedScene).instantiate()
	match popup:
		POPUP.SETTINGS: _open_editor_settings(_open_popups[popup] as SettingsPanel)
		POPUP.PROJECT_SETTINGS: _open_project_settings(_open_popups[popup] as SettingsPanel)

	_control.add_child(_open_popups[popup])
	_control.visible = true


func _open_editor_settings(settings_panel: SettingsPanel) -> void:
	settings_panel.set_mode(SettingsPanel.MODE.EDITOR_SETTINGS)


func _open_project_settings(settings_panel: SettingsPanel) -> void:
	settings_panel.set_mode(SettingsPanel.MODE.PROJECT_SETTINGS)


func close_popup(popup: POPUP) -> void:
	if _open_popups.has(popup):
		_open_popups[popup].queue_free()

		if !_open_popups.erase(popup):
			printerr("PopupManager: Could not erase popup '%s' from open_popups!" % popup)

	_check_background()


func close_popups() -> void:
	for popup: POPUP in _open_popups:
		_open_popups[popup].queue_free()

	_open_popups.clear()
	_check_background()


func get_popup(popup: POPUP) -> Control:
	if !_open_popups.has(popup):
		open_popup(popup)
	return _open_popups[popup]


func create_file_dialog(title: String, mode: FileDialog.FileMode, filters: PackedStringArray = []) -> FileDialog:
	var dialog: FileDialog = FileDialog.new()
	var use_native_dialog: bool = Settings.get_use_native_dialog()

	dialog.force_native = use_native_dialog
	dialog.use_native_dialog = use_native_dialog
	dialog.title = title
	dialog.access = FileDialog.ACCESS_FILESYSTEM
	dialog.file_mode = mode
	dialog.filters = filters

	return dialog


func create_accept_dialog(title: String) -> AcceptDialog:
	var dialog: AcceptDialog = AcceptDialog.new()
	var use_native_dialog: bool = Settings.get_use_native_dialog()

	dialog.force_native = use_native_dialog
	dialog.title = title

	return dialog


func create_popup_menu(permanent: bool = false) -> PopupMenu:
	var popup: PopupMenu = PopupMenu.new()

	if !permanent:
		popup.mouse_exited.connect(popup.queue_free)

	popup.size = Vector2i(100,0)
	return popup


func show_popup_menu(popup: PopupMenu) -> void:
	var mouse_pos: Vector2 = get_viewport().get_mouse_position()

	popup.position.x = int(mouse_pos.x)
	popup.position.y = int(mouse_pos.y + (popup.size.y / 2.0))

	add_child(popup)
	popup.popup()


# Private functions
func _on_size_changed() -> void:
	_control.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)


func _check_background() -> void:
	_control.visible = _open_popups.size() != 0
