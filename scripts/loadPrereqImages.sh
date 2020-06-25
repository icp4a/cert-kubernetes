#!/bin/bash
#set -x
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
    echo -e "\nUsage: loadPrereqImages.sh -r docker_registry [-l]\n"
    echo "Options:"
    echo "  -h  Display help"
    echo "  -r  Target Docker registry and namespace"
    echo "      For example: mycorp-docker-local.mycorp.com/image-space"
    echo "  -l  Optional: Target a local registry"
}

# initialize variables
unset target_docker_repo
local_registry=false
unset cli_cmd
unset local_repo_prefix
unset loaded_msg_prefix

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

# Check OCI command
if command -v "podman" >/dev/null 2>&1
then
    echo "Use podman command to load images."
    cli_cmd="podman"
    local_repo_prefix="localhost/"
    loaded_msg_prefix="Loaded image(s): localhost/"
elif command -v "docker" >/dev/null 2>&1
then
    echo "Use docker command to load images."
    cli_cmd="docker"
    local_repo_prefix=""
    loaded_msg_prefix="Loaded image: "
else
    echo "No available Docker-compatible command line. Exit."
    exit -1
fi


shift $((OPTIND-1))


echo "target_docker_repo: $target_docker_repo"
if [ -z "$target_docker_repo" ]
then
    echo "Need to input target Docker registry and namespace value."
    showHelp
    exit -1
fi

# declare -A prereqimages=(["db2u.tools:11.5.1.0-CN1"]="docker.io/ibmcom/"
#                    ["db2:11.5.1.0-CN1"]="docker.io/ibmcom/"
#                    ["db2u.auxiliary.auth:11.5.1.0-CN1"]="docker.io/ibmcom/"
#                    ["db2u.instdb:11.5.1.0-CN1"]="docker.io/ibmcom/"
#                    ["etcd:v3.3.10"]="quay.io/coreos/"
#                    ["openldap:1.3.0"]="osixia/"
#                    ["busybox:latest"]="docker.io/library/"
#                    ["phpldapadmin:0.9.0"]="osixia/"
#                     )
 prereqimages=("db2u.tools:11.5.1.0-CN1"
               "db2:11.5.1.0-CN1"
               "db2u.auxiliary.auth:11.5.1.0-CN1"
               "db2u.instdb:11.5.1.0-CN1"
               "etcd:v3.3.10"
               "openldap:1.3.0"
               "busybox:latest"
               "phpldapadmin:0.9.0")
function getimagerepo(){
    if [[ $image == ${prereqimages[0]} ]]; then
        image_repo="docker.io/ibmcom/"
    elif [[ $image == ${prereqimages[1]} ]]; then
        image_repo="docker.io/ibmcom/"
    elif [[ $image == ${prereqimages[2]} ]]; then
        image_repo="docker.io/ibmcom/"
    elif [[ $image == ${prereqimages[3]} ]]; then
        image_repo="docker.io/ibmcom/"
    elif [[ $image == ${prereqimages[4]} ]]; then
        image_repo="quay.io/coreos/"
    elif [[ $image == ${prereqimages[5]} ]]; then
        image_repo="osixia/"
    elif [[ $image == ${prereqimages[6]} ]]; then
        image_repo="docker.io/library/"
    elif [[ $image == ${prereqimages[7]} ]]; then
        image_repo="osixia/"
    fi
}

for image in "${prereqimages[@]}"
do
  getimagerepo
  origin_image=${image_repo}${image}

  echo -e "\x1B[1mPull image: ${origin_image}.\n\x1B[0m"   
  ${cli_cmd} pull ${origin_image}

  if [ "${cli_cmd}" = "docker" ]
    then
      echo "${cli_cmd} tag ${origin_image} ${target_docker_repo}/${image}"
      ${cli_cmd} tag ${origin_image} ${target_docker_repo}/${image}
  elif  [ "${cli_cmd}" = "podman" ]
    then
      echo "${cli_cmd} tag ${origin_image} ${image}"
      ${cli_cmd} tag ${origin_image} ${image}
  fi

  if ! $local_registry
    then
      if [ "${cli_cmd}" = "docker" ]
        then
          ${cli_cmd} push ${target_docker_repo}/${image} | grep -e repository -e digest -e unauthorized
          ${cli_cmd} rmi -f ${origin_image} ${target_docker_repo}/${image} | grep -e unauthorized
          echo -e "\x1B[1mPushed image: ${target_docker_repo}/${image} \n\x1B[0m"  

      elif [ "${cli_cmd}" = "podman" ]
        then
          ${cli_cmd} push --tls-verify=false ${local_repo_prefix}${image} ${target_docker_repo}/${image} | grep -e repository -e digest -e unauthorized
          ${cli_cmd} rmi -f ${origin_image} ${local_repo_prefix}${image}| grep -e unauthorized
          echo -e "\x1B[1mPushed image: ${target_docker_repo}/${image} \n\x1B[0m" 
      fi
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
for img_load in ${prereqimages[@]}
do
    echo "     -  ${target_docker_repo}/${img_load}"
done
