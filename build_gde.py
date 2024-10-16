import subprocess
import os

print('Getting latest version of GDE GoZen repo')
os.chdir('gde_gozen')
subprocess.run(["git", "pull"], check=True)

print('Building GDExtension')
subprocess.run(['python', 'build.py'], check=True)
