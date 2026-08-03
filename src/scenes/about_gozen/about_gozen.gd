extends PanelContainer

const URL: String = "[color=#A718F1][url=URL]URL[/url][/color]"
const PROJECT_SETTING_VERSION: String = "application/config/version"


@export var line_edit_version: LineEdit
@export var rich_text_label_website: RichTextLabel
@export var rich_text_label_source_code: RichTextLabel
@export var rich_text_label_discord: RichTextLabel
@export var rich_text_label_youtube: RichTextLabel
@export var rich_text_label_support: RichTextLabel

@export var rich_text_label_made_by: RichTextLabel
@export var rich_text_label_license: RichTextLabel



func _ready() -> void:
	line_edit_version.text = "%s%s" % [
			ProjectSettings.get_setting(PROJECT_SETTING_VERSION),
			"-debug" if OS.is_debug_build() else "-debug"]

	rich_text_label_website.text = "[url=URL]URL".replace("URL", ProjectSettings.get_setting("urls/site") as String)
	rich_text_label_source_code.text = "[url=URL]URL".replace("URL", ProjectSettings.get_setting("urls/source_code") as String)
	rich_text_label_discord.text = "[url=URL]URL".replace("URL", ProjectSettings.get_setting("urls/discord") as String)
	rich_text_label_support.text = "[url=URL]URL".replace("URL", ProjectSettings.get_setting("urls/support") as String)
	rich_text_label_youtube.text = "[url=URL]URL".replace("URL", ProjectSettings.get_setting("urls/youtube_channel") as String)

	rich_text_label_made_by.text = "[center]" + tr("Made by [url=%s]Voylin's Gamedev Journey[/url]!") % [
			"https://youtube.com/@VoylinsGamedevJourney"]
	rich_text_label_license.text = "[center]" + tr("License") + ": [url=%s]GPLv3" % ProjectSettings.get_setting("urls/license")


func _input(event: InputEvent) -> void:
	if event.is_action_pressed("ui_cancel"):
		_on_close_button_pressed()


func _on_close_button_pressed() -> void:
	PopupManager.close(PopupManager.CREDITS)


func _on_links_label_meta_clicked(meta: Variant) -> void:
	Utils.open_url(str(meta))
