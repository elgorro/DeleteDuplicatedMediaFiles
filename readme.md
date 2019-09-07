# Delete Duplicated Media Files

Delete duplicated media files by MD5-Checksum with FFMPEG-Codec on Linux.

## Description
Normal duplicate finders check the whole file with checksums - so there is a small chance if the ID-Tag or filename is diffrent that a dupe will not identified.

With [FFMPEG MD5 Hashes](https://ffmpeg.org/ffmpeg-all.html#md5-1) you can get the MD5 of the media-contnent only.
`md5=$(ffmpeg -loglevel quiet -v quiet -err_detect ignore_err -i "$file" -f md5 - < /dev/null )`

Note: this will take some time, because it renders all the detected media files.
Currently this is because `find "$folder" -type f` will all pass all files from folders with no subfolders `find $files_dir -type d -links 2` to the pipe recursivly. (Feel free to change these to your benefits!) 

This is only tested with music (MP3, FLAC, etc.) but should also work with movies (.AVI, .MP4, etc.) see all supported [FFMPEG codecs here](https://www.ffmpeg.org/ffmpeg-codecs.html).

Because it is rendering all media files (to `null`) to get the hashes, it could take a long time or crash your system. Feel free to analize less files at one time.

## Use
./delete-media-duplicates.sh /path/to/media/

If you have ":" in your filenames it probably will not work, then change `cut -f1 -d":"` and `cut -f2 -d":"` to something you dont have in filenames.

For security reasons for now i implemented a `echo "rm $f"`, which will only output all dupes!

## Know Issues
- Whitespaces in script param crash the execution - be aware, this can perhaps delete unwanted dupes!!
