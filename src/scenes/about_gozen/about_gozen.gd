extends PanelContainer

const URL: String = "[color=#A718F1][url=URL]URL[/url][/color]"

@export var version_label: Label
@export var links_label: RichTextLabel



func _ready() -> void:
	# Load in info
	_set_version_label()
	_set_links_label()


func _set_version_label() -> void:
	var version_string: String = tr("text_version").capitalize()
	version_string += ProjectSettings.get_setting("application/config/version")

	if OS.is_debug_build():
		version_string += "-debug"

	version_label.text += version_string
	
	
func _set_links_label() -> void:
	var site_url: String = ProjectSettings.get_setting("urls/site")
	var github_url: String = ProjectSettings.get_setting("urls/github")
	var discord_url: String = ProjectSettings.get_setting("urls/discord")
	var support_url: String = ProjectSettings.get_setting("urls/support")
	var youtube_url: String = ProjectSettings.get_setting("urls/youtube_channel")

	var lines: PackedStringArray = [
			tr("text_gozen_website") + ": " + URL.replace("URL", site_url),
			tr("text_github_repo") + ": " + URL.replace("URL", github_url),
			tr("text_discord_link") + ": " + URL.replace("URL", discord_url),
			tr("text_support_gozen") + ": " + URL.replace("URL", support_url),
			"",
			tr("text_gozen_made_by") + " [color=#A718F1][url=URL]Voylin's Gamedev Journey[/url][/color]! ;)".replace("URL", youtube_url)
	]
	for line: String in lines:
		links_label.text += line + "\n"


func _input(event: InputEvent) -> void:
	if event.is_action_pressed("ui_cancel"):
		_on_close_button_pressed()


func _on_close_button_pressed() -> void:
	PopupManager.close_popup(PopupManager.POPUP.CREDITS)


func _on_links_label_meta_clicked(meta: Variant) -> void:
	Utils.open_url(str(meta))

