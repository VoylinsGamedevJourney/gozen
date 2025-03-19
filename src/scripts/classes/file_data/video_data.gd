class_name VideoData
extends FileData


var videos: Array[Video] = []
var audio: AudioStreamWAV = null
var current_frame: PackedInt64Array = []

var padding: int = 0
var resolution: Vector2i = Vector2i.ZERO
var uv_resolution: Vector2i = Vector2i.ZERO
var frame_count: int = 0
var framerate: float = 0.0



func _update_duration() -> void:
	get_file().duration = floor(floor(videos[0].get_frame_count() /
			videos[0].get_framerate()) * Project.get_framerate())

