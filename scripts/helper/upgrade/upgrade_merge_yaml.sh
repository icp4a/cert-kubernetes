#!/bin/bash
# set -x
###############################################################################
#
# LICENSED MATERIALS - PROPERTY OF IBM
#
# (C) COPYRIGHT IBM CORP. 2023. ALL RIGHTS RESERVED.
#
# US GOVERNMENT USERS RESTRICTED RIGHTS - USE, DUPLICATION OR
# DISCLOSURE RESTRICTED BY GSA ADP SCHEDULE CONTRACT WITH IBM CORP.
#
###############################################################################
CUR_DIR=$(dirname "$0")
# Directory for upgrade deployment for CP4BA multiple deployment
UPGRADE_DEPLOYMENT_FOLDER=${CUR_DIR}/cp4ba-upgrade/project/$1
UPGRADE_DEPLOYMENT_PROPERTY_FILE=${UPGRADE_DEPLOYMENT_FOLDER}/cp4ba_upgrade.property

UPGRADE_DEPLOYMENT_CR=${UPGRADE_DEPLOYMENT_FOLDER}/custom_resource
UPGRADE_DEPLOYMENT_CR_BAK=${UPGRADE_DEPLOYMENT_CR}/backup

UPGRADE_DEPLOYMENT_CONTENT_CR=${UPGRADE_DEPLOYMENT_CR}/content.yaml
UPGRADE_DEPLOYMENT_CONTENT_CR_TMP=${UPGRADE_DEPLOYMENT_CR}/.content_tmp.yaml
UPGRADE_DEPLOYMENT_CONTENT_CR_BAK=${UPGRADE_DEPLOYMENT_CR_BAK}/content_cr_backup.yaml

UPGRADE_DEPLOYMENT_ICP4ACLUSTER_CR=${UPGRADE_DEPLOYMENT_CR}/icp4acluster.yaml
UPGRADE_DEPLOYMENT_ICP4ACLUSTER_CR_TMP=${UPGRADE_DEPLOYMENT_CR}/.icp4acluster_tmp.yaml
UPGRADE_DEPLOYMENT_ICP4ACLUSTER_CR_BAK=${UPGRADE_DEPLOYMENT_CR_BAK}/icp4acluster_cr_backup.yaml

UPGRADE_DEPLOYMENT_WFPS_CR=${UPGRADE_DEPLOYMENT_CR}/wfps.yaml
UPGRADE_DEPLOYMENT_WFPS_CR_TMP=${UPGRADE_DEPLOYMENT_CR}/.wfps_tmp.yaml
UPGRADE_DEPLOYMENT_WFPS_CR_BAK=${UPGRADE_DEPLOYMENT_CR_BAK}/wfps_cr_backup.yaml

UPGRADE_CS_ZEN_FILE=${UPGRADE_DEPLOYMENT_CR}/.cs_zen_parameter.yaml
UPGRADE_DEPLOYMENT_BAI_TMP=${UPGRADE_DEPLOYMENT_CR}/.bai_tmp.yaml

UPGRADE_ICP4A_SHARED_INFO_CM_FILE=${UPGRADE_DEPLOYMENT_CR}/.ibm_cp4ba_shared_info.yaml
UPGRADE_ICP4A_CONTENT_SHARED_INFO_CM_FILE=${UPGRADE_DEPLOYMENT_CR}/.ibm_cp4ba_content_shared_info.yaml

# Returns 0 if the provided CP4BA CSV version belongs to one of the supported upgrade source streams
# and meets the corresponding minimum version defined in MINIMUM_SUPPORTED_UPGRADE_VERSIONS.
# Returns 1 otherwise.
function is_cp4ba_version_meeting_minimum_supported_upgrade_version(){
    local existing_cp4ba_csv_version=$1

    for abs_min in "${MINIMUM_SUPPORTED_UPGRADE_VERSIONS[@]}"; do
        local abs_major_minor="${abs_min%.*}"
        local curr_major_minor="${existing_cp4ba_csv_version%.*}"

        if [[ "$curr_major_minor" == "$abs_major_minor" ]]; then
            if [[ "$(printf '%s\n' "$abs_min" "$existing_cp4ba_csv_version" | sort -V | head -n1)" = "$abs_min" ]]; then
                return 0
            fi
            return 1
        fi
    done

    return 1
}

# Returns 0 only when the provided CP4BA CSV version is from the 24.0.0 stream
# and meets the minimum level required for ADS/ADP PostgreSQL migration logic.
# Returns 1 otherwise.
function check_adp_ads_version_to_migrate_postgres(){
    local existing_cp4ba_csv_version=$1
    local abs_min="24.0.9"

    if [[ "${existing_cp4ba_csv_version}" != 24.0.* ]]; then
        return 1
    fi

    if [[ "$(printf '%s\n' "$abs_min" "$existing_cp4ba_csv_version" | sort -V | head -n1)" = "$abs_min" ]]; then
        return 0
    fi

    return 1
}

# Reads the schema value stored in the gitsvc secret's data-access.json and writes it into
# dc_adp_datasource.database_schema in the CR, so the upgrade uses the same schema as the
# fresh install.
#
# Arguments:
#   $1 - CR name (e.g. "icp4adeploy")
#   $2 - Namespace / project name
#   $3 - CR file location
#
# Relies on: CLI_CMD, YQ_CMD being set in caller scope.
function apply_adpgg_schema_from_gitsvc_secret(){
    local cr_name=$1
    local ns=$2
    local cr_location=$3
    local _secret_name="${cr_name}-gitsvc-secret"
    local _b64 _schema
    # Use -o json + awk to extract the base64 value — avoids jsonpath dot-escaping
    # issues with "data-access.json" across different oc/kubectl versions.
    # The key and value are on the same line in oc/kubectl JSON output:
    #   "data-access.json": "eyJ..."
    # Split on the key pattern and take the value field that follows.
    _b64=$(${CLI_CMD} get secret "$_secret_name" -n "$ns" -o json 2>/dev/null \
        | awk -F'"data-access\\.json"[[:space:]]*:[[:space:]]*"' 'NF>1{split($2,a,"\""); print a[1]; exit}' \
        | tr -d '[:space:]')
    if [[ -n "$_b64" ]]; then
        # Decode and extract the top-level "schema" value.
        # base64 --decode is portable across GNU and BSD coreutils.
        _schema=$(echo "$_b64" | base64 --decode 2>/dev/null \
            | awk -F'"schema"[[:space:]]*:[[:space:]]*"' '{print $2}' \
            | awk -F'"' '{print $1}' \
            | tr -d '[:space:]')
        if [[ -n "$_schema" ]]; then
            info "Setting dc_adp_datasource.database_schema = \"$_schema\" (from secret $_secret_name)"
            # Delete first so a pre-existing null node from the live CR is fully replaced.
            ${YQ_CMD} -i 'del(.spec.datasource_configuration.dc_adp_datasource.database_schema)' "$cr_location"
            ${YQ_CMD} -i ".spec.datasource_configuration.dc_adp_datasource.database_schema = \"$_schema\"" "$cr_location"
        else
            warning "Could not extract schema from secret $_secret_name data-access.json; review dc_adp_datasource.database_schema in the CR manually."
        fi
    else
        warning "Secret $_secret_name not found or has no data-access.json key; review dc_adp_datasource.database_schema in the CR manually."
    fi
}

# For the IFix-to-IFix upgrade path (upgradeDeploymentStatus), the CR is never regenerated
# and re-applied, so database_schema must be persisted directly onto the live cluster CR via
# oc/kubectl patch.  This function mirrors apply_adpgg_schema_from_gitsvc_secret but writes
# the value with "oc patch" instead of yq-editing a local file.
#
# Arguments:
#   $1 - CR name        (e.g. "icp4adeploy")
#   $2 - Namespace / project name
#
# Relies on: CLI_CMD being set in caller scope.
function patch_adpgg_schema_on_live_cr(){
    local cr_name=$1
    local ns=$2
    local _secret_name="${cr_name}-gitsvc-secret"
    local _b64 _schema
    # Reuse the same awk extraction as apply_adpgg_schema_from_gitsvc_secret.
    _b64=$(${CLI_CMD} get secret "$_secret_name" -n "$ns" -o json 2>/dev/null \
        | awk -F'"data-access\\.json"[[:space:]]*:[[:space:]]*"' 'NF>1{split($2,a,"\""); print a[1]; exit}' \
        | tr -d '[:space:]')
    if [[ -z "$_b64" ]]; then
        warning "Secret $_secret_name not found or has no data-access.json key; dc_adp_datasource.database_schema in the live CR may be absent — set it manually before upgrading."
        return 0
    fi
    _schema=$(echo "$_b64" | base64 --decode 2>/dev/null \
        | awk -F'"schema"[[:space:]]*:[[:space:]]*"' '{print $2}' \
        | awk -F'"' '{print $1}' \
        | tr -d '[:space:]')
    if [[ -z "$_schema" ]]; then
        warning "Could not extract schema from secret $_secret_name data-access.json; dc_adp_datasource.database_schema in the live CR may be absent — set it manually before upgrading."
        return 0
    fi
    info "Persisting dc_adp_datasource.database_schema = \"$_schema\" onto live CR \"$cr_name\" (from secret $_secret_name)"
    ${CLI_CMD} patch icp4acluster "$cr_name" -n "$ns" --type=merge \
        -p "{\"spec\":{\"datasource_configuration\":{\"dc_adp_datasource\":{\"database_schema\":\"$_schema\"}}}}" >/dev/null 2>&1
    if [[ $? -eq 0 ]]; then
        success "dc_adp_datasource.database_schema = \"$_schema\" successfully set on live CR \"$cr_name\"."
    else
        warning "Failed to patch dc_adp_datasource.database_schema on live CR \"$cr_name\" — set it manually: ${CLI_CMD} patch icp4acluster $cr_name -n $ns --type=merge -p '{\"spec\":{\"datasource_configuration\":{\"dc_adp_datasource\":{\"database_schema\":\"$_schema\"}}}}'"
    fi
}

# Handle non-postgres upgrade scenario for ADP/DICMS components
# This function prompts the user to choose between external PostgreSQL or CNPG (CloudNativePG)
# when CPE/ICN is on a non-Postgres DB, then writes the appropriate values into the CR.
#
# When the user chooses CNPG the caller's upgrade_scenario variable is updated to "new-edb"
# so that the existing CNPG/EDB instructions block is displayed in the final output.
# When the user chooses external-postgres the caller's upgrade_scenario remains "non-postgres".
#
# Arguments:
#   $1 - Component name (e.g., "ADP Gitgateway and DICMS Designer/Runtime")
#   $2 - Datasource path prefix (e.g., "dc_adp_datasource", "dc_ads_designer_datasource",
#        "dc_ads_runtime_datasource")
#   $3 - CR file location
#   $4 - Whether to include SSL settings (true/false) — applies to the external-postgres path only
#   $5 - (Optional) Pre-resolved db_choice ("cnpg" or "external-postgres"). When provided the
#        interactive prompt is skipped and this value is used directly.
#
# Sets caller-scope variable:
#   upgrade_scenario - set to "new-edb" when the user chooses CNPG
#   NON_POSTGRES_UPGRADE_DB_CHOICE - set to the resolved choice so callers can reuse it
#
# Returns:
#   0 - Successfully configured datasource
#   1 - Error
function handle_non_postgres_upgrade_scenario(){
    local component_name=$1
    local datasource_prefix=$2
    local cr_location=$3
    local include_ssl_settings=${4:-false}
    local preset_db_choice=${5:-""}

    # Input validation
    if [[ -z "$component_name" || -z "$datasource_prefix" || -z "$cr_location" ]]; then
        error "handle_non_postgres_upgrade_scenario: Missing required arguments"
        return 1
    fi

    if [[ ! -f "$cr_location" ]]; then
        error "handle_non_postgres_upgrade_scenario: CR file not found: $cr_location"
        return 1
    fi

    # --- Ask the user which Postgres backend to use ---
    local db_choice=""
    if [[ -n "$preset_db_choice" ]]; then
        # Caller already obtained an answer (e.g. for a sibling component) — reuse it
        db_choice="$preset_db_choice"
    elif [[ "${SKIP_FOR_API:-false}" == "true" ]]; then
        # Silent/API mode: honour a pre-set value, defaulting to cnpg (matches the interactive default of No)
        db_choice="${NON_POSTGRES_UPGRADE_CHOICE:-cnpg}"
    else
        printf "\n"
        printf "\x1B[1mDo you want to use an external Postgres DB for %s in this CP4BA deployment?\x1B[0m\n" "$component_name"
        printf "[${YELLOW_TEXT}NOTE${RESET_TEXT}: IF YES, YOU WILL NEED TO CREATE THE POSTGRESQL DB BEFORE APPLYING THE CP4BA CUSTOM RESOURCE. IF NO, CNPG (CloudNativePG) WILL BE USED.]\n"
        while true; do
            read -erp "Enter your choice (Yes/No, default: No): " ans
            ans=$(echo "$ans" | tr '[:upper:]' '[:lower:]')
            case "$ans" in
                "y"|"yes")
                    db_choice="external-postgres"
                    break
                    ;;
                "n"|"no"|"")
                    db_choice="cnpg"
                    break
                    ;;
                *)
                    printf '%b\n' "Answer must be \"Yes\" or \"No\"\n"
                    ;;
            esac
        done
    fi
    # Export so the caller can pass the same answer to sibling components
    NON_POSTGRES_UPGRADE_DB_CHOICE="$db_choice"

    if [[ "$db_choice" == "cnpg" ]]; then
        # CNPG (CloudNativePG) path — same CR values as the existing EDB cluster
        upgrade_scenario="new-edb"
        allow_postgres_edb_for_2600_upgrade="true"
        ${YQ_CMD} -i ".spec.datasource_configuration.${datasource_prefix}.database_servername = \"postgres-cp4ba-rw.{{ meta.namespace }}.svc\"" "$cr_location" || return 1
        ${YQ_CMD} -i ".spec.datasource_configuration.${datasource_prefix}.database_port = \"5432\"" "$cr_location" || return 1
        ${YQ_CMD} -i ".spec.datasource_configuration.${datasource_prefix}.dc_use_postgres = true" "$cr_location" || return 1
        if [[ "$include_ssl_settings" == "true" ]]; then
            ${YQ_CMD} -i ".spec.datasource_configuration.${datasource_prefix}.ssl_secret_name = \"{{ meta.name }}-pg-client-cert-secret\"" "$cr_location" || return 1
        else
            ${YQ_CMD} -i ".spec.datasource_configuration.${datasource_prefix}.database_ssl_secret_name = \"{{ meta.name }}-pg-client-cert-secret\"" "$cr_location" || return 1
        fi
    else
        # External PostgreSQL path — placeholder values; user fills in real server details
        # upgrade_scenario remains "non-postgres" as set by the caller
        ${YQ_CMD} -i ".spec.datasource_configuration.${datasource_prefix}.database_servername = \"your-external-postgres-server\"" "$cr_location" || return 1
        ${YQ_CMD} -i ".spec.datasource_configuration.${datasource_prefix}.database_port = \"5432\"" "$cr_location" || return 1
        ${YQ_CMD} -i ".spec.datasource_configuration.${datasource_prefix}.dc_use_postgres = false" "$cr_location" || return 1
        if [[ "$include_ssl_settings" == "true" ]]; then
            ${YQ_CMD} -i ".spec.datasource_configuration.${datasource_prefix}.ssl_enabled = \"true\"" "$cr_location" || return 1
            ${YQ_CMD} -i ".spec.datasource_configuration.${datasource_prefix}.ssl_mode = \"verify-ca\"" "$cr_location" || return 1
            ${YQ_CMD} -i ".spec.datasource_configuration.${datasource_prefix}.ssl_secret_name = \"ibm-cp4ba-postgresdb-ssl-secret\"" "$cr_location" || return 1
        else
            ${YQ_CMD} -i ".spec.datasource_configuration.${datasource_prefix}.database_ssl_secret_name = \"ibm-cp4ba-postgresdb-ssl-secret\"" "$cr_location" || return 1
        fi
    fi
    return 0
}


