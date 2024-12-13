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

#set of filters that can be used while mirroring images
AUTOMATION_DECISION_SERVICES="ibmcp4baProd,ibmcp4baADSImages,ibmcp4baBANImages,ibmcp4baBASImages,ibmcp4baAAEImages,ibmEdbStandard"
AUTOMATION_DOCUMENT_PROCESSING="ibmcp4baProd,ibmcp4baADPImages,ibmcp4baFNCMImages,ibmcp4baBANImages,ibmcp4baBASImages,ibmcp4baAAEImages,ibmEdbStandard"
AUTOMATION_WORKSTREAM_SERVICES="ibmcp4baProd,ibmcp4baBAWImages,ibmcp4baPFSImages,ibmcp4baFNCMImages,ibmcp4baBANImages,ibmcp4baBASImages,ibmcp4baAAEImages,ibmEdbStandard"
BUSINESS_AUTOMATION_APPLICATION="ibmcp4baProd,ibmcp4baBASImages,ibmcp4baAAEImages,ibmEdbStandard"
BUSINESS_AUTOMATION_WORKFLOW="ibmcp4baProd,ibmcp4baBAWImages,ibmcp4baFNCMImages,ibmcp4baBANImages,ibmcp4baBASImages,ibmcp4baAAEImages,ibmEdbStandard,ibmcp4baUMSImages"
PROCESS_FEDERATION_SERVER="ibmcp4baProd,ibmcp4baPFSImages,ibmcp4baAAEImages"
FILENET_CONTENT_MANAGER="ibmcp4baProd,ibmcp4baFNCMImages,ibmcp4baBANImages,ibmcp4baAAEImages,ibmEdbStandard"
OPERATION_DECISION_MANAGER="ibmcp4baProd,ibmcp4baODMImages,ibmcp4baBASImages,ibmcp4baAAEImages,ibmEdbStandard"
WORKFLOW_PROCESS_SERVICE="ibmcp4baProd,ibmcp4baAAEImages,ibmcp4baBASImages,ibmcp4baWFPSImages,ibmEdbStandard"
BUSINESS_AUTOMATION_INSIGHTS_STANDALONE="ibmcp4baProd,ibmcp4baBAIImages,ibmEdbStandard"
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
    echo -e "\x1B[1${PREFIX}${MSG}\x1B[0m"
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

base64_encode() {
    local input="$1"
    local encoded=$(echo -n "$input" | base64)
    eval "$2='$encoded'"
}

base64_decode() {
    local input="$1"
    local decoded=$(echo -n "$input" | base64 --decode)
    eval "$2='$decoded'"
}


#function to parse the image-set-config.yaml file
display_image_set_config_file() {
    # Path to your YAML file
    yaml_file=$1
    
    # Extract all package names
    package_names=$(${YQ_CMD} r "$yaml_file" 'mirror.operators[*].packages[*].name')

    # Print the header
	#info "For each package listed in the first columnn of the table below, the script will mirror images corresponding to the channels listed in the second column of the table \n"
    printf "%-30s %-50s\n" "Package" "Channels"
    printf "%-30s %-50s\n" "-------" "-------"
    
    # Iterate over each package name
    while IFS= read -r package_name; do
        # Extract the channels associated with the current package
        channels=$(${YQ_CMD} r "$yaml_file" "mirror.operators[*].packages(name==$package_name).channels[*].name")

        # Print the package name
        printf "%-30s " "$package_name"
        
        # Prepare the channel list to display in the second column
        channel_list=""
        for channel in $channels; do
            channel_list+="$channel, "
        done
        
        # Remove trailing comma and space if channel_list is not empty
        channel_list=${channel_list%, }

        # Print the channels in the second column
        printf "%-50s\n" "$channel_list"
    done <<< "$package_names"
 	printf "\n"

}



