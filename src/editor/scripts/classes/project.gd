class_name Project


var title: String = "Untitled project"
var path: String = ""
var resolution : Vector2i
var framerate: float = 30.0

var files_id: int = 0 
var files: Dictionary = {
	"Color1": FileColor.new(Color.GREEN),
	"Color2": FileColor.new(Color.AQUA),
	"Color3": FileColor.new(Color.FUCHSIA),
}
