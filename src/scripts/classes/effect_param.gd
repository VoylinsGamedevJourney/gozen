class_name EffectParam
extends Resource

@export var id: String ## The same id used in the shader or in the audio effect.
@export var nickname: String ## The name shown to the user.
@export var tooltip: String ## The description shown to the users when hovering over the param.

@export var default_value: Variant ## Default value.
@export var min_value: Variant ## Minimum value.
@export var max_value: Variant ## Maximum value.

@export var step: float = 0.0 ## The step value for SpinBox inputs, 0.0 defaults to 0.01 for floats and 1.0 for integers.

@export var keyframeable: bool = true ## Set to false if the param has no use for being keyframeable.

@export var is_linkable: bool = false ## Allows X and Y to be linked in the UI (for Vector2/Vector2i).
@export var is_linked: bool = false ## Default state of the link.

@export var has_slider: bool = true ## Display's a slider in automatically generated effects UI.
