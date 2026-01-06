class_name VideoEffect
extends Resource

enum PARAM_TYPE { STRING, FLOAT }


@export var effect_name: String
@export var shader_path: String
@export var params: Array[VideoEffectParam] = []

