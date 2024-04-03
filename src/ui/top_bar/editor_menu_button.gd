extends MenuButton


var items: Array = [
	ItemEntry.new("EDITOR_MENU_ITEM_REPORT_BUG", _report_bug_pressed, "bug"),
	ItemSeparator.new("EDITOR_MENU_SEPARATOR_LINKS"),
	ItemEntry.new("EDITOR_MENU_ITEM_MANUALS", _url_manual_pressed, "link"),
	ItemEntry.new("EDITOR_MENU_ITEM_TUTORIALS", _url_tutorials_pressed, "link"),
	ItemEntry.new("EDITOR_MENU_ITEM_DISCORD", _url_discord_pressed, "link"),
	ItemEntry.new("EDITOR_MENU_ITEM_SUPPORT_PROJECT", _url_support_project_pressed, "link")]


func _ready() -> void:
	var l_menu: PopupMenu = get_popup()
	var l_id: int = 0
	
	for l_item: Object in items:
		if l_item is ItemSeparator:
			l_menu.add_separator(l_item.label)
		else:
			l_menu.add_item(l_item.label)
			l_menu.set_item_icon(l_id, Toolbox.get_icon_tex2d(l_item.item_icon))
		l_id += 1
		
	l_menu.id_pressed.connect(_on_id_pressed)
	l_menu.mouse_exited.connect(_on_menu_mouse_exited)


func _on_menu_mouse_exited() -> void:
	get_popup().visible = false


func _on_id_pressed(a_id: int) -> void:
	if !items[a_id] is ItemSeparator:
		items[a_id].function.call()


func _report_bug_pressed() -> void:
	PopupManager.open_popup(PopupManager.POPUP.BUG_REPORT)


func _url_manual_pressed() -> void:
	OS.shell_open(Globals.URL_MANUAL)


func _url_tutorials_pressed() -> void:
	OS.shell_open(Globals.URL_TUTORIALS)


func _url_github_pressed() -> void:
	OS.shell_open(Globals.URL_GITHUB_REPO)


func _url_discord_pressed() -> void:
	OS.shell_open(Globals.URL_DISCORD)


func _url_support_project_pressed() -> void:
	OS.shell_open(Globals.URL_SUPPORT_PROJECT)


class ItemEntry:
	var label: String
	var function: Callable
	var item_icon: String
	
	func _init(a_label: String, a_function: Callable, a_item_icon: String) -> void:
		self.label = a_label
		self.function = a_function
		self.item_icon = a_item_icon


class ItemSeparator:
	var label: String
	
	func _init(a_label: String) -> void:
		self.label = a_label
