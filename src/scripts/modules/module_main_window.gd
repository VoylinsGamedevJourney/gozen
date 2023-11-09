class_name ModuleMainWindow extends Control
## Main Window Module
##
## The main window module is the entire window with an area where
## content gets displayed into. All functionality such as resizing,
## closing, minimizing, maximizing, ... all have to be implemented.
##
## All main_window modules should extend from this script and 
## have following functions, variables and signals.
##
## Required functions:
## - add_to_content(node: Node)

static var instance: ModuleMainWindow


func _init() -> void:
	instance = self


## Easy way for other modules to add a Node to the the content
## part of the screen
func add_to_content(_node: Node) -> void:
	printerr("'add_to_content' is not implemented!!")
