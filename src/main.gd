extends Control

## Main editor control
##
## The only use of this 'Main' control node is for at
## startup to load the correct module and to have a place
## where modules can attach upon.


func _ready() -> void:
	# First module to load in the Project Manager module.
	# This contains the list of all your current projects and
	# allows you to create/remove/open projects.
	add_child(ModuleManager.get_module("project_manager"))
