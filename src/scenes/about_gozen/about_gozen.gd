extends PanelContainer
# TODO: Maybe add a tabbed interface.
# General tab: Logo, version (With a new version available indicator), short description, and links (to site, github, and socials)
# Credits: A list of Sponsors and main contributors (Requirement would be 10 PR's I guess)
# System Info: Technical details for debugging (OS, GPU, RAM) (Add button to copy debug info)
# Licenses: Show the GPLv3 license for GoZen (and the third party licenses?)

const URL: String = "[color=#A718F1][url=URL]URL[/url][/color]"
const PROJECT_SETTING_VERSION: String = "application/config/version"

@export var version_label: Label
@export var links_label: RichTextLabel



func _ready() -> void:
	_set_version_label()
	_set_links_label()


func _set_version_label() -> void:
	var version_string: String = tr("GoZen version") + ": "
	version_string += ProjectSettings.get_setting(PROJECT_SETTING_VERSION)

	if OS.is_debug_build(): version_string += "-debug"
	version_label.text += version_string


func _set_links_label() -> void:
	var site_url: String = ProjectSettings.get_setting("urls/site")
	var github_url: String = ProjectSettings.get_setting("urls/github")
	var discord_url: String = ProjectSettings.get_setting("urls/discord")
	var support_url: String = ProjectSettings.get_setting("urls/support")
	var youtube_url: String = ProjectSettings.get_setting("urls/youtube_channel")

	var lines: PackedStringArray = [
			tr("Website") + ": " + URL.replace("URL", site_url),
			tr("GitHub repo") + ": " + URL.replace("URL", github_url),
			tr("Discord") + ": " + URL.replace("URL", discord_url),
			tr("Support GoZen") + ": " + URL.replace("URL", support_url),
			"",
			tr("Made by [color=#A718F1][url=URL]Voylin's Gamedev Journey[/url][/color]! ;)").replace("URL", youtube_url)
	]
	for line: String in lines: links_label.text += line + "\n"


func _input(event: InputEvent) -> void:
	if event.is_action_pressed("ui_cancel"): _on_close_button_pressed()


func _on_close_button_pressed() -> void:
	PopupManager.close_popup(PopupManager.POPUP.CREDITS)


func _on_links_label_meta_clicked(meta: Variant) -> void:
	Utils.open_url(str(meta))

