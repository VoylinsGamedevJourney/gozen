class_name VisualEffectTransform
extends VisualEffect


@export var position: Vector2i = Vector2i.ZERO
@export var size: Vector2 = Project.get_resolution()
@export_range(-360, 360) var rotation: float = 0.0
@export var pivot: Vector2i = Project.get_resolution() / 2
@export_range(0, 1) var alpha: float = 1.0


func get_shader_rid() -> RID:
	return load("res://effects/visual/transform.glsl").get_spirv()


func get_effects_panel() -> Container:
	# TODO: Create the effects settings
	return Container.new()


func get_buffer_data(frame_nr: int, context_data: Dictionary) -> PackedByteArray:
	return []

