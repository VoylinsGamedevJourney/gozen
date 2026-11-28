extends Node

const WINDOWS_SCRIPT: String = "[Windows.UI.Notifications.ToastNotificationManager, Windows.UI.Notifications, ContentType = WindowsRuntime] > $null; [Windows.Data.Xml.Dom.XmlDocument, Windows.Data.Xml.Dom.XmlDocument, ContentType = WindowsRuntime] > $null; $xml = New-Object Windows.Data.Xml.Dom.XmlDocument; $xml.LoadXml('<toast><visual><binding template=\"ToastText02\"><text id=\"1\">%s</text><text id=\"2\">%s</text></binding></visual></toast>'); $toast = [Windows.UI.Notifications.ToastNotification]::new($xml); [Windows.UI.Notifications.ToastNotificationManager]::CreateToastNotifier('GoZen').Show($toast)"

const LINUX_ICON_INFO: String = "dialog-information"
const LINUX_ICON_WARN: String = "dialog-warning"
const LINUX_ICON_ERR: String = "dialog-error"

const POPUP_WIDTH: float = 280.0
const MAX_VISIBLE_NOTIFICATIONS: int = 5

const DISPLAY_DURATION: float = 1.2
const FADE_IN_DURATION: float = 0.2
const FADE_OUT_DURATION: float = 0.35


var is_linux: bool = OS.get_name() == "Linux"
var is_macos: bool = OS.get_name() == "macOS"
var is_windows: bool = OS.get_name() == "Windows"

var notification_layer: CanvasLayer
var notifications_vbox: VBoxContainer



func _ready() -> void:
	notification_layer = CanvasLayer.new()
	notification_layer.layer = 110
	add_child(notification_layer)

	var anchor_margin: MarginContainer = MarginContainer.new()
	anchor_margin.mouse_filter = Control.MOUSE_FILTER_IGNORE
	anchor_margin.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_RIGHT)
	anchor_margin.grow_horizontal = Control.GROW_DIRECTION_BEGIN
	anchor_margin.grow_vertical = Control.GROW_DIRECTION_BEGIN
	anchor_margin.add_theme_constant_override("margin_right", 16)
	anchor_margin.add_theme_constant_override("margin_bottom", 16)
	notification_layer.add_child(anchor_margin)

	notifications_vbox = VBoxContainer.new()
	notifications_vbox.mouse_filter = Control.MOUSE_FILTER_IGNORE
	notifications_vbox.alignment = BoxContainer.ALIGNMENT_END
	notifications_vbox.add_theme_constant_override("separation", 8)
	anchor_margin.add_child(notifications_vbox)


func info(text: String) -> void: _send("Info", text, LINUX_ICON_INFO)
func error(text: String) -> void: _send("Error", text, LINUX_ICON_ERR)
func warning(text: String) -> void:	_send("Warn", text, LINUX_ICON_WARN)


func _send(type: String, text: String, linux_icon: String) -> void:
	var title: String = "GoZen " + type # NO_TRANSLATE

	Print.info("NotificationManager", title, "-", text) # We print to have a better log of what's happening.
	if DisplayServer.window_is_focused() or (DisplayServer.get_window_list().size() > 1 and DisplayServer.window_is_focused(1)):
		_show_popup(type, text)
		return # No sending of notifications if inside of the editor.

	if is_linux: OS.execute("notify-send", ["-i", linux_icon, title, text])
	elif is_macos: OS.execute("osascript", ["-e", "display notification \"%s\" with title \"%s\"" % [text.replace('"', '\\"'), title.replace('"', '\\"')] ])
	elif is_windows: OS.execute("powershell", ["-Command", WINDOWS_SCRIPT % [title.replace("'", "''"), text.replace("'", "''")]])


#--- IN-EDITOR NOTIFICATIONS ---

