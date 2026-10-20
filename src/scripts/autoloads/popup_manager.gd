extends Node


enum {
	# Settings.
	EDITOR_SETTINGS,
	PROJECT_SETTINGS,
	MODULE_MANAGER,

	# File stuff.
	FILE_INFO,
	FILE_RENAME,
	FILE_OVERWRITE,

	FILES_MISSING,
	FILES_UPDATED,
	FILES_SHORTENED,

	# Folder stuff.
	FOLDER_RENAME,
	CREATE_FOLDER,

	# Render stuff.
	RENDER_FINISHED,
	RENDER_FAILED,

	# Timeline/clip stuff.
	MARKER,
	AUTO_CUT,
	ADD_EFFECTS,
	JUMP_TO_FRAME,
	CHANGE_CLIP_SPEED,
	DUPLICATION_ERROR,

	REPLACE_AUDIO,
	APPLY_REPLACE_AUDIO,

	# Start screen.
	STARTUP_SCREEN,
	WELCOME_SCREEN,
	SAVE_PROFILE_PRESET,
	SCAN_COMPLETE,

	# Workspace stuff.
	NEW_WORKSPACE,
	DELETE_WORKSPACE,

	# Extra popups.
	CREDITS,
	PROGRESS,
	COMMAND_BAR,
	COLOR_PICKER,
	}

var _open_popups: Dictionary [int, Control] = {}
var _popup_uids: Dictionary [int, String] = {
	# Settings.
	EDITOR_SETTINGS: "uid://dnhn66udpn7vp",
	PROJECT_SETTINGS: "uid://dnhn66udpn7vp",
	MODULE_MANAGER: "uid://bcu0coqxgk2do",

	# File stuff.
	FILE_INFO: "uid://w1n0m33ll8vp",
	FILE_RENAME: "uid://y450a2mtc4om",
	FILE_OVERWRITE: "uid://dvgpe8pybbyk5",

	FILES_MISSING: "uid://cay7444it7bqa",
	FILES_UPDATED: "uid://yym5tccggc88",
	FILES_SHORTENED: "uid://dwuk3bbyw16cp",

	# Folder stuff.
	CREATE_FOLDER: "uid://cyfsdm8w12mdq",
	FOLDER_RENAME: "uid://6f381g3j2gdd",

	# Render stuff.
	RENDER_FINISHED: "uid://b2p7khnqofboy",
	RENDER_FAILED: "uid://b46mlum2m65tv",

	# Timeline/clip stuff.
	MARKER: "uid://ce1hy5ks465h7",
	AUTO_CUT: "uid://td87gbksxsi3",
	ADD_EFFECTS: "uid://dqsbn4yb7nd0",
	JUMP_TO_FRAME: "uid://cfu334o2qox1a",
	CHANGE_CLIP_SPEED: "uid://cbbu6mhc0c3kj",
	DUPLICATION_ERROR: "uid://dvjs0g0dsgqxd",

	REPLACE_AUDIO: "uid://c3c08cihs1see",
	APPLY_REPLACE_AUDIO: "uid://nmdtjin0sdp5",

	# Start screen.
	STARTUP_SCREEN: "uid://bqlcn30hs8qp5",
	WELCOME_SCREEN: "uid://bdxuv18wukbj5",
	SAVE_PROFILE_PRESET: "uid://ccpft706e57gp",
	SCAN_COMPLETE: "uid://c50l3xlo6cawd",

	# Workspace stuff.
	NEW_WORKSPACE: "uid://xio6rtqr55wg",
	DELETE_WORKSPACE: "uid://b3n1tmr7pr8m4",

	# Extra popups.
	CREDITS: "uid://d4e5ndtm65ok3",
	PROGRESS: "uid://d4h7t8ccus0yv",
	COMMAND_BAR: "uid://rj2h8g761jr1",
	COLOR_PICKER: "uid://brbxvynl0y3ha",
	}

var control: Control = Control.new()



func _ready() -> void:
	get_window().size_changed.connect(_on_size_changed)

	await get_tree().root.ready
	get_tree().root.add_child(control)

	control.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	control.top_level = true
	_check_background()


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("ui_cancel") and not _open_popups.is_empty():
		if _open_popups.has(PROGRESS) and _open_popups.size() == 1: return
		close_all()
		get_viewport().set_input_as_handled()


func open(popup: int) -> void:
	if popup not in _open_popups:
		_open_popups[popup] = (load(_popup_uids[popup]) as PackedScene).instantiate()
		match popup:
			EDITOR_SETTINGS: _open_editor_settings(_open_popups[popup] as SettingsPanel)
			PROJECT_SETTINGS: _open_project_settings(_open_popups[popup] as SettingsPanel)

		control.add_child(_open_popups[popup])
		_check_background()


func _open_editor_settings(settings_panel: SettingsPanel) -> void:
	settings_panel.set_mode(SettingsPanel.Mode.EDITOR_SETTINGS)


func _open_project_settings(settings_panel: SettingsPanel) -> void:
	settings_panel.set_mode(SettingsPanel.Mode.PROJECT_SETTINGS)


func close(popup: int) -> void:
	if _open_popups.has(popup):
		_open_popups[popup].call_deferred("queue_free")
		if !_open_popups.erase(popup):
			printerr("PopupManager: Could not erase popup '%s' from open_popups!" % popup)
	get_viewport().set_input_as_handled()
	_check_background()


func close_all() -> void:
	for popup: int in _open_popups:
		_open_popups[popup].call_deferred("queue_free")
	_open_popups.clear()
	_check_background()


func get_popup(popup: int) -> Control:
	if !_open_popups.has(popup):
		open(popup)
	return _open_popups[popup]


func create_file_dialog(title: String, mode: FileDialog.FileMode, filters: Array[String] = []) -> FileDialog:
	var dialog: FileDialog = FileDialog.new()
	dialog.use_native_dialog = true
	dialog.title = title
	dialog.access = FileDialog.ACCESS_FILESYSTEM
	dialog.file_mode = mode
	if !filters.is_empty():
		dialog.filters = filters

	dialog.visibility_changed.connect(func() -> void: if not dialog.visible: dialog.call_deferred("queue_free"))
	return dialog


func create_menu(permanent: bool = false) -> PopupMenu:
	var popup: PopupMenu = PopupMenu.new()
	if !permanent:
		popup.popup_hide.connect(popup.queue_free)
	popup.size = Vector2i(100,0)
	popup.add_theme_constant_override("icon_max_width", 20)
	return popup


func show_menu(popup: PopupMenu) -> void:
	var mouse_pos: Vector2
	if !popup.is_embedded():
		mouse_pos = DisplayServer.mouse_get_position()
	else:
		mouse_pos = get_viewport().get_mouse_position()
	popup.position.x = int(mouse_pos.x)
	popup.position.y = int(mouse_pos.y + (popup.size.y / 2.0))
	add_child(popup)
	popup.popup()


#--- Helper functions ---

func _on_size_changed() -> void:
	control.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)


func _check_background() -> void:
	control.visible = !_open_popups.is_empty()
