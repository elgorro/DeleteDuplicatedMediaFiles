#!/bin/bash

files_dir="$1"
if [[ -z '$files_dir' ]]; then
    echo "Error: files dir is undefined"
    exit;
fi

#generate md5 hashes
md5array=()
while read folder;
do
    echo "$folder"
    count=0
    while read file
    do
        filename=$(basename "$file")
        echo ">>> $filename"
        md5=$(ffmpeg -loglevel quiet -v quiet -err_detect ignore_err -i "$file" -f md5 - < /dev/null )
        #printf "\e[91m%s:%s\n" "$md5" "$file"
        md5array+=( "$md5:$file")
        let "count++"
    done < <(find "$folder" -type f)
    printf "Analized $count Songs in $folder\n\n"
done < <(find $files_dir -type d -links 2)

printf "\n%s\n" "Found ${#md5array[@]} Songs\n"
#printf "%s\n" "${md5array[@]}"

#sort by md5
readarray -t sortedmd5 < <(for e in "${md5array[@]}"; do echo "$e"; done | sort)
#printf "%s\n" "${sortedmd5[@]}"

#split into md5 and fullpath
md5=()
fullpath=()
IFS=''
for song in "${sortedmd5[@]}"
do
    md5+=($( echo "$song" | cut -f1 -d":" ))
    fullpath+=($( echo "$song" | cut -f2 -d":" ))
    
done
#printf "%s\n" "${md5[@]}"
#printf "%s\n" "${fullpath[@]}"

#detect dupes
countdupes=0
dupes=()
for ((idx=0; idx<${#md5[@]}-1; ++idx)); do
    if [[ ${md5[$idx]} = ${md5[$idx+1]} ]]
    then
        let "countdupes++"
        dupes+=( "${fullpath[$idx]}" )
        echo "${idx}" "${md5[idx]}" "${fullpath[$idx]}"
    fi
done
printf "Found %s duplicates\n" "$countdupes"
#printf "%s\n" "${dupes[@]}"

for f in "${dupes[@]}"
do
    echo "rm $f" #remove echo to delete
done
printf "Deleted %s files in %s" "${#dupes[@]}" "$files_dir"
echo
