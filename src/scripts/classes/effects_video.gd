class_name EffectsVideo
extends Node

# Default variables can be gotten from anywhere through
# EditorCore.default_effects_video
# This will be helpful if some people want to set defaults which apply to each
# project as we only need to adjust the instance of Editor to apply changes
# anywhere.


var clip_id: int = -1

@export var position: Dictionary[int, Vector2i] = { 0: Vector2i.ZERO }
@export var size: Dictionary[int, Vector2i] = { 0: Vector2i.ZERO }
@export var scale: Dictionary[int, float] = { 0: 100 }
@export var rotation: Dictionary[int, float] = { 0: 0 }
@export var alpha: Dictionary[int, float] = { 0: 1.0 }
@export var pivot: Dictionary[int, Vector2i] = { 0: Vector2i.ZERO }

@export var enable_color_correction: bool = false
@export var brightness: Dictionary[int, float] = { 0: 0.0 } # Min: -1.0, Max: 1.0
@export var contrast: Dictionary[int, float] = { 0: 1.0 } # Min: -1.0, Max: 1.0
@export var saturation: Dictionary[int, float] = { 0: 1.0 } # Min: -1.0, Max: 1.0

@export var red_value: Dictionary[int, float] = { 0: 1.0 } # Min: 0.0, Max: 1.0
@export var green_value: Dictionary[int, float] = { 0: 1.0 } # Min: 0.0, Max: 1.0
@export var blue_value: Dictionary[int, float] = { 0: 1.0 } # Min: 0.0, Max: 1.0

@export var tint_color: Dictionary[int, Color] = { 0: Color.BLACK }
@export var tint_effect_factor: Dictionary[int, float] = { 0: 0.0 } # Min: 0.0, Max: 1.0

@export var enable_chroma_key: bool = false
@export var chroma_key_color: Dictionary[int, Color] = { 0: Color.LIME_GREEN }
@export var chroma_key_tolerance: Dictionary[int, float] = { 0: 0.3 } # Min: 0.0, Max 1.0
@export var chroma_key_softness: Dictionary[int, float] = { 0: 0.05 } # Min: 0.0, Max 0.5

@export var fade_in: int = -1 # In frames
@export var fade_out: int = -1 # In frames




func set_default_transform() -> void:
	position = { 0: Vector2i.ZERO }
	size = { 0: Project.get_resolution() }
	scale = { 0: 100 }
	rotation = { 0: 0 }
	alpha = { 0: 1.0 }
	pivot = { 0: Vector2i(size[0] / 2) }


# TODO: Add animation smoothness and correct values.
func apply_transform(view_texture: TextureRect, material: ShaderMaterial) -> void:
	var start_frame: int = Project.get_clip(clip_id).start_frame
	var current_frame: int = EditorCore.frame_nr - start_frame

	var alpha_adjust: float = 0
	if fade_in != 0 and current_frame <= fade_in:
		alpha_adjust = Toolbox.calculate_fade(current_frame, fade_in)
	if fade_out != 0 and current_frame >= Project.get_clip(clip_id).duration - fade_out:
		current_frame = Project.get_clip(clip_id).duration - current_frame
		alpha_adjust = Toolbox.calculate_fade(current_frame, fade_out)

	view_texture.position = position[0]
	view_texture.set_deferred("size", size[0])
	view_texture.scale = Vector2(scale[0] / 100, scale[0] / 100)
	view_texture.rotation = deg_to_rad(rotation[0])
	material.set_shader_parameter("alpha", maxf(0, alpha[0] - alpha_adjust))
	view_texture.pivot_offset = pivot[0]


# TODO: Add animation smoothness and correct values.
func apply_color_correction(material: ShaderMaterial) -> void:
	material.set_shader_parameter("brightness", brightness[0])
	material.set_shader_parameter("contrast", contrast[0])
	material.set_shader_parameter("saturation", saturation[0])

	material.set_shader_parameter("red_value", red_value[0])
	material.set_shader_parameter("green_value", green_value[0])
	material.set_shader_parameter("blue_value", blue_value[0])

	material.set_shader_parameter("tint_color", tint_color[0])
	material.set_shader_parameter("tint_effect_factor", tint_effect_factor[0])


# TODO: Add animation smoothness and correct values.
func apply_chroma_key(material: ShaderMaterial) -> void:
	material.set_shader_parameter("apply_chroma_key", enable_chroma_key)

	if enable_chroma_key:
		material.set_shader_parameter("key_color", chroma_key_color[0])
		material.set_shader_parameter("key_tolerance", chroma_key_tolerance[0])
		material.set_shader_parameter("key_softness", chroma_key_softness[0])


func reset_transform() -> void:
	set_default_transform()


func reset_fade() -> void:
	fade_in = 0
	fade_out = 0


func reset_color_correction() -> void:
	brightness = EditorCore.default_effects_video.brightness
	contrast = EditorCore.default_effects_video.contrast
	saturation = EditorCore.default_effects_video.saturation
	
	red_value = EditorCore.default_effects_video.red_value
	green_value = EditorCore.default_effects_video.green_value
	blue_value = EditorCore.default_effects_video.blue_value
	
	tint_color = EditorCore.default_effects_video.tint_color
	tint_effect_factor = EditorCore.default_effects_video.tint_effect_factor


func reset_chroma_key() -> void:
	chroma_key_color = EditorCore.default_effects_video.chroma_key_color
	chroma_key_tolerance = EditorCore.default_effects_video.chroma_key_tolerance
	chroma_key_softness = EditorCore.default_effects_video.chroma_key_softness


func transforms_equal_to_defaults() -> bool:
	if position != EditorCore.default_effects_video.position:
		return false
	if size != EditorCore.default_effects_video.size:
		return false
	if scale != EditorCore.default_effects_video.scale:
		return false
	if rotation != EditorCore.default_effects_video.rotation:
		return false
	if pivot != EditorCore.default_effects_video.pivot:
		return false
	return true


func fade_equal_to_defaults() -> bool:
	if fade_in != EditorCore.default_effects_video.fade_in:
		return false
	if fade_out != EditorCore.default_effects_video.fade_out:
		return false
	return true


func color_correction_equal_to_defaults() -> bool:
	if brightness != EditorCore.default_effects_video.brightness:
		return false
	if contrast != EditorCore.default_effects_video.contrast:
		return false
	if saturation != EditorCore.default_effects_video.saturation:
		return false
	
	if red_value != EditorCore.default_effects_video.red_value:
		return false
	if green_value != EditorCore.default_effects_video.green_value:
		return false
	if blue_value != EditorCore.default_effects_video.blue_value:
		return false
	
	if tint_color != EditorCore.default_effects_video.tint_color:
		return false
	if tint_effect_factor != EditorCore.default_effects_video.tint_effect_factor:
		return false
	return true


func chroma_key_equal_to_defaults() -> bool:
	if chroma_key_color != EditorCore.default_effects_video.chroma_key_color:
		return false
	if chroma_key_tolerance != EditorCore.default_effects_video.chroma_key_tolerance:
		return false
	if chroma_key_softness != EditorCore.default_effects_video.chroma_key_softness:
		return false
	return true
