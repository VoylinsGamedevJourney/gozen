class_name File
extends Resource

# TODO: Add functionality to add PCK files (packed scenes)


enum {
	COLOR, TEXT, # GENERATED
	VIDEO, IMAGE, AUDIO, PCK # ACTUAL FILES
}

const PCK_EXT: PackedStringArray = ["pck"]
const COLOR_EXT: PackedStringArray = ["gozenc"]
const TEXT_EXT: PackedStringArray = ["gozent"]
const VIDEO_EXT: PackedStringArray = ["mp4","mov","avi","mkv","webm","flv","mpeg",
									  "mpg","wmv","asf","vob","ts","m2ts","mts","3gp","3g2"]
const AUDIO_EXT: PackedStringArray = ["ogg","wav","mp3"]
const IMAGE_EXT: PackedStringArray = ["png","jpg","svg","webp","bmp","tga","dds","hdr","exr"]


var id: int = -1
var type: int = -1
var nickname: String
var path: String
var sha256: String

var location: String = "/" # Path for file managers inside of GoZen

var duration: int = 0


static func open(a_path: String) -> File:
	var l_file: File = File.new()
	var l_ext: String = a_path.get_extension().to_lower()

	l_file.nickname = a_path.get_file()
	l_file.path = a_path
	l_file.sha256 = FileAccess.get_sha256(a_path)

	if l_ext in PCK_EXT: l_file.type = PCK
	elif l_ext in TEXT_EXT: l_file.type = TEXT
	elif l_ext in VIDEO_EXT: l_file.type = VIDEO
	elif l_ext in AUDIO_EXT: l_file.type = AUDIO
	elif l_ext in IMAGE_EXT: l_file.type = IMAGE
	elif l_ext in COLOR_EXT: l_file.type = COLOR
	else:
		printerr("No valid extension!")
		return null

	return l_file


func get_thumb() -> Texture2D:
	# TODO: Generate thumbs representing the actual data instead of icons,
	# make this int a setting to let people choose.
	match type:
		TEXT: return preload("res://assets/icons/text_file.png")
		VIDEO: return preload("res://assets/icons/video_file.png")
		AUDIO: return preload("res://assets/icons/audio_file.png")
		IMAGE: return preload("res://assets/icons/image_file.png")
		_: return preload("res://assets/icons/file.png")
	
