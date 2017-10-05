#! /bin/bash

### CONFIG ###

api_url="https://api.tinify.com/shrink"

### COLORS ###

RED='\033[0;31m'
GREEN='\033[0;32m'
NORMAL='\033[0m'

### SCRIPT ###

function get_args {
    while [[ $# -gt 0 ]]
    do
        arg=$1
        case $arg in
            -p|--path)
                path=$2
                shift
                shift
            ;;
            -k|--api-key)
                api_key=$2
                shift
                shift
            ;;
            -b|--backup-path)
                backup_path=$2
                shift
                shift
            ;;
            -h|--help)
                echo "Usage: tinypicomatic [OPTION]
Use the tinyPNG API to reduce the weight of pictures in a directory.
Example: tinypicomatic -k \"YOUR-API-KEY\" -p ./

Options:
    -k, --api-key       Your API key for tinyPNG
    -p, --path          Path of the directory where to convert images
    -b, --backup-path   If specified, images will be copied there before any change is done
    -h, --help          Display this help and exit
  
tinypicomatic will search for all .png, .jpg and .jpeg file in the given path recursively.
If no path is specified the default one is the current directory."
                exit
            ;;
            *)
                echo "Error: Unknow option \"$1\""
                exit 1
            ;;
        esac
    done
}

function check_args {
    if [ -z $api_key ]
    then
        echo "Error: You have to specify an api key"
        exit 1
    fi

    if [ -z $path ]
    then
        path="."
    else
        if [ ! -d $path ]
        then
            echo "Error: Specified path directory does not exist"
            exit 1
        fi
        path=${path%/}
        if [[ ${path:0:2} == "./" ]]
        then
            path=${path:2}
        fi
    fi

    if [ ! -z $backup_path ]
    then
        backup_path=${backup_path%/}
        if [[ ${backup_path:0:2} == "./" ]]
        then
            backup_path=${backup_path:2}
        fi
    fi
}

function get_files {
    if [ -z $backup_path ]
    then
        files=($(find $path -name "*.png" -o -name "*.jpg" -o -name "*.jpeg"))
    else
        files=($(find $path -name "*.png" -not -path "$backup_path/*" \
            -o -name "*.jpg" -not -path "$backup_path/*" \
            -o -name "*.jpeg" -not -path "$backup_path/*"))
    fi
}

function create_backup_dir {
    if [ ! -d $backup_path ] && [ ! -z $backup_path ]
    then
        mkdir $backup_path
    fi
}

function check_file {
    file_type=$(file $1 | cut -d" " -f 2)

    if [ $file_type != "PNG" ] && [ $file_type != "JPEG" ]
    then
        echo -e "[${RED}KO${NORMAL}] Check \"$1\" is a valid file"
        return 1
    else
        echo -e "[${GREEN}OK${NORMAL}] Check \"$1\" is a valid file"
    fi
}

function backup_file {
    if [ -z $backup_path ]
    then
        return
    fi
    file_name=$(basename $file)

    cp "$file" "$backup_path/$file_name" 2> /dev/null

    if [ $? != 0 ]
    then
        echo -e "[${RED}KO${NORMAL}] Backup \"$file\" in \"$backup_path/$file_name\""
        return 1
    else
        echo -e "[${GREEN}OK${NORMAL}] Backup \"$file\" in \"$backup_path/$file_name\""
    fi
}

function upload_file {
    location=$(curl -s $api_url \
        --user api:$api_key \
        --data-binary @$file \
        --dump-header /dev/stdout 2> /dev/null \
        | grep "location" | cut -d" " -f 2 | tr -dc "[:print:]")

    if [ -z $location ]
    then
        echo -e "[${RED}KO${NORMAL}] Upload \"$file\" to \"$api_url\""
        return 1
    else
        echo -e "[${GREEN}OK${NORMAL}] Upload \"$file\" to \"$api_url\""
    fi
}

function download_file {
    file_name=$(basename $file)
    
    curl -s $location \
        --user api:$api_key \
        --output $file

    if [ $? != 0 ]
    then
        echo -e "[${RED}KO${NORMAL}] Download \"$file\" from \"$location\""
        if [ ! -z $backup_path ]
        then
            mv "$backup_path/$file_name" $file
        fi
        return 1
    else
        echo -e "[${GREEN}OK${NORMAL}] Download \"$file\" from \"$location\""
    fi
}

function verify_file {
    file_name=$(basename $file)
    file_type=$(file $file | cut -d" " -f 2)

    if [ $file_type != "PNG" ] && [ $file_type != "JPEG" ]
    then
        echo -e "[${RED}KO${NORMAL}] Verify \"$file\" downloaded is a valid file"
        if [ ! -z $backup_path ]
        then
            mv "$backup_path/$file_name" $file
        fi
        return 1
    else
        echo -e "[${GREEN}OK${NORMAL}] Verify \"$file\" downloaded is a valid file"
    fi
}

function process_file {
    status=0

    if ! check_file $1; then status=1; fi
    if [ $status = 0 ] && ! backup_file $1; then status=1; fi
    if [ $status = 0 ] && ! upload_file $1; then status=1; fi
    if [ $status = 0 ] && ! download_file $1; then status=1; fi
    if [ $status = 0 ] && ! verify_file $1; then status=1; fi
}

function loop_files {
    for file in ${files[@]}
    do
        process_file $file &
    done
    
    wait
}

function main {
    get_args $@
    check_args
    get_files
    create_backup_dir
    loop_files
}

main $@