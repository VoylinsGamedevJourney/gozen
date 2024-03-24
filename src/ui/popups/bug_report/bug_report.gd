extends Window

const url_form := "https://forms.gle/fwCfAXTQ4HrkZ1J77"
const url_request := "https://docs.google.com/forms/u/0/d/e/1FAIpQLSc05KlF6MVlT_-ImbU07XywOXWDWBMhbbJZ-8gNMTcXSoSKAQ/formResponse"
const packet_header := [
	"Content-Type: application/x-www-form-urlencoded"
]
const id_version := 1893125384
const id_contact := 529782953
const id_desc := 1630285445

func _ready() -> void:
	print("entry.{id_version}={version}&entry.{id_contact}={contact}&entry.{id_desc}={desc}".format({
			"id_version": id_version,
			"id_contact": id_contact,
			"id_desc": id_desc,
			"version": ProjectSettings.get_setting("application/config/version"),
			"contact": %ContactLineEdit.text,
			"desc": %DescTextEdit.text
		}))


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
		url_request, 
		packet_header,
		HTTPClient.METHOD_POST,
		"entry.{id_version}:{version}&entry.{id_contact}:{contact}&entry.{id_desc}:{desc}".format({
			"id_version": id_version,
			"id_contact": id_contact,
			"id_desc": id_desc,
			"version": ProjectSettings.get_setting("application/config/version"),
			"contact": %ContactLineEdit.text,
			"desc": %DescTextEdit.text
		}))
	request.request_completed.connect(_request_completed.bind(request))
	PopupManager.close_popup(PopupManager.POPUP.BUG_REPORT)


func _request_completed(_r: int, _rc: int, _h: PackedStringArray, body: PackedByteArray, request: HTTPRequest) -> void:
	print(body.get_string_from_utf8())
	remove_child(request)
