class_name StartupModule extends Node

## This is the interface for Startup Modules.
##
## The startup module is where we select which project 
## we want to work with. A clean list of all previously
## saved projects.

const PATH_RECENT_PROJECTS := "user://recent_projects"
var recent_projects: PackedStringArray = []


func _ready() -> void:
	pass


func load_recent_projects() -> void:
	pass


func save_recent_projects() -> void:
	pass
