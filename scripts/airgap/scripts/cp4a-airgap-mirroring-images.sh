#!/bin/bash
###############################################################################
#
# Licensed Materials - Property of IBM
#
# (C) Copyright IBM Corp. 2024. All Rights Reserved.
#
# US Government Users Restricted Rights - Use, duplication or
# disclosure restricted by GSA ADP Schedule Contract with IBM Corp.
#
###############################################################################


#This is a script that peforms the mirroring of all images for a specific CP4BA IFix Version from entitlement registry to a private registry.
#SCRIPT VARIABLES
CUR_DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"
PARENT_DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )/.." && pwd )"
TO_BE_MIRRORED_FILE=$(find "$PARENT_DIR" -maxdepth 1 -type f -name "cp4ba-case*" | tail -n 1)
AIRGAP_FOLDER=${CUR_DIR}/cp4ba-airgap-logs
AIRGAP_FOLDER_MIRRORING_LOGS=$AIRGAP_FOLDER/mirroring_logs
CONFIG_FILE=""
#Script mode can be 3 types
# 1. prod -> this is for mirroring images from a published case package ( DEFAULT)
# 2. devprodER -> this is an internal mode that should be used for mirroring images from the internal case location and when the images have been push to production ER
# 3. devstagingER -> this is an internal mode that should be used for mirroring images from the internal case location and when the images are still in staging ER
SCRIPT_MODE="prod"


# HELPER SCRIPTS LOADED

#helper script for commonly used functions
# All DEV mode only related functions are also found here
source ${CUR_DIR}/helperscripts/common.sh

#helper script to perform the validation of tools required to do the mirroring
source ${CUR_DIR}/helperscripts/prechecks.sh

#helper script that collects all user inputs/ parses the property file for silent install
source ${CUR_DIR}/helperscripts/user_inputs.sh

#helper script that collects all user inputs/ parses the property file for silent install
source ${CUR_DIR}/helperscripts/setup_configuration.sh

#helper script that runs the different oc mirror commands
source ${CUR_DIR}/helperscripts/execute_mirror_commands.sh


#calling helper function to create an airgap directory, it also tars and saves a copy of the old
create_or_recreate_dir $AIRGAP_FOLDER true
#calling helper function to create an airgap directory
create_or_recreate_dir $AIRGAP_FOLDER_MIRRORING_LOGS false

#Functions to start logging the script output
save_log $AIRGAP_FOLDER/script_logs "cp4a-airgap-mirroring-images-log" 
trap cleanup_log EXIT

function parse_args() {
    while [[ "$@" != "" ]]; do
    case "$1" in
        --help)
        print_help
        exit 1
        ;;
        -c)
        if [ -n "$2" ] && [ "${2#-}" = "$2" ]; then
            CONFIG_FILE="$2"
            shift
        else
            echo "Error: Missing argument for -c option."
            exit 1
        fi
        ;;
        dev)
        SCRIPT_MODE="devprodER"
        ;;
        devstaging)
        SCRIPT_MODE="devstagingER"
        ;;
        -*)
        echo "Error: Unsupported option $1"
        exit 1
        ;;
        *)
        echo "Error: Unsupported argument $1"
        exit 1
        ;;
    esac
    shift
    done

}


# Call the function to parse arguments
parse_args "$@"


# Code block that checks for dev env variables being set 
# ONLY FOR DEV MODE
if [[ "$SCRIPT_MODE" == "devprodER" || "$SCRIPT_MODE" == "devstagingER" ]]; then
    info "DEV mode initiated..."
    info "The script will mirror images from the internal case repository.."
    env_present=true
    check_required_dev_env_vars HTTP_CASE_USER_NAME HTTP_CASE_PASSWORD CASECTL_RESOLVERS_LOCATION CASECTL_RESOLVERS_AUTH_LOCATION
    if [[ "$env_present" == true ]]; then
        GIT_USERNAME=$HTTP_CASE_USER_NAME
        GIT_PASSWORD=$HTTP_CASE_PASSWORD
        CASE_RESOLVERS_LOCATION=$CASECTL_RESOLVERS_LOCATION
        CASE_RESOLVERS_AUTH_LOCATION=$CASECTL_RESOLVERS_AUTH_LOCATION
    else
        echo "The script will now exit"
        exit
    fi
    #exit
fi


# Validate 
info "This script will execute the mirroring of images for the CP4BA version."
printf "\n"
echo_bold "Starting with the validation of packages required for this script."

# Run the validation checks on all tools required
validate_tools

# Either load and parse the config file if it was passed or gather user inputs needed interactively from the terminal
if [ -n "$CONFIG_FILE" ]; then
    #Function to process config_file
    process_config_file "$CONFIG_FILE"
else
    #Function to ask and process user inputs
    prompt_user_input
fi


#Configure and display the environment variables used in the script for the mirroring process
configure_environment_variables $SCRIPT_MODE 

#display the cases to be downloaded
print_cases_table 

# Start executing oc-mirror commands

# Funciton to download the case files required
download_case_files $SCRIPT_MODE

### START OF A DEV MODE STEP ####
# This is a step required only when the images are in staging and we need to modify some of the images to point to staging ER
if [[ "$SCRIPT_MODE" == "devstagingER" ]]; then
    modify_metadata_files
fi
### END OF A DEV MODE STEP ####

# Function that Asks the customer if a filtered set of images should be mirrored and accordingly builds the image filter
create_image_filter

generate_mirror_manifests #generates mirror manifests

# function to process the image set config file that can be updated if required
# We pass script mode so that if required we will perform dev mode related modifications to the image_set_config.yaml
process_image_set_config_file  $SCRIPT_MODE 

mirror_images # function to mirror images

display_next_steps #function to display the next steps after mirroring