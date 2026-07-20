class_name EditorUI
extends Control

static var instance: EditorUI


@export var menu_bar: MenuBar

@export var workspaces: TabContainer
@export var workspace_buttons_hbox: HBoxContainer


# Workspace variables
var workspace_buttons: Array[Button] = []
var workspace_button_group: ButtonGroup = ButtonGroup.new()



func _ready() -> void:
	instance = self

	# Printing startup info.
	Print.header_editor("--==  GoZen - Video Editor  ==--")
	for info_print: PackedStringArray in [
			["GoZen Version", ProjectSettings.get_setting("application/config/version")],
			["OS", OS.get_model_name()],
			["OS Version", OS.get_version()],
			["Distribution", OS.get_distribution_name()],
			["Processor", OS.get_processor_name()],
			["Threads", OS.get_processor_count()],
			["Ram", "\n\tTotal: %s GB\n\tAvailable: %s GB" % [
				str("%0.2f" % (OS.get_memory_info().physical/1_073_741_824)),
				str("%0.2f" % (OS.get_memory_info().available/1_073_741_824))]],
			["Video adapter", "\n\tName: %s\n\tVersion: %s\n\tType: %s" % [
				RenderingServer.get_video_adapter_name(),
				RenderingServer.get_video_adapter_api_version(),
				RenderingServer.get_video_adapter_type()]],
			["Locale", OS.get_locale()],
			["Startup args", OS.get_cmdline_args()]]:
		Print.info_editor(info_print[0], info_print[1])
	Print.header_editor("--==--================--==--")

	@warning_ignore_start("return_value_discarded")
	InputManager.on_show_editor_workspace.connect(switch_workspace.bind(0))
	InputManager.on_show_render_workspace.connect(switch_workspace.bind(1))
	InputManager.on_switch_workspace.connect(switch_workspace_quick)
	WorkspaceManager.workspace_added.connect(_on_workspace_added)
	Settings.on_show_menu_bar_changed.connect(func(value: bool) -> void: menu_bar.visible = value)
	@warning_ignore_restore("return_value_discarded")

	# Populate workspaces + buttons.
	for workspace_name: String in WorkspaceManager.available_workspaces:
		_add_workspace_tab(workspace_name)

	# Create menu buttons.
	_create_project_popup_menu()
	_create_edit_popup_menu()
	_create_view_popup_menu()
	_create_preferences_popup_menu()
	_create_help_popup_menu()

	Settings.on_show_menu_bar_changed.emit(Settings.get_show_menu_bar())

	switch_workspace(0)
	PhysicsServer2D.set_active(false)
	PhysicsServer3D.set_active(false)

	# Check if editor got opened with a project path as argument.
	for arg: String in OS.get_cmdline_args():
		if arg.to_lower().ends_with(Project.EXTENSION):
			await Project.open(arg)
			return
	add_child(preload(Library.SCENE_STARTUP).instantiate())


# --- Menu bar functions ---

func _create_project_popup_menu() -> void:
	var menu: PopupMenu = PopupMenu.new()
	menu_bar.add_child(menu)

	menu.title = "Project"
	menu.add_theme_constant_override("icon_max_width", 20)

	menu.add_icon_item(preload(Library.ICON_FILE_VIDEO), "Save project", 0)
	menu.add_icon_item(preload(Library.ICON_FILE_VIDEO), "Save project as ...", 1)
	menu.add_separator()
	menu.add_icon_item(preload(Library.ICON_OPEN), "Open project", 2)
	menu.add_icon_item(preload(Library.ICON_OPEN), "Recent projects", 3)
	menu.add_separator()
	menu.add_icon_item(preload(Library.ICON_PROJECT_SETTINGS), "Project settings", 4)
	menu.add_icon_item(preload(Library.ICON_CLOSE), "Quit", 5)

	@warning_ignore("return_value_discarded")
	menu.id_pressed.connect(_on_project_popup_menu_id_pressed)


