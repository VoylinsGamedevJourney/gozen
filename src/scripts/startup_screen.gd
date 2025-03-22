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


func _set_recent_projects() -> void:
	if !FileAccess.file_exists(Project.RECENT_PROJECTS_FILE):
		return

	var l_file: FileAccess = FileAccess.open(Project.RECENT_PROJECTS_FILE, FileAccess.READ)
	var l_path: String = l_file.get_line()
	var l_new_paths: PackedStringArray = []

	while !l_file.eof_reached():
		if l_path.contains(Project.EXTENSION) and !l_new_paths.has(l_path):
			if !FileAccess.file_exists(l_path):
				# We still add non-found projects in case people have projects
				# saved on removable disks. This way when they connect their
				# disk, they can easily find the project in recent projects.
				if l_new_paths.append(l_path):
					Toolbox.print_append_error()
				continue

			var l_hbox: HBoxContainer = HBoxContainer.new()
			var l_project_button: Button = Button.new()
			var l_delete_button: TextureButton = TextureButton.new()

			l_project_button.text = l_path.get_file().trim_suffix(Project.EXTENSION)
			l_project_button.tooltip_text = l_path
			l_project_button.size_flags_horizontal = Control.SIZE_EXPAND_FILL

			Toolbox.connect_func(l_project_button.pressed, open_project.bind(l_path))

			l_delete_button.texture_normal = preload("uid://dyndi17ou8ixo")
			l_delete_button.ignore_texture_size = true
			l_delete_button.stretch_mode = TextureButton.STRETCH_KEEP_ASPECT_CENTERED
			l_delete_button.custom_minimum_size = Vector2i(18,0)

			Toolbox.connect_func(
					l_delete_button.pressed,
					_on_delete_recent_project.bind(l_hbox, l_path))

			l_hbox.add_child(l_delete_button)
			l_hbox.add_child(l_project_button)

			recent_projects_vbox.add_child(l_hbox)
			if l_new_paths.append(l_path):
				Toolbox.print_append_error()

		l_path = l_file.get_line()

	l_file.close()
	l_file = FileAccess.open(Project.RECENT_PROJECTS_FILE, FileAccess.WRITE)

	for l_new_path: String in l_new_paths:
		if !l_file.store_line(l_new_path):
			printerr("Error storing line for recent_projects!\n", get_stack())

	l_file.close()


func _on_delete_recent_project(a_hbox: HBoxContainer, a_path: String) -> void:
	var l_file: FileAccess = FileAccess.open(Project.RECENT_PROJECTS_FILE, FileAccess.READ)
	var l_context: String = l_file.get_as_text().replace(a_path, '')

	l_file.close()
	l_file = FileAccess.open(Project.RECENT_PROJECTS_FILE, FileAccess.WRITE)
	if !l_file.store_string(l_context):
		printerr("Error storing String for recent_projects!\n", get_stack())
	a_hbox.queue_free()


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


func _on_image_author_meta_clicked(a_meta: Variant) -> void:
	Toolbox.open_url(str(a_meta))


func _on_support_project_button_pressed() -> void:
	Toolbox.open_url(str(ProjectSettings.get_setting_with_override("urls/site")))
	

func _on_go_zen_logo_button_pressed() -> void:
	Toolbox.open_url(str(ProjectSettings.get_setting_with_override("urls/support")))


func _on_site_button_pressed() -> void:
	Toolbox.open_url(str(ProjectSettings.get_setting_with_override("urls/site")))


func _on_manual_button_pressed() -> void:
	Toolbox.open_url(str(ProjectSettings.get_setting_with_override("urls/manual")))


func _on_tutorials_button_pressed() -> void:
	Toolbox.open_url(str(ProjectSettings.get_setting_with_override("urls/tutorials")))


func _on_discord_server_button_pressed() -> void:
	Toolbox.open_url(str(ProjectSettings.get_setting_with_override("urls/discord")))


func _on_open_project_button_pressed() -> void:
	var l_dialog: FileDialog = Toolbox.get_file_dialog(
			tr("Open project"),
			FileDialog.FILE_MODE_OPEN_FILE,
			["*%s;GoZen project files" % Project.EXTENSION])

	Toolbox.connect_func(l_dialog.file_selected, open_project)

	add_child(l_dialog)
	l_dialog.popup_centered()


func _on_create_project_button_pressed() -> void:
	tab_container.current_tab = 1


func open_project(a_path: String) -> void:
	Project.open(a_path)
	self.queue_free()


func _on_cancel_create_project_button_pressed() -> void:
	tab_container.current_tab = 0


func _on_create_new_project_button_pressed() -> void:
	var l_path: String = project_path_line_edit.text

	if l_path[-1] == '/':
		l_path += "project" + Project.EXTENSION
	elif l_path.split('.')[-1] != Project.EXTENSION.replace('.', ''):
		l_path += Project.EXTENSION

	if FileAccess.file_exists(l_path):
		warning_label.text = "Already a project with this name in the current folder! %s" % l_path
		warning_label.tooltip_text = warning_label.text
		warning_label.visible = true
		return

	Project.new_project(
		l_path,
		Vector2i(int(resolution_x_spinbox.value), int(resolution_y_spinbox.value)),
		framerate_spinbox.value
	)

	self.queue_free()
		

func _on_project_path_button_pressed() -> void:
	var l_dialog: FileDialog = Toolbox.get_file_dialog(
			tr("Select project path"),
			FileDialog.FILE_MODE_SAVE_FILE,
			["*%s;GoZen project files" % Project.EXTENSION])

	Toolbox.connect_func(l_dialog.file_selected, open_project)

	add_child(l_dialog)
	l_dialog.popup_centered()


func _set_project_path(a_path: String) -> void:
	if a_path.split('.')[-1].to_lower() != Project.EXTENSION.replace('.', ''):
		a_path += Project.EXTENSION

	project_path_line_edit.text = a_path

