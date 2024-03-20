extends Control

var landscape := true # For creating new projects


func _ready():
	# Populating the recent projects lists
	var recent_projects := RecentProjects.new()
	var count := 0
	for entry: RecentProject in recent_projects.data:
		if count != 5:
			count += 1
			_create_recent_project_button(entry, %RecentProjectsVBoxShort)
		_create_recent_project_button(entry, %RecentProjectsVBoxLong)
	
	if recent_projects.data.size() < 5:
		# Hiding the separator and the 'show all projects' button
		%RecentProjectsVBoxShort.get_node("ShowAllProjectsButton").visible = false
		%RecentProjectsVBoxShort.get_node("Spacer2").visible = false
	else:
		move_child(%RecentProjectsVBoxShort.get_node("ShowAllProjectsButton"), -1)
		move_child(%RecentProjectsVBoxShort.get_node("Spacer2"), -1)


func _create_recent_project_button(data: RecentProject, parent: Node) -> void:
	var button := Button.new()
	button.alignment = HORIZONTAL_ALIGNMENT_LEFT
	button.text = data.title
	button.tooltip_text = data.path
	button.icon = preload("res://assets/icons/video_file.png")
	button.pressed.connect(_file_selected.bind(data.path))
	parent.add_child(button)


func _file_selected(path: String) -> void:
	if Toolbox.check_extension(path, ["gozen"]):
		ProjectManager.load_project(path)
		self.queue_free()
	else:
		Printer.error("Can't open project as path does not have '*.gozen' extension!")


###############################################################
#region Buttons  ##############################################
###############################################################

func _on_open_project_button_pressed() -> void:
	var dialog := DialogManager.get_open_project_dialog()
	dialog.file_selected.connect(_file_selected)
	dialog.canceled.connect(func() -> void: dialog.queue_free())
	add_child(dialog)
	dialog.popup_centered(Vector2i(500,600))


func _on_show_all_projects_button_pressed() -> void:
	%StartupTabPanel.current_tab = 1


func _on_create_project_button_pressed() -> void:
	%StartupTabPanel.current_tab = 2


func _on_return_button_pressed() -> void:
	%StartupTabPanel.current_tab = 0


func _on_create_project():
	if %TitleLineEdit.text == "" or %PathLineEdit.text == "":
		return
	ProjectManager.new_project(
		%TitleLineEdit.text,
		%PathLineEdit.text,
		Vector2i(%XSpinBox.value, %YSpinBox.value), # resolution
		%FramerateSpinBox.value)
	self.queue_free()


func _on_select_path_button_pressed():
	var dialog := DialogManager.get_select_path_dialog()
	dialog.file_selected.connect(_on_file_selected)
	dialog.canceled.connect(func() -> void: dialog.queue_free())
	add_child(dialog)
	dialog.popup_centered(Vector2i(500,600))


func _on_file_selected(path: String) -> void:
	if %TitleLineEdit.text == "":
		%TitleLineEdit.text = path.split('/')[-1].to_pascal_case()
	if !Toolbox.check_extension(path, ["gozen"]):
		%PathLineEdit.text = path + ".gozen"
	else:
		%PathLineEdit.text = path


func _on_switch_landscape(value: bool) -> void:
	landscape = value
	var big: int = max(%XSpinBox.value, %YSpinBox.value) 
	var small: int = min(%XSpinBox.value, %YSpinBox.value) 
	%XSpinBox.value = big if landscape else small
	%YSpinBox.value = small if landscape else big


func _on_set_quality(resolution: Vector2i) -> void:
	%XSpinBox.value = resolution.x if landscape else resolution.y
	%YSpinBox.value = resolution.y if landscape else resolution.x


func _on_framerate_button_pressed(frame_rate: int) -> void:
	%FramerateSpinBox.value = frame_rate

#endregion
###############################################################
