class_name SettingsPanel
extends Control
# TODO: Add a search bar to find settings more easily.
# TODO: Add "reset to default" button for everything.
# TODO: Add "reset to default" button for setting.
# TODO: Make certain that resolution input is mod-2, if entering a non mod-2
# number, we can maybe turn the spinbox orange to indicate an issue.

enum MODE { EDITOR_SETTINGS, PROJECT_SETTINGS }

@export var panel_label: Label
@export var side_bar_vbox: VBoxContainer
@export var settings_vbox: VBoxContainer


var sections: Dictionary[String, GridContainer] = {}
var side_bar_button_group: ButtonGroup = ButtonGroup.new()

var listening_active: bool = false
var listening_action: String = ""
var listening_index: int = -1
var listening_button: Button = null



func _input(event: InputEvent) -> void:
	if listening_active and listening_button != null:
		get_viewport().set_input_as_handled()

		if event.is_action_pressed("ui_cancel"):
			_stop_listening()
			return

		if (event is InputEventKey and event.is_pressed()) or (event is InputEventMouseButton and event.is_pressed()):
			Settings.set_shortcut_event_at_index(listening_action, listening_index, event)
			listening_button.text = _get_event_text(event)
			_stop_listening()
	elif event.is_action_pressed("ui_cancel"):
		_on_close_button_pressed()


func _on_close_button_pressed() -> void:
	_stop_listening()
	Settings.save()
	PopupManager.close_popup(PopupManager.POPUP.SETTINGS)
	PopupManager.close_popup(PopupManager.POPUP.PROJECT_SETTINGS)


func set_mode(mode: MODE) -> void:
	var menu_options: Dictionary[String, Array] = {}

	match mode:
		MODE.EDITOR_SETTINGS: menu_options = get_settings_menu_options()
		MODE.PROJECT_SETTINGS: menu_options = get_project_settings_menu_options()

	for section_name: String in menu_options:
		var section_grid: Node = _create_section(section_name)

		for node: Node in menu_options[section_name]:
			if !node.get_parent():
				section_grid.add_child(node)


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

	button.pressed.connect(_show_section.bind(section_name))
	side_bar_vbox.add_child(button)


func _create_section(section_name: String) -> GridContainer:
	var grid: GridContainer = GridContainer.new()

	grid.columns = 2
	grid.set_anchors_preset(PRESET_FULL_RECT)

	settings_vbox.add_child(grid)
	sections[section_name] = grid
	grid.visible = settings_vbox.get_child_count() == 1

	_add_side_bar_option(section_name)
	return grid


