class_name EffectParam
extends Resource


@export var id: String ## The same id used in the shader or in the audio effect
@export var nickname: String ## The name shown to the user
@export var tooltip: String ## The description shown to the users when hovering over the param

@export var default_value: Variant ## Default value
@export var min_value: Variant ## Minimum value
@export var max_value: Variant ## Maximum value
