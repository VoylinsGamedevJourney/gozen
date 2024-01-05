extends Control
## Settings menu manager
##
## Startup argument needed for startup:
## --type=<settings,project_settings>: if no type is given, settings gets chosen;
## --project_path=<project file path>: is needed when type is project_settings.

#region Consts
const PATH_SETTINGS_MENU_CFG := "user://settings_data.cfg"
const PATH_PROJECT_MENU_CFG := "user://project_data.cfg"

const PATH_SETTINGS := "user://settings.cfg"
#endregion

#region Variables
var arguments := {} # Startup arguments

var menu_data := ConfigFile.new()
var user_data := ConfigFile.new()

var unsaved: bool = false
#endregion


func _ready() -> void:
	#region Startup arguments
	for argument: String in OS.get_cmdline_args():
		if argument.find("=") > -1:
			var key_value = argument.split("=")
			arguments[key_value[0].lstrip("--")] = key_value[1]
	if arguments.size() == 0:
		arguments.type = "settings"
	
	%WindowLabel.text = tr("TOP_BAR_TITLE_%s_MENU" % arguments.type.to_upper())
	if arguments.type == "project_settings" and !arguments.has("project_path"):
		printerr("No project_path argument was found whilst type is project_settings!")
		get_tree().quit()
	#endregion
	#region Loading configs
	if arguments.type == "settings":
		menu_data.load(PATH_SETTINGS_MENU_CFG)
		user_data.load(PATH_SETTINGS)
		TranslationServer.set_locale(user_data.get_value("general", "language", "en"))
	elif arguments.type == "project_settings":
		menu_data.load(PATH_PROJECT_MENU_CFG)
		user_data.load(arguments.project_path)
		var settings := ConfigFile.new()
		settings.load(PATH_SETTINGS)
		TranslationServer.set_locale(settings.get_value("general", "language", "en"))
	else:
		printerr("Invalid type!")
		get_tree().quit()
	#endregion
	build_layout()  # Building layout according to argument 'type'

###############################################################
#region Builder  ##############################################
###############################################################

## Building each section one by one
func build_layout() -> void:
	for section: String in menu_data.get_sections():
		# Adding the section label
		var section_label := Label.new()
		section_label.text = tr("SECTION_%s" % section.to_upper())
		section_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		section_label.label_settings = preload("res://ui/theming/label_settings_title.tres")
		%SettingsGrid.add_child(section_label)
		
		# We need an empty control as this is a grid with 2 columns
		var control := Control.new()
		control.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		%SettingsGrid.add_child(control)
		
		# Building the settings with their labels and nodes to change the setting
		_build_section(section)
		
		# Adding a line underneath the section to create some
		# separation from other settings
		var separator := HSeparator.new()
		%SettingsGrid.add_child(separator)
		%SettingsGrid.add_child(separator.duplicate())


## Populating each section with all settings
func _build_section(section: String) -> void:
	for key: String in menu_data.get_section_keys(section):
		# Creating the setting label
		var key_label := Label.new()
		key_label.text = "SETTING_%s" % key.to_upper()
		key_label.label_settings = preload("res://ui/theming/label_settings_text.tres")
		%SettingsGrid.add_child(key_label)
		
		# Adding method to show/change the setting value 
		var node: Control
		var meta: Dictionary = menu_data.get_value(section, key)
		if meta.has("options"): # Dropdown menu
			var option_button := OptionButton.new()
			var option_keys: PackedStringArray = []
			for option: String in meta.options:
				option_button.add_item(meta.options[option])
				option_keys.append(option)
			option_button.selected = option_keys.find(user_data.get_value(section, key))
			option_button.item_selected.connect(func(index: int):
					changes_made()
					user_data.set_value(section, key, option_keys[index])
					if key == "language":
						TranslationServer.set_locale(option_keys[index]))
			node = option_button
		elif meta.type == "bool":
			var checkbox := CheckBox.new()
			checkbox.button_pressed = user_data.get_value(section, key)
			checkbox.toggled.connect(func(toggled_on: bool):
				changes_made() 
				user_data.set_value(section, key, toggled_on))
			node = checkbox
		elif meta.type == "int" or meta.type == "float":
			var spinbox := SpinBox.new()
			spinbox.min_value = meta.min_value
			spinbox.max_value = meta.max_value
			spinbox.step = meta.step
			spinbox.value = user_data.get_value(section, key)
			spinbox.value_changed.connect(func(value: float):
					changes_made()
					user_data.set_value(section, key, value))
			node = spinbox
		
		# Setting the tooltip and adding to grid
		node.tooltip_text = tr("TOOLTIP_SETTING_%s" % key.to_upper())
		%SettingsGrid.add_child(node)


func _input(event: InputEvent) -> void:
	# CTRL+S shortcut to easily save settings whilst keeping menu open 
	if event.is_action_pressed("save_data"):
		save_data()


func save_data() -> void:
	if arguments.type == "project_settings":
		user_data.save(arguments.project_path)
	else:
		user_data.save(PATH_SETTINGS)
	changes_saved()


func changes_made() -> void:
	# Unhide label to notify user of unsaved changes
	if $AnimationPlayer.is_playing():
		$AnimationPlayer.stop()
	unsaved = true
	%StatusLabel.modulate = Color("ffffff")
	%StatusLabel.text = "STATUS_UNSAVED_CHANGES"


func changes_saved() -> void:
	# Play small dissapear animation on label
	unsaved = false
	%StatusLabel.text = "STATUS_CHANGES_SAVED"
	$AnimationPlayer.play("hide_changes_saved")

#endregion
###############################################################
#region Buttons  ##############################################
###############################################################

func _on_exit_button_pressed() -> void:
	if unsaved: # If unsaved settings are present, ask if wanting to save or not
		var conf_dialog := ConfirmationDialog.new()
		conf_dialog.canceled.connect(func(): 
				get_tree().quit())
		conf_dialog.confirmed.connect(func(): 
				save_data()
				get_tree().quit())
		conf_dialog.dialog_text = "CLOSE_DIALOG_TEXT"
		conf_dialog.cancel_button_text = "CLOSE_DIALOG_BUTTON_CANCEL"
		conf_dialog.ok_button_text = "CLOSE_DIALOG_BUTTON_OK"
		add_child(conf_dialog)
		conf_dialog.popup_centered()
		return
	get_tree().quit()


func _on_save_button_pressed() -> void:
	save_data()
	get_tree().quit()

#endregion
###############################################################
