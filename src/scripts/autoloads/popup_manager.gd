extends Node

enum {
	SETTINGS,
	PROJECT_SETTINGS,
	CREDITS,
	COLOR,
	MARKER,
	PROGRESS,
	COMMAND_BAR,
	MODULE_MANAGER,
	RECENT_PROJECTS,
	ADD_EFFECTS,
	REPLACE_AUDIO,
	WELCOME,
	AUTO_CUT }


var _open_popups: Dictionary [int, Control] = {}
var _popup_uids: Dictionary [int, String] = {
	SETTINGS: "uid://dnhn66udpn7vp",
	PROJECT_SETTINGS: "uid://dnhn66udpn7vp",
	CREDITS: "uid://d4e5ndtm65ok3",
	COLOR: "uid://brbxvynl0y3ha",
	MARKER: "uid://ce1hy5ks465h7",
	PROGRESS: "uid://d4h7t8ccus0yv",
	COMMAND_BAR: "uid://rj2h8g761jr1",
	MODULE_MANAGER: "uid://bcu0coqxgk2do",
	RECENT_PROJECTS: "", # TODO
	ADD_EFFECTS: "uid://dqsbn4yb7nd0",
	REPLACE_AUDIO: "uid://c3c08cihs1see",
	WELCOME: "uid://bdxuv18wukbj5",
	AUTO_CUT: "uid://td87gbksxsi3" }

var _control: Control = Control.new()
var _background: PanelContainer = (load("uid://xu8ndgud6cox") as PackedScene).instantiate()



func _ready() -> void:
	@warning_ignore("return_value_discarded")
	get_window().size_changed.connect(_on_size_changed)

	await get_tree().root.ready
	get_tree().root.add_child(_control)
	_control.add_child(_background)
	_control.visible = false
	_control.top_level = true
	_control.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("ui_cancel") and not _open_popups.is_empty():
		if _open_popups.has(PROGRESS) and _open_popups.size() == 1: return
		close_all()
		get_viewport().set_input_as_handled()


func open(popup: int) -> void:
	if popup in _open_popups: return

	_open_popups[popup] = (load(_popup_uids[popup]) as PackedScene).instantiate()
	match popup:
		SETTINGS: _open_editor_settings(_open_popups[popup] as SettingsPanel)
		PROJECT_SETTINGS: _open_project_settings(_open_popups[popup] as SettingsPanel)

	_control.add_child(_open_popups[popup])
	_control.visible = true


func _open_editor_settings(settings_panel: SettingsPanel) -> void:
	settings_panel.set_mode(SettingsPanel.Mode.EDITOR_SETTINGS)


func _open_project_settings(settings_panel: SettingsPanel) -> void:
	settings_panel.set_mode(SettingsPanel.Mode.PROJECT_SETTINGS)


func close(popup: int) -> void:
	if _open_popups.has(popup):
		_open_popups[popup].queue_free()
		if !_open_popups.erase(popup):
			printerr("PopupManager: Could not erase popup '%s' from open_popups!" % popup)
	get_viewport().set_input_as_handled()
	_check_background()


func close_all() -> void:
	for popup: int in _open_popups:
		_open_popups[popup].queue_free()
	_open_popups.clear()
	_check_background()


func get_popup(popup: int) -> Control:
	if !_open_popups.has(popup):
		open(popup)
	return _open_popups[popup]


func create_file_dialog(title: String, mode: FileDialog.FileMode, filters: Array[String] = []) -> FileDialog:
	var dialog: FileDialog = FileDialog.new()
	var use_native_dialog: bool = Settings.get_use_native_dialog()

	dialog.force_native = use_native_dialog
	dialog.use_native_dialog = use_native_dialog
	dialog.title = title
	dialog.access = FileDialog.ACCESS_FILESYSTEM
	dialog.file_mode = mode
	dialog.filters = filters

	@warning_ignore("return_value_discarded")
	dialog.visibility_changed.connect(func() -> void: if not dialog.visible: dialog.queue_free())
	return dialog


func create_accept_dialog(title: String) -> AcceptDialog:
	var dialog: AcceptDialog = AcceptDialog.new()
	var use_native_dialog: bool = Settings.get_use_native_dialog()

	dialog.force_native = use_native_dialog
	dialog.title = title

	@warning_ignore("return_value_discarded")
	dialog.visibility_changed.connect(func() -> void: if not dialog.visible: dialog.queue_free())
	return dialog


func create_confirmation_dialog(title: String, text: String) -> ConfirmationDialog:
	var dialog: ConfirmationDialog = ConfirmationDialog.new()
	var use_native_dialog: bool = Settings.get_use_native_dialog()

	dialog.force_native = use_native_dialog
	dialog.title = title
	dialog.dialog_text = text

	@warning_ignore("return_value_discarded")
	dialog.visibility_changed.connect(func() -> void: if not dialog.visible: dialog.queue_free())
	_control.add_child(dialog)
	return dialog


func create_menu(permanent: bool = false) -> PopupMenu:
	var popup: PopupMenu = PopupMenu.new()
	if !permanent:
		@warning_ignore("return_value_discarded")
		popup.popup_hide.connect(popup.queue_free)
	popup.size = Vector2i(100,0)
	popup.add_theme_constant_override("icon_max_width", 20)
	return popup


func show_menu(popup: PopupMenu) -> void:
	var mouse_pos: Vector2 = get_viewport().get_mouse_position()
	popup.position.x = int(mouse_pos.x)
	popup.position.y = int(mouse_pos.y + (popup.size.y / 2.0))
	add_child(popup)
	popup.popup()


#--- Helper functions ---

func _on_size_changed() -> void:
	_control.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)


func _check_background() -> void:
	_control.visible = !_open_popups.is_empty()
