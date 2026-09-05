extends Control

@export var tree: Tree
@export var install_button: Button
@export var close_button: Button



func _ready() -> void:
	tree.columns = 3
	tree.set_column_title(0, "Module")
	tree.set_column_title(1, "Description")
	tree.set_column_title(2, "Actions")
	tree.set_column_expand(0, false)
	tree.set_column_custom_minimum_width(0, 250)
	tree.set_column_expand(2, false)
	tree.set_column_custom_minimum_width(2, 100)
	tree.hide_root = true

	if install_button.pressed.connect(_on_install_pressed): Print.stack_connect()
	if close_button.pressed.connect(_on_close_pressed): Print.stack_connect()
	if tree.button_clicked.connect(_on_button_clicked): Print.stack_connect()
	if tree.item_edited.connect(_on_item_edited): Print.stack_connect()

	_populate_tree()


func _populate_tree() -> void:
	tree.clear()
	var root: TreeItem = tree.create_item()

	for module: GoZenModule in ModuleManager.loaded_gozen_modules:
		var item: TreeItem = tree.create_item(root)
		item.set_cell_mode(0, TreeItem.CELL_MODE_CHECK)
		item.set_checked(0, true)
		item.set_editable(0, false)
		var display_name: String = module.name if module.name != "" else module.resource_path.get_base_dir().get_file()
		item.set_text(0, display_name)
		item.set_metadata(0, module.resource_path)
		item.set_text(1, module.description)

	for filename: String in ModuleManager.loaded_modules.keys():
		var data: Dictionary = ModuleManager.loaded_modules[filename]
		var item: TreeItem = tree.create_item(root)
		item.set_cell_mode(0, TreeItem.CELL_MODE_CHECK)
		item.set_checked(0, data.get("enabled", false) as bool)
		item.set_text(0, data.get("name", filename) as String)
		item.set_editable(0, true)
		item.set_metadata(0, filename)
		item.set_text(1, data.get("description", "") as String)
		item.add_button(2, load(Library.ICON_DELETE) as Icon, 0, false, "Delete Module")


func _on_item_edited() -> void:
	var item: TreeItem = tree.get_edited()
	var filename: String = item.get_metadata(0)
	if not ModuleManager.loaded_modules.has(filename): return

	var checked: bool = item.is_checked(0)
	ModuleManager.set_module_enabled(filename, checked)
	NotificationManager.info("Module state changed. A restart might be required.")


func _on_button_clicked(item: TreeItem, column: int, id: int, _index: int) -> void:
	if column == 2 and id == 0:
		var filename: String = item.get_metadata(0)
		ModuleManager.delete_module(filename)
		_populate_tree()
		NotificationManager.info("Module deleted. A restart might be required.")


func _on_install_pressed() -> void:
	var dialog: FileDialog = PopupManager.create_file_dialog("Install Module", FileDialog.FILE_MODE_OPEN_FILE, ["*.pck, *.zip; Godot Resource Pack"])
	if dialog.file_selected.connect(_on_file_selected): print_stack()
	add_child(dialog)
	dialog.popup_centered()


func _on_file_selected(path: String) -> void:
	ModuleManager.install_module(path)
	_populate_tree()
	NotificationManager.info("Module installed. A restart might be required to apply all extensions.")


func _on_close_pressed() -> void:
	PopupManager.close(PopupManager.MODULE_MANAGER)


func _input(event: InputEvent) -> void:
	if event.is_action_pressed("ui_cancel"):
		_on_close_pressed()
		get_viewport().set_input_as_handled()
