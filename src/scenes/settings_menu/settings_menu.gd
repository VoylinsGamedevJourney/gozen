class_name SettingsPanel
extends Control


@export var panel_label: Label
@export var side_bar_vbox: VBoxContainer
@export var settings_vbox: VBoxContainer


var sections: Dictionary[String, GridContainer] = {}
var side_bar_button_group: ButtonGroup = ButtonGroup.new()



func _input(event: InputEvent) -> void:
	if event.is_action_pressed("ui_cancel"):
		_on_close_button_pressed()


func _on_close_button_pressed() -> void:
	Settings.save()
	PopupManager.close_popup(PopupManager.POPUP.SETTINGS)


func set_mode_editor_settings() -> void:
	panel_label.text = "title_editor_settings"

	# Data needed for some settings options.
	var language_data: Dictionary[String, String] = Settings.get_languages()
	var theme_data: Dictionary[String, SettingsData.THEME] = Settings.get_themes()
	var audio_waveform_style_data: Dictionary[String, SettingsData.AUDIO_WAVEFORM_STYLE] = Settings.get_audio_waveform_styles()
	var empty_space_mod_data: Dictionary[String, int] = Settings.get_delete_empty_modifiers()

	# Adding the Appearance section.
	_add_section("title_appearance", [
		_create_label("setting_language"),
		_create_option_button(
				language_data, 
				language_data.values().find(Settings.get_language()),
				Settings.set_language,
				TYPE_STRING,
				""),
		_create_label("setting_theme"),
		_create_option_button(
				theme_data,
				theme_data.values().find(Settings.get_theme()),
				Settings.set_theme,
				TYPE_INT,
				"setting_tooltip_theme"),
		_create_label("setting_show_menu_bar"),
		_create_check_button(
				Settings.get_show_menu_bar(),
				Settings.set_show_menu_bar,
				""),
		_create_label("setting_waveform_style"),
		_create_option_button(
				audio_waveform_style_data,
				audio_waveform_style_data.values().find(Settings.get_audio_waveform_style()),
				Settings.set_audio_waveform_style,
				TYPE_INT,
				"setting_tooltip_theme"),
	])

	# Adding the Defaults section.
	_add_section("title_defaults", [
		_create_label("setting_default_image_duration"),
		_create_spinbox(
				Settings.get_image_duration(),
				1, 100, false, true,
				Settings.set_image_duration,
				"setting_tooltip_duration_in_frames"
		),
		_create_label("setting_default_color_duration"),
		_create_spinbox(
				Settings.get_color_duration(),
				1, 100, false, true,
				Settings.set_color_duration,
				"setting_tooltip_duration_in_frames"
		),
		_create_label("setting_default_text_duration"),
		_create_spinbox(
				Settings.get_text_duration(),
				1, 100, false, true,
				Settings.set_text_duration,
				"setting_tooltip_duration_in_frames"
		),
		_create_label("setting_default_project_resolution"),
		_create_default_resolution_hbox(),
		_create_label("setting_default_project_framerate"),
		_create_spinbox(
				Settings.get_default_framerate(),
				1, 100, false, true,
				Settings.set_default_framerate,
				"setting_tooltip_default_project_framerate"
		),
	])

	# Adding the Timeline section.
	_add_section("title_timeline", [
		_create_label("setting_default_track_amount"),
		_create_spinbox(
				Settings.get_tracks_amount(),
				1, 32, false, false,
				Settings.set_default_framerate,
				""
		),
		_create_label("setting_pause_after_dragging"),
		_create_check_button(
				Settings.get_pause_after_drag(),
				Settings.set_pause_after_drag,
				""),
		_create_label("setting_delete_empty_space_mod"),
		_create_option_button(
				empty_space_mod_data, 
				empty_space_mod_data.values().find(Settings.get_delete_empty_modifier()),
				Settings.set_delete_empty_modifier,
				TYPE_INT,
				"setting_tooltip_delete_empty_space_mod"),
	])

	# Adding the Extras section.
	_add_section("title_extras", [
		_create_label("setting_check_version"),
		_create_check_button(
				Settings.get_check_version(),
				Settings.set_check_version,
				"setting_tooltip_check_version"),
		_create_label("setting_auto_save"),
		_create_check_button(
				Settings.get_auto_save(),
				Settings.set_auto_save,
				"setting_tooltip_auto_save"),
	])


func set_mode_project_settings() -> void:
	panel_label.text = "title_project_settings"
	_add_section("title_appearance", [
		_create_label("setting_background_color"),
		_create_color_picker(
				Project.get_background_color(),
				Project.set_background_color,
				"tooltip_setting_background_color"),
	])


