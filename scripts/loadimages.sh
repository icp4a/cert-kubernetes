#!/bin/bash

echo -e "\033[1;31mImportant! Please ensure that you had login to the target Docker registry in advance. \033[0m"
echo -e "\033[1;31mImportant! The load image sample script is for x86_64, amd64, or i386 platforms only.\n \033[0m"

ARCH=$(arch)
case ${ARCH} in
    amd64|x86_64|i386)
        echo "Supported arch: ${ARCH}"
    ;;
    *)
        echo "Unsupported arch: ${ARCH}"
        exit -1
    ;;
esac


function showHelp {
    echo -e "\nUsage: loadimages.sh -p path/to/ppa_archive.tgz -r docker_registry [-l]\n"
    echo "Options:"
    echo "  -h  Display help"
    echo "  -p  PPA archive files location or archive filename"
    echo "      For example: /Downloads/PPA or /Downloads/PPA/ImageArchive.tgz or /Downloads/PPA/ImageArchive.tar.gz"
    echo "  -r  Target Docker registry and namespace"
    echo "      For example: mycorp-docker-local.mycorp.com/image-space"
    echo "  -l  Optional: Target a local registry"
}

# initialize variables
unset ppa_path
unset target_docker_repo
local_registry=false

OPTIND=1         # Reset in case getopts has been used previously in the shell.

if [[ $1 == "" ]]
then
    showHelp
    exit -1
else
    while getopts ":hlp:r:" opt; do
        case "$opt" in
        h|\?)
            showHelp
            exit 0
            ;;
        p)  ppa_path=${OPTARG}
            ;;
        r)  target_docker_repo=${OPTARG}
            ;;
        l)  local_registry=true
            ;;
        :)  echo "Invalid option: -$OPTARG requires an argument"
            showHelp
            exit -1
            ;;
      esac
    done

fi

shift $((OPTIND-1))

echo "ppa_path: $ppa_path"

# check required parameters
if [ -z "$ppa_path" ]
then
    echo "Need to input PPA archive files location or name value."
    showHelp
    exit -1
elif `test -f $ppa_path` || `test -d $ppa_path`
then
    arr_ppa_archive=( $(find ${ppa_path} -name "*.tgz" -o -name "*.tar.gz") )
    echo "arr_ppa_archive: $arr_ppa_archive"
else
    echo "Input PPA archive files location or name invalid! ($ppa_path) Exit and try again."
    showHelp
    exit -1
fi

echo "target_docker_repo: $target_docker_repo"
if [ -z "$target_docker_repo" ]
then
    echo "Need to input target Docker registry and namespace value."
    showHelp
    exit -1
fi

# reset counter
_ind=0

for ppa_file in ${arr_ppa_archive[@]}
do
    echo -e "\nCheck image archives in the PPA package: "$ppa_file
    # check manifest.json
    tar -zxvf $ppa_file manifest.json
    # get image archive files list in current PPA
    arr_img_gz=( $(grep archive manifest.json | awk '{print $2}' | sed 's/\"//g') )
    echo "Image archives list in ${ppa_file}:"
    echo ${arr_img_gz[@]}
    echo "Image archives in "$ppa_file" count: "${#arr_img_gz[@]}

    echo -e "\nLoad docker images from image archives into local registry."
    if [ ${#arr_img_gz[@]} -gt 0 ]
    then
        for img_gz_file in ${arr_img_gz[@]}
        do
            if [[ $img_gz_file == images/* ]]
            then
                echo "Loading image file: "$img_gz_file
                # echo "tar -zxf ${ppa_file} ${img_gz_file} -O | docker load -q"
                load_cmd_output=`tar -zOxf ${ppa_file} ${img_gz_file} | docker load -q`
                echo $load_cmd_output
                arr_img_load[$_ind]=${load_cmd_output#*Loaded image: }

                docker tag ${arr_img_load[$_ind]} ${target_docker_repo}/${arr_img_load[$_ind]}
                if ! $local_registry
                then
                    docker push ${target_docker_repo}/${arr_img_load[$_ind]} | grep -e repository -e digest -e unauthorized
                    docker rmi -f ${arr_img_load[$_ind]} ${target_docker_repo}/${arr_img_load[$_ind]} | grep -e unauthorized
                    echo "Pushed image: "${target_docker_repo}/${arr_img_load[$_ind]}
                fi
                let _ind++
            fi
        done
        echo "PPA package "$ppa_file" was processed completely."
    else
        echo "No image archive found in "$ppa_file
        continue
    fi
    
done

# summary list
if $local_registry
then
    status="load"
else
    status="push"
fi
echo -e "\nDocker images ${status} to ${target_docker_repo} completed, and check the following images in the Docker registry:"
for img_load in ${arr_img_load[@]}
do
    echo "     -  ${target_docker_repo}/${img_load}"
done

#
rm -rf manifest.json
