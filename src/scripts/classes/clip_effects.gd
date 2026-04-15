class_name ClipEffects
extends Resource


var video: Array[EffectVisual] = []
var audio: Array[EffectAudio] = []

var fade_visual: Vector2i ## { x = in, y = out }.
var fade_audio: Vector2i ## { x = in, y = out }.

var ato_active: bool = false
var ato_offset: float = 0.0 ## Seconds.
var ato_file: int = -1

var is_muted: bool = false



#--- Data handling ---

func serialize() -> Dictionary:
	var data: Dictionary = {
		"fade_visual": fade_visual,
		"fade_audio": fade_audio,
		"ato_active": ato_active,
		"ato_offset": ato_offset,
		"ato_file": ato_file,
		"is_muted": is_muted,
		"video": [],
		"audio": []}

	for effect: EffectVisual in video:
		@warning_ignore("unsafe_method_access")
		data["video"].append(effect.serialize())
	for effect: EffectAudio in audio:
		@warning_ignore("unsafe_method_access")
		data["audio"].append(effect.serialize())
	return data


func deserialize(data: Dictionary) -> void:
	fade_visual = data.get("fade_visual", Vector2i.ZERO)
	fade_audio = data.get("fade_audio", Vector2i.ZERO)
	ato_active = data.get("ato_active", false)
	ato_offset = data.get("ato_offset", 0.0)
	ato_file = data.get("ato_file", -1)
	is_muted = data.get("is_muted", false)

	video.clear()
	if data.has("video"):
		_deserialize_video(data)

	audio.clear()
	if data.has("audio"):
		_deserialize_audio(data)


func _deserialize_video(data: Dictionary) -> void:
	for effect_value: Variant in data["video"]:
		if effect_value is EffectVisual:
			video.append(effect_value)
			continue

		var effect_id: String = (effect_value as Dictionary).get("id", "")
		if !EffectsHandler.visual_effect_instances.has(effect_id):
			continue

		var effect: EffectVisual = EffectsHandler.visual_effect_instances[effect_id].deep_copy()
		effect.deserialize(effect_value as Dictionary)
		video.append(effect)


func _deserialize_audio(data: Dictionary) -> void:
	for effect_value: Variant in data["audio"]:
		if effect_value is EffectAudio:
			audio.append(effect_value)
			continue

		var effect_id: String = (effect_value as Dictionary).get("id", "")
		if !EffectsHandler.audio_effect_instances.has(effect_id):
			continue

		var effect: EffectAudio = EffectsHandler.audio_effect_instances[effect_id].deep_copy()
		effect.deserialize(effect_value as Dictionary)
		audio.append(effect)
