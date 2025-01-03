class_name ViewPanel extends PanelContainer


@onready var view_texture: TextureRect = get_node("VBox/TextureRect")


func _ready() -> void:
	view_texture.texture = View.main_view.get_texture()


func _on_play_button_pressed() -> void:
	View._on_play_button_pressed()

