extends PanelContainer
# TODO: Add popup, with fuzzy searching, to browse through all projects.
# Save a thumbnail of each project at 2 seconds in the timeline to show in the
# popup to make it easy for people to select the project they are looking for.
# Set the default focus on the button which opens the popup to browse through
# all projects.

const PRESETS: Dictionary[String, Vector3i] = {
	"Custom": Vector3i.ZERO,
	"FHD (1080p) 30fps": Vector3i(1920, 1080, 30),
	"FHD (1080p) 60fps": Vector3i(1920, 1080, 60),
	"Vertical (1080p) 30fps": Vector3i(1080, 1920, 30),
	"Vertical (1080p) 60fps": Vector3i(1080, 1920, 60),
	"UHD (4K) 30fps": Vector3i(1920, 1080, 30),
	"UHD (4K) 60fps": Vector3i(1920, 1080, 60)
}


@export var version_label: RichTextLabel
@export var new_version_available_panel: PanelContainer
@export var new_version_available_button: TextureButton
@export var tab_container: TabContainer
@export var recent_projects_vbox: VBoxContainer

@export_category("New project menu")
@export var presets_option_button: OptionButton

@export var project_path_line_edit: LineEdit
@export var resolution_x_spinbox: SpinBox
@export var resolution_y_spinbox: SpinBox
@export var framerate_spinbox: SpinBox
@export var warning_label: Label

@export var advanced_options_button: CheckButton
@export var advanced_options: GridContainer
@export var background_color_picker: ColorPickerButton


var http_request: HTTPRequest ## For version checking.



func _ready() -> void:
	tab_container.current_tab = 0
	advanced_options_button.button_pressed = false
	advanced_options.visible = false

	_set_recent_projects()
	_set_version_label()
	_set_new_project_defaults()
	project_path_line_edit.text = OS.get_system_dir(OS.SYSTEM_DIR_MOVIES) + "/project.gozen"

	if Settings.get_check_version():
		_check_new_version()
	else:
		new_version_available_panel.visible = false


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
				new_paths.append(path)
				continue

			var hbox: HBoxContainer = HBoxContainer.new()
			var project_button: Button = Button.new()
			var delete_button: TextureButton = TextureButton.new()

			project_button.text = path.get_file().trim_suffix(Project.EXTENSION)
			project_button.tooltip_text = path
			project_button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
			project_button.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
			project_button.pressed.connect(open_project.bind(path))

			delete_button.texture_normal = preload(Library.ICON_DELETE)
			delete_button.ignore_texture_size = true
			delete_button.stretch_mode = TextureButton.STRETCH_KEEP_ASPECT_CENTERED
			delete_button.custom_minimum_size = Vector2i(18,0)
			delete_button.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
			delete_button.pressed.connect(_on_delete_recent_project.bind(hbox, path))

			hbox.add_child(delete_button)
			hbox.add_child(project_button)

			recent_projects_vbox.add_child(hbox)
			new_paths.append(path)
		path = file.get_line()
	file.close()
	file = FileAccess.open(Project.RECENT_PROJECTS_FILE, FileAccess.WRITE)
	for new_path: String in new_paths:
		if !file.store_line(new_path):
			printerr("StartupScreen: Error storing line for recent_projects!\n", get_stack())
	file.close()


func _on_delete_recent_project(hbox: HBoxContainer, path: String) -> void:
	var file: FileAccess = FileAccess.open(Project.RECENT_PROJECTS_FILE, FileAccess.READ)
	var context: String = file.get_as_text().replace(path, '')

	file.close()
	file = FileAccess.open(Project.RECENT_PROJECTS_FILE, FileAccess.WRITE)
	if !file.store_string(context):
		printerr("StartupScreen: Error storing String for recent_projects!\n", get_stack())
	hbox.queue_free()


func _set_version_label() -> void:
	var version_string: String = tr("Version") + ": "
	version_string += ProjectSettings.get_setting("application/config/version")

	if OS.is_debug_build():
		version_string += "-debug"

	version_label.text = version_string


func _set_new_project_defaults() -> void:
	# Setting the preset options
	presets_option_button.clear()

	for preset: String in PRESETS:
		presets_option_button.add_item(preset)

	presets_option_button.selected = 0

	# Setting the normal project settings
	project_path_line_edit.text = Settings.get_default_project_path()
	resolution_x_spinbox.value = Settings.get_default_resolution_x()
	resolution_y_spinbox.value = Settings.get_default_resolution_y()
	framerate_spinbox.value = Settings.get_default_framerate()

	# Setting the advanced project settings
	background_color_picker.color = Color.BLACK


func _on_editor_settings_button_pressed() -> void:
	Settings.open_settings_menu()


func _on_image_author_meta_clicked(meta: Variant) -> void:
	Utils.open_url(str(meta))


func _on_support_project_button_pressed() -> void:
	Utils.open_url("support")


func _on_go_zen_logo_button_pressed() -> void:
	Utils.open_url("site")


func _on_site_button_pressed() -> void:
	Utils.open_url("site")


func _on_manual_button_pressed() -> void:
	Utils.open_url("manual")


func _on_tutorials_button_pressed() -> void:
	Utils.open_url("tutorials")


func _on_discord_server_button_pressed() -> void:
	Utils.open_url("discord")


