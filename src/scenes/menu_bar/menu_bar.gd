extends HBoxContainer


var callables: Dictionary[String, Callable] = {}


func _ready() -> void:
	_show_menu_bar(Settings.get_show_menu_bar())
	Utils.connect_func(Settings.on_show_menu_bar_changed, _show_menu_bar)

	build_menu_bar()


func _show_menu_bar(value: bool) -> void:
	visible = value


func build_menu_bar() -> void:
	_add_popup_menu("menu_bar_project", [
		MenuItem.new("menu_bar_project_save", Project.save, preload(Library.ICON_SAVE)),
		MenuItem.new("menu_bar_project_save_as", Project.save_as, preload(Library.ICON_SAVE)),
		MenuItem.new("menu_bar_project_open_project", Project.open_project, preload(Library.ICON_OPEN)),
		MenuItem.new("line"),
		MenuItem.new("menu_bar_project_open_settings", Project.open_settings_menu, preload(Library.ICON_EDITOR_SETTINGS)),
	])

	_add_popup_menu("menu_bar_editor", [
		MenuItem.new("menu_bar_editor_open_settings", Settings.open_settings_menu, preload(Library.ICON_PROJECT_SETTINGS)),
		MenuItem.new("line"),
		MenuItem.new("menu_bar_editor_open_url_site", Utils.open_url.bind("site"), preload(Library.ICON_LINK)),
		MenuItem.new("menu_bar_editor_open_url_manual", Utils.open_url.bind("manual"), preload(Library.ICON_MANUAL)),
		MenuItem.new("menu_bar_editor_open_url_tutorials", Utils.open_url.bind("tutorials"), preload(Library.ICON_TUTORIALS)),
		MenuItem.new("menu_bar_editor_open_url_discord", Utils.open_url.bind("discord"), preload(Library.ICON_LINK)),
		MenuItem.new("line"),
		MenuItem.new("menu_bar_editor_open_url_support", Utils.open_url.bind("support"), preload(Library.ICON_SUPPORT)),
		MenuItem.new("menu_bar_editor_open_about_gozen", _open_about_gozen, preload(Library.ICON_ABOUT_GOZEN)),
	])


func _add_popup_menu(title: String, options: Array[MenuItem]) -> void:
	var popup: PopupMenu = PopupManager.create_popup_menu(true)
	var index: int = 0

	Utils.connect_func(popup.id_pressed, _on_id_pressed.bind(popup))
	popup.name = title
	popup.add_theme_constant_override("icon_max_width", 20)

	for item: MenuItem in options:
		if item.title == "line":
			popup.add_separator()
		else:
			popup.add_item(item.title)
			popup.set_item_icon(index, item.icon)
			popup.set_item_metadata(index, item.title)
			callables[item.title] = item.callable

		index += 1

	get_child(0).add_child(popup)


func _on_id_pressed(id: int, menu: PopupMenu) -> void:
	callables[menu.get_item_metadata(id)].call()


func _open_about_gozen() -> void:
	get_tree().root.add_child(preload(Library.SCENE_ABOUT_GOZEN).instantiate())


func _on_editor_screen_button_pressed() -> void:
	InputManager.show_editor_screen()


func _on_render_screen_button_pressed() -> void:
	InputManager.show_render_screen()



class MenuItem:
	var title: String
	var callable: Callable
	var icon: CompressedTexture2D


	func _init(new_title: String, new_call: Callable = Callable(), new_icon: CompressedTexture2D = null) -> void:
		title = new_title
		callable = new_call
		icon = new_icon

