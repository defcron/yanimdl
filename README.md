# yanimdl

## Gets images from links contained within particularly structured .json input files

- specify the .json input files as args to the script, and it will get the images which are linked to inside those files, by using common operations of how to do so, but doing so effectively somewhat, and otherwise this isn't useful beyond its mentioned singular purpose.

Look at the contents of the two .sh scripts with the shortest filenames for full info about the what and the how of it, and why is because images are needed or wanted sometimes and so this tool achieves the getting of the images from the sources where they originate.

## Usage

```bash
# Copy or symlink these scripts into a folder that's in your $PATH (yanimdl.sh, yanimdl.dl.sh, yanimdl-lite.sh), then you can use them.

# Standard version with the fancy optimized downloader script integration, augmented by Claude. Uses the `yanimdl.dl.sh` script internally, and expects it to be in your $PATH.
yanimdl.sh input-file-with-image-links-1.json input-file-with-image-links-2.json

# Simpler, slower version, with simple download logic and probably will deliver a few more duplicate images than the standard version.
yanimdl-lite.sh input-file-with-image-links-1.json input-file-with-image-links-2.json
```

