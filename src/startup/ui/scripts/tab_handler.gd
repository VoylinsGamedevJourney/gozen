extends TabContainer
## Tab Handler
##
## The under panel of the startup menu consists out of different tabs/panels.
## This script has the logic to handle these.


func _ready() -> void:
	current_tab = 0 # Setting main tab active on launch


###############################################################
#region Button logic  #########################################
###############################################################

func _on_show_all_projects_button_pressed() -> void:
	%TabContainer.current_tab = 1


func _on_all_projects_return_button_pressed() -> void:
	%TabContainer.current_tab = 0

#endregion
###############################################################
