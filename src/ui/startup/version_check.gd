extends PanelContainer
## Version Check
##
## Runs on the startup screen to check if the user needs to be
## notified of a new GoZen version which is available to download.


func _ready() -> void:
	## Creating an http request, connects and sends it. 
	var l_request := HTTPRequest.new()
	add_child(l_request)
	l_request.request_completed.connect(_request_completed)
	var l_error = l_request.request(Globals.URL_VERSION_STABLE)
	if l_error != OK:
		Printer.error(Globals.ERROR_VERSION_CHECK_REQUEST % l_error)


func _request_completed(a_result: int, a_response_code: int, _h, a_body: PackedByteArray) -> bool:
	## When a request has been completed, this will be checked if we could find the
	## config file, if yes, we load it in and we compare to the local config file.
	if a_result != OK or a_response_code == 404:
		return false # Could not get the page, possibly no connection?
	var l_config := ConfigFile.new()
	l_config.parse(a_body.get_string_from_utf8())
	# Getting version strings
	var l_stable_version: String = l_config.get_value("application/config", "version_stable", "0.0.0")
	var l_local_version: String = ProjectSettings.get_setting("application/config/version")
	# Version checking
	var l_version_remote: PackedInt32Array = get_version(l_stable_version)
	var l_version_local: PackedInt32Array = get_version(l_local_version)
	for i: int in 3:
		if l_version_remote[i] > l_version_local[i]:
			Printer.debug("New version is available!\n\tVersion: %s" % l_stable_version)
			return true
		elif l_version_remote[i] < l_version_local[i]:
			return false
	return false


func get_version(a_version: String) -> PackedInt32Array:
	## Version number has 3 values, but it could have a string attached to it in
	## case of alpha, beta, or dev. We need an Int array, so we should avoid
	## loading the last numbers as this is not necesarry.
	var l_data := a_version.split("-")[0].split(".")
	return [int(l_data[0]), int(l_data[1]), int(l_data[2])]
