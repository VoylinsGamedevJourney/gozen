class_name EffectsAudio
extends RefCounted


enum MONO { DISABLE = 0, LEFT_CHANNEL = 1, RIGHT_CHANNEL = 2 }

const FADE_OUT_LIMIT: int = -40


var clip_id: int = -1

@export var mute: bool = false
@export var gain: Dictionary[int, float] = { 0: 0 }
@export var mono: MONO = MONO.DISABLE

@export var fade_in: int = 0 # In frames
@export var fade_out: int = 0 # In frames


var _current_gain: float = 0.0



# TODO: Add animation smoothness and correct values.
func apply_basics(bus_index: int) -> bool:
	AudioServer.set_bus_mute(bus_index, mute)

	if mute:
		return false

	AudioServer.set_bus_volume_db(bus_index, gain[0])
	_current_gain = gain[0]

	return true


func apply_fade(bus_index: int) -> void:
	var start_frame: int = Project.get_clip(clip_id).start_frame
	var current_frame: int = EditorCore.frame_nr - start_frame

	var gain_adjust: float = 0
	if fade_in != 0 and current_frame <= fade_in:
		gain_adjust = Utils.calculate_fade(current_frame, fade_in)
	if fade_out != 0 and current_frame >= Project.get_clip(clip_id).duration - fade_out:
		current_frame = Project.get_clip(clip_id).duration - current_frame
		gain_adjust = Utils.calculate_fade(current_frame, fade_out)

	AudioServer.set_bus_volume_db(bus_index, _current_gain + (gain_adjust * FADE_OUT_LIMIT))


func reset_basics() -> void:
	mute = EditorCore.default_effects_audio.mute
	gain = EditorCore.default_effects_audio.gain
	mono = EditorCore.default_effects_audio.mono


func reset_fade() -> void:
	fade_in = 0
	fade_out = 0


func basics_equal_to_defaults() -> bool:
	if mute != EditorCore.default_effects_audio.mute:
		return false
	if gain != EditorCore.default_effects_audio.gain:
		return false
	if mono != EditorCore.default_effects_audio.mono:
		return false
	return true


func fade_equal_to_defaults() -> bool:
	if fade_in != EditorCore.default_effects_audio.fade_in:
		return false
	if fade_out != EditorCore.default_effects_audio.fade_out:
		return false
	return true