func _on_project_popup_menu_id_pressed(id: int) -> void:
	match id:
		0: Project.save()
		1: Project.save_as()
		# -------------
		2: Project.open_project()
		3: PopupManager.open(PopupManager.RECENT_PROJECTS)
		# -------------
		4: Project.open_settings_menu()
		5: get_tree().quit()


func _create_edit_popup_menu() -> void:
	var menu: PopupMenu = PopupMenu.new()
	menu_bar.add_child(menu)

	menu.title = "Edit"
	menu.add_theme_constant_override("icon_max_width", 20)

	menu.add_item("Undo", 0)
	menu.add_item("Redo", 1)

	@warning_ignore("return_value_discarded")
	menu.id_pressed.connect(_on_edit_popup_menu_id_pressed)


func _on_edit_popup_menu_id_pressed(id: int) -> void:
	@warning_ignore_start("return_value_discarded")
	match id:
		0: InputManager.undo_redo.undo()
		1: InputManager.undo_redo.redo()
	@warning_ignore_restore("return_value_discarded")


func _create_view_popup_menu() -> void:
	var menu: PopupMenu = PopupMenu.new()
	menu_bar.add_child(menu)

	menu.title = "View"
	menu.add_theme_constant_override("icon_max_width", 20)

	menu.add_item("Save workspace", 0)
	menu.add_item("New workspace", 1)
	menu.add_separator("", 2)
	menu.add_item("Show panel titles", 3)
	menu.add_separator("Panels", 4)

	@warning_ignore_start("return_value_discarded")
	menu.about_to_popup.connect(_on_view_popup_menu_about_to_popup.bind(menu))
	menu.id_pressed.connect(_on_view_popup_menu_id_pressed)
	@warning_ignore_restore("return_value_discarded")


func _on_view_popup_menu_about_to_popup(menu: PopupMenu) -> void:
	const PANEL_ENTRIES_START: int = 5
	while menu.item_count > PANEL_ENTRIES_START:
		menu.remove_item(PANEL_ENTRIES_START)

	var title_item_idx: int = menu.get_item_index(3)
	if WorkspaceManager.show_tab_titles:
		menu.set_item_text(title_item_idx, tr("Hide panel titles"))
	else:
		menu.set_item_text(title_item_idx, tr("Show panel titles"))

	var panel_names: Array = WorkspaceManager.active_panels.keys()
	for i: int in panel_names.size():
		var panel_name: String = panel_names[i]
		var panel: Control = WorkspaceManager.active_panels[panel_name]
		menu.add_check_item(panel_name, PANEL_ENTRIES_START + i)
		menu.set_item_checked(
				menu.get_item_index(PANEL_ENTRIES_START + i),
				panel.is_inside_tree())


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


func _create_preferences_popup_menu() -> void:
	var menu: PopupMenu = PopupMenu.new()
	menu_bar.add_child(menu)

	menu.title = "Preferences"
	menu.add_theme_constant_override("icon_max_width", 20)

	menu.add_icon_item(preload(Library.ICON_EDITOR_SETTINGS), "Editor settings", 0)
	menu.add_icon_item(preload(Library.ICON_MODULE_MANAGER), "Module manager", 1)
	menu.add_separator()
	menu.add_icon_item(preload(Library.ICON_COMMAND_PROMPT), "Command bar", 2)

	@warning_ignore("return_value_discarded")
	menu.id_pressed.connect(_on_preferences_popup_menu_id_pressed)


func _on_preferences_popup_menu_id_pressed(id: int) -> void:
	match id:
		0: Settings.open_settings_menu()
		1: PopupManager.open(PopupManager.MODULE_MANAGER)
		# Line.
		3: PopupManager.open(PopupManager.COMMAND_BAR)


