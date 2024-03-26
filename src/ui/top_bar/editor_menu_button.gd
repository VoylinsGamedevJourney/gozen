extends MenuButton


var items: Array = [
	ItemEntry.new("EDITOR_MENU_ITEM_REPORT_BUG", _report_bug_pressed, "bug"),
	ItemSeparator.new("EDITOR_MENU_SEPARATOR_LINKS"),
	ItemEntry.new("EDITOR_MENU_ITEM_MANUALS", _url_manual_pressed, "link"),
	ItemEntry.new("EDITOR_MENU_ITEM_TUTORIALS", _url_tutorials_pressed, "link"),
	ItemEntry.new("EDITOR_MENU_ITEM_DISCORD", _url_discord_pressed, "link"),
	ItemEntry.new("EDITOR_MENU_ITEM_SUPPORT_PROJECT", _url_support_project_pressed, "link")]


func _ready() -> void:
	var menu: PopupMenu = get_popup()
	var id := 0
	for item: Object in items:
		if item is ItemSeparator:
			menu.add_separator(item.label)
		else:
			menu.add_item(item.label)
			menu.set_item_icon(id, Toolbox.get_icon_tex2d(item.item_icon))
		id += 1
	menu.id_pressed.connect(_on_id_pressed)
	menu.mouse_exited.connect(_on_menu_mouse_exited)


func _on_menu_mouse_exited() -> void:
	get_popup().visible = false


func _on_id_pressed(id: int) -> void:
	if !items[id] is ItemSeparator:
		items[id].function.call()


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
	
	
	func _init(_label: String, _function: Callable, _item_icon: String) -> void:
		self.label = _label
		self.function = _function
		self.item_icon = _item_icon


class ItemSeparator:
	var label: String
	
	
	func _init(_label: String) -> void:
		self.label = _label
