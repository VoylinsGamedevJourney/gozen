- Pasting an image should send the data to file logic which creates the "images" directory to put the file into;
- Opening older projects with a temp_file should check for image data and run the file logic function whilst discarding the info so it no longer lives in the `*.gozen` file;
- Upon saving a temporary project (quick-create) we check if we have any files with a cache path so we can create the "images" folder for those and move those files whilst changing the paths in the data;


- Check if for Colors we can't just create a shader which creates the dimensions and such for the color instead of creating an actual image;
- Check if we actually still need temp data or if we can just set the path to `#color_code` for colors and `text` for text files or something similar;

