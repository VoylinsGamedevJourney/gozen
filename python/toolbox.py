import readline
import os



def print_title(a_title):
	print(f'--== {a_title} ==--')


def get_input_choice(a_title, a_choices):
	print(f'-= {a_title} =-')
	for i, choice in enumerate(a_choices, start=1):
		print(f'{i}. {choice};')
	
	user_input = ''
	while True:
		user_input = input('> ')
		if user_input.isdigit() and int(user_input) <= len(a_choices):
			break
		print('Please enter a valid number!')
	print()
	return int(user_input) - 1

