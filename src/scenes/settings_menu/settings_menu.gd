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


func set_mode_settings(mode_name: String, menu_options: Dictionary[String, Array]) -> void:
	panel_label.text = mode_name

	for section_name: String in menu_options:
		var section_grid: Node = _create_section(section_name)
	
		for node: Node in menu_options[section_name]:
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

	Utils.connect_func(button.pressed, _show_section.bind(section_name))
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

