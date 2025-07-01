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

#helper script to run the different oc mirror commands

# function to download the case files (Step 1)
function download_case_files() {
    local script_mode=$1
    # Prompt for confirmation
    info "The script will start the execution of downloading case files for CP4BA $CASE_VERSION case package"
    read -p "Do you want to proceed? (yes/no) [default: yes]: " response

    # Set default response if empty
    response=$(echo "$response" | tr '[:upper:]' '[:lower:]')  # Convert to lowercase
    if [ -z "$response" ]; then
        response="yes"
    fi

    # Check the response
    if [[ "$response" == "no" || "$response" == "n" ]]; then
        error "Exiting without downloading case files."
        exit 1
    fi

    info "Downloading case files for CP4BA $CASE_VERSION case package ....."
    printf "\n"
    echo "Command executing -> oc ibm-pak get -c file://$TO_BE_MIRRORED_FILE "
    printf "\n"
    if [[ "$script_mode" == "prod" ]]; then
        oc ibm-pak get -c file://$TO_BE_MIRRORED_FILE
    else
        oc ibm-pak get -c file://$TO_BE_MIRRORED_FILE --skip-verify
    fi

    # validating the download of case files
    info "Validating the download of case files..."
    printf "\n"
    #echo "Command executing -> oc ibm-pak list --downloaded "
    printf "\n"
    output=$(oc ibm-pak list --downloaded)

    # Check if the desired version is present in the "Current Version" column
    if echo "$output" | awk 'NR>2 {print $2}' | grep -q "$CASE_VERSION"; then
        success "Case files for version '$CASE_VERSION' have been downloaded successfully"
    else
        error "Cannot find the '$CASE_VERSION' case files downloaded.The below case files are the only case versions that have been downloaded.The script will exit now."
        oc ibm-pak list --downloaded
        exit
    fi
}

#function that creates the image filter if the user wants to mirror images for only specific capability (Step 2)
function create_image_filter(){
    info "The script can mirror images for only selected CP4BA capabalities \n"
    filter_capabalities="no"
    loop_attempts=0
    while true;do
        read -p " Do you want to mirror images from only certain CP4BA capabalities (yes/no) (Default: no) " filter_capabalities
        if [ -z "$filter_capabalities" ]; then
            filter_capabalities="no"
        fi
        filter_capabalities=$(echo "$filter_capabalities" | tr '[:upper:]' '[:lower:]')
        
        case "$filter_capabalities" in
            yes|y)
            break
            ;;
            no|n)
            info "The script will mirror images for all CP4BA capabalities\n"
            break
            ;;
            *)
            
            loop_attempts=$((loop_attempts + 1))
            if [[ $loop_attempts -eq 3 ]]; then
                error '\x1B[1mLimit reached for invalid inputes entered. Exiting ...\n\x1B[0m'
                exit 1
            else
                echo "Invalid option. Please enter Yes or No/n."
            fi
            ;;
        esac
    done
    if [[ "$filter_capabalities" == "yes" ]]; then
        # Call the function to select CP4BA capabalities
        select_filter_options

        # Call the function to build  the final filter
        build_final_filter
    fi
}

#function to generate the mirror manifests (Step 3)
function generate_mirror_manifests(){
    # Prompt for confirmation
    info "The script will start generating mirror manifests for CP4BA $CASE_VERSION case package"
    read -p "Do you want to proceed? (yes/no) [default: yes]: " response
    printf "\n"
    oc ibm-pak config mirror-tools --enabled oc-mirror
    printf "\n"
    # Set default response if empty
    response=$(echo "$response" | tr '[:upper:]' '[:lower:]')  # Convert to lowercase
    if [ -z "$response" ]; then
        response="yes"
    fi
    # Check the response
    if [[ "$response" == "no" || "$response" == "n" ]]; then
        error "Exiting without generating mirror manifests."
        exit 1
    fi

    info "Generating mirror manifests for CP4BA $CASE_VERSION case package ....."
    printf "\n"
    
    if [[ -z "$IMAGE_MIRROR_FILTER" ]]; then
        echo "Command executing -> oc ibm-pak generate mirror-manifests $CASE_NAME $TARGET_REGISTRY --version $CASE_VERSION"
        printf "\n"
        echo "[NOTE]: The mirror manifest generation step can take up to 5 minutes. The script is currently generating mirror manifests and will not display any logs during this time.."
        printf "\n"
        oc ibm-pak generate mirror-manifests $CASE_NAME $TARGET_REGISTRY --version $CASE_VERSION > /dev/null 2>&1
    else
        echo "Command executing -> oc ibm-pak generate mirror-manifests $CASE_NAME $TARGET_REGISTRY --version $CASE_VERSION --filter $IMAGE_MIRROR_FILTER"
        printf "\n"
        oc ibm-pak generate mirror-manifests $CASE_NAME $TARGET_REGISTRY --version $CASE_VERSION --filter $IMAGE_MIRROR_FILTER > /dev/null 2>&1
    fi
    success "The mirror manifest files have been generated successfully\n"
}

