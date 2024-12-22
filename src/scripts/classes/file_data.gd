class_name FileData extends Node


var id: int

var image: Texture2D = null
var audio: AudioStreamWAV = null
var video: Array[Video] = []


func get_type() -> File.TYPE:
	return Project.files[id].type


func get_duration() -> int:
	var l_file: File = Project.files[id]
	if l_file.duration == -1:
		# We need to calculate the duration first
		match l_file.type:
			File.TYPE.IMAGE: l_file.duration = Settings.default_image_duration
			File.TYPE.AUDIO: l_file.duration = 0 # TODO: Get correct duration
			File.TYPE.VIDEO: l_file.duration = 0 # TODO: Get correct duration

	return Project.files[id].duration


func init_data() -> void:
	var l_file: File = Project.files[id]
	match get_type():
		File.TYPE.IMAGE: image = load(l_file.path)
		File.TYPE.AUDIO: audio = Audio.get_wav(l_file.path)
		File.TYPE.VIDEO:
			# At this moment we have by default 6 tracks
			for i: int in 6:
				var l_video: Video = Video.new()

				if l_video.open(l_file.path, false):
					printerr("Something went wrong opening video at path '%s'!" %
							l_file.path)
				else:
					video.append(l_video)

			# Adding audio from video file individually
			audio = Audio.get_wav(l_file.path)