################################################################################
# Enhanced for https://jsw.ibm.com/browse/DBACLD-212650
# Initial reasoning for this function was for https://jsw.ibm.com/browse/DBACLD-154068
#
# Function: update_license
#
# Description:
#   Updates the FNCM license value in the Custom Resource (CR) YAML file during
#   CP4BA upgrades. This function handles license migration from the
#   "user" license to one of the new supported license types introduced in 
#   CP4BA 26.0.0 when someone is upgrading from 24.0.0 ONLY
#
# Parameters:
#   $1 - yaml_file: Path to the CR YAML file to be updated
#   $2 - license_type: Type of license to update (currently only "fncm" supported)
#
# Global Variables:
#   SKIP_FOR_API: Boolean flag for silent/API mode (default: false)
#   UPDATED_FNCM_LICENSE: Pre-selected license value for silent/API mode
#   FNCM_LICENSE_UPDATE_FAILED: Set to "true" if update fails
#   YQ_CMD: Command to execute yq for YAML manipulation
#   YELLOW_TEXT, RED_TEXT, RESET_TEXT: Terminal color codes
#
# Behavior:
#   - Only prompts for update when current license value is "user"
#   - Skips update if license is not "user"
#   - Interactive mode: Prompts user to select from 3 license options (3 retries)
#   - Silent/API mode: Uses UPDATED_FNCM_LICENSE variable value
#   - Validates selected license before applying to CR
#
# Valid User License Values that can be selected:
#   - user: 
#   - concurrent-user: 
#   - authorized-user:
#
# Returns:
#   0 - Success (license updated or no update needed)
#   1 - Failure (invalid type, validation failed, or max retries exceeded)
#
# Example Usage:
#   update_license "/path/to/cr.yaml" "fncm"
#   SKIP_FOR_API=true UPDATED_FNCM_LICENSE="concurrent-user" update_license "/path/to/cr.yaml" "fncm"
################################################################################
function update_license() {
    # Input arguments passed to the function.
    local yaml_file="$1"
    local license_type="$2"

    # Retry count used only for interactive prompting.
    local retries=3

    # Holds the current value read from the CR for the target license field.
    local license_value=""

    # Holds the value selected either by user input or by silent mode variables.
    local selected_license=""

    # Holds the yq path of the field to be updated in the CR.
    local yq_path=""

    # Resolve runtime mode and incoming silent-mode values from globals.
    # If the globals are not set, default them safely.
    local skip_for_api="${SKIP_FOR_API:-false}"
    local updated_fncm_license="${UPDATED_FNCM_LICENSE:-}"

    # Resolve which YAML field should be updated based on the license type,
    # and also read the current value from the CR for that field.
    case "$license_type" in
        fncm)
            yq_path=".spec.shared_configuration.sc_deployment_fncm_license"
            license_value="$(${YQ_CMD} "$yq_path" "$yaml_file")"
            ;;
        *)
            fail "Unsupported license type: $license_type"
            return 1
            ;;
    esac

    # Validate whether a proposed new license value is allowed for the given
    # license type. This is used by both interactive mode and silent/API mode.
    # Only user, concurrent-user, and authorized-user are valid for FNCM.
    is_valid_license_value() {
        local current_license_type="$1"
        local current_license_value="$2"

        case "$current_license_type" in
            fncm)
                case "$current_license_value" in
                    user|concurrent-user|authorized-user) return 0 ;;
                    *) return 1 ;;
                esac
                ;;
            *)
                return 1
                ;;
        esac
    }

    # Update the resolved YAML field with the new selected license value.
    # The yq path used here was already resolved earlier based on license type.
    set_license_value() {
        local new_license_value="$1"
        ${YQ_CMD} -i "${yq_path} = \"${new_license_value}\"" "$yaml_file"
    }

    printf "\n"

    # Handle FNCM license updates.
    if [[ "$license_type" == "fncm" ]]; then
        # Check if the current license value is "user" - only proceed if it is.
        # This ensures we only prompt for migration when the deprecated "user"
        # license is present. Other license values (concurrent-user, authorized-user)
        # are already valid and don't need to be updated.
        if [[ "$license_value" != "user" ]]; then
            info "Current sc_deployment_fncm_license value is \"$license_value\". No update required (only \"user\" license needs migration)."
            printf "\n"
            return 0
        fi

        # Silent/API mode path for FNCM:
        # In this mode, we do not prompt the user. Instead, we validate the
        # UPDATED_FNCM_LICENSE variable that should have been set externally,
        # and then update the CR with that value.
        if [[ "$skip_for_api" == "true" ]]; then
            if ! is_valid_license_value "fncm" "$updated_fncm_license"; then
                fail "Invalid Content Cortex Essentials license value passed in using the UPDATED_FNCM_LICENSE argument: \"$updated_fncm_license\". Allowed values are: user, concurrent-user, authorized-user."
                FNCM_LICENSE_UPDATE_FAILED="true"
                return 1
            fi

            set_license_value "$updated_fncm_license"
            success "The sc_deployment_fncm_license value has been successfully updated to \"$updated_fncm_license\"."
            printf "\n"
            return 0
        fi

        # Interactive mode path for FNCM:
        # Prompt the user to choose one of the newly supported license values.
        # The user has up to 3 attempts to select a valid option.
        while (( retries > 0 )); do
            echo "${YELLOW_TEXT}[ATTENTION]: From the 24.0.1 release of CP4BA or newer, there are 2 additional user based license types supported for the Content Cortex Essentials License. The script will now prompt you to choose a valid license value for your deployment.${RESET_TEXT}"
            echo "${RED_TEXT}[IMPORTANT] This is a mandatory step before the Custom Resource file for the 26.0.0 CP4BA deployment can be applied.${RESET_TEXT}"
            printf "\n"
            echo "Current license value: \"$license_value\""
            echo "Select one of the following options as the updated license value:"
            echo "1) user"
            echo "2) concurrent-user"
            echo "3) authorized-user"
            echo


            read -r -p "Enter the number corresponding to the license of your choice: " choice

            # Map the numeric user choice to the actual FNCM license value.
            case "$choice" in
                1) selected_license="user" ;;
                2) selected_license="concurrent-user" ;;
                3) selected_license="authorized-user" ;;
                *)
                    echo "Invalid option. Choose again."
                    echo
                    retries=$((retries - 1))
                    continue
                    ;;
            esac

            # Update the CR and exit successfully once a valid option is chosen.
            set_license_value "$selected_license"
            success "The sc_deployment_fncm_license value has been successfully updated to \"$selected_license\"."
            printf "\n"
            return 0
        done

        # If all interactive retries are exhausted, mark the FNCM update as failed.
        fail "Maximum retries reached while updating sc_deployment_fncm_license."
        FNCM_LICENSE_UPDATE_FAILED="true"
        return 1
    fi
}



