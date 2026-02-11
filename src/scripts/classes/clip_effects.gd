class_name ClipEffects
extends RefCounted

var video: Array[GoZenEffectVisual] = []
var audio: Array[GoZenEffectAudio] = []

var fade_visual: Vector2i ## { x = fade_in, y = fade_out }
var fade_audio: Vector2i ## { x = fade_in, y = fade_out }

var ato_active: bool = false
var ato_offset: float = 0.0 # Seconds
var ato_id: int = -1
