extends PanelContainer


const PROJECT_SETTING_VERSION: String = "application/config/version"


@export var line_edit_version: LineEdit
@export var label_website: RichTextLabel
@export var label_source_code: RichTextLabel
@export var label_discord: RichTextLabel
@export var label_youtube: RichTextLabel
@export var label_support: RichTextLabel

@export var label_made_by: RichTextLabel
@export var label_license: RichTextLabel



func _ready() -> void:
	line_edit_version.text = "%s%s" % [
			ProjectSettings.get_setting(PROJECT_SETTING_VERSION),
			"-debug" if OS.is_debug_build() else "-debug"]

	label_website.text = "[url=URL]URL".replace("URL", ProjectSettings.get_setting("urls/site") as String)
	label_source_code.text = "[url=URL]URL".replace("URL", ProjectSettings.get_setting("urls/source_code") as String)
	label_discord.text = "[url=URL]URL".replace("URL", ProjectSettings.get_setting("urls/discord") as String)
	label_support.text = "[url=URL]URL".replace("URL", ProjectSettings.get_setting("urls/support") as String)
	label_youtube.text = "[url=URL]URL".replace("URL", ProjectSettings.get_setting("urls/youtube_channel") as String)

	label_license.text = "[center]" + tr("License") + ": [url=%s]GPLv3" % ProjectSettings.get_setting("urls/license")


func _input(event: InputEvent) -> void:
	if event.is_action_pressed("ui_cancel"):
		_on_close_button_pressed()


func _gui_input(event: InputEvent) -> void:
	if event is InputEventMouseButton:
		var mouse_event: InputEventMouseButton = event as InputEventMouseButton
		if mouse_event.pressed and mouse_event.button_index == MouseButton.MOUSE_BUTTON_LEFT:
			_on_close_button_pressed()


func _on_links_label_meta_clicked(meta: Variant) -> void:
	URL.open(str(meta))


func _on_close_button_pressed() -> void:
	PopupManager.close(PopupManager.CREDITS)
