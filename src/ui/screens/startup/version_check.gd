extends PanelContainer
## Version Check
##
## Runs on the startup screen to check if the user needs to be
## notified of a new GoZen version which is available to download.


func _ready() -> void:
	## Creating an http request, connects and sends it. 
	var request := HTTPRequest.new()
	add_child(request)
	request.request_completed.connect(_request_completed)
	var error = request.request(Globals.URL_VERSION_STABLE)
	if error != OK:
		Printer.error("Could not complete Version check request '%s'!" % error)


func _request_completed(result: int, response_code: int, _h, body: PackedByteArray) -> bool:
	## When a request has been completed, this will be checked if we could find the
	## config file, if yes, we load it in and we compare to the local config file.
	if result != OK or response_code == 404:
		return false # Could not get the page, possibly no connection?
	var config := ConfigFile.new()
	config.parse(body.get_string_from_utf8())
	# Getting version strings
	var stable_version: String = config.get_value("application/config", "version_stable", "0.0.0")
	var local_version: String = ProjectSettings.get_setting("application/config/version")
	# Version checking
	var v_remote: PackedInt32Array = get_version(stable_version)
	var v_local: PackedInt32Array = get_version(local_version)
	for i: int in 3:
		if v_remote[i] > v_local[i]:
			Printer.debug("New version is available!\n\tVersion: %s" % stable_version)
			return true
		elif v_remote[i] < v_local[i]:
			return false
	return false


func get_version(version: String) -> PackedInt32Array:
	## Version number has 3 values, but it could have a string attached to it in
	## case of alpha, beta, or dev. We need an Int array, so we should avoid
	## loading the last numbers as this is not necesarry.
	var data := version.split("-")[0].split(".")
	return [int(data[0]), int(data[1]), int(data[2])]
