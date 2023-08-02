extends CommandBarModule

signal _on_create_new_project


enum { STARTUP, EDITING }


var state := STARTUP
var active := false
@onready var command_line := find_child("CommandLineEdit")
@onready var info_vbox := find_child("InfoVBox")

var commands_startup := [
	["Create new project", _on_create_new_project]]
var commands_editing := []


func _ready() -> void:
	self.visible = false


func _process(delta: float) -> void:
	if !active: return
	match state:
		STARTUP: update_info_panel(commands_startup)
		EDITING: update_info_panel(commands_editing)


func update_info_panel(list: Array) -> void:
	pass


func _input(event: InputEvent) -> void:
	if !active and event.is_action_pressed("open_command_bar"):
		show_command_bar()
	if active and event.is_action_pressed("ui_cancel"):
		hide_command_bar()


func show_command_bar() -> void:
	self.visible = true
	active = true
	command_line.grab_focus()


func hide_command_bar() -> void:
	self.visible = false
	command_line.text = ""
	active = false
