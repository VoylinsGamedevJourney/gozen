class_name FileImage extends File


const EXTENSIONS: PackedStringArray = ["png", "jpg", "svg", "webp", "bmp", "tga", "dds", "hdr", "exr"]


var file_path: String = ""
var sha256: String = ""



func _init(a_file_name: String = "") -> void:
	type = FILE_IMAGE
	duration = SettingsManager.default_image_duration


static func create(a_file_path: String) -> FileImage:
	if not a_file_path.split('.')[-1].to_lower() in EXTENSIONS:
		printerr("File is not an image file!")
		return FileImage.new()
	var l_file: FileImage = FileImage.new()
	l_file.file_path = a_file_path
	l_file.sha256 = FileAccess.get_sha256(a_file_path)
	
	l_file.nickname = a_file_path.split('/')[-1].split('.')[0]
	return l_file
