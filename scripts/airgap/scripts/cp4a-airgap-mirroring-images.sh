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


# HELPER SCRIPTS LOADED

#helper script for commonly used functions
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
    while [ "$#" -gt 0 ]; do
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


# These functions setup configurations and display the cases to be downloaded and other environment variables used
configure_ibm_pak_cli #Set up oc ibm-pak configurations

print_cases_table #display the cases to be downloaded

configure_environment_variables #display the environment variables used


#Start executing oc-mirror commands
download_case_files #downloads the case files

create_image_filter # Asks the customer if a filtered set of images should be mirrored

generate_mirror_manifests #generates mirror manifests

process_image_set_config_file  # function to process the image set config file that can be updated if required

mirror_images # function to mirror images

display_next_steps #function to display the next steps after mirroring

# Your script's main logic here
#echo "Script executed successfully!"