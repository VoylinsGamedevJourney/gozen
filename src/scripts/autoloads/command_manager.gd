extends Node

var commands: Array[String] = [] ## Localized strings.
var base_commands: Array[String] = [] ## Non-localized strings.

var calls: Array[Callable] = []
var actions: Array[String] = []



func _ready() -> void:
	register(Command.new("Open editor settings", Settings.open_settings_menu, "open_settings"))
	register(Command.new("Open project settings", Project.open_settings_menu, "open_project_settings"))
	register(Command.new("open render menu", InputManager.switch_workspace.bind(1), "open_render_workspace"))

	@warning_ignore("return_value_discarded")
	Settings.on_localization_updated.connect(_localize_commands)


func _localize_commands() -> void:
	for i: int in commands.size(): commands[i] = tr(base_commands[i])


# --- Command registering ---

func register(cmd: Command) -> void:
	commands.append(tr(cmd.command))
	base_commands.append(cmd.command) # Has to be the original English translation.

	calls.append(cmd.callable)
	actions.append(cmd.action)


# --- Getters ---

func get_text(index: int) -> String:   return ("%s [%s]" % [commands[index], actions[index]]).replace(' []', '')
func get_call(index: int) -> Callable: return calls[index]
func get_action(index: int) -> String: return actions[index]


func get_sorted_indexes() -> Array[int]:
	var data: Array[int] = []
	for index: int in commands.size(): data.append(index)

	data.sort_custom(func(a: int, b: int) -> bool:
			return commands[a].naturalcasecmp_to(commands[b]) < 0)
	return data



class Command:
	var command: StringName
	var callable: Callable
	var action: StringName


	func _init(_command: StringName, _callable: Callable, _action: StringName) -> void:
		command = _command
		callable = _callable
		action = _action
