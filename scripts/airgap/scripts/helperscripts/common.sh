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


#common variables needed for the script

# Release/Patch version for CP4BA
# CP4BA_RELEASE_BASE is for fetch content/foundation operator pod, only need to change for major release.
CP4BA_RELEASE_BASE="25.0.0"
#set of filters that can be used while mirroring images
AUTOMATION_DECISION_SERVICES="ibmcp4baProd,ibmcp4baADSImages,ibmcp4baBANImages,ibmcp4baBASImages,ibmcp4baAAEImages,ibmEdbStandard"
AUTOMATION_DOCUMENT_PROCESSING="ibmcp4baProd,ibmcp4baADPImages,ibmcp4baFNCMImages,ibmcp4baBANImages,ibmcp4baBASImages,ibmcp4baAAEImages,ibmEdbStandard"
AUTOMATION_WORKSTREAM_SERVICES="ibmcp4baProd,ibmcp4baBAWImages,ibmcp4baPFSImages,ibmcp4baFNCMImages,ibmcp4baBANImages,ibmcp4baBASImages,ibmcp4baAAEImages,ibmEdbStandard"
BUSINESS_AUTOMATION_APPLICATION="ibmcp4baProd,ibmcp4baBASImages,ibmcp4baAAEImages,ibmEdbStandard"
BUSINESS_AUTOMATION_WORKFLOW="ibmcp4baProd,ibmcp4baBAWImages,ibmcp4baFNCMImages,ibmcp4baBANImages,ibmcp4baBASImages,ibmcp4baAAEImages,ibmEdbStandard,ibmcp4baUMSImages,ibm_es_1_1_2470"
PROCESS_FEDERATION_SERVER="ibmcp4baProd,ibmcp4baPFSImages,ibmcp4baAAEImages,ibm_es_1_1_2470"
FILENET_CONTENT_MANAGER="ibmcp4baProd,ibmcp4baFNCMImages,ibmcp4baBANImages,ibmcp4baAAEImages,ibmEdbStandard"
OPERATION_DECISION_MANAGER="ibmcp4baProd,ibmcp4baODMImages,ibmcp4baBASImages,ibmcp4baAAEImages,ibmEdbStandard"
WORKFLOW_PROCESS_SERVICE="ibmcp4baProd,ibmcp4baAAEImages,ibmcp4baBASImages,ibmcp4baWFPSImages,ibmEdbStandard,ibm_es_1_1_2470"
BUSINESS_AUTOMATION_INSIGHTS_STANDALONE="ibmcp4baProd,ibmcp4baBAIImages,ibmEdbStandard,ibm_es_1_1_2470"
SELECTED_FILTER_OPTIONS=(0 0 0 0 0 0 0 0 0 0)
IMAGE_MIRROR_FILTER=""


# Function to check if a directory exists, create a tar ,delete and recreate if present, else just create it
create_or_recreate_dir() {
    local dir_path="$1"  # The directory path to check
	local tar_file="$2"
    
    if [[ ( -d "$dir_path") && $tar_file=="true" ]]; then
        #echo "Directory exists: $dir_path. Deleting and recreating."
		tar_folder_if_exists $dir_path
        rm -rf "$dir_path"
    fi
    
    # Create the directory
    mkdir -p "$dir_path"
    #echo "Directory created: $dir_path"
}

# creating a tar file of the logs folder of the previous execution
tar_folder_if_exists() {
    folder_path="$1"

    if [[ -d "$folder_path" ]]; then
        tar_file_name="$(basename "$folder_path")_$(date +'%Y%m%d%H%M%S').tar.gz"
        #echo "Tarring folder $folder_path into $tar_file_name..."
        
        # Create the tar.gz archive
        tar -czf "$CUR_DIR/$tar_file_name" -C "$(dirname "$folder_path")" "$(basename "$folder_path")"
        
        #echo "Tar archive created: $tar_file_name"
    fi
}



# Set of common utility functions that are used in the cp4a-airgap-mirroring-images script

