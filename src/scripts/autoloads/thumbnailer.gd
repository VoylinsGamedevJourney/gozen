extends Node

signal thumb_generated(id: int)


const FILE_NAME: String = "%s.webp"
const DATA_NAME: String = "data"


var thumb_folder: String = "%s/gozen/thumbs/" % OS.get_cache_dir()

var data: Dictionary[String, int] = {}  ## { thumb_path : int }
var thumbs_todo: PackedInt64Array = []


func _ready() -> void:
	# Create the thumb directory if not existing.
	if !DirAccess.dir_exists_absolute(thumb_folder):
		var base_cache_dir: String = thumb_folder.trim_suffix("thumbs/")

		if DirAccess.make_dir_absolute(base_cache_dir):
			printerr("FilePanel: Couldn't create folder at %s!" % base_cache_dir)
		if DirAccess.make_dir_absolute(thumb_folder):
			printerr("FilePanel: Couldn't create folder at %s!" % thumb_folder)

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
		printerr("FilePanel: Error happened when storing empty thumb data!")


func get_thumb(file_id: int) -> Texture2D:
	var file_index: int = Project.files.index_map[file_id]
	var file_path: String = Project.data.files_path[file_index]
	var image: Image

	# Check if color or image.
	if file_path in ["temp://color", "temp://image"]:
		var temp: Variant = Project.files.file_data[file_index].image_data
		if !temp or temp != ImageTexture:
			return null

		var image_tex: ImageTexture = temp
		image = scale_thumbnail(image_tex.get_image())
		return ImageTexture.create_from_image(image)
	elif file_path == "temp://text":
		printerr("FilePanel: Thumbnailer: No thumbnails for text yet!")
		return null

	# Check if thumb has been made and actually exists.
	# If file didn't exist, deleting entry to create new.
	if data.has(file_path) and !FileAccess.file_exists(thumb_folder + FILE_NAME % data[file_path]):
		data.erase(file_path)
		_save_data()

	# Not thumb has been made yet, return default and put id in waiting line.
	if !data.has(file_path):
		thumbs_todo.append(file_id)
		# Add the correct placeholder image.
		match Project.data.files_type[file_index]:
			EditorCore.TYPE.AUDIO: return _get_default_thumb(Library.THUMB_DEFAULT_AUDIO)
			EditorCore.TYPE.TEXT: return _get_default_thumb(Library.THUMB_DEFAULT_TEXT)
			_: return _get_default_thumb(Library.THUMB_DEFAULT_VIDEO) # Video placeholder.

	# Return the saved thumbnail.
	var raw_path: String = thumb_folder + FILE_NAME % data[file_path]
	image = Image.load_from_file(ProjectSettings.globalize_path(raw_path))
	return ImageTexture.create_from_image(image)


func _get_default_thumb(icon_uid: String) -> Texture2D:
	var image_tex: CompressedTexture2D = load(icon_uid)
	var image: Image = scale_thumbnail(image_tex.get_image())
	return ImageTexture.create_from_image(image)

# This function is for generating thumbnails, should only be called from the
# _process function and in a thread through Threader.

func _gen_thumb(file_id: int) -> void:
	if !Project.files.index_map.has(file_id):
		return
	var file_index: int = Project.files.index_map[file_id]
	var file_path: String = Project.data.files_path[file_index]
	var file_type: EditorCore.TYPE = Project.data.files_type[file_index] as EditorCore.TYPE
	var image: Image

	match file_type:
		EditorCore.TYPE.IMAGE: image = Image.load_from_file(file_path)
		EditorCore.TYPE.AUDIO: image = Project.files.generate_audio_thumb(file_id)
		EditorCore.TYPE.VIDEO, EditorCore.TYPE.VIDEO_ONLY:
			var temp: Variant = Project.files.file_data[file_index]
			if !temp or temp is not GoZenVideo:
				return
			var video: GoZenVideo = temp
			image = video.generate_thumbnail_at_frame(0)

	# Resizing the image with correct aspect ratio for non-audio thumbs.
	if file_type != EditorCore.TYPE.AUDIO:
		image = scale_thumbnail(image)
	if image.save_webp(thumb_folder + FILE_NAME % file_id):
		return printerr("FilePanel: Something went wrong saving thumb!")

	Threader.mutex.lock()
	data[file_path] = file_id
	_save_data()
	Threader.mutex.unlock()


func scale_thumbnail(image: Image) -> Image:
	if !image:
		return Image.create_empty(1, 1, false, Image.FORMAT_L8)
	var image_scale: float = min(107 / float(image.get_width()), 60 / float(image.get_height()))
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
