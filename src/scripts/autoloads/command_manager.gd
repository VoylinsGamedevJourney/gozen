extends Node

var commands: PackedStringArray = [] ## Localized strings
var base_commands: PackedStringArray = [] ## Non-localized strings
var calls: Array[Callable] = []
var actions: PackedStringArray = []



func _ready() -> void:
	base_commands.append("Open editor settings")
	base_commands.append("Open project settings")
	base_commands.append("open render menu")

	register(tr("Open editor settings"), Settings.open_settings_menu, "open_settings")
	register(tr("Open project settings"), Project.open_settings_menu, "open_project_settings")
	register(tr("open render menu"), InputManager.switch_screen.bind(1), "open_render_screen")

	Settings.localization_updated.connect(_localize_commands)


func _localize_commands() -> void:
	for i: int in commands.size(): commands[i] = tr(base_commands[i])


# --- Command registering ---

func register(command: StringName, callable: Callable, action: StringName) -> void:
	commands.append(tr(command))
	base_commands.append(tr(command))
	calls.append(callable)
	actions.append(action)


## Only used for the editor itself since we add commands on build. Manually add
## the command to base_commands as well!
func _editor_register(command: StringName, callable: Callable, action: StringName) -> void:
	commands.append(command)
	calls.append(callable)
	actions.append(action)


# --- Getters ---

func get_text(index: int) -> String: return ("%s [%s]" % [commands[index], actions[index]]).replace(' []', '')
func get_call(index: int) -> Callable: return calls[index]
func get_action(index: int) -> String: return actions[index]


func get_sorted_indexes() -> Array[int]:
	var data: Array[int] = []
	for index: int in commands.size(): data.append(index)

	data.sort_custom(_sort_commands)
	return data


func _sort_commands(a: int, b: int) -> bool:
	return commands[a].naturalcasecmp_to(commands[b]) < 0