function set_global_env_vars() {
    unameOut="$(uname -s)"
    case "${unameOut}" in
        Linux*)     machine="Linux";;
        Darwin*)    machine="Mac";;
        *)          machine="UNKNOWN:${unameOut}"
    esac

    if [[ "$machine" == "Mac" ]]; then
        SED_COMMAND='sed -i ""'
        SED_COMMAND_FORMAT='sed -i "" s/^M//g'
        YQ_CMD=${CUR_DIR}/../../helper/yq/yq_darwin_amd64
        COPY_CMD=/bin/cp
    else
        SED_COMMAND='sed -i'
        SED_COMMAND_FORMAT='sed -i s/\r//g'
        if [[ $(uname -m) == 'x86_64' ]]; then
            YQ_CMD=${CUR_DIR}/../../helper/yq/yq_linux_amd64
        elif [[ $(uname -m) == 'ppc64le' ]]; then
            YQ_CMD=${CUR_DIR}/../../helper/yq/yq_linux_ppc64le
        else
            YQ_CMD=${CUR_DIR}/../../helper/yq/yq_linux_s390x
        fi
        COPY_CMD=/usr/bin/cp
    fi
}

###################
# Echoing utilities
###################
RED_TEXT=`tput setaf 1`
GREEN_TEXT=`tput setaf 2`
YELLOW_TEXT=`tput setaf 3`
BLUE_TEXT=`tput setaf 6`
WHITE_TEXT=`tput setaf 7`
RESET_TEXT=`tput sgr0`

set_global_env_vars


function msg() {

  printf '\n%b\n' "$1"

}



function wait_msg() {

  printf '%s\r' "${1}"

}

function success() {

  msg "\33[32m[✔] ${1}\33[0m"

}

function info() {

  msg "\x1B[33;5m[INFO] \x1B[0m${1}"

}

function INFO() {

  msg "============== ${1} =============="

}



function error() {

  msg "\33[31m[✘] ${1}\33[0m"

}

function echo_impl() {
    # Echoes a message prefixed and suffixed by formatting characters
    local MSG=${1:?Missing message to echo}
    local PREFIX=${2:?Missing message prefix}
    #local SUFFIX=${3:?Missing message suffix}
    printf '%b\n' "\x1B[1${PREFIX}${MSG}\x1B[0m"
}

function echo_bold() {
    # Echoes a message in bold characters
    echo_impl "${1}" "m"
}


# Function to display help/usage
function print_help() {
  echo "Usage: $0 [OPTIONS]"
  echo ""
  echo "Options:"
  echo "  --help      Show the usage of the cp4a-airgap-mirroring-images.sh script"
  echo "  -c <file>   Specify the config file with variables (optional)."
  echo "Sample file can be found at ${CUR_DIR}/configfile/cp4a_airgap_mirroring.property"
  echo ""
  exit 1
}

# Function to check if a file exists, and exit if not found
check_file_exists() {
    local file_path="$1"  # The file path to check

    if [ ! -f "$file_path" ]; then
        echo "Error: File does not exist: $file_path"
        return 1  # Return from the function with an error code
    fi
}

#parse the property file
function prop_airgap_mirroring_file() {
    grep "^${2}=" ${1}|cut -d'"' -f2
}

function base64_encode() {
    local input="$1"
    local encoded=$(printf '%s' "$input" | base64)
    eval "$2='$encoded'"
}

function base64_decode() {
    local input="$1"
    local decoded=$(printf '%s' "$input" | base64 --decode)
    eval "$2='$decoded'"
}

