import sys
import os
import subprocess

import gozen.build_ffmpeg as ffmpeg

sys.path.append(os.path.join(os.path.dirname(os.path.realpath(__file__)),"../python"))
import toolbox



def compile_ffmpeg(a_num_jobs = 0):
	ffmpeg.build(a_num_jobs)



def compile_gozen():
	subprocess.run(
    	f'scons -j {num_jobs} target={target} platform={platform} {scons_extra_args}',
    	shell=True, cwd='gd_extensions/gozen')


def compile_godot_cpp():
	subprocess.run(f'scons -j {num_jobs}', shell=True, cwd='gd_extensions/godot_cpp')


def menu():
	match toolbox.get_input_choices('GDExtensions menu', [
		'Build GoZen GDExtension',
		'Generate godot-cpp',
		'Generate FFmpeg']):
		case 0: compile_gozen()
		case 1: compile_godot_cpp()
		case 2: ffmpeg.build()


if __name__ == '__main__':
	toolbox.print_title('GDExtensions menu')
	menu()