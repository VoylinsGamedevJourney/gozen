class_name FileImage extends File

var image_name: String
var image_path: String


# TODO: Check on opening project if file still exists (_init?)


static func create(full_path: String, duration: int) -> FileImage:
	var file_image := FileImage.new()
	file_image.type = TYPE.IMAGE
	file_image.image_name = full_path.split('/')[-1]
	file_image.image_path = full_path.trim_suffix(file_image.image_name)
	file_image.duration = duration
	return file_image


func get_image() -> Image:
	if !FileAccess.file_exists(get_full_path()):
		printerr("Image no longer exists at path '%s'!" % get_full_path())
		return Image.new()
	return Image.load_from_file(get_full_path())


func get_full_path() -> String:
	return image_path + image_name
