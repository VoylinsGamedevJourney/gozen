@abstract
class_name VisualEffect
extends Resource


@export var effect_name: String


## The panel which will appear in the effects panel in it's own foldable
## container with all the options to adjust the variables for the effect.
@abstract func get_effects_panel() -> Container

## Get the compute shader file
@abstract func get_compute_shader() -> int

## Get the byte size of the buffer data which is passed to the shader
@abstract func get_std140_size() -> int



func _to_string() -> String:
	return "<VideoEffect: %s>" % effect_name
