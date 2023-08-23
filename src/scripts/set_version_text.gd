extends Label
## Version Text Setter
##
## This script sets the label text to the version of the editor.
## Because this value gets loaded at startup we connect it to the
## _on_change signal so we always display the correct version text.


func _ready() -> void: 
	set_version_string(SettingsManager.get_version())
	SettingsManager._on_version_changed.connect(set_version_string)


func set_version_string(version: String) -> void:
	self.text = version
