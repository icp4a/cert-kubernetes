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

CUR_DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"
PARENT_DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )/.." && pwd )"
TEMP_FOLDER=${CUR_DIR}/.tmp
unset IFS #This is to reset using "," as separate in map_pattern_and_CR.sh
ODM_PRESENT="False"
ODM_REPO="cp.icr.io/cp/cp4a/odm"
#################debug##########################
# PLATFORM_SELECTED="OCP"
# SCRIPT_MODE="dev"
# IMAGE_REGISTRY="hyc-dba-base-image-docker-local.artifactory.swg-devops.com/gyfguo"
#################debug###d######################

if [[ $1 == "" ]]; then
  # This is for debug purpose only
  DEPLOY_TYPE_IN_FILE_NAME="production_FC"
  FOUNDATION_PATTERN_FILE=${PARENT_DIR}/../descriptors/patterns/ibm_cp4a_cr_${DEPLOY_TYPE_IN_FILE_NAME}_foundation.yaml
  CONTENT_PATTERN_FILE=${PARENT_DIR}/../descriptors/patterns/ibm_cp4a_cr_${DEPLOY_TYPE_IN_FILE_NAME}_content.yaml
  CR_FILES=(${FOUNDATION_PATTERN_FILE} ${CONTENT_PATTERN_FILE})
else
  CR_FILES=$1
fi

if [[ $2 == "" ]]; then
  IMAGE_REGISTRY="localhost:5000"
else
  IMAGE_REGISTRY=$2
fi

if [ ! -d "${TEMP_FOLDER}" ]; then
  mkdir $TEMP_FOLDER
fi
IMAGE_REPOSITORY_LIST_FILE=${TEMP_FOLDER}/image_repository_list.properties
IMAGE_TAG_LIST_FILE=${TEMP_FOLDER}/image_tag_list.properties

echo "patterns in here $CR_FILES"
function extract_image_list_from_CR(){
  # clean the list content
  echo '' > ${IMAGE_REPOSITORY_LIST_FILE}
  echo '' > ${IMAGE_TAG_LIST_FILE}

  # extract repository and tag for each CR
  for item in "${CR_FILES[@]}"
  do
    echo "Extracting images from $item..."
    ${YQ_CMD} r ${item} "**.repository" >> ${IMAGE_REPOSITORY_LIST_FILE}
    ${YQ_CMD} r ${item} "**.tag" >> ${IMAGE_TAG_LIST_FILE}
  done

  # For debug purpose, dev would pull from staging image registry
  if [[ "${SCRIPT_MODE}" =~ "dev" ]]; then
    sed -i 's/cp.icr.io/cp.stg.icr.io/g' ${IMAGE_REPOSITORY_LIST_FILE}
  fi
}

function extract_odm_image_list(){
  IMAGE_REPOSITORY_LIST1=($(cat $IMAGE_REPOSITORY_LIST_FILE))
  IMAGE_TAG_LIST1=($(cat $IMAGE_TAG_LIST_FILE))
  #to get the current tag of odm
  for i in "${!IMAGE_REPOSITORY_LIST1[@]}"
  do
    if [[ "${IMAGE_REPOSITORY_LIST1[$i]}" == "${ODM_REPO}" ]]; then
      ODM_IMAGE_TAG=${IMAGE_TAG_LIST1[$i]}
    fi
  done
  #array of odm images repositories
  ODM_IMAGE_REPOSITORY_LIST=("cp.icr.io/cp/cp4a/odm/odm-decisioncenter" "cp.icr.io/cp/cp4a/odm/dbserver" "cp.icr.io/cp/cp4a/odm/odm-decisionrunner" "cp.icr.io/cp/cp4a/odm/odm-decisionserverconsole" "cp.icr.io/cp/cp4a/odm/odm-decisionserverruntime" "cp.icr.io/cp/cp4a/odm/dba-keytool-initcontainer")
  for repo_item in "${ODM_IMAGE_REPOSITORY_LIST[@]}"
  do
    echo ${repo_item} >> ${IMAGE_REPOSITORY_LIST_FILE}
    echo ${ODM_IMAGE_TAG} >> ${IMAGE_TAG_LIST_FILE}
  done

  # For debug purpose, dev would pull from staging image registry
  if [[ "${SCRIPT_MODE}" =~ "dev" ]]; then
    sed -i 's/cp.icr.io/cp.stg.icr.io/g' ${IMAGE_REPOSITORY_LIST_FILE}
  fi

}


function push_images(){
  IMAGE_REPOSITORY_LIST=($(cat $IMAGE_REPOSITORY_LIST_FILE))
  IMAGE_TAG_LIST=($(cat $IMAGE_TAG_LIST_FILE))

  if [ ${#IMAGE_REPOSITORY_LIST[@]} != ${#IMAGE_TAG_LIST[@]} ]; then
    echo "Image repository number doesn't match image tag number, exit now...."
    exit 1
  else
    i=0
    for item in "${IMAGE_REPOSITORY_LIST[@]}"
    do  
      # DBACLD-31777: remove image context and --src-creds comment
      new_image_repo="${IMAGE_REPOSITORY_LIST[i]##*/}"
      echo "Pushing $i: ${IMAGE_REPOSITORY_LIST[i]}:${IMAGE_TAG_LIST[i]} to ${IMAGE_REGISTRY}/${new_image_repo}:${IMAGE_TAG_LIST[i]}"
      skopeo copy \
        docker://"${IMAGE_REPOSITORY_LIST[i]}:${IMAGE_TAG_LIST[i]}" \
        docker://"${IMAGE_REGISTRY}/${new_image_repo}:${IMAGE_TAG_LIST[i]}" \
        --all \
        --dest-tls-verify=false \
        --remove-signatures
      ((i++))
    done
  fi
}

extract_image_list_from_CR
IMAGE_REPOSITORY_LIST1=($(cat $IMAGE_REPOSITORY_LIST_FILE))
#check if odm is present from the selected patterns
if [[ " ${IMAGE_REPOSITORY_LIST1[@]} " =~ "cp.icr.io/cp/cp4a/odm" ]]; then
  extract_odm_image_list
fi
push_images