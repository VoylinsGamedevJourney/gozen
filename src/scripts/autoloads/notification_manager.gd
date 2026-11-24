extends Node

const WINDOWS_SCRIPT: String = "[Windows.UI.Notifications.ToastNotificationManager, Windows.UI.Notifications, ContentType = WindowsRuntime] > $null; [Windows.Data.Xml.Dom.XmlDocument, Windows.Data.Xml.Dom.XmlDocument, ContentType = WindowsRuntime] > $null; $xml = New-Object Windows.Data.Xml.Dom.XmlDocument; $xml.LoadXml('<toast><visual><binding template=\"ToastText02\"><text id=\"1\">%s</text><text id=\"2\">%s</text></binding></visual></toast>'); $toast = [Windows.UI.Notifications.ToastNotification]::new($xml); [Windows.UI.Notifications.ToastNotificationManager]::CreateToastNotifier('GoZen').Show($toast)"

const LINUX_ICON_INFO: String = "dialog-information"
const LINUX_ICON_WARN: String = "dialog-warning"
const LINUX_ICON_ERR: String = "dialog-error"


var is_linux: bool = OS.get_name() == "Linux"
var is_macos: bool = OS.get_name() == "macOS"
var is_windows: bool = OS.get_name() == "Windows"



func info(text: String) -> void: _send("Info", text, LINUX_ICON_INFO)
func error(text: String) -> void: _send("Error", text, LINUX_ICON_ERR)
func warning(text: String) -> void:	_send("Warn", text, LINUX_ICON_WARN)


func _send(type: String, text: String, linux_icon: String) -> void:
	var title: String = "GoZen " + type # NO_TRANSLATE

	Print.info("NotificationManager", title, " - ", text) # We print to have a better log of what's happening.
	if DisplayServer.window_is_focused() or (DisplayServer.get_window_list().size() > 1 and DisplayServer.window_is_focused(1)):
		return # No sending of notifications if inside of the editor.

	if is_linux: OS.execute("notify-send", ["-i", linux_icon, title, text])
	elif is_macos: OS.execute("osascript", ["-e", "display notification \"%s\" with title \"%s\"" % [text.replace('"', '\\"'), title.replace('"', '\\"')] ])
	elif is_windows: OS.execute("powershell", ["-Command", WINDOWS_SCRIPT % [title.replace("'", "''"), text.replace("'", "''")]])
