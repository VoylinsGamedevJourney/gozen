extends Tree


@export var main_file_panel: Control


var proxy_progress: Dictionary[int, int] = {}
var wave_progress: Dictionary[int, int] = {}



func _ready() -> void:
	if ProxyHandler.proxy_loading.connect(_on_proxy_loading): Print.stack_connect()
	if FileLogic.wave_loading.connect(_on_wave_loading): Print.stack_connect()


func _draw() -> void:
	var file_items: Dictionary = main_file_panel.get("file_items")

	# Display indicator of the generating of proxies.
	for file_id: int in proxy_progress.keys():
		if not file_items.has(file_id): continue
		var rect: Rect2 = get_item_area_rect(file_items[file_id] as TreeItem)
		rect.size.x = (rect.size.x / 100.0) * proxy_progress[file_id]
		draw_rect(rect, get_theme_color("proxy_loading_color", "FileTree"))

	# Display indicator for generating waves.
	for file_id: int in wave_progress.keys():
		if not file_items.has(file_id): continue
		var rect: Rect2 = get_item_area_rect(file_items[file_id] as TreeItem)
		rect.size.x = (rect.size.x / 100.0) * wave_progress[file_id]
		var wave_color: Color = get_theme_color("wave_loading_color", "FileTree") if has_theme_color("wave_loading_color", "FileTree") else Color(0.2, 0.6, 1.0, 0.5)
		draw_rect(rect, wave_color)


func _on_proxy_loading(file: FileData, progress: int) -> void:
	proxy_progress[file.id] = progress
	if progress == 100 and !proxy_progress.erase(file.id):
		printerr("FileTreeProxyProgress: Couldn't erase '%s' from proxy_progress!" % file.id)
	queue_redraw()


func _on_wave_loading(file: FileData, progress: int) -> void:
	wave_progress[file.id] = progress
	if progress == 100:
		if !wave_progress.erase(file.id): Print.stack_erase()
	queue_redraw()
