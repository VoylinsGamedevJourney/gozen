extends BaseButton

@export var link: String

# Called when the node enters the scene tree for the first time.
func _ready():
	pressed.connect(_on_button_pressed)


func _on_button_pressed() -> void:
	if link == "":
		Printer.error("No link given for button '%s'!" % name)
		return
	if link.contains("http"):
		OS.shell_open(link)
		return
	OS.shell_open(ProjectSettings.get_setting("globals/url/%s" % link))
