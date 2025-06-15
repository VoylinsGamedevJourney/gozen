extends HBoxContainer


var callables: Dictionary[String, Callable] = {}


func _ready() -> void:
	_show_menu_bar(Settings.get_show_menu_bar())
	Toolbox.connect_func(Settings.on_show_menu_bar_changed, _show_menu_bar)

	build_menu_bar()


func _show_menu_bar(value: bool) -> void:
	visible = value


func build_menu_bar() -> void:
	_add_popup_menu("menu_bar_project", [
		MenuItem.new("menu_bar_project_save", Project.save, preload("uid://crolsp3m3n14")),
		MenuItem.new("menu_bar_project_save_as", Project.save_as, preload("uid://crolsp3m3n14")),
		MenuItem.new("menu_bar_project_open_project", Project.open_project, preload("uid://8yvgi81apxxg")),
		MenuItem.new("line"),
		MenuItem.new("menu_bar_project_open_settings", Project.open_settings_menu, preload("uid://dpsmt1do2u4xl")),
	])

	_add_popup_menu("menu_bar_editor", [
		MenuItem.new("menu_bar_editor_open_settings", Settings.open_settings_menu, preload("uid://c35rwqbeqmush")),
		MenuItem.new("line"),
		MenuItem.new("menu_bar_editor_open_url_site", Toolbox.open_url_site, preload("uid://npglkea55x8p")),
		MenuItem.new("menu_bar_editor_open_url_manual", Toolbox.open_url_manual, preload("uid://c8ydairucfdee")),
		MenuItem.new("menu_bar_editor_open_url_tutorials", Toolbox.open_url_tutorials, preload("uid://bbuw3ew0x2ghk")),
		MenuItem.new("menu_bar_editor_open_url_discord", Toolbox.open_url_discord, preload("uid://npglkea55x8p")),
		MenuItem.new("line"),
		MenuItem.new("menu_bar_editor_open_url_support", Toolbox.open_url_support, preload("uid://qin4ceo74nw6")),
		MenuItem.new("menu_bar_editor_open_about_gozen", _open_about_gozen, preload("uid://rfesonobkxh1")),
	])


func _add_popup_menu(title: String, options: Array[MenuItem]) -> void:
	var popup_menu: PopupMenu = PopupMenu.new()

	Toolbox.connect_func(popup_menu.id_pressed, _on_id_pressed.bind(popup_menu))
	popup_menu.name = title
	popup_menu.add_theme_constant_override("icon_max_width", 20)


	var index: int = 0
	for item: MenuItem in options:
		if item.title == "line":
			popup_menu.add_separator()
		else:
			popup_menu.add_item(tr(item.title))
			popup_menu.set_item_icon(index, item.icon)
			popup_menu.set_item_metadata(index, item.title)
			callables[item.title] = item.callable

		index += 1

	get_child(0).add_child(popup_menu)


func _on_id_pressed(id: int, menu: PopupMenu) -> void:
	callables[menu.get_item_metadata(id)].call()


func _open_about_gozen() -> void:
	add_child(preload("uid://d4e5ndtm65ok3").instantiate())


class MenuItem:
	var title: String
	var callable: Callable
	var icon: CompressedTexture2D


	func _init(new_title: String, new_call: Callable = Callable(), new_icon: CompressedTexture2D = null) -> void:
		title = new_title
		callable = new_call
		icon = new_icon