# Function that checks if there are any missing quotes in the config file being used
function check_missing_quotes(){
    local input_file=$1
    missing_quotes=0

    tmp_file=$(mktemp)
    sed $'s/\r//g' "$input_file" > "$tmp_file" && mv "$tmp_file" "$input_file"
    # Array to store incorrect entries
    incorrect_values=()

    while IFS= read -r line || [ -n "$line" ]; do
        # Skip comment lines or empty lines
        if [[ $line =~ ^[[:space:]]*# ]] || [[ -z $line ]]; then
            continue
        fi
        
        # Skip lines that are completely empty or contain only whitespace
        if [[ "$line" =~ ^[[:space:]]*$ ]]; then
            continue
        fi

        # Ensure the line contains '=' before processing
        if [[ $line != *"="* ]]; then
            continue
        fi

        # Extract the key and value
        key=$(echo "$line" | cut -d'=' -f1)
        value=$(echo "$line" | cut -d'=' -f2-)

        # Check if the value is enclosed in quotes
        if [[ ! $value =~ ^\".*\"$ ]]; then
            # Add to the list of incorrect values
            incorrect_values+=("$key")
        fi
    done < "$input_file"

    # Output results
    if [ ! ${#incorrect_values[@]} -eq 0 ]; then
        missing_quotes=1
        error "Validation of the config file has failed: The following values in the confile file located at \"${input_file}\" are not enclosed in quotes:"
        printf "\n"
        echo "---------------------------------------------------------------"
        for entry in "${incorrect_values[@]}"; do
            echo "  - $entry"
        done
        echo "---------------------------------------------------------------"

    fi

    if [[ "$missing_quotes" == 1 ]] ; then
        info "[NEXT_STEPS]: Reference the table above and ensure all values in the config file are enclosed in quotes and re-run \"cp4a-airgap-mirroring-images.sh -c ${input_file} \" ."
        exit 1
    fi
}

# Function to validate the config file passed
# Function checks if all values are filled and to make sure all values are enclosed in quotes
function validate_config_file(){
    local input_file=$1
    check_missing_quotes $input_file
    local empty_value_tag=0
    value_empty=`grep '="<Required>"' "${input_file}" | wc -l`  >/dev/null 2>&1
    if [ $value_empty -ne 0 ] ; then
        #Extract the parameter name and include it to the error message when the property not defined in the file.
        parameter_name=$(grep '="<Required>"' "${input_file}" | awk -F'=' '{print $1}'  | tr -d ' ' | paste -sd ',' -)
        error "Found invalid value(s) \"<Required>\" found for parameter \"$parameter_name\" in the config file located at \"${input_file}\", please input the correct value."
        empty_value_tag=1
        exit 1
    fi
    success " Validation of config file located at \"$input_file\" successfully completed."
    printf "\n"

}

# For https://jsw.ibm.com/browse/DBACLD-207571
# Function to parse and display image-set-config.yaml (yq v4 compatible)
function display_image_set_config_file() {
    # Path to your YAML file
    yaml_file=$1
    
    # Extract all package names (yq v4 syntax)
    package_names=$(${YQ_CMD} eval '.mirror.operators[].packages[].name' "$yaml_file")

    # Print the header
    printf "%-30s %-50s\n" "Package" "Channels"
    printf "%-30s %-50s\n" "-------" "-------"
    
    # Iterate over each package name
    while IFS= read -r package_name; do
        # Extract the channels associated with the current package (yq v4 syntax)
        channels=$(${YQ_CMD} eval ".mirror.operators[].packages[] | select(.name == \"$package_name\") | .channels[].name" "$yaml_file")

        # Print the package name
        printf "%-30s " "$package_name"
        
        # Prepare the channel list to display in the second column
        channel_list=""
        while IFS= read -r channel; do
            if [ -n "$channel" ]; then
                channel_list+="$channel, "
            fi
        done <<< "$channels"
        
        # Remove trailing comma and space if channel_list is not empty
        channel_list=${channel_list%, }

        # Print the channels in the second column
        printf "%-50s\n" "$channel_list"
    done <<< "$package_names"
    printf "\n"
}

# For https://jsw.ibm.com/browse/DBACLD-207571
# Function to edit the image-set-config.yaml file to keep only the latest channel (yq v4 compatible)
function edit_image_set_config_file(){
	# Define the original YAML file path and the new output file path
	local original_yaml=$1
	check_file_exists "$original_yaml" || exit 1
	cp -f "$original_yaml" "$AIRGAP_FOLDER/image-set-config-backup.yaml" 
	local new_yaml="$ibm_pak_home/.ibm-pak/data/mirror/$case_name/$case_version/image-set-config-new.yaml"
	# Copy the original file to the new file
	cp "$original_yaml" "$new_yaml"

	# Check if operators exist
	operators=$(${YQ_CMD} eval '.mirror.operators[].catalog // ""' "$original_yaml")
	if [[ -z "$operators" ]]; then
		return
	fi

	# Loop through each operator by index
	i=0
	while true; do
		# Get the catalog for the current operator
		catalog=$(${YQ_CMD} eval ".mirror.operators[$i].catalog // \"\"" "$original_yaml")
		if [[ -z "$catalog" ]]; then
			break
		fi
		
		
		# Get the number of packages for the current operator
		j=0
		while true; do
			# Get the package name for the current package
			package_name=$(${YQ_CMD} eval ".mirror.operators[$i].packages[$j].name // \"\"" "$original_yaml")
			if [[ -z "$package_name" ]]; then
				break
			fi

			# Convert package name to lowercase
			package_name_lower=$(echo "$package_name" | tr '[:upper:]' '[:lower:]')

			# Skip if the package name matches the postgres
			if [[ "$package_name_lower" == "cloud-native-postgresql" ]]; then
				j=$((j + 1))
				continue
			fi

			# Get the channels for the current package
			channels=$(${YQ_CMD} eval ".mirror.operators[$i].packages[$j].channels // \"\"" "$original_yaml")
			
			# Check if channels exist
			if [[ -z "$channels" ]]; then
				j=$((j + 1))
				continue
			fi
			
			# Extract the last channel from the channels
			last_channel=$(${YQ_CMD} eval ".mirror.operators[$i].packages[$j].channels[-1].name" "$original_yaml")

			# Remove all channels and set only the last channel in a proper format
			${YQ_CMD} eval -i "del(.mirror.operators[$i].packages[$j].channels)" "$new_yaml"
			${YQ_CMD} eval -i ".mirror.operators[$i].packages[$j].channels = [{}]" "$new_yaml"
			${YQ_CMD} eval -i ".mirror.operators[$i].packages[$j].channels[0].name = \"$last_channel\"" "$new_yaml"

			j=$((j + 1))
		done

		i=$((i + 1))
	done
	mv -f $new_yaml $original_yaml
	success "The image-set-config.yaml has been processed and has been updated to have only the latest channels.\n"
}



# Function to display menu with different patterns that can be deployed and collect user input
# Multi select menu
function select_filter_options() {
    while true; do
        info "Select the CP4BA capabilities for which you would like to mirror images for. Press 'Enter' to finalize selections.\n"
        printf "[NOTE] If Business Automation Insights (BAI) is needed for FileNet Content Manager, Operational Decision Manager, Automation Decision Services, Business Automation Workflow, or Workflow Process Service, you must select option 10"
        printf "/n"

        # Display menu with ticks for selected options
        echo "1) Automation Decision Services $(if [[ ${SELECTED_FILTER_OPTIONS[0]} -eq 1 ]]; then echo '✔'; fi)"
        echo "2) Automation Document Processing $(if [[ ${SELECTED_FILTER_OPTIONS[1]} -eq 1 ]]; then echo '✔'; fi)"
        echo "3) Automation Workstream Services  $(if [[ ${SELECTED_FILTER_OPTIONS[2]} -eq 1 ]]; then echo '✔'; fi)"
        echo "4) Business Automation Application  $(if [[ ${SELECTED_FILTER_OPTIONS[3]} -eq 1 ]]; then echo '✔'; fi)"
        echo "5) Business Automation Workflow  $(if [[ ${SELECTED_FILTER_OPTIONS[4]} -eq 1 ]]; then echo '✔'; fi)"
        echo "6) Process Federation Server  $(if [[ ${SELECTED_FILTER_OPTIONS[5]} -eq 1 ]]; then echo '✔'; fi)"
        echo "7) IBM FileNet® Content Manager  $(if [[ ${SELECTED_FILTER_OPTIONS[6]} -eq 1 ]]; then echo '✔'; fi)"
        echo "8) Operational Decision Manager  $(if [[ ${SELECTED_FILTER_OPTIONS[7]} -eq 1 ]]; then echo '✔'; fi)"
        echo "9) Workflow Process Service  $(if [[ ${SELECTED_FILTER_OPTIONS[8]} -eq 1 ]]; then echo '✔'; fi)"
        echo "10) Business Automation Insights standalone  $(if [[ ${SELECTED_FILTER_OPTIONS[9]} -eq 1 ]]; then echo '✔'; fi)"

        # Read user input
        read -p "Enter your choice (1-10) or Enter to finalize: " choice

        # Check if the user presses Enter (no input)
        if [[ -z "$choice" ]]; then
            break
        fi

        # Validate user input (must be between 1 and 10)
        if [[ "$choice" =~ ^[1-9]$|10 ]]; then
            index=$((choice-1))
            SELECTED_FILTER_OPTIONS[$index]=1
        else
            error "Invalid input. Please enter a number between 1-10 or '0' to finalize."
        fi
    done
}

# Function to build the final filter based on selected capabilities
function build_final_filter() {
    IMAGE_MIRROR_FILTER=""
	temp_values=()

    for i in {0..9}; do
        if [[ ${SELECTED_FILTER_OPTIONS[$i]} -eq 1 ]]; then
            case $i in
                0) IMAGE_MIRROR_FILTER+="$AUTOMATION_DECISION_SERVICES," ;;
                1) IMAGE_MIRROR_FILTER+="$AUTOMATION_DOCUMENT_PROCESSING," ;;
                2) IMAGE_MIRROR_FILTER+="$AUTOMATION_WORKSTREAM_SERVICES," ;;
                3) IMAGE_MIRROR_FILTER+="$BUSINESS_AUTOMATION_APPLICATION," ;;
                4) IMAGE_MIRROR_FILTER+="$BUSINESS_AUTOMATION_WORKFLOW," ;;
                5) IMAGE_MIRROR_FILTER+="$PROCESS_FEDERATION_SERVER," ;;
                6) IMAGE_MIRROR_FILTER+="$FILENET_CONTENT_MANAGER," ;;
                7) IMAGE_MIRROR_FILTER+="$OPERATION_DECISION_MANAGER," ;;
                8) IMAGE_MIRROR_FILTER+="$WORKFLOW_PROCESS_SERVICE," ;;
                9) IMAGE_MIRROR_FILTER+="$BUSINESS_AUTOMATION_INSIGHTS_STANDALONE," ;;
            esac
			# Split the selected_str into individual values
            IFS=',' read -r -a values <<< "$IMAGE_MIRROR_FILTER"

            # Add unique values to the temporary array
            for value in "${values[@]}"; do
                # Check if the value already exists in temp_values
                if [[ ! " ${temp_values[@]} " =~ " ${value} " ]]; then
                    temp_values+=("$value")
                fi
            done
        fi
    done

    # Remove trailing comma and display final value
    IMAGE_MIRROR_FILTER=$(IFS=,; echo "${temp_values[*]}")
    echo "Image filter: $IMAGE_MIRROR_FILTER"
}

