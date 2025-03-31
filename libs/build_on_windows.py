#!/usr/bin/env python3

import os
import sys
import subprocess
import platform as os_platform


def check_required_programs_wsl():
    print('Checking if required programs are installed for WSL ...')

    missing_programs = []
    required_programs = {
        'gcc': 'build-essential',
        'make': 'build-essential',
        'pkg-config': 'pkg-config',
        'python3': 'python3',
        'scons': 'scons',
        'mingw-w64': 'mingw-w64',
        'git': 'git',
        'yasm': 'yasm'
    }

    for program, package in required_programs.items():
        try:
            if subprocess.run(['wsl', 'which', program], capture_output=True,
                              text=True, shell=True).returncode != 0:
                missing_programs.append(package)
        except subprocess.SubprocessError as error:
            print(f'Error checking for {program}: {error}')
            missing_programs.append(package)

    return len(missing_programs) == 0, list(set(missing_programs))


def install_wsl_required_programs():
    # Attempt on installing the missing programs.
    print('Installing necessary WSL programs ...')

    try:
        subprocess.run('wsl sudo apt-get update', shell=True, check=True, cwd='./')
        subprocess.run('wsl sudo apt-get install -y build-essential pkg-config python3 scons mingw-w64 git', shell=True, cwd='./')

        print('Successfully isntalled the required WSL programs!')
    except subprocess.CalledProcessError:
        print('Error installing programs!')
        print('Please run the following commands in WSL manually:')
        print('\tsudo apt-get update')
        print('\tsudo apt-get install build-essential pkg-config python3 scons mingw-w64 git')

        input('Press Enter to exit...')
        sys.exit(1)


def main():
    if os_platform.system() != 'Windows':
        print('No windows system detected')
        sys.exit(0)

    print('Windows system detected ...\nNeed WSL to build GDE GoZen')

    # Check if WSL is installend when running from Windows,
    # else provide instructions to the user.
    wsl_found = True
    try:
        wsl_found = subprocess.run('wsl --status', capture_output=True,
                                   text=True, shell=True).returncode == 0
    except FileNotFoundError:
        wsl_found = False

    if not wsl_found:
        print('WSL (Windows Subsystem for Linux) is not installed!\nSteps to install WSL:')
        print('\t1. Open PowerShell as an Administrator;')
        print('\t2. Run the command: wsl --install')
        print('\t3. Restart your computer;')
        print('\t4. Complete the Ubuntu setup when it launches automatically after restart;')

        input('After installation, run this script again.\nPress Enter to exit...')
        sys.exit(1)

    programs_installed, missing_programs = check_required_programs_wsl()

    if not programs_installed:
        print('Some required programs are missing in WSL:')

        for program in missing_programs:
            print(f'\t- {program}')

        install_wsl_required_programs()

    try:
        # Navigate to the correct directory in WSL and run the script again.
        wsl_path = subprocess.run(['wsl', 'wslpath', os.getcwd()], capture_output=True, text=True, shell=True).stdout.strip()
        subprocess.run(['wsl', 'python3', 'build.py'], cwd=wsl_path, check=True, shell=True)

        print('Build completed successfully!')
    except subprocess.CalledProcessError as error:
        print(f'Error during build process: {error}')

        input('Press Enter to exit...')
        sys.exit(1)


if __name__ == '__main__':
    main()
