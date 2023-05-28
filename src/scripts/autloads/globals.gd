extends Node

@onready var main : Node = get_node("/root/Main")

const MODULE_USER_PATH := "user://modules"
const MODULE_RES_PATH := "res://modules"
enum MODULES {
	PROJECT_MANAGER,
	FILE_EXPLORER }
const MODULE_PATHS := {
	MODULES.PROJECT_MANAGER: "project_manager",
	MODULES.FILE_EXPLORER: "file_explorer" }
