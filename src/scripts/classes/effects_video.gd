class_name EffectsVideo
extends Node



var position: Vector2i = Vector2i.ZERO
var size: Vector2i = Vector2i.ZERO
var scale: float = 100
var rotation: float = 0
var pivot: Vector2i = Vector2i.ZERO

var alpha: float = 1.0

var brightness: float = 0.0 # Min: -1.0, Max: 1.0
var contrast: float = 1.0 # Min: -1.0, Max: 1.0
var saturation: float = 1.0 # Min: -1.0, Max: 1.0

var red_value: float = 1.0 # Min: 0.0, Max: 1.0
var green_value: float = 1.0 # Min: 0.0, Max: 1.0
var blue_value: float = 1.0 # Min: 0.0, Max: 1.0

var tint_color: Color = Color.BLACK
var tint_effect_factor: float = 0.0 # Min: 0.0, Max: 1.0

var enable_chroma_key: bool = false
var chroma_key_color: Color = Color.LIME_GREEN
var chroma_key_tolerance: float = 0.3 # Min: 0.0, Max 1.0
var chroma_key_softness: float = 0.05 # Min: 0.0, Max 0.5



func update_transform() -> void:
	position = Vector2i.ZERO
	size = Project.get_resolution()
	pivot = Vector2i(int(size.x as float / 2), int(size.y as float / 2))

