extends PanelContainer
# TODO: Add popup, with fuzzy searching, to browse through all projects.
# Save a thumbnail of each project at 2 seconds in the timeline to show in the
# popup to make it easy for people to select the project they are looking for.
# Set the default focus on the button which opens the popup to browse through
# all projects.

const DEFAULT_PROFILES_PATH: String = "res://profiles/project/"


@export var panel: PanelContainer
@export var version_label: RichTextLabel
@export var tab_container: TabContainer
@export var recent_projects_flow: HFlowContainer
@export var sort_option_button: OptionButton
@export var create_new_project_button: Button

@export_category("New project menu")
@export var project_presets_option_button: OptionButton

@export var project_path_line_edit: LineEdit
@export var resolution_x_spinbox: SpinBox
@export var resolution_y_spinbox: SpinBox
@export var framerate_spinbox: SpinBox
@export var warning_label: Label

@export var advanced_options_button: CheckButton
@export var advanced_options: GridContainer
@export var background_color_picker: ColorPickerButton
@export var track_amount_spinbox: SpinBox

@export var save_profile_preset_button: TextureButton
@export var delete_profile_preset_button: TextureButton

@export_category("Startup image")
@export var startup_image: TextureRect
@export var startup_image_credit_label: RichTextLabel


var http_request: HTTPRequest ## For version checking.

var startup_images_data: Array[PackedStringArray] = [ ## [ Image UID, unsplash image id ]
	["uid://sh8txndv1wtu", "u27Rrbs9Dwc"],
	["uid://bixnh6u1jfb18", "XzbgXfnjclI"],
	["uid://b68fi43mkp6i1", "A5GmtHW3O9k"],
]

var loaded_preset_profiles: Array[ProjectProfile] = [] ## New project profiles.
var default_profiles_count: int = 0

var _recent_projects_data: Array[RecentProjectData] = []



func _ready() -> void:
	sort_option_button.item_selected.connect(_build_recent_projects_ui.unbind(1))

	resolution_x_spinbox.value_changed.connect(_on_new_project_setting_changed.unbind(1))
	resolution_y_spinbox.value_changed.connect(_on_new_project_setting_changed.unbind(1))
	framerate_spinbox.value_changed.connect(_on_new_project_setting_changed.unbind(1))
	background_color_picker.color_changed.connect(_on_new_project_setting_changed.unbind(1))

	tab_container.current_tab = 0
	advanced_options_button.button_pressed = false
	advanced_options.visible = false

	_set_recent_projects()
	_set_version_label()
	_set_new_project_defaults()

	# Set the startup background image.
	randomize()
	var weights: Array = [0, 0, 0] # I want the first image to appear most of the time :p
	for i: int in startup_images_data.size():
		weights.append(i)
	var image_index: int = randi() % weights.size()
	var image_data: PackedStringArray = startup_images_data[weights[image_index]]
	var image_author: String = ResourceUID.uid_to_path(image_data[0]).get_basename().get_file()
	image_author = Format.clean_file_name(image_author)

	startup_image_credit_label.text = tr("Image by")
	startup_image_credit_label.text += " [url=https://unsplash.com/photos/%s][u]%s[/u][/url]" % [image_data[1], image_author] # NO_TRANSLATE
	startup_image.texture = load(image_data[0])


func _input(event: InputEvent) -> void:
	if event.is_action_pressed("open_project", false, true):
		_on_open_project_button_pressed()
	elif event.is_action_pressed("ui_cancel", false, true):
		if tab_container.current_tab != 0 and not Project.is_loaded:
			tab_container.current_tab = 0
		else:
			dismiss()


func _gui_input(event: InputEvent) -> void:
	if event is InputEventMouseButton:
		var mouse_event: InputEventMouseButton = event as InputEventMouseButton
		if mouse_event.pressed and mouse_event.button_index == MouseButton.MOUSE_BUTTON_LEFT:
			dismiss()


