class_name ModuleCommandBar extends Control
## Command Bar Module
##
## The command bar module is the quick search of GoZen. Find
## settings easily, change certain settings easily, shortcuts
## to improve your workflow by quickly doing the action you
## want to happen.
##
## All command_bar modules should extend from this script and 
## have following functions, variables and signals.

static var instance: ModuleCommandBar


func _init() -> void:
	instance = self
