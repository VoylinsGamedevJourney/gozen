extends Label

var version: String = ProjectSettings.get_setting("application/config/version")


func _ready() -> void:
	_set_text()
	SettingsManager._on_language_changed.connect(_set_text)


func _set_text(_new_language: String = "") -> void:
	set_text("%s: %s" % [tr("TEXT_VERSION"), version])
