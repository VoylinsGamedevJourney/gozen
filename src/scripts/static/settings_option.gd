class_name SettingsOption



static func create_label(title: String) -> Label:
	var label: Label = Label.new()

	label.text = title
	label.size_flags_horizontal = Control.SIZE_EXPAND_FILL

	return label


static func create_option_button(options: Dictionary, default: int, callable: Callable, type: Variant.Type, tooltip: String) -> OptionButton:
	# Options should have the option text as key and the value to pass to
	# callable as value.
	var option_button: OptionButton = OptionButton.new()

	Utils.connect_func(option_button.item_selected, _option_button_item_selected.bind(option_button, callable, type))

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


static func _option_button_item_selected(id: int, option_button: OptionButton, callable: Callable, type: Variant.Type) -> void:
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


static func create_check_button(default: bool, callable: Callable, tooltip: String) -> CheckButton:
	var check_button: CheckButton = CheckButton.new()

	check_button.flat = true
	check_button.button_pressed = default
	check_button.tooltip_text = tooltip
	check_button.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	Utils.connect_func(check_button.toggled, callable)

	check_button.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
	check_button.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND

	return check_button


static func create_spinbox(default: float, min_value: float, max_value: float, step: float, allow_lesser: bool, allow_greater: bool, callable: Callable, tooltip: String, suffix: String = "") -> SpinBox:
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
	Utils.connect_func(spinbox.value_changed, callable)

	spinbox.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	spinbox.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND

	return spinbox


static func create_color_picker(default: Color, callable: Callable, tooltip: String) -> ColorPickerButton:
	var color_picker: ColorPickerButton = ColorPickerButton.new()

	color_picker.color = default
	color_picker.tooltip_text = tooltip
	color_picker.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	Utils.connect_func(color_picker.color_changed, callable)

	color_picker.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	color_picker.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND

	return color_picker


static func create_default_resolution_hbox() -> HBoxContainer:
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

