class_name FileData
extends Node


var id: int


var videos: Array[Video] = []
var video_meta: VideoMeta = null
var audio: AudioStreamWAV = null
var image: ImageTexture = null

var current_frame: PackedInt64Array = []

var padding: int = 0
var resolution: Vector2i = Vector2i.ZERO
var uv_resolution: Vector2i = Vector2i.ZERO
var frame_count: int = 0
var framerate: float = 0.0



func _update_duration() -> void:
	var l_file: File = Project.get_file(id)

	match l_file.type:
		File.TYPE.IMAGE:
			l_file.duration = Settings.get_image_duration()
		File.TYPE.AUDIO:
			l_file.duration = floor(float(audio.data.size()) / (4 * 44101) * Project.get_framerate())
		File.TYPE.VIDEO:
			l_file.duration = floor(floor(video_meta.get_frame_count() /
					video_meta.get_framerate()) * Project.get_framerate())

	if l_file.duration == 0:
		printerr("Something went wrong loading file '%s', duration is 0!" % id)


func init_data(a_id: int) -> void:
	id = a_id

	var l_file: File = Project.get_file(id)

	if l_file.type == File.TYPE.IMAGE:
		if l_file.temp_file != null:
			image = l_file.temp_file.image_data
			return

		image = ImageTexture.create_from_image(Image.load_from_file(l_file.path))
	elif l_file.type == File.TYPE.VIDEO:
		video_meta = VideoMeta.new()

		if video_meta.load_meta(l_file.path):
			printerr("Failed loading video file meta data!")

		# Set necessary metadata
		resolution = video_meta.get_resolution()
		padding = video_meta.get_padding()
		uv_resolution = Vector2i(int((resolution.x + padding) / 2.), int(resolution.y / 2.))
		frame_count = video_meta.get_frame_count()
		framerate = video_meta.get_framerate()

		Threader.tasks.append(Threader.Task.new(WorkerThreadPool.add_task(
				_load_video_data.bind(l_file.path))))

		for i: int in 5:
			Threader.tasks.append(Threader.Task.new(WorkerThreadPool.add_task(
						_load_video_data.bind(l_file.path))))

	if l_file.type in Editor.AUDIO_TYPES:
		Threader.tasks.append(Threader.Task.new(WorkerThreadPool.add_task(
				_load_audio_data.bind(l_file.path))))


func _load_audio_data(a_file_path: String) -> void:
	audio = AudioStreamWAV.new()
	audio.mix_rate = 44100
	audio.stereo = true
	audio.format = AudioStreamWAV.FORMAT_16_BITS
	audio.data = Audio.get_audio_data(a_file_path)


func _load_video_data(a_file_path: String) -> void:
	var l_video: Video = Video.new()

	if l_video.open(a_file_path):
		printerr("Couldn't open video at path '%s'!" % a_file_path)
		return

	Threader.mutex.lock()
	videos.append(l_video)
	if current_frame.append(0):
		printerr("Couldn't append to current frame!")
	Threader.mutex.unlock()

