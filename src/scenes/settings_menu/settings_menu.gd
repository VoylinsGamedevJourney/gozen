class_name SettingsPanel
extends Control

enum MODE { EDITOR_SETTINGS, PROJECT_SETTINGS }


@export var panel_label: Label
@export var side_bar_vbox: VBoxContainer
@export var search_line_edit: LineEdit
@export var settings_vbox: VBoxContainer


var sections: Dictionary[String, GridContainer] = {}
var side_bar_button_group: ButtonGroup = ButtonGroup.new()

var listening_active: bool = false
var listening_action: String = ""
var listening_index: int = -1
var listening_button: Button = null

var _editor_settings: bool = false



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
	PopupManager.close(PopupManager.SETTINGS)
	PopupManager.close(PopupManager.PROJECT_SETTINGS)


func set_mode(mode: MODE) -> void:
	var menu_options: Dictionary[String, Array] = {}
	match mode:
		MODE.EDITOR_SETTINGS:
			menu_options = get_settings_menu_options()
			_editor_settings = true
		MODE.PROJECT_SETTINGS:
			menu_options = get_project_settings_menu_options()
			_editor_settings = false

	for section_name: String in menu_options:
		var section_grid: Node = _create_section(section_name)
		for node: Node in menu_options[section_name]:
			if !node.get_parent():
				section_grid.add_child(node)


