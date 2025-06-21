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

# This helper script is used for gathering inputs needed to run the cp4a-airgap-mirroring-images script
# The script either processes the property file or asks for the user to input values

DOCKER_REG_SERVER="cp.icr.io"
ENTITLEMENT_KEY=""
COLLECT_ENTITLEMENT_KEY_DETAILS="false"
COLLECT_REGISTRY_DETAILS="false"
PRIVATE_REGISTRY_HOST=""
PRIVATE_REGISTRY_USERNAME=""
PRIVATE_REGISTRY_PASSWORD=""
PRIVATE_REGISTRY_SERVER=""
PRIVATE_REGISTRY_MIRRORING_PATH=$PRIVATE_REGISTRY_HOST
ENTITLEMENT_KEY_VALIDATION=""
PRIVATE_REGISTRY_VALIDATION=""
PRIVATE_REGISTRY_IMAGE_STORAGE_PATH=""
CONFIG_FILE_PRESENT="false"


# Function to read and process the .property file
process_config_file() {
    CONFIG_FILE=$1
    if [ -f "$CONFIG_FILE" ]; then
        echo "Config file found: $CONFIG_FILE"
        ENTITLEMENT_KEY=$(prop_airgap_mirroring_file  "$CONFIG_FILE" ENTITLEMENT_KEY)
        PRIVATE_REGISTRY_HOST=$(prop_airgap_mirroring_file  "$CONFIG_FILE" PRIVATE_REGISTRY_HOST)
        PRIVATE_REGISTRY_PORT=$(prop_airgap_mirroring_file  "$CONFIG_FILE" PRIVATE_REGISTRY_PORT)
        PRIVATE_REGISTRY_USERNAME=$(prop_airgap_mirroring_file  "$CONFIG_FILE" PRIVATE_REGISTRY_USERNAME)
        PRIVATE_REGISTRY_PASSWORD=$(prop_airgap_mirroring_file  "$CONFIG_FILE" PRIVATE_REGISTRY_PASSWORD)
        PRIVATE_REGISTRY_IMAGE_STORAGE_PATH=$(prop_airgap_mirroring_file  "$CONFIG_FILE" PRIVATE_REGISTRY_IMAGE_STORAGE_PATH)
        PRIVATE_REGISTRY_SERVER="${PRIVATE_REGISTRY_HOST}:${PRIVATE_REGISTRY_PORT}"
        # If the port is not a standard port then we need to use it in the mirroring path
        if [[ "$PRIVATE_REGISTRY_PORT" != "443" && "$PRIVATE_REGISTRY_PORT" != "80" ]]; then
            if [[ "$PRIVATE_REGISTRY_IMAGE_STORAGE_PATH" == "" ]]; then
                PRIVATE_REGISTRY_MIRRORING_PATH=$PRIVATE_REGISTRY_SERVER
            else
                PRIVATE_REGISTRY_IMAGE_STORAGE_PATH="${PRIVATE_REGISTRY_IMAGE_STORAGE_PATH#/}"
                PRIVATE_REGISTRY_MIRRORING_PATH=$PRIVATE_REGISTRY_SERVER/$PRIVATE_REGISTRY_IMAGE_STORAGE_PATH
            fi
        else
            if [[ "$PRIVATE_REGISTRY_IMAGE_STORAGE_PATH" == "" ]]; then
                PRIVATE_REGISTRY_MIRRORING_PATH=$PRIVATE_REGISTRY_HOST
            else
                PRIVATE_REGISTRY_IMAGE_STORAGE_PATH="${PRIVATE_REGISTRY_IMAGE_STORAGE_PATH#/}"
                PRIVATE_REGISTRY_MIRRORING_PATH=$PRIVATE_REGISTRY_HOST/$PRIVATE_REGISTRY_IMAGE_STORAGE_PATH
            fi
        fi
        CONFIG_FILE_PRESENT="true"
        #TEMP_FILE=$(mktemp) # only for dev purposes
        #debug_summary #only for dev purposes
    else
        echo "Config file $CONFIG_FILE not found."
        exit 1
    fi
    # Setting the registry auth file
    export XDG_RUNTIME_DIR=/run/user/${UID}
    export REGISTRY_AUTH_FILE=$XDG_RUNTIME_DIR/containers/auth.json
    #validate entitlement key
    validate_entitlement_key
    validate_private_registry_details

}
# Function to gather the IBM entitlement key
collect_entitlement_key(){
    ATTEMPTS=0
    while true; do
        printf "\x1B[1mEnter your Entitlement Registry key: \x1B[0m"
        read -rsp ""  ENTITLEMENT_KEY
        if [[ "$ENTITLEMENT_KEY" == "" ]]; then
            error "Entitlement Registry key can't be empty. Please try again."
            ATTEMPTS=$((ATTEMPTS + 1))
            if [[ $ATTEMPTS -eq 3 ]]; then
                error '\x1B[1mEnter a valid Entitlement Registry key. Exiting ...\n\x1B[0m'
                exit 1
            fi
        else
            printf "\n"
            break
        fi
    done
}
# Function to validate the IBM entitlement key
validate_entitlement_key(){
    #validating the entitlement key
    if  [[ $ENTITLEMENT_KEY == iamapikey:* ]] ;then
        DOCKER_REG_USER="iamapikey"
        DOCKER_REG_KEY="${ENTITLEMENT_KEY#*:}"
    else
        DOCKER_REG_USER="cp"
        DOCKER_REG_KEY=$ENTITLEMENT_KEY
    fi
    while [[ $ENTITLEMENT_KEY_VALIDATION == '' ]]
    do
        printf "\n"
        info "\x1B[1mValidating the Entitlement Registry key...\n\x1B[0m"
        if [[ ("$machine" == "Mac" && $PODMAN_FOUND == "No") ]]; then
            cli_command="podman"
        else
            cli_command="podman"
        fi
        ATTEMPTS=0
        if podman login -u "$DOCKER_REG_USER" -p "$DOCKER_REG_KEY" "$DOCKER_REG_SERVER"; then
            success 'Entitlement Registry key is valid.\n'
            ENTITLEMENT_KEY_VALIDATION="true"
        else
            error '\x1B[1;31mThe Entitlement Registry key validation failed. Try again...\n\x1B[0m'
            ATTEMPTS=$((ATTEMPTS + 1))
            if [[ $ATTEMPTS -eq 3 || "$CONFIG_FILE_PRESENT" == "true" ]]; then
                error '\x1B[1mEnter a valid Entitlement Registry key. Exiting ...\n\x1B[0m'
                exit 1
            fi
            ENTITLEMENT_KEY=''
            ENTITLEMENT_KEY_VALIDATION="false"
        fi
    done
    if [[ "$ENTITLEMENT_KEY_VALIDATION" == "true" ]]; then
        printf "\n"
        break
    fi
}

# Function to gather and validate the IBM entitlement key
process_entitlement_key() {
    VALIDATION_ATTEMPTS=0
    while true; do
        # Prompt for entitlement key
        while true; do
            printf "\x1B[1;31mFollow the instructions on how to get your Entitlement Key: \n\x1B[0m"
            printf "\x1B[1;31mhttps://www.ibm.com/docs/en/cloud-paks/cp-biz-automation/$CP4BA_RELEASE_BASE?topic=deployment-getting-access-images-from-public-entitled-registry\n\x1B[0m"
            read -p "Do you have an entitlement key? (yes/no): " has_key
            has_key=$(echo "$has_key" | tr '[:upper:]' '[:lower:]')
            case "$has_key" in
                yes|y)
                COLLECT_ENTITLEMENT_KEY_DETAILS="true"
                echo  # Newline after password input
                break
                ;;
                no|n)
                echo "An entitlement key is required. Exiting."
                COLLECT_ENTITLEMENT_KEY_DETAILS="false"
                exit 1
                ;;
                *)
                echo "Invalid option. Please enter YES or no/n/NO/N."
                COLLECT_ENTITLEMENT_KEY_DETAILS="false"
                ;;
            esac
            if [[ "$COLLECT_ENTITLEMENT_KEY_DETAILS" == "true" ]]; then
                break
            fi
        done
        collect_entitlement_key
        validate_entitlement_key
        if [[ "$ENTITLEMENT_KEY_VALIDATION" == "true" ]]; then
            break
        else
            VALIDATION_ATTEMPTS=$((VALIDATION_ATTEMPTS + 1))
        fi
        if [[ $VALIDATION_ATTEMPTS -eq 3 ]]; then
            error '\x1B[1mLimit reached for validating the private registry details entered. Exiting ...\n\x1B[0m'
            exit 1
        fi
    done
}

# Function to collect private registry hostname
collect_private_registry_hostname(){
    ATTEMPTS=0
    while true; do
        printf "\x1B[1mEnter the private registry hostname: \x1B[0m"
        read -r  PRIVATE_REGISTRY_HOST
        if [[ "$PRIVATE_REGISTRY_HOST" == "" ]]; then
            error "Private registry hostname can't be empty. Please try again."
            ATTEMPTS=$((ATTEMPTS + 1))
            if [[ $ATTEMPTS -eq 3 ]]; then
                error '\x1B[1mEnter a valid Private registry. Exiting ...\n\x1B[0m'
                exit 1
            fi
        else
            printf "\n"
            break
        fi
    done
}

# Function to collect private registry port
collect_private_registry_port(){
    ATTEMPTS=0
    while true; do
        printf "\x1B[1mEnter the private registry port number: \x1B[0m"
        read -r PRIVATE_REGISTRY_PORT
        if [[ "$PRIVATE_REGISTRY_PORT" == "" ]]; then
            error "Private registry port can't be empty. Please try again."
            ATTEMPTS=$((ATTEMPTS + 1))
        fi
        # Check if port contains only digits (integers)
        if ! echo "$PRIVATE_REGISTRY_PORT" | grep -qE '^[0-9]+$'; then
            error "Port is invalid. It must contain only integers."
            ATTEMPTS=$((ATTEMPTS + 1))
            PRIVATE_REGISTRY_PORT=""
        else
            printf "\n"
            break
        fi
        if [[ $ATTEMPTS -eq 3 ]]; then
            error '\x1B[1mEnter a valid Private registry port. Exiting ...\n\x1B[0m'
            exit 1
        fi
    done
}

# Function to collect private registry username
collect_private_registry_username(){
    ATTEMPTS=0
    while true; do
        printf "\x1B[1mEnter the private registry username: \x1B[0m"
        read -r PRIVATE_REGISTRY_USERNAME
        if [[ "$PRIVATE_REGISTRY_USERNAME" == "" ]]; then
            error "Private registry username can't be empty. Please try again."
            ATTEMPTS=$((ATTEMPTS + 1))
            if [[ $ATTEMPTS -eq 3 ]]; then
                error '\x1B[1mEnter a valid Private registry username. Exiting ...\n\x1B[0m'
                exit 1
            fi
        else
            printf "\n"
            break
        fi
    done
}

# Function to collect private registry password
collect_private_registry_password(){
    ATTEMPTS=0
    while true; do
        printf "\x1B[1mEnter the private registry password: \x1B[0m"
        read -rsp "" PRIVATE_REGISTRY_PASSWORD
        if [[ "$PRIVATE_REGISTRY_PASSWORD" == "" ]]; then
            error "Private registry password can't be empty. Please try again."
            ATTEMPTS=$((ATTEMPTS + 1))
            if [[ $ATTEMPTS -eq 3 ]]; then
                error '\x1B[1mEnter a valid Private registry password. Exiting ...\n\x1B[0m'
                exit 1
            fi
        else
            printf "\n"
            break
        fi
    done
}

#Function to validate the private registry details
validate_private_registry_details(){
    #Validating the private registry details
    info "Validating Private registry credentials...\n"
    if podman login "$PRIVATE_REGISTRY_SERVER" -u "$PRIVATE_REGISTRY_USERNAME" -p "$PRIVATE_REGISTRY_PASSWORD" --tls-verify=false; then
        success 'Successfully Authenticated with Private Registry...\n'
        PRIVATE_REGISTRY_VALIDATION="true"
    else
        PRIVATE_REGISTRY_VALIDATION="false"
        error '\x1B[1;31mLogin failed...\n\x1B[0m'
        if [[ "$CONFIG_FILE_PRESENT" == "true" ]]; then
            error "\x1B[1;31mPrivate registry credentials could not be authenticated.\x1B[0m"
            exit 1
        fi
        error "\x1B[1;31mPrivate registry credentials could not be authenticated. Please try again.\x1B[0m"
    fi
}

# Main function to gather and validate private registry
process_private_registry(){
    # Prompt for entitlement key
    VALIDATION_ATTEMPTS=0
    while true; do
        while true; do
            printf "\x1B[1;31mA private image registry must be used to store all images used in an offline (Airgap) deployment. \n\x1B[0m"
            printf "\x1B[1;31mhttps://www.ibm.com/docs/en/cloud-paks/cp-biz-automation/$CP4BA_RELEASE_BASE?topic=deployment-setting-up-private-registry\n\x1B[0m"
            read -p "Do you have access to a private registry where you can store images? (yes/no): " has_key
            has_key=$(echo "$has_key" | tr '[:upper:]' '[:lower:]')
            case "$has_key" in
                yes|y)
                COLLECT_REGISTRY_DETAILS="true"
                break
                ;;
                no|n)
                info "A Private Registry is required to store images.\n Configure a Private Registry and re-run the script\n"
                COLLECT_REGISTRY_DETAILS="false"
                exit 1
                ;;
                *)
                echo "Invalid option. Please enter YES or no/n/NO/N."
                ;;
            esac
            if [[ "$COLLECT_REGISTRY_DETAILS" == "true" ]]; then
                break
            fi
        done
        collect_private_registry_hostname
        collect_private_registry_port
        collect_private_registry_username
        collect_private_registry_password
        PRIVATE_REGISTRY_SERVER="${PRIVATE_REGISTRY_HOST}:${PRIVATE_REGISTRY_PORT}"
        validate_private_registry_details
        if [[ "$PRIVATE_REGISTRY_VALIDATION" == "true" ]]; then
            break
        else
            VALIDATION_ATTEMPTS=$((VALIDATION_ATTEMPTS + 1))
        fi
        if [[ $VALIDATION_ATTEMPTS -eq 3 ]]; then
            error '\x1B[1mLimit reached for validating the private registry details entered. Exiting ...\n\x1B[0m'
            exit 1
        fi
    done
    process_image_storage_location

}

# function to collect the image storage location path from the user
collect_private_image_storage_location(){
    ATTEMPTS=0
    while true; do
        printf "\x1B[1mPlease enter the registry location (it will be appended after the hostname followed by '/'): \x1B[0m"
        read -r  PRIVATE_REGISTRY_IMAGE_STORAGE_PATH
        if [[ "$PRIVATE_REGISTRY_IMAGE_STORAGE_PATH" == "" ]]; then
            info "Images will be mirrored to: \"$PRIVATE_REGISTRY_HOST\" "
            PRIVATE_REGISTRY_IMAGE_STORAGE_VALIDATION="true"
            # If the port is not a standard port then we need to use it in the mirroring path
            if [[ "$PRIVATE_REGISTRY_PORT" != "443" && "$PRIVATE_REGISTRY_PORT" != "80" ]]; then
                PRIVATE_REGISTRY_MIRRORING_PATH=$PRIVATE_REGISTRY_SERVER
            else
                PRIVATE_REGISTRY_MIRRORING_PATH=$PRIVATE_REGISTRY_HOST
            fi
            break
        else
            PRIVATE_REGISTRY_IMAGE_STORAGE_PATH="${PRIVATE_REGISTRY_IMAGE_STORAGE_PATH#/}"
            printf "\n"
            # Validate the input: Check if it's a valid file path addition (no spaces and contains alphanumeric or special characters)
            if [[ "$PRIVATE_REGISTRY_IMAGE_STORAGE_PATH" =~ ^[a-zA-Z0-9._/-]+$ ]]; then
                echo "Registry location is valid and will be appended after the hostname."
                info "Images will be mirrored to: $PRIVATE_REGISTRY_HOST/$PRIVATE_REGISTRY_IMAGE_STORAGE_PATH "
                PRIVATE_REGISTRY_IMAGE_STORAGE_VALIDATION="true"
                # If the port is not a standard port then we need to use it in the mirroring path
                if [[ "$PRIVATE_REGISTRY_PORT" != "443" && "$PRIVATE_REGISTRY_PORT" != "80" ]]; then
                    PRIVATE_REGISTRY_MIRRORING_PATH=$PRIVATE_REGISTRY_SERVER/$PRIVATE_REGISTRY_IMAGE_STORAGE_PATH
                else
                    PRIVATE_REGISTRY_MIRRORING_PATH=$PRIVATE_REGISTRY_HOST/$PRIVATE_REGISTRY_IMAGE_STORAGE_PATH
                fi
                break
            else
                echo "Invalid registry location. Please try again. Only alphanumeric characters, '.', '_', '-' and '/' are allowed."
                PRIVATE_REGISTRY_IMAGE_STORAGE_VALIDATION="false"
                ATTEMPTS=$((ATTEMPTS + 1))
                if [[ $ATTEMPTS -eq 3 ]]; then
                    error '\x1B[1mEnter a valid Private registry location. Exiting ...\n\x1B[0m'
                    exit 1
                fi
            fi
        fi
    done
}

