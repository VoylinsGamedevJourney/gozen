extends HBoxContainer


@export var popup_menu_project: PopupMenu
@export var popup_menu_edit: PopupMenu
@export var popup_menu_preferences: PopupMenu
@export var popup_menu_help: PopupMenu



func _ready() -> void:
	Settings.on_show_menu_bar_changed.connect(_show_menu_bar)

	_show_menu_bar(Settings.get_show_menu_bar())
	_set_shortcuts()


func _show_menu_bar(value: bool) -> void:
	visible = value


func _open_about_gozen() -> void:
	PopupManager.open(PopupManager.CREDITS)


func _on_editor_screen_button_pressed() -> void:
	InputManager.show_editor_screen()


func _on_render_screen_button_pressed() -> void:
	InputManager.show_render_screen()


func _on_project_popup_menu_id_pressed(id: int) -> void:
	match id:
		0: Project.save()
		1: Project.save_as()
		# -------------
		3: Project.open_project()
		4: PopupManager.open(PopupManager.RECENT_PROJECTS)
		# -------------
		6: Project.open_settings_menu()
		# -------------
		8: get_tree().quit()


func _on_edit_popup_menu_id_pressed(id: int) -> void:
	match id:
		0: InputManager.undo_redo.undo()
		1: InputManager.undo_redo.redo()


func _on_preferences_popup_menu_id_pressed(id: int) -> void:
	match id:
		0: Settings.open_settings_menu()
		1: PopupManager.open(PopupManager.MODULE_MANAGER)
		# Line.
		3: PopupManager.open(PopupManager.COMMAND_BAR)


func _on_help_popup_menu_id_pressed(id: int) -> void:
	match id:
		0: Utils.open_url("support")
		1: PopupManager.open(PopupManager.VERSION_CHECK)
		# -------------
		3: Utils.open_url("manual")
		4: Utils.open_url("tutorials")
		5: Utils.open_url("discord")
		# -------------
		7: Utils.open_url("site")
		8: Utils.open_url("support")
		9: PopupManager.open(PopupManager.CREDITS)


func _set_shortcuts() -> void:
	# Project Menu Shortcuts.
	_set_menu_shortcut(popup_menu_project, 0, "save_project")
	_set_menu_shortcut(popup_menu_project, 1, "save_project_as")
	_set_menu_shortcut(popup_menu_project, 3, "open_project")
	_set_menu_shortcut(popup_menu_project, 6, "open_project_settings")
	# Edit Menu Shortcuts.
	_set_menu_shortcut(popup_menu_edit, 0, "ui_undo")
	_set_menu_shortcut(popup_menu_edit, 1, "ui_redo")
	# Preferences.
	_set_menu_shortcut(popup_menu_preferences, 0, "open_settings")
	_set_menu_shortcut(popup_menu_preferences, 3, "open_command_bar")
	# Help.
	_set_menu_shortcut(popup_menu_help, 9, "help")


func _set_menu_shortcut(popup: PopupMenu, item_index: int, action: String) -> void:
	var events: Array[InputEvent] = InputMap.action_get_events(action)
	var shortcut: Shortcut = Shortcut.new()
	var event: InputEventKey = events[0].duplicate()
	# To remove the "- physical" we need to change the keycode :/
	event.keycode = event.keycode if event.keycode != KEY_NONE else event.physical_keycode
	shortcut.events = [event]
	popup.set_item_shortcut(item_index, shortcut, true)
