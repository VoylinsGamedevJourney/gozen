class_name ModuleProjectView extends Control
## Project View Module
##
## The project view module is the module which shows you 
## the view from the timeline where your cursor is at 
## that time. 
##
## All editor modules should extend from this script and 
## have following functions, variables and signals.

static var instance: ModuleProjectView


func _init() -> void:
	instance = self
