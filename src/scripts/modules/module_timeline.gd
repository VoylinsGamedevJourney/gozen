class_name ModuleTimeline extends Control
## Timeline Module
##
## The timeline module is where you decide the order of your clips
## and audio's. It displays the linear progression of your video./
##
## All editor modules should extend from this script and 
## have following functions, variables and signals.

static var instance: ModuleTimeline


func _init() -> void:
	instance = self
