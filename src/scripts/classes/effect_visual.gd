class_name EffectVisual
extends Effect

@export var shader_path: String
@export var shader_passes: int = 1
@export var matrix_map: Dictionary[String, Matrix.TYPE]

@export var custom_overlay_path: String ## UID which leads to the EffectOverlay.



func get_custom_overlay() -> EffectVisualOverlay:
	if FileAccess.file_exists(custom_overlay_path):
		return load(custom_overlay_path) as EffectVisualOverlay
	return null
