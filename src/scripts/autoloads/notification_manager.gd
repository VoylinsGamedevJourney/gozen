extends Node

const WINDOWS_SCRIPT: String = "[Windows.UI.Notifications.ToastNotificationManager, Windows.UI.Notifications, ContentType = WindowsRuntime] > $null; [Windows.Data.Xml.Dom.XmlDocument, Windows.Data.Xml.Dom.XmlDocument, ContentType = WindowsRuntime] > $null; $xml = New-Object Windows.Data.Xml.Dom.XmlDocument; $xml.LoadXml('<toast><visual><binding template=\"ToastText02\"><text id=\"1\">%s</text><text id=\"2\">%s</text></binding></visual></toast>'); $toast = [Windows.UI.Notifications.ToastNotification]::new($xml); [Windows.UI.Notifications.ToastNotificationManager]::CreateToastNotifier('GoZen').Show($toast)"

const LINUX_ICON_INFO: String = "dialog-information"
const LINUX_ICON_WARN: String = "dialog-warning"
const LINUX_ICON_ERR: String = "dialog-error"



func info(text: String) -> void: 	_send("Info", text, LINUX_ICON_INFO)
func warning(text: String) -> void:	_send("Warn", text, LINUX_ICON_WARN)
func error(text: String) -> void:	_send("Error", text, LINUX_ICON_ERR)


func _send(type: String, text: String, linux_icon: String) -> void:
	var title: String = "GoZen " + type # NO_TRANSLATE

	@warning_ignore_start("return_value_discarded")
	match OS.get_name():
		"Linux": OS.execute("notify-send", ["-i", linux_icon, title, text])
		"macOS": OS.execute("osascript", ["-e", "display notification \"%s\" with title \"%s\"" % [text.replace('"', '\\"'), title.replace('"', '\\"')] ])
		"Windows": OS.execute("powershell", ["-Command", WINDOWS_SCRIPT % [title.replace("'", "''"), text.replace("'", "''")]])
		_: Print.info("NotificationManager", title, " - ", text)
	@warning_ignore_restore("return_value_discarded")
