class_name EffectsVideo
extends Node


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

