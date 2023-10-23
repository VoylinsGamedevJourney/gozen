extends Button

var command_line: LineEdit
var info_button: Button

var selected := -1


func _ready() -> void:
	command_line = find_child("CommandLineEdit")
	_hide_command_bar()
	CommandBarManager.bar = self
	
	# Binding functions
	command_line.text_changed.connect(_on_text_changed)
	command_line.text_submitted.connect(_on_text_submitted)
	CommandBarManager._on_possible_commands_entered.connect(update_info_panel)
	info_button = preload("res://modules/command_bar/default/InfoButton.tscn").instantiate()


func _input(event: InputEvent) -> void:
	if event.is_action_released("open_command_bar") and !self.visible:
		_show_command_bar()
	if event.is_action_pressed("ui_cancel") and self.visible:
		_hide_command_bar()
	if event.is_action_pressed("ui_down") and selected < %InfoVBox.get_child_count() -1:
		get_viewport().set_input_as_handled()
		update_selected_command_button(selected + 1)
	if event.is_action_pressed("ui_up") and selected != 0:
		get_viewport().set_input_as_handled()
		update_selected_command_button(selected - 1)


func _show_command_bar() -> void:
	self.visible = true
	command_line.grab_focus()


func _hide_command_bar() -> void:
	self.visible = false
	command_line.text = ""
	selected = -1


func update_info_panel(possible_commands: Array, command_text: String) -> void:
	update_selected_command_button(-1)
	for button in %InfoVBox.get_children():
		button.queue_free()
	
	# Formatting possible commandsvar possible_texts := []
	var possible_texts := []
	for command in possible_commands:
		var result : String = ""
		var c: int = 0
		var t: int = 0
		while c < command.length() and t < command_text.length():
			if command[c].to_lower() == command_text[t].to_lower():
				result += "[color=white]" + command[c] + "[/color]"
				t += 1
			else:
				result += command[c]
			c += 1
		result += command.substr(c)
		possible_texts.append("[color=gray]%s[/color]" % result)
	
	for id in possible_commands.size():
		var button := info_button.duplicate()
		button.find_child("CommandLabel").text = possible_texts[id]
		button.name = possible_commands[id]
		button.connect(
			"pressed", 
			func(): 
				CommandBarManager._on_command_line_submitted(possible_commands[id])
				_hide_command_bar())
		%InfoVBox.add_child(button)


func _on_text_changed(command: String) -> void:
	CommandBarManager._on_command_line_text_changed(command)


func _on_text_submitted(_text: String) -> void:
	if %InfoVBox.get_child_count() < selected + 1:
		_hide_command_bar()
		return
	if selected == -1:
		selected = 0
	CommandBarManager._on_command_line_submitted(
			%InfoVBox.get_child(selected).name)
	_hide_command_bar()


func update_selected_command_button(new_selected: int) -> void:
	selected = new_selected
	var empty_style := StyleBoxEmpty.new()
	var selected_style := StyleBoxFlat.new()
	selected_style.set_corner_radius_all(7)
	selected_style.bg_color = Color("880BCB")
	for button_id in %InfoVBox.get_child_count():
		%InfoVBox.get_child(button_id).add_theme_stylebox_override(
				"normal", selected_style if button_id == selected else empty_style)
