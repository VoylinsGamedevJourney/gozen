class_name GoZenModule
extends Resource
## NOTE: Give the folder name in "res://modules/" a unique name so it doesn't
## 		 interfere with other modules!

@export_group("Module info")
@export var name: String = ""
@export var description: String = ""
@export var author: String = ""
@export var version: String = "1.0"

@export_group("Playback")
@export var default_duration: int = 300 ## In frames.
@export var min_duration: int = 1 ## Minimum allowed frames.
@export var max_duration: int = -1 ## Maximum allowed frames. -1 = unlimited.

@export_group("Content")
@export var scene: PackedScene = null # The actual scene that gets used.
@export var params: Array[EffectParam] = [] ## Parameters which get shown in the Effects panel.
