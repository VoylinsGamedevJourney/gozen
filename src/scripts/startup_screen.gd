extends PanelContainer


@export var version_label: RichTextLabel
@export var tab_container: TabContainer
@export var recent_projects_vbox: VBoxContainer

@export_category("New project menu")
@export var project_path_line_edit: LineEdit
@export var resolution_x_spinbox: SpinBox
@export var resolution_y_spinbox: SpinBox
@export var framerate_spinbox: SpinBox
@export var warning_label: Label



func _ready() -> void:
	tab_container.current_tab = 0
	_set_recent_projects()
	_set_version_label()
	_set_new_project_defaults()
	project_path_line_edit.text = OS.get_executable_path().get_base_dir() + "/project.gozen"


func _input(event: InputEvent) -> void:
	if event.is_action_pressed("open_project", false, true):
		_on_open_project_button_pressed()


func _set_recent_projects() -> void:
	if !FileAccess.file_exists(Project.RECENT_PROJECTS_FILE):
		return

	var file: FileAccess = FileAccess.open(Project.RECENT_PROJECTS_FILE, FileAccess.READ)
	var path: String = file.get_line()
	var new_paths: PackedStringArray = []

	while !file.eof_reached():
		if path.contains(Project.EXTENSION) and !new_paths.has(path):
			if !FileAccess.file_exists(path):
				# We still add non-found projects in case people have projects
				# saved on removable disks. This way when they connect their
				# disk, they can easily find the project in recent projects.
				if new_paths.append(path):
					Toolbox.print_append_error()
				continue

			var hbox: HBoxContainer = HBoxContainer.new()
			var project_button: Button = Button.new()
			var delete_button: TextureButton = TextureButton.new()

			project_button.text = path.get_file().trim_suffix(Project.EXTENSION)
			project_button.tooltip_text = path
			project_button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
			project_button.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND

			Toolbox.connect_func(project_button.pressed, open_project.bind(path))

			delete_button.texture_normal = preload("uid://dyndi17ou8ixo")
			delete_button.ignore_texture_size = true
			delete_button.stretch_mode = TextureButton.STRETCH_KEEP_ASPECT_CENTERED
			delete_button.custom_minimum_size = Vector2i(18,0)
			delete_button.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND

			Toolbox.connect_func(
					delete_button.pressed,
					_on_delete_recent_project.bind(hbox, path))

			hbox.add_child(delete_button)
			hbox.add_child(project_button)

			recent_projects_vbox.add_child(hbox)
			if new_paths.append(path):
				Toolbox.print_append_error()

		path = file.get_line()

	file.close()
	file = FileAccess.open(Project.RECENT_PROJECTS_FILE, FileAccess.WRITE)

	for new_path: String in new_paths:
		if !file.store_line(new_path):
			printerr("Error storing line for recent_projects!\n", get_stack())

	file.close()


func _on_delete_recent_project(hbox: HBoxContainer, path: String) -> void:
	var file: FileAccess = FileAccess.open(Project.RECENT_PROJECTS_FILE, FileAccess.READ)
	var context: String = file.get_as_text().replace(path, '')

	file.close()
	file = FileAccess.open(Project.RECENT_PROJECTS_FILE, FileAccess.WRITE)
	if !file.store_string(context):
		printerr("Error storing String for recent_projects!\n", get_stack())
	hbox.queue_free()


func _set_version_label() -> void:
	var version_string: String = ProjectSettings.get_setting_with_override(
			"application/config/version")

	if OS.is_debug_build():
		version_string += "-debug"

	version_label.text += version_string


func _set_new_project_defaults() -> void:
	project_path_line_edit.text = Settings.get_default_project_path()
	resolution_x_spinbox.value = Settings.get_default_resolution().x
	resolution_y_spinbox.value = Settings.get_default_resolution().y
	framerate_spinbox.value = Settings.get_default_framerate()


func _on_editor_settings_button_pressed() -> void:
	get_tree().root.add_child(preload("uid://bjen0oagwidr7").instantiate())


func _on_image_author_meta_clicked(meta: Variant) -> void:
	Toolbox.open_url(str(meta))


func _on_support_project_button_pressed() -> void:
	Toolbox.open_url(str(ProjectSettings.get_setting_with_override("urls/support")))
	

func _on_go_zen_logo_button_pressed() -> void:
	Toolbox.open_url(str(ProjectSettings.get_setting_with_override("urls/site")))


func _on_site_button_pressed() -> void:
	Toolbox.open_url(str(ProjectSettings.get_setting_with_override("urls/site")))


func _on_manual_button_pressed() -> void:
	Toolbox.open_url(str(ProjectSettings.get_setting_with_override("urls/manual")))


func _on_tutorials_button_pressed() -> void:
	Toolbox.open_url(str(ProjectSettings.get_setting_with_override("urls/tutorials")))


func _on_discord_server_button_pressed() -> void:
	Toolbox.open_url(str(ProjectSettings.get_setting_with_override("urls/discord")))


func _on_open_project_button_pressed() -> void:
	var dialog: FileDialog = Toolbox.get_file_dialog(
			tr("Open project"),
			FileDialog.FILE_MODE_OPEN_FILE,
			["*%s;GoZen project files" % Project.EXTENSION])

	Toolbox.connect_func(dialog.file_selected, open_project)

	add_child(dialog)
	dialog.popup_centered()


func _on_create_project_button_pressed() -> void:
	tab_container.current_tab = 1


func open_project(path: String) -> void:
	Project.open(path)
	self.queue_free()


func _on_cancel_create_project_button_pressed() -> void:
	tab_container.current_tab = 0


func _on_create_new_project_button_pressed() -> void:
	var path: String = project_path_line_edit.text

	if path[-1] == '/':
		path += "project" + Project.EXTENSION
	elif path.split('.')[-1] != Project.EXTENSION.replace('.', ''):
		path += Project.EXTENSION

	if FileAccess.file_exists(path):
		warning_label.text = "Already a project with this name in the current folder! %s" % path
		warning_label.tooltip_text = warning_label.text
		warning_label.visible = true
		return

	Project.new_project(
		path,
		Vector2i(int(resolution_x_spinbox.value), int(resolution_y_spinbox.value)),
		framerate_spinbox.value
	)

	self.queue_free()
		

func _on_project_path_button_pressed() -> void:
	var dialog: FileDialog = Toolbox.get_file_dialog(
			tr("Select project path"),
			FileDialog.FILE_MODE_SAVE_FILE,
			["*%s;GoZen project files" % Project.EXTENSION])

	Toolbox.connect_func(dialog.file_selected, _set_project_path)
	dialog.ok_button_text = "Select"

	add_child(dialog)
	dialog.popup_centered()


func _set_project_path(path: String) -> void:
	if path.split('.')[-1].to_lower() != Project.EXTENSION.replace('.', ''):
		path += Project.EXTENSION

	project_path_line_edit.text = path

