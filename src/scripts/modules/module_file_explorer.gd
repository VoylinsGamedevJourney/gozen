class_name ModuleFileExplorer extends Control
## File Explorer Module
##
## The file explorer module is what the name says. It's
## the screen in which you can select where to save the
## project or video(s), but also the tool used to import
## resources into your project.
##
## All editor modules should extend from this script and 
## have following functions, variables and signals.

static var instance: ModuleFileExplorer


func _init() -> void:
	instance = self
