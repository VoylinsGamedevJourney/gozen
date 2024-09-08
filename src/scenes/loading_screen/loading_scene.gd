extends Control

const MIN_TIME: int = 3


@export var loading_text_label: Label
@export var version_label: Label
@export var timer: Timer


func _ready() -> void:
	var l_total_time: float = 0
	version_label.text = "Version: %s " % ProjectSettings.get_setting("application/config/version")

	for l_loadable: Loadable in GoZenServer.loadables as Array[Loadable]:
		loading_text_label.text = "%s..." % l_loadable.info_text
		loading_text_label.tooltip_text = l_loadable.info_text
		await RenderingServer.frame_pre_draw
		await l_loadable.function.call()

		if l_loadable.delay == 0:
			l_total_time += 0.1
			timer.start(0.1)
		else:
			l_total_time += l_loadable.delay
			timer.start(l_loadable.delay)

		l_total_time += timer.wait_time
		await timer.timeout
	
	loading_text_label.text = "Finalizing ..."
	loading_text_label.tooltip_text = "Finalizing"
	await RenderingServer.frame_pre_draw
	
	timer.start(MIN_TIME - l_total_time if l_total_time < MIN_TIME else 1.)
	await timer.timeout

	get_viewport().get_window().unresizable = false
	self.visible = false
	SettingsManager.change_window_mode(Window.MODE_MAXIMIZED)

	# Check for tiling window managers to disable floating
	if SettingsManager._tiling_wm:
		get_window().grab_focus()
		match SettingsManager.get_wm_name():
			"i3":
				if OS.execute("i3-msg", ["floating", "disable"]):
					printerr("Error occured when making non floating on i3!")

	GoZenServer.loadables = [] # Cleanup of memory

	if get_tree().change_scene_to_file("res://scenes/main_screen/main_scene.tscn"):
		printerr("Couldn't load main scene!")
		get_tree().quit(-2)


func _on_meta_clicked(a_meta: String) -> void:
	if OS.shell_open(a_meta):
		printerr("Error opening url! ", a_meta)

