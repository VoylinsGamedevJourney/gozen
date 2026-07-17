class_name EditorUI
extends Control

static var instance: EditorUI


@export var menu_bar: HBoxContainer
@export var workspaces: TabContainer


var workspace_buttons_hbox: HBoxContainer
var workspace_buttons: Array[Button] = []
var workspace_button_group: ButtonGroup = ButtonGroup.new()



func _ready() -> void:
	instance = self
	workspace_buttons_hbox = menu_bar.get_node("WorkspaceButtonsHBox")

	# Populate workspaces + buttons.
	for workspace_name: String in WorkspaceManager.available_workspaces:
		_add_workspace_tab(workspace_name)

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
	InputManager.on_show_editor_screen.connect(switch_screen.bind(0))
	InputManager.on_show_render_screen.connect(switch_screen.bind(1))
	InputManager.on_switch_screen.connect(switch_screen_quick)
	WorkspaceManager.workspace_added.connect(_on_workspace_added)
	@warning_ignore_restore("return_value_discarded")

	switch_screen(0)
	PhysicsServer2D.set_active(false)
	PhysicsServer3D.set_active(false)

	# Check if editor got opened with a project path as argument.
	for arg: String in OS.get_cmdline_args():
		if arg.to_lower().ends_with(Project.EXTENSION):
			await Project.open(arg)
			return
	add_child(preload(Library.SCENE_STARTUP).instantiate())


func _add_workspace_tab(_workspace_name: String) -> void:
	var tab: Control = Control.new()
	tab.name = _workspace_name
	workspaces.add_child(tab)

	var button: Button = Button.new()
	button.text = _workspace_name
	button.theme_type_variation = "workspace_button"
	button.toggle_mode = true
	button.button_group = workspace_button_group

	@warning_ignore("return_value_discarded")
	button.pressed.connect(func() -> void:
			var index: int = workspace_buttons.find(button)
			if index != -1: switch_screen(index))

	@warning_ignore("return_value_discarded")
	button.gui_input.connect(func(event: InputEvent) -> void:
			if event is not InputEventMouseButton: return
			var input_event: InputEventMouseButton = event
			if input_event.pressed and input_event.button_index == MOUSE_BUTTON_RIGHT:
				_show_workspace_context_menu(_workspace_name, button))

	workspace_buttons_hbox.add_child(button)
	workspace_buttons.append(button)


func _on_workspace_added(workspace_name: String) -> void:
	_add_workspace_tab(workspace_name)
	switch_screen(workspace_buttons.size() - 1)


func switch_screen(index: int) -> void:
	if RenderManager.encoder == null or !RenderManager.encoder.is_open():
		if index >= 0 and index < workspace_buttons.size():
			workspaces.current_tab = index
			workspace_buttons[index].button_pressed = true
			WorkspaceManager.workspace_root = workspaces.get_child(index)
			WorkspaceManager.load_workspace(workspace_buttons[index].text)


func switch_screen_quick() -> void:
	if RenderManager.encoder == null or !RenderManager.encoder.is_open():
		var next_index: int = 0
		for i: int in workspace_buttons.size():
			if workspace_buttons[i].button_pressed:
				next_index = (i + 1) % workspace_buttons.size()
				break
		switch_screen(next_index)


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
		switch_screen(target_idx)
	elif button_b.button_pressed:
		switch_screen(current_idx)


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
		switch_screen(target_idx)

	WorkspaceManager.available_workspaces.erase(workspace_name)

	var tab: Node = workspaces.get_child(current_idx)
	workspaces.remove_child(tab)
	tab.queue_free()
	workspace_buttons_hbox.remove_child(button_to_delete)
	button_to_delete.queue_free()
	workspace_buttons.remove_at(current_idx)
