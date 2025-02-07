extends Node

enum { OFF, LEFT_CHANNEL, RIGHT_CHANNEL }

var mono: int = OFF

#	# Applying Mono effect
#	if effects_audio.mono != effects_audio.MONO.OFF:
#		Project._audio[id] = Audio.change_to_mono(
#				Project._audio[id] as PackedByteArray,
#				effects_audio.mono == effects_audio.MONO.LEFT_CHANNEL)


#func _on_effect_mono_option_button_item_selected(a_index: int) -> void:
#	match a_index:
#		0: current_clip.effects_audio.mono = EffectsAudio.MONO.OFF
#		1: current_clip.effects_audio.mono = EffectsAudio.MONO.LEFT_CHANNEL
#		2: current_clip.effects_audio.mono = EffectsAudio.MONO.RIGHT_CHANNEL
#	current_clip.update_audio_data()

func get_effect_name() -> String:
	## Only displayed when adding effects to clips/files.
	return ""


func get_ui(_update_callable: Callable) -> Control:
	## The actual UI to interact with clips/files, use the argument to connect the
	## needed signals for updating the data.
	return null


func get_one_shot() -> bool:
	## This should only be overriden if the effect can only be aplied once.
	return false


func apply_effect(_id: int) -> void:
	## This will be called in a thread to update the data
	pass

