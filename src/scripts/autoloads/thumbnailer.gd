extends Node

signal thumb_generated(id: int)


const FILE_NAME: String = "%s.webp"
const DATA_NAME: String = "data"


var thumb_folder: String = "%s/gozen/thumbs/" % OS.get_cache_dir()

var data: Dictionary[String, int] = {}  ## { thumb_path : file_id }
var thumbs_todo: Array[FileData] = []



func _ready() -> void:
	Project.project_ready.connect(_on_project_ready)

	# Create the thumb directory if not existing.
	if !DirAccess.dir_exists_absolute(thumb_folder):
		var base_cache_dir: String = thumb_folder.trim_suffix("thumbs/")
		if DirAccess.make_dir_absolute(base_cache_dir):
			printerr("FilePanel: Couldn't create folder at %s!" % base_cache_dir)
		if DirAccess.make_dir_absolute(thumb_folder):
			printerr("FilePanel: Couldn't create folder at %s!" % thumb_folder)

	# Create the thumb data file if not existing.
	var data_path: String = thumb_folder + DATA_NAME
	if FileAccess.file_exists(data_path):
		var file: FileAccess = FileAccess.open(data_path, FileAccess.READ)
		data = file.get_var()
	else:
		_save_data()


func _on_project_ready() -> void:
	FileLogic.audio_wave_generated.connect(_on_audio_wave_generated)


func _process(_delta: float) -> void:
	if thumbs_todo.size():
		# We only do one at the time to avoid issues.
		var file: FileData = thumbs_todo[0]
		Threader.add_task(_gen_thumb.bind(file), thumb_generated.emit.bind(file))
		thumbs_todo.remove_at(0)


func _save_data() -> void:
	if !FileAccess.open(thumb_folder + DATA_NAME, FileAccess.WRITE).store_var(data):
		printerr("FilePanel: Error happened when storing empty thumb data!")


func get_thumb(file: FileData) -> Texture2D:
	var image: Image

	# Check if color or image.
	if file.path.begins_with("temp://color") or file.path == "temp://image":
		var temp: Variant = FileLogic.file_data[file.id]
		if !temp or temp is not ImageTexture:
			return null

		var image_tex: ImageTexture = temp
		image = scale_thumbnail(image_tex.get_image())
		return ImageTexture.create_from_image(image)
	elif file.path == "temp://text":
		return _get_default_thumb(Library.THUMB_DEFAULT_TEXT)

	# Check if thumb has been made and actually exists.
	# If file didn't exist, deleting entry to create new.
	Threader.mutex.lock()
	if data.has(file.path) and !FileAccess.file_exists(thumb_folder + FILE_NAME % data[file.path]):
		data.erase(file.path)
		_save_data()

	# Not thumb has been made yet, return default and put id in waiting line.
	var has_thumb: bool = data.has(file.path)
	var thumb_id: int = data.get(file.path, 0)
	Threader.mutex.unlock()

	if !has_thumb:
		thumbs_todo.append(file)
		# Add the correct placeholder image.
		match file.type:
			EditorCore.TYPE.AUDIO: return _get_default_thumb(Library.THUMB_DEFAULT_AUDIO)
			EditorCore.TYPE.TEXT: return _get_default_thumb(Library.THUMB_DEFAULT_TEXT)
			_: return _get_default_thumb(Library.THUMB_DEFAULT_VIDEO) # Video placeholder.

	# Return the saved thumbnail.
	var raw_path: String = thumb_folder + FILE_NAME % thumb_id
	image = Image.load_from_file(ProjectSettings.globalize_path(raw_path))
	if not image or image.is_empty():
		return _get_default_thumb(Library.THUMB_DEFAULT_VIDEO)
	return ImageTexture.create_from_image(image)


func _get_default_thumb(icon_uid: String) -> Texture2D:
	var image_tex: CompressedTexture2D = load(icon_uid)
	var image: Image = scale_thumbnail(image_tex.get_image())
	return ImageTexture.create_from_image(image)


## This function is for generating thumbnails, should only be called from the
## _process function and in a thread through Threader.
func _gen_thumb(file: FileData) -> void:
	var image: Image

	match file.type:
		EditorCore.TYPE.IMAGE: image = Image.load_from_file(file.path)
		EditorCore.TYPE.AUDIO: image = FileLogic.generate_audio_thumb(file)
		EditorCore.TYPE.VIDEO:
			var video: Video = Video.new()
			if video.open(file.path) == OK:
				image = video.generate_thumbnail_at_frame(0)
				video.close()
	if !image: # TODO: Run this function a second or so later as the data will probably be ready by now.
		return

	# Resizing the image with correct aspect ratio for non-audio thumbs.
	if file.type != EditorCore.TYPE.AUDIO:
		image = scale_thumbnail(image)
	if image.save_webp(thumb_folder + FILE_NAME % file.id):
		return printerr("FilePanel: Something went wrong saving thumb!")

	Threader.mutex.lock()
	data[file.path] = file.id
	_save_data()
	Threader.mutex.unlock()


func _on_audio_wave_generated(file: FileData) -> void:
	if file.type != EditorCore.TYPE.AUDIO:
		return

	# Remove the potentially flat/empty cached thumbnail data.
	Threader.mutex.lock()
	if data.has(file.path):
		data.erase(file.path)
		_save_data()
	Threader.mutex.unlock()

	# Queue this file for immediate thumbnail regeneration.
	if not thumbs_todo.has(file):
		thumbs_todo.insert(0, file)


func scale_thumbnail(image: Image) -> Image:
	if !image or image.is_empty():
		return null
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
