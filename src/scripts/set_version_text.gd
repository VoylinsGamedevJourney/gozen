extends Label

func _ready() -> void: 
	set_version_string(Globals.version_string)
	Globals._on_version_string_change.connect(set_version_string)


func set_version_string(version_string) -> void:
	self.text = version_string
