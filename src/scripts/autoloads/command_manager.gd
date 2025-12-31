extends Node


var commands: Array[Command] = []



func register(command: StringName, callback: Callable, action: StringName) -> void:
	commands.append(Command.new(command, callback, action))
	commands.sort_custom(Command.sort_commands)



class Command:
	var command: StringName
	var callback: Callable
	var action: String = ""

	func _init(_command: StringName, _callback: Callable, _action: StringName) -> void:
		command = _command
		callback = _callback

		# We need to format the action to display better
		var events: Array[InputEvent] = InputMap.action_get_events(_action)
		if events.size() == 0: return

		var shortcut: String = events[0].as_text().replace("(Physical)", "").strip_edges()

		shortcut = shortcut.replace("period", ",")


	func get_button_text() -> String:
		if action == "":
			return command
		else:
			return "%s [%s]" % [command, action]

	
	static func get_all_keys(commands: Array[Command]) -> PackedStringArray:
		var arr: PackedStringArray = []

		for command_option: Command in commands:
			arr.append(command_option.command)

		return arr


	static func sort_commands(a: Command, b: Command) -> bool:
		return a.command.naturalcasecmp_to(b.command) < 0



