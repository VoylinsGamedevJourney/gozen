class_name CommandBar
extends Control

# TODO: Display the actions in a better way
# TODO: Replace the action by the actual shortcut and replace stuff like
# "period" by an actual period.


const MAX_COMMANDS: int = 5
const FUZZY_SCORE_POINT: int = 1
const FUZZY_SCORE_BONUS: int = 10


var commands: Array[Command] = [
	Command.new("command_editor_settings", Settings.open_settings_menu, "open_settings"),
	Command.new("command_project_settings", Project.open_settings_menu, "open_project_settings"),
	Command.new("command_render_menu", InputManager.on_show_render_screen.emit, "open_render_screen"),
]


@export var command_line: LineEdit
@export var command_buttons: VBoxContainer

var shown_buttons: Array[Button] = []
var selected_button: int = 0



func _ready() -> void:
	var button_group:ButtonGroup = ButtonGroup.new()

	command_line.grab_focus()
	commands.sort_custom(Command.sort_commands)

	for command_option: Command in commands:
		var button: Button = Button.new()
		var events: Array[InputEvent] = InputMap.action_get_events(command_option.action)
		if events.size() == 0: events.append("") # Temporary
		var shortcut: String = events[0].as_text()

		if shortcut != "":
			button.text = "%s [%s]" % [command_option.command, shortcut.replace("(Physical)", "").strip_edges()]
		else:
			button.text = command_option.command
		button.alignment = HORIZONTAL_ALIGNMENT_LEFT
		button.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
		button.button_group = button_group
		button.toggle_mode = true
		button.pressed.connect(command_option.callback)
		button.pressed.connect(_close)

		if command_buttons.get_child_count() > MAX_COMMANDS:
			button.visible = false
		else:
			shown_buttons.append(button)

		command_buttons.add_child(button)

	shown_buttons[0].button_pressed = true


func _input(event: InputEvent) -> void:
	if event.is_action_pressed("ui_cancel"):
		PopupManager.close_popup(PopupManager.POPUP.COMMAND_BAR)
	if event.is_action_pressed("ui_up"):
		selected_button = clampi(
				selected_button - 1, 0, mini(shown_buttons.size() - 1, MAX_COMMANDS))
		shown_buttons[selected_button].button_pressed = true
	if event.is_action_pressed("ui_down"):
		selected_button = clampi(
				selected_button + 1, 0, mini(shown_buttons.size() - 1, MAX_COMMANDS))
		shown_buttons[selected_button].button_pressed = true


func _on_command_line_edit_text_changed(command_text: String) -> void:
	var buttons: Array[ButtonScore] = []

	shown_buttons.clear()
	selected_button = 0

	for button: Button in command_buttons.get_children():
		buttons.append(ButtonScore.new(button, command_text))

	buttons.sort_custom(ButtonScore.sort_scores)

	for i: int in min(buttons.size(), MAX_COMMANDS):
		var button: Button = buttons[i].button

		button.visible = buttons[i].score != 0
		command_buttons.move_child(button, i)
		shown_buttons.append(button)
		
	if shown_buttons.size() > 0:
		shown_buttons[0].button_pressed = true


func _on_command_line_edit_text_submitted(_command_text: String) -> void:
	for button: Button in command_buttons.get_children():
		if button.visible:
			if selected_button == 0:
				button.pressed.emit()
				return
			else:
				selected_button -= 1

	_close()


func _close() -> void:
	PopupManager.close_popup(PopupManager.POPUP.COMMAND_BAR)



class Command:
	var command: StringName
	var callback: Callable
	var action: StringName

	func _init(_command: StringName, _callback: Callable, _action: StringName) -> void:
		command = _command
		callback = _callback
		action = _action

	
	static func get_all_keys(commands: Array[Command]) -> PackedStringArray:
		var arr: PackedStringArray = []

		for command_option: Command in commands:
			arr.append(command_option.command)

		return arr


	static func sort_commands(a: Command, b: Command) -> bool:
		return a.command.naturalcasecmp_to(b.command) < 0



class ButtonScore:
	var button: Button
	var score: int

	func _init(button_node: Button, command_text: String) -> void:
		button = button_node
		score = _get_fuzzy_score(command_text, button.text)


	func _get_fuzzy_score(query: String, text: String) -> int:
		if query.is_empty():
			return 1
		elif query.length() > text.length():
			return 0
		
		var query_index: int = 0
		var text_index: int = 0
		
		query = query.to_lower()
		text = text.to_lower()
		
		while query_index < query.length() and text_index < text.length():
			if query[query_index] == text[text_index]:
				score += FUZZY_SCORE_POINT # Match found

				# Bonus for start of word
				if text_index == 0 or text[text_index - 1] == " " or text[text_index - 1] == "_":
					score += FUZZY_SCORE_BONUS # Start word found so extra bonus
				query_index += 1
			text_index += 1
		
		return score if query_index == query.length() else 0


	static func sort_scores(a: ButtonScore, b: ButtonScore) -> bool:
		return a.score > b.score
