extends Node
## Command Bar Manager
##
## This gives a link to the command bar and makes it so
## we can easily have signals 

signal _on_possible_commands_entered(possible_commands, text)

var selected_command: String = ""

var bar: CommandBarModule

## List of possible commands
##
## Every command should be added with the command class.
var commands := {
	
}


func _ready() -> void:
	# Add default editor commands
	_add_command_change_language()
	# TODO: Zen mode command
	# TODO: Save project command
	# TODO: Open settings command
	# TODO: Open project settings command


func _on_command_line_text_changed(text:String) -> void:
	var possible_commands := []
	for command in commands:
		if _check_command_string(command, text):
			possible_commands.append(command)
	_on_possible_commands_entered.emit(possible_commands, text)


func _on_command_line_submitted(text: String) -> void:
	var possible_commands := []
	if selected_command == ""and commands[text].options != []:
		# Check if options are available
			selected_command = text
			_on_possible_commands_entered.emit(commands[text].options, "%s:"%text)
#	var possible_commands()
	_on_possible_commands_entered.emit(possible_commands, text)
	# Check if selected command is empty, check for options
	# Check if selected command has command
	pass


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


func _add_command_change_language() -> void:
	var command_entry: Command = Command.new()
	command_entry.command = "Change language"
	command_entry.edit_only = false
	command_entry.startup_only = false
	command_entry.info = "Change the language of the editor"
	var languages := []
	for language in TranslationServer.get_loaded_locales():
		languages.append(TranslationServer.get_locale_name(language))
	command_entry.options = languages
	command_entry.function = func(x):
			for locale in TranslationServer.get_loaded_locales():
				if x == TranslationServer.get_locale_name(locale):
					SettingsManager.set_language(locale)
					return
	commands[command_entry.command] = command_entry
