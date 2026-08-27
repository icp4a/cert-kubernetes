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

# This helper script is used for precheck validation of the packages required for cp4a-airgap-mirroring-images script

# Functio to validate the tools required for airgap mirroring
function validate_tools() {
    # Function to compare version numbers (major.minor.patch)
    version_ge() { 
        # Normalize version strings to have three parts (major.minor.patch)
        local v1=$(echo "$1" | awk -F. '{ printf("%d%03d%03d\n", $1,$2,$3); }')
        local v2=$(echo "$2" | awk -F. '{ printf("%d%03d%03d\n", $1,$2,$3); }')
        [[ "$v1" -ge "$v2" ]]
    }

    # Tool validation variables
    local validation_status=0
    local tools=(
        "1. oc OCP CLI tool:4.12.0"
        "2. Podman:Any"
        # Will update this to 1.13.0
        "3. IBM Catalog Management Plug-in:1.13.0"
        "4. oc mirror:4.14.0"
    )
    local current_versions=()

    info "The following tools will be validated:"
    for tool in "${tools[@]}"; do
        IFS=":" read -r tool_name required_version <<< "$tool"
        echo "$tool_name (required version: $required_version)"
    done
    echo

    # Validate oc OCP CLI tool
    info "Validating oc OCP CLI tool..."
    if command -v oc &> /dev/null; then
        oc_version=$(oc version --client | grep 'Client Version' | awk '{print $3}' | cut -d '-' -f 1)
        if version_ge "$oc_version" "4.12.0"; then
            success "oc OCP CLI tool version $oc_version is acceptable."
            current_versions+=("oc OCP CLI tool:$oc_version")
        else
            error "oc OCP CLI tool version $oc_version is installed, but version 4.12.0 or later is required."
            current_versions+=("oc OCP CLI tool:$oc_version (update needed)")
            validation_status=1
        fi
    else
        error "oc OCP CLI tool is not installed."
        current_versions+=("oc OCP CLI tool:Not installed (install needed)")
        validation_status=1
    fi

    # Validate Podman
    info "Validating Podman..."
    if command -v podman &> /dev/null; then
        success "Podman is installed."
        PODMAN_FOUND="YES"
        current_versions+=("Podman:Installed")
    else
        error "Podman is not installed."
        current_versions+=("Podman:Not installed (install needed)")
        validation_status=1
    fi

    # Validate IBM Catalog Management Plug-in
    info "Validating IBM Catalog Management Plug-in..."
    if command -v oc &> /dev/null; then
        plugin_version=$(oc ibm-pak --version | sed 's/^v//')
        # Will update this to 1.13.0
        #plugin_version="1.13.0"
        if version_ge "$plugin_version" "1.13.0"; then
            success "IBM Catalog Management Plug-in version $plugin_version is acceptable."
            current_versions+=("IBM Catalog Management Plug-in:$plugin_version")
        else
            error "IBM Catalog Management Plug-in version $plugin_version is installed, but version 1.13.0 or later is required."
            current_versions+=("IBM Catalog Management Plug-in:$plugin_version (update needed)")
            validation_status=1
        fi
    else
        error "oc CLI is not installed or the IBM Catalog Management Plug-in is not available."
        current_versions+=("IBM Catalog Management Plug-in:Not available (install needed)")
        validation_status=1
    fi

    # Validate oc mirror
    info "Validating oc mirror..."
    if command -v oc-mirror &> /dev/null; then
        oc_mirror_version=$(oc mirror version --output=yaml 2>/dev/null | grep 'gitVersion' | awk '{print $2}' | cut -d '-' -f 1)
        #oc_mirror_version="4.14.0"
        if [[ -z "$oc_mirror_version" ]]; then
            error "oc mirror is installed but its version could not be determined (binary may be incompatible with this platform)."
            current_versions+=("oc mirror:Unknown (check binary)")
            validation_status=1
            export OC_MIRROR_VERSION_FLAG=""
        elif version_ge "$oc_mirror_version" "4.14.0"; then
            success "oc mirror version $oc_mirror_version is acceptable."
            current_versions+=("oc mirror:$oc_mirror_version")

            # Determine the oc mirror version flag:
            #   < 4.18  -> no flag (--v1/--v2 flags do not exist yet)
            #   >= 4.18 -> --v1  (flag is optional from 4.18, mandatory from 4.21; v1 preserves existing workflow behaviour)
            if version_ge "$oc_mirror_version" "4.18.0"; then
                OC_MIRROR_VERSION_FLAG="--v1"
                info "oc mirror >= 4.18 detected: will use '--v1' flag during image mirroring."
            else
                OC_MIRROR_VERSION_FLAG=""
            fi
            export OC_MIRROR_VERSION_FLAG
        else
            error "oc mirror version $oc_mirror_version is installed, but version 4.14.x is required."
            current_versions+=("oc mirror:$oc_mirror_version (update needed)")
            validation_status=1
            export OC_MIRROR_VERSION_FLAG=""
        fi
    else
        error "oc mirror is not installed."
        current_versions+=("oc mirror:Not installed (install needed)")
        validation_status=1
        export OC_MIRROR_VERSION_FLAG=""
    fi

    echo
    echo_bold "Tools Validation Summary:"
    echo "------------------------------------------------------------------------"
    printf "%-35s | %-15s | %-20s\n" "Tool" "Required Version" "Current Version"
    echo "------------------------------------------------------------------------"
    for i in "${!tools[@]}"; do
        IFS=":" read -r tool_name required_version <<< "${tools[$i]}"
        printf "%-35s | %-15s | %-20s\n" "$tool_name" "$required_version" "${current_versions[$i]}"
    done
    echo "-------------------------------------------------------------------------"
    echo
    if [ "$validation_status" -eq 0 ]; then
        success "All required tools are installed with the correct versions."
    else
        error "Some tools need updates or installation. Please check the summary above."
        #return 1
    fi
    return $validation_status
}