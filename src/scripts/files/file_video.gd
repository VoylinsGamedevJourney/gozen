class_name FileVideo extends File


const EXTENSIONS: PackedStringArray = [
		"mp4", "mov", "avi", "mkv",
		"webm", "flv", "mpeg", "mpg",
		"wmv", "asf", "vob", "ts",
		"m2ts", "mts", "3gp", "3g2"]


var file_path: String = ""
var sha256: String = ""



func _init() -> void:
	type = FILE_VIDEO
	# TODO: file_effects = Apply default effects such as transform and volume


static func create(a_file_path: String) -> FileVideo:
	if not a_file_path.split('.')[-1].to_lower() in EXTENSIONS:
		printerr("File is not a video file!")
		return FileVideo.new()
	var l_file: FileVideo = FileVideo.new()
	l_file.file_path = a_file_path
	l_file.sha256 = FileAccess.get_sha256(a_file_path)
	l_file.nickname = a_file_path.split('/')[-1].split('.')[0]
	
	# TODO: Add this to Project settings during data loading
	var l_video: Video = Video.new()
	l_video.open(a_file_path)
	l_file.duration = l_video.get_total_frame_nr() / l_video.get_framerate()
	l_video.close()
	
	return l_file
