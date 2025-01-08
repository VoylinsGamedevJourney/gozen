class_name FileData extends Node


var id: int

var image: ImageTexture = null
var audio: PackedByteArray = []
var video: Array[Video] = []

var padding: int = 0
var resolution: Vector2i = Vector2i.ZERO
var uv_resolution: Vector2i = Vector2i.ZERO
var frame_duration: int = 0
var framerate: float = 0.0

var current_frame: PackedInt64Array = []


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
				l_file.duration = floor(floor(video[0].get_frame_duration() /
						video[0].get_framerate()) * Project.framerate)

	return Project.files[id].duration


func init_data() -> void:
	var l_file: File = Project.files[id]
	match get_type():
		File.TYPE.IMAGE:
			image = ImageTexture.create_from_image(Image.load_from_file(l_file.path))
		File.TYPE.AUDIO: audio = Audio.get_audio_data(l_file.path)
		File.TYPE.VIDEO:
			# At this moment we have by default 6 tracks
			# TODO: Find a better way instead of creating a new video object
			# for each track. A possible solution could be to create a separate
			# array which can tell if a certain video object is in use or not
			# by a certain clip. And have a function check if all these objects
			# are being used or not, if yes, we add a new one unless we reached
			# the amount of tracks in the timeline. This way there will always
			# be an extra video class so there can't be any lag from creating
			# a new video class instance
			for i: int in 6:
				var l_video: Video = Video.new()

				if l_video.open(l_file.path):
					printerr("Something went wrong opening video at path '%s'!" %
							l_file.path)
				else:
					video.append(l_video)
					if current_frame.append(video[0].seek_frame(0)):
						printerr("Couldn't append to current frame!")

			# Adding audio from video file individually
			audio = Audio.get_audio_data(l_file.path)

			# Set necessary metadata
			# TODO: Create a function in GDE GoZen which gets this meta data
			# instead of having this metadata in every video instance
			resolution = video[0].get_resolution()
			padding = video[0].get_padding()
			uv_resolution = Vector2i(int((resolution.x + padding) / 2.), int(resolution.y / 2.))
			frame_duration = video[0].get_frame_duration()
			framerate = video[0].get_framerate()

