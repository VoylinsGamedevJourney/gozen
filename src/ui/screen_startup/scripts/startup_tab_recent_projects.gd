extends MarginContainer


func _on_return_button_pressed():
	get_parent().current_tab = 0


func _on_visibility_changed():
	if visible and $VBox/ScrollContainer/RecentProjectsVBox.get_child_count() == 0:
		$VBox/ScrollContainer/RecentProjectsVBox.load_list()
