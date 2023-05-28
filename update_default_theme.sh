#!/bin/bash

source_file="main_src/default_theme.tres"
target_directory="Modules"

subdirectories=$(find "$target_directory" -maxdepth 1 -type d)

echo
for subdir in $subdirectories; do
  if [ "$subdir" != "$target_directory" ]; then  
    target_file="$subdir/default_theme.tres"
    cp "$source_file" "$target_file"
    echo "Copied $source_file to $target_file"
  fi
done
echo
echo "Copying theme completed!"
echo
