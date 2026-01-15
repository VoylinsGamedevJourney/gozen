class_name EffectParam
extends Resource


@export var param_id: String ## The same id used in the shader or in the audio effect
@export var param_name: String ## The name shown to the user
@export var param_tooltip: String ## The description shown to the users when hovering over the param

@export var default_value: Variant ## Default value
@export var min_value: Variant ## Minimum value
@export var max_value: Variant ## Maximum value
