extends Label
## Version Label
##
## A script which you can attach to a node to get the current GoZen version
## as text for your label.

var version: String = ProjectSettings.get_setting("application/config/version")


func _ready() -> void:
	_set_text()
	SettingsManager._on_language_changed.connect(_set_text)


func _set_text(_new_language: String = "") -> void:
	set_text("%s: %s" % [tr("TEXT_VERSION"), version])
