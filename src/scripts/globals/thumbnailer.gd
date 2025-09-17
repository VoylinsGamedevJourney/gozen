extends Node


signal thumb_generated(id: int)


const FILE_NAME: String = "%s.webp"
const DATA_NAME: String = "data"


var thumb_folder: String = "%s/gozen/thumbs/" % OS.get_cache_dir()

var data: Dictionary[String, int] = {}  # { Path, int }
var thumbs_todo: PackedInt64Array = []



func _ready() -> void:
	# Create the thumb directory if not existing.
	if !DirAccess.dir_exists_absolute(thumb_folder):
		var base_cache_dir: String = thumb_folder.trim_suffix("thumbs/")

		if DirAccess.make_dir_absolute(base_cache_dir):
			printerr("Couldn't create folder at %s!" % base_cache_dir)
		if DirAccess.make_dir_absolute(thumb_folder):
			printerr("Couldn't create folder at %s!" % thumb_folder)

	# Create the thumb data file if not existing.
	if !FileAccess.file_exists(thumb_folder + DATA_NAME):
		_save_data()


func _process(_delta: float) -> void:
	if thumbs_todo.size():
		# We only do one at the time to avoid issues.
		var id: int = thumbs_todo[0]

		Threader.add_task(_gen_thumb.bind(id), thumb_generated.emit.bind(id))
		thumbs_todo.remove_at(0)


func _save_data() -> void:
	if !FileAccess.open(thumb_folder + DATA_NAME, FileAccess.WRITE).store_var(data):
		printerr("Error happened when storing empty thumb data!")


func get_thumb(file_id: int) -> Texture2D:
	var file: File = FileManager.get_file(file_id)
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
	if data.has(path) and !FileAccess.file_exists(thumb_folder + FILE_NAME % data[path]):
		if data.erase(path):
			Toolbox.print_erase_error()

		_save_data()

	# Not thumb has been made yet, return default and put id in waiting line.
	if !data.has(path):
		if thumbs_todo.append(file_id):
			Toolbox.print_append_error()

		# Add the correct placeholder image.
		match FileManager.get_file(file_id).type:
			File.TYPE.AUDIO:
				return _get_default_thumb_audio()
			File.TYPE.TEXT:
				return _get_default_thumb_text()
			_: # Video placeholder.
				return _get_default_thumb_video()

	# Return the saved thumbnail.
	image = Image.load_from_file(ProjectSettings.globalize_path(thumb_folder + FILE_NAME % data[path]))

	return ImageTexture.create_from_image(image)


func _get_default_thumb_audio() -> Texture2D:
	var tex: Texture2D = preload(Library.THUMB_DEFAULT_AUDIO)
	return ImageTexture.create_from_image(scale_thumbnail(tex.get_image()))


func _get_default_thumb_video() -> Texture2D:
	var tex: Texture2D = preload(Library.THUMB_DEFAULT_VIDEO)
	return ImageTexture.create_from_image(scale_thumbnail(tex.get_image()))


func _get_default_thumb_text() -> Texture2D:
	var tex: Texture2D = preload(Library.THUMB_DEFAULT_TEXT)
	return ImageTexture.create_from_image(scale_thumbnail(tex.get_image()))


# This function is for generating thumbnails, should only be called from the
# _process function and in a thread through Threader.
func _gen_thumb(file_id: int) -> void:
	if !FileManager.has_file(file_id):
		return

	var file: File = FileManager.get_file(file_id)
	var path: String = file.path
	var type: File.TYPE = file.type
	var image: Image

	match type:
		File.TYPE.IMAGE:
			image = Image.load_from_file(path)
		File.TYPE.VIDEO:
			image = FileManager.get_file_data(file_id).video.generate_thumbnail_at_frame(0)
		File.TYPE.AUDIO:
			image = await FileManager.get_file_data(file_id).generate_audio_thumb()
	
	# Resizing the image with correct aspect ratio for non-audio thumbs.
	if type != File.TYPE.AUDIO:
		image = scale_thumbnail(image)

	if image.save_webp(thumb_folder + FILE_NAME % file_id):
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
	
	var border_extra: int = int(float(107 - image.get_width()) / 2.0)

	if border_extra != 0:
		image.flip_x()
		image.crop(image.get_width() + border_extra, 60)
		image.flip_x()
		image.crop(107, 60)

	return image