func _create_help_popup_menu() -> void:
	var menu: PopupMenu = PopupMenu.new()
	menu_bar.add_child(menu)

	menu.title = "Help"
	menu.add_theme_constant_override("icon_max_width", 20)

	menu.add_icon_item(preload(Library.ICON_BUG), "Report bug", 0)
	menu.add_icon_item(preload(Library.ICON_MANUAL), "Manual", 1)
	menu.add_icon_item(preload(Library.ICON_TUTORIALS), "Tutorials", 2)
	menu.add_icon_item(preload(Library.ICON_LINK), "Discord", 3)
	menu.add_separator()
	menu.add_icon_item(preload(Library.ICON_LINK), "Website", 4)
	menu.add_icon_item(preload(Library.ICON_SUPPORT), "Support GoZen", 5)
	menu.add_icon_item(preload(Library.ICON_GOZEN), "About GoZen", 6)

	@warning_ignore("return_value_discarded")
	menu.id_pressed.connect(_on_preferences_popup_menu_id_pressed)

func _on_help_popup_menu_id_pressed(id: int) -> void:
	match id:
		0: Utils.open_url("support")
		1: Utils.open_url("manual")
		2: Utils.open_url("tutorials")
		3: Utils.open_url("discord")
		# -------------
		4: Utils.open_url("site")
		5: Utils.open_url("support")
		6: PopupManager.open(PopupManager.CREDITS)


func _create_new_workspace() -> void:
	var dialog: ConfirmationDialog = PopupManager.create_confirmation_dialog(tr("New workspace"), "")
	var line_edit: LineEdit = LineEdit.new()
	line_edit.placeholder_text = tr("Workspace name")
	dialog.add_child(line_edit)

	@warning_ignore("return_value_discarded")
	dialog.confirmed.connect(_on_create_new_workspace_confirmed.bind(dialog, line_edit))
	dialog.popup_centered(Vector2i(250, 80))
	line_edit.grab_focus()


func _on_create_new_workspace_confirmed(dialog: ConfirmationDialog, line_edit: LineEdit) -> void:
	var workspace_name: String = line_edit.text.strip_edges().capitalize()
	if not workspace_name.is_empty() and not WorkspaceManager.available_workspaces.has(workspace_name):
		WorkspaceManager.create_workspace(workspace_name)
	dialog.queue_free()


# --- Workspace functions ---

func _add_workspace_tab(workspace_name: String) -> void:
	var tab: Control = Control.new()
	tab.name = workspace_name
	workspaces.add_child(tab)

	var button: Button = Button.new()
	button.text = workspace_name
	button.theme_type_variation = "workspace_button"
	button.toggle_mode = true
	button.button_group = workspace_button_group

	@warning_ignore_start("return_value_discarded")
	button.pressed.connect(_on_add_workspace_tab_button_pressed.bind(button))
	button.gui_input.connect(_on_add_workspace_tab_gui_input.bind(workspace_name, button))
	@warning_ignore_restore("return_value_discarded")

	workspace_buttons_hbox.add_child(button)
	workspace_buttons.append(button)


func _on_add_workspace_tab_button_pressed(button: Button) -> void:
	var index: int = workspace_buttons.find(button)
	if index != -1: switch_workspace(index)


func _on_add_workspace_tab_gui_input(event: InputEvent, workspace_name: String, button: Button) -> void:
	if event is not InputEventMouseButton: return

	var input_event: InputEventMouseButton = event
	if input_event.pressed and input_event.button_index == MOUSE_BUTTON_RIGHT:
		_show_workspace_context_menu(workspace_name, button)


func _on_workspace_added(workspace_name: String) -> void:
	_add_workspace_tab(workspace_name)
	switch_workspace(workspace_buttons.size() - 1)


