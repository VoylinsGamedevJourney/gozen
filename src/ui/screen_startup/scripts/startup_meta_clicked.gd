extends RichTextLabel


func _ready() -> void:
	meta_clicked.connect(_on_meta_clicked)


# Called when the node enters the scene tree for the first time.
func _on_meta_clicked(meta: Variant) -> void:
	print("test")
	OS.shell_open(meta)
