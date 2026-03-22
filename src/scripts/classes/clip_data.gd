class_name ClipData
extends Resource


@export var id: int
@export var track: int
@export var type: EditorCore.TYPE

@export var file: int # File ID.

@export var start: int ## Frame_nr.
@export var begin: int ## Only for video and audio files.
@export var speed: float = 1.0 ## x times normal speed.
@export var duration: int

@export var effects: ClipEffects


@export var end: int: ## Should never be set.
	get: return start + duration
