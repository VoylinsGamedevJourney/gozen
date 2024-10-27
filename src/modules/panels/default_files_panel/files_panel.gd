extends Control


# TODO: Add tabs to left
# TODO: Add extra button for adding files + tab for opening to add, or creating to add


const ICON_MAX_WIDTH: int = 20

@export var tab_container: TabContainer

@export var folder_pck: HFlowContainer
@export var folder_text: HFlowContainer
@export var folder_color: HFlowContainer
@export var folder_image: HFlowContainer
@export var folder_audio: HFlowContainer
@export var folder_video: HFlowContainer



func _ready() -> void:
	CoreLoader.append_after("Preparing file panel", _initialize_file_tree)

	CoreError.err_connect([
			CoreMedia._on_file_added.connect(_on_file_added),
			CoreMedia._on_file_removed.connect(_on_file_removed),
			SettingsManager._on_icon_pack_changed.connect(_update_icons)])


#------------------------------------------------ TREE HANDLERS
func _initialize_file_tree() -> void:
	_update_icons()

	for l_file: File in Project.files.values():
		_add_file(l_file)


func _update_icons() -> void:
	var l_tab_bar: TabBar = tab_container.get_tab_bar()
	var l_tab_data: Array[PackedStringArray] = [
		["PCK", "pck"],
		["Text", "text"],
		["Color", "color"],
		["Image", "image"],
		["Audio", "audio"],
		["Video", "video"],
	]

	for i: int in l_tab_data.size():
		l_tab_bar.set_tab_title(i, "")
		l_tab_bar.set_tab_icon_max_width(i, 22)
		l_tab_bar.set_tab_tooltip(i, "%s files" % l_tab_data[i][0])
		l_tab_bar.set_tab_icon(i, SettingsManager.get_icon("%s_file" % l_tab_data[i][1]))


func _sort_tree(a_type: int) -> void:
	var l_folder: HFlowContainer = _get_folder_from_type(a_type)
	var l_nodes: Dictionary = {}

	for l_child: Button in l_folder.get_children():
		l_nodes[Project.files[l_child.name.to_int()].nickname] = l_child
	
	var l_pos: int = 0
	var l_keys: PackedStringArray = l_nodes.keys()

	l_keys.sort()

	for l_node_name: String in l_nodes.keys():
		var l_button: Button = l_nodes[l_node_name]

		l_folder.move_child(l_button, l_pos)
		l_pos += 1


func _get_folder_from_type(a_type: int) -> HFlowContainer:
	match a_type:
		File.PCK: return folder_pck
		File.TEXT: return folder_text
		File.COLOR: return folder_color
		File.IMAGE: return folder_image
		File.AUDIO: return folder_audio
		File.VIDEO: return folder_video
		_:
			printerr("Invalid type!")
			return null


#------------------------------------------------ FILE HANDLING
func _on_file_added(l_id: int) -> void:
	var l_file: File = Project.files[l_id]

	_add_file(l_file)
	_sort_tree(l_file.type)


func _on_file_removed(l_id: int) -> void:
	_remove_file(l_id)


func _add_file(a_file: File) -> void:
	var l_file_box: Button = preload("res://modules/panels/default_files_panel/files_box/files_box.tscn").instantiate()
	l_file_box.name = str(a_file.id)
	l_file_box.text = a_file.nickname
	l_file_box.icon = a_file.get_thumb()
	l_file_box.tooltip_text = a_file.nickname + '/n' + a_file.path

	_get_folder_from_type(a_file.type).add_child(l_file_box)
	tab_container.current_tab = _get_folder_from_type(a_file.type).get_parent().get_index()

	_sort_tree(a_file.type)


func _remove_file(a_id: int) -> void:
	if Project.files.has(a_id):
		CoreMedia.remove_file(a_id)
		return

	var l_file: File = Project.files[a_id]

	_get_folder_from_type(l_file.type).get_node(l_file.nickname).queue_free()