#function for storing logs
function save_log(){
    local LOG_DIR=$1
    LOG_FILE="$LOG_DIR/$2_$(date +'%Y%m%d%H%M%S').log"
    local debug=1

    if [ $debug -eq 1 ]; then
        if [[ ! -d $LOG_DIR ]]; then
            mkdir -p "$LOG_DIR"
        fi

        # Create a named pipe
        PIPE=$(mktemp -u)
        mkfifo "$PIPE"

        # Tee the output to both the log file and the terminal
        tee "$LOG_FILE" < "$PIPE" &

        # Redirect stdout and stderr to the named pipe
        exec > "$PIPE" 2>&1

        # Remove the named pipe
        rm "$PIPE"
    fi
}

function cleanup_log() {
    # Check if the log file already exists
    if [[ -e $LOG_FILE ]]; then
        # Remove ANSI escape sequences from log file
        sed -E 's/\x1B\[[0-9;]+[A-Za-z]//g' "$LOG_FILE" > "$LOG_FILE.tmp" && mv "$LOG_FILE.tmp" "$LOG_FILE"
    fi
}

# Function to display the next steps
function display_next_steps(){
	step_num=1
	ICSP_CONFIG=$ibm_pak_home/.ibm-pak/data/mirror/$case_name/$case_version/image-content-source-policy.yaml
    info "${YELLOW_TEXT}- [NEXT-STEPS]${RESET_TEXT}"
	info "${YELLOW_TEXT}- Follow the steps below to install the Cloud Pak catalog and operator instances.${RESET_TEXT}"
	echo "  - STEP ${step_num} ${RED_TEXT}(Required)${RESET_TEXT}:${GREEN_TEXT} # Using the oc login command, log in to the Red Hat OpenShift Container Platform cluster where you plan to install the Cloud Pak catalog and operator instances. You can identify your specific oc login by clicking the user drop-down menu in the Red Hat OpenShift Container Platform console, then clicking Copy Login Command${RESET_TEXT}"  && step_num=$((step_num + 1))
	echo "  - STEP ${step_num} ${RED_TEXT}(Required)${RESET_TEXT}:${GREEN_TEXT} # Update the global image pull secret for your Red Hat OpenShift cluster to have authentication credentials in place to pull images from your target registry as specified in the image-content-source-policy.yaml file. For more information, see [https://docs.openshift.com/container-platform/4.12/openshift_images/managing_images/using-image-pull-secrets.html#images-update-global-pull-secret_using-image-pull-secrets]${RESET_TEXT}"  && step_num=$((step_num + 1))
	info "${YELLOW_TEXT}NOTE : If there is an existing ImageContentsourcePolicy named ibm-cp-automation on the cluster, then on running the command, it overwrites the existing mirroring configuration due to which all deployments on the cluster are affected. To keep the existing mirroring configuration of the ImageContentsourcePolicy unchanged, you must update the existing ImageContentsourcePolicy manually with the mirroring configuration that is created in the file that is located at ${ICSP_CONFIG}${RESET_TEXT}"
	echo "  - STEP ${step_num} ${RED_TEXT}(Required)${RESET_TEXT}:${GREEN_TEXT}  Run the following command to create ImageContentsourcePolicy ${RESET_TEXT}# oc apply -f ${ICSP_CONFIG} "  && step_num=$((step_num + 1))
	echo "  - STEP ${step_num} ${RED_TEXT}(Required)${RESET_TEXT}:${GREEN_TEXT}  Verify that the ImageContentsourcePolicy resource is created ${RESET_TEXT}# oc get imageContentSourcePolicy "  && step_num=$((step_num + 1))
	echo "  - STEP ${step_num} ${RED_TEXT}(Required)${RESET_TEXT}:${GREEN_TEXT}  Install the Cloud Pak catalog and operator instances by using the cluster admin script. For more information see [https://www.ibm.com/docs/en/cloud-paks/cp-biz-automation/$CP4BA_RELEASE_BASE?topic=icpcoi-option-1-installing-cloud-pak-catalog-operator-instances-by-using-cluster-admin-script-recommended] ${RESET_TEXT}"  && step_num=$((step_num + 1))

	printf "\n"
	
}

