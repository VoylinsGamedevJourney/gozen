extends Control

@onready var project_tree: Tree = self.find_child("project_tree")
@onready var global_tree: Tree = self.find_child("global_tree")


func _ready():
	# Loading global folders and files
	load_folder(FileManager.get_folders(), null, global_tree, FileManager.get_files())
	
	# Connection to ProjectManager for loading project folders and files
	ProjectManager._on_project_loaded.connect(_load_project_tree)


func _load_project_tree() -> void:
	load_folder(ProjectManager.get_folders(), null, project_tree, ProjectManager.get_files())


func load_folder(data: Dictionary, parent: TreeItem, tree: Tree, files: Dictionary) -> void:
	var item := tree.create_item(parent)
	item.set_text(0, data.folder_name)
	item.set_icon(0, preload("res://assets/icons/folder_open.png"))
	item.set_icon_max_width(0, 17)
	for file: String in data.files:
		var file_item := tree.create_item(parent)
		file_item.set_text(0, files.file.nickname)
		file_item.set_icon(0, FileDefault.get_file_icon(files.file.type))
		file_item.set_icon_max_width(0, 17)
	
	for sub_folder: Dictionary in data.sub_folders:
		load_folder(sub_folder, item, tree, files)


func add_folder(tree: Tree, folder_name: String) -> void:
	
	pass
