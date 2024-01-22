extends PanelContainer
#"application/config/version_stable"

func _ready():
	var request := HTTPRequest.new()
	add_child(request)
	request.request_completed.connect(
		func(result: int, response_code: int, _h, body: PackedByteArray):
			if result != OK or response_code == 404:
				return # Could not get the page, no connection
			var config := ConfigFile.new()
			config.parse(body.get_string_from_utf8())
			visible = compare_versions(
				get_version(config.get_value("application/config", "version_stable", "0.0.0")),
				get_version(ProjectSettings.get_setting("application/config/version"))
			)
	)
	var error = request.request(ProjectSettings.get_setting("globals/url/stable_version"))
	if error != OK:
		Printer.error("Could not complete Version check request '%s'!" % error)


func get_version(version: String) -> PackedInt32Array:
	var data := version.split("-")[0].split(".")
	return [int(data[0]), int(data[1]), int(data[2])]


func compare_versions(repo, local) -> bool:
	for i: int in 3:
		if repo[i] > local[i]:
			return true
		elif repo[i] < local[i]:
			return false
	return false
