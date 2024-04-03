extends Control

var landscape: bool = true # For creating new projects


func _ready() -> void:
	# Populating the recent projects lists
	var l_recent_projects: RecentProjects = RecentProjects.new()
	var l_count: int = 0
	
	for l_entry: RecentProject in l_recent_projects.data:
		if l_count != 5:
			l_count += 1
			_create_recent_project_button(l_entry, %RecentProjectsVBoxShort)
		_create_recent_project_button(l_entry, %RecentProjectsVBoxLong)
	
	if l_recent_projects.data.size() < 5:
		# Hiding the separator and the 'show all projects' button
		%RecentProjectsVBoxShort.get_node("ShowAllProjectsButton").visible = false
		%RecentProjectsVBoxShort.get_node("Spacer2").visible = false
	else:
		move_child(%RecentProjectsVBoxShort.get_node("ShowAllProjectsButton"), -1)
		move_child(%RecentProjectsVBoxShort.get_node("Spacer2"), -1)


func _create_recent_project_button(a_data: RecentProject, a_parent: Node) -> void:
	var l_button := Button.new()
	
	l_button.alignment = HORIZONTAL_ALIGNMENT_LEFT
	l_button.text = a_data.title
	l_button.tooltip_text = a_data.path
	l_button.icon = preload("res://assets/icons/video_file.png")
	l_button.pressed.connect(_file_selected.bind(a_data.path))
	
	a_parent.add_child(l_button)


func _file_selected(a_path: String) -> void:
	if Toolbox.check_extension(a_path, ["gozen"]):
		ProjectManager.load_project(a_path)
		self.queue_free()
		return
	Printer.error(Globals.ERROR_PROJECT_PATH_EXTENSION)


#region #####################  New Project Buttons  ############################

func _on_open_project_button_pressed() -> void:
	var l_dialog := DialogManager.get_open_project_dialog()
	
	l_dialog.file_selected.connect(_file_selected)
	l_dialog.canceled.connect(Toolbox.free_node.bind(l_dialog))
	
	add_child(l_dialog)
	l_dialog.popup_centered(Vector2i(500,600))


func _on_return_button_pressed() -> void:
	%StartupTabPanel.current_tab = 0


func _on_show_all_projects_button_pressed() -> void:
	%StartupTabPanel.current_tab = 1


func _on_create_project_button_pressed() -> void:
	%StartupTabPanel.current_tab = 2


func _on_create_project() -> void:
	if %TitleLineEdit.text != "" and %PathLineEdit.text != "":
		ProjectManager.new_project(
			%TitleLineEdit.text,
			%PathLineEdit.text,
			Vector2i(%XSpinBox.value, %YSpinBox.value), # resolution
			%FramerateSpinBox.value)
		self.queue_free()


func _on_select_path_button_pressed() -> void:
	var l_dialog := DialogManager.get_select_path_dialog()
	
	l_dialog.file_selected.connect(_on_file_selected)
	l_dialog.canceled.connect(Toolbox.free_node.bind(l_dialog))
	
	add_child(l_dialog)
	l_dialog.popup_centered(Vector2i(500,600))


func _on_file_selected(a_path: String) -> void:
	if %TitleLineEdit.text == "":
		%TitleLineEdit.text = a_path.split('/')[-1].to_pascal_case()
	
	if !Toolbox.check_extension(a_path, ["gozen"]):
		%PathLineEdit.text = a_path + ".gozen"
	else:
		%PathLineEdit.text = a_path


func _on_switch_landscape(a_value: bool) -> void:
	var l_big: int = max(%XSpinBox.value, %YSpinBox.value) 
	var l_small: int = min(%XSpinBox.value, %YSpinBox.value) 
	
	landscape = a_value
	%XSpinBox.value = l_big if landscape else l_small
	%YSpinBox.value = l_small if landscape else l_big


func _on_set_quality(a_resolution: Vector2i) -> void:
	%XSpinBox.value = a_resolution.x if landscape else a_resolution.y
	%YSpinBox.value = a_resolution.y if landscape else a_resolution.x


func _on_framerate_button_pressed(a_frame_rate: int) -> void:
	%FramerateSpinBox.value = a_frame_rate

#endregion
#region #####################  Link buttons  ###################################

func _on_editor_button_pressed() -> void:
	OS.shell_open(Globals.URL_GITHUB_REPO) # NOTE: Replace by site in future


func _on_manual_button_pressed() -> void:
	OS.shell_open(Globals.URL_MANUAL) # NOTE: Replace in future


func _on_tutorials_button_pressed() -> void:
	OS.shell_open(Globals.URL_TUTORIALS) # NOTE: Replace in future


func _on_discord_button_pressed() -> void:
	OS.shell_open(Globals.URL_DISCORD)


func _on_support_project_button_pressed() -> void:
	OS.shell_open(Globals.URL_SUPPORT_PROJECT)

#endregion
