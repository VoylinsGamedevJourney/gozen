extends HBoxContainer


@export var popup_menu_project: PopupMenu
@export var popup_menu_edit: PopupMenu
@export var popup_menu_view: PopupMenu
@export var popup_menu_preferences: PopupMenu
@export var popup_menu_help: PopupMenu



func _ready() -> void:
	@warning_ignore("return_value_discarded")
	Settings.on_show_menu_bar_changed.connect(_show_menu_bar)

	_show_menu_bar(Settings.get_show_menu_bar())
	_set_shortcuts()

	@warning_ignore("return_value_discarded")
	popup_menu_view.about_to_popup.connect(_on_view_menu_about_to_popup)


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
	@warning_ignore_start("return_value_discarded")
	match id:
		0: InputManager.undo_redo.undo()
		1: InputManager.undo_redo.redo()
	@warning_ignore_restore("return_value_discarded")


func _on_view_popup_menu_id_pressed(id: int) -> void:
	if id >= 5:
		var panel_names: Array = WorkspaceManager.active_panels.keys()
		if id - 5 < panel_names.size():
			var panel_id: String = panel_names[id - 5]
			WorkspaceManager.toggle_panel(panel_id)

	match id:
		0: WorkspaceManager.save_current_workspace()
		1: _create_new_workspace()
		3: WorkspaceManager.toggle_tab_titles()


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


func _create_new_workspace() -> void:
	var dialog: ConfirmationDialog = PopupManager.create_confirmation_dialog(tr("New workspace"), "")
	var line_edit: LineEdit = LineEdit.new()
	line_edit.placeholder_text = tr("Workspace name")
	dialog.add_child(line_edit)

	@warning_ignore("return_value_discarded")
	dialog.confirmed.connect(func() -> void:
			var workspace_name: String = line_edit.text.strip_edges().capitalize()
			if not workspace_name.is_empty():
				if not WorkspaceManager.available_workspaces.has(workspace_name):
					WorkspaceManager.create_workspace(workspace_name)
			dialog.queue_free())
	dialog.popup_centered(Vector2i(250, 80))
	line_edit.grab_focus()


func _on_view_menu_about_to_popup() -> void:
	const PANEL_ENTRIES_START: int = 5
	while popup_menu_view.item_count > PANEL_ENTRIES_START:
		popup_menu_view.remove_item(PANEL_ENTRIES_START)

	var title_item_idx: int = popup_menu_view.get_item_index(3)
	if WorkspaceManager.show_tab_titles:
		popup_menu_view.set_item_text(title_item_idx, tr("Hide panel titles"))
	else:
		popup_menu_view.set_item_text(title_item_idx, tr("Show panel titles"))

	var panel_names: Array = WorkspaceManager.active_panels.keys()
	for i: int in panel_names.size():
		var panel_name: String = panel_names[i]
		var panel: Control = WorkspaceManager.active_panels[panel_name]
		popup_menu_view.add_check_item(panel_name, PANEL_ENTRIES_START + i)
		popup_menu_view.set_item_checked(
				popup_menu_view.get_item_index(PANEL_ENTRIES_START + i),
				panel.is_inside_tree())
