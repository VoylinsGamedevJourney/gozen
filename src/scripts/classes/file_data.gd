class_name FileData extends Node


var id: int

var image: ImageTexture = null
var audio: AudioStreamWAV = null
var video: Array[Video] = []

var padding: int = 0
var resolution: Vector2i = Vector2i.ZERO
var uv_resolution: Vector2i = Vector2i.ZERO
var frame_count: int = 0
var framerate: float = 0.0

var current_frame: PackedInt64Array = []



func get_duration() -> int:
	var l_file: File = Project.files[id]
	if l_file.duration == -1:
		# We need to calculate the duration first
		match l_file.type:
			File.TYPE.IMAGE: l_file.duration = Settings.default_image_duration
			File.TYPE.AUDIO:
				l_file.duration = AudioHandler.get_audio_duration(audio)
			File.TYPE.VIDEO:
				l_file.duration = floor(floor(video[0].get_frame_count() /
						video[0].get_framerate()) * Project.framerate)

	if l_file.duration == 0:
		printerr("Something went wrong loading file ", id, ", duration is 0!")

	load_wave()
	return Project.files[id].duration


func load_wave() -> void:
	return
#	if raw_audio.size() != 0:
#		wave = Audio.get_audio_wave(raw_audio, Project.framerate)


func init_data(a_id: int) -> void:
	id = a_id
	var l_file: File = Project.files[id]

	if l_file.type == File.TYPE.IMAGE:
		var l_image: Image = Image.load_from_file(l_file.path)
		image = ImageTexture.create_from_image(l_image)
	if l_file.type == File.TYPE.VIDEO:
		# At this moment we have by default 6 tracks
		# TODO: Find a better way instead of creating a new video object
		# for each track. A possible solution could be to create a separate
		# array which can tell if a certain video object is in use or not
		# by a certain clip. And have a function check if all these objects
		# are being used or not, if yes, we add a new one unless we reached
		# the amount of tracks in the timeline. This way there will always
		# be an extra video class so there can't be any lag from creating
		# a new video class instance
		Threader.tasks.append(Threader.Task.new(WorkerThreadPool.add_task(
				_load_video_data.bind(l_file.path)),
				_set_video_meta_data.bind(l_file.path)))

		for i: int in 5:
			Threader.tasks.append(Threader.Task.new(WorkerThreadPool.add_task(
						_load_video_data.bind(l_file.path))))

	if l_file.type in View.AUDIO_TYPES:
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
	video.append(l_video)
	if current_frame.append(0):
		printerr("Couldn't append to current frame!")
	Threader.mutex.unlock()


func _set_video_meta_data(a_file_path: String) -> void:
	# Set necessary metadata
	# TODO: Create a function in GDE GoZen which gets this meta data
	# instead of having this metadata in every video instance

	resolution = video[0].get_resolution()
	padding = video[0].get_padding()
	uv_resolution = Vector2i(int((resolution.x + padding) / 2.), int(resolution.y / 2.))
	frame_count = video[0].get_frame_count()
	framerate = video[0].get_framerate()
	print("Video ", a_file_path, " fully loaded")

