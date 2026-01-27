extends Tree

const COLOR_PROXY_LOADING: Color = Color(0.0, 0.5, 0.5, 0.5)


@export var main_file_panel: Control

var proxy_progress: Dictionary[int, int] = {}



func _ready() -> void:
	ProxyHandler.proxy_loading.connect(_on_proxy_loading)


func _draw() -> void:
	# Display indicator of the generating of proxies.
	for file_id: int in proxy_progress.keys():
		var rect: Rect2 = get_item_area_rect(main_file_panel.file_items[file_id])

		rect.size.x = (rect.size.x / 100.0) * proxy_progress[file_id]
		print(rect)
		draw_rect(rect, COLOR_PROXY_LOADING)


func _on_proxy_loading(file_id: int, progress: int) -> void:
	proxy_progress[file_id] = progress
	if progress == 100: proxy_progress.erase(file_id)
	queue_redraw()
