import sys
import os
import subprocess

sys.path.append(os.path.join(os.path.dirname(os.path.realpath(__file__))))
sys.path.append(os.path.join(os.path.dirname(os.path.realpath(__file__)),"../python"))

import gozen.build_ffmpeg as ffmpeg
import toolbox


def compile_ffmpeg(a_num_jobs):
	ffmpeg.build(a_num_jobs)


def compile_gozen(a_num_jobs, a_target, a_platform):
	scons_extra_args = 'use_mingw=yes' if a_platform == 'windows' else ''
	subprocess.run(
		f'scons -j {a_num_jobs} target={a_target} platform={a_platform} {scons_extra_args}',
		shell=True, cwd='gd_extensions/gozen')


def menu():
	match toolbox.get_input_choice('GDExtensions menu', [
		'Build GoZen GDExtension',
		'Generate FFmpeg']):
		case 0: compile_gozen(
				toolbox.get_input_jobs(), 
				toolbox.get_target_choice(), 
				toolbox.get_platform_choice())
		case 1: ffmpeg.build(toolbox.get_input_jobs())


if __name__ == '__main__':
	toolbox.print_title('GDExtensions menu')
	menu()