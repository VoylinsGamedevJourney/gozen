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
		var events: Array[InputEvent] = InputMap.action_get_events(_action)
		var shortcut: String
		command = _command
		callback = _callback

		if events.size() == 0: return

		shortcut = events[0].as_text()
		shortcut = shortcut.replace("(Physical)", "").strip_edges()
		shortcut = shortcut.replace("period", ",")


	func get_button_text() -> String:
		return String(command) if action == "" else "%s [%s]" % [command, action]


	static func get_all_keys(commands: Array[Command]) -> PackedStringArray:
		var arr: PackedStringArray = []
		for command_option: Command in commands:
			arr.append(command_option.command)

		return arr


	static func sort_commands(a: Command, b: Command) -> bool:
		return a.command.naturalcasecmp_to(b.command) < 0
