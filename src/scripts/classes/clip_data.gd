class_name ClipData
extends Resource


var id: int
var track: int
var type: EditorCore.TYPE

var file: int # File ID.

var start: int ## Frame_nr.
var begin: int ## Only for video and audio files.
var speed: float = 1.0 ## x times normal speed.
var duration: int

var effects: ClipEffects


var end: int: ## Should never be set.
	get: return start + duration
