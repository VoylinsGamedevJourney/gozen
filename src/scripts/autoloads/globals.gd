extends Node

## Globals Autoload
##
## This file contains all consts which are not supposed to be
## changed during runtime like the version number and path.


const VERSION := "0.0.1-Alpha"

# Paths
const PATH_PROJECTS_LIST := "user://projects_lists.dat"
const PATH_SETTINGS := "user://settings.dat"


# Nodes

var editor_layout: EditorLayoutInterface


# Variables

var window_title: String:
	set(value):
		get_window().set_title(value)
		window_title = value
var project: Project

var system_username


func _ready() -> void:
	window_title = "GoZen - %s" % VERSION
	
	# Getting the username of the OS,
	var output : Array = []
	OS.execute("whoami", [], output) # TODO: Make cross-platform
	system_username = output[0].replace("\n","")
