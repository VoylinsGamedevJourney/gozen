extends Node
## Different icons for notifications:
## dialog-information: Standard information icon (often a blue 'i' or similar).
## dialog-warning: Warning symbol (usually a yellow exclamation mark).
## dialog-error:


func notify(text: String) -> void:
	_send_notification("GoZen", text, "dialog-information")


func notify_warning(text: String) -> void:
	_send_notification("GoZen Warning", text, "dialog-warning")


func notify_error(text: String) -> void:
	_send_notification("GoZen Error", text, "dialog-error")


#---- Private helper function ----

func _send_notification(title: String, text: String, linux_icon: String) -> void:
	match OS.get_name():
		"Linux": OS.execute("notify-send", ["-i", linux_icon, title, text])
		"macOS": OS.execute("osascript", ["-e", 'display notification "%s" with title "%s"' % [text.replace('"', '\\"'), title.replace('"', '\\"')] ])
		"Windows":
			var script: String = "[Windows.UI.Notifications.ToastNotificationManager, Windows.UI.Notifications, ContentType = WindowsRuntime] > $null; [Windows.Data.Xml.Dom.XmlDocument, Windows.Data.Xml.Dom.XmlDocument, ContentType = WindowsRuntime] > $null; $xml = New-Object Windows.Data.Xml.Dom.XmlDocument; $xml.LoadXml('<toast><visual><binding template=\"ToastText02\"><text id=\"1\">%s</text><text id=\"2\">%s</text></binding></visual></toast>'); $toast = [Windows.UI.Notifications.ToastNotification]::new($xml); [Windows.UI.Notifications.ToastNotificationManager]::CreateToastNotifier('GoZen').Show($toast)" % [title.replace("'", "''"), text.replace("'", "''")]
			OS.execute("powershell", ["-Command", script])
		_: print(title, ": ", text)
