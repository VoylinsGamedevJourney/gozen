class_name CommandBar
extends Control

# TODO: Display the actions in a better way

const MAX_COMMANDS: int = 5


@export var command_line: LineEdit
@export var command_buttons: VBoxContainer

var shown_buttons: Array[Button] = []
var selected_button: int = 0



func _ready() -> void:
	var button_group:ButtonGroup = ButtonGroup.new()

	command_line.grab_focus()

	for index: int in CommandManager.get_sorted_indexes():
		var button: Button = Button.new()

		button.text = CommandManager.get_text(index)
		button.alignment = HORIZONTAL_ALIGNMENT_LEFT
		button.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
		button.button_group = button_group
		button.toggle_mode = true
		button.pressed.connect(CommandManager.get_call(index))
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
		if !button.visible: continue
		elif selected_button != 0: selected_button -= 1
		else: return button.pressed.emit()
	_close()


func _close() -> void:
	PopupManager.close_popup(PopupManager.POPUP.COMMAND_BAR)



class ButtonScore:
	var button: Button
	var score: int

	func _init(button_node: Button, command_text: String) -> void:
		button = button_node
		score = Utils.get_fuzzy_score(command_text, button.text)


	static func sort_scores(a: ButtonScore, b: ButtonScore) -> bool:
		return a.score > b.score
