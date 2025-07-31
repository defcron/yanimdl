# yanimdl

## Gets images from links contained within particularly structured .json input files

- specify the .json input files as args to the script, and it will get the images which are linked to inside those files, by using common operations of how to do so, but doing so effectively somewhat, and otherwise this isn't useful beyond its mentioned singular purpose.

Look at the contents of the two .sh scripts with the shortest filenames for full info about the what and the how of it, and why is because images are needed or wanted sometimes and so this tool achieves the getting of the images from the sources where they originate.

## Usage

```bash
# Copy or symlink these scripts into a folder that's in your $PATH (yanimdl.sh, yanimdl.dl.sh, yanimdl-lite.sh), then you can use them.

# Get images from links in the certain kind of .json input files. Uses the `yanimdl.dl.sh` script internally, and expects it to be in the current directory or in your $PATH. Consider putting both `yanimdl.sh` and `yanimdl.dl.sh` in a location that's in your $PATH for ease of use.
yanimdl.sh input-file-with-image-links-1.json input-file-with-image-links-2.json
```

