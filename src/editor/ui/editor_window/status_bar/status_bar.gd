extends PanelContainer
## StatusBar
##
## At this stage the only thing StatusBar does is display the
## the number version. During ZenMode the statusbar is hidden.


func _ready() -> void:
	$HBox/VersionLabel.text = "%s: %s" % [
			tr("TEXT_VERSION"),
			ProjectSettings.get_setting("application/config/version")]
	
	visible = !SettingsManager.get_zen_mode()
	SettingsManager._on_zen_switched.connect(
			func(value: bool): visible = !value)