# function to monitor mirroring
function monitor_mirroring() {
    local log_file="$AIRGAP_FOLDER_MIRRORING_LOGS/$case_name-$case_version.txt" 
    local max_attempts=100
    local attempt=0

    while (( attempt < max_attempts )); do
        # Check if the log message "info: Mirroring completed" exists in the log file
        if grep -q "info: Mirroring completed" "$log_file"; then
            success "Mirroring of images for version $case_version of $case_name case is completed!"
            return 0  # End the function successfully
        else
            # Display ongoing progress message if log message isn't found
            echo "Mirroring in process, check $log_file for more details..."
        fi

        # Increment the attempt counter and sleep for 1 minute
        ((attempt++))
        sleep 60
    done

    # If loop completes without finding the message, display a final message
    echo "Continue monitoring the logs at $log_file."
}

# Helper function used to find a file based on a start and end string
function find_file(){
    local start_string="$1"
    local end_string="$2"
    local folder="$3"

    find "$folder" -maxdepth 1 -type f -name "${start_string}*${end_string}" | head -n 1

}

# Function to update metadata files for staging based dev mode i.e devstaging
# Only for scenarios when the images are still in staging repository

function modify_metadata_files(){
    matched_file=$(find_file "ibm-cp-automation" "-airgap-metadata.yaml" "${WORKING_DIRECTORY}/data/cases/$case_name/$case_version")
    echo "Updating the metadata file $matched_file"
    ${SED_COMMAND} 's|icr.io/cpopen|cp.stg.icr.io/cp|g' "$matched_file"

    matched_file=$(find_file "ibm-cp-fncm-case" "-airgap-metadata.yaml" "${WORKING_DIRECTORY}/data/cases/$case_name/$case_version")
    echo "Updating the metadata file $matched_file"
    ${SED_COMMAND} 's|icr.io/cpopen|cp.stg.icr.io/cp|g' "$matched_file"
}


