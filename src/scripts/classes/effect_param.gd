class_name EffectParam
extends Resource


enum PARAM_TYPE { FLOAT, COLOR, INT, VEC2, VEC3, VEC4, IVEC2, IVEC3, IVEC4 }


@export var param_id: String ## The same id used in the shader or in the audio effect
@export var param_name: String ## The name shown to the user
@export var type: PARAM_TYPE ## The type of param

@export var default_value: Variant ## Default value
@export var min_value: Variant ## Minimum value
@export var max_value: Variant ## Maximum value
