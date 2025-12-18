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

# SCRIPT VARIABLES USED
REPO_CONFIGURED="false"
OC_MIRROR_CONFIGURED="false"

# Configure oc mirror with the ibm-pak cli
configure_oc_mirror(){
    if [[ "$REPO_CONFIGURED" == "true" ]]; then
        output=$(oc ibm-pak config mirror-tools --enabled oc-mirror)
        # Run the `oc ibm-pak config mirror-tools --enabled oc-mirror` command
        if ! output=$(oc ibm-pak config mirror-tools --enabled oc-mirror); then
            echo "Error: Failed to enable the oc-mirror tool."
            exit 1
        else
            OC_MIRROR_CONFIGURED="true"
        fi
    fi
}

# Function to configure ibm-pak cli with the repository to mirror from
# Based on the script mode we must configure a different REPO with ibm-pak CLI
configure_ibm_pak_cli(){
    local script_mode=$1
    if [[ "$script_mode" == "devstagingER" || "$script_mode" == "devprodER" ]]; then
        REPO="https://raw.github.ibm.com/IBMPrivateCloud/cloud-pak/master/repo/case"
        REPO_NAME="IBM Cloud-Pak Github Repo"
    else
        REPO="oci:cp.icr.io/cpopen"
        REPO_NAME="IBM Cloud-Pak OCI registry"
    fi
    # Capture the output of `oc ibm-pak config`
    output=$(oc ibm-pak config)

    # Extract the relevant "Repository Config" section
    repo_config=$(echo "$output" | awk '/Repository Config/{flag=1} /Locale Config/{flag=0} flag')

    # Display the extracted section
    info "Displaying the currently configured Repositories"
    printf "\n"
    echo "$repo_config"

    # Check if the required URL is present
    if ! echo "$repo_config" | grep -q "* $REPO"; then
        info "$REPO_NAME is NOT configured with $REPO in the CASE Repo URL."
        info "Configuring $REPO_NAME with ibm-pak CLI tool...\n"
        if ! output=$(oc ibm-pak config repo "$REPO_NAME" -r $REPO --enable); then
            error "Error: Failed to enable the repository '$REPO_NAME'."
            exit 1
        else
            REPO_CONFIGURED="true"
            success "$REPO_NAME has been configured! Proceeding with next steps..."
            printf "\n"
            # Capture the output of `oc ibm-pak config`
            output=$(oc ibm-pak config)
            # Extract the relevant "Repository Config" section
            repo_config=$(echo "$output" | awk '/Repository Config/{flag=1} /Locale Config/{flag=0} flag')

            # Display the extracted section
            info "Displaying the currently configured Repositories"
            printf "\n"
            echo "$repo_config"
        fi
    else
        REPO_CONFIGURED="true"
        success "$REPO_NAME is currently configured! Proceeding with next steps..."
        printf "\n"
    fi
    configure_oc_mirror
}

# Print the different cases and case versions that will be downloaded
print_cases_table() {
    # Use yq to extract the cases list
    #echo ${YQ_CMD}
    names=$(${YQ_CMD} ".cases[].name" "$TO_BE_MIRRORED_FILE")
    versions=$(${YQ_CMD} ".cases[].version" "$TO_BE_MIRRORED_FILE")

    # Check if yq command was successful
    if [ $? -ne 0 ]; then
        echo "Error: Failed to parse YAML file with yq."
        exit 1
    fi

    info "The following CASE files will be downloaded..."
    # Convert names and versions into arrays
    IFS=$'\n' read -r -d '' -a name_array <<< "$names"
    IFS=$'\n' read -r -d '' -a version_array <<< "$versions"

    # Define column widths
    name_width=30
    version_width=15
    # Print the header of the table
    printf "%-${name_width}s %-${version_width}s\n" "Name" "Version"
    printf "%-${name_width}s %-${version_width}s\n" "----" "-------"
    len="${#name_array[@]}"
    if (( ${#version_array[@]} < len )); then
        len="${#version_array[@]}"
    fi

    # Print each case in the table with proper padding, using the shorter array's length
    for (( i=0; i<len; i++ )); do
        # Check if both name and version are non-empty
        if [[ -n "${name_array[$i]}" && -n "${version_array[$i]}" ]]; then
            printf "%-${name_width}s %-${version_width}s\n" "${name_array[$i]}" "${version_array[$i]}"
        fi
    done
    }

# Function to configure the IBMPAK_HOME env variable , default value is always $CUR_DIR/$case_version
configure_ibm_pak_home(){
    # Print message about creating the folder
    info "Creating folder: $CUR_DIR/$case_version for airgap files"

    # Create the /root/2400 directory (using sudo if necessary)
    #mkdir -p /root/2400 # change to root later
    mkdir -p $CUR_DIR/$case_version
    

    # Confirm the folder was created
    if [ -d "$CUR_DIR/$case_version" ]; then
        success "Folder $CUR_DIR/$case_version created successfully."
    else
        error "Failed to create folder $CUR_DIR/$case_version."
        exit
    fi
    ibm_pak_home=$CUR_DIR/$case_version
    export IBMPAK_HOME=$ibm_pak_home
    # THis variable is only used to to tell the customer where all files are downloaded
    WORKING_DIRECTORY=$ibm_pak_home/.ibm-pak
}

# Function to configure CASE_VERSION variable which is got from the to-be-mirrored-file
configure_case_version(){
    # Use yq to extract the cases list
    #echo ${YQ_CMD}
    case_names=$(${YQ_CMD} ".cases[].name" "$TO_BE_MIRRORED_FILE")
    versions=$(${YQ_CMD} ".cases[].version" "$TO_BE_MIRRORED_FILE")
    # Convert names and versions into arrays
    IFS=$'\n' read -r -d '' -a name_array <<< "$case_names"
    IFS=$'\n' read -r -d '' -a version_array <<< "$versions"

    # Loop through the case names array
    #echo $case_name
    printf '\n'
    # Loop through the case names array
    for i in "${!name_array[@]}"; do
        # Trim any leading/trailing whitespace from case names
        current_case=$(echo "${name_array[$i]}" | xargs)
        
        if [[ "$current_case" == "$case_name" ]]; then
            case_version="${version_array[$i]}"
            break  # Exit the loop once we find the match
        fi
    done
    export CASE_VERSION=$case_version
}

# function to create the different env variables used in the mirroring process
configure_environment_variables() {
    local script_mode=$1
    #setting the case name
    case_name=ibm-cp-automation
    export CASE_NAME=$case_name

    configure_case_version
    #configure IBM_PAK
    configure_ibm_pak_home
    export TARGET_REGISTRY=$PRIVATE_REGISTRY_MIRRORING_PATH
    
    # These functions setup configurations and display the cases to be downloaded and other environment variables used
    configure_ibm_pak_cli $script_mode #Set up oc ibm-pak configurations

    info "List of variables to be used for mirroring process"
    printf "\n"
    mirror_variables=(TO_BE_MIRRORED_FILE IBMPAK_HOME CASE_NAME CASE_VERSION TARGET_REGISTRY REGISTRY_AUTH_FILE)
    # Loop through the array and print the name and value of each variable
    for var in "${mirror_variables[@]}"; do
        value="${!var}"  # Indirect expansion to get the value of the variable
        echo "$var: $value"
    done

    printf "\n"
    info " [IMPORTANT] All files generated by the ibm-pak command line tool as a part of the image mirroring process can be found in directory \"$WORKING_DIRECTORY\" .."
    printf "\n"

}