func _show_popup(type: String, text: String) -> void:
	if not is_node_ready():
		return

	while notifications_vbox.get_child_count() >= MAX_VISIBLE_NOTIFICATIONS:
		var oldest_notification: Node = notifications_vbox.get_child(0)
		notifications_vbox.remove_child(oldest_notification)
		oldest_notification.queue_free()

	var control: Control = Control.new()
	control.mouse_filter = Control.MOUSE_FILTER_IGNORE
	control.modulate.a = 0.9

	var panel: PanelContainer = PanelContainer.new()
	panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	panel.custom_minimum_size = Vector2(POPUP_WIDTH, 0.0)
	panel.add_theme_stylebox_override("panel", _get_popup_panel_style())

	var margin: MarginContainer = MarginContainer.new()
	margin.mouse_filter = Control.MOUSE_FILTER_IGNORE
	panel.add_child(margin)

	var hbox: HBoxContainer = HBoxContainer.new()
	hbox.mouse_filter = Control.MOUSE_FILTER_IGNORE
	hbox.add_theme_constant_override("separation", 8)
	margin.add_child(hbox)

	var accent_bar: ColorRect = ColorRect.new()
	accent_bar.mouse_filter = Control.MOUSE_FILTER_IGNORE
	accent_bar.custom_minimum_size = Vector2(3.0, 0.0)
	accent_bar.color = _get_accent_color(type)
	hbox.add_child(accent_bar)

	var text_vbox: VBoxContainer = VBoxContainer.new()
	text_vbox.mouse_filter = Control.MOUSE_FILTER_IGNORE
	text_vbox.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	text_vbox.add_theme_constant_override("separation", 2)
	hbox.add_child(text_vbox)

	var title_label: Label = Label.new()
	title_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	title_label.theme_type_variation = &"title_label"
	title_label.text = _get_type_title(type)
	text_vbox.add_child(title_label)

	var message_label: Label = Label.new()
	message_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	message_label.custom_minimum_size = Vector2(POPUP_WIDTH - 28.0, 0.0)
	message_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	message_label.text = text
	text_vbox.add_child(message_label)

	control.add_child(panel)
	notifications_vbox.add_child(control)
	var sync_slot_size: Callable = func() -> void:
			if is_instance_valid(control) and is_instance_valid(panel):
				var combined_size: Vector2 = panel.get_combined_minimum_size()
				control.custom_minimum_size = combined_size
				panel.size = combined_size
	panel.position = Vector2(0.0, 16)
	panel.minimum_size_changed.connect(sync_slot_size)
	sync_slot_size.call()

	var tween: Tween = panel.create_tween()
	tween.set_parallel(true)
	tween.tween_property(panel, "position:y", 0.0, FADE_IN_DURATION)\
			.set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	tween.tween_property(panel, "modulate:a", 1.0, FADE_IN_DURATION)\
			.set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	tween.set_parallel(false)
	tween.tween_interval(DISPLAY_DURATION)
	tween.tween_property(panel, "modulate:a", 0.0, FADE_OUT_DURATION).\
			set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	tween.tween_callback(control.queue_free)


func _get_popup_panel_style() -> StyleBox:
	var panel_style: StyleBox = notifications_vbox.get_theme_stylebox("panel", "PopupMenu")
	if panel_style == null:
		panel_style = notifications_vbox.get_theme_stylebox("panel", "box")
	return panel_style


func _get_type_title(type: String) -> String:
	if type == "Warn":
		return tr("Warning")
	elif type == "Error":
		return tr("Error")
	return tr("Info")


func _get_accent_color(type: String) -> Color:
	if type == "Warn":
		if notifications_vbox.has_theme_color("loading_color", "ProgressOverlay"):
			return notifications_vbox.get_theme_color("loading_color", "ProgressOverlay")
		return Color.ORANGE
	elif type == "Error":
		if notifications_vbox.has_theme_color("error_color", "ProgressOverlay"):
			return notifications_vbox.get_theme_color("error_color", "ProgressOverlay")
		if notifications_vbox.has_theme_color("font_color", "warning_label"):
			return notifications_vbox.get_theme_color("font_color", "warning_label")
		return Color.RED
	var main_button_style: StyleBox = notifications_vbox.get_theme_stylebox("normal", "main_button")
	if main_button_style is StyleBoxFlat:
		return (main_button_style as StyleBoxFlat).bg_color
	return Library.COLOR_GOZEN_ACCENT