func dismiss() -> void:
	if Project.is_loaded:
		self.queue_free()
	else:
		_on_create_quick_h_project_button_pressed()


func get_user_profiles_path() -> String:
	return Utils.get_config_dir().path_join("profiles/project")


func _set_recent_projects() -> void:
	_recent_projects_data.clear()
	if !FileAccess.file_exists(Project.RECENT_PROJECTS_FILE):
		return

	var file: FileAccess = FileAccess.open(Project.RECENT_PROJECTS_FILE, FileAccess.READ)
	var path: String = file.get_line().strip_edges()
	var new_paths: PackedStringArray = []
	var original_index: int = 0

	while !file.eof_reached():
		if path.contains(Project.EXTENSION) and !new_paths.has(path):
			if !FileAccess.file_exists(path):
				# We still add non-found projects in case people have projects
				# saved on removable disks. This way when they connect their
				# disk, they can easily find the project in recent projects.
				new_paths.append(path)
				path = file.get_line().strip_edges()
				continue

			var title: String = path.get_file().trim_suffix(Project.EXTENSION)
			var modified_time: int = FileAccess.get_modified_time(path)
			_recent_projects_data.append(RecentProjectData.new(path, title, modified_time, original_index))
			original_index += 1
			new_paths.append(path)
		path = file.get_line().strip_edges()
	file.close()
	file = FileAccess.open(Project.RECENT_PROJECTS_FILE, FileAccess.WRITE)
	if file:
		for new_path: String in new_paths:
			if !file.store_line(new_path) or file.get_error():
				printerr("StartupScreen: Error storing line for recent_projects!\n", get_stack())
		file.close()

	_build_recent_projects_ui()

func _build_recent_projects_ui() -> void:
	for child: Node in recent_projects_flow.get_children():
		recent_projects_flow.remove_child(child)
		child.queue_free()

	var sorted_data: Array[RecentProjectData] = _recent_projects_data.duplicate()
	var sort_index: int = sort_option_button.selected

	match sort_index:
		# Latest
		0: sorted_data.sort_custom(func(a: RecentProjectData, b: RecentProjectData) -> bool:
					return a.original_index < b.original_index)
		# Oldest
		1: sorted_data.sort_custom(func(a: RecentProjectData, b: RecentProjectData) -> bool:
					return a.original_index > b.original_index)
		# Name A-Z
		2: sorted_data.sort_custom(func(a: RecentProjectData, b: RecentProjectData) -> bool:
					return a.title.naturalnocasecmp_to(b.title) < 0)
		# Name Z-A
		3: sorted_data.sort_custom(func(a: RecentProjectData, b: RecentProjectData) -> bool:
					return a.title.naturalnocasecmp_to(b.title) > 0)

	for data: RecentProjectData in sorted_data:
		var project_button: Button = Button.new()
		project_button.custom_minimum_size = Vector2(250, 80)
		project_button.custom_maximum_size = Vector2(330, 80) # Y value doesn't do anything.
		project_button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		project_button.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
		project_button.pressed.connect(open_project.bind(data.path))
		project_button.gui_input.connect(_on_recent_project_gui_input.bind(project_button, data.path))

		var margin: MarginContainer = MarginContainer.new()
		margin.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
		margin.add_theme_constant_override("margin_left", 3)
		margin.add_theme_constant_override("margin_top", 3)
		margin.add_theme_constant_override("margin_right", 3)
		margin.add_theme_constant_override("margin_bottom", 3)
		margin.mouse_filter = Control.MOUSE_FILTER_IGNORE
		project_button.add_child(margin)

		var hbox: HBoxContainer = HBoxContainer.new()
		hbox.mouse_filter = Control.MOUSE_FILTER_IGNORE
		margin.add_child(hbox)

		var thumb: TextureRect = TextureRect.new()
		thumb.custom_minimum_size = Vector2(100, 0)
		thumb.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		thumb.texture = Thumbnailer.get_project_thumb(data.path)
		thumb.mouse_filter = Control.MOUSE_FILTER_IGNORE
		hbox.add_child(thumb)

		var vbox: VBoxContainer = VBoxContainer.new()
		vbox.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		vbox.mouse_filter = Control.MOUSE_FILTER_IGNORE
		hbox.add_child(vbox)

		var title_label: Label = Label.new()
		title_label.size_flags_vertical = Control.SIZE_EXPAND_FILL
		# title_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		title_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		title_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		title_label.clip_text = true
		title_label.mouse_filter = Control.MOUSE_FILTER_PASS
		title_label.text = Format.clean_file_name(data.title)
		vbox.add_child(title_label)

		var path_label: Label = Label.new()
		path_label.modulate = Color(1, 1, 1, 0.498)
		path_label.clip_text = true
		path_label.mouse_filter = Control.MOUSE_FILTER_PASS
		path_label.text = Format.path_remove_middle(data.path, 34)
		path_label.add_theme_font_size_override("font_size", 12)
		vbox.add_child(path_label)

		var date_label: Label = Label.new()
		var mod_date_str: String = "Unknown"
		date_label.modulate = Color(1, 1, 1, 0.498)
		date_label.mouse_filter = Control.MOUSE_FILTER_PASS
		if data.modified_time > 0:
			var mod_time_dict: Dictionary = Time.get_datetime_dict_from_unix_time(data.modified_time)
			mod_date_str = "%04d-%02d-%02d %02d:%02d:%02d" % [mod_time_dict.year, mod_time_dict.month, mod_time_dict.day, mod_time_dict.hour, mod_time_dict.minute, mod_time_dict.second]
		date_label.text = mod_date_str
		date_label.add_theme_font_size_override("font_size", 12)
		vbox.add_child(date_label)

		var tooltip: String = "%s\n%s\nModified: %s" % [data.title, data.path, mod_date_str]
		project_button.tooltip_text = tooltip

		recent_projects_flow.add_child(project_button)

	# Set the focus on the first project so it can be opened with enter.
	if recent_projects_flow.get_child_count() > 0:
		var first_button: Button = recent_projects_flow.get_child(0) as Button
		first_button.grab_focus.call_deferred()
	else:
		create_new_project_button.grab_focus.call_deferred()


