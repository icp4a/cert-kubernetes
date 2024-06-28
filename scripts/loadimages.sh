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

echo -e "\033[1;31mImportant! The load image sample script is for x86_64, amd64, or i386 platforms only. \033[0m"
echo -e "\033[1;31mImportant! Please ensure that: \n\
    1. you had login to the target Docker registry in advance. \n\
    2. you had login to IBM Entitiled Image Registry in advance.  \n\
    3. you had skopeo installed in advance. \033[0m \n" 


function showHelp {
    echo -e "\nUsage: loadimages.sh -r docker_registry [-m]\n"
    echo "Options:"
    echo "  -h  Display help"
    echo "  -r  Target Docker registry"
    echo "      For example: mycorp-docker-local.mycorp.com"
    echo "  -m  Optional: wheter to run the script in dev mode or BAW standalone mode, below are acceptable values:"
    echo "      if set as 'dev', then will pull images from IBM Staging Image Registry"
    echo "      if set as 'baw', run for BAW standalone mode and pull images from IBM Image Registry"
    echo "      if set as 'baw-dev', run for BAW standalone mode and pull images from IBM Staging Image Registry"
}

# initialize variables
unset ppa_path
unset target_docker_repo
unset DEPLOYMENT_TYPE
unset SCRIPT_MODE
unset PATTERNS_SELECTED
PLATFORM_SELECTED="other" # This is the default value and will be reset by select_pattern.sh

unset CR_FILES
OPTIND=1         # Reset in case getopts has been used previously in the shell.
LOG_FILE="${CUR_DIR}/lodimages.log" # Keep image upload logs
touch $LOG_FILE && echo '' > $LOG_FILE # Reset log content

if [[ $1 == "" ]]
then
    showHelp
    exit -1
else
    while getopts ":h:m:r:" opt; do
        case "$opt" in
        h|\?)
            showHelp
            exit 0
            ;;
        r)  target_docker_repo=${OPTARG}
            ;;
        m)  SCRIPT_MODE=${OPTARG}
            ;;
        :)  echo "Invalid option: -$OPTARG requires an argument"
            showHelp
            exit -1
            ;;
      esac
    done

fi

if [[ "${SCRIPT_MODE}" =~ "baw" ]]; then
    cr_file_name="" # BAW standalone doesn't need foundation CR.
else
    cr_file_name="foundation" # Always include FC foundation CR.
fi

# check required parameters
echo "target_docker_repo: $target_docker_repo"
if [ -z "$target_docker_repo" ]
then
    echo "Need to input target Docker registry and namespace value."
    showHelp
    exit -1
fi

function prepare_pattern_file(){
    DEPLOY_TYPE_IN_FILE_NAME="production_FC"
    FOUNDATION_PATTERN_FILE=${PARENT_DIR}/descriptors/patterns/ibm_cp4a_cr_${DEPLOYMENT_TYPE}_foundation.yaml
    CONTENT_PATTERN_FILE=${PARENT_DIR}/descriptors/patterns/ibm_cp4a_cr_${DEPLOY_TYPE_IN_FILE_NAME}_content.yaml
    APPLICATION_PATTERN_FILE=${PARENT_DIR}/descriptors/patterns/ibm_cp4a_cr_${DEPLOY_TYPE_IN_FILE_NAME}_application.yaml
    DECISIONS_PATTERN_FILE=${PARENT_DIR}/descriptors/patterns/ibm_cp4a_cr_${DEPLOY_TYPE_IN_FILE_NAME}_decisions.yaml
    ADS_PATTERN_FILE=${PARENT_DIR}/descriptors/patterns/ibm_cp4a_cr_${DEPLOY_TYPE_IN_FILE_NAME}_decisions_ads.yaml
    ARIA_PATTERN_FILE=${PARENT_DIR}/descriptors/patterns/ibm_cp4a_cr_${DEPLOY_TYPE_IN_FILE_NAME}_document_processing.yaml
    WORKFLOW_PATTERN_FILE=${PARENT_DIR}/descriptors/patterns/ibm_cp4a_cr_${DEPLOY_TYPE_IN_FILE_NAME}_workflow.yaml
    WORKSTREAMS_PATTERN_FILE=${PARENT_DIR}/descriptors/patterns/ibm_cp4a_cr_${DEPLOY_TYPE_IN_FILE_NAME}_workstreams.yaml
    WORKFLOW_AUTHOR_PATTERN_FILE=${PARENT_DIR}/descriptors/patterns/ibm_cp4a_cr_${DEPLOY_TYPE_IN_FILE_NAME}_workflow_authoring.yaml
}

function push_images(){
    DEPLOY_TYPE_IN_FILE_NAME="production_FC"
    # Get CR list according to selected patterns, FC foundation CR will be included. 
    for item in ${cr_file_name[@]}
    do
        CR_FILES[${#CR_FILES[*]}]="${PARENT_DIR}/descriptors/patterns/ibm_cp4a_cr_${DEPLOY_TYPE_IN_FILE_NAME}_${item}.yaml"
    done
    # For starter deployment, including ibm_cp4a_cr_starter_foundation.yaml as well.
    if [[ "$DEPLOYMENT_TYPE" == "starter" ]]; then
        CR_FILES[${#CR_FILES[*]}]="${PARENT_DIR}/descriptors/patterns/ibm_cp4a_cr_starter_foundation.yaml"
    fi

    

    source ${CUR_DIR}/helper/extract_and_push_images.sh $CR_FILES $target_docker_repo 2>&1| tee -a $LOG_FILE
}

# Import common utilities and environment variables
source ${CUR_DIR}/helper/common.sh
validate_cli # Make sure user install yq
source ${CUR_DIR}/helper/select_deployment_type.sh
source ${CUR_DIR}/helper/select_platform.sh
if [[ "${SCRIPT_MODE}" =~ "baw" ]]; then
    # For BAW stand alone delivery, no need to show pattern list since there is only one pattern
    # Will extra image list from ibm_cp4a_cr_production_FC_workflow-standalone.yaml for both starter and production deployment
    cr_file_name[${#cr_file_name[*]}]="workflow-standalone"
else
    source ${CUR_DIR}/helper/select_pattern.sh
    source ${CUR_DIR}/helper/map_pattern_and_CR.sh
fi

push_images
