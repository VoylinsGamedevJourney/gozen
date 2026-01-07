class_name VideoEffect
extends Resource

enum PARAM_TYPE { FLOAT, COLOR }


@export var effect_name: String
@export var shader_path: String
@export var params: Array[VideoEffectParam] = []


# { frame_nr : (dictionary of all changed params) }
# Each dictionary is { param_id: value }
var frames: Dictionary[int, Dictionary] = {}
var enabled: bool = true


func _to_string() -> String:
	return "<VideoEffect: %s>" % effect_name