func _on_recent_project_gui_input(event: InputEvent, button: Button, path: String) -> void:
	if event is InputEventMouseButton:
		var mouse_event: InputEventMouseButton = event as InputEventMouseButton
		if mouse_event.pressed and mouse_event.button_index == MOUSE_BUTTON_RIGHT:
			var popup: PopupMenu = PopupManager.create_menu()
			popup.add_icon_item(load(Library.ICON_FOLDER) as Texture2D, tr("Open in file manager"), 0)
			popup.add_icon_item(load(Library.ICON_DELETE) as Texture2D, tr("Remove from list"), 1)
			popup.id_pressed.connect(_on_recent_project_popup_id_pressed.bind(button, path))
			PopupManager.show_menu(popup)


func _on_recent_project_popup_id_pressed(id: int, button: Button, path: String) -> void:
	if id == 0:
		OS.shell_show_in_file_manager(ProjectSettings.globalize_path(path.get_base_dir()))
	elif id == 1:
		_on_delete_recent_project(button, path)


func _on_delete_recent_project(button: Button, path: String) -> void:
	# Remove it from our local array so it doesn't return when resorting.
	for i: int in range(_recent_projects_data.size() - 1, -1, -1):
		if _recent_projects_data[i].path == path:
			_recent_projects_data.remove_at(i)
			break

	var paths: Array[String] = []
	var file: FileAccess

	if FileAccess.file_exists(Project.RECENT_PROJECTS_FILE):
		file = FileAccess.open(Project.RECENT_PROJECTS_FILE, FileAccess.READ)
		while not file.eof_reached():
			var line: String = file.get_line().strip_edges()
			if not line.is_empty() and line != path:
				paths.append(line)
		file.close()

	file = FileAccess.open(Project.RECENT_PROJECTS_FILE, FileAccess.WRITE)
	if file:
		for project_path: String in paths:
			file.store_line(project_path)
		file.close()
	else:
		printerr("StartupScreen: Error storing String for recent_projects!\n", get_stack())
	button.queue_free()


