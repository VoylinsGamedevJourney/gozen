class_name ModuleProjectSettingsMenu extends Control
## Project Settings Menu Module
##
## The project settings menu module is where you can find
## all project specific settings such as framerate, quality,
## ... and so on.
##
## All editor modules should extend from this script and 
## have following functions, variables and signals.

static var instance: ModuleProjectSettingsMenu


func _init() -> void:
	instance = self
