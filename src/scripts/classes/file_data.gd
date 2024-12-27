class_name FileData extends Node


var id: int

var image: ImageTexture = null
var audio: PackedByteArray = []
var video: Array[Video] = []


func get_type() -> File.TYPE:
	return Project.files[id].type


func get_duration() -> int:
	var l_file: File = Project.files[id]
	if l_file.duration == -1:
		# We need to calculate the duration first
		match l_file.type:
			File.TYPE.IMAGE: l_file.duration = Settings.default_image_duration
			File.TYPE.AUDIO:
				l_file.duration = int(
						float(audio.size()) / AudioHandler.bytes_per_frame)
			File.TYPE.VIDEO:
				l_file.duration = int(
						float(audio.size()) / AudioHandler.bytes_per_frame)

	return Project.files[id].duration


func init_data() -> void:
	var l_file: File = Project.files[id]
	match get_type():
		File.TYPE.IMAGE:
			image = ImageTexture.create_from_image(Image.load_from_file(l_file.path))
		File.TYPE.AUDIO: audio = Audio.get_audio_data(l_file.path)
		File.TYPE.VIDEO:
			# At this moment we have by default 6 tracks
			for i: int in 6:
				var l_video: Video = Video.new()

				if l_video.open(l_file.path):
					printerr("Something went wrong opening video at path '%s'!" %
							l_file.path)
				else:
					video.append(l_video)

			# Adding audio from video file individually
			audio = Audio.get_audio_data(l_file.path)