# function to process the image storage location path
process_image_storage_location(){
    # Prompt for entitlement key
    VALIDATION_ATTEMPTS=0
    while true; do
        while true; do
            printf "\x1B[1;31m The images can be mirrored to a specific location in the private registry. \n\x1B[0m"
            printf "\x1B[1;31mhttps://www.ibm.com/docs/en/cloud-paks/cp-biz-automation/$CP4BA_RELEASE_BASE?topic=deployment-mirroring-catalogs-private-registry-using-oc-mirror\n\x1B[0m"
            read -p "Do you wish to mirror images access to a specific location in the private registry.? (yes/no) (default no): " has_key
            has_key=$(echo "$has_key" | tr '[:upper:]' '[:lower:]')
            case "$has_key" in
                yes|y)
                CUSTOM_IMAGE_STORAGE_PATH="true"
                break
                ;;
                no|n)
                info "A Private Registry is required to store images.\n Configure a Private Registry and re-run the script\n"
                CUSTOM_IMAGE_STORAGE_PATH="false"
                break
                ;;
                *)
                echo "Invalid option. Please enter YES or no/n/NO/N."
                ;;
            esac
        done
        if [[ "$CUSTOM_IMAGE_STORAGE_PATH" == "false" ]]; then
            break
        fi
        collect_private_image_storage_location
        if [[ "$PRIVATE_REGISTRY_IMAGE_STORAGE_VALIDATION" == "true" ]]; then
            break
        else
            VALIDATION_ATTEMPTS=$((VALIDATION_ATTEMPTS + 1))
        fi
        if [[ $VALIDATION_ATTEMPTS -eq 3 ]]; then
            error '\x1B[1mLimit reached for validating the private registry image storage path entered. Exiting ...\n\x1B[0m'
            exit 1
        fi

    done

}

# dev function to show the summary of values entered
debug_summary(){
	echo "ENTITLEMENT_KEY=*****" >> "$TEMP_FILE"
	echo "PRIVATE_REGISTRY_SERVER=$PRIVATE_REGISTRY_SERVER" >> "$TEMP_FILE"
	echo "PRIVATE_REGISTRY_USERNAME=$PRIVATE_REGISTRY_USERNAME" >> "$TEMP_FILE"
	echo "PRIVATE_REGISTRY_PASSWORD=*****" >> "$TEMP_FILE"
	echo "ENTITLEMENT_KEY_VALIDATION=$ENTITLEMENT_KEY_VALIDATION" >> "$TEMP_FILE"
	echo "PRIVATE_REGISTRY_VALIDATION=$PRIVATE_REGISTRY_VALIDATION" >> "$TEMP_FILE"
    echo "PRIVATE_REGISTRY_IMAGE_STORAGE_PATH=$PRIVATE_REGISTRY_MIRRORING_PATH" >> "$TEMP_FILE"
    echo "PRIVATE_REGISTRY_IMAGE_STORAGE_VALIDATION=$PRIVATE_REGISTRY_IMAGE_STORAGE_VALIDATION" >> "$TEMP_FILE"
	# Display the summary table
	echo "Summary of processed values:"
	echo "---------------------------"
	while IFS='=' read -r key value; do
	printf "%-20s : %s\n" "$key" "$value"
	done < "$TEMP_FILE"
	echo "---------------------------"

	# Clean up temporary file
	rm "$TEMP_FILE"
}

# dev function to show the summary of values entered
print_validation_summary(){
    echo
    echo_bold "Credentials Validation Summary:"
    echo "---------------------------------------------------------------------"
    printf "%-35s | %-15s\n" "Credential" "Valid Credentials"
    echo "---------------------------------------------------------------------"
    printf "%-35s | %-15s\n" "Entitlement Key Credentials" "$ENTITLEMENT_KEY_VALIDATION"
    printf "%-35s | %-15s\n" "Private Registry Credentials" "$PRIVATE_REGISTRY_VALIDATION"
    echo "----------------------------------------------------------------------"
    echo
}


# Main function that performs the collection of user inputs needed for entitlement key and private registry validation
prompt_user_input() {
    echo "Config file not provided or not found. Prompting for user input."
    TEMP_FILE=$(mktemp)
    export XDG_RUNTIME_DIR=/run/user/${UID}
    export REGISTRY_AUTH_FILE=$XDG_RUNTIME_DIR/containers/auth.json
    # gather and validate entitlement key
    process_entitlement_key
    clear
    # gather and validate private registry
    process_private_registry
    clear
    #debug_summary # dev only function to print summary
    #print_validation_summary # dev only function to print summary
}