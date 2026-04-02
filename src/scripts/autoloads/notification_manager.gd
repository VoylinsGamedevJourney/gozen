## Different icons for notifications:
## dialog-information: Standard information icon (often a blue 'i' or similar).
## dialog-warning: Warning symbol (usually a yellow exclamation mark).
## dialog-error:


func notify(text: String) -> void:
	match OS.get_name():
		"Linux": OS.execute("notify-send", ["-i dialog-information", "GoZen", text])
		_: print("Notification system not implemented yet for this OS!")


func notify_warning(text: String) -> void:
	match OS.get_name():
		"Linux": OS.execute("notify-send", ["-i dialog-warning", "GoZen", text])
		_: print("Notification system not implemented yet for this OS!")


func notify_error(text: String) -> void:
	match OS.get_name():
		"Linux": OS.execute("notify-send", ["-i dialog-error", "GoZen", text])
		_: print("Notification system not implemented yet for this OS!")
