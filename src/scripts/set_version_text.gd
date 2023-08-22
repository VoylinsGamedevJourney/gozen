extends Label

func _ready() -> void: 
	set_version_string(VersionCheck.version_string)
	VersionCheck._on_change.connect(set_version_string)


func set_version_string(version_string) -> void:
	self.text = version_string
