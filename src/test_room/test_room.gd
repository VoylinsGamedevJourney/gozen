extends Control


func _ready() -> void:
	var interface: GoZenInterface = GoZenInterface.new()
	interface.get_thumb("/home/voylin/Documents/Programming/GoZen/src/test_room/test.mp4", "/home/voylin/Documents/Programming/GoZen/src/test_room/test.png")
