extends Label


func _ready() -> void:
	var version: String= ProjectSettings.get_setting("application/config/version")
	text = "%s: %s" % [tr("STARTUP_TEXT_VERSION"), version]
