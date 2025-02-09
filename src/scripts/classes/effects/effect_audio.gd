class_name EffectAudio extends Effect


func update_audio_effect() -> void:
	if clip_id != -1:
		AudioHandler.audio_effect_update(clip_id)
		return
	AudioHandler.audio_effect_update_file(file_id)


func apply_effect(_data: PackedByteArray) -> PackedByteArray:
	## This will be called in a thread to update the data
	return _data


func create_bus_effect(_bus_index: int) -> void:
	pass

