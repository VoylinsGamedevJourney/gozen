class_name CommandBarModule extends Node
## The Command Bar Interface
##
## The basic necesarry things to setup the command bar.
## Most functionality of the command bar itself is handled
## by the command bar manager.


var command_line: LineEdit:
	set = set_command_line


func _init() -> void:
	self.visible = false
	CommandBarManager.bar = self


func set_command_line(line_edit: LineEdit) -> void:
	command_line = line_edit
	# Connect necesarry signals


func _on_text_changed(text: String) -> void:
	CommandBarManager._on_command_line_text_changed(text)


func _on_text_submitted(text: String) -> void:
	CommandBarManager._on_command_line_submitted(text)


func _input(event: InputEvent) -> void:
	if event.is_action_released("open_command_bar") and !self.visible:
		_show_command_bar()
	if event.is_action_pressed("ui_cancel") and self.visible:
		_hide_command_bar()


func _show_command_bar() -> void:
	self.visible = true
	command_line.grab_focus()


func _hide_command_bar() -> void:
	self.visible = false
	command_line.text = ""
