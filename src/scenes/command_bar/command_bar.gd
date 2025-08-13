class_name CommandBar
extends Control


const MAX_COMMANDS: int = 5


var commands: Dictionary[String, Callable] = {
	"command_editor_settings": open_editor_settings,
	"command_project_settings": open_project_settings,
	"command_render_menu": open_render_menu
}


@export var command_line: LineEdit
@export var command_buttons: VBoxContainer

var shown_buttons: Array[Button] = []
var selected_button: int = 0



func _ready() -> void:
	command_line.grab_focus()

	var command_keys: PackedStringArray = commands.keys()
	var button_group:ButtonGroup = ButtonGroup.new()
	command_keys.sort()

	for command: String in command_keys:
		var button: Button = Button.new()
		
		button.text = command
		button.alignment = HORIZONTAL_ALIGNMENT_LEFT
		button.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
		Toolbox.connect_func(button.pressed, commands[command])
		button.button_group = button_group
		button.toggle_mode = true

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
	shown_buttons.clear()
	selected_button = 0

	for button: Button in command_buttons.get_children():
		if command_text.is_empty() and shown_buttons.size() < MAX_COMMANDS:
			button.visible = true
			shown_buttons.append(button)
		elif command_text.to_lower() in button.text.to_lower() and shown_buttons.size() < MAX_COMMANDS:
			button.visible = true
			shown_buttons.append(button)
		else:
			button.visible = false

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


func open_editor_settings() -> void:
	Settings.open_settings_menu()
	PopupManager.close_popup(PopupManager.POPUP.COMMAND_BAR)


func open_project_settings() -> void:
	Project.open_settings_menu()
	PopupManager.close_popup(PopupManager.POPUP.COMMAND_BAR)


func open_render_menu() -> void:
	InputManager.show_render_screen()
	PopupManager.close_popup(PopupManager.POPUP.COMMAND_BAR)