#Function to edit the image-set-config.yaml file to keep only the latest channel
edit_image_set_config_file(){
	# Define the original YAML file path and the new output file path
	local original_yaml=$1
	check_file_exists "$original_yaml" || exit 1
	cp -f "$original_yaml" "$AIRGAP_FOLDER/image-set-config-backup.yaml" 
	local new_yaml="$ibm_pak_home/.ibm-pak/data/mirror/$case_name/$case_version/image-set-config-new.yaml"
	#local new_yaml="/Users/varunsriram/Documents/Work/CloudPak/CodeRepos/cert-kubernetes/image-set-config-new.yaml"
	# Copy the original file to the new file
	cp "$original_yaml" "$new_yaml"

	# Check if operators exist
	operators=$(${YQ_CMD} r "$original_yaml" 'mirror.operators[*].catalog')
	if [[ -z "$operators" ]]; then
		#echo "No operators found!"
		return
	fi

	# Loop through each operator by index
	i=0
	while true; do
		# Get the catalog for the current operator
		catalog=$(${YQ_CMD} r "$original_yaml" "mirror.operators[$i].catalog")
		if [[ -z "$catalog" ]]; then
			break
		fi
		
		#echo "Processing operator $i with catalog $catalog"
		
		# Get the number of packages for the current operator
		j=0
		while true; do
			# Get the package name for the current package
			package_name=$(${YQ_CMD} r "$original_yaml" "mirror.operators[$i].packages[$j].name")
			if [[ -z "$package_name" ]]; then
				break
			fi

			# Convert package name to lowercase
			package_name_lower=$(echo "$package_name" | tr '[:upper:]' '[:lower:]')

			# Skip if the package name matches the postgres
			if [[ "$package_name_lower" == "cloud-native-postgresql" ]]; then
				#echo "Skipping package $package_name"
				j=$((j + 1))
				continue
			fi
			
			#echo "Processing package $package_name in operator $i"

			# Get the channels for the current package
			channels=$(${YQ_CMD} r "$original_yaml" "mirror.operators[$i].packages[$j].channels")
			
			# Check if channels exist
			if [[ -z "$channels" ]]; then
				#echo "No channels found for package $package_name in operator $i"
				continue
			fi
			
			# Extract the last channel from the channels
			last_channel=$(${YQ_CMD} r "$original_yaml" "mirror.operators[$i].packages[$j].channels[-1].name")
			#echo "Last channel for package $package_name: $last_channel"

			# Remove all channels and set only the last channel in a proper format
			${YQ_CMD} w -i "$new_yaml" "mirror.operators[$i].packages[$j].channels.name" ""
			${YQ_CMD} w -i "$new_yaml" "mirror.operators[$i].packages[$j].channels[0].name" "$last_channel"
			#echo "Updated package $package_name with last channel: $last_channel"

			j=$((j + 1))
		done

		i=$((i + 1))
	done
	mv -f $new_yaml $original_yaml
	success "The image-set-config.yaml has been processed and has been updated to have only the latest channels.\n"


}



# Function to display menu and collect user input
select_filter_options() {
    while true; do
        info "Select the CP4BA capabilities for which you would like to mirror images for. Press 'Enter' to finalize selections."
        
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
build_final_filter() {
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
	info "    NOTE : If there is an existing ImageContentsourcePolicy named ibm-cp-automation on the cluster, then on running the command, it overwrites the existing mirroring configuration due to which all deployments on the cluster are affected. To keep the existing mirroring configuration of the ImageContentsourcePolicy unchanged, you must update the existing ImageContentsourcePolicy manually with the mirroring configuration that is created in the file that is located at ${ICSP_CONFIG}"
	echo "  - STEP ${step_num} ${RED_TEXT}(Required)${RESET_TEXT}:${GREEN_TEXT}  Run the following command to create ImageContentsourcePolicy ${RESET_TEXT}# oc apply -f ${ICSP_CONFIG} "  && step_num=$((step_num + 1))
	echo "  - STEP ${step_num} ${RED_TEXT}(Required)${RESET_TEXT}:${GREEN_TEXT}  Verify that the ImageContentsourcePolicy resource is created ${RESET_TEXT}# oc get imageContentSourcePolicy "  && step_num=$((step_num + 1))
	echo "  - STEP ${step_num} ${RED_TEXT}(Required)${RESET_TEXT}:${GREEN_TEXT}  Install the Cloud Pak catalog and operator instances by using the cluster admin script. For more information see [https://www.ibm.com/docs/en/cloud-paks/cp-biz-automation/24.0.1?topic=icpcoi-option-1-installing-cloud-pak-catalog-operator-instances-by-using-cluster-admin-script-recommended] ${RESET_TEXT}"  && step_num=$((step_num + 1))

	printf "\n"
	
}

# function to monitor mirroring
monitor_mirroring() {
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