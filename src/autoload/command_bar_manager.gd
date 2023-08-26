extends Node
## Command Bar Manager
##
## This gives a link to the command bar and makes it so
## we can easily have signals 

signal _on_possible_commands_entered(possible_commands, text)

var selected_command: String = ""

var bar: Control

## List of possible commands
##
## Every command should be added with the command class.
var commands := {}


func _ready() -> void:
	# Add default editor commands
	_add_default_commands()
	# TODO: Open settings command
	# TODO: Open project settings command


func _on_command_line_text_changed(text:String) -> void:
	var possible_commands := []
	var current_mode: Command.MODES
	if ProjectManager.project == null:
		current_mode = Command.MODES.STARTUP_ONLY
	else:
		current_mode = Command.MODES.EDITOR_ONLY
	for command in commands:
		var command_mode: Command.MODES = commands[command].mode
		if command_mode == current_mode or command_mode == Command.MODES.EVERYWHERE:
			if _check_command_string(command, text):
				possible_commands.append(command)
	_on_possible_commands_entered.emit(possible_commands, text)


func _on_command_line_submitted(command: String) -> void:
	commands[command].function.call()


func _check_command_string(command, text) -> bool:
	var c: int = 0
	var t: int = 0
	while c < command.length() and t < text.length():
		if command[c].to_lower() == text[t].to_lower():
			t += 1
		c += 1
	return t == text.length()


func add_command(command_entry: Command) -> void:
	commands[command_entry.command] = command_entry


func _add_default_commands() -> void:
	# Command:Toggle zen mode
	var c_toggle_zen: Command = Command.new()
	c_toggle_zen.command = "Setting: Toggle zen mode"
	c_toggle_zen.mode = Command.MODES.EVERYWHERE
	c_toggle_zen.function = func(): 
			SettingsManager.switch_zen_mode()
	commands[c_toggle_zen.command] = c_toggle_zen

	# Command: Save project
	var c_save_project: Command = Command.new()
	c_save_project.command = "Project: Save project"
	c_save_project.mode = Command.MODES.EDITOR_ONLY
	c_save_project.function = func(): 
			ProjectManager.save_project()
	commands[c_save_project.command] = c_save_project
	
	# Command: Save project as ...
	var c_save_project_as: Command = Command.new()
	c_save_project_as.command = "Project: Save project as ..."
	c_save_project_as.mode = Command.MODES.EDITOR_ONLY
	c_save_project_as.function = func(): 
			ProjectManager.set_project_path("")
			ProjectManager.save_project()
	commands[c_save_project_as.command] = c_save_project_as
