extends StartupModule

# TODO: Include website URL, placeholder  = WebsiteLabel
# TODO: Add icons
# TODO: Change button style, stylebox empty but color on hover + click
# TODO: Changelog button, for this we need a changelog.md file as well


func _on_image_credit_meta_clicked(meta) -> void:
	OS.shell_open(meta)




func _on_donate_button_pressed() -> void:
	OS.shell_open("https://github.com/voylin/GoZen")
