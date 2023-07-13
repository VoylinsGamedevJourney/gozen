extends Control

## Main editor control
##
## The only use of this 'Main' control node is for at
## startup to load the correct module and to have a place
## where modules can attach upon.



func _ready() -> void:
	add_child(ModuleManager.get_module("project_manager"))