# For jsw.ibm.com/browse/DBACLD-153103 where we need to update the datavolume section of the CR to be in the right format
# Function to check PVC size for a given PVC
get_pvc_size_from_cluster() {
    pvc_name=$1
    project_namespace=$2
    DEFAULT_SIZE="1Gi"
    size=$(${CLI_CMD} get pvc "$pvc_name" -n $project_namespace -o=jsonpath='{.spec.resources.requests.storage}' 2>/dev/null)

    # If the PVC doesn't exist or kubectl fails, return the default size
    if [ -z "$size" ]; then
        echo "$DEFAULT_SIZE"
    else
        echo "$size"
    fi
}
# For jsw.ibm.com/browse/DBACLD-153103 where we need to update the datavolume section of the CR to be in the right format
# Function to process all datavolume fields in the YAML file and update the formatting to the current CR format
process_datavolumes() {
    local input_yaml="$1"
    project_namespace="$2"

    # Find all paths that have a datavolume section
    datavolume_paths=$(${YQ_CMD} \
    '.. | path
        | select(length>0)
        | select(.[-1]=="datavolume")
        | ( .[] | select((. | tag) == "!!int") |= (["[", tostring, "]"] | join("")) )
        | join(".")
        | sub("\\.\\[","[")' \
    "$input_yaml")

    # Iterate over each datavolume path found
    for path in $datavolume_paths; do
        # Find all the key names inside the datavolume section
        keys=($(${YQ_CMD} '.$path' $input_yaml | grep -v '^\s'| awk -F ':' '{print $1}' | xargs -n 1))

        # Loop through the keys using the index
        for i in "${!keys[@]}"; do
            key="${keys[$i]}"
            key_path="$path.$key"
            # Check if 'name' and 'size' fields exist under this key
            name_exists=$(${YQ_CMD} ".${path}.${key}.name | select(. != null)" "$input_yaml" 2>/dev/null)
            size_exists=$(${YQ_CMD} ".${path}.${key}.size | select(. != null)" "$input_yaml" 2>/dev/null)

            # If the 'name' and 'size' field already exists, skip further processing for this key as it is in the right format already, otherwise the script makes changes
            if [[ ! -n "$name_exists" && ! -n "$size_exists" ]]; then
                #retrieve the current pvc name 
                current_value=$(${YQ_CMD} ".$key_path" "$input_yaml")
                # retrieve the current PVC size, default is 1Gi
                pvc_size=$(get_pvc_size_from_cluster "$current_value" "$project_namespace")

                # Write the name field with the name of the PVC
                ${YQ_CMD} -i ".$path.${key}.name = \"$current_value\"" "$input_yaml"

                # Write the size field with the pvc size
                ${YQ_CMD} -i ".$path.${key}.size = \"$pvc_size\"" "$input_yaml"
            fi
        done
    done
}

# For DBACLD-159463 where we need to add quotes around the jvm options string passed. In addition all custom annotations defined in the CR must be in strings
function add_quotes_to_values(){
    local input_yaml="$1"
    # Use sed to add quotes around jvm_customize_options values if not already quoted
    ${SED_COMMAND} -E '/jvm_customize_options:/ { /: *["'"'"']/ !s/: *(.+)/: "\1"/; }' "${input_yaml}"
    
    annotations_paths=$(${YQ_CMD} \
    '.. | path
        | select(length>0)
        | select(.[-1]=="custom_annotations")
        | ( .[] | select((. | tag) == "!!int") |= (["[", tostring, "]"] | join("")) )
        | join(".")
        | sub("\\.\\[","[")' \
    "$input_yaml")
    for path in $annotations_paths; do
        
        keys=($(${YQ_CMD} '.$path' ${input_yaml} | grep -v '^\s'| awk -F ':' '{print $1}' | xargs -n 1))
        # Loop through the keys using the index
        for i in "${!keys[@]}"; do
            key="${keys[$i]}"
            key_path="$path.\"$key\""
            current_value=$(${YQ_CMD} ".$key_path" "${input_yaml}")
            if [[ $current_value == true || $current_value == false ]]; then
                ${YQ_CMD} -i ".$key_path = \"$current_value\"" "${input_yaml}"
            fi
        done
    done
    ${SED_COMMAND} "s|'\"|\"|g" ${input_yaml}
    ${SED_COMMAND} "s|\"'|\"|g" ${input_yaml}
}

# This is a function to remove all image tags from a CR
# Called during the upgradeDeployment mode
function remove_image_tags(){
    local CR_FILE=$1
    TAGS_REMOVED="false"
    ## remove all image tags
    # jq -r paths generates all possible paths in a json/yaml as comma seperated lists
    # select(.[-1] == "tag" selects all the paths ending with tag 
    # the map(tostring) | join("/") joins the list into the full path and stores it in the list tag_paths
    # the reason there are two different arrays is because to display the values from the yaml , yq needs the yaml path to be seperated by . but the oc patch command needs the path seperated by /
    tag_paths_display=$(${YQ_CMD} -o=json '.' "${CR_FILE}" | jq -r 'paths | select(.[-1] == "tag") | map(tostring) | join(".")')
    tag_paths_patch=$(${YQ_CMD} -o=json '.' "${CR_FILE}" | jq -r 'paths | select(.[-1] == "tag") | map(tostring) | join("/")')
    # Removing tags only if the list is populated
    if [[ -n "$tag_paths_display" ]]; then
        echo "${YELLOW_TEXT}[ATTENTION]: The script detects image tags set in the current version of the Custom Resource file.\n[ATTENTION]: The script will remove the tags in the new version of the Custom Resource file and patch the current Custom Resource by removing those image tags since the tags are old and prevent the operator from deploying the updated software."
        info "The list of image tags that will be removed are listed below :"
        for path in $tag_paths_display; do
            tag_value=$(${YQ_CMD} ".$path" ${CR_FILE})
            # Extract the parent path (all parts except the last)
            parent_path=$(echo "$path" | awk -F'.' '{print substr($0, 1, length($0)-length($NF)-1)}')
            repository_value=$(${YQ_CMD} ".$parent_path.repository" ${CR_FILE})
            info "$repository_value:$tag_value"
        done
        printf "\n"
        if [[ "$SKIP_FOR_API" != "true" ]]; then
            prompt_press_any_key_to_continue "to remove the defined image tags from the Custom Resource file"
        fi
        printf "\n"
        # To remove the tags and prevent them from being added back by the last-applied-configuration annotation we need to 
        # 1. Remove it from the CR file that will be applied
        ${SED_COMMAND} "/tag: .*/d" ${CR_FILE}
        TAGS_REMOVED="true"
    fi         
}

# This is a Validation Function to do a dry run of applying the CR and if there are any errors it will prompt remediation steps and exit out
function dryrun(){
    FILE=$1
    projectname=$2
    # Run kubectl apply with dry-run
    output=$(${CLI_CMD} apply -f "$FILE" --dry-run=server 2>&1)
    exit_code=$?
    info "Validating the CP4BA Custom Resource file by executing a dry run..."
    printf "\n"
    # Check the exit code and output to handle different cases
    if [ $exit_code -eq 0 ]; then
        echo "${GREEN_TEXT} The Custom Resource file does not contain any errors.${RESET_TEXT}"
        echo "Done!"
    else
        # Handle specific errors
        if echo "$output" | grep -q "unknown field"; then
            # The sample output of the dry run when there is an unknown/invalid field ends with "strict decoding error: unknown field \"<field_name>\""
            # The sed command first removes the entire output string before and including unknown_field " and then removes everything the next quote it finds,keep only <field_name> to be assigned to the unknownfield variable
            unknownfield=$(echo "$output" | sed 's/.*unknown field "//;s/".*//')
            error "ERROR: Unknown field \"$unknownfield\" found in ${FILE}. Check the field names and values."
        elif echo "$output" | grep -q "error parsing"; then
            error "Error: Error parsing ${FILE}. Fix the YAML syntax for this custom resource file."
        else
            # Handle other errors
            error "Unknown Error found while applying the Custom Resource file."
        fi
        # Display next steps when an error is encountered
        echo "${YELLOW_TEXT}[NEXT ACTIONS]:${RESET_TEXT}"
        step_num=1
        printf "\n"
        echo "${YELLOW_TEXT}- Resolve the errors that were discovered earlier by modifying the Custom Resource file \"${FILE}\" .${RESET_TEXT}"
        echo "${YELLOW_TEXT}- If the error is related to an unknown field, remove the unknown field from the Custom Resource file \"${FILE}\" .${RESET_TEXT}"
        echo "${YELLOW_TEXT}- If the error is due to YAML parsing, fix the YAML syntax or indentation of the Custom Resource file \"${FILE}\" .${RESET_TEXT}"
        echo "${YELLOW_TEXT}[NOTE]:${RESET_TEXT} This step will fix the custom resource file errors that were found in the previous executed of the upgradeDeployment mode."
        echo "  - STEP ${step_num} ${RED_TEXT}(Required)${RESET_TEXT}:${GREEN_TEXT} # ${CLI_CMD} apply -f ${FILE} -n $projectname${RESET_TEXT}" && step_num=$((step_num + 1))
        printf "\n"
        echo "${YELLOW_TEXT}[NOTE]:${RESET_TEXT} Rerun the script cp4ba-deployent.sh in upgradeDeployment mode to continue with the upgrade of IBM Cloud Pak for Business Automation deployment."
        CUR_DIR=$(realpath "$(dirname "${BASH_SOURCE[0]}")")
        SCRIPTS_DIR="$(realpath "$CUR_DIR/../..")"
        echo "  - STEP ${step_num} ${RED_TEXT}(Required)${RESET_TEXT}: ${GREEN_TEXT}# ${SCRIPTS_DIR}/cp4a-deployment.sh -m upgradeDeployment -n $projectname${RESET_TEXT}"

        printf "\n"
        exit
    fi
}

function convert_olm_cr(){
    local cr_file=$1
    EXISTING_PATTERN_ARR=()
    EXISTING_OPT_COMPONENT_ARR=()
    # check the cr is olm format or not, it indicates that the CR is in OLM format
    olm_cr_flag=`${YQ_CMD} ".spec.olm_ibm_license // \"\"" "$cr_file"`
    if [[ ! -z $olm_cr_flag ]]; then
        olm_cr_flag="Yes"
        #Mapping parameters from olm, to ensure compatibility and proper functionality in the Cert-K8 environment
        local OLM_PATTERN_CR_MAPPING=("spec.olm_production_content"
                                "spec.olm_production_application"
                                "spec.olm_production_decisions"
                                "spec.olm_production_decisions_ads"
                                "spec.olm_production_document_processing"
                                "spec.olm_production_workflow"
                                "spec.olm_production_workflow_process_service")
        local SCRIPT_PATTERN_CR_MAPPING=("content"
                                "application"
                                "decisions"
                                "decisions_ads"
                                "document_processing"
                                "workflow"
                                "workflow-process-service")

        #Mapping parameters to convert parameters from the OLM format to the Cert-K8 format
        for i in "${!OLM_PATTERN_CR_MAPPING[@]}"; do
            # echo "Element $i: ${OLM_PATTERN_CR_MAPPING[$i]}"
            olm_pattern_flag=`${YQ_CMD} ".${OLM_PATTERN_CR_MAPPING[$i]}" "$cr_file"`
            if [[ $olm_pattern_flag == "true" ]]; then
                EXISTING_PATTERN_ARR=( "${EXISTING_PATTERN_ARR[@]}" "${SCRIPT_PATTERN_CR_MAPPING[$i]}" )
                if [[ ${SCRIPT_PATTERN_CR_MAPPING[$i]} == "workflow" ]]; then
                    olm_pattern_flag=`${YQ_CMD} ".spec.olm_production_workflow_deploy_type" "$cr_file"`
                    EXISTING_PATTERN_ARR=( "${EXISTING_PATTERN_ARR[@]}" "$olm_pattern_flag" )
                    if [[ $olm_pattern_flag == "workflow_authoring" ]]; then
                        EXISTING_OPT_COMPONENT_ARR=( "${EXISTING_OPT_COMPONENT_ARR[@]}" "baw_authoring" )
                    fi
                fi
                if [[ ${SCRIPT_PATTERN_CR_MAPPING[$i]} == "document_processing" ]]; then
                    olm_pattern_flag=`${YQ_CMD} ".spec.olm_production_option.adp.document_processing_runtime // \"\"" "$cr_file"`
                    if [[ $olm_pattern_flag == "true" ]]; then
                        EXISTING_PATTERN_ARR=( "${EXISTING_PATTERN_ARR[@]}" "document_processing_runtime" )
                    elif [[ $olm_pattern_flag == "false" ]]; then
                        EXISTING_PATTERN_ARR=( "${EXISTING_PATTERN_ARR[@]}" "document_processing_designer" )
                    fi
                fi
            elif [[ -z $olm_pattern_flag ]]; then
                ${YQ_CMD} -i ".${OLM_PATTERN_CR_MAPPING[$i]} = \"false\"" ${cr_file}
            fi
        done
        #Mapping optional components from olm, to ensure compatibility and proper functionality in the Cert-K8 environment
        local OLM_OPTIONAL_COMPONENT_CR_MAPPING=("spec.olm_production_option.adp.cmis"
                                                "spec.olm_production_option.adp.css"
                                                "spec.olm_production_option.adp.document_processing_runtime"
                                                "spec.olm_production_option.adp.es"
                                                "spec.olm_production_option.adp.tm"

                                                "spec.olm_production_option.ads.ads_designer"
                                                "spec.olm_production_option.ads.ads_runtime"
                                                "spec.olm_production_option.ads.bai"

                                                "spec.olm_production_option.application.app_designer"
                                                "spec.olm_production_option.application.ae_data_persistence"

                                                "spec.olm_production_option.content.bai"
                                                "spec.olm_production_option.content.cmis"
                                                "spec.olm_production_option.content.css"
                                                "spec.olm_production_option.content.es"
                                                "spec.olm_production_option.content.iccsap"
                                                "spec.olm_production_option.content.ier"
                                                "spec.olm_production_option.content.tm"

                                                "spec.olm_production_option.decisions.decisionCenter"
                                                "spec.olm_production_option.decisions.decisionRunner"
                                                "spec.olm_production_option.decisions.decisionServerRuntime"
                                                "spec.olm_production_option.decisions.bai"

                                                "spec.olm_production_option.wfps_authoring.bai"
                                                "spec.olm_production_option.wfps_authoring.pfs"
                                                "spec.olm_production_option.wfps_authoring.kafka"

                                                "spec.olm_production_option.workfow_authoring.bai"
                                                "spec.olm_production_option.workfow_authoring.pfs"
                                                "spec.olm_production_option.workfow_authoring.kafka"
                                                "spec.olm_production_option.workfow_authoring.ae_data_persistence"

                                                "spec.olm_production_option.workfow_runtime.bai"
                                                "spec.olm_production_option.workfow_runtime.kafka"
                                                "spec.olm_production_option.workfow_runtime.opensearch"
                                                "spec.olm_production_option.workfow_runtime.elasticsearch")
        for i in "${!OLM_OPTIONAL_COMPONENT_CR_MAPPING[@]}"; do
            # echo "Element $i: ${OLM_OPTIONAL_COMPONENT_CR_MAPPING[$i]}"

            # migration from elasticsearch to opensearch in workflow_runtime
            # updates the CR file based on the presence and value of the Elasticsearch flag and the workflow deployment type
            if [[ ${OLM_OPTIONAL_COMPONENT_CR_MAPPING[$i]} == "spec.olm_production_option.workfow_runtime.elasticsearch" ]]; then
                olm_optional_component_flag=`${YQ_CMD} ".${OLM_OPTIONAL_COMPONENT_CR_MAPPING[$i]} // \"\"" "$cr_file"`
                if [[ $olm_optional_component_flag == "true" ]]; then
                    ${YQ_CMD} -i '.spec.olm_production_option.workfow_runtime.opensearch = true' ${cr_file}
                elif [[ $olm_optional_component_flag == "false" ]]; then
                    ${YQ_CMD} -i '.spec.olm_production_option.workfow_runtime.opensearch = false' ${cr_file}
                elif [[ -z $olm_optional_component_flag ]]; then
                    olm_workflow_runtime_flag=`${YQ_CMD} ".spec.olm_production_workflow_deploy_type" "$cr_file"`
                    if [[ $olm_workflow_runtime_flag == "workflow_runtime" ]]; then
                        ${YQ_CMD} -i '.spec.olm_production_option.workfow_runtime.opensearch = true' ${cr_file}
                    fi
                fi
                ${YQ_CMD} -i "del(.${OLM_OPTIONAL_COMPONENT_CR_MAPPING[${i}]})" "$cr_file"
            fi

            # PFS is requird from 21.0.3/22.0.2 to 24.0.0 for workflow_authoring
            #Setting the PFS flag based on its current state in the CR file
            if [[ ${OLM_OPTIONAL_COMPONENT_CR_MAPPING[$i]} == "spec.olm_production_option.workfow_authoring.pfs" ]]; then
                olm_optional_component_flag=`${YQ_CMD} ".${OLM_OPTIONAL_COMPONENT_CR_MAPPING[$i]} // \"\"" "$cr_file"`
                if [[ $olm_optional_component_flag == "true" ]]; then
                    ${YQ_CMD} -i '.spec.olm_production_option.workfow_authoring.pfs = true' ${cr_file}
                elif [[ $olm_optional_component_flag == "false" ]]; then
                    ${YQ_CMD} -i '.spec.olm_production_option.workfow_authoring.pfs = false' ${cr_file}
                elif [[ -z $olm_optional_component_flag ]]; then
                    olm_workfow_authoring_flag=`${YQ_CMD} ".spec.olm_production_workflow_deploy_type" "$cr_file"`
                    if [[ $olm_workfow_authoring_flag == "workflow_authoring" ]]; then
                        ${YQ_CMD} -i '.spec.olm_production_option.workfow_authoring.pfs = true' ${cr_file}
                    fi
                fi
            fi

            # remove ae_data_persistence and enable olm_production_application
            if [[ ${OLM_OPTIONAL_COMPONENT_CR_MAPPING[$i]} == "spec.olm_production_option.workfow_authoring.ae_data_persistence" ]]; then
                olm_optional_component_flag=`${YQ_CMD} ".${OLM_OPTIONAL_COMPONENT_CR_MAPPING[$i]}" "$cr_file"`
                if [[ $olm_optional_component_flag == "true" ]]; then
                    ${YQ_CMD} -i '.spec.olm_production_application = true' ${cr_file}
                    ${YQ_CMD} -i '.spec.olm_production_option.application.ae_data_persistence = true' ${cr_file}
                fi
                ${YQ_CMD} -i "del(.${OLM_OPTIONAL_COMPONENT_CR_MAPPING[${i}]})" "$cr_file"
            fi

            olm_optional_component_flag=`${YQ_CMD} ".${OLM_OPTIONAL_COMPONENT_CR_MAPPING[$i]}" "$cr_file"`
            if [[ $olm_optional_component_flag == "true" ]]; then
                OIFS=$IFS
                IFS='.' read -r -a array <<< "${OLM_OPTIONAL_COMPONENT_CR_MAPPING[$i]}"
                last_element="${array[-1]}"
                EXISTING_OPT_COMPONENT_ARR=( "${EXISTING_OPT_COMPONENT_ARR[@]}" "$last_element" )
                IFS=$OIFS
            elif [[ -z $olm_pattern_flag && ${OLM_OPTIONAL_COMPONENT_CR_MAPPING[$i]} != "spec.olm_production_option.workfow_authoring.ae_data_persistence" && ${OLM_OPTIONAL_COMPONENT_CR_MAPPING[$i]} != "spec.olm_production_option.workfow_runtime.elasticsearch" ]]; then
                ${YQ_CMD} -i ".${OLM_OPTIONAL_COMPONENT_CR_MAPPING[$i]} = \"false\"" ${cr_file}
            fi
        done

        # remove duplicate element from EXISTING_OPT_COMPONENT_ARR
        UNIQUE_COMPONENTS=$(printf "%s\n" "${EXISTING_OPT_COMPONENT_ARR[@]}" | sort -u)
        EXISTING_OPT_COMPONENT_ARR=($UNIQUE_COMPONENTS)

        # echo "EXISTING_PATTERN_ARR: ${EXISTING_PATTERN_ARR[*]}"
        # echo "EXISTING_OPT_COMPONENT_ARR: ${EXISTING_OPT_COMPONENT_ARR[*]}"
    else
        olm_cr_flag="No"
    fi
}
#create property file to manage configuration parameters necessary for the CP4BA upgrade
function create_upgrade_property(){

    mkdir -p ${UPGRADE_DEPLOYMENT_FOLDER}

cat << EOF > ${UPGRADE_DEPLOYMENT_PROPERTY_FILE}
##############################################################################
## The property is for ZenService customize configuration used by Common Services $CS_OPERATOR_VERSION
##############################################################################

## The value for CS_OPERATOR_NAMESPACE/CS_SERVICES_NAMESPACE fill in by script.
## The value will be inserted into ibm-cp4ba-common-config configMap for upgrade CP4BA deployment automatically.
## kind: ConfigMap
## apiVersion: v1
## metadata:
##   name: ibm-cp4ba-common-config
##   namespace: <cp4ba-namespace>
## data:
##   operator_namespace: "<commonservice-operator-namespace>"
##   services_namespace: "<commonservice-namespace>"

## The namespace for Common Service Operator $CS_OPERATOR_VERSION
CS_OPERATOR_NAMESPACE=""

## The namespace for Common Service $CS_OPERATOR_VERSION
CS_SERVICES_NAMESPACE=""
EOF
  create_zen_yaml
  success "Created CP4BA upgrade property file\n"

}

#create a YAML file for the ibm-cp4ba-common-config ConfigMap
#used to define configuration settings for the CP4BA upgrade, including namespaces for the Common Service Operator and Common Service
function create_zen_yaml(){
    mkdir -p ${UPGRADE_DEPLOYMENT_CR}
cat << EOF > ${UPGRADE_CS_ZEN_FILE}
# YAML template for ibm-cp4ba-common-config
---
kind: ConfigMap
apiVersion: v1
metadata:
  name: ibm-cp4ba-common-config
  labels:
    cp4ba.ibm.com/backup-type: mandatory
data:
  ## The namespace for Common Service Operator
  operators_namespace: ""
  ## The namespace for Common Service
  services_namespace: ""
EOF
    success "Created YAML file for migration IBM Cloud Pak foundational services \"${UPGRADE_CS_ZEN_FILE}\"."
}

#Function that applies the changes required for the new network policy design as part of 25.0.0
# 1.Retrieves the existing network policies
# 2.Removes owner references from the network policies and reapplies the modified templates
# 3.Notifies the user about the new flag that will generate new network policy templates after the operator is brought up
# 4.Removes the restricted_internet_access flag as it is no longer supported
# For https://jsw.ibm.com/browse/DBACLD-167387
function update_network_policies(){
    local namespace=$1
    local cr_type=$2
    local cr_file=$3
    local netpol_targ_path=${CUR_DIR}/network-policies/${namespace}/templates
    printf "\n"
    echo "${RED_TEXT}[ATTENTION]: ${RESET_TEXT}${YELLOW_TEXT} Starting with 25.0.0, the operator is no longer creating network policies automatically.${RESET_TEXT}"
    echo "${YELLOW_TEXT}In addition, the script will remove the ownerReference of any network policies created by the operators, and save the definition of the network policies to ${RESET_TEXT}${GREEN_TEXT}$netpol_targ_path${RESET_TEXT}."
    echo "${YELLOW_TEXT}The script will not delete any existing network policies.The user now is responsible for maintaining these network policies moving forward.${RESET_TEXT}"
    printf "\n"
    if [[ "$SKIP_FOR_API" != "true" ]]; then
        prompt_press_any_key_to_continue
    fi
    bash ${CUR_DIR}/cp4a-network-policies.sh -m retrieveExisting -n $namespace --kind $cr_type
    bash ${CUR_DIR}/cp4a-network-policies.sh -m removeRef -n $namespace
    printf "\n"
    echo "${YELLOW_TEXT}(Notes: Starting from $CP4BA_RELEASE_BASE, the CP4BA operators no longer install network policies automatically.${RESET_TEXT}"
    echo "However, the script \"cp4a-network-policies.sh\" is provided as a tool you can optionally use to generate network policy templates which you can review and apply.  If you want to generate network policy templates, then do the following:"
    echo "1. Make sure the flag \"shared_configuration.sc_generate_sample_network_policies\" is set to \"true\" in your custom resource file. (By default, the script will set the sc_generate_sample_network_policies to \"false\" )"
    echo "2. Wait for your deployment complete."
    # Will be adding the KC link after its been created
    echo "3. You can retrieve and apply the network policies by running the cp4a-network-policies.sh script after the CP4BA upgrade has been completed ."
    printf "\n"
    if [[ "$SKIP_FOR_API" != "true" ]]; then
        prompt_press_any_key_to_continue
    fi
    # For WFPSRuntime the CR does not need the sc_generate_sample_network_policies flag nor does it have sc_restricted_internet_access
    # The operator picks those values from the ICP4ACluster
    # For https://jsw.ibm.com/browse/DBACLD-175988
    if [[ $cr_type != "WfPSRuntime" ]]; then
        ${YQ_CMD} -i 'del(.spec.shared_configuration.sc_egress_configuration.sc_restricted_internet_access)' "${cr_file}"
        ${YQ_CMD} -i '.spec.shared_configuration.sc_generate_sample_network_policies = false' ${cr_file}
    fi

}

# Function to detect if the Domain is configured with SCIM
# During upgradeOperator we check for SCIM configuration in the Domain and then save a boolean flag in the shared info configmap
# This function retrieves the flag and accordingly sets the sc_skip_ldap_config flag in the CR
# https://jsw.ibm.com/browse/DBACLD-157386 https://jsw.ibm.com/browse/DBACLD-178101 https://jsw.ibm.com/browse/DBACLD-177550 https://jsw.ibm.com/browse/DBACLD-177742
# No longer required in 26.0.0 as this solution was required for deployments upgraded from 21.0.3/22.0.2 and we do not support that scenario in 26.0.0
#function detect_scim_configuration(){
#    local namespace=$1
#    local configmap_name=$2
#    local cr_file=$3
#    #checking if the SCIM Value is in either ibm-cp4ba-content-shared-info or ibm-cp4ba-shared-info
#    scim_enabled=''
#    scim_enabled=$(${CLI_CMD} get cm "$configmap_name" -n $namespace -o yaml | ${YQ_CMD} '.data.scim_configured // ""' -)
#    if [[ ! -z "$scim_enabled" ]]; then
#        echo "SCIM STATUS----$scim_enabled"
#        if [[ "$scim_enabled" == "True" ]]; then
#            info "${YELLOW_TEXT}When the Content Process Engine directory provider type is set to SCIM, the script will set \"shared_configuration.sc_skip_ldap_config\" as \"true\" while upgrading CP4BA deployment from version \"$cr_version\".${RESET_TEXT}"
#            ${YQ_CMD} -i '.spec.shared_configuration.sc_skip_ldap_config = true' ${cr_file}
#        else
#            info "${YELLOW_TEXT}When Content Process Engine directory provider type is set to LDAP (not SCIM), setting \"shared_configuration.sc_skip_ldap_config\" as \"false\" while upgrading CP4BA deployment from version \"$cr_version\".${RESET_TEXT}"
#            ${YQ_CMD} -i '.spec.shared_configuration.sc_skip_ldap_config = false' ${cr_file}
#        fi
#    fi
#}

# Function to scale down content pattern related resources
# This includes scaling down CPE, CPE watcher, Navigator, Navigator Watcher CSS
# takes two arguments
# 1. The deployment namespace
# 2. The deployment prefix which is the top level CR metaname
function scale_down_content_pattern_resources() {
    local namespace=$1
    local deployment_prefix=$2
    info "Scaling down CPE deployment"
    ${CLI_CMD} scale --replicas=0 deployment ${deployment_prefix}-cpe-deploy -n $namespace >/dev/null 2>&1
    echo "Done!"
    # To allow any changes to creation of the zen extension configuration that we make from IFIX to IFIX,its best if the watcher pods are scaled down prior to applying the new CR
    # DBACLD-171900
    info "Scaling down CPE Watcher deployment"
    ${CLI_CMD} scale --replicas=0 deployment ${deployment_prefix}-cpe-watcher -n $namespace >/dev/null 2>&1
    echo "Done!"
    info "Scaling down Navigator deployment"
    ${CLI_CMD} scale --replicas=0 deployment ${deployment_prefix}-navigator-deploy -n $namespace >/dev/null 2>&1
    echo "Done!"
    # To allow any changes to creation of the zen extension configuration that we make from IFIX to IFIX,its best if the watcher pods are scaled down prior to applying the new CR
    # DBACLD-171900
    info "Scaling down Navigator Watcher deployment"
    ${CLI_CMD} scale --replicas=0 deployment ${deployment_prefix}-navigator-watcher -n $namespace >/dev/null 2>&1
    echo "Done!"

    info "Scaling down CSS deployment if it has been deployed"
    css_instance_number=0
    css_instance_index=1
    while true; do
        ${CLI_CMD} get deployment ${deployment_prefix}-css-deploy-${css_instance_index} >/dev/null 2>&1
        if [[ $? -ne 0 ]]; then
            break
        else
            ((css_instance_index++))
            ((css_instance_number++))
        fi
    done
    if (( $css_instance_number > 0  )); then
        for ((j=1;j<=${css_instance_number};j++));
        do
            ${CLI_CMD} scale --replicas=0 deployment ${deployment_prefix}-css-deploy-${j} -n $namespace >/dev/null 2>&1
        done
        echo "Done!"
    fi
}

# Scale up the ADP Mongo deployment so the 26.0.0 gitgateway can perform its one-time
# MongoDB → PostgreSQL data migration on startup.
#
# Starting from 26.0.0-IF001 the operator no longer manages the mongo-deploy deployment
# (commit 8a7e2772 "remove Mongo deployment" in ibm-content-operator).  It neither creates
# nor scales it — meaning whatever replica count it held going into the upgrade stays frozen.
# The deployment is left at 0/0 replicas after upgradeOperator shuts everything down, but
# the IF001+ gitgateway image needs a live Mongo connection at startup to migrate its data to
# PostgreSQL.  Without this scale-up gitgateway crashes in a connect-timeout loop.
#
# The scale-up is gated on:
#   - target release is 26.0.0
#   - source is 24.0.x >= 24.0.9  (check_adp_ads_version_to_migrate_postgres)
#   - document_processing_designer optional component is installed
#   - the mongo-deploy deployment actually exists in the namespace
#
# Arguments:
#   $1 - deployment namespace
#   $2 - CR metaname (deployment prefix, e.g. "icp4adeploy")
function scale_up_adp_mongo_for_migration() {
    local namespace=$1
    local deployment_prefix=$2
    local mongo_deploy="${deployment_prefix}-mongo-deploy"

    # Only needed when upgrading from 24.x to 26.0.0
    if [[ "${CP4BA_RELEASE_BASE}" != "26.0.0" ]]; then
        return 0
    fi
    if ! check_adp_ads_version_to_migrate_postgres "${cp4ba_original_csv_ver_for_upgrade_script}"; then
        return 0
    fi

    # Only act when the deployment exists (i.e. was created by the 24.x operator)
    if ! ${CLI_CMD} get deployment ${mongo_deploy} -n ${namespace} --no-headers --ignore-not-found 2>/dev/null | grep -q .; then
        return 0
    fi

    info "Scaling up ADP Mongo deployment \"${mongo_deploy}\" so gitgateway can migrate data to PostgreSQL"
    ${CLI_CMD} scale --replicas=1 deployment ${mongo_deploy} -n ${namespace} >/dev/null 2>&1
    if [[ $? -ne 0 ]]; then
        warning "Failed to scale up \"${mongo_deploy}\" — gitgateway may fail to start. Scale it up manually: ${CLI_CMD} scale --replicas=1 deployment ${mongo_deploy} -n ${namespace}"
        return 0
    fi
    wait_for_pod ${namespace} ${deployment_prefix}-mongo
    success "ADP Mongo deployment \"${mongo_deploy}\" is running. Gitgateway will migrate its data to PostgreSQL on first startup."
    info "After gitgateway is Running/Ready, you may optionally delete the Mongo deployment as it is no longer needed: ${CLI_CMD} delete deployment ${mongo_deploy} -n ${namespace} && ${CLI_CMD} delete service ${deployment_prefix}-mongo-svc -n ${namespace}"
}

# This function performs all common updates that would be required regardless of the top level CR type
# This include version update, license update if required,network policy related tasks,BAI savepoints
# Takes in three arguments
# 1. The location of the top level CR copy that was made at the beginning of this mode
# 2. The top level CR kind that was retrieved at the very beginning of the mode
# 3. The top level CR's version prior to making modifications
function common_cr_updates() {

    local current_cr_details=$1
    local current_cr_kind=$2
    local current_cr_version=$3

    # Delete unnecessary section in CR
    ${YQ_CMD} -i 'del(.status)' "${current_cr_details}"
    #${YQ_CMD} d -i ${UPGRADE_DEPLOYMENT_CONTENT_CR_TMP} metadata.annotations
    ${YQ_CMD} -i 'del(.metadata.creationTimestamp)' "${current_cr_details}"
    ${YQ_CMD} -i 'del(.metadata.generation)' "${current_cr_details}"
    ${YQ_CMD} -i 'del(.metadata.resourceVersion)' "${current_cr_details}"
    ${YQ_CMD} -i 'del(.metadata.uid)' "${current_cr_details}"
    #Validate the CR by performing a dry run
    dryrun $current_cr_details $deployment_project_name
    #applying the latest tmp CR so that we can update the kubectl.kubernetes.io/last-applied-configuration section to include any potential user edits
    ${CLI_CMD} apply -f ${current_cr_details} -n $deployment_project_name >/dev/null 2>&1

    # DBACLD-190549 - Remove "null" values from jvm_customize_options
    ${SED_COMMAND} -E '/jvm_customize_options/ { s/: "null, */: "/g; s/: null, */: /g; s/, *null, */,/g; s/, *null"/"/g; s/, *null$//g; s/"null, */"/g; s/":"null,/":"/g; }' "${current_cr_details}"

    # replace release/appVersion
    ${SED_COMMAND} "s|release: .*|release: ${CP4BA_RELEASE_BASE}|g" ${current_cr_details}
    ${SED_COMMAND} "s|appVersion: .*|appVersion: ${CP4BA_RELEASE_BASE}|g" ${current_cr_details}

    # We ask for license update only for an upgrade from 24.0.0 where we support two new user licenses-> concurrent-user and authorized-user
    if [[ "$cr_version" == "24.0.0" ]]; then
        update_license ${current_cr_details} "fncm"
    fi

    
    ${SED_COMMAND} "s/route_reencrypt: .*/route_reencrypt: $ZEN_ROUTE_REENCRYPT/g" ${current_cr_details}

    # This block of is used to merge the BAI save point into the CR.  It's only executed when it's an n-1 to n upgrade, not ifix to ifix
    # The is_ifix_to_ifix_upgrade is set to false in the determine_type_of_upgrade function.
    # if [[ ! ("$cp4ba_original_csv_ver_for_upgrade_script" == "24.0."*) ]]; then
    # Sourcing upgrade_check_status.sh and calling determine_type_of_upgrade to dertmine the type of upgrade
    info "CR Version: $cr_version"
    determine_type_of_upgrade "$cr_version"
    if [[ "$is_ifix_to_ifix_upgrade" == "false" ]]; then
        # This flag is set in upgradedeployment function
        bai_flag=$(echo "$bai_flag" | tr '[:upper:]' '[:lower:]')
        if [[ $bai_flag == "true" ]]; then
            info "Merging Flink job savepoint from \"${UPGRADE_DEPLOYMENT_BAI_TMP}\" into new version of custom resource \"${current_cr_details}\"."
            if [ -s ${UPGRADE_DEPLOYMENT_BAI_TMP} ]; then
                ${YQ_CMD} eval-all -i 'select(fi==0) *+ select(fi==1)' ${current_cr_details} ${UPGRADE_DEPLOYMENT_BAI_TMP}
                success "Merged Flink job savepoint into new version of custom resource."
            else
                warning "Not found file ${UPGRADE_DEPLOYMENT_BAI_TMP}."
            fi
        fi
    fi

    # By default we will always set the sc_enable_usage_metering flag to true and this will enable the operators to deploy the cron jobs to send usage metrics to software central
    # https://jsw.ibm.com/browse/DBACLD-225399
    ${YQ_CMD} -i ".spec.shared_configuration.sc_enable_usage_metering = true" ${current_cr_details}

    # Migrate deprecated watsonx_deployment_id to new fields based on deployment type
    # Check if workflow_assistant_configuration.watsonx_deployment_id exists
    watsonx_deployment_id=$(${YQ_CMD} '.spec.workflow_assistant_configuration.watsonx_deployment_id // ""' ${current_cr_details})
    
    if [[ -n "$watsonx_deployment_id" && "$watsonx_deployment_id" != "null" ]]; then
        info "Migrating deprecated watsonx_deployment_id field to new deployment-specific fields"
        
        # Determine deployment type by checking sc_optional_components for authoring indicators
        # Authoring environments have 'baw_authoring' or 'wfps_authoring' in sc_optional_components
        sc_optional_components=$(${YQ_CMD} '.spec.shared_configuration.sc_optional_components // ""' ${current_cr_details})
        
        is_authoring=false
        
        # Check if sc_optional_components contains baw_authoring or wfps_authoring
        if [[ "$sc_optional_components" == *"baw_authoring"* ]] || [[ "$sc_optional_components" == *"wfps_authoring"* ]]; then
            is_authoring=true
        fi
        
        # Migrate based on deployment type
        if [[ "$is_authoring" == "true" ]]; then
            # For Authoring environment: set both authoring_agent and runtime_agent with same value
            info "Detected authoring environment (baw_authoring or wfps_authoring) - setting both authoring_agent_watsonx_deployment_id and runtime_agent_watsonx_deployment_id"
            ${YQ_CMD} -i ".spec.workflow_assistant_configuration.authoring_agent_watsonx_deployment_id = \"$watsonx_deployment_id\"" ${current_cr_details}
            ${YQ_CMD} -i ".spec.workflow_assistant_configuration.runtime_agent_watsonx_deployment_id = \"$watsonx_deployment_id\"" ${current_cr_details}
        else
            # For Runtime environment: set only runtime_agent
            info "Detected runtime environment - setting runtime_agent_watsonx_deployment_id"
            ${YQ_CMD} -i ".spec.workflow_assistant_configuration.runtime_agent_watsonx_deployment_id = \"$watsonx_deployment_id\"" ${current_cr_details}
        fi
        
        # Remove the deprecated watsonx_deployment_id field
        info "Removing deprecated watsonx_deployment_id field"
        ${YQ_CMD} -i 'del(.spec.workflow_assistant_configuration.watsonx_deployment_id)' ${current_cr_details}
        
        success "Successfully migrated watsonx_deployment_id to new deployment-specific fields"
    fi

    # Function that will retrieve the network policies created in 24.0.1 by the operators and remove the references and re-apply them
    # For https://jsw.ibm.com/browse/DBACLD-167387
    # For upgrades to 26.0.0 there are paths from 24.0.0 , 25.0.0 and 25.0.1 , this means that the only time we need to update network policies and set the sc_generate_network_policies flag is for upgrades from 24.0.0.
    # 25.0.0 onwards already has the updated network policy approach
    # https://jsw.ibm.com/browse/DBACLD-232074
    if [[ "$cr_version" == "24.0.0" ]]; then
        update_network_policies "$deployment_project_name" "$current_cr_kind" "${current_cr_details}"
    fi

    # Function that retrieves the networktype and network cidr range
    # https://jsw.ibm.com/browse/DBACLD-173602
    retrieve_network_details "upgrade" "$deployment_project_name"

}

# This function performs all common cleanup activities of the yaml to make sure no parameter has incorrect syntax
function common_cr_cleanup () {
    local current_cr_details=$1
    
    ${SED_COMMAND} "s|'\"|\"|g" ${current_cr_details}
    ${SED_COMMAND} "s|\"'|\"|g" ${current_cr_details}

    # convert ssl enable true or false to meet CSV
    ${SED_COMMAND} "s/: \"True\"/: true/g" ${current_cr_details}
    ${SED_COMMAND} "s/: \"False\"/: false/g" ${current_cr_details}
    ${SED_COMMAND} "s/: \"true\"/: true/g" ${current_cr_details}
    ${SED_COMMAND} "s/: \"false\"/: false/g" ${current_cr_details}
    ${SED_COMMAND} "s/: \"Yes\"/: true/g" ${current_cr_details}
    ${SED_COMMAND} "s/: \"yes\"/: true/g" ${current_cr_details}
    ${SED_COMMAND} "s/: \"No\"/: false/g" ${current_cr_details}
    ${SED_COMMAND} "s/: \"no\"/: false/g" ${current_cr_details}

    #For DBACLD-159463 to make sure all jvm options defined and all custom annotations are strings
    add_quotes_to_values "${current_cr_details}"

    # Remove all null string
    ${SED_COMMAND} "s/: null/: /g" ${current_cr_details}

    #Function to remove the image tags from the CR if present
    remove_image_tags $current_cr_details
    if [[ $TAGS_REMOVED == "true" ]]; then
        info "IMAGE TAGS ARE REMOVED FROM THE NEW VERSION OF THE CUSTOM RESOURCE FILE."
        printf "\n"
    fi
    printf "\n"
}

#manages the shutdown of the CP4BA operator and retrieves existing CR's,to prevent conflicts during the upgrade
#handles their processing based on their ownership.
function upgrade_deployment(){
    local deployment_project_name=$1
    local operator_project_name=$2
    local allow_direct_upgrade=$3
    local top_level_cr_kind=$4
    local top_level_cr_name=$5
    local top_level_cr_details_location=$6
    # local cr_version=$4
    mkdir -p ${UPGRADE_DEPLOYMENT_CR} >/dev/null 2>&1
    # trap 'startup_operator $deployment_project_name' EXIT, to preventing issues during the upgrade
    shutdown_operator $operator_project_name
    source ${CUR_DIR}/helper/upgrade/upgrade_check_status.sh

    # Using the retrieve_custom_resource details the top level CR details are already set, the function also copies the CR to a certain location
    # For content the CR is created in UPGRADE_DEPLOYMENT_CONTENT_CR_TMP
    if [[ "$top_level_cr_kind" == "content" ]]; then
        # cr_metaname is the deployment prefix used to construct operand deployment names
        # (e.g. icp4adeploy-cpe-deploy, icp4adeploy-mongo-deploy).  It must be set from
        # top_level_cr_name here so scale_down_content_pattern_resources and
        # scale_up_adp_mongo_for_migration construct the correct Kubernetes resource names.
        cr_metaname=$top_level_cr_name

        cr_version=$(${YQ_CMD} '.spec.appVersion' "$top_level_cr_details_location")
        # Update the appVersion in foundationrequest
        # Updates the 'appVersion' field in the FoundationRequest CR to match the new release version of CP4BA
        foundationrequest_cr_name=$(${CLI_CMD} get foundationrequest -n $deployment_project_name --no-headers --ignore-not-found | awk '{print $1}')
        ${CLI_CMD} patch foundationrequest $foundationrequest_cr_name -n $deployment_project_name -p '{"spec":{"appVersion":"$CP4BA_RELEASE_BASE"}}' --type=merge >/dev/null 2>&1
        
        # Backup existing content CR, creates a backup of the existing content Custom Resource to avoid data loss
        mkdir -p ${UPGRADE_DEPLOYMENT_CR_BAK}
        ${COPY_CMD} -rf ${top_level_cr_details_location} ${UPGRADE_DEPLOYMENT_CONTENT_CR_BAK}

        info "Merging existing CP4BA Content Custom Resource with new version ($CP4BA_RELEASE_BASE)"

        #IF BAI is an optional component then set the bai_flag to true so that we can create savepoints in common_cr_updates
        bai_flag=`${YQ_CMD} ".spec.content_optional_components.bai" "$top_level_cr_details_location"`
        
        # This function performs all common updates that would be required regardless of the top level CR type
        common_cr_updates "${top_level_cr_details_location}" "$top_level_cr_kind" "$cr_version"

        # Disable sc_content_initialization/sc_content_verification
        if [[ $olm_cr_flag == "No" ]]; then
            ${YQ_CMD} -i '.spec.shared_configuration.sc_content_initialization = false' ${top_level_cr_details_location}
            ${YQ_CMD} -i '.spec.shared_configuration.sc_content_verification = false' ${top_level_cr_details_location}
        else
            ${YQ_CMD} -i '.spec.shared_configuration.olm_sc_content_initialization = false' ${top_level_cr_details_location}
            ${YQ_CMD} -i '.spec.shared_configuration.olm_sc_content_verification = false' ${top_level_cr_details_location}
        fi
        ${YQ_CMD} -i 'del(.spec.shared_configuration.sc_content_initialization_update_scim)' "${top_level_cr_details_location}"

        # remove initialize_configuration/verify_configuration, no longer required in the new version of CP4BA
        info "Remove initialize_configuration/verify_configuration from new version of CP4BA Content Custom Resource"
        ${YQ_CMD} -i 'del(.spec.verify_configuration)' "${top_level_cr_details_location}"
        ${YQ_CMD} -i 'del(.spec.initialize_configuration)' "${top_level_cr_details_location}"
        

        # Function to detect if the Domain is configured with SCIM
        # https://jsw.ibm.com/browse/DBACLD-157386 https://jsw.ibm.com/browse/DBACLD-178101 https://jsw.ibm.com/browse/DBACLD-177550 https://jsw.ibm.com/browse/DBACLD-177742
        # No longer required in 26.0.0 as this solution was required for deployments upgraded from 21.0.3/22.0.2 and we do not support that scenario in 26.0.0
        # detect_scim_configuration "$deployment_project_name" "ibm-cp4ba-content-shared-info" "${UPGRADE_DEPLOYMENT_CONTENT_CR_TMP}"
        
        #Scaling down Content Pattern Resources including CPE, CPE watcher, Navigator, Navigator Watcher, CSS
        scale_down_content_pattern_resources "$deployment_project_name" "$cr_metaname"

        # Scale up the ADP Mongo deployment so the 26.0.0 gitgateway can migrate its data to PostgreSQL.
        # The 26.0.0-IF001+ operator no longer manages mongo-deploy; gitgateway needs Mongo live at startup
        # to perform the one-time MongoDB→PostgreSQL migration before the operator cleans Mongo up.
        # Gate: 24.x→26.0.0 upgrade + document_processing_designer installed.
        _content_opt_components=$(${YQ_CMD} '.spec.content_optional_components // ""' "${top_level_cr_details_location}" 2>/dev/null)
        if [[ "${_content_opt_components}" == *"document_processing_designer"* ]]; then
            scale_up_adp_mongo_for_migration "$deployment_project_name" "$cr_metaname"
        fi
        
        # This function performs all common cleanup activities of the yaml to make sure no parameter has incorrect syntax
        common_cr_cleanup "${top_level_cr_details_location}"
        
        # Copy the modified CR to the location where the script will tell the user to apply it from
        ${COPY_CMD} -rf ${top_level_cr_details_location} ${UPGRADE_DEPLOYMENT_CONTENT_CR}
            

        # info "Remove initialize_configuration/verify_configuration from CP4BA Content Custom Resource"
        # ${CLI_CMD} patch content $content_cr_name -n $deployment_project_name --type=json -p='[{"op": "remove", "path": "/spec/initialize_configuration"}]' >/dev/null 2>&1
        # ${CLI_CMD} patch content $content_cr_name -n $deployment_project_name --type=json -p='[{"op": "remove", "path": "/spec/verify_configuration"}]' >/dev/null 2>&1
        info "The new version ($CP4BA_RELEASE_BASE) of CP4BA Content Custom Resource is created and saved at ${UPGRADE_DEPLOYMENT_CONTENT_CR}"
       
        
        
        # Displaying final steps before ending UpgradeDeployment Mode
        initialize_cfg_flag=$(${CLI_CMD} get $top_level_cr_kind $top_level_cr_name -n $deployment_project_name --no-headers --ignore-not-found -o 'jsonpath={.spec.initialize_configuration}') >/dev/null 2>&1
        verify_cfg_flag=$(${CLI_CMD} get $top_level_cr_kind $top_level_cr_name -n $deployment_project_name --no-headers --ignore-not-found -o 'jsonpath={.spec.verify_configuration}') >/dev/null 2>&1

        printf "\n"
        echo "${YELLOW_TEXT}[NEXT ACTION]:${RESET_TEXT}"
        step_num=1
        printf "\n"

        echo "${YELLOW_TEXT}- Refer to the Knowledge Center: \"Updating the custom resource for each capability in your deployment\" topic to complete REQUIRED steps for the installed pattern(s)."
        echo "  - [https://www.ibm.com/docs/en/cloud-paks/cp-biz-automation/$CP4BA_RELEASE_BASE?topic=uycpdf2-updating-custom-resource-each-capability-in-your-deployment] ${RESET_TEXT}"
        echo "${YELLOW_TEXT}- After reviewing or modifying the custom resource file \"${UPGRADE_DEPLOYMENT_CONTENT_CR}\", you need to follow the steps below to upgrade this CP4BA deployment.${RESET_TEXT}"

        if [[ "$FNCM_LICENSE_UPDATE_FAILED" == "true" ]]; then
            echo
            echo "${RED_TEXT}[IMPORTANT]: The script failed to update the sc_deployment_fncm_license parameter in the Custom Resource file.You must review the newly generated Custom Resource file and manually update the license value before proceeding with the next steps.${RESET_TEXT}"
            echo
        fi
        # As a part of DBACLD-149126 solution we no longer needed the user to patch or annotate the custom resource file
        echo "  - STEP ${step_num} ${RED_TEXT}(Required)${RESET_TEXT}:${GREEN_TEXT} # ${CLI_CMD} apply -f ${UPGRADE_DEPLOYMENT_CONTENT_CR} -n $deployment_project_name${RESET_TEXT}" && step_num=$((step_num + 1))

        printf "\n"
        echo "${YELLOW_TEXT}- How to check the overall upgrade status for CP4BA/zenService/IM.${RESET_TEXT}"
        echo "${YELLOW_TEXT}  [TIPS]: ${RESET_TEXT}The [upgradeDeploymentStatus] option will start CP4BA operators automatically after zenService ready."
        CUR_DIR=$(realpath "$(dirname "${BASH_SOURCE[0]}")")
        SCRIPTS_DIR="$(realpath "$CUR_DIR/../..")"
        echo "  - STEP ${step_num} ${RED_TEXT}(Required)${RESET_TEXT}: ${GREEN_TEXT}# ${SCRIPTS_DIR}/cp4a-deployment.sh -m upgradeDeploymentStatus -n $deployment_project_name${RESET_TEXT}"
        printf "\n"
        echo "${YELLOW_TEXT}[ATTENTION]: The zenService will be ready in about 120 minutes after the new version ($CP4BA_RELEASE_BASE) of the CP4BA custom resource was applied.${RESET_TEXT}"
    fi


    # Retrieve existing WfPSRuntime CR, to get list of existing WfPSRuntime cr's in the specified namespace
    exist_wfps_cr_array=($(${CLI_CMD} get WfPSRuntime -n $deployment_project_name --no-headers --ignore-not-found | awk '{print $1}'))
    if [ ! -z $exist_wfps_cr_array ]; then
        for item in "${exist_wfps_cr_array[@]}"
        do
            info "Retrieving existing IBM CP4BA Workflow Process Service (Kind: WfPSRuntime.icp4a.ibm.com) Custom Resource: \"${item}\""
            cr_type="WfPSRuntime"
            cr_metaname=$(${CLI_CMD} get $cr_type ${item} -n $deployment_project_name -o yaml | ${YQ_CMD} '.metadata.name' -)
            UPGRADE_DEPLOYMENT_WFPS_CR=${UPGRADE_DEPLOYMENT_CR}/wfps_${cr_metaname}.yaml
            UPGRADE_DEPLOYMENT_WFPS_CR_TMP=${UPGRADE_DEPLOYMENT_CR}/.wfps_${cr_metaname}_tmp.yaml
            UPGRADE_DEPLOYMENT_WFPS_CR_BAK=${UPGRADE_DEPLOYMENT_CR_BAK}/wfps_cr_${cr_metaname}_backup.yaml

            ${CLI_CMD} get $cr_type ${item} -n $deployment_project_name -o yaml > ${UPGRADE_DEPLOYMENT_WFPS_CR_TMP}

            # Backup existing WfPSRuntime CR, make backup of the WfPSRuntime custom resource to preserve its original state before applying any upgrades
            mkdir -p ${UPGRADE_DEPLOYMENT_CR_BAK}
            ${COPY_CMD} -rf ${UPGRADE_DEPLOYMENT_WFPS_CR_TMP} ${UPGRADE_DEPLOYMENT_WFPS_CR_BAK}

            info "Merging existing IBM CP4BA Workflow Process Service custom resource: \"${item}\" with new version ($CP4BA_RELEASE_BASE)"
            # Delete unnecessary section in CR
            ${YQ_CMD} -i 'del(.status)' "${UPGRADE_DEPLOYMENT_WFPS_CR_TMP}"
            #${YQ_CMD} d -i ${UPGRADE_DEPLOYMENT_WFPS_CR_TMP} metadata.annotations
            ${YQ_CMD} -i 'del(.metadata.creationTimestamp)' "${UPGRADE_DEPLOYMENT_WFPS_CR_TMP}"
            ${YQ_CMD} -i 'del(.metadata.generation)' "${UPGRADE_DEPLOYMENT_WFPS_CR_TMP}"
            ${YQ_CMD} -i 'del(.metadata.resourceVersion)' "${UPGRADE_DEPLOYMENT_WFPS_CR_TMP}"
            ${YQ_CMD} -i 'del(.metadata.uid)' "${UPGRADE_DEPLOYMENT_WFPS_CR_TMP}"

            # replace release/appVersion BEFORE applying the CR so that the cluster
            # receives the correct appVersion on the first (and only necessary) apply.
            # Previously this sed ran after the apply, leaving appVersion: 24.0.0 in
            # the first kubectl apply and relying on a second apply at line 1181 to
            # correct it.  Moving it here fixes the ordering.
            # ${SED_COMMAND} "s|release: .*|release: ${CP4BA_RELEASE_BASE}|g" ${UPGRADE_DEPLOYMENT_PFS_CR_TMP}
            ${SED_COMMAND} "s|appVersion: .*|appVersion: ${CP4BA_RELEASE_BASE}|g" ${UPGRADE_DEPLOYMENT_WFPS_CR_TMP}

            # Remove stale image tags so the operator uses the built-in digest for the new version.
            # A pinned spec.image.tag (e.g. 25.0.0-IF005-amd64) prevents the operator from rolling
            # pods to the upgraded image. Same logic is applied to Content/ICP4ACluster CRs via
            # common_cr_cleanup(). WfPS CR does not go through common_cr_cleanup() so we call it here.
            remove_image_tags ${UPGRADE_DEPLOYMENT_WFPS_CR_TMP}

            # Scale up wfps operator deployment to enable webhook for CR validation
            ${CLI_CMD} scale --replicas=1 deployment ibm-cp4a-wfps-operator -n $operator_project_name >/dev/null 2>&1
            wait_for_pod $operator_project_name ibm-cp4a-wfps-operator
            #Validate the CR by performing a dry run
            #additional sleep time added so that we can make sure that the wfps operator is completely ready prior to applying new CR
            # DBACLD-190320
            sleep 25
            dryrun $UPGRADE_DEPLOYMENT_WFPS_CR_TMP $deployment_project_name
            #applying the latest tmp CR so that we can update the kubectl.kubernetes.io/last-applied-configuration section to include any potential user edits
            ${CLI_CMD} apply -f ${UPGRADE_DEPLOYMENT_WFPS_CR_TMP} -n $deployment_project_name >/dev/null 2>&1
            # Scale down wfps operator deployment again
            ${CLI_CMD} scale --replicas=0 deployment ibm-cp4a-wfps-operator -n $operator_project_name >/dev/null 2>&1


            # # change failureThreshold/periodSeconds for WfPS before upgrade
            # ${YQ_CMD} w -i ${UPGRADE_DEPLOYMENT_WFPS_CR_TMP} spec.node.probe.startupProbe.failureThreshold 800
            # ${YQ_CMD} w -i ${UPGRADE_DEPLOYMENT_WFPS_CR_TMP} spec.node.probe.startupProbe.periodSeconds 10
            
            # Function that will retrieve the network policies created in 24.0.1 by the operators and remove the references and re-apply them 
            # For https://jsw.ibm.com/browse/DBACLD-167387
            # not needed as we include WfPSRuntime as part of the CP4BA related CRs in the network policy script
            #update_network_policies $deployment_project_name "WfPSRuntime" ${UPGRADE_DEPLOYMENT_WFPS_CR_TMP}

            ${SED_COMMAND} "s|'\"|\"|g" ${UPGRADE_DEPLOYMENT_WFPS_CR_TMP}
            ${SED_COMMAND} "s|\"'|\"|g" ${UPGRADE_DEPLOYMENT_WFPS_CR_TMP}

            # convert ssl enable true or false to meet CSV
            ${SED_COMMAND} "s/: \"True\"/: true/g" ${UPGRADE_DEPLOYMENT_WFPS_CR_TMP}
            ${SED_COMMAND} "s/: \"False\"/: false/g" ${UPGRADE_DEPLOYMENT_WFPS_CR_TMP}
            ${SED_COMMAND} "s/: \"true\"/: true/g" ${UPGRADE_DEPLOYMENT_WFPS_CR_TMP}
            ${SED_COMMAND} "s/: \"false\"/: false/g" ${UPGRADE_DEPLOYMENT_WFPS_CR_TMP}
            ${SED_COMMAND} "s/: \"Yes\"/: true/g" ${UPGRADE_DEPLOYMENT_WFPS_CR_TMP}
            ${SED_COMMAND} "s/: \"yes\"/: true/g" ${UPGRADE_DEPLOYMENT_WFPS_CR_TMP}
            ${SED_COMMAND} "s/: \"No\"/: false/g" ${UPGRADE_DEPLOYMENT_WFPS_CR_TMP}
            ${SED_COMMAND} "s/: \"no\"/: false/g" ${UPGRADE_DEPLOYMENT_WFPS_CR_TMP}

            #For DBACLD-159463 to make sure all jvm options defined and all custom annotations are strings
            add_quotes_to_values "${UPGRADE_DEPLOYMENT_WFPS_CR_TMP}"

            # Remove all null string
            ${SED_COMMAND} "s/: null/: /g" ${UPGRADE_DEPLOYMENT_WFPS_CR_TMP}

            ${COPY_CMD} -rf ${UPGRADE_DEPLOYMENT_WFPS_CR_TMP} ${UPGRADE_DEPLOYMENT_WFPS_CR}
            success "Completed to merge existing IBM CP4BA Workflow Process Service custom resource with new version ($CP4BA_RELEASE_BASE)"

            # Check IBM CP4BA Workflow Process Service operator upgrade status
            echo "****************************************************************************"
            info "Checking for IBM CP4BA Workflow Process Service operator pod initialization"
            maxRetry=10
            for ((retry=0;retry<=${maxRetry};retry++)); do
                isReady=$(${CLI_CMD} get csv ibm-cp4a-wfps-operator.$CP4BA_CSV_VERSION -n $operator_project_name -o jsonpath='{.status.phase}')
                # isReady=$(kubectl exec $cpe_pod_name -c ${meta_name}-cpe-deploy -n $deployment_project_name -- cat /opt/ibm/version.txt |grep -F "P8 Content Platform Engine $CP4BA_RELEASE_BASE")
                if [[ $isReady != "Succeeded" ]]; then
                    if [[ $retry -eq ${maxRetry} ]]; then
                    printf "\n"
                    warning "Timeout waiting for IBM CP4BA Workflow Process Service operator to start"
                    printf '%b\n' "\x1B[1mCheck the status of Pod by issuing the following command:\x1B[0m"
                    echo "${CLI_CMD} describe pod $(${CLI_CMD} get pod -n $operator_project_name|grep ibm-cp4a-wfps-operator|awk '{print $1}') -n $operator_project_name"
                    printf "\n"
                    printf '%b\n' "\x1B[1mCheck the status of ReplicaSet by issuing the following command:\x1B[0m"
                    echo "${CLI_CMD} describe rs $(${CLI_CMD} get rs -n $operator_project_name|grep ibm-cp4a-wfps-operator|awk '{print $1}') -n $operator_project_name"
                    printf "\n"
                    exit 1
                    else
                    sleep 30
                    printf '%s' "..."
                    continue
                    fi
                elif [[ $isReady == "Succeeded" ]]; then
                    pod_name=$(${CLI_CMD} get pod -l=name=ibm-cp4a-wfps-operator -n $operator_project_name -o 'custom-columns=NAME:.metadata.name,PHASE:.status.phase,READY:.status.containerStatuses[0].ready,DELETED:.metadata.deletionTimestamp' --no-headers | grep 'Running' | grep 'true' | grep '<none>' | head -1 | awk '{print $1}')
                    if [ -z $pod_name ]; then
                        warning "IBM CP4BA Workflow Process Service operator pod is NOT running"
                        info "Starting IBM CP4BA Workflow Process Service operator"
                        ${CLI_CMD} scale --replicas=1 deployment ibm-cp4a-wfps-operator -n $operator_project_name >/dev/null 2>&1
                        if [ $? -eq 0 ]; then
                            sleep 1
                        else
                            fail "Failed to scale up \"IBM CP4BA Workflow Process Service\" operator"
                        fi
                    else
                        success "IBM CP4BA Workflow Process Service operator is running"
                        break
                    fi
                fi
            done
            echo "****************************************************************************"


            info "Apply the new version ($CP4BA_RELEASE_BASE) of IBM CP4BA Workflow Process Service custom resource"
            ${CLI_CMD} apply -f ${UPGRADE_DEPLOYMENT_WFPS_CR} -n $deployment_project_name >/dev/null 2>&1
            if [ $? -ne 0 ]; then
                fail "IBM CP4BA Workflow Process Service custom resource update failed"
                exit 1
            else
                echo "Done!"

                printf "\n"
                # echo "${YELLOW_TEXT}[NEXT ACTION]${RESET_TEXT}:"
                # msgB "Run \"cp4a-deployment.sh -m upgradeDeploymentStatus -n $deployment_project_name\" to get overview upgrade status for IBM CP4BA Workflow Process Service"
            fi
        done
    fi

    # Update appVersion in ProcessFederationServer CR if present.
    # ProcessFederationServer has its own spec.appVersion field (separate CR kind)
    # and is not handled by the WfPSRuntime loop or common_cr_updates() above.
    exist_pfs_cr_array=($(${CLI_CMD} get ProcessFederationServer -n $deployment_project_name --no-headers --ignore-not-found | awk '{print $1}'))
    if [[ ! -z $exist_pfs_cr_array ]]; then
        for item in "${exist_pfs_cr_array[@]}"
        do
            info "Updating appVersion in ProcessFederationServer CR: \"${item}\""
            ${CLI_CMD} patch ProcessFederationServer ${item} -n $deployment_project_name \
                --type merge \
                -p "{\"spec\":{\"appVersion\":\"${CP4BA_RELEASE_BASE}\"}}" >/dev/null 2>&1
            if [[ $? -eq 0 ]]; then
                success "ProcessFederationServer \"${item}\" appVersion updated to ${CP4BA_RELEASE_BASE}"
            else
                warning "Failed to patch ProcessFederationServer \"${item}\" appVersion — operator may not be running"
            fi
        done
    fi

    # Using the retrieve_custom_resource details the top level CR details are already set, the function also copies the CR to a certain location
    # For icp4acluster the CR is created in UPGRADE_DEPLOYMENT_ICP4ACLUSTER_CR_TMP
    if [[ "$top_level_cr_kind" == "icp4acluster" ]]; then
        # cr_metaname is the deployment prefix used to construct operand deployment names
        # (e.g. icp4adeploy-cpe-deploy, icp4adeploy-mongo-deploy).  It must be set from
        # top_level_cr_name here so scale_down_content_pattern_resources and
        # scale_up_adp_mongo_for_migration construct the correct Kubernetes resource names.
        cr_metaname=$top_level_cr_name

        cr_version=$(${YQ_CMD} '.spec.appVersion' "$top_level_cr_details_location")
        convert_olm_cr "${top_level_cr_details_location}"
        if [[ $olm_cr_flag == "No" ]]; then
            existing_pattern_list=""
            existing_opt_component_list=""

            EXISTING_PATTERN_ARR=()
            EXISTING_OPT_COMPONENT_ARR=()
            existing_pattern_list=`${YQ_CMD} ".spec.shared_configuration.sc_deployment_patterns" "$top_level_cr_details_location"`
            existing_opt_component_list=`${YQ_CMD} ".spec.shared_configuration.sc_optional_components" "$top_level_cr_details_location"`

            OIFS=$IFS
            IFS=',' read -r -a EXISTING_PATTERN_ARR <<< "$existing_pattern_list"
            IFS=',' read -r -a EXISTING_OPT_COMPONENT_ARR <<< "$existing_opt_component_list"
            IFS=$OIFS
        fi

        #IF BAI is an optional component then set the bai_flag to true so that we can create savepoints in common_cr_updates
        if [[ " ${EXISTING_OPT_COMPONENT_ARR[@]} " =~ "bai" ]]; then
            bai_flag="true"
        fi

        # Backup existing icp4acluster CR
        mkdir -p ${UPGRADE_DEPLOYMENT_CR_BAK}
        ${COPY_CMD} -rf ${top_level_cr_details_location} ${UPGRADE_DEPLOYMENT_ICP4ACLUSTER_CR_BAK}

        info "Updating the existing CP4BA Custom Resource with new version ($CP4BA_RELEASE_BASE)"
        
        # This function performs all common updates that would be required regardless of the top level CR type
        common_cr_updates "${top_level_cr_details_location}" "$top_level_cr_kind" "$cr_version"

        # Add "dc_adp_datasource" into datasource_configuration for supported upgrade sources.
        # Use cp4ba_original_csv_ver_for_upgrade_script for IFIX-aware source version checks because cr_version only contains the base release.
        upgrade_scenario=""
        cpe_database_servername=""
        allow_postgres_edb_for_2600_upgrade="false"

        # Helper: detect whether an EDB (24.x, cluster.postgresql.k8s.enterprisedb.io) or CNPG
        # (26.x, cluster.pg.ibm.com) PostgreSQL instance named $EDB_INSTANCE_CP4BA_NAME exists.
        # Sets local variable pg_instance_found to "cnpg", "edb", or "".
        _detect_pg_instance() {
            local ns=$1
            local inst=$2
            local cnpg_cr edb_cr
            cnpg_cr=$( ${CLI_CMD} get cluster.pg.ibm.com -n "$ns" --no-headers --ignore-not-found "$inst" 2>/dev/null | awk '{print $1}' )
            if [[ "$cnpg_cr" == "$inst" ]]; then
                pg_instance_found="cnpg"
                return
            fi
            edb_cr=$( ${CLI_CMD} get cluster.postgresql.k8s.enterprisedb.io -n "$ns" --no-headers --ignore-not-found "$inst" 2>/dev/null | awk '{print $1}' )
            if [[ "$edb_cr" == "$inst" ]]; then
                pg_instance_found="edb"
                return
            fi
            pg_instance_found=""
        }

        # Shared non-postgres db_choice for ADPGG + DICMS (asked once, reused for all three datasources)
        NON_POSTGRES_UPGRADE_DB_CHOICE=""

        if [[ $cr_version != "${CP4BA_RELEASE_BASE}" && "${CP4BA_RELEASE_BASE}" == "26.0.0" && (" ${EXISTING_PATTERN_ARR[@]} " =~ "document_processing") && (" ${EXISTING_OPT_COMPONENT_ARR[@]} " =~ "document_processing_designer") ]] && check_adp_ads_version_to_migrate_postgres "${cp4ba_original_csv_ver_for_upgrade_script}"; then
            ${YQ_CMD} -i '.spec.datasource_configuration.dc_adp_datasource.dc_database_type = "postgresql"' $top_level_cr_details_location
            ${YQ_CMD} -i '.spec.datasource_configuration.dc_adp_datasource.database_name = "adpggdb"' $top_level_cr_details_location

            info "Determining if PostgreSQL \"$EDB_INSTANCE_CP4BA_NAME\" is installed for IBM Cloud Pak for Business Automation."
            pg_instance_found=""
            _detect_pg_instance "$deployment_project_name" "$EDB_INSTANCE_CP4BA_NAME"
            if [[ -n "$pg_instance_found" ]]; then
                info "Found PostgreSQL instance \"$EDB_INSTANCE_CP4BA_NAME\" ($pg_instance_found)"
                upgrade_scenario="edb-already-exists"  # CNPG/EDB exists
                allow_postgres_edb_for_2600_upgrade="true"
                ${YQ_CMD} -i '.spec.datasource_configuration.dc_adp_datasource.database_servername = "postgres-cp4ba-rw.{{ meta.namespace }}.svc"' $top_level_cr_details_location
                ${YQ_CMD} -i '.spec.datasource_configuration.dc_adp_datasource.database_port = "5432"' $top_level_cr_details_location
                ${YQ_CMD} -i '.spec.datasource_configuration.dc_adp_datasource.database_ssl_secret_name = "{{ meta.name }}-pg-client-cert-secret"' $top_level_cr_details_location
                ${YQ_CMD} -i '.spec.datasource_configuration.dc_adp_datasource.dc_use_postgres = true' $top_level_cr_details_location
            else
                info "Not found PostgreSQL instance \"$EDB_INSTANCE_CP4BA_NAME\""
                cpe_database_type=`${YQ_CMD} ".spec.datasource_configuration.dc_gcd_datasource.dc_database_type" "$top_level_cr_details_location"`
                if [[ $cpe_database_type == "postgresql" ]]; then
                    # CP4BA is using external Postgres, so ADPGG will use the same external Postgres
                    upgrade_scenario="external-postgres"  # External Postgres is used
                    cpe_database_servername=`${YQ_CMD} ".spec.datasource_configuration.dc_gcd_datasource.database_servername" "$top_level_cr_details_location"`
                    cpe_database_port=`${YQ_CMD} ".spec.datasource_configuration.dc_gcd_datasource.database_port" "$top_level_cr_details_location"`
                    cpe_database_ssl_secret_name=`${YQ_CMD} ".spec.datasource_configuration.dc_gcd_datasource.database_ssl_secret_name" "$top_level_cr_details_location"`
                    ${YQ_CMD} -i ".spec.datasource_configuration.dc_adp_datasource.database_servername = \"$cpe_database_servername\"" $top_level_cr_details_location
                    ${YQ_CMD} -i ".spec.datasource_configuration.dc_adp_datasource.database_port = \"$cpe_database_port\"" $top_level_cr_details_location
                    ${YQ_CMD} -i ".spec.datasource_configuration.dc_adp_datasource.database_ssl_secret_name = \"$cpe_database_ssl_secret_name\"" $top_level_cr_details_location
                    ${YQ_CMD} -i '.spec.datasource_configuration.dc_adp_datasource.dc_use_postgres = false' $top_level_cr_details_location
                    # Carry the schema used at install time forward into the CR.
                    apply_adpgg_schema_from_gitsvc_secret "$top_level_cr_name" "$deployment_project_name" "$top_level_cr_details_location"
                else
                    # CP4BA is not using Postgres — prompt user to choose external Postgres or CNPG for ADPGG and DICMS
                    upgrade_scenario="non-postgres"  # External Postgres for ADPGG when CPE is on non-Postgres DB
                    warning "CP4BA is using non-PostgreSQL database (DB2/Oracle/MSSQL)."

                    if ! handle_non_postgres_upgrade_scenario "ADP Gitgateway and DICMS Designer/Runtime" "dc_adp_datasource" "$top_level_cr_details_location" "false"; then
                        exit 1
                    fi
                    # NON_POSTGRES_UPGRADE_DB_CHOICE is now set by handle_non_postgres_upgrade_scenario
                    # If the user chose external Postgres, carry the schema from the gitsvc secret into the CR.
                    if [[ "$NON_POSTGRES_UPGRADE_DB_CHOICE" == "external-postgres" ]]; then
                        apply_adpgg_schema_from_gitsvc_secret "$top_level_cr_name" "$deployment_project_name" "$top_level_cr_details_location"
                    fi
                fi
            fi
        fi

        # For upgrades from any prior version (24.x, 25.x, …): if dc_adp_datasource already
        # exists in the CR with dc_use_postgres=false (external PG) and database_schema is
        # absent or empty, read the schema from the gitsvc secret and patch it in.
        if [[ $cr_version != "${CP4BA_RELEASE_BASE}" && "${CP4BA_RELEASE_BASE}" == "26.0.0" \
            && (" ${EXISTING_PATTERN_ARR[@]} " =~ "document_processing") \
            && (" ${EXISTING_OPT_COMPONENT_ARR[@]} " =~ "document_processing_designer") ]]; then
            _adp_dc_use_postgres=$(${YQ_CMD} '.spec.datasource_configuration.dc_adp_datasource.dc_use_postgres' "$top_level_cr_details_location" 2>/dev/null)
            _adp_dc_schema=$(${YQ_CMD} '.spec.datasource_configuration.dc_adp_datasource.database_schema' "$top_level_cr_details_location" 2>/dev/null)
            # Only patch when: datasource exists (dc_use_postgres is set) AND uses external PG AND schema is absent/null/empty
            if [[ "$_adp_dc_use_postgres" == "false" && ( -z "$_adp_dc_schema" || "$_adp_dc_schema" == "null" ) ]]; then
                apply_adpgg_schema_from_gitsvc_secret "$top_level_cr_name" "$deployment_project_name" "$top_level_cr_details_location"
            fi
        fi

        # 24.0.1
        # Add "dc_ads_designer_datasource" into datasource_configuration if upgrading from 24.0.1 and existing pattern is decisions_ads and optional component is ads_designer
        icn_database_servername=""
        if [[ $cr_version != "${CP4BA_RELEASE_BASE}" && "${CP4BA_RELEASE_BASE}" == "26.0.0" && (" ${EXISTING_PATTERN_ARR[@]} " =~ "decisions_ads") && (" ${EXISTING_OPT_COMPONENT_ARR[@]} " =~ "ads_designer") ]] && check_adp_ads_version_to_migrate_postgres "${cp4ba_original_csv_ver_for_upgrade_script}"; then
            ${YQ_CMD} -i '.spec.datasource_configuration.dc_ads_designer_datasource.dc_database_type = "postgresql"' $top_level_cr_details_location
            ${YQ_CMD} -i '.spec.datasource_configuration.dc_ads_designer_datasource.database_name = "adsdesignerdb"' $top_level_cr_details_location
            ${YQ_CMD} -i '.spec.datasource_configuration.dc_ads_designer_datasource.current_schema = "adsdesigner"' $top_level_cr_details_location
            ${YQ_CMD} -i '.spec.datasource_configuration.dc_ads_designer_datasource.database_instance_secret = "ibm-ads-designer-database"' $top_level_cr_details_location
            info "Determining if PostgreSQL \"$EDB_INSTANCE_CP4BA_NAME\" is installed for IBM Cloud Pak for Business Automation."
            pg_instance_found=""
            _detect_pg_instance "$deployment_project_name" "$EDB_INSTANCE_CP4BA_NAME"
            if [[ -n "$pg_instance_found" ]]; then
                info "Found PostgreSQL instance \"$EDB_INSTANCE_CP4BA_NAME\" ($pg_instance_found)"
                upgrade_scenario="edb-already-exists"  # CNPG/EDB exists
                allow_postgres_edb_for_2600_upgrade="true"
                ${YQ_CMD} -i '.spec.datasource_configuration.dc_ads_designer_datasource.database_servername = "postgres-cp4ba-rw.{{ meta.namespace }}.svc"' $top_level_cr_details_location
                ${YQ_CMD} -i '.spec.datasource_configuration.dc_ads_designer_datasource.database_port = "5432"' $top_level_cr_details_location
                ${YQ_CMD} -i '.spec.datasource_configuration.dc_ads_designer_datasource.ssl_secret_name = "{{ meta.name }}-pg-client-cert-secret"' $top_level_cr_details_location
                ${YQ_CMD} -i '.spec.datasource_configuration.dc_ads_designer_datasource.dc_use_postgres = true' $top_level_cr_details_location
            else
                info "Not found PostgreSQL instance \"$EDB_INSTANCE_CP4BA_NAME\""
                icn_database_type=`${YQ_CMD} ".spec.datasource_configuration.dc_icn_datasource.dc_database_type" "$top_level_cr_details_location"`
                if [[ $icn_database_type == "postgresql" ]]; then
                    # ICN is using external Postgres, so DICMS will use the same external Postgres
                    upgrade_scenario="external-postgres"  # External Postgres is used
                    icn_database_servername=`${YQ_CMD} ".spec.datasource_configuration.dc_icn_datasource.database_servername" "$top_level_cr_details_location"`
                    icn_database_port=`${YQ_CMD} ".spec.datasource_configuration.dc_icn_datasource.database_port" "$top_level_cr_details_location"`
                    icn_database_ssl_secret_name=`${YQ_CMD} ".spec.datasource_configuration.dc_icn_datasource.database_ssl_secret_name" "$top_level_cr_details_location"`
                    database_ssl_enabled=`${YQ_CMD} ".spec.datasource_configuration.dc_ssl_enabled" "$top_level_cr_details_location"`
                    ${YQ_CMD} -i ".spec.datasource_configuration.dc_ads_designer_datasource.database_servername = \"$icn_database_servername\"" $top_level_cr_details_location
                    ${YQ_CMD} -i ".spec.datasource_configuration.dc_ads_designer_datasource.database_port = \"$icn_database_port\"" $top_level_cr_details_location
                    ${YQ_CMD} -i ".spec.datasource_configuration.dc_ads_designer_datasource.ssl_enabled = \"$database_ssl_enabled\"" $top_level_cr_details_location
                    ${YQ_CMD} -i '.spec.datasource_configuration.dc_ads_designer_datasource.ssl_mode = "verify-full"' $top_level_cr_details_location
                    ${YQ_CMD} -i ".spec.datasource_configuration.dc_ads_designer_datasource.ssl_secret_name = \"$icn_database_ssl_secret_name\"" $top_level_cr_details_location
                    ${YQ_CMD} -i '.spec.datasource_configuration.dc_ads_designer_datasource.dc_use_postgres = false' $top_level_cr_details_location
                else
                    # CP4BA is not using Postgres — reuse the choice already made for ADPGG (or ask if ADPGG block was skipped)
                    upgrade_scenario="non-postgres"  # External Postgres for DICMS when ICN is on non-Postgres DB
                    warning "CP4BA is using non-PostgreSQL database (DB2/Oracle/MSSQL)."

                    if ! handle_non_postgres_upgrade_scenario "DICMS Designer" "dc_ads_designer_datasource" "$top_level_cr_details_location" "true" "$NON_POSTGRES_UPGRADE_DB_CHOICE"; then
                        exit 1
                    fi
                    # NON_POSTGRES_UPGRADE_DB_CHOICE already set by handle_non_postgres_upgrade_scenario; keep for runtime block
                fi
            fi
        fi

        # Add "dc_ads_runtime_datasource" into datasource_configuration for supported upgrade sources
        if [[ $cr_version != "${CP4BA_RELEASE_BASE}" && "${CP4BA_RELEASE_BASE}" == "26.0.0" && (" ${EXISTING_PATTERN_ARR[@]} " =~ "decisions_ads") && (" ${EXISTING_OPT_COMPONENT_ARR[@]} " =~ "ads_runtime") ]] && check_adp_ads_version_to_migrate_postgres "${cp4ba_original_csv_ver_for_upgrade_script}"; then
            ${YQ_CMD} -i '.spec.datasource_configuration.dc_ads_runtime_datasource.dc_database_type = "postgresql"' $top_level_cr_details_location
            ${YQ_CMD} -i '.spec.datasource_configuration.dc_ads_runtime_datasource.database_name = "adsruntimedb"' $top_level_cr_details_location
            ${YQ_CMD} -i '.spec.datasource_configuration.dc_ads_runtime_datasource.current_schema = "adsruntime"' $top_level_cr_details_location
            ${YQ_CMD} -i '.spec.datasource_configuration.dc_ads_runtime_datasource.database_instance_secret = "ibm-ads-runtime-database"' $top_level_cr_details_location
            info "Determining if PostgreSQL \"$EDB_INSTANCE_CP4BA_NAME\" is installed for IBM Cloud Pak for Business Automation."
            pg_instance_found=""
            _detect_pg_instance "$deployment_project_name" "$EDB_INSTANCE_CP4BA_NAME"
            if [[ -n "$pg_instance_found" ]]; then
                info "Found PostgreSQL instance \"$EDB_INSTANCE_CP4BA_NAME\" ($pg_instance_found)"
                upgrade_scenario="edb-already-exists"  # CNPG/EDB exists
                allow_postgres_edb_for_2600_upgrade="true"
                ${YQ_CMD} -i '.spec.datasource_configuration.dc_ads_runtime_datasource.dc_use_postgres = true' $top_level_cr_details_location
                ${YQ_CMD} -i '.spec.datasource_configuration.dc_ads_runtime_datasource.database_servername = "postgres-cp4ba-rw.{{ meta.namespace }}.svc"' $top_level_cr_details_location
                ${YQ_CMD} -i '.spec.datasource_configuration.dc_ads_runtime_datasource.database_port = "5432"' $top_level_cr_details_location
                ${YQ_CMD} -i '.spec.datasource_configuration.dc_ads_runtime_datasource.ssl_secret_name = "{{ meta.name }}-pg-client-cert-secret"' $top_level_cr_details_location
            else
                info "Not found PostgreSQL instance \"$EDB_INSTANCE_CP4BA_NAME\""
                icn_database_type=`${YQ_CMD} ".spec.datasource_configuration.dc_icn_datasource.dc_database_type" "$top_level_cr_details_location"`
                if [[ $icn_database_type == "postgresql" ]]; then
                    # CP4BA is using external Postgres, so DICMS will use the same external Postgres
                    upgrade_scenario="external-postgres"  # External Postgres is used
                    icn_database_servername=`${YQ_CMD} ".spec.datasource_configuration.dc_icn_datasource.database_servername" "$top_level_cr_details_location"`
                    icn_database_port=`${YQ_CMD} ".spec.datasource_configuration.dc_icn_datasource.database_port" "$top_level_cr_details_location"`
                    icn_database_ssl_secret_name=`${YQ_CMD} ".spec.datasource_configuration.dc_icn_datasource.database_ssl_secret_name" "$top_level_cr_details_location"`
                    database_ssl_enabled=`${YQ_CMD} ".spec.datasource_configuration.dc_ssl_enabled" "$top_level_cr_details_location"`
                    ${YQ_CMD} -i '.spec.datasource_configuration.dc_ads_runtime_datasource.dc_use_postgres = false' $top_level_cr_details_location
                    ${YQ_CMD} -i ".spec.datasource_configuration.dc_ads_runtime_datasource.database_servername = \"$icn_database_servername\"" $top_level_cr_details_location
                    ${YQ_CMD} -i ".spec.datasource_configuration.dc_ads_runtime_datasource.database_port = \"$icn_database_port\"" $top_level_cr_details_location
                    ${YQ_CMD} -i ".spec.datasource_configuration.dc_ads_runtime_datasource.ssl_enabled = \"$database_ssl_enabled\"" $top_level_cr_details_location
                    ${YQ_CMD} -i '.spec.datasource_configuration.dc_ads_runtime_datasource.ssl_mode = "verify-full"' $top_level_cr_details_location
                    ${YQ_CMD} -i ".spec.datasource_configuration.dc_ads_runtime_datasource.ssl_secret_name = \"$icn_database_ssl_secret_name\"" $top_level_cr_details_location
                else
                    # CP4BA is not using Postgres — reuse the choice already made for ADPGG/DICMS Designer (or ask if both blocks were skipped)
                    upgrade_scenario="non-postgres"  # External Postgres for DICMS when CP4BA is on non-Postgres DB
                    warning "CP4BA is using non-PostgreSQL database (DB2/Oracle/MSSQL)."

                    if ! handle_non_postgres_upgrade_scenario "DICMS Runtime" "dc_ads_runtime_datasource" "$top_level_cr_details_location" "true" "$NON_POSTGRES_UPGRADE_DB_CHOICE"; then
                        exit 1
                    fi
                fi
            fi
        fi

        #DBACLD-226283: Adding Authoring (workflow_authoring_configuration.case.tos_list) back
        # for BAW authoring, set workflow_authoring_configuration.case.tos_list
        # Support multiple tos instance from $CP4BA_RELEASE_BASE

        # for BAW authoring, set workflow_authoring_configuration.case.tos_list
        # Support multiple tos instance from $CP4BA_RELEASE_BASE
        # DBACLD-177124: Updated the logic to dynammically check if this is an ifix to ifix upgrade or not.  If not, then we'll set the is_baw_cr_updated_needed to true
        # This condition is only needed for n-1 to n upgrade
        is_baw_cr_updated_needed=false
        if [[ "$is_ifix_to_ifix_upgrade" == false ]]; then
                is_baw_cr_updated_needed=true
        fi


        if [[ $cr_version != "${CP4BA_RELEASE_BASE}" && $is_baw_cr_updated_needed == true ]]; then
            if [[ " ${EXISTING_OPT_COMPONENT_ARR[@]} " =~ "baw_authoring" ]]; then
                # Support multiple tos instance from $CP4BA_RELEASE_BASE
                tos_instance_index=0
                while true; do
                    baw_instance_flag=`${YQ_CMD} ".spec.workflow_authoring_configuration.case // \"\"" "$top_level_cr_details_location"`
                    if [[ ! -z "$baw_instance_flag" ]]; then
                        baw_object_store_name_tos=`${YQ_CMD} ".spec.workflow_authoring_configuration.case.tos_list.[${tos_instance_index}].object_store_name // \"\"" "$top_level_cr_details_location"`
                        baw_connection_point_name_tos=`${YQ_CMD} ".spec.workflow_authoring_configuration.case.tos_list.[${tos_instance_index}].connection_point_name // \"\"" "$top_level_cr_details_location"`
                        baw_target_environment_name=`${YQ_CMD} ".spec.workflow_authoring_configuration.case.tos_list.[${tos_instance_index}].target_environment_name // \"\"" "$top_level_cr_details_location"`
                        desktop_id=`${YQ_CMD} ".spec.workflow_authoring_configuration.case.tos_list.[${tos_instance_index}].desktop_id // \"\"" "$top_level_cr_details_location"`
                        if [[ (! -z "$baw_object_store_name_tos") && -z "$baw_connection_point_name_tos" ]]; then
                            init_section=`${YQ_CMD} ".spec.initialize_configuration // \"\"" "$top_level_cr_details_location"`
                            if [[ -z "$init_section" ]]; then
                                info "Not found initialize_configuration, continue..."
                            else
                                os_index=0
                                while true; do
                                    os_flag=`${YQ_CMD} ".spec.initialize_configuration.ic_obj_store_creation.object_stores.[${os_index}].oc_cpe_obj_store_symb_name // \"\"" "$top_level_cr_details_location"`
                                    if [[ ! -z "$os_flag" ]]; then
                                        enable_workflow=`${YQ_CMD} ".spec.initialize_configuration.ic_obj_store_creation.object_stores.[${os_index}].oc_cpe_obj_store_enable_workflow" "$top_level_cr_details_location"`
                                        if [[ "$enable_workflow" == "true" ]]; then
                                            tos_datasource_name=`${YQ_CMD} ".spec.initialize_configuration.ic_obj_store_creation.object_stores.[${os_index}].oc_cpe_obj_store_conn.dc_os_datasource_name // \"\"" "$top_level_cr_details_location"`
                                            tos_connection=`${YQ_CMD} ".spec.initialize_configuration.ic_obj_store_creation.object_stores.[${os_index}].oc_cpe_obj_store_workflow_pe_conn_point_name // \"\"" "$top_level_cr_details_location"`
                                            if [[ $baw_object_store_name_tos == $tos_datasource_name ]]; then
                                                if [[ ! -z "$tos_datasource_name" ]]; then
                                                    ${YQ_CMD} -i ".spec.workflow_authoring_configuration.case.tos_list[${tos_instance_index}].object_store_name = \"$tos_datasource_name\"" ${top_level_cr_details_location}
                                                fi
                                                if [[ ! -z "$tos_connection" ]]; then
                                                    ${YQ_CMD} -i ".spec.workflow_authoring_configuration.case.tos_list[${tos_instance_index}].connection_point_name = \"$tos_connection\"" ${top_level_cr_details_location}
                                                fi
                                                # if [[ -z "$baw_target_environment_name" ]]; then
                                                #     tmp_val_ds_name=$(echo "$tos_datasource_name" | tr '[:upper:]' '[:lower:]')
                                                #     ${YQ_CMD} w -i ${top_level_cr_details_location} spec.workflow_authoring_configuration.case.tos_list.[${tos_instance_index}].target_environment_name "$tmp_val_ds_name"
                                                # fi
                                            fi
                                        fi
                                        ((os_index++))
                                    else
                                        break
                                    fi
                                done
                            fi
                            ((tos_instance_index++))
                        else
                            break
                        fi
                    fi
                done
            fi
        fi


        # for BAW authoring, set workflow_authoring_configuration.case.tos_list
        # Support multiple tos instance from $CP4BA_RELEASE_BASE
        # DBACLD-177124: Updated the logic to dynammically check the version against the MINIMUM_SUPPORTED_UPGRADE_VERSIONS
        # This condition is only needed for n-1 to n upgrade
        if [[ $cr_version != "${CP4BA_RELEASE_BASE}" && $is_baw_cr_updated_needed == true ]]; then
            if [[ (! " ${EXISTING_OPT_COMPONENT_ARR[@]} " =~ "baw_authoring") && (" ${EXISTING_PATTERN_ARR[@]} " =~ "workflow" || " ${EXISTING_PATTERN_ARR[@]} " =~ "workflow-workstreams") ]]; then
                # Support multiple tos instance from $CP4BA_RELEASE_BASE
                baw_instance_index=0
                while true; do
                    baw_instance_flag=`${YQ_CMD} ".spec.baw_configuration.[${baw_instance_index}].case // \"\"" "$top_level_cr_details_location"`
                    if [[ ! -z "$baw_instance_flag" ]]; then
                        # Support multiple tos instance from $CP4BA_RELEASE_BASE
                        tos_instance_index=0
                        while true; do
                            baw_instance_flag=`${YQ_CMD} ".spec.baw_configuration.[${baw_instance_index}].case // \"\"" "$top_level_cr_details_location"`
                            if [[ ! -z "$baw_instance_flag" ]]; then
                                baw_object_store_name_tos=`${YQ_CMD} ".spec.baw_configuration.[${baw_instance_index}].case.tos_list.[${tos_instance_index}].object_store_name // \"\"" "$top_level_cr_details_location"`
                                baw_connection_point_name_tos=`${YQ_CMD} ".spec.baw_configuration.[${baw_instance_index}].case.tos_list.[${tos_instance_index}].connection_point_name // \"\"" "$top_level_cr_details_location"`
                                baw_target_environment_name=`${YQ_CMD} ".spec.baw_configuration.[${baw_instance_index}].case.tos_list.[${tos_instance_index}].target_environment_name // \"\"" "$top_level_cr_details_location"`
                                desktop_id=`${YQ_CMD} ".spec.baw_configuration.[${baw_instance_index}].case.tos_list.[${tos_instance_index}].desktop_id // \"\"" "$top_level_cr_details_location"`
                                if [[ (! -z "$baw_object_store_name_tos") && -z "$baw_connection_point_name_tos" ]]; then
                                    init_section=`${YQ_CMD} ".spec.initialize_configuration // \"\"" "$top_level_cr_details_location"`
                                    if [[ -z "$init_section" ]]; then
                                        info "Not found initialize_configuration, continue..."
                                    else
                                        os_index=0
                                        while true; do
                                            os_flag=`${YQ_CMD} ".spec.initialize_configuration.ic_obj_store_creation.object_stores.[${os_index}].oc_cpe_obj_store_symb_name // \"\"" "$top_level_cr_details_location"`
                                            if [[ ! -z "$os_flag" ]]; then
                                                enable_workflow=`${YQ_CMD} ".spec.initialize_configuration.ic_obj_store_creation.object_stores.[${os_index}].oc_cpe_obj_store_enable_workflow" "$top_level_cr_details_location"`
                                                if [[ "$enable_workflow" == "true" ]]; then
                                                    tos_datasource_name=`${YQ_CMD} ".spec.initialize_configuration.ic_obj_store_creation.object_stores.[${os_index}].oc_cpe_obj_store_conn.dc_os_datasource_name // \"\"" "$top_level_cr_details_location"`
                                                    tos_connection=`${YQ_CMD} ".spec.initialize_configuration.ic_obj_store_creation.object_stores.[${os_index}].oc_cpe_obj_store_workflow_pe_conn_point_name // \"\"" "$top_level_cr_details_location"`
                                                    if [[ $baw_object_store_name_tos == $tos_datasource_name ]]; then
                                                        if [[ ! -z "$tos_datasource_name" ]]; then
                                                            ${YQ_CMD} -i ".spec.baw_configuration[${baw_instance_index}].case.tos_list[${tos_instance_index}].object_store_name = \"$tos_datasource_name\"" ${top_level_cr_details_location}
                                                        fi
                                                        if [[ ! -z "$tos_connection" ]]; then
                                                            ${YQ_CMD} -i ".spec.baw_configuration[${baw_instance_index}].case.tos_list[${tos_instance_index}].connection_point_name = \"$tos_connection\"" ${top_level_cr_details_location}
                                                        fi
                                                        # if [[ -z "$baw_target_environment_name" ]]; then
                                                        #     tmp_val_ds_name=$(echo "$tos_datasource_name" | tr '[:upper:]' '[:lower:]')
                                                        #     ${YQ_CMD} w -i ${top_level_cr_details_location} spec.baw_configuration.[${baw_instance_index}].case.tos_list.[${tos_instance_index}].target_environment_name "$tmp_val_ds_name"
                                                        # fi
                                                    fi
                                                fi
                                                ((os_index++))
                                            else
                                                break
                                            fi
                                        done
                                    fi
                                    ((tos_instance_index++))
                                else
                                    break
                                fi
                            fi
                        done
                        ((baw_instance_index++))
                    else
                        break
                    fi
                done
            fi
        fi


        if [[ (" ${EXISTING_PATTERN_ARR[@]} " =~ "content") || (" ${EXISTING_PATTERN_ARR[@]} " =~ "workflow") || (" ${EXISTING_PATTERN_ARR[@]} " =~ "document_processing") || (" ${EXISTING_OPT_COMPONENT_ARR[@]} " =~ "baw_authoring") || (" ${EXISTING_OPT_COMPONENT_ARR[@]} " =~ "ae_data_persistence") ]]; then
            
            if [[ $olm_cr_flag == "No" ]]; then
            # Disable sc_content_initialization/sc_content_verification, to ensure these configurations are disabled if OLM is not managing the deployment
                ${YQ_CMD} -i '.spec.shared_configuration.sc_content_initialization = false' ${top_level_cr_details_location}
                ${YQ_CMD} -i '.spec.shared_configuration.sc_content_verification = false' ${top_level_cr_details_location}
            else
                ${YQ_CMD} -i '.spec.shared_configuration.olm_sc_content_initialization = false' ${top_level_cr_details_location}
                ${YQ_CMD} -i '.spec.shared_configuration.olm_sc_content_verification = false' ${top_level_cr_details_location}
            fi

            # remove initialize_configuration/verify_configuration
            info "Remove initialize_configuration/verify_configuration from new version of CP4BA Custom Resource"
            ${YQ_CMD} -i 'del(.spec.verify_configuration)' "${top_level_cr_details_location}"
            ${YQ_CMD} -i 'del(.spec.initialize_configuration)' "${top_level_cr_details_location}"
            # ${YQ_CMD} w -i ${UPGRADE_DEPLOYMENT_ICP4ACLUSTER_CR_TMP} spec.verify_configuration
            # ${YQ_CMD} w -i ${UPGRADE_DEPLOYMENT_ICP4ACLUSTER_CR_TMP} spec.initialize_configuration

            
            #Scaling down Content Pattern Resources including CPE, CPE watcher, Navigator, Navigator Watcher, CSS
            scale_down_content_pattern_resources "$deployment_project_name" "$cr_metaname"

            # Scale up the ADP Mongo deployment so the 26.0.0 gitgateway can migrate its data to PostgreSQL.
            # The 26.0.0-IF001+ operator no longer manages mongo-deploy; gitgateway needs Mongo live at startup
            # to perform the one-time MongoDB→PostgreSQL migration before the operator cleans Mongo up.
            # Gate: 24.x→26.0.0 upgrade + document_processing_designer installed.
            if [[ (" ${EXISTING_OPT_COMPONENT_ARR[@]} " =~ "document_processing_designer") ]]; then
                scale_up_adp_mongo_for_migration "$deployment_project_name" "$cr_metaname"
            fi

        fi


        # Convert pattern array to list by common, format required for the CR specification
        delim=""
        patterns_joined=""
        for item in "${EXISTING_PATTERN_ARR[@]}"; do
            patterns_joined="$patterns_joined$delim$item"
            delim=","
        done
        ${SED_COMMAND} "s|sc_deployment_patterns:.*|sc_deployment_patterns: \"$patterns_joined\"|g" ${top_level_cr_details_location}

        # Convert optional components array to list by common
        delim=""
        opt_components_joined=""
        for item in "${EXISTING_OPT_COMPONENT_ARR[@]}"; do
            opt_components_joined="$opt_components_joined$delim$item"
            delim=","
        done

        # Set sc_optional_components='' when none optional component selected
        if [ "${#EXISTING_OPT_COMPONENT_ARR[@]}" -eq "0" ]; then
            ${SED_COMMAND} "s|sc_optional_components:.*|sc_optional_components: \"\"|g" ${top_level_cr_details_location}
        else
            ${SED_COMMAND} "s|sc_optional_components:.*|sc_optional_components: \"$opt_components_joined\"|g" ${top_level_cr_details_location}
        fi


        # must use string type for nodelabel_value in ADP
        if [[ (" ${EXISTING_PATTERN_ARR[@]} " =~ "document_processing") ]]; then
            ${SED_COMMAND} 's/\(nodelabel_value: \)\([^"][^ ]*\)/\1"\2"/' ${top_level_cr_details_location} >/dev/null 2>&1
        fi

        # IF ODM is selected then we need to add the CR section that will reference the odm keystore password secret
        # DBACLD-238578: Add passwordSecretRef for ODM keystore password secret for 26.0.0-GA
        if [[ "${CP4BA_RELEASE_BASE}-${CP4BA_PATCH_VERSION}" == "26.0.0-GA" ]]; then
            if [[ "${EXISTING_PATTERN_ARR[@]}" =~ "decisions" ]]; then
                ${YQ_CMD} -i ".spec.odm_configuration.dba.passwordSecretRef = \"ibm-odm-keystore-secret\"" ${top_level_cr_details_location}
            fi
        fi

        # This function performs all common cleanup activities of the yaml to make sure no parameter has incorrect syntax
        common_cr_cleanup "${top_level_cr_details_location}"
        
        ${COPY_CMD} -rf ${top_level_cr_details_location} ${UPGRADE_DEPLOYMENT_ICP4ACLUSTER_CR}
        
        success "Completed to merge existing CP4BA Custom Resource with new version ($CP4BA_RELEASE_BASE)"
        info "The new version ($CP4BA_RELEASE_BASE) of CP4BA Custom Resource is created ${UPGRADE_DEPLOYMENT_ICP4ACLUSTER_CR}"



        # Displaying final info statements before ending upgradeDeployment Mode.
        initialize_cfg_flag=$(${CLI_CMD} get $top_level_cr_kind $top_level_cr_name -n $deployment_project_name --no-headers --ignore-not-found -o 'jsonpath={.spec.initialize_configuration}') >/dev/null 2>&1
        verify_cfg_flag=$(${CLI_CMD} get $top_level_cr_kind $top_level_cr_name -n $deployment_project_name --no-headers --ignore-not-found -o 'jsonpath={.spec.verify_configuration}') >/dev/null 2>&1
        printf "\n"

        echo "${YELLOW_TEXT}- Refer to the Knowledge Center: \"Updating the custom resource for each capability in your deployment\" topic to complete REQUIRED steps for the installed pattern(s)."
        if [[ "${CP4BA_RELEASE_BASE}" == "26.0.0" ]] && is_cp4ba_version_meeting_minimum_supported_upgrade_version "${cp4ba_original_csv_ver_for_upgrade_script}"; then
            if [[ "${cp4ba_original_csv_ver_for_upgrade_script}" == 24.0.* ]]; then
                echo "  - If upgrading from 24.0.0-IF009 and higher: [From  https://www.ibm.com/docs/en/cloud-paks/cp-biz-automation/$CP4BA_RELEASE_BASE navigate to Upgrading --> Upgrading from 24.0.0 --> Upgrading CP4BA multi-pattern cluster from 24.0.0 --> Upgrading your IBM Cloud Pak deployment from 24.0.0 --> Updating the custom resource for each capability in your deployment]${RESET_TEXT}"
            elif [[ "${cp4ba_original_csv_ver_for_upgrade_script}" == 25.0.* ]]; then
                echo "  - If upgrading from 25.0.0-IF004 and higher: [From https://www.ibm.com/docs/en/cloud-paks/cp-biz-automation/$CP4BA_RELEASE_BASE navigate to Upgrading --> Upgrading from 25.0.0 --> Upgrading CP4BA multi-pattern cluster from 25.0.0 --> Upgrading your IBM Cloud Pak deployment from 25.0.0 --> Updating the custom resource for each capability in your deployment] ${RESET_TEXT}"
            elif [[ "${cp4ba_original_csv_ver_for_upgrade_script}" == 25.1.* ]]; then
                echo "  - If upgrading from 25.0.1-IF001 and higher: [From https://www.ibm.com/docs/en/cloud-paks/cp-biz-automation/$CP4BA_RELEASE_BASE navigate to Upgrading --> Upgrading from 25.0.1 --> Upgrading CP4BA multi-pattern cluster from 25.0.1 --> Upgrading your IBM Cloud Pak deployment from 25.0.1 --> Updating the custom resource for each capability in your deployment] ${RESET_TEXT}"
            fi
        fi
        # For ICP4ACLUSTER CR as the top level CR kind , the saved CR file to be applied is different than if the top level CR kind is Content
        echo "${YELLOW_TEXT}- After reviewing or modifying the custom resource file \"${UPGRADE_DEPLOYMENT_ICP4ACLUSTER_CR}\", you need to follow the steps below to upgrade this CP4BA deployment.${RESET_TEXT}"

        echo "${YELLOW_TEXT}[NEXT ACTION]:${RESET_TEXT}"
        step_num=1        
        
        # output info for upgrading DICMS for supported upgrade sources
        if [[ $cr_version != "${CP4BA_RELEASE_BASE}" && "${CP4BA_RELEASE_BASE}" == "26.0.0" && (" ${EXISTING_PATTERN_ARR[@]} " =~ "decisions_ads") ]] && check_adp_ads_version_to_migrate_postgres "${cp4ba_original_csv_ver_for_upgrade_script}"; then
            printf '%b\n' "\x1B[33m- Decision Intelligence Client Managed Software capability is installed in this CP4BA deployment: \x1B[0m"
	           echo "  - STEP ${step_num} ${RED_TEXT}(Required)${RESET_TEXT}: Review and modify DICMS database configuration for the upgrade scenario"
	           if [[ $upgrade_scenario == "edb-already-exists" ]]; then
                    if [[ "${allow_postgres_edb_for_2600_upgrade}" != "true" ]]; then
                        echo "        - CNPG PostgreSQL instance \"$EDB_INSTANCE_CP4BA_NAME\" is already installed for IBM Cloud Pak for Business Automation."
                        echo "        - ${RED_TEXT}(Required)${RESET_TEXT} PostgreSQL CNPG is not supported for this 26.0.0 upgrade path."
                        echo "        - Please wait for a 26.0.0-IF release that adds PostgreSQL CNPG support before proceeding with this upgrade."
                        printf "\n"
                    else
                        echo "        - In this upgrade scenario, CNPG PostgreSQL instance \"$EDB_INSTANCE_CP4BA_NAME\" has been migrated from EDB for IBM Cloud Pak for Business Automation. The CP4BA operator will automatically create the DICMS designer and/or runtime database(s) and their credentials on the new CNPG cluster during upgradeDeployment. The dc_ads_designer_datasource and/or dc_ads_runtime_datasource section(s) in the custom resource file have been automatically populated with the CNPG connection settings. No further action is required for the DICMS database configuration in this upgrade scenario."
                        printf "\n"
                    fi
            elif [[ $upgrade_scenario == "external-postgres" ]]; then
                    echo "        - In this upgrade scenario, external PostgreSQL server ${icn_database_servername} is used for the CP4BA database. Before proceeding, make sure you:"
                    echo "            a. ${RED_TEXT}(Required)${RESET_TEXT} create DICMS designer and/or runtime database(s) on this external PostgreSQL. (from https://www.ibm.com/docs/en/cloud-paks/cp-biz-automation/$CP4BA_RELEASE_BASE?topic=automation-upgrading, navigate to the section for your current upgrade source version and then \"Option 2\" for the sample scripts)."
                    echo "            b. ${RED_TEXT}(Required)${RESET_TEXT} create DICMS database_instance_secret secret(s) for DICMS designer/runtime database username and password (password only required if using password authentication). (from https://www.ibm.com/docs/en/cloud-paks/cp-biz-automation/$CP4BA_RELEASE_BASE?topic=automation-upgrading, navigate to the section for your current upgrade source version and then \"Option 2\" for the sample scripts)."
                    echo "            c. ${RED_TEXT}(Required)${RESET_TEXT} review and modify dc_ads_designer_datasource and/or dc_ads_runtime_datasource section(s) in the custom resource file \"${UPGRADE_DEPLOYMENT_ICP4ACLUSTER_CR}\" to match your external PostgreSQL configuration. "
                    echo " ${RED_TEXT}[IMPORTANT]${RESET_TEXT} If you have set \"sc_restricted_internet_access\" to \"true\" in your applied custom resource file , you must follow the information detailed in https://www.ibm.com/docs/en/cloud-paks/cp-biz-automation/$CP4BA_RELEASE_BASE?topic=uycpdf2-option-2-upgrading-cp4ba-deployment-that-uses-external-postgresql to create any custom Network policies before applying the generated Custom Resource file."
                    printf "\n"
            elif [[ $upgrade_scenario == "non-postgres" ]]; then
                    echo "        - In this upgrade scenario, other database(s) is using non-PostgreSQL database (DB2/Oracle/MSSQL) and DICMS requires external PostgreSQL. Before proceeding, make sure you:"
                    echo "            a. ${RED_TEXT}(Required)${RESET_TEXT} create DICMS designer and/or runtime database(s) on an external PostgreSQL server. (from https://www.ibm.com/docs/en/cloud-paks/cp-biz-automation/$CP4BA_RELEASE_BASE?topic=automation-upgrading, navigate to the section for your current upgrade source version and then \"Option 2\" for the sample scripts)."
                    echo "            b. ${RED_TEXT}(Required)${RESET_TEXT} create DICMS database_instance_secret secret(s) for DICMS designer/runtime database username and password (password only required if using password authentication). (from https://www.ibm.com/docs/en/cloud-paks/cp-biz-automation/$CP4BA_RELEASE_BASE?topic=automation-upgrading, navigate to the section for your current upgrade source version and then \"Option 2\" for the sample scripts)."
                    echo "            c. ${RED_TEXT}(Required)${RESET_TEXT} review and modify dc_ads_designer_datasource and/or dc_ads_runtime_datasource section(s) in the custom resource file \"${UPGRADE_DEPLOYMENT_ICP4ACLUSTER_CR}\" to match your external PostgreSQL configuration. "
                    echo " ${RED_TEXT}[IMPORTANT]${RESET_TEXT} If you have set \"sc_restricted_internet_access\" to \"true\" in your applied custom resource file , you must follow the information detailed in https://www.ibm.com/docs/en/cloud-paks/cp-biz-automation/$CP4BA_RELEASE_BASE?topic=uycpdf2-option-2-upgrading-cp4ba-deployment-that-uses-external-postgresql to create any custom Network policies before applying the generated Custom Resource file."
                    printf "\n"
            elif [[ $upgrade_scenario == "new-edb" ]]; then
                    if [[ "${allow_postgres_edb_for_2600_upgrade}" != "true" ]]; then
                        echo "        - PostgreSQL CNPG would be required for the DICMS Designer/Runtime database in this upgrade scenario."
                        echo "        - ${RED_TEXT}(Required)${RESET_TEXT} PostgreSQL CNPG is not supported for this 26.0.0 upgrade path."
                        echo "        - Please wait for a 26.0.0-IF release that adds PostgreSQL CNPG support before proceeding with this upgrade."
                        printf "\n"
                    else
                        echo "        - In this upgrade scenario, CNPG PostgreSQL instance \"$EDB_INSTANCE_CP4BA_NAME\" will be provisioned for the DICMS Designer/Runtime database. The dc_ads_designer_datasource and/or dc_ads_runtime_datasource section(s) in the custom resource file have been automatically populated with the CNPG connection settings. No further action is required for the DICMS database configuration in this upgrade scenario."
                        printf "\n"
                    fi
            fi
            step_num=$((step_num + 1))
        fi

        # output info for upgrading document process databases
        if [[ (" ${EXISTING_PATTERN_ARR[@]} " =~ "document_processing") ]]; then
                printf '%b\n' "\x1B[33m- Automation Document Processing capability is installed in this CP4BA deployment: \x1B[0m"
                echo "  - STEP ${step_num} ${RED_TEXT}(Required)${RESET_TEXT}: Upgrade the Automation Document Processing databases"
                step_num=$((step_num + 1))
            if [[ "${CP4BA_RELEASE_BASE}" == "26.0.0" ]] && is_cp4ba_version_meeting_minimum_supported_upgrade_version "${cp4ba_original_csv_ver_for_upgrade_script}"; then
                echo "    - Refer to the Knowledge Center topic: ${GREEN_TEXT}\"Upgrading your Automation Document Processing databases\"${RESET_TEXT} https://www.ibm.com/docs/en/cloud-paks/cp-biz-automation/$CP4BA_RELEASE_BASE?topic=deployment-upgrading-automation-document-processing#tasktask_upgrd_adp__postreq__1"
                if [[ $cr_version != "${CP4BA_RELEASE_BASE}" && (" ${EXISTING_OPT_COMPONENT_ARR[@]} " =~ "document_processing_designer") ]]; then
                    if [[ $upgrade_scenario == "edb-already-exists" ]]; then
                        if [[ "${allow_postgres_edb_for_2600_upgrade}" != "true" ]]; then
                            echo "    - CNPG PostgreSQL instance \"$EDB_INSTANCE_CP4BA_NAME\" is already installed for IBM Cloud Pak for Business Automation."
                            echo "    - ${RED_TEXT}(Required)${RESET_TEXT} PostgreSQL CNPG is not supported for this 26.0.0 upgrade path."
                            echo "    - Please wait for a 26.0.0-IF release that adds PostgreSQL CNPG support before proceeding with this upgrade."
                            printf "\n"
                        else
                            echo "    - In this upgrade scenario, CNPG PostgreSQL instance \"$EDB_INSTANCE_CP4BA_NAME\" has been migrated from EDB for IBM Cloud Pak for Business Automation. The CP4BA operator will automatically create the ADPGG database and its credentials on the new CNPG cluster during upgradeDeployment. The dc_adp_datasource section in the custom resource file has been automatically populated with the CNPG connection settings. Before proceeding, make sure you:"
                            echo "        a. ${RED_TEXT}(Required)${RESET_TEXT} do NOT delete mongoUri key from ibm-adp-secret."
                            printf "\n"
                        fi
                    elif [[ $upgrade_scenario == "external-postgres" ]]; then
                            echo "    - In this upgrade scenario, external PostgreSQL server ${cpe_database_servername} is used for the CPE GCD database. Before proceeding, make sure you:"
                            echo "        a. ${RED_TEXT}(Required)${RESET_TEXT} create ADPGG database on this external PostgreSQL (from https://www.ibm.com/docs/en/cloud-paks/cp-biz-automation/$CP4BA_RELEASE_BASE?topic=automation-upgrading, navigate to the section for your current upgrade source version and then \"Option 2\" for the sample scripts)."
                            echo "        b. ${RED_TEXT}(Required)${RESET_TEXT} update ibm-adp-secret to include adpggDBUsername and adpggDBPassword for the ADPGG database (password only required if using password authentication)."
                            echo "        c. ${RED_TEXT}(Required)${RESET_TEXT} do NOT delete mongoUri key from ibm-adp-secret."
                            echo "        d. ${RED_TEXT}(Required)${RESET_TEXT} review and modify dc_adp_datasource section in the custom resource file \"${UPGRADE_DEPLOYMENT_ICP4ACLUSTER_CR}\" to match your Postgres configuration."
                            printf "\n"
                    elif [[ $upgrade_scenario == "non-postgres" ]]; then
                            echo "    - In this upgrade scenario, other database(s) is using DB2 database and ADP Gitgateway requires external PostgreSQL. Before proceeding, make sure you:"
                            echo "        a. ${RED_TEXT}(Required)${RESET_TEXT} create ADPGG database on an external PostgreSQL server (from https://www.ibm.com/docs/en/cloud-paks/cp-biz-automation/$CP4BA_RELEASE_BASE?topic=automation-upgrading, navigate to the section for your current upgrade source version and then \"Option 2\" for the sample scripts)."
                            echo "        b. ${RED_TEXT}(Required)${RESET_TEXT} update ibm-adp-secret to include adpggDBUsername and adpggDBPassword for the ADPGG database (password only required if using password authentication)."
                            echo "        c. ${RED_TEXT}(Required)${RESET_TEXT} do NOT delete mongoUri key from ibm-adp-secret."
                            echo "        d. ${RED_TEXT}(Required)${RESET_TEXT} review and modify dc_adp_datasource section in the custom resource file \"${UPGRADE_DEPLOYMENT_ICP4ACLUSTER_CR}\" to match your Postgres configuration."
                            printf "\n"
                    elif [[ $upgrade_scenario == "new-edb" ]]; then
                        if [[ "${allow_postgres_edb_for_2600_upgrade}" != "true" ]]; then
                            echo "    - PostgreSQL CNPG would be required for ADP Gitgateway in this upgrade scenario."
                            echo "    - ${RED_TEXT}(Required)${RESET_TEXT} PostgreSQL CNPG is not supported for this 26.0.0 upgrade path."
                            echo "    - Please wait for a 26.0.0-IF release that adds PostgreSQL CNPG support before proceeding with this upgrade."
                        else
                            echo "    - In this upgrade scenario, CNPG PostgreSQL instance \"$EDB_INSTANCE_CP4BA_NAME\" will be provisioned for ADP Gitgateway. The dc_adp_datasource section in the custom resource file has been automatically populated with the CNPG connection settings. Before proceeding, make sure you:"
                            echo "        a. ${RED_TEXT}(Required)${RESET_TEXT} Do NOT delete mongoUri key from ibm-adp-secret."
                        fi
                        printf "\n"
                    fi
                fi
            fi
        fi
            echo "${YELLOW_TEXT}  - Refer to the Knowledge Center: \"Updating the custom resource for each capability in your deployment\" topic to complete REQUIRED steps for the installed pattern(s)."
        
        # Adding a statement to delete the old elastic search CR since we are updating the elastic search CR to switch the quiesce flag from false to true in 24.0.1 to 25.0.0 upgrade
        # https://jsw.ibm.com/browse/DBACLD-166681
        # Only show ElasticsearchCluster cleanup instructions when upgrading from 24.0.x, as that is the only path
        # where the old kind:ElasticsearchCluster CR existed. From 25.0.0 onwards the CR is already kind:Cluster.
        if [[ (" ${EXISTING_OPT_COMPONENT_ARR[@]} " =~ "bai") || (" ${EXISTING_OPT_COMPONENT_ARR[@]} " =~ "pfs") ]]; then
            if [[ "${cp4ba_original_csv_ver_for_upgrade_script}" == 24.0.* ]]; then
                printf '%b\n' "\x1B[33m- Optional Components Business Automation Insights (BAI) or Data Collector and Data Indexer (PFS) are installed in this CP4BA deployment: \x1B[0m"
                echo "${YELLOW_TEXT}[IMPORTANT]: ${RESET_TEXT}From ($CP4BA_RELEASE_BASE) ,CP4BA will be moving from Opensearch version 2.17.0 (kind: ElasticsearchCluster) to Opensearch version 2.19.x (kind: Cluster). The upgrade process will automatically migrate all the existing indices to new Opensearch version.After the upgrade is completed you must validate and verify all the existing indices are migrated successfully."
                echo "Once you have verified that indices are migrated successfully you may delete the old Opensearch instance (kind: ElasticsearchCluster) by executing \"${GREEN_TEXT} ${CLI_CMD} delete ElasticsearchCluster opensearch -n $deployment_project_name${RESET_TEXT} \" . "
                echo "${YELLOW_TEXT}[NOTE]: ${RESET_TEXT} There will be no functional impact of leaving the old Opensearch  (kind: ElasticsearchCluster) running in the cluster."
                printf "\n"
            fi
        fi
        if [[ "${CP4BA_RELEASE_BASE}" == "26.0.0" ]] && is_cp4ba_version_meeting_minimum_supported_upgrade_version "${cp4ba_original_csv_ver_for_upgrade_script}"; then
            if [[ "${cp4ba_original_csv_ver_for_upgrade_script}" == 24.0.* ]]; then
                echo "    - If upgrading from 24.0.0-IF009 and higher: [https://www.ibm.com/docs/en/cloud-paks/cp-biz-automation/$CP4BA_RELEASE_BASE?topic=uycpdf2-updating-custom-resource-each-capability-in-your-deployment] ${RESET_TEXT}"
            elif [[ "${cp4ba_original_csv_ver_for_upgrade_script}" == 25.0.* ]]; then
                echo "    - If upgrading from 25.0.0-IF004 and higher: [https://www.ibm.com/docs/en/cloud-paks/cp-biz-automation/$CP4BA_RELEASE_BASE?topic=uycpdf2-updating-custom-resource-each-capability-in-your-deployment] ${RESET_TEXT}"
            elif [[ "${cp4ba_original_csv_ver_for_upgrade_script}" == 25.1.* ]]; then
                echo "    - If upgrading from 25.0.1-IF001 and higher: [https://www.ibm.com/docs/en/cloud-paks/cp-biz-automation/$CP4BA_RELEASE_BASE?topic=uycpdf2-updating-custom-resource-each-capability-in-your-deployment] ${RESET_TEXT}"
            fi
        fi


        

        
        if [[ "$FNCM_LICENSE_UPDATE_FAILED" == "true" ]]; then
            echo
            echo "${RED_TEXT}[IMPORTANT]: The script failed to update the sc_deployment_fncm_license parameter in the Custom Resource file.You must review the newly generated Custom Resource file and manually update the license value before proceeding with the next steps.${RESET_TEXT}"
            echo
        fi

        # As a part of DBACLD-149126 solution we no longer needed the user to patch or annotate the custom resource file
        echo "  - STEP ${step_num} ${RED_TEXT}(Required)${RESET_TEXT}:${GREEN_TEXT} # ${CLI_CMD} apply -f ${UPGRADE_DEPLOYMENT_ICP4ACLUSTER_CR} -n $deployment_project_name${RESET_TEXT}"  && step_num=$((step_num + 1))

        printf "\n"
        echo "${YELLOW_TEXT}- How to check the overall upgrade status for CP4BA/zenService/IM.${RESET_TEXT}"
        echo "${YELLOW_TEXT}  [TIPS]: ${RESET_TEXT}The [upgradeDeploymentStatus] option will start necessary CP4BA operators (ibm-cp4a-operator/icp4a-foundation-operator) first to upgrade zenService, and then will start all other CP4BA operators when zenService upgrade done."
        CUR_DIR=$(realpath "$(dirname "${BASH_SOURCE[0]}")")
        SCRIPTS_DIR="$(realpath "$CUR_DIR/../..")"
        echo "  - STEP ${step_num} ${RED_TEXT}(Required)${RESET_TEXT}:${GREEN_TEXT} # ${SCRIPTS_DIR}/cp4a-deployment.sh -m upgradeDeploymentStatus -n $TARGET_PROJECT_NAME${RESET_TEXT}"
        printf "\n"
        echo "${YELLOW_TEXT}[ATTENTION]: The zenService will be ready in about 120 minutes after the new version ($CP4BA_RELEASE_BASE) of CP4BA custom resource was applied.${RESET_TEXT}"
        printf "\n"

    
    fi # End of ICP4ACluster CR changes

    if [[ (-z $top_level_cr_name) && (-z $exist_wfps_cr_array) ]]; then
        fail "No Content, ICP4ACluster or WfPSRuntime kind custom resource found in the project \"$deployment_project_name\""
        exit 1
    fi
}

function wait_for_pod() {
    local namespace=$1
    local name=$2
    local condition="oc -n ${namespace} get po --no-headers --ignore-not-found | egrep 'Running|Completed|Succeeded' | grep ^${name}"
    local retries=30
    local sleep_time=10
    local total_time_mins=$(( sleep_time * retries / 60))
    local wait_message="Waiting for pod ${name} in namespace ${namespace} to be running ..."
    local success_message="Pod ${name} in namespace ${namespace} is running."
    local error_message="Timeout after ${total_time_mins} minutes waiting for pod ${name} in namespace ${namespace} to be running."
 
    wait_for_condition "${condition}" ${retries} ${sleep_time} "${wait_message}" "${success_message}" "${error_message}"
}

function wait_for_condition() {
    local condition=$1
    local retries=$2
    local sleep_time=$3
    local wait_message=$4
    local success_message=$5
    local error_message=$6

    info "${wait_message}"
    while true; do
        result=$(eval "${condition}")

        if [[ ( ${retries} -eq 0 ) && ( -z "${result}" ) ]]; then
            error "${error_message}"
        fi
 
        sleep ${sleep_time}
        result=$(eval "${condition}")
        
        if [[ -z "${result}" ]]; then
            info "RETRYING: ${wait_message} (${retries} left)"
            retries=$(( retries - 1 ))
        else
            break
        fi
    done

    if [[ ! -z "${success_message}" ]]; then
        success "${success_message}"
    fi
}