func _set_version_label() -> void:
	var version_string: String = tr("Version") + ": "
	version_string += ProjectSettings.get_setting("application/config/version")

	if OS.is_debug_build():
		version_string += "-debug"

	version_label.text = version_string


func _set_new_project_defaults() -> void:
	loaded_preset_profiles.clear()
	project_presets_option_button.clear()

	# Setting the preset options.
	var profile_files: PackedStringArray = DirAccess.get_files_at(DEFAULT_PROFILES_PATH)
	for profile_path: String in profile_files:
		profile_path = profile_path.trim_suffix(".remap")
		if !profile_path.ends_with(".tres") and !profile_path.ends_with(".res"): continue

		var project_profile: ProjectProfile = load(DEFAULT_PROFILES_PATH.path_join(profile_path))
		if not project_profile: continue

		project_presets_option_button.add_item(project_profile.profile_name, loaded_preset_profiles.size())
		loaded_preset_profiles.append(project_profile)

	default_profiles_count = loaded_preset_profiles.size()

	project_presets_option_button.add_separator(tr("User presets"))

	if not DirAccess.dir_exists_absolute(get_user_profiles_path()):
		DirAccess.make_dir_recursive_absolute(get_user_profiles_path())
	else:
		var user_profile_files: PackedStringArray = DirAccess.get_files_at(get_user_profiles_path())
		for profile_path: String in user_profile_files:
			profile_path = profile_path.trim_suffix(".remap")
			if !profile_path.ends_with(".tres") and !profile_path.ends_with(".res"): continue

			var project_profile: ProjectProfile = load(get_user_profiles_path().path_join(profile_path))
			if not project_profile: continue

			project_presets_option_button.add_item(project_profile.profile_name, loaded_preset_profiles.size())
			loaded_preset_profiles.append(project_profile)

	# Setting the normal project settings.
	project_path_line_edit.text = Settings.get_default_project_path().path_join("project.gozen")
	resolution_x_spinbox.set_value_no_signal(Settings.get_default_resolution_x())
	resolution_y_spinbox.set_value_no_signal(Settings.get_default_resolution_y())
	framerate_spinbox.set_value_no_signal(Settings.get_default_framerate())

	# Setting the advanced project settings.
	background_color_picker.color = Color.BLACK
	track_amount_spinbox.set_value_no_signal(Settings.get_module_setting("core_timeline_panel", "tracks_amount", 6) as float)

	_on_new_project_option_button_item_selected(0)
	save_profile_preset_button.disabled = true
	save_profile_preset_button.modulate = get_theme_color("icon_disabled", "StartupScreen")
	delete_profile_preset_button.disabled = true
	delete_profile_preset_button.modulate = get_theme_color("icon_disabled", "StartupScreen")


func _on_editor_settings_button_pressed() -> void:
	Settings.open_settings_menu()


func _on_image_author_meta_clicked(meta: Variant) -> void:  URL.open(str(meta))


func _on_support_project_button_pressed() -> void: URL.open("support")
func _on_gozen_logo_button_pressed() -> void:	   URL.open("site")
func _on_site_button_pressed() -> void: 		   URL.open("site")
func _on_manual_button_pressed() -> void: 		   URL.open("manual")
func _on_tutorials_button_pressed() -> void: 	   URL.open("tutorials")
func _on_discord_server_button_pressed() -> void:  URL.open("discord")


func _on_create_project_button_pressed() -> void:		 tab_container.current_tab = 1
func _on_cancel_create_project_button_pressed() -> void: tab_container.current_tab = 0