func _show_section(section_name: String) -> void:
	for section: String in sections.keys():
		sections[section].visible = section == section_name
	_on_search_line_edit_text_changed(search_line_edit.text)


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
	var default_settings: SettingsData = SettingsData.new()
	panel_label.text = tr("Editor settings")

	# Creating the marker nodes.
	var marker_nodes: Array = []
	var marker_texts: PackedStringArray = [
		tr("Marker one"), tr("Marker two"), tr("Marker three"),
		tr("Marker four"), tr("Marker five")]
	marker_nodes.append(create_header(tr("Markers")))
	marker_nodes.append(Control.new())

	for i: int in marker_texts.size():
		marker_nodes.append(create_label(marker_texts[i]))
		marker_nodes.append(create_marker_setting(i))

	# Creating the shortcut nodes.
	var shortcut_nodes: Array = []
	var action_keys: PackedStringArray = Settings.data.shortcuts.keys()
	shortcut_nodes.append(create_header(tr("Shortcuts")))
	shortcut_nodes.append(Control.new())
	action_keys.sort()

	for action: String in action_keys:
		shortcut_nodes.append(create_label(action.capitalize()))
		shortcut_nodes.append(create_shortcut_buttons(action))

	return {
		tr("Appearance"): [
			create_header(tr("Display")), Control.new(),
			create_label(tr("Language")),
			create_option_button(
					Settings.get_languages(),
					Settings.get_languages().values().find(Settings.get_language()),
					Settings.get_languages().values().find("en"),
					Settings.set_language,
					TYPE_STRING),
			create_label(tr("Display scale")),
			create_spinbox(
					Settings.get_display_scale_int(),
					100,
					50, 300, 5, false, false,
					Settings.set_display_scale_int,
					"%"),
			create_label(tr("Editor theme")),
			create_option_button(
					Settings.get_themes(),
					Settings.get_themes().values().find(Settings.get_theme_path()),
					Settings.get_themes().values().find(Library.THEME_DEFAULT),
					Settings.set_theme_path,
					TYPE_STRING),
			create_label(tr("Base color")),
			create_color_picker(
					Settings.get_base_color(),
					default_settings.base_color,
					Settings.set_base_color,
					tr("The base color of the editor UI.")),
			create_label(tr("Accent color")),
			create_color_picker(
					Settings.get_accent_color(),
					default_settings.accent_color,
					Settings.set_accent_color,
					tr("The highlight/accent color of the editor UI.")),
			create_label(tr("Show menu bar")),
			create_check_button(
					Settings.get_show_menu_bar(),
					default_settings.show_menu_bar,
					Settings.set_show_menu_bar),
			create_header(tr("Audio waveforms")), Control.new(),
			create_label(tr("Waveform style")),
			create_option_button(
					Settings.get_audio_waveform_styles(),
					Settings.get_audio_waveform_styles().values().find(Settings.get_audio_waveform_style()),
					Settings.get_audio_waveform_styles().values().find(default_settings.audio_waveform_style),
					Settings.set_audio_waveform_style,
					TYPE_INT),
			create_label(tr("Waveform amplifier")),
			create_spinbox(
					Settings.get_audio_waveform_amp(),
					default_settings.audio_waveform_amp,
					0.5, 6, 0.5, false, false,
					Settings.set_audio_waveform_amp,
					"",
					tr("Sometimes the waveforms aren't very clear due to audio levels being too low, with this setting you can adjust their intensity")),
			create_header(tr("Dialogs")), Control.new(),
			create_label(tr("Use native dialogs")),
			create_check_button(
					Settings.get_use_native_dialog(),
					default_settings.use_native_dialog,
					Settings.set_use_native_dialog)
		],

		tr("Defaults"): [
			create_header(tr("Default durations")), Control.new(),
			create_label(tr("Default image duration")),
			create_spinbox(
					Settings.get_image_duration(),
					default_settings.image_duration,
					1, 100, 1, false, true,
					Settings.set_image_duration,
					"",
					tr("Duration in frames per second.")),
			create_label(tr("Default color duration")),
			create_spinbox(
					Settings.get_color_duration(),
					default_settings.color_duration,
					1, 100, 1, false, true,
					Settings.set_color_duration,
					"",
					tr("Duration in frames per second.")),
			create_label(tr("Default text duration")),
			create_spinbox(
					Settings.get_text_duration(),
					default_settings.text_duration,
					1, 100, 1, false, true,
					Settings.set_text_duration,
					"",
					tr("Duration in frames per second.")),
			create_label(tr("Project resolution")),
			create_default_resolution_hbox(default_settings),
			create_label(tr("Project frame-rate")),
			create_spinbox(
					Settings.get_default_framerate(),
					default_settings.default_framerate,
					1, 100, 1, false, true,
					Settings.set_default_framerate),
		],

		tr("Timeline"): [
			create_header(tr("Timeline settings")), Control.new(),
			create_label(tr("Default track amount")),
			create_spinbox(
					Settings.get_tracks_amount(),
					default_settings.tracks_amount,
					1, 32, 1, false, false,
					Settings.set_tracks_amount),
			create_label(tr("Track height")),
			create_spinbox(
					Settings.get_track_height(),
					default_settings.tracks_height,
					20, 60, 1, false, false,
					Settings.set_track_height),
			create_header(tr("Timeline controls")), Control.new(),
			create_label(tr("Pause after dragging")),
			create_check_button(
					Settings.get_pause_after_drag(),
					default_settings.pause_after_drag,
					Settings.set_pause_after_drag,
					tr("Setting this will pause playback after having dragged the playhead around.")),
			create_label(tr("Empty space delete modifier")),
			create_option_button(
					Settings.get_delete_empty_modifiers(),
					Settings.get_delete_empty_modifiers().values().find(Settings.get_delete_empty_modifier()),
					Settings.get_delete_empty_modifiers().values().find(default_settings.delete_empty_modifier),
					Settings.set_delete_empty_modifier,
					TYPE_INT,
					tr("The modifier you want to easily delete empty space between clips.")),
			create_header(tr("Addons")), Control.new(),
			create_label(tr("Show mode bar")),
			create_check_button(
					Settings.get_show_time_mode_bar(),
					default_settings.show_time_mode_bar,
					Settings.set_show_time_mode_bar,
					tr("The mode bar is the bar on the left of the timeline with buttons for changing the current timeline mode.")),
		],

		tr("Performance"): [
			create_header(tr("Video Decoding")), Control.new(),
			create_label(tr("Smart Seek Threshold")),
			create_spinbox(
					Settings.get_video_smart_seek_threshold(),
					default_settings.video_smart_seek_threshold,
					0, 500, 1, false, true,
					Settings.set_video_smart_seek_threshold,
					"",
					tr("Defines how many frames the decoder will sequentially read ahead instead of performing a full seek operation. Higher values prevent lag during short jumps but use more CPU.")),
			create_label(tr("Video Cache Size")),
			create_spinbox(
					Settings.get_video_cache_size(),
					default_settings.video_cache_size,
					0, 1000, 1, false, true,
					Settings.set_video_cache_size,
					"",
					tr("The maximum number of decoded frames to keep in RAM. Higher values enable smoother backward seeking and scrubbing but increase memory usage.")),
			create_label(tr("Use proxies")),
			create_check_button(
				Settings.get_use_proxies(),
				default_settings.use_proxies,
				Settings.set_use_proxies),
			create_label(tr("Proxies save path")),
			create_line_edit(
				Settings.get_proxies_path(),
				default_settings.proxies_path,
				Settings.set_proxies_path,
				tr("Changing this setting should be done with a path which points to an already existing folder. All previously made proxy clips will need to be generated again and deleted manually from the previous folder.")),
		],

		tr("Markers"): marker_nodes,

		tr("Extras"): [
			create_header(tr("Extras")), Control.new(),
			create_label(tr("Check version")),
			create_check_button(
					Settings.get_check_version(),
					default_settings.check_version,
					Settings.set_check_version),
			create_label(tr("Auto save")),
			create_check_button(
					Settings.get_auto_save(),
					default_settings.auto_save,
					Settings.set_auto_save)
		],

		tr("Shortcuts"): shortcut_nodes,
	}