func _create_default_resolution_hbox() -> HBoxContainer:
	# Resolution HBOX contains 2 labels and 2 spinboxes. That's why we created
	# a separate function to deal with creating this node instance.
	var resolution_hbox: HBoxContainer = HBoxContainer.new()
	var x_label: Label = Label.new()
	var y_label: Label = Label.new()

	x_label.text = "X:"
	y_label.text = "Y:"
	x_label.tooltip_text = "setting_tooltip_default_project_resolution_x"
	y_label.tooltip_text = "setting_tooltip_default_project_resolution_y"

	resolution_hbox.add_child(x_label)
	resolution_hbox.add_child(_create_spinbox(
			Settings.get_default_resolution_x(),
			1, 100, false, true,
			Settings.set_default_resolution_x,
			"setting_tooltip_default_project_resolution_x"))
	resolution_hbox.add_child(y_label)
	resolution_hbox.add_child(_create_spinbox(
			Settings.get_default_resolution_y(),
			1, 100, false, true,
			Settings.set_default_resolution_y,
			"setting_tooltip_default_project_resolution_y"))

	return resolution_hbox


func _show_section(section_name: String) -> void:
	for section: String in sections.keys():
		sections[section].visible = section == section_name


func _add_side_bar_option(section_name: String) -> void:
	var button: Button = Button.new()
	
	button.text = section_name
	button.toggle_mode = true
	button.button_group = side_bar_button_group
	button.theme_type_variation = "side_bar_button"
	button.button_pressed = side_bar_vbox.get_child_count() == 0

	Toolbox.connect_func(button.pressed, _show_section.bind(section_name))
	side_bar_vbox.add_child(button)


func _add_section(section_name: String, options: Array[Node]) -> void:
	var grid: GridContainer = GridContainer.new()

	grid.columns = 2
	grid.set_anchors_preset(PRESET_FULL_RECT)
	
	for node: Node in options:
		grid.add_child(node)

	settings_vbox.add_child(grid)
	sections[section_name] = grid
	grid.visible = settings_vbox.get_child_count() == 1

	_add_side_bar_option(section_name)


func _create_label(title: String) -> Label:
	var label: Label = Label.new()

	label.text = title
	label.size_flags_horizontal = Control.SIZE_EXPAND_FILL

	return label


func _create_option_button(options: Dictionary, default: int, callable: Callable, type: Variant.Type, tooltip: String) -> OptionButton:
	# Options should have the option text as key and the value to pass to
	# callable as value.
	var option_button: OptionButton = OptionButton.new()

	Toolbox.connect_func(option_button.item_selected, _option_button_item_selected.bind(option_button, callable, type))

	var i: int = 0
	for option: String in options:
		option_button.add_item(option)
		option_button.set_item_metadata(i, options[option])
		i += 1

	option_button.selected = default
	option_button.tooltip_text = tooltip
	option_button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	option_button.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND

	return option_button


func _option_button_item_selected(id: int, option_button: OptionButton, callable: Callable, type: Variant.Type) -> void:
	@warning_ignore_start("unsafe_cast")
	if type == TYPE_INT:
		callable.call(option_button.get_item_metadata(id) as int)
	elif type == TYPE_FLOAT:
		callable.call(option_button.get_item_metadata(id) as float)
	elif type == TYPE_STRING:
		callable.call(option_button.get_item_metadata(id) as String)
	
	if callable == Settings.set_language:
		Settings.set_language(option_button.get_item_metadata(id) as String)
	@warning_ignore_restore("unsafe_cast")


func _create_check_button(default: bool, callable: Callable, tooltip: String) -> CheckButton:
	var check_button: CheckButton = CheckButton.new()

	check_button.flat = true
	check_button.button_pressed = default
	check_button.tooltip_text = tooltip
	check_button.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	Toolbox.connect_func(check_button.toggled, callable)

	check_button.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
	check_button.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND

	return check_button


func _create_spinbox(default: float, min_value: float, max_value: float, allow_lesser: bool, allow_greater: bool, callable: Callable, tooltip: String) -> SpinBox:
	var spinbox: SpinBox = SpinBox.new()

	spinbox.allow_greater = allow_greater
	spinbox.allow_lesser = allow_lesser
	spinbox.min_value = min_value
	spinbox.max_value = max_value

	# Value needs to go last else it may cause problems if the value
	# wasn't within the boundaries of min/max.
	spinbox.value = default
	spinbox.tooltip_text = tooltip
	spinbox.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	Toolbox.connect_func(spinbox.value_changed, callable)

	spinbox.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	spinbox.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND

	return spinbox


func _create_color_picker(default: Color, callable: Callable, tooltip: String) -> ColorPickerButton:
	var color_picker: ColorPickerButton = ColorPickerButton.new()

	color_picker.color = default
	color_picker.tooltip_text = tooltip
	color_picker.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	Toolbox.connect_func(color_picker.color_changed, callable)

	color_picker.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	color_picker.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND

	return color_picker

