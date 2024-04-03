class_name FileActual extends File

var file_path: String
var sha256: String


func _init(a_file_path: String = "") -> void:
	file_path = a_file_path
	sha256 = FileAccess.get_sha256(file_path)
	nickname = file_path.split('/')[-1].split('.')[0]


static func get_file_type(a_file_name: String) -> TYPE:
	var l_extension: String = a_file_name.split('.')[-1]
	for l_type: TYPE in SUPPORTED_FORMATS:
		if l_extension in SUPPORTED_FORMATS[l_type]:
			return l_type
	return TYPE.ERROR
