import os
import python.toolbox as toolbox
import translations.translations as translations
import gd_extensions.build_gdextensions as gde_extensions


def build_gozen():
	l_user_input = toolbox.get_input_choice('Menu', [
		'Full build (Godot, GDExtensions, Localizations, ...)',
		'Godot build only'])
	
	# Gather build info
	l_num_jobs = toolbox.get_input_jobs()
	l_platform = toolbox.get_platform_choice()
	l_target = toolbox.get_target_choice()

	# Start building
	if l_user_input == 0:
		translations.generate_mo()
		if l_platform == 'windows':
			gde_extensions.compile_ffmpeg(l_num_jobs)

	print('Not yet to implemented!') # Building Godot application


def menu():
	match toolbox.get_input_choice('Menu', [
		'Build GoZen',
		'Localization menu',
		'GDExtension menu']):
		case 0: build_gozen()
		case 1: translations.menu()
		case 2: gde_extensions.menu()


if __name__ == '__main__':
	toolbox.print_title('GoZen builder')
	menu()