func get_settings_menu_options() -> Dictionary[String, Array]:
	panel_label.text = "title_editor_settings"

	# Creating the marker nodes
	var marker_nodes: Array = []
	var marker_texts: Array = [
		"settings_marker_one", "settings_marker_two", "settings_marker_three",
		"settings_marker_four", "settings_marker_five"]
	marker_nodes.append(create_header("setting_header_markers"))
	marker_nodes.append(Control.new())

	for i: int in marker_texts.size():
		marker_nodes.append(create_label(marker_texts[i]))
		marker_nodes.append(create_marker_setting(i))

	# Creating the shortcut nodes
	var shortcut_nodes: Array = []
	var action_keys: PackedStringArray = Settings.data.shortcuts.keys()

	shortcut_nodes.append(create_header("setting_header_shortcuts"))
	shortcut_nodes.append(Control.new())
	action_keys.sort()

	for action: String in action_keys:
		shortcut_nodes.append(create_label(action.capitalize()))
		shortcut_nodes.append(create_shortcut_buttons(action))

	return {
		"title_appearance" = [
			create_header("setting_header_display"), Control.new(),
			create_label("setting_language"),
			create_option_button(
					Settings.get_languages(),
					Settings.get_languages().values().find(Settings.get_language()),
					Settings.set_language,
					TYPE_STRING,
					"setting_tooltip_language"),
			create_label("setting_display_scale"),
			create_spinbox(
					Settings.get_display_scale_int(),
					50, 300, 5, false, false,
					Settings.set_display_scale_int,
					"setting_tooltip_display_scale",
					"%"),
			create_label("setting_theme"),
			create_option_button(
					Settings.get_themes(),
					Settings.get_themes().values().find(Settings.get_theme_path()),
					Settings.set_theme_path,
					TYPE_STRING,
					"setting_tooltip_theme"),
			create_label("setting_show_menu_bar"),
			create_check_button(
					Settings.get_show_menu_bar(),
					Settings.set_show_menu_bar,
					"setting_tooltip_show_menu_bar"),
			create_header("setting_header_waveform"), Control.new(),
			create_label("setting_waveform_style"),
			create_option_button(
					Settings.get_audio_waveform_styles(),
					Settings.get_audio_waveform_styles().values().find(Settings.get_audio_waveform_style()),
					Settings.set_audio_waveform_style,
					TYPE_INT,
					"setting_tooltip_theme"),
			create_label("setting_waveform_amp"),
			create_spinbox(
					Settings.get_audio_waveform_amp(),
					0.5, 6, 0.5, false, false,
					Settings.set_audio_waveform_amp,
					"setting_tooltip_audio_waveform_amp",),
			create_header("setting_header_dialogues"), Control.new(),
			create_label("setting_use_native_dialog"),
			create_check_button(
					Settings.get_use_native_dialog(),
					Settings.set_use_native_dialog,
					"setting_tooltip_use_native_dialog")
		],

		"title_defaults" = [
			create_header("setting_header_default_durations"), Control.new(),
			create_label("setting_default_image_duration"),
			create_spinbox(
					Settings.get_image_duration(),
					1, 100, 1, false, true,
					Settings.set_image_duration,
					"setting_tooltip_duration_in_frames"),
			create_label("setting_default_color_duration"),
			create_spinbox(
					Settings.get_color_duration(),
					1, 100, 1, false, true,
					Settings.set_color_duration,
					"setting_tooltip_duration_in_frames"),
			create_label("setting_default_text_duration"),
			create_spinbox(
					Settings.get_text_duration(),
					1, 100, 1, false, true,
					Settings.set_text_duration,
					"setting_tooltip_duration_in_frames"),
			create_label("setting_default_project_resolution"),
			create_default_resolution_hbox(),
			create_label("setting_default_project_framerate"),
			create_spinbox(
					Settings.get_default_framerate(),
					1, 100, 1, false, true,
					Settings.set_default_framerate,
					"setting_tooltip_default_project_framerate"),
			create_label("setting_default_use_proxies"),
			create_check_button(
				Settings.get_use_proxies(),
				Settings.set_use_proxies,
				"setting_tooltip_default_use_proxies"),
		],

		"title_timeline" = [
			create_header("setting_header_default_timeline"), Control.new(),
			create_label("setting_default_track_amount"),
			create_spinbox(
					Settings.get_tracks_amount(),
					1, 32, 1, false, false,
					Settings.set_tracks_amount,
					"setting_tooltip_default_track_amount"),
			create_header("setting_header_timeline_controls"), Control.new(),
			create_label("setting_pause_after_dragging"),
			create_check_button(
					Settings.get_pause_after_drag(),
					Settings.set_pause_after_drag,
					"setting_tooltip_pause_after_dragging"),
			create_label("setting_delete_empty_space_mod"),
			create_option_button(
					Settings.get_delete_empty_modifiers(),
					Settings.get_delete_empty_modifiers().values().find(Settings.get_delete_empty_modifier()),
					Settings.set_delete_empty_modifier,
					TYPE_INT,
					"setting_tooltip_delete_empty_space_mod"),
			create_header("setting_header_timeline_addons"), Control.new(),
			create_label("setting_show_time_mode_bar"),
			create_check_button(
					Settings.get_show_time_mode_bar(),
					Settings.set_show_time_mode_bar,
					"setting_tooltip_show_time_mode_bar"),
		],

		"title_markers" = marker_nodes,

		"title_extras" = [
			create_header("setting_header_extras"), Control.new(),
			create_label("setting_check_version"),
			create_check_button(
					Settings.get_check_version(),
					Settings.set_check_version,
					"setting_tooltip_check_version"),
			create_label("setting_auto_save"),
			create_check_button(
					Settings.get_auto_save(),
					Settings.set_auto_save,
					"setting_tooltip_auto_save")
		],

		"title_shortcuts" = shortcut_nodes,

	}


func get_project_settings_menu_options() -> Dictionary[String, Array]:
	panel_label.text = "title_project_settings"

	return {
		"title_appearance" = [
			create_header("setting_header_project_appearance"), Control.new(),
			create_label("setting_background_color"),
			create_color_picker(
					Project.get_background_color(),
					Project.set_background_color,
					"tooltip_setting_background_color"),
		],
	}


func create_header(title: String) -> Control:
	var header: Label = Label.new()

	header.text = title
	header.theme_type_variation = "title_label"
	header.custom_minimum_size.y = 30
	header.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	header.size_flags_horizontal = Control.SIZE_EXPAND_FILL

	return header


func create_label(title: String) -> Label:
	var label: Label = Label.new()

	label.text = title
	label.size_flags_horizontal = Control.SIZE_EXPAND_FILL

	return label


func create_option_button(options: Dictionary, default: int, callable: Callable, type: Variant.Type, tooltip: String) -> OptionButton:
	# Options should have the option text as key and the value to pass to
	# callable as value.
	var option_button: OptionButton = OptionButton.new()

	option_button.item_selected.connect(_option_button_item_selected.bind(option_button, callable, type))

	var i: int = 0

	for option: String in options:
		if option == "":
			option_button.add_separator()
		else:
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


