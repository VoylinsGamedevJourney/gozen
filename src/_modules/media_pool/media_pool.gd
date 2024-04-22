extends PanelContainer


@onready var tabs: Dictionary = {
	File.TYPE.VIDEO:$VBox/Scroll/TabPanel/VideosVBox,
	File.TYPE.AUDIO:$VBox/Scroll/TabPanel/AudioVBox,
	File.TYPE.IMAGE:$VBox/Scroll/TabPanel/ImagesVBox,
	File.TYPE.TEXT:$VBox/Scroll/TabPanel/TextVBox,
	File.TYPE.COLOR:$VBox/Scroll/TabPanel/ColorsVBox }



func _ready() -> void:
	# Connection signals
	Printer.connect_error(get_window().files_dropped.connect(_on_files_dropped))
	Printer.connect_error(ProjectManager._on_project_loaded.connect(_on_project_loaded))
	
	# Change to Video tab on startup
	_on_tab_bar_tab_clicked(0)


func _on_tab_bar_tab_clicked(a_tab: int) -> void:
	for l_child: Node in $VBox/Scroll/TabPanel.get_children():
		l_child.visible = a_tab == 0
		a_tab -= 1
	pass # Replace with function body.


func _on_project_loaded() -> void:
	# Clean up lists
	for l_list: VBoxContainer in $VBox/Scroll/TabPanel.get_children():
		for l_button: Button in l_list.get_children():
			l_button.queue_free()
	
	# Load in all project files
	for l_file_id: int in ProjectManager.files_data:
		_add_file_button(l_file_id)
	
	# Alphabetically sort files
	for l_child: Node in $VBox/Scroll/TabPanel.get_children():
		_sort_files(l_child)


func _sort_files(a_parent: VBoxContainer) -> void:
	var l_children: Array = a_parent.get_children()
	
	l_children.sort_custom(func(l_1: Button, l_2: Button) -> bool: return l_1.text < l_2.text)
	for l_child: Node in l_children:
		a_parent.remove_child(l_child)
		a_parent.add_child(l_child)


func _add_file_button(a_file_id: int) -> void:
	var l_button: Button = Button.new()
	l_button.set_meta("file_id", a_file_id)
	l_button.set_text(ProjectManager.files_data[a_file_id].nickname)
	l_button.alignment = HORIZONTAL_ALIGNMENT_LEFT
	tabs[ProjectManager.files_data[a_file_id].type].add_child(l_button)


func _on_files_dropped(a_files: PackedStringArray) -> void:
	if ProjectManager.project_path == "":
		return # No project loaded
	for l_file_path: String in a_files:
		var l_file_id: int = ProjectManager.add_file_actual(l_file_path)
		print(l_file_id)
		if l_file_id > 0:
			_add_file_button(l_file_id)
	for l_child: Node in $VBox/Scroll/TabPanel.get_children():
		_sort_files(l_child)


func _on_tab_bar_gui_input(a_event: InputEvent):
	if a_event is InputEventMouseButton:
		if a_event.button_index == 4 and a_event.pressed: # Scroll down
			$VBox/TabBar.current_tab -= 1
		if a_event.button_index == 5 and a_event.pressed: # Scroll up
			$VBox/TabBar.current_tab += 1





#func _ready():
#	# Creating the Tree root
#	var root: TreeItem = tree.create_item()
#	root.set_text(0, "root")
#	var item1: TreeItem = tree.create_item(root)
#	var item2: TreeItem = tree.create_item(root)
#	var item3: TreeItem = tree.create_item(root)
#	item1.set_text(0, "Test4")
#	item2.set_text(0, "Test2")
#	item3.set_text(0, "Test1")
#	item3.sort2
#	
#	Printer.connect_error(ProjectManager._on_project_loaded.connect(_load_tree))
#
#
#func _load_tree() -> void:
#	for folder: String in ProjectManager.folder_data:
#		pass
#
#
#func _create_folder(a_path: String) -> void:
#	# Creating the root item
#	var l_parent_path: String = a_path.trim_suffix(a_path.split("/")[-1])
#	var l_item: TreeItem = tree.create_item(folder_items[l_parent_path])
#	l_item.set_text(0, a_path.split("/")[-1])
#	l_item.set_icon(0, ICON_FOLDER)
#	l_item.set_icon_max_width(0, ICON_MAX_WIDTH)
#	folder_items[a_path] = l_item
#	# TODO: Alphabetically sort items
#
#
#func _create_file(a_text: String, a_parent: TreeItem) -> void:
#	# Creating the root item
#	var l_item: TreeItem = tree.create_item(a_parent)
#	l_item.set_text(0, a_text)
#	# TODO: Set icon correctly
#	l_item.set_icon(0, ICON_FOLDER)
#	l_item.set_icon_max_width(0, ICON_MAX_WIDTH)
#	# TODO: Alphabetically sort items
#
#
#func create_folder(a_parent: String) -> void:
#	# Create folder in tree with default name
#	#_create_folder()
#	# add folder to ProjectManager folder data
#	pass 
#
#
#func _sort(l_1: Control, l_2: Control) -> bool:  
#	return l_1.get_node("HBox/FolderLabel").text < l_2.get_node("HBox/FolderLabel").text
#
