extends Node


signal thumb_generated(id: int)


const THUMB_FOLDER: String = "user://thumbs/"
const FILE_PATH: String = "user://thumbs/%s.webp"
const DATA_PATH: String = "user://thumbs/data"


var data: Dictionary[String, int] = {}  # { Path, int }
var thumbs_todo: PackedInt64Array = []



func _ready() -> void:
	# Create the thumb directory if not existing.
	if !DirAccess.dir_exists_absolute(THUMB_FOLDER):
		if DirAccess.make_dir_absolute(THUMB_FOLDER):
			printerr("Couldn't create folder at %s!" % THUMB_FOLDER)

	# Create the thumb data file if not existing.
	if !FileAccess.file_exists(DATA_PATH):
		_save_data()


func _process(_delta: float) -> void:
	if thumbs_todo.size():
		# We only do one at the time to avoid issues.
		var id: int = thumbs_todo[0]

		Threader.add_task(_gen_thumb.bind(id), thumb_generated.emit.bind(id))
		thumbs_todo.remove_at(0)


func _save_data() -> void:
	if !FileAccess.open(DATA_PATH, FileAccess.WRITE).store_var(data):
		printerr("Error happened when storing empty thumb data!")


func get_thumb(file_id: int) -> Texture2D:
	var file: File = Project.get_file(file_id)
	var path: String = file.path
	var image: Image

	# Check if color or image.
	if file.path in ["temp://color", "temp://image"]:
		image = scale_thumbnail(file.temp_file.image_data.get_image())
		return ImageTexture.create_from_image(image)
	elif file.path == "temp://text":
		printerr("No thumbnails for text yet!")
		return

	# Check if thumb has been made and actually exists.
	# If file didn't exist, deleting entry to create new.
	if data.has(path) and !FileAccess.file_exists(FILE_PATH % data[path]):
		if data.erase(path):
			Toolbox.print_erase_error()

		_save_data()

	# Not thumb has been made yet, return default and put id in waiting line.
	if !data.has(path):
		if thumbs_todo.append(file_id):
			Toolbox.print_append_error()

		# Add the correct placeholder image.
		match Project.get_file(file_id).type:
			File.TYPE.AUDIO:
				return preload("uid://cs5gcg8kix42x")
			File.TYPE.TEXT:
				return preload("uid://dqv5j4hytkcya")
			_: # Video placeholder.
				return preload("uid://dpg11eiuwgv38")

	# Return the saved thumbnail.
	image = Image.load_from_file(ProjectSettings.globalize_path(FILE_PATH % data[path]))

	return ImageTexture.create_from_image(image)


# This function is for generating thumbnails, should only be called from the
# _process function and in a thread through Threader.
func _gen_thumb(file_id: int) -> void:
	var file: File = Project.get_file(file_id)
	var path: String = file.path
	var type: File.TYPE = file.type
	var image: Image

	match type:
		File.TYPE.IMAGE:
			image = Image.load_from_file(path)
		File.TYPE.VIDEO:
			image = Project.get_file_data(file_id).video.generate_thumbnail_at_frame(0)
		File.TYPE.AUDIO:
			image = await Project.get_file_data(file_id).generate_audio_thumb()
	
	# Resizing the image with correct aspect ratio for non-audio thumbs.
	if type != File.TYPE.AUDIO:
		image = scale_thumbnail(image)

	if image.save_webp(FILE_PATH % file_id):
		printerr("Something went wrong saving thumb!")

	Threader.mutex.lock()
	data[path] = file_id
	_save_data()
	Threader.mutex.unlock()


func scale_thumbnail(image: Image) -> Image:
	var image_scale: float = min(
			107 / float(image.get_width()),
			60 / float(image.get_height()))

	image.resize(
			int(image.get_width() * image_scale),
			int(image.get_height() * image_scale),
			Image.INTERPOLATE_BILINEAR)

	return image