func create_check_button(default: bool, callable: Callable, tooltip: String) -> CheckButton:
	var check_button: CheckButton = CheckButton.new()

	check_button.flat = true
	check_button.button_pressed = default
	check_button.tooltip_text = tooltip
	check_button.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	check_button.toggled.connect(callable)

	check_button.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
	check_button.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND

	return check_button


func create_spinbox(default: float, min_value: float, max_value: float, step: float, allow_lesser: bool, allow_greater: bool, callable: Callable, tooltip: String, suffix: String = "") -> SpinBox:
	var spinbox: SpinBox = SpinBox.new()

	spinbox.allow_greater = allow_greater
	spinbox.allow_lesser = allow_lesser
	spinbox.min_value = min_value
	spinbox.max_value = max_value
	spinbox.step = step
	spinbox.suffix = suffix

	# Value needs to go last else it may cause problems if the value
	# wasn't within the boundaries of min/max.
	spinbox.value = default
	spinbox.tooltip_text = tooltip
	spinbox.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	spinbox.value_changed.connect(callable)

	spinbox.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	spinbox.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND

	return spinbox


func create_color_picker(default: Color, callable: Callable, tooltip: String) -> ColorPickerButton:
	var color_picker: ColorPickerButton = ColorPickerButton.new()

	color_picker.color = default
	color_picker.tooltip_text = tooltip
	color_picker.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	color_picker.color_changed.connect(callable)

	color_picker.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	color_picker.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND

	return color_picker


func create_default_resolution_hbox() -> HBoxContainer:
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
	resolution_hbox.add_child(create_spinbox(
			Settings.get_default_resolution_x(),
			1, 100, 1, false, true,
			Settings.set_default_resolution_x,
			"setting_tooltip_default_project_resolution_x"))
	resolution_hbox.add_child(y_label)
	resolution_hbox.add_child(create_spinbox(
			Settings.get_default_resolution_y(),
			1, 100, 1, false, true,
			Settings.set_default_resolution_y,
			"setting_tooltip_default_project_resolution_y"))

	return resolution_hbox


func create_marker_setting(index: int) -> HBoxContainer:
	# Marker text
	var line_edit: LineEdit = LineEdit.new()
	var name_function: Callable = func(text: String) -> void:
			Settings.set_marker_name(index, text)

	line_edit.text = Settings.get_marker_name(index)
	line_edit.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	line_edit.text_submitted.connect(name_function)
	line_edit.focus_exited.connect(name_function.bind(line_edit.text))

	# Marker color
	var color_picker: ColorPickerButton = create_color_picker(
		Settings.get_marker_color(index),
		Settings.set_marker_color.bind(index),
		"tooltip_setting_marker_color"
	)

	# Bundling
	var hbox: HBoxContainer = HBoxContainer.new()

	hbox.add_child(line_edit)
	hbox.add_child(color_picker)
	hbox.size_flags_horizontal = Control.SIZE_EXPAND_FILL

	return hbox


func create_shortcut_buttons(action: String) -> HBoxContainer:
	var events: Array[InputEvent] = Settings.get_events_for_action(action)
	var hbox: HBoxContainer = HBoxContainer.new()

	hbox.size_flags_horizontal = SIZE_EXPAND_FILL

	for i: int in 2:
		var button: Button = Button.new()

		button.size_flags_horizontal = SIZE_EXPAND_FILL
		button.toggle_mode = true
		button.text = _get_event_text(events[i])
		button.tooltip_text = tr("tooltip_setting_shortcut")
		button.pressed.connect(_on_shortcut_button_pressed.bind(button, action, i))
		hbox.add_child(button)

	return hbox


func _on_shortcut_button_pressed(button: Button, action: String, index: int) -> void:
	# We should only be able to listen to one button each
	if listening_active and listening_button != null and listening_button != button:
		listening_button.button_pressed = false
		listening_button.text = _get_event_text(Settings.get_events_for_action(listening_action)[listening_index])

	listening_active = true
	listening_action = action
	listening_index = index
	listening_button = button
	listening_button.text = "Press any key..."


func _stop_listening() -> void:
	if listening_button != null:
		var events: Array[InputEvent] = Settings.get_events_for_action(listening_action)

		listening_button.button_pressed = false
		listening_button.text = _get_event_text(events[listening_index])
	listening_active = false
	listening_button = null
	listening_action = ""
	listening_index = -1


func _get_event_text(event: InputEvent) -> String:
	if event == null: return "None"
	elif event is InputEventKey:
		return event.as_text_physical_keycode()
	return event.as_text()