func _on_open_project_button_pressed() -> void:
	var dialog: FileDialog = PopupManager.create_file_dialog(
			tr("Open project"),
			FileDialog.FILE_MODE_OPEN_FILE,
			["*%s;%s" % [Project.EXTENSION, tr("GoZen project file")]])

	dialog.file_selected.connect(open_project)

	add_child(dialog)
	dialog.popup_centered()


func _on_create_project_button_pressed() -> void:
	tab_container.current_tab = 1


func open_project(path: String) -> void:
	await Project.open(path)
	self.queue_free()


func _on_cancel_create_project_button_pressed() -> void:
	tab_container.current_tab = 0


func _on_create_new_project_button_pressed() -> void:
	var path: String = project_path_line_edit.text
	var resolution: Vector2i = Vector2i(int(resolution_x_spinbox.value), int(resolution_y_spinbox.value))

	if path[-1] == '/':
		path += "project" + Project.EXTENSION
	elif path.split('.')[-1] != Project.EXTENSION.replace('.', ''):
		path += Project.EXTENSION

	if FileAccess.file_exists(path):
		warning_label.text = "Already a project with this name in the current folder! %s" % path
		warning_label.tooltip_text = warning_label.text
		warning_label.visible = true
		return

	await Project.new_project(path, resolution, framerate_spinbox.value)
	if advanced_options_button.button_pressed:
		Project.set_background_color(background_color_picker.color)
	self.queue_free()


func _on_project_path_button_pressed() -> void:
	var dialog: FileDialog = PopupManager.create_file_dialog(
			tr("Select project save path"),
			FileDialog.FILE_MODE_SAVE_FILE,
			["*%s;%s" % [Project.EXTENSION, tr("GoZen project file")]])

	dialog.file_selected.connect(_set_project_path)
	dialog.ok_button_text = "Select"

	add_child(dialog)
	dialog.popup_centered()


func _set_project_path(path: String) -> void:
	if path.split('.')[-1].to_lower() != Project.EXTENSION.replace('.', ''):
		path += Project.EXTENSION

	project_path_line_edit.text = path


func _check_new_version() -> void:
	http_request = HTTPRequest.new()
	add_child(http_request)
	http_request.request_completed.connect(_check_new_version_request_completed)

	if !http_request.request("latest_release_check"):
		printerr("StartupScreen: Couldn't send an http request for the version check!")

	new_version_available_button.pressed.connect(func() -> void: Utils.open_url("latest_release"))


func _check_new_version_request_completed(result: int, response_code: int, _headers: PackedStringArray, body: PackedByteArray) -> void:
	# Initial check to see if the request was successful or not.
	if result != HTTPRequest.RESULT_SUCCESS:
		new_version_available_panel.visible = false
		print("StartupScreen: Check for new version failed! ", result)
	elif response_code == 404:
		print("StartupScreen: No releases found for repo! ", response_code)
	elif response_code != 200:
		print("StartupScreen: HTTPRequest failed with status code: ", response_code)
		return

	# Request was successful, not checking the JSON data.
	var json: Variant = JSON.parse_string(body.get_string_from_utf8())

	if json == null:
		print("StartupScreen: Failed to parse JSON response for checking version!")
		return
	elif typeof(json) != TYPE_DICTIONARY:
		print("StartupScreen: Failed to get dictionary from json for checking version!")
		return

	var json_data: Dictionary = json

	if !json_data.has("tag_name"):
		print("StartupScreen: StartupScreen: No releases found for repo!")
		return

	# Checking the version from the latest release vs the current editor version.
	var latest_release: String = str(json_data["tag_name"]).to_lower().lstrip('v')
	var major: int = int(latest_release.split('.')[0])
	var minor: int = int(latest_release.split('.')[1])
	var patch: int = -1
	var tag: int = 3

	var current_release: String = ProjectSettings.get_setting("application/config/version")
	var current_major: int = int(current_release.split('.')[0])
	var current_minor: int = int(current_release.split('.')[0])
	var current_patch: int = -1
	var current_tag: int = 3

	if latest_release.count('.') == 3:
		patch = int(latest_release.split('.')[2])
	if current_release.count('.') == 3:
		patch = int(current_release.split('.')[2])

	if latest_release.contains('-'):
		match latest_release.split('-')[1]:
			"dev": tag = 0
			"alpha": tag = 1
			"beta": tag = 2
	if current_release.contains('-'):
		match current_release.split('-')[1]:
			"dev": current_tag = 0
			"alpha": current_tag = 1
			"beta": current_tag = 2

	# Checking Major.
	if current_major < major:
		new_version_available_panel.visible = true
		return
	elif current_major > major:
		return # Already newest version.

	# Checking Minor.
	if current_minor < minor:
		new_version_available_panel.visible = true
		return
	elif current_minor > minor:
		return # Already newest version.

	# Checking Patch.
	if current_patch < patch:
		new_version_available_panel.visible = true
		return
	elif current_patch > patch:
		return # Already newest version.

	# Checking Tag.
	if current_tag < tag:
		new_version_available_panel.visible = true
		return
	elif current_tag > tag:
		return # Already newest version.


func _on_advanced_options_check_button_toggled(toggled_on: bool) -> void:
	advanced_options.visible = toggled_on


func _on_new_project_option_button_item_selected(index: int) -> void:
	if index == 0: # Custom
		_set_new_project_defaults()
		return

	var keys: PackedStringArray = PRESETS.keys()
	var presets_data: Vector3 = PRESETS[keys[index]]

	resolution_x_spinbox.value = presets_data.x
	resolution_y_spinbox.value = presets_data.y
	framerate_spinbox.value = presets_data.z
