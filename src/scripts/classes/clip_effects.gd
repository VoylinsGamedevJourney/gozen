class_name ClipEffects
extends Resource

var video: Array[EffectVisual] = []
var audio: Array[EffectAudio] = []

var fade_visual: Vector2i ## { x = in, y = out }.
var fade_audio: Vector2i ## { x = in, y = out }.

var ato_active: bool = false
var ato_offset: float = 0.0 ## Seconds.
var ato_id: int = -1
