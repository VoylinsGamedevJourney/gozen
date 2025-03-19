class_name AudioData
extends FileData


var audio: AudioStreamWAV = null



func _update_duration() -> void:
	get_file().duration = floor(
			float(audio.data.size()) / (4 * 44101) * Project.get_framerate())

