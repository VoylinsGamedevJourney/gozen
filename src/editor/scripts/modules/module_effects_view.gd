class_name ModuleEffectsView extends Control
## Effects View Module
##
## The effects view module displays all effects a clip has
## together with the buttons, sliders, ... necesarry to edit
## those effects. The effecs displayed can be clip specific,
## or specific to the file itself.
##
## All editor modules should extend from this script and 
## have following functions, variables and signals.

static var instance: ModuleEffectsView


func _init() -> void:
	instance = self
