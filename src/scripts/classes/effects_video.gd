class_name EffectsVideo
extends Node

# Default variables can be gotten from anywhere through
# Editor.default_effects_video
# This will be helpful if some people want to set defaults which apply to each
# project as we only need to adjust the instance of Editor to apply changes
# anywhere.



@export var position: Vector2i = Vector2i.ZERO
@export var size: Vector2i = Vector2i.ZERO
@export var scale: float = 100
@export var rotation: float = 0
@export var alpha: float = 1.0
@export var pivot: Vector2i = Vector2i.ZERO

@export var enable_color_correction: bool = false
@export var brightness: float = 0.0 # Min: -1.0, Max: 1.0
@export var contrast: float = 1.0 # Min: -1.0, Max: 1.0
@export var saturation: float = 1.0 # Min: -1.0, Max: 1.0

@export var red_value: float = 1.0 # Min: 0.0, Max: 1.0
@export var green_value: float = 1.0 # Min: 0.0, Max: 1.0
@export var blue_value: float = 1.0 # Min: 0.0, Max: 1.0

@export var tint_color: Color = Color.BLACK
@export var tint_effect_factor: float = 0.0 # Min: 0.0, Max: 1.0

@export var enable_chroma_key: bool = false
@export var chroma_key_color: Color = Color.LIME_GREEN
@export var chroma_key_tolerance: float = 0.3 # Min: 0.0, Max 1.0
@export var chroma_key_softness: float = 0.05 # Min: 0.0, Max 0.5



func set_default_transform() -> void:
	position = Vector2i.ZERO
	size = Project.get_resolution()
	scale = 100
	rotation = 0
	alpha = 1.0
	pivot = size / 2


func apply_transform(view_texture: TextureRect) -> void:
	view_texture.position = position
	view_texture.size = size
	view_texture.scale = Vector2(scale / 100, scale / 100)
	view_texture.rotation = deg_to_rad(rotation)
	view_texture.pivot_offset = pivot


func apply_color_correction(material: ShaderMaterial) -> void:
	material.set_shader_parameter("brightness", brightness)
	material.set_shader_parameter("contrast", contrast)
	material.set_shader_parameter("saturation", saturation)

	material.set_shader_parameter("red_value", red_value)
	material.set_shader_parameter("green_value", green_value)
	material.set_shader_parameter("blue_value", blue_value)

	material.set_shader_parameter("tint_color", tint_color)
	material.set_shader_parameter("tint_effect_factor", tint_effect_factor)


func apply_chroma_key(material: ShaderMaterial) -> void:
	material.set_shader_parameter("apply_chroma_key", enable_chroma_key)

	if enable_chroma_key:
		material.set_shader_parameter("key_color", chroma_key_color)
		material.set_shader_parameter("key_tolerance", chroma_key_tolerance)
		material.set_shader_parameter("key_softness", chroma_key_softness)


func reset_transform() -> void:
	set_default_transform()


func reset_color_correction() -> void:
	brightness = Editor.default_effects_video.brightness
	contrast = Editor.default_effects_video.contrast
	saturation = Editor.default_effects_video.saturation
	
	red_value = Editor.default_effects_video.red_value
	green_value = Editor.default_effects_video.green_value
	blue_value = Editor.default_effects_video.blue_value
	
	tint_color = Editor.default_effects_video.tint_color
	tint_effect_factor = Editor.default_effects_video.tint_effect_factor


func reset_chroma_key() -> void:
	chroma_key_color = Editor.default_effects_video.chroma_key_color
	chroma_key_tolerance = Editor.default_effects_video.chroma_key_tolerance
	chroma_key_softness = Editor.default_effects_video.chroma_key_softness


func transforms_equal_to_defaults() -> bool:
	if position != Editor.default_effects_video.position: return false
	if size != Editor.default_effects_video.size: return false
	if scale != Editor.default_effects_video.scale: return false
	if rotation != Editor.default_effects_video.rotation: return false
	if pivot != Editor.default_effects_video.pivot: return false
	return true


func color_correction_equal_to_defaults() -> bool:
	if brightness != Editor.default_effects_video.brightness:
		return false
	if contrast != Editor.default_effects_video.contrast:
		return false
	if saturation != Editor.default_effects_video.saturation:
		return false
	
	if red_value != Editor.default_effects_video.red_value:
		return false
	if green_value != Editor.default_effects_video.green_value:
		return false
	if blue_value != Editor.default_effects_video.blue_value:
		return false
	
	if tint_color != Editor.default_effects_video.tint_color:
		return false
	if tint_effect_factor != Editor.default_effects_video.tint_effect_factor:
		return false
	return true


func chroma_key_equal_to_defaults() -> bool:
	if chroma_key_color != Editor.default_effects_video.chroma_key_color:
		return false
	if chroma_key_tolerance != Editor.default_effects_video.chroma_key_tolerance:
		return false
	if chroma_key_softness != Editor.default_effects_video.chroma_key_softness:
		return false
	return true