func _on_open_project_button_pressed() -> void:
	var dialog: FileDialog = PopupManager.create_file_dialog(
			tr("Open project"),
			FileDialog.FILE_MODE_OPEN_FILE,
			["*%s;%s" % [Project.EXTENSION, tr("GoZen project file")]])
	var default_dir: String = Settings.get_default_project_path()
	dialog.current_dir = default_dir if not default_dir.is_empty() else Project.get_picker_path(OS.SYSTEM_DIR_MOVIES)
	dialog.file_selected.connect(open_project)

	add_child(dialog)
	dialog.popup_centered()


func open_project(path: String) -> void:
	Project.check_unsaved_and_perform(func() -> void:
			self.visible = false
			Project._cleanup()
			await get_tree().process_frame
			await Project.open(path)
			self.queue_free())


func _on_create_new_project_button_pressed() -> void:
	var path: String = project_path_line_edit.text

	if !path.is_empty():
		if path.ends_with("/") or path.ends_with("\\"):
			path = path.path_join("project" + Project.EXTENSION)
		elif path.get_extension().to_lower() != Project.EXTENSION.replace('.', ''):
			path += Project.EXTENSION

		if FileAccess.file_exists(path):
			warning_label.text = "Already a project with this name in the current folder! %s" % path
			warning_label.tooltip_text = warning_label.text
			warning_label.visible = true
			return

	var request: RequestProjectNew = RequestProjectNew.new()
	request.project_path = path
	request.resolution = Vector2i(int(resolution_x_spinbox.value), int(resolution_y_spinbox.value))
	request.framerate = framerate_spinbox.value

	if advanced_options_button.button_pressed:
		request.background_color = background_color_picker.color
		request.track_amount = int(track_amount_spinbox.value)

	Project.check_unsaved_and_perform(func() -> void:
			self.visible = false
			Project._cleanup()
			await get_tree().process_frame
			Project.new_project(request)
			self.queue_free())


func _on_create_quick_h_project_button_pressed() -> void: ## Horizontal.
	var request: RequestProjectNew = RequestProjectNew.new()
	request.resolution = Settings.get_quick_create_horizontal_res()
	request.framerate  = Settings.get_quick_create_horizontal_fps()
	Project.check_unsaved_and_perform(func() -> void:
			self.visible = false
			Project._cleanup()
			await get_tree().process_frame
			Project.new_project(request)
			self.queue_free())


func _on_create_quick_v_project_button_pressed() -> void: ## Vertical.
	var request: RequestProjectNew = RequestProjectNew.new()
	request.resolution = Settings.get_quick_create_vertical_res()
	request.framerate  = Settings.get_quick_create_vertical_fps()
	Project.check_unsaved_and_perform(func() -> void:
			self.visible = false
			Project._cleanup()
			await get_tree().process_frame
			Project.new_project(request)
			self.queue_free())


func _on_project_path_button_pressed() -> void:
	var dialog: FileDialog = PopupManager.create_file_dialog(
			tr("Select project save path"),
			FileDialog.FILE_MODE_SAVE_FILE,
			["*%s;%s" % [Project.EXTENSION, tr("GoZen project file")]])
	var default_dir: String = Settings.get_default_project_path()
	dialog.current_dir = default_dir if not default_dir.is_empty() else Project.get_picker_path(OS.SYSTEM_DIR_MOVIES)
	dialog.file_selected.connect(_set_project_path)
	dialog.ok_button_text = "Select"

	add_child(dialog)
	dialog.popup_centered()


func _set_project_path(path: String) -> void:
	if path.get_extension().to_lower() != Project.EXTENSION.replace('.', ''):
		path += Project.EXTENSION

	project_path_line_edit.text = path


func _on_advanced_options_check_button_toggled(toggled_on: bool) -> void:
	advanced_options.visible = toggled_on
	_on_new_project_setting_changed()


