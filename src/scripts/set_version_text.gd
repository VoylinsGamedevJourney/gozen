extends Label
## Version Text Setter
##
## This script sets the label text to the version of the editor.
## Because this value gets loaded at startup we connect it to the
## _on_change signal so we always display the correct version text.


func _ready() -> void: 
	set_version_string(VersionCheck.version_string)
	VersionCheck._on_change.connect(set_version_string)


func set_version_string(version_string) -> void:
	self.text = version_string