# For https://jsw.ibm.com/browse/DBACLD-207571
# Function to update Image set configfile for staging based dev mode
# IF images are still in staging the image set config file needs to be updated to use staging based catalog sources 
# also we need to do a skopeo copy the staging image to "oci:///root/<catalog-source-name>" and use that image in the image-set-config yaml file
function dev_mode_edit_image_set_config_file() {
    # Step 1: Loop through operators
    local YAML_FILE=$1
    count=$(${YQ_CMD} eval '.mirror.operators | length' "$YAML_FILE")

    i=0
    while [[ $i -lt $count ]]; do
        catalog=$(${YQ_CMD} eval ".mirror.operators[$i].catalog" "$YAML_FILE")
        # For ibm-fncm-catalog or ibm-cp-automation-catalog we need to skopeo copy it and then update the image-set-config yaml
        if echo "$catalog" | grep -qE "ibm-fncm-catalog|ibm-cp-automation-catalog"; then
            new_catalog=$(echo "$catalog" | sed 's|icr.io/cpopen|cp.stg.icr.io/cp|')
            now=$(date +"%Y%m%d%H%M") # this is for a unique image name
            if echo "$new_catalog" | grep -qE "ibm-fncm-catalog"; then
                copied_image="oci:///root/ibm-fncm-catalog$now"
            else
                copied_image="oci:///root/ibm-cp-automation-catalog$now"
            fi
            skopeo copy docker://${new_catalog} $copied_image --all --format v2s2
            
            ${YQ_CMD} eval -i ".mirror.operators[$i].catalog = \"$copied_image\"" "$YAML_FILE"
        fi
        ((i++))
    done

    # Step 2: Loop through additionalImages and update matching names
    img_count=$(${YQ_CMD} eval '.mirror.additionalImages | length' "$YAML_FILE")

    j=0
    while [[ $j -lt $img_count ]]; do
        image=$(${YQ_CMD} eval ".mirror.additionalImages[$j].name" "$YAML_FILE")
        if echo "$image" | grep -qE "ibm-fncm-catalog|ibm-cp-automation-catalog"; then
            new_image=$(echo "$image" | sed 's|icr.io/cpopen|cp.stg.icr.io/cp|')
            ${YQ_CMD} eval -i ".mirror.additionalImages[$j].name = \"$new_image\"" "$YAML_FILE"
        fi
        ((j++))
    done
}




# function that checks if all dev mode related env variables are set
function check_required_dev_env_vars() {
  local missing_vars=()

  for var in "$@"; do
    if [ -z "${!var}" ]; then
      missing_vars+=("$var")
    fi
  done

  if [ ${#missing_vars[@]} -ne 0 ]; then
    error "All required environment variable(s) for internal airgap mirroring have not be set"
    printf "\n"
    echo "Error: The following required environment variable(s) for dev mode are not set:"
    for var in "${missing_vars[@]}"; do
      echo "  - $var"
    done
    env_present=false
  fi
}