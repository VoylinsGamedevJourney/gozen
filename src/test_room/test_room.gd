extends Control


func _ready() -> void:
	var interface: GoZenInterface = GoZenInterface.new()
	interface.get_thumb("test", "test2")
