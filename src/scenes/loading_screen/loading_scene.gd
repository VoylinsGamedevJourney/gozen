extends Control


@export var loading_text_label: Label
@export var version_label: Label
@export var timer: Timer


func _ready() -> void:
	version_label.text = "Version: %s " % ProjectSettings.get_setting("application/config/version")

	for l_loadable: Loadable in GozenServer.loadables:
		loading_text_label.text = ": %s..." % l_loadable.info_text
		loading_text_label.tooltip_text = l_loadable.info_text
		await l_loadable.function.call()
		timer.wait_time = l_loadable.delay
		timer.start()
		await timer.timeout

	get_viewport().get_window().unresizable = false
	self.visible = false
	DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_MAXIMIZED)

	# Check for tiling window managers
	if OS.get_name() == "Linux":
		var l_reply: Array = []
		print(OS.execute("echo", ["$XDG_CURRENT_DESKTOP"], l_reply))
		var l_wm: String = l_reply[0]
		match l_wm.trim_suffix("\n"):
			"i3":
				if OS.execute("i3-msg", ["floating", "disable"]):
					printerr("Error occured when making non floating on i3!")
			_: print("Not a tiling window manager")

	# TODO: on end load main UI


func _on_meta_clicked(a_meta: String) -> void:
	if OS.shell_open(a_meta):
		printerr("Error opening url! ", a_meta)

