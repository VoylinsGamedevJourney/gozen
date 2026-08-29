class_name ClipEffects
extends Resource


var video: Array[Effect] = []
var audio: Array[Effect] = []

var fade_visual: Vector2i = Vector2i.ZERO ## { x = in, y = out }.
var fade_audio: Vector2i = Vector2i.ZERO ## { x = in, y = out }.

var transition_left: Effect = null
var transition_right: Effect = null

var ato_active: bool = false ## Audio-take-over (renamed to Replace audio).
var ato_offset: float = 0.0 ## Seconds.
var ato_file: int = -1

var is_showing: bool = true
var is_muted: bool = false

var audio_stream_index: int = -1



#--- Data handling ---

func serialize() -> Dictionary:
	var data: Dictionary = {}

	if video.size() != 0: data["video"] = []
	if audio.size() != 0: data["audio"] = []

	if fade_visual != Vector2i.ZERO: data["fade_visual"] = fade_visual
	if fade_audio  != Vector2i.ZERO: data["fade_audio"]  = fade_audio

	if is_showing != true: data["is_showing"] = is_showing
	if is_muted != false:	data["is_muted"] = is_muted
	if ato_active != false: data["ato_active"] = ato_active
	if ato_offset != 0.0:	data["ato_offset"] = ato_offset
	if ato_file != -1:		data["ato_file"] = ato_file
	if audio_stream_index != -1: data["audio_stream_index"] = audio_stream_index

	if transition_left:  data["transition_left"] = transition_left.serialize()
	if transition_right: data["transition_right"] = transition_right.serialize()

	for effect: Effect in video: (data["video"] as Array).append(effect.serialize())
	for effect: Effect in audio:  (data["audio"] as Array).append(effect.serialize())

	return data


func deserialize(data: Dictionary, file_id: int = -1) -> void:
	fade_visual = data.get("fade_visual", Vector2i.ZERO)
	fade_audio = data.get("fade_audio", Vector2i.ZERO)
	ato_active = data.get("ato_active", false)
	ato_offset = data.get("ato_offset", 0.0)
	ato_file = data.get("ato_file", -1)
	is_showing = data.get("is_showing", true)
	is_muted = data.get("is_muted", false)
	audio_stream_index = data.get("audio_stream_index", -1)

	video.clear()
	audio.clear()

	if data.has("video"): _deserialize_video(data, file_id)
	if data.has("audio"): _deserialize_audio(data)

	if data.has("transition_left"):
		var left_id: String = (data["transition_left"] as Dictionary).get("id", "")
		if EffectsHandler.transition_instances.has(left_id):
			transition_left = EffectsHandler.transition_instances[left_id].deep_copy()
			transition_left.deserialize(data["transition_left"] as Dictionary)
	elif EffectsHandler.transition_instances.has("fade"):
		transition_left = EffectsHandler.transition_instances["fade"].deep_copy()

	if data.has("transition_right"):
		var right_id: String = (data["transition_right"] as Dictionary).get("id", "")
		if EffectsHandler.transition_instances.has(right_id):
			transition_right = EffectsHandler.transition_instances[right_id].deep_copy()
			transition_right.deserialize(data["transition_right"] as Dictionary)
	elif EffectsHandler.transition_instances.has("fade"):
		transition_right = EffectsHandler.transition_instances["fade"].deep_copy()


func _deserialize_video(data: Dictionary, file_id: int = -1) -> void:
	for effect_value: Variant in data["video"]:
		if effect_value is Effect:
			video.append(effect_value)
			continue

		var effect_id: String = (effect_value as Dictionary).get("id", "")
		var effect: Effect = null

		if effect_id == "pck_effect_params" and file_id != -1:
			effect = Effect.new()
			effect.id = "pck_effect_params"
			effect.nickname = "Module Parameters"

			var module_data: GoZenModuleScene = FileLogic.file_data.get(file_id)
			if module_data:
				for effect_param: EffectParam in module_data.params:
					effect.params.append(effect_param.duplicate(true))
		elif EffectsHandler.visual_effect_instances.has(effect_id):
			effect = EffectsHandler.visual_effect_instances[effect_id].deep_copy()

		if effect:
			effect.deserialize(effect_value as Dictionary)
			video.append(effect)


func _deserialize_audio(data: Dictionary) -> void:
	for effect_value: Variant in data["audio"]:
		if effect_value is Effect:
			audio.append(effect_value)
			continue

		var effect_id: String = (effect_value as Dictionary).get("id", "")
		if !EffectsHandler.audio_effect_instances.has(effect_id): continue

		var effect: Effect = EffectsHandler.audio_effect_instances[effect_id].deep_copy()
		effect.deserialize(effect_value as Dictionary)
		audio.append(effect)
