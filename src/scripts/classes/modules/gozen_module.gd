class_name GoZenModule
extends Resource
## NOTE: Give the folder name in "res://modules/" a unique name so it doesn't
## 		 interfere with other modules!

@export_group("Module info")
@export var name: String = ""
@export var description: String = ""
@export var author: String = ""
@export var version: String = "1.0"

@export_group("Content")
@export var custom_scenes: Array[GoZenModuleScene] = []
@export var custom_panels: Array[GoZenModulePanel] = []
@export var custom_effects: Array[GoZenModuleEffect] = []
@export var custom_transitions: Array[GoZenModuleTransition] = []
@export var custom_themes: Array[GoZenModuleTheme] = []