func _show_workspace_context_menu(workspace_name: String, button: Button) -> void:
	var popup: PopupMenu = PopupManager.create_menu()
	var index: int = workspace_buttons.find(button)

	popup.add_item(tr("Move Left"), 0)
	if index == 0: popup.set_item_disabled(0, true)

	popup.add_item(tr("Move Right"), 1)
	if index == workspace_buttons.size() - 1: popup.set_item_disabled(1, true)

	popup.add_item(tr("Delete"), 2)
	if workspace_buttons.size() <= 1: popup.set_item_disabled(2, true)

	@warning_ignore("return_value_discarded")
	popup.id_pressed.connect(func(id: int) -> void:
			match id:
				0: _move_workspace(workspace_name, -1)
				1: _move_workspace(workspace_name, 1)
				2: _delete_workspace_prompt(workspace_name)
	)
	PopupManager.show_menu(popup)


func _move_workspace(workspace_name: String, direction: int) -> void:
	var current_idx: int = -1
	for i: int in workspace_buttons.size():
		if workspace_buttons[i].text == workspace_name:
			current_idx = i
			break
	if current_idx == -1: return

	var target_idx: int = current_idx + direction
	if target_idx < 0 or target_idx >= workspace_buttons.size(): return

	var name_a: String = WorkspaceManager.available_workspaces[current_idx]
	var name_b: String = WorkspaceManager.available_workspaces[target_idx]
	WorkspaceManager.available_workspaces[current_idx] = name_b
	WorkspaceManager.available_workspaces[target_idx] = name_a

	var button_a: Button = workspace_buttons[current_idx]
	var button_b: Button = workspace_buttons[target_idx]
	workspace_buttons[current_idx] = button_b
	workspace_buttons[target_idx] = button_a

	workspace_buttons_hbox.move_child(button_a, target_idx)

	var tab_a: Node = workspaces.get_child(current_idx)
	workspaces.move_child(tab_a, target_idx)

	if button_a.button_pressed:
		switch_workspace(target_idx)
	elif button_b.button_pressed:
		switch_workspace(current_idx)


func _delete_workspace_prompt(workspace_name: String) -> void:
	var dialog: ConfirmationDialog = PopupManager.create_confirmation_dialog(
			tr("Delete Workspace"),
			tr("Are you sure you want to delete the workspace '%s'?") % workspace_name)
	@warning_ignore("return_value_discarded")
	dialog.confirmed.connect(func() -> void: _delete_workspace(workspace_name))
	dialog.popup_centered()


func _delete_workspace(workspace_name: String) -> void:
	var current_idx: int = -1
	for i: int in workspace_buttons.size():
		if workspace_buttons[i].text == workspace_name:
			current_idx = i
			break

	var file_name: String = workspace_name.to_lower().replace(" ", "_") + ".tres"
	var path: String = WorkspaceManager.WORKSPACES_DIR + file_name
	if FileAccess.file_exists(path):
		var err: Error = DirAccess.remove_absolute(path)
		if err != OK:
			printerr("Editor: Failed to delete workspace file at '%s'!" % path)

	var button_to_delete: Button = workspace_buttons[current_idx]
	if button_to_delete.button_pressed:
		var target_idx: int = 0
		if current_idx == 0:
			target_idx = 1
		switch_workspace(target_idx)

	WorkspaceManager.available_workspaces.erase(workspace_name)

	var tab: Node = workspaces.get_child(current_idx)
	workspaces.remove_child(tab)
	tab.queue_free()
	workspace_buttons_hbox.remove_child(button_to_delete)
	button_to_delete.queue_free()
	workspace_buttons.remove_at(current_idx)


func switch_workspace(index: int) -> void:
	if RenderManager.encoder == null or !RenderManager.encoder.is_open():
		if index >= 0 and index < workspace_buttons.size():
			workspaces.current_tab = index
			workspace_buttons[index].button_pressed = true
			WorkspaceManager.workspace_root = workspaces.get_child(index)
			WorkspaceManager.load_workspace(workspace_buttons[index].text)


func switch_workspace_quick() -> void:
	if RenderManager.encoder == null or !RenderManager.encoder.is_open():
		var next_index: int = 0
		for i: int in workspace_buttons.size():
			if workspace_buttons[i].button_pressed:
				next_index = (i + 1) % workspace_buttons.size()
				break
		switch_workspace(next_index)