func _on_new_project_option_button_item_selected(index: int) -> void:
	var id: int = project_presets_option_button.get_item_id(index)
	if id < 0 or id >= loaded_preset_profiles.size():
		return


	var profile: ProjectProfile = loaded_preset_profiles[id]
	resolution_x_spinbox.set_value_no_signal(profile.resolution.x)
	resolution_y_spinbox.set_value_no_signal(profile.resolution.y)
	framerate_spinbox.set_value_no_signal(profile.framerate)

	advanced_options_button.set_pressed_no_signal(profile.advanced_settings_enabled)
	advanced_options.visible = profile.advanced_settings_enabled
	if profile.advanced_settings_enabled:
		background_color_picker.color = profile.background_color

	save_profile_preset_button.disabled = true
	save_profile_preset_button.modulate = get_theme_color("icon_disabled", "StartupScreen")
	if id < default_profiles_count:
		delete_profile_preset_button.disabled = true
		delete_profile_preset_button.modulate = get_theme_color("icon_disabled", "StartupScreen")
	else:
		delete_profile_preset_button.disabled = false
		delete_profile_preset_button.modulate = get_theme_color("icon_enabled", "StartupScreen")


func _on_save_profile_preset_button_pressed() -> void:
	var dialog: ConfirmationDialog = PopupManager.create_confirmation_dialog(tr("Save preset"), "")
	var line_edit: LineEdit = LineEdit.new()
	line_edit.placeholder_text = tr("Preset name")
	dialog.add_child(line_edit)

	var confirm_lambda: Callable = func() -> void:
		var preset_name: String = line_edit.text.strip_edges()
		if preset_name.is_empty():
			preset_name = "Custom"

		var profile: ProjectProfile = ProjectProfile.new()
		profile.profile_name = preset_name
		profile.resolution = Vector2i(int(resolution_x_spinbox.value), int(resolution_y_spinbox.value))
		profile.framerate = framerate_spinbox.value
		profile.advanced_settings_enabled = advanced_options_button.button_pressed
		profile.background_color = background_color_picker.color

		if not DirAccess.dir_exists_absolute(get_user_profiles_path()):
			var _dir_err: int = DirAccess.make_dir_recursive_absolute(get_user_profiles_path())

		var save_path: String = get_user_profiles_path().path_join(preset_name.validate_filename() + ".tres")
		ResourceSaver.save(profile, save_path)

		_set_new_project_defaults()

		for i: int in project_presets_option_button.item_count:
			var item_id: int = project_presets_option_button.get_item_id(i)
			if item_id >= 0 and item_id < loaded_preset_profiles.size():
				if loaded_preset_profiles[item_id].profile_name == preset_name:
					project_presets_option_button.selected = i
					_on_new_project_option_button_item_selected(i)
					break
		dialog.call_deferred("queue_free")

	dialog.confirmed.connect(confirm_lambda)
	line_edit.text_submitted.connect(func(_text: String) -> void:
				confirm_lambda.call())

	add_child(dialog)
	dialog.popup_centered(Vector2i(250, 80))
	line_edit.grab_focus()


func _on_delete_profile_preset_button_pressed() -> void:
	var index: int = project_presets_option_button.selected
	if index == -1:
		return

	var id: int = project_presets_option_button.get_item_id(index)
	if id < default_profiles_count or id >= loaded_preset_profiles.size():
		return

	var profile: ProjectProfile = loaded_preset_profiles[id]
	var path: String = get_user_profiles_path().path_join(profile.profile_name.validate_filename() + ".tres")
	if FileAccess.file_exists(path):
		DirAccess.remove_absolute(path)

	_set_new_project_defaults()


func _on_new_project_setting_changed() -> void:
	project_presets_option_button.selected = -1

	save_profile_preset_button.disabled = false
	save_profile_preset_button.modulate = get_theme_color("icon_enabled", "StartupScreen")

	delete_profile_preset_button.disabled = true
	delete_profile_preset_button.modulate = get_theme_color("icon_disabled", "StartupScreen")



class RecentProjectData:
	var path: String
	var title: String
	var modified_time: int
	var original_index: int


	func _init(_path: String, _title: String, _modified_time: int, _original_index: int) -> void:
		path = _path
		title = _title
		modified_time = _modified_time
		original_index = _original_index
