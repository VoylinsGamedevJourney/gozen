class_name ModuleMediaPool extends Control
## Media Pool Module
##
## The media pool module is where all your project specific
## files can be found, together with global files which you
## want to use over your whole project.
##
## All editor modules should extend from this script and 
## have following functions, variables and signals.

static var instance: ModuleMediaPool


func _init() -> void:
	instance = self
