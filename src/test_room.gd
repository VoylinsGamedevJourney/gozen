extends Control


#func _ready() -> void:
#	await RenderingServer.frame_post_draw
#	$SubViewportContainer/SubViewport.get_texture().get_image().save_png("user://Screenshot.png")


var viewport_initial_size = Vector2(1920, 1080)
@onready var viewport = $SubViewportContainer/SubViewport
@onready var viewport_container = $SubViewportContainer

func _ready():
	viewport.size_changed.connect(_root_viewport_size_changed)
	viewport.size = viewport_initial_size

func _root_viewport_size_changed():
	print("size changed")
	viewport.size = Vector2.ONE * get_viewport().size.y
	viewport_container.scale = Vector2(1, -1) * viewport_initial_size.y / get_viewport().size.y

func _input(event: InputEvent) -> void:
	if event.is_action_released("ui_page_up"):
		await RenderingServer.frame_post_draw
		viewport.get_texture().get_image().save_png("user://Screenshot.png")