func get_project_settings_menu_options() -> Dictionary[String, Array]:
	panel_label.text = tr("Project settings")
	return {
		tr("Appearance"): [
			create_header(tr("Appearance")), Control.new(),
			create_label(tr("Background color")),
			create_color_picker(
					Project.data.background_color,
					Color.BLACK,
					Project.set_background_color,
					tr("The background color when no clips are displayed.")),
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


func wrap_with_reset_button(control: Control, current_value: Variant, reset_value: Variant) -> HBoxContainer:
	var hbox: HBoxContainer = HBoxContainer.new()
	var reset_button: TextureButton = TextureButton.new()
	reset_button.name = "ResetButton"
	reset_button.texture_normal = preload(Library.ICON_REFRESH)
	reset_button.tooltip_text = tr("Reset to default")
	reset_button.ignore_texture_size = true
	reset_button.stretch_mode = TextureButton.STRETCH_KEEP_ASPECT_CENTERED
	reset_button.custom_minimum_size = Vector2(14, 14)
	reset_button.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	reset_button.visible = not _is_same_value(current_value, reset_value)

	hbox.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	hbox.add_child(reset_button)
	hbox.add_child(control)
	return hbox


func create_option_button(options: Dictionary, current_value: int, reset_value: int, callable: Callable, type: Variant.Type, tooltip: String = "") -> Control:
	var option_button: OptionButton = OptionButton.new()
	var i: int = 0
	for option: String in options:
		if option == "":
			option_button.add_separator()
		else:
			option_button.add_item(option)
			option_button.set_item_metadata(i, options[option])
		i += 1

	option_button.selected = current_value
	option_button.tooltip_text = tooltip
	option_button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	option_button.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND

	var hbox: HBoxContainer = wrap_with_reset_button(option_button, current_value, reset_value)
	var reset_btn: TextureButton = hbox.get_node("ResetButton")
	var update_value: Callable = (func(id: int) -> void:
			reset_btn.visible = not _is_same_value(id, reset_value)
			_option_button_item_selected(id, option_button, callable, type))

	option_button.item_selected.connect(update_value)
	reset_btn.pressed.connect(func() -> void:
			option_button.selected = reset_value
			option_button.item_selected.emit(reset_value))
	return hbox


func _option_button_item_selected(id: int, option_button: OptionButton, callable: Callable, type: Variant.Type) -> void:
	if type == TYPE_INT:
		callable.call(option_button.get_item_metadata(id) as int)
	elif type == TYPE_FLOAT:
		callable.call(option_button.get_item_metadata(id) as float)
	elif type == TYPE_STRING:
		callable.call(option_button.get_item_metadata(id) as String)


func create_line_edit(current_value: String, reset_value: String, callable: Callable, tooltip: String = "") -> Control:
	var line_edit: LineEdit = LineEdit.new()
	line_edit.flat = true
	line_edit.text = current_value
	line_edit.tooltip_text = tooltip
	line_edit.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	line_edit.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND

	var hbox: HBoxContainer = wrap_with_reset_button(line_edit, current_value, reset_value)
	var reset_btn: TextureButton = hbox.get_node("ResetButton")
	var update_value:Callable = (func(value: String) -> void:
			reset_btn.visible = not _is_same_value(value, reset_value)
			callable.call(value))

	line_edit.text_submitted.connect(update_value)
	line_edit.focus_exited.connect(func() -> void: update_value.call(line_edit.text))
	reset_btn.pressed.connect(func() -> void:
			line_edit.text = reset_value
			update_value.call(reset_value))
	return hbox


func create_check_button(current_value: bool, reset_value: bool, callable: Callable, tooltip: String = "") -> Control:
	var check_button: CheckButton = CheckButton.new()
	check_button.flat = true
	check_button.button_pressed = current_value
	check_button.tooltip_text = tooltip
	check_button.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
	check_button.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND

	var hbox: HBoxContainer = wrap_with_reset_button(check_button, current_value, reset_value)
	var reset_btn: TextureButton = hbox.get_node("ResetButton")
	var update_value: Callable = (func(value: bool) -> void:
			reset_btn.visible = not _is_same_value(value, reset_value)
			callable.call(value))

	check_button.toggled.connect(update_value)
	reset_btn.pressed.connect(func() -> void:
			if check_button.button_pressed != reset_value:
				check_button.button_pressed = reset_value
			else:
				update_value.call(reset_value))

	hbox.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
	return hbox


func create_spinbox(current_value: float, reset_value: float, min_value: float, max_value: float, step: float, allow_lesser: bool, allow_greater: bool, callable: Callable, suffix: String = "", tooltip: String = "") -> Control:
	var spinbox: SpinBox = SpinBox.new()
	spinbox.allow_greater = allow_greater
	spinbox.allow_lesser = allow_lesser
	spinbox.min_value = min_value
	spinbox.max_value = max_value
	spinbox.step = step
	spinbox.suffix = suffix

	# Value needs to go last else it may cause problems if the value
	# wasn't within the boundaries of min/max.
	spinbox.value = current_value
	spinbox.tooltip_text = tooltip
	spinbox.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	spinbox.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND

	var hbox: HBoxContainer = wrap_with_reset_button(spinbox, current_value, reset_value)
	var reset_btn: TextureButton = hbox.get_node("ResetButton")
	var update_value: Callable = (func(value: float) -> void:
			reset_btn.visible = not _is_same_value(value, reset_value)
			callable.call(value))

	spinbox.value_changed.connect(update_value)
	reset_btn.pressed.connect(func() -> void:
			if not _is_same_value(spinbox.value, reset_value):
				spinbox.value = reset_value
			else:
				update_value.call(reset_value))
	return hbox


func create_color_picker(current_value: Color, reset_value: Color, callable: Callable, tooltip: String = "") -> Control:
	var color_picker: ColorPickerButton = ColorPickerButton.new()
	color_picker.color = current_value
	color_picker.tooltip_text = tooltip
	color_picker.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	color_picker.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND

	var hbox: HBoxContainer = wrap_with_reset_button(color_picker, current_value, reset_value)
	var reset_btn: TextureButton = hbox.get_node("ResetButton")
	var update_value: Callable = (func(value: Color) -> void:
			reset_btn.visible = not _is_same_value(value, reset_value)
			callable.call(value))

	color_picker.color_changed.connect(update_value)
	reset_btn.pressed.connect(func() -> void:
			if not _is_same_value(color_picker.color, reset_value):
				color_picker.color = reset_value
				color_picker.color_changed.emit(reset_value)
			else:
				update_value.call(reset_value))
	return hbox


func _is_same_value(value_a: Variant, value_b: Variant) -> bool:
	if typeof(value_a) in [TYPE_FLOAT, TYPE_INT] and typeof(value_b) in [TYPE_FLOAT, TYPE_INT]:
		return is_equal_approx(value_a as float, value_b as float)
	elif typeof(value_a) in [TYPE_VECTOR2, TYPE_VECTOR2I] and typeof(value_b) in [TYPE_VECTOR2, TYPE_VECTOR2I]:
		return (value_a as Vector2).is_equal_approx(value_b as Vector2)
	elif value_a is Color and value_b is Color:
		return (value_a as Color).is_equal_approx(value_b as Color)
	return value_a == value_b


func create_default_resolution_hbox(default_settings: SettingsData) -> HBoxContainer:
	# Resolution HBOX contains 2 labels and 2 spinboxes. That's why we created
	# a separate function to deal with creating this node instance.
	var resolution_hbox: HBoxContainer = HBoxContainer.new()
	var x_label: Label = Label.new()
	var y_label: Label = Label.new()

	x_label.text = "X:" # NO_TRANSLATE
	y_label.text = "Y:" # NO_TRANSLATE

	resolution_hbox.add_child(x_label)
	resolution_hbox.add_child(create_spinbox(
			Settings.get_default_resolution_x(),
			default_settings.default_resolution.x,
			2, 100000, 2, false, true,
			Settings.set_default_resolution_x))
	resolution_hbox.add_child(y_label)
	resolution_hbox.add_child(create_spinbox(
			Settings.get_default_resolution_y(),
			default_settings.default_resolution.y,
			2, 100000, 2, false, true,
			Settings.set_default_resolution_y))
	return resolution_hbox


func create_marker_setting(index: int) -> HBoxContainer:
	var default_settings: SettingsData = SettingsData.new()

	var name_function: Callable = func(text: String) -> void:
			Settings.set_marker_name(index, text)

	# Marker text.
	var line_edit: Control = create_line_edit(
		Settings.get_marker_name(index),
		default_settings.marker_names[index],
		name_function
	)

	# Marker color.
	var color_picker: Control = create_color_picker(
			Settings.get_marker_color(index),
			default_settings.marker_colors[index],
			Settings.set_marker_color.bind(index))

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
	if event == null:
		return "None"
	elif event is not InputEventKey:
		return event.as_text()
	var event_key: InputEventKey = event
	return event_key.as_text_physical_keycode()


func _on_search_line_edit_text_changed(new_text: String) -> void:
	var search: String = new_text.to_lower()
	for section: String in sections:
		var grid: GridContainer = sections[section]
		if !grid.visible:
			continue

		var children: Array[Node] = grid.get_children()
		var i: int = 0
		while i < children.size():
			var node: Control = children[i]
			if node is Label and node.theme_type_variation == "title_label":
				node.visible = true
				if i + 1 < children.size():
					(children[i+1] as Control).visible = true
				i += 2
			elif node is Label:
				var label: Label = node
				var setting_control: Control = children[i+1] if i + 1 < children.size() else null
				var match_found: bool = search.is_empty() or label.text.to_lower().contains(search)
				node.visible = match_found
				if setting_control:
					setting_control.visible = match_found
				i += 2
			else:
				i += 1
