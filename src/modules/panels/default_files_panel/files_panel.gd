extends Control


const ICON_MAX_WIDTH: int = 20


@export var tree: Tree


var root: TreeItem



func _ready() -> void:
	var err: int = 0
	err += Project._on_folder_added.connect(_on_folder_added)
	err += Project._on_folder_removed.connect(_on_folder_removed)
	err += Project._on_file_added.connect(_on_file_added)
	err += Project._on_file_removed.connect(_on_file_removed)
	if err:
		printerr("Errors occured connecting functions from Project to Files Panel!")

	#tree.set_drag_forwarding()

	GoZenServer.add_after_loadable(
		Loadable.new("Preparing file tree module", _initialize_file_tree))


#------------------------------------------------ TREE HANDLERS
func _initialize_file_tree() -> void:
	if tree == null:
		printerr("No file tree detected!")
		return
	elif root != null:
		printerr("File tree already initialized!")
		return
	
	root = tree.create_item()

	for l_folder: String in Project.folders:
		_add_folder(l_folder)
	for l_file: File in Project.files.values():
		_add_file(l_file)


func _find_folder_item_by_meta(l_parent: TreeItem, l_meta: String) -> TreeItem:
	var l_item: TreeItem = l_parent.get_first_child()
	while l_item:
		if l_item.get_metadata(0) is String and l_item.get_metadata(0) == l_meta:
			return l_item
		l_item = l_item.get_next()
	return null


func _find_file_item_by_meta(l_parent: TreeItem, l_meta: int) -> TreeItem:
	var l_item: TreeItem = l_parent.get_first_child()
	while l_item:
		if l_item.get_metadata(0) is int and l_item.get_metadata(0) == l_meta:
			return l_item
		l_item = l_item.get_next()
	return null


func _on_files_tree_button_clicked(item:TreeItem, column:int, id:int, mouse_button_index:int) -> void:
	# TODO: Make this work
	pass # Replace with function body.


#------------------------------------------------ FOLDER HANDLING
func _on_folder_added(a_path: String) -> void:
	_add_folder(a_path)
	#_sort_tree(root)


func _on_folder_removed(a_path: String) -> void:
	_remove_folder(a_path)


func _add_folder(a_path: String) -> void:
	var l_folder_structure: PackedStringArray = a_path.split("/")
	var l_parent_item: TreeItem = root
	var l_full_path: String = ""

	for l_folder_name: String in l_folder_structure:
		if l_folder_name == "":
			continue

		l_full_path += "/" + l_folder_name
		var l_folder_item: TreeItem = _find_folder_item_by_meta(l_parent_item, l_full_path)
		
		if l_folder_item == null:
			l_folder_item = tree.create_item(l_parent_item)
			l_folder_item.set_text(0, l_folder_name)
			l_folder_item.set_metadata(0, l_full_path)
			l_folder_item.set_tooltip_text(0, l_full_path)
			l_folder_item.set_disable_folding(false)
		l_parent_item = l_folder_item


func _remove_folder(a_path: String) -> void:
	var l_folder_item: TreeItem = _find_folder_item_by_meta(root, a_path)
	if l_folder_item:
		l_folder_item.free()
	else:
		printerr("Couldn't find folder with path %s to delete" % a_path)


#------------------------------------------------ FILE HANDLING
func _on_file_added(l_id: int) -> void:
	var l_file: File = Project.files[l_id]
	_add_file(l_file)
	#_sort_tree(root)


func _on_file_removed(l_id: int) -> void:
	_remove_file(l_id)


func _add_file(a_file: File) -> void:
	_add_folder(a_file.location)

	var l_parent_folder: TreeItem = _find_folder_item_by_meta(root, a_file.location)
	var l_file_item: TreeItem = tree.create_item(l_parent_folder)

	l_file_item.set_text(0, a_file.nickname)
	l_file_item.set_icon(0, a_file.get_thumb())
	l_file_item.set_metadata(0, a_file.id)
	l_file_item.set_tooltip_text(0, a_file.path)
	l_file_item.set_icon_max_width(0, ICON_MAX_WIDTH)
	l_file_item.set_disable_folding(true)


func _remove_file(a_id: int) -> void:
	var l_file_item: TreeItem = _find_file_item_by_meta(root, a_id)
	if l_file_item:
		l_file_item.free()
	else:
		printerr("Couldn't find file with id %s to delete" % a_id)


#------------------------------------------------ SORT

