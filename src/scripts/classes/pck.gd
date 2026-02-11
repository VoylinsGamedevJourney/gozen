@abstract
class_name PCK
extends Resource

# Use propagate_call to send info on the duration + current frame + ...

const MODULES_PATH: String = "res://modules/"


@export var duration: int = 300 ## In frames.
@export var min_duration: int = 1 ## In frames.
@export var max_duration: int = -1 ## In frames. -1 is for unlimited

@export var scene: PackedScene = null
