#!/bin/bash
# set -x
###############################################################################
#
# Licensed Materials - Property of IBM
#
# (C) Copyright IBM Corp. 2021. All Rights Reserved.
#
# US Government Users Restricted Rights - Use, duplication or
# disclosure restricted by GSA ADP Schedule Contract with IBM Corp.
#
###############################################################################
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
    echo -e "\nUsage: loadPrereqImages.sh -r docker_registry [-t] [-l]\n"
    echo "Options:"
    echo "  -h  Display help"
    echo "  -r  Target Docker registry and namespace"
    echo "      For example: mycorp-docker-local.mycorp.com/image-space"
    # echo "  -t  Optional: Download OSS images from IBM Staging Entitled Registry"
    echo "  -l  Optional: Target a local registry"
}

# initialize variables
unset target_docker_repo
local_registry=false
unset cli_cmd
unset local_repo_prefix
unset loaded_msg_prefix
DOCKER_REG_SERVER="cp.icr.io"
OPTIND=1         # Reset in case getopts has been used previously in the shell.

if [[ $1 == "" ]]
then
    showHelp
    exit -1
else
    while getopts ":hltr:" opt; do
        case "$opt" in
        h|\?)
            showHelp
            exit 0
            ;;
        r)  target_docker_repo=${OPTARG}
            ;;
        l)  local_registry=true
            ;;
        t)  DOCKER_REG_SERVER="cp.stg.icr.io"
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
echo "Pulling OSS images from '$DOCKER_REG_SERVER'"

shift $((OPTIND-1))

echo "Target_docker_repo: $target_docker_repo"
if [ -z "$target_docker_repo" ]
then
    echo "Need to input target Docker registry and namespace value."
    showHelp
    exit -1
fi

function loginEntitlementRepo() {
    printf "\n"
    printf "\x1B[1mThe script will pull 'openldap, busybox, phpldapadmin, alpine, gitea' images from Entitled Registry. \n\x1B[0m"
    printf "\x1B[1mFollow the instructions on how to get your Entitlement Key if you don't have it: \n\x1B[0m"
    printf "\x1B[1mhttps://www.ibm.com/support/knowledgecenter/en/SSYHZ8_20.0.x/com.ibm.dba.install/op_topics/tsk_images_enterp.html\n\x1B[0m"
    # printf "\x1B[1mNote: If you are using the Staging Entiled Registry, then use IAMAPIKey in the format 'iamapikey:xxxxx' where 'xxxxx' is the IAMAPIKey.\n \x1B[0m"
    printf "\n"
    printf "\x1B[1mEnter your Entitlement Registry key: \x1B[0m"
    while [[ $entitlement_key == '' ]]
    do
        read -rsp "" entitlement_key
        if [ -z "$entitlement_key" ]; then
            printf "\n"
            echo -e "\x1B[1;31mEnter a valid Entitlement Registry key\x1B[0m"
        else
            if  [[ $entitlement_key == iamapikey:* ]] ;
            then
                DOCKER_REG_USER="iamapikey"
                DOCKER_REG_KEY="${entitlement_key#*:}"
            else
                DOCKER_REG_USER="cp"
                DOCKER_REG_KEY=$entitlement_key

            fi
            entitlement_verify_passed=""
            while [[ $entitlement_verify_passed == '' ]]
            do
                printf "\n"
                printf "\x1B[1mVerifying the Entitlement Registry key...\n\x1B[0m"
                if [ "${cli_cmd}" = "docker" ]; then
                    if docker login -u "$DOCKER_REG_USER" -p "$DOCKER_REG_KEY" "$DOCKER_REG_SERVER"; then
                        entitlement_verify_passed="passed"       
                    fi
                elif  [ "${cli_cmd}" = "podman" ];then
                    if podman login -u "$DOCKER_REG_USER" -p "$DOCKER_REG_KEY" "$DOCKER_REG_SERVER" --tls-verify=false; then
                        entitlement_verify_passed="passed"
                    fi
                fi
                
                if [[ $entitlement_verify_passed == '' ]]; then
                    printf "\x1B[1;31mThe Entitlement Registry key failed.\n\x1B[0m"
                    printf "\x1B[1mEnter a valid Entitlement Registry key.\n\x1B[0m"
                    entitlement_key=''
                    entitlement_verify_passed="failed"
                else
                    printf "Entitlement Registry key is valid.\n"
                fi                        
            done
        fi
    done

}

 prereqimages=("db2u.tools:11.5.1.0-CN1"
               "db2:11.5.1.0-CN1"
               "db2u.auxiliary.auth:11.5.1.0-CN1"
               "db2u.instdb:11.5.1.0-CN1"
               "etcd:v3.3.10"
               "openldap:1.3.0"
               "busybox:1.32"
               "phpldapadmin:0.9.0"
               "alpine:3.6"
               "gitea:1.12.3")

function getimagerepo(){
    if [[ $image == db2* ]]; then
        image_repo="docker.io/ibmcom/"
    elif [[ $image == etcd* ]]; then
        image_repo="quay.io/coreos/"
    else
        image_repo="$DOCKER_REG_SERVER/cp/cp4a/demo/"
    fi
}

loginEntitlementRepo

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

