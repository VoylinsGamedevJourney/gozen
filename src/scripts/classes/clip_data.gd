class_name ClipData
extends RefCounted



var id: int
var file_id: int
var track_id: int

var start_frame: int
var duration: int
var end_frame: int:
	get: return start_frame + duration

var begin: int = 0 # Only for video and audio files

var effects_video: Array[VisualEffect]
var effects_audio: Array[AudioEffect]

var transform: TransformEffect # Only for clips with visuals



func _to_string() -> String:
	return "<clip:%s>" % id



class TransformEffect:
	var position: Dictionary[int, Vector2i] = { 0: Vector2i.ZERO }
	var size: Dictionary[int, Vector2i] = { 0: Vector2i.ZERO }
	var scale: Dictionary[int, float] = { 0: 100 }
	var rotation: Dictionary[int, float] = { 0: 0 }
	var alpha: Dictionary[int, float] = { 0: 1.0 }
	var pivot: Dictionary[int, Vector2i] = { 0: Vector2i.ZERO }
