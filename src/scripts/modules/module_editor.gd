class_name ModuleEditor extends Control
## Editor Module
##
## The editor module is where all the magic happens, this is
## the screen people work in when editing videos. This contains
## all modules necesarry, including custom ones, and displays it
## in a clear way.
##
## All editor modules should extend from this script and 
## have following functions, variables and signals.

static var instance: ModuleEditor


func _init() -> void:
	instance = self
