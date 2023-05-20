extends PanelContainer


var status_data := {
	ProjectManager.sig_opening_project:  "Opening project ...",
	ProjectManager.sig_opening_complete: "Opening project complete!",
	ProjectManager.sig_saving_project:   "Saving project ...",
	ProjectManager.sig_saving_complete:  "Saving project complete!",
	ProjectManager.sig_loading_project:  "Loading project ...",
	ProjectManager.sig_loading_complete: "Loading project complete!", }

@onready var project_name_label: Label = get_node("MarginContainer/ProjectName")
@onready var status_label: Label = get_node("MarginContainer/StatusLabel")


func _ready() -> void:
	project_name_label.text = "New Project"
	ProjectManager.sig_opening_complete.connect(_on_open_project)
	
	# Status signal connects
	for x in status_data:
		x.connect(_update_status.bind(status_data[x]))
	_update_status("")


func _on_open_project() -> void: 
	# Gets called whenever a (new) project 
	# opens to change the project name.
	project_name_label.text = ProjectManager.get_project_name()

func _update_status(message) -> void:
	status_label.text = message
