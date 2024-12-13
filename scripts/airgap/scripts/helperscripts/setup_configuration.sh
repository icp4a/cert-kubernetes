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
configure_ibm_pak_cli(){
    # Capture the output of `oc ibm-pak config`
    output=$(oc ibm-pak config)

    # Extract the relevant "Repository Config" section
    repo_config=$(echo "$output" | awk '/Repository Config/{flag=1} /Locale Config/{flag=0} flag')

    # Display the extracted section
    info "Displaying the currently configured Repositories"
    echo "$repo_config"

    # Check if the required URL is present
    if ! echo "$repo_config" | grep -q "oci:cp.icr.io/cpopen"; then
        info "oci:cp.icr.io/cpopen is NOT present in the CASE Repo URL."
        info "Configuring oci:cp.icr.io/cpopen with ibm-pak CLI tool...\n"
        if ! output=$(oc ibm-pak config repo 'IBM Cloud-Pak OCI registry' -r oci:cp.icr.io/cpopen --enable); then
            error "Error: Failed to enable the repository 'IBM Cloud-Pak OCI registry'."
            exit 1
        else
            REPO_CONFIGURED="true"
            success "oci:cp.icr.io/cpopen has been configured! Proceeding with next steps..."
            printf "\n"
        fi
    else
        REPO_CONFIGURED="true"
        success "oci:cp.icr.io/cpopen is currently configured! Proceeding with next steps..."
        printf "\n"
    fi
    configure_oc_mirror
}

# Print the different cases and case versions that will be downloaded
print_cases_table() {
    # Use yq to extract the cases list
    #echo ${YQ_CMD}
    names=$(${YQ_CMD} r "$TO_BE_MIRRORED_FILE" 'cases[*].name')
    versions=$(${YQ_CMD} r "$TO_BE_MIRRORED_FILE" 'cases[*].version')


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
}

# Function to configure CASE_VERSION variable which is got from the to-be-mirrored-file
configure_case_version(){
    # Use yq to extract the cases list
    #echo ${YQ_CMD}
    case_names=$(${YQ_CMD} r "$TO_BE_MIRRORED_FILE" 'cases[*].name')
    versions=$(${YQ_CMD} r "$TO_BE_MIRRORED_FILE" 'cases[*].version')
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
    #setting the case name
    case_name=ibm-cp-automation
    export CASE_NAME=$case_name

    configure_case_version
    #configure IBM_PAK
    configure_ibm_pak_home
    export TARGET_REGISTRY=$PRIVATE_REGISTRY_MIRRORING_PATH

    info "List of variables to be used for mirroring process"
    printf "\n"
    mirror_variables=(TO_BE_MIRRORED_FILE IBMPAK_HOME CASE_NAME CASE_VERSION TARGET_REGISTRY REGISTRY_AUTH_FILE)
    # Loop through the array and print the name and value of each variable
    for var in "${mirror_variables[@]}"; do
        value="${!var}"  # Indirect expansion to get the value of the variable
        echo "$var: $value"
    done

}


