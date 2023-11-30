class_name File

enum TYPE { COLOR, IMAGE, TEXT, VIDEO, AUDIO }


const EXT_AUDIO := ["mp3", "wav", "m4a", "flac", "ogg", "aac", "wma", "aiff"]
const EXT_IMAGES := ["jpeg", "jpg", "png", "gif", "tif", "tiff", "bmp", "svg", "webp"]
const EXT_VIDEO := ["mp4", "mov", "avi", "webm", "mkv", "flv", "wmv", "mxf", "ogv"]


var type: TYPE
var duration: int # Duration in frames
