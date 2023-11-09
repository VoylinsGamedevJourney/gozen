class_name ModuleStartup extends Control
## Startup Module
##
## The startup module is the first screen you see when 
## starting up the editor. It is where you can open a new
## or existing project from.
##
## All editor modules should extend from this script and 
## have following functions, variables and signals.

static var instance: ModuleStartup


func _init() -> void:
	instance = self
