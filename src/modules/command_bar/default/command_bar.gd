extends Control

var command_line: LineEdit
var info_vbox: VBoxContainer
var info_button: Button

var selected := 0


func _ready() -> void:
	command_line = find_child("CommandLineEdit")
	_hide_command_bar()
	CommandBarManager.bar = self
	
	# Binding functions
	command_line.text_changed.connect(_on_text_changed)
	command_line.text_submitted.connect(_on_text_submitted)
	info_vbox = find_child("InfoVBox")
	CommandBarManager._on_possible_commands_entered.connect(update_info_panel)
	info_button = preload("res://modules/command_bar/default/InfoButton.tscn").instantiate()


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


func update_info_panel(possible_commands: Array, text: String) -> void:
	# TODO: connect buttons to a separate function which calls _on_text_submitted
	#       with the correct command text
	var possible_texts := _format_possible_commands(possible_commands, text)
	var new_button := info_button.duplicate()
	
	var existing_buttons: PackedStringArray = []
	for button in info_vbox.get_children():
		existing_buttons.append(button.name)
	
	for id in possible_commands.size():
		if possible_commands[id] in existing_buttons:
			var button = info_vbox.find_child(possible_commands[id],true,false)
			button.find_child("CommandLabel").text = possible_texts[id]
			existing_buttons.remove_at(existing_buttons.find(possible_commands[id]))
			continue
		new_button.name = possible_commands[id]
		new_button.find_child("CommandLabel").text = possible_texts[id]
		info_vbox.add_child(new_button)
	
	for button in existing_buttons:
		info_vbox.find_child(button,true,false).queue_free()


func _format_possible_commands(possible_commands: Array, text: String) -> Array:
	var possible_texts := []
	for command in possible_commands:
		var result : String = ""
		var c: int = 0
		var t: int = 0
		while c < command.length() and t < text.length():
			if command[c].to_lower() == text[t].to_lower():
				result += "[color=white]" + command[c] + "[/color]"
				t += 1
			else:
				result += command[c]
			c += 1
		result += command.substr(c)
		possible_texts.append("[color=gray]%s[/color]" % result)
	return possible_texts


func _on_text_changed(command: String) -> void:
	CommandBarManager._on_command_line_text_changed(command)


func _on_text_submitted(_text: String) -> void:
	if info_vbox.get_child_count() < selected + 1:
		_hide_command_bar()
		return
	CommandBarManager._on_command_line_submitted(
			info_vbox.get_child(selected).name)
	_hide_command_bar()