#function to process the image set config file (Step 4)
function process_image_set_config_file(){
    local script_mode=$1
    CUR_IMAGE_SET_CONFIG=$ibm_pak_home/.ibm-pak/data/mirror/$case_name/$case_version/image-set-config.yaml
    info "For each package listed in the first columnn of the table below, the script will mirror images corresponding to the channels listed in the second column of the table. \n"
    display_image_set_config_file $CUR_IMAGE_SET_CONFIG
    latest_version="no"
    loop_attempts=0
    while true;do
        info "The script can mirror images for the latest channel for each product."
        printf "\n"
        echo_bold "${YELLOW_TEXT}[WARNING]${RESET_TEXT} Mirroring images from all channels requires large storage space in the private registry.Mirroring from the latest channel is the recommended approach."
        printf "\n"
        read -p " Do you want to mirror images from only the latest channel (yes/no) (Default: yes) " latest_version
        latest_version=$(echo "$latest_version" | tr '[:upper:]' '[:lower:]')  # Convert to lowercase
        if [ -z "$latest_version" ]; then
            latest_version="yes"
        fi
        latest_version=$(echo "$latest_version" | tr '[:upper:]' '[:lower:]')
        case "$latest_version" in
            yes|y)
            info "Updating the image-set-config file - $CUR_IMAGE_SET_CONFIG\n"
            break
            ;;
            no|n)
            info "The script will mirror images from all channels listed\n"
            break
            ;;
            *)
            loop_attempts=$((loop_attempts + 1))
            if [[ $loop_attempts -eq 3 ]]; then
                error '\x1B[1mLimit reached for invalid inputes entered. Exiting ...\n\x1B[0m'
                exit 1
            else
                echo "Invalid option. Please enter Yes or No/n."
            fi
            ;;
        esac
    done
    if [[ "$latest_version" == "yes" ]]; then
        # function that edits the image set config yaml to have only the latest channel images
        edit_image_set_config_file $CUR_IMAGE_SET_CONFIG
        if [[ "$script_mode" == "devstagingER" ]]; then
            dev_mode_edit_image_set_config_file $CUR_IMAGE_SET_CONFIG
        fi
        info "For each package listed in the first columnn of the table below, the script will now mirror images corresponding to the channels listed in the second column of the table. \n"
        # function to display the image set config        
        display_image_set_config_file $CUR_IMAGE_SET_CONFIG
    fi
}



# function that starts the mirroring of images (Step 5)
function mirror_images(){
    # Prompt for confirmation
    info "The script will start mirroring the images for CP4BA $CASE_VERSION case package"
    read -p "Do you want to proceed? (yes/no) [default: yes]: " response

    # Set default response if empty
    response=$(echo "$response" | tr '[:upper:]' '[:lower:]')  # Convert to lowercase
    if [ -z "$response" ]; then
        response="yes"
    fi
    # Check the response
    if [[ "$response" == "no" || "$response" == "n" ]]; then
        error "Exiting without generating mirror manifests."
        exit 1
    fi

    info "If you are running the command on a remote system, you can run the command in the background with the nohup POSIX command so that it does not stop if the user logs out. The following command starts the mirroring process in the background and writes the log to a $case_name-$case_version.txt file."
    #echo " - nohup oc mirror --config $ibm_pak_home/.ibm-pak/data/mirror/$CASE_NAME/$CASE_VERSION/image-set-config.yaml docker://$PRIVATE_REGISTRY_MIRRORING_PATH --dest-skip-tls --max-per-registry=6 > $AIRGAP_FOLDER_MIRRORING_LOGS/$case_name-$case_version.txt 2>&1 &"
    printf "\n"
    read -p "Do you want the script to use nohup to execute the mirroring of images? (yes/no) [default: yes]: " response
    # Set default response if empty
    response=$(echo "$response" | tr '[:upper:]' '[:lower:]')  # Convert to lowercase
    if [ -z "$response" ]; then
        response="yes"
    fi
    # Check the response
    # if no we mirror without nohup
    if [[ "$response" == "no" || "$response" == "n" ]]; then
        info "Starting with the image mirroring process ... "
        printf "\n"
        echo "Command executing -> oc mirror --config $ibm_pak_home/.ibm-pak/data/mirror/$CASE_NAME/$CASE_VERSION/image-set-config.yaml docker://$PRIVATE_REGISTRY_MIRRORING_PATH --dest-skip-tls --max-per-registry=6"
        printf "\n"
        oc mirror --config $ibm_pak_home/.ibm-pak/data/mirror/$CASE_NAME/$CASE_VERSION/image-set-config.yaml docker://$PRIVATE_REGISTRY_MIRRORING_PATH --dest-skip-tls --max-per-registry=6
    else
        info "Starting with the image mirroring process ... "
        printf "\n"
        echo "Command executing -> nohup oc mirror --config $ibm_pak_home/.ibm-pak/data/mirror/$CASE_NAME/$CASE_VERSION/image-set-config.yaml docker://$PRIVATE_REGISTRY_MIRRORING_PATH --dest-skip-tls --max-per-registry=6 > $AIRGAP_FOLDER_MIRRORING_LOGS/$case_name-$case_version.txt 2>&1 &"
        printf "\n"
        nohup oc mirror --config $ibm_pak_home/.ibm-pak/data/mirror/$CASE_NAME/$CASE_VERSION/image-set-config.yaml docker://$PRIVATE_REGISTRY_MIRRORING_PATH --dest-skip-tls --max-per-registry=6 > $AIRGAP_FOLDER_MIRRORING_LOGS/$case_name-$case_version.txt 2>&1 &
        monitor_mirroring
    fi
    
}