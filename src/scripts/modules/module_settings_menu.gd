class_name ModuleSettingsMenu extends Control
## Settings Menu Module
##
## The settings menu module is the screen where you can 
## change all editor specific settings.
##
## All editor modules should extend from this script and 
## have following functions, variables and signals.

static var instance: ModuleSettingsMenu


func _init() -> void:
	instance = self
