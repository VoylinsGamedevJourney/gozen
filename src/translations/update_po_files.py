import subprocess
import os
from pathlib import Path


def update_po_files(po_folder, pot_file):
    po_folder = Path(po_folder)
    pot_file = Path(pot_file)

    if not pot_file.exists():
        raise FileNotFoundError(f"POT file not found: {pot_file}")

    for po_file in po_folder.glob("*.po"):
        print(f"Updating {po_file.name}...")

        cmd = [
            "msgmerge",
            "--update",
            "--verbose",
            "--backup=off",
            str(po_file),
            str(pot_file)
        ]

        result = subprocess.run(cmd, capture_output=True, text=True)

        if result.returncode != 0:
            print(f"Error updating {po_file.name}:\n{result.stderr}")
        else:
            print(f"✓ Updated {po_file.name}")


if __name__ == "__main__":
    update_po_files(
        po_folder="./",
        pot_file="localization_template.pot"
    )
