extends Window

const URL_FORM := "https://forms.gle/fwCfAXTQ4HrkZ1J77"
const URL_REQUEST := "https://docs.google.com/forms/u/0/d/e/1FAIpQLSc05KlF6MVlT_-ImbU07XywOXWDWBMhbbJZ-8gNMTcXSoSKAQ/formResponse"
const PACKET_HEADER := [
	"Content-Type: application/x-www-form-urlencoded"
]
const ID_VERSION := 1893125384
const ID_CONTACT := 529782953
const ID_DESC := 1630285445


func _on_about_to_popup() -> void:
	%ContactLineEdit.text = ""
	%DescTextEdit.text = ""


func _on_cancel_button_pressed() -> void:
	PopupManager.close_popup(PopupManager.POPUP.BUG_REPORT)


func _on_submit_button_pressed() -> void:
	if %DescTextEdit.text == "":
		_on_cancel_button_pressed()
	var request := HTTPRequest.new()
	add_child(request)
	request.request(
		URL_REQUEST, 
		PACKET_HEADER,
		HTTPClient.METHOD_POST,
		"entry.{id_version}={version}&entry.{id_contact}={contact}&entry.{id_desc}={desc}".format({
			id_version = ID_VERSION,
			id_contact = ID_CONTACT,
			id_desc = ID_DESC,
			version = ProjectSettings.get_setting("application/config/version"),
			contact = %ContactLineEdit.text,
			desc = %DescTextEdit.text
		}))
	request.request_completed.connect(_request_completed.bind(request))
	PopupManager.close_popup(PopupManager.POPUP.BUG_REPORT)


func _request_completed(_r: int, _rc: int, _h: PackedStringArray, body: PackedByteArray, request: HTTPRequest) -> void:
	print(body.get_string_from_utf8())
	remove_child(request)
