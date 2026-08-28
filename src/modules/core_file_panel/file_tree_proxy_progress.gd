extends Tree


@export var main_file_panel: Control


var proxy_progress: Dictionary[int, int] = {}



func _ready() -> void:
	@warning_ignore("return_value_discarded")
	ProxyHandler.proxy_loading.connect(_on_proxy_loading)


func _draw() -> void:
	# Display indicator of the generating of proxies.
	for file_id: int in proxy_progress.keys():
		var file_items: Dictionary = main_file_panel.get("file_items")
		if not file_items.has(file_id): continue

		var tree_item: TreeItem = file_items[file_id] as TreeItem
		if not tree_item: continue

		var rect: Rect2 = get_item_area_rect(tree_item)
		rect.size.x = (rect.size.x / 100.0) * proxy_progress[file_id]
		draw_rect(rect, get_theme_color("proxy_loading_color", "FileTree"))


func _on_proxy_loading(file: FileData, progress: int) -> void:
	proxy_progress[file.id] = progress
	if progress == 100 and !proxy_progress.erase(file.id):
		printerr("FileTreeProxyProgress: Couldn't erase '%s' from proxy_progress!" % file.id)
	queue_redraw()
