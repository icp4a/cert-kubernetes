#!/bin/bash
# set -x

###############################################################################
#
# Licensed Materials - Property of IBM
#
# (C) Copyright IBM Corp. 2026. All Rights Reserved.
#
# US Government Users Restricted Rights - Use, duplication or
# disclosure restricted by GSA ADP Schedule Contract with IBM Corp.
#
###############################################################################

# Script-level runtime variables.
# NAMESPACE is required when the script is executed directly.
SCRIPT_NAME="$(basename "$0")"

# CUR_DIR points to the scripts directory where this file is located.
# PARENT_DIR points to the repository root parent needed for descriptor lookups.
# NAMESPACE is used by helper/common.sh and is set after argument parsing.
# Only set these if not already set (to avoid overwriting when sourced)
if [[ -z "$CUR_DIR" ]]; then
    CUR_DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"
fi
if [[ -z "$PARENT_DIR" ]]; then
    PARENT_DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )/.." && pwd )"
fi

# Display command usage and help information for direct execution.
# Direct execution supports property mode and generate mode.
function show_help() {
    printf '\n'
    printf '%s\n' "IBM Content Cortex AI Services Deployment Setup Script"
    printf '%s\n' "======================================================="
    printf '\n'
    printf '%s\n' "DESCRIPTION:"
    printf '%s\n' "  This script automates the deployment setup for IBM Content Cortex AI Services."
    printf '%s\n' "  It supports multi-provider AI configuration including WatsonX.ai SaaS,"
    printf '%s\n' "  WatsonX.ai Lightweight Engine (LWE), and Microsoft Foundry."
    printf '\n'
    printf '%s\n' "USAGE:"
    printf '%s\n' "  Property Mode (Generate property file):"
    printf '%s\n' "    $SCRIPT_NAME -m property -n <namespace>"
    printf '\n'
    printf '%s\n' "  Generate Mode (Generate secrets and CR from property file):"
    printf '%s\n' "    $SCRIPT_NAME -m generate -n <namespace>"
    printf '\n'
    printf '%s\n' "  Help:"
    printf '%s\n' "    $SCRIPT_NAME --help"
    printf '\n'
    printf '%s\n' "OPTIONS:"
    printf '%s\n' "  -m <mode>            Mode: 'property' or 'generate' (required)"
    printf '%s\n' "  -n <namespace>       Target namespace for CP4BA deployment (required)"
    printf '%s\n' "  -h, --help           Display this help message and exit"
    printf '\n'
    printf '%s\n' "MODES:"
    printf '%s\n' "  Property Mode (-m property):"
    printf '%s\n' "    Interactively collects AI provider configuration and generates a property file."
    printf '%s\n' "    Supports multiple AI providers (WatsonX SaaS, WLE, Microsoft Foundry)."
    printf '%s\n' "    Property file location: cp4ba-prerequisites/propertyfile/cp4ba_ai_services.property"
    printf '%s\n' "    Example: $SCRIPT_NAME -m property -n cpupgrade"
    printf '\n'
    printf '%s\n' "  Generate Mode (-m generate):"
    printf '%s\n' "    Reads the property file and generates secrets, configmaps, and custom resources."
    printf '%s\n' "    Optionally applies generated artifacts to the cluster."
    printf '%s\n' "    Example: $SCRIPT_NAME -m generate -n cpupgrade"
    printf '\n'
    printf '%s\n' "WORKFLOW:"
    printf '%s\n' "  1. Run property mode to generate configuration file"
    printf '%s\n' "  2. Review and edit the property file as needed"
    printf '%s\n' "  3. Run generate mode to create and apply resources"
    printf '\n'
    printf '%s\n' "EXAMPLES:"
    printf '%s\n' "  Step 1 - Generate property file:"
    printf '%s\n' "    $SCRIPT_NAME -m property -n my-namespace"
    printf '\n'
    printf '%s\n' "  Step 2 - Generate resources from property file:"
    printf '%s\n' "    $SCRIPT_NAME -m generate -n my-namespace"
    printf '\n'
}



# Check whether a property value is usable.
# Invalid values are:
#   - empty string
#   - <Required>
#   - <Optional>
# This helper is used throughout the script before consuming property values
# Validate that a property value is not empty and not a placeholder
function is_valid_property_value() {
    local value="${1:-}"
    
    if [[ -z "$value" ]]; then
        return 1
    fi
    
    case "$value" in
        "<Required>"|"<Optional>")
            return 1
            ;;
        *)
            return 0
            ;;
    esac
}

# Ensure all directories required for temporary and final CR generation exist.
# This helper guarantees that both the temp workspace and the final nested
# output folder structure are present before any file copy/write occurs.
function ensure_cr_generation_directories_exist() {
    # Create temp folder if it doesn't exist (mkdir -p is idempotent - safe to call multiple times)
    [[ ! -d "$TEMP_FOLDER" ]] && mkdir -p "$TEMP_FOLDER" >/dev/null 2>&1
    [[ ! -d "$FINAL_CR_FOLDER" ]] && mkdir -p "$FINAL_CR_FOLDER" >/dev/null 2>&1
    mkdir -p "$(dirname "$CONTENT_CORTEX_AI_SERVICES_PATTERN_FILE_FINAL")" >/dev/null 2>&1
}

# Copy the source CR template into a temporary working file.
# The temporary file is modified before being written to the final generated location.
# Keeping template mutation isolated to a temp file prevents accidental edits
# to the source descriptor file checked into the repository.
function copy_content_cortex_ai_services_cr_template_to_tmp() {
    # Create any required parent directories before copying the template file.
    ensure_cr_generation_directories_exist

    # Confirm that the source CR template exists in the descriptors directory.
    if [[ ! -f "$CONTENT_CORTEX_AI_SERVICES_PATTERN_FILE" ]]; then
        error "Content Cortex AI Services CR template file not found: $CONTENT_CORTEX_AI_SERVICES_PATTERN_FILE"
        return 1
    fi

    # Copy the source template into the temp working file that will be updated.
    cp "$CONTENT_CORTEX_AI_SERVICES_PATTERN_FILE" "$CONTENT_CORTEX_AI_SERVICES_PATTERN_FILE_TMP"

    # Validate that the temporary CR file now exists after the copy.
    if [[ ! -f "$CONTENT_CORTEX_AI_SERVICES_PATTERN_FILE_TMP" ]]; then
        error "Failed to create temporary CR file: $CONTENT_CORTEX_AI_SERVICES_PATTERN_FILE_TMP"
        return 1
    fi

    return 0
}

# Update the temporary CR file with deployment configuration values
#
# Purpose:
#   Modifies the temporary Custom Resource YAML file with deployment-specific
#   configuration values gathered from property files, user input, or calling scripts.
#   Uses yq to perform in-place YAML updates.
#
# Prerequisites:
#   - CONTENT_CORTEX_AI_SERVICES_PATTERN_FILE_TMP must exist (created by copy function)
#   - YQ_CMD must be set (path to yq binary)
#   - Required variables must be set:
#     * NAMESPACE: Target OpenShift namespace
#     * CP4BA_SLOW_FILE_STORAGE_CLASSNAME: Storage class for persistent volumes
#     * ENABLE_REDIS: Redis enablement flag (true/false)
#     * CP4BA_BLOCK_STORAGE_CLASS_NAME: Block storage class (required if Redis enabled)
#     * CP4BA_ENABLE_GENERATE_SAMPLE_NETWORK_POLICIES: Network policies flag (true/false)
#     * CP4BA_ENABLE_INSTANA_MONITORING: Instana monitoring flag (true/false)
#
# CR Fields Updated:
#   1. metadata.namespace
#      - Target namespace for deployment
#      - Validated before update
#
#   2. spec.shared_configuration.storage_configuration.sc_slow_file_storage_classname
#      - Storage class for file-based persistent volumes
#      - Used for logs, configuration, and other file storage
#      - Validated before update
#
#   3. spec.shared_configuration.sc_redis_enable
#      - Enables/disables Redis for token caching
#      - Boolean value (true/false)
#      - When true, improves performance by caching tokens
#
#   4. spec.shared_configuration.storage_configuration.sc_block_storage_classname
#      - Storage class for block-based persistent volumes
#      - Required only when Redis is enabled
#      - Used for Redis persistent storage
#      - Conditionally added based on ENABLE_REDIS flag
#
#   5. spec.shared_configuration.sc_generate_sample_network_policies
#      - Controls generation of sample NetworkPolicy resources
#      - Boolean value (true/false)
#      - Helps secure pod-to-pod communication
#
#   6. spec.shared_configuration.sc_enable_instana_metric_collection
#      - Enables Instana monitoring integration
#      - Boolean value (true/false)
#      - Allows metrics collection for observability
#
# Validation:
#   - Checks temporary CR file exists before updates
#   - Validates NAMESPACE is not empty or placeholder
#   - Validates CP4BA_SLOW_FILE_STORAGE_CLASSNAME is not empty or placeholder
#   - Validates CP4BA_BLOCK_STORAGE_CLASS_NAME when Redis is enabled
#
# Error Handling:
#   - Returns 1 if temporary CR file not found
#   - Returns 1 if namespace validation fails
#   - Returns 1 if storage class validation fails
#   - Errors are logged with descriptive messages
#
# Calling Contexts:
#   1. Standalone generate mode:
#      - Called by generate_content_cortex_ai_services_cr()
#      - Uses values from parsed property file
#
#   2. CP4BA deployment integration:
#      - Called by generate_content_cortex_ai_services_cr()
#      - Uses values from user profile and parsed AI Services property file
#      - Storage classes come from user profile
#      - Redis setting comes from AI Services property file
#
# Returns:
#   0 - Success (all updates applied)
#   1 - Failure (validation error or file not found)
#
# Example Values:
#   NAMESPACE="my-namespace"
#   CP4BA_SLOW_FILE_STORAGE_CLASSNAME="ocs-storagecluster-cephfs"
#   ENABLE_REDIS="true"
#   CP4BA_BLOCK_STORAGE_CLASS_NAME="ocs-storagecluster-ceph-rbd"
#   CP4BA_ENABLE_GENERATE_SAMPLE_NETWORK_POLICIES="true"
#   CP4BA_ENABLE_INSTANA_MONITORING="false"
#
function update_content_cortex_ai_services_cr_tmp_file() {
    # Ensure the temp CR file exists before attempting any YAML updates.
    if [[ ! -f "$CONTENT_CORTEX_AI_SERVICES_PATTERN_FILE_TMP" ]]; then
        error "Temporary CR file not found: $CONTENT_CORTEX_AI_SERVICES_PATTERN_FILE_TMP"
        return 1
    fi

    # Validate the namespace value that will be injected into metadata.namespace.
    if ! is_valid_property_value "$NAMESPACE"; then
        error "Namespace is invalid or empty. Cannot update CR metadata.namespace"
        return 1
    fi

    # Validate the resolved slow storage class value before writing it into the CR.
    if ! is_valid_property_value "$CP4BA_SLOW_FILE_STORAGE_CLASSNAME"; then
        error "CP4BA.SLOW_FILE_STORAGE_CLASSNAME is invalid or empty. Cannot update CR"
        return 1
    fi

    # Update the namespace and storage class fields in the temporary CR file.
    ${YQ_CMD} -i ".metadata.namespace = \"$NAMESPACE\"" "$CONTENT_CORTEX_AI_SERVICES_PATTERN_FILE_TMP"
    ${YQ_CMD} -i ".spec.shared_configuration.storage_configuration.sc_slow_file_storage_classname = \"$CP4BA_SLOW_FILE_STORAGE_CLASSNAME\"" "$CONTENT_CORTEX_AI_SERVICES_PATTERN_FILE_TMP"
    ${YQ_CMD} -i ".spec.shared_configuration.sc_redis_enable = $ENABLE_REDIS" "$CONTENT_CORTEX_AI_SERVICES_PATTERN_FILE_TMP"
    ${YQ_CMD} -i ".spec.shared_configuration.sc_generate_sample_network_policies = $CP4BA_ENABLE_GENERATE_SAMPLE_NETWORK_POLICIES" "$CONTENT_CORTEX_AI_SERVICES_PATTERN_FILE_TMP"
    ${YQ_CMD} -i ".spec.shared_configuration.sc_enable_instana_metric_collection = $CP4BA_ENABLE_INSTANA_MONITORING" "$CONTENT_CORTEX_AI_SERVICES_PATTERN_FILE_TMP"

    # Add block storage class to storage_configuration if Redis is enabled and value is provided
    if [[ "$ENABLE_REDIS" == "true" ]] && is_valid_property_value "$CP4BA_BLOCK_STORAGE_CLASS_NAME"; then
        ${YQ_CMD} -i ".spec.shared_configuration.storage_configuration.sc_block_storage_classname = \"$CP4BA_BLOCK_STORAGE_CLASS_NAME\" | .spec.shared_configuration.storage_configuration.sc_block_storage_classname style=\"double\"" "$CONTENT_CORTEX_AI_SERVICES_PATTERN_FILE_TMP"
    fi

    return 0
}

# Copy the updated temporary CR file into its final generated output location.
# This keeps the generated artifact separate from the temp working file.
function save_content_cortex_ai_services_cr_final_file() {
    if [[ ! -f "$CONTENT_CORTEX_AI_SERVICES_PATTERN_FILE_TMP" ]]; then
        error "Temporary CR file not found: $CONTENT_CORTEX_AI_SERVICES_PATTERN_FILE_TMP"
        return 1
    fi

    # Ensure the final output directory exists before saving the generated CR.
    ensure_cr_generation_directories_exist

    # Copy the fully updated temporary file to the final generated location.
    cp "$CONTENT_CORTEX_AI_SERVICES_PATTERN_FILE_TMP" "$CONTENT_CORTEX_AI_SERVICES_PATTERN_FILE_FINAL"

    # Validate that the final generated CR file now exists.
    if [[ ! -f "$CONTENT_CORTEX_AI_SERVICES_PATTERN_FILE_FINAL" ]]; then
        error "Failed to create final CR file: $CONTENT_CORTEX_AI_SERVICES_PATTERN_FILE_FINAL"
        return 1
    fi

    return 0
}

# Generate Content Cortex AI Services Custom Resource (CR) YAML file
#
# Purpose:
#   Creates a Kubernetes Custom Resource YAML file for deploying Content Cortex
#   AI Services with the specified configuration (namespace, storage, Redis, etc.).
#
# Prerequisites:
#   - CONTENT_CORTEX_AI_SERVICES_PATTERN_FILE_BAK must be defined (source template path)
#   - CONTENT_CORTEX_AI_SERVICES_PATTERN_FILE_TMP must be defined (temporary work file)
#   - CONTENT_CORTEX_AI_SERVICES_PATTERN_FILE_FINAL must be defined (output file path)
#   - Helper functions must be available:
#     * copy_content_cortex_ai_services_cr_template_to_tmp()
#     * update_content_cortex_ai_services_cr_tmp_file()
#     * save_content_cortex_ai_services_cr_final_file()
#
# Parameters (all optional, fall back to global variables):
#   $1 - namespace: Target Kubernetes namespace for deployment
#   $2 - slow_file_storage_classname: Storage class for slow file storage (RWX)
#   $3 - enable_redis: Enable Redis for caching (true/false)
#   $4 - block_storage_classname: Storage class for block storage (RWO)
#   $5 - enable_network_policies: Enable network policy generation (true/false)
#   $6 - enable_instana_monitoring: Enable Instana monitoring (true/false)
#
# Invocation Modes:
#   1. Standalone execution (generate mode):
#      - Uses global variables set by parse_multi_provider_property_file()
#      - No parameters needed
#
#   2. Called from cp4a-prerequisites.sh:
#      - Passes namespace and storage class as parameters
#      - Uses parameters to override global variables
#
#   3. Called from cp4a-deployment.sh:
#      - Passes all configuration as parameters
#      - Fully parameterized invocation
#
# Workflow:
#   1. Resolve configuration from parameters or global variables
#   2. Update global variables with resolved values
#   3. Copy source CR template to temporary file
#   4. Update temporary file with runtime values:
#      - Namespace
#      - Storage classes (slow file, block)
#      - Redis enablement
#      - Network policies
#      - Instana monitoring
#   5. Save completed CR to final output location
#
# Global Variables Used/Modified:
#   - NAMESPACE: Target namespace (input/output)
#   - CP4BA_SLOW_FILE_STORAGE_CLASSNAME: Slow file storage class (input/output)
#   - ENABLE_REDIS: Redis enablement flag (input/output)
#   - CP4BA_BLOCK_STORAGE_CLASS_NAME: Block storage class (input/output)
#   - CP4BA_ENABLE_GENERATE_SAMPLE_NETWORK_POLICIES: Network policies flag (input/output)
#   - CP4BA_ENABLE_INSTANA_MONITORING: Instana monitoring flag (input/output)
#
# Generated CR Structure:
#   apiVersion: icp4a.ibm.com/v1
#   kind: CCXAIServices
#   metadata:
#     name: ccxaiservices
#     namespace: <NAMESPACE>
#   spec:
#     license: ...
#     shared_configuration:
#       sc_slow_file_storage_classname: <STORAGE_CLASS>
#       sc_block_storage_classname: <BLOCK_STORAGE_CLASS>
#     ccx_configuration:
#       redis:
#         enabled: <ENABLE_REDIS>
#
# Returns:
#   0 - Success (CR file created)
#   1 - Failure (template copy, update, or save failed)
#
# Error Conditions:
#   - Source template file not found
#   - Failed to create temporary file
#   - Failed to update temporary file
#   - Failed to save final file
#
function generate_content_cortex_ai_services_cr() {
    # Resolve invocation-specific values from either function parameters
    # or existing global variables (with parameters taking precedence)
    local function_namespace="${1:-$NAMESPACE}"
    local function_slow_file_storage_classname="${2:-$CP4BA_SLOW_FILE_STORAGE_CLASSNAME}"
    local function_enable_redis="${3:-$ENABLE_REDIS}"
    local function_block_storage_classname="${4:-$CP4BA_BLOCK_STORAGE_CLASS_NAME}"
    local function_enable_network_policies="${5:-false}"
    local function_enable_instana_monitoring="${6:-false}"

    # Persist the resolved values into the global variables
    # These globals are used by downstream helper functions
    NAMESPACE="$function_namespace"
    CP4BA_SLOW_FILE_STORAGE_CLASSNAME="$function_slow_file_storage_classname"
    ENABLE_REDIS="$function_enable_redis"
    CP4BA_BLOCK_STORAGE_CLASS_NAME="$function_block_storage_classname"
    CP4BA_ENABLE_GENERATE_SAMPLE_NETWORK_POLICIES="$function_enable_network_policies"
    CP4BA_ENABLE_INSTANA_MONITORING="$function_enable_instana_monitoring"

    # Copy the source template into a temporary file for safe mutation
    # This preserves the original template for future use
    copy_content_cortex_ai_services_cr_template_to_tmp || return 1

    # Inject the runtime configuration into the temporary CR file
    # This performs sed replacements for namespace, storage classes, etc.
    update_content_cortex_ai_services_cr_tmp_file || return 1

    # Save the completed CR into the final generated output location
    # This moves the temporary file to the final destination
    save_content_cortex_ai_services_cr_final_file || return 1

    return 0
}

# Print a table of artifacts that can be applied in default mode.
# This is purely a display helper used before asking whether artifacts
# Display the multi-provider configuration banner
function display_provider_setup_banner() {
    clear
    printf "\n"
    printf "╔═══════════════════════════════════════════════════════════════════════════════╗\n"
    printf "║                                                                               ║\n"
    printf "║              Content Cortex AI Services Deployment Setup                      ║\n"
    printf "║                                                                               ║\n"
    printf "║  This script automates the deployment setup for IBM Content Cortex AI         ║\n"
    printf "║  Services. It will guide you through collecting required configuration        ║\n"
    printf "║  properties and generate a property file for deployment.                      ║\n"
    printf "║                                                                               ║\n"
    printf "╚═══════════════════════════════════════════════════════════════════════════════╝\n"
    printf "\n"

    echo "${YELLOW_TEXT}[IMPORTANT] Content Cortex AI Services deployment requires an x86/amd64 architecture environment.${RESET_TEXT}"
    echo
    prompt_press_any_key_to_continue
    
    clear
    printf "\n"
    printf "═══════════════════════════════════════════════════════════════════════════════\n"
    printf " AI Model Provider Configuration\n"
    printf "═══════════════════════════════════════════════════════════════════════════════\n"
    printf "\n"
    printf "Configure the AI model providers for your Content Cortex deployment.\n"
    printf "\n"
    printf "What are Model Providers?\n"
    printf "  Model providers are AI services that power intelligent features in Content\n"
    printf "  Cortex. You can configure multiple providers for redundancy or to use\n"
    printf "  different models.\n"
    printf "\n"
    printf "Supported Provider Types:\n"
    printf "  • WatsonX.ai SaaS - IBM's cloud-based AI platform\n"
    printf "  • WatsonX.ai Lightweight Engine (LWE) - On-premise AI deployment\n"
    printf "  • Microsoft Foundry - Microsoft's Azure AI platform (https://ai.azure.com/)\n"
    printf "\n"
    printf "💡 Recommendation: Start with 1 provider for initial deployment.\n"
    printf "   Additional providers can be added later.\n"
    printf "\n"
    printf "═══════════════════════════════════════════════════════════════════════════════\n"
    printf "\n"
}

# Prompt for multi-select provider types with interactive toggle
function prompt_provider_types_multiselect() {
    local -a selected_providers=()
    local input=""
    local empty_count=0
    local max_empty_attempts=3
    
    while true; do
        # Clear and display current selection state
        printf '\n'
        printf '\x1B[1mSelect the AI provider type(s) you want to configure:\x1B[0m\n'
        
        # Display options with selection indicators
        if [[ " ${selected_providers[@]} " =~ " 1 " ]]; then
            printf '  1) WatsonX.ai SaaS \x1B[1m(Selected)\x1B[0m\n'
        else
            printf '  1) WatsonX.ai SaaS\n'
        fi
        
        if [[ " ${selected_providers[@]} " =~ " 2 " ]]; then
            printf '  2) WatsonX.ai Lightweight Engine (LWE) \x1B[1m(Selected)\x1B[0m\n'
        else
            printf '  2) WatsonX.ai Lightweight Engine (LWE)\n'
        fi
        
        if [[ " ${selected_providers[@]} " =~ " 3 " ]]; then
            printf '  3) Microsoft Foundry \x1B[1m(Selected)\x1B[0m\n'
        else
            printf '  3) Microsoft Foundry\n'
        fi
        
        printf '\n'
        if [[ ${#selected_providers[@]} -gt 0 ]]; then
            printf 'Currently selected: %d provider(s)\n' "${#selected_providers[@]}"
        fi
        printf 'Enter a number to toggle selection, or press Enter to continue: '
        
        read -r input
        input="$(printf '%s' "$input" | sed 's/^[[:space:]]*//;s/[[:space:]]*$//')"
        
        # Check if user pressed Enter
        if [[ -z "$input" ]]; then
            # Check if at least one provider is selected
            if [[ ${#selected_providers[@]} -eq 0 ]]; then
                empty_count=$((empty_count + 1))
                warning "At least one provider must be selected."
                warning "Attempt ${empty_count}/${max_empty_attempts} failed."
                
                if [[ $empty_count -ge $max_empty_attempts ]]; then
                    error "Maximum retry limit reached. Exiting the script."
                    exit 1
                fi
                
                printf '\n'
                warning "Please select at least one provider."
                sleep 2
                continue
            else
                # User is done selecting
                break
            fi
        fi
        
        # Validate input is 1, 2, or 3
        if [[ ! "$input" =~ ^[1-3]$ ]]; then
            warning "Invalid input. Please enter 1, 2, or 3."
            sleep 1
            continue
        fi
        
        # Toggle selection
        if [[ " ${selected_providers[@]} " =~ " $input " ]]; then
            # Remove from selection
            local new_selection=()
            local item
            for item in "${selected_providers[@]}"; do
                if [[ "$item" != "$input" ]]; then
                    new_selection+=("$item")
                fi
            done
            selected_providers=("${new_selection[@]}")
        else
            # Add to selection
            selected_providers+=("$input")
        fi
        
        sleep 0.5
    done
    
    # Sort selections
    local OLDIFS="$IFS"
    IFS=$'\n' selected_providers=($(sort -n <<<"${selected_providers[*]}"))
    IFS="$OLDIFS"
    
    PROVIDER_COUNT=${#selected_providers[@]}
    
    # Map selections to provider types and generate IDs with unique strings
    local watsonx_count=0
    local azure_count=0
    local i
    
    for i in "${!selected_providers[@]}"; do
        local provider_num=$((i + 1))
        # Generate a unique 4-character string using timestamp and random
        local unique_string=$(date +%s%N | md5sum | head -c 4)
        
        case "${selected_providers[$i]}" in
            1)
                PROVIDER_TYPES[$provider_num]="watsonx_saas"
                watsonx_count=$((watsonx_count + 1))
                PROVIDER_IDS[$provider_num]="watsonx_${unique_string}"
                ;;
            2)
                PROVIDER_TYPES[$provider_num]="watsonx_lightweightengine"
                watsonx_count=$((watsonx_count + 1))
                PROVIDER_IDS[$provider_num]="watsonx_${unique_string}"
                ;;
            3)
                PROVIDER_TYPES[$provider_num]="azure"
                azure_count=$((azure_count + 1))
                PROVIDER_IDS[$provider_num]="azure_${unique_string}"
                ;;
        esac
    done
    
    return 0
}

# Display provider configuration banner
function display_provider_config_banner() {
    local provider_num=$1
    local provider_type=$2
    local provider_id=$3
    
    printf '\n'
    printf "═══════════════════════════════════════════════════════════════════════════════\n"
    printf " Provider %d Configuration: %s\n" "$provider_num" "$provider_id"
    printf "═══════════════════════════════════════════════════════════════════════════════\n"
    printf '\n'
}

# Set default values for provider configuration (no prompting)
function set_default_provider_configuration() {
    local provider_num=$1
    local provider_type=$2
    local provider_id=$3
    
    # Set default values based on provider type
    case "$provider_type" in
        watsonx_saas)
            PROVIDER_URLS[$provider_num]="https://us-south.ml.cloud.ibm.com"
            PROVIDER_API_KEYS[$provider_num]="<Required>"
            PROVIDER_SPACE_IDS[$provider_num]="<Required>"
            PROVIDER_PROJECT_IDS[$provider_num]=""
            ;;
            
        watsonx_lightweightengine)
            PROVIDER_URLS[$provider_num]="https://localhost:8443"
            PROVIDER_USERNAMES[$provider_num]="<Required>"
            PROVIDER_API_KEYS[$provider_num]="<Required>"
            ;;
            
        azure)
            PROVIDER_URLS[$provider_num]="https://your-endpoint.openai.azure.com"
            PROVIDER_API_KEYS[$provider_num]="<Required>"
            ;;
    esac
}

# Generate the multi-provider property file
# Parameters:
#   $1 (optional): "skip_storage" - Skip storage class properties (used when called from cp4a-prerequisites.sh)
# Generate multi-provider property file in TOML-like format
#
# Purpose:
#   Creates a property file containing configuration for multiple AI providers
#   (WatsonX SaaS, WatsonX LWE, Azure OpenAI) and their associated models.
#
# Parameters:
#   $1 - skip_storage_properties (optional): Set to "skip_storage" to omit storage class properties
#        Used when called from cp4a-prerequisites.sh which handles storage separately
#
# Prerequisites:
#   - PROVIDER_COUNT must be set (number of providers to configure)
#   - PROVIDER_TYPES array must be populated with provider types
#   - PROVIDER_IDS array must be populated with unique provider IDs
#   - AI_SERVICES_PROPERTY_FILE must be defined (output file path)
#   - WATSONX_SSL_CERT_FOLDER must be defined (for SSL certificates)
#   - Property arrays from cp4ba-property.sh must be loaded:
#     * AI_SERVICES_COMMON_PROPERTIES
#     * AI_SERVICES_PROVIDER_PROPERTIES
#     * AI_SERVICES_MODEL_PROPERTIES
#
# Property File Structure:
#   [COMMON]                    - Common configuration (Redis, storage classes)
#   [PROVIDER_1]                - First provider configuration
#   [[PROVIDER_1.MODELS]]       - Models for first provider
#   [PROVIDER_2]                - Second provider configuration
#   [[PROVIDER_2.MODELS]]       - Models for second provider
#   ...
#
# Behavior:
#   - Creates property file directory if it doesn't exist
#   - Creates SSL certificate folder for LWE providers
#   - Sets default configurations for each provider type
#   - Generates property file with:
#     * Header with generation timestamp and namespace
#     * Common section with Redis and storage settings
#     * Provider sections with type-specific defaults
#     * Model sections with provider-specific defaults
#   - Adds instructional comments for users
#   - Handles provider-specific parameters (SSL for LWE, space/project for SaaS, etc.)
#
# Provider-Specific Defaults:
#   WatsonX SaaS:
#     - MODEL_ID: openai/gpt-oss-120b
#     - CONTEXT_WINDOW_TOKEN_LIMIT: 131072
#   WatsonX LWE:
#     - MODEL_ID: openai/gpt-oss-120b
#     - CONTEXT_WINDOW_TOKEN_LIMIT: 131072
#     - SSL_ENABLED: false (can be enabled for self-signed certs)
#   Azure OpenAI:
#     - MODEL_ID: gpt-5.4
#     - CONTEXT_WINDOW_TOKEN_LIMIT: 272000
#
# Returns:
#   0 - Success (property file created)
#   1 - Failure (directory creation failed)
#
function generate_multi_provider_property_file() {
    local skip_storage_properties="${1:-}"
    local property_dir=""
    
    # Get directory path for property file and create it
    property_dir="$(dirname "$AI_SERVICES_PROPERTY_FILE")"
    mkdir -p "$property_dir" >/dev/null 2>&1
    
    if [[ ! -d "$property_dir" ]]; then
        error "Failed to create directory for AI services property file: $property_dir"
        return 1
    fi
    
    # Create SSL certificate folder for WatsonX LWE providers
    # This folder will contain lwe.crt files for SSL/TLS validation
    mkdir -p "$WATSONX_SSL_CERT_FOLDER" >/dev/null 2>&1
    
    # Set default configuration for each provider if not already set
    # This ensures proper default values when called from cp4a-prerequisites.sh
    # where provider configuration may be collected interactively
    for ((i=1; i<=PROVIDER_COUNT; i++)); do
        if [[ -z "${PROVIDER_URLS[$i]}" ]]; then
            set_default_provider_configuration "$i" "${PROVIDER_TYPES[$i]}" "${PROVIDER_IDS[$i]}"
        fi
    done
    
    # Start building the property file
    {
        printf '%s\n' "###############################################################################"
        printf '%s\n' "#"
        printf '%s\n' "# IBM Content Cortex AI Services - Multi-Provider Configuration"
        printf '%s\n' "#"
        printf '%s\n' "# This file contains configuration for AI model providers used by"
        printf '%s\n' "# Content Cortex AI Services."
        printf '%s\n' "#"
        printf '%s\n' "# Generated: $(date)"
        printf '%s\n' "# Namespace: $NAMESPACE"
        printf '%s\n' "#"
        printf '%s\n' "###############################################################################"
        printf '\n'
        printf '%s\n' "=================================================================================================================="
        printf '%s\n' "NOTES: Please replace all \"<Required>\" values with actual configuration values."
        printf '%s\n' "       Values marked as \"<Required>\" must be provided for the deployment to work correctly."
        printf '%s\n' "=================================================================================================================="
        printf '\n'
        
        printf '%s\n' "####################################################"
        printf '%s\n' "## Common Configuration for Content Cortex AI Services"
        printf '%s\n' "####################################################"
        
        # Generate common properties using arrays
        for idx in "${!AI_SERVICES_COMMON_PROPERTIES[@]}"; do
            local prop_name="${AI_SERVICES_COMMON_PROPERTIES[$idx]}"
            local prop_comment="${COMMENTS_AI_SERVICES_COMMON_PROPERTIES[$idx]}"
            local prop_default="${DEFAULTS_AI_SERVICES_COMMON_PROPERTIES[$idx]}"
            local prop_value=""
            
            # Skip storage class properties when called from cp4a-prerequisites.sh
            if [[ "$skip_storage_properties" == "skip_storage" ]]; then
                if [[ "$prop_name" == "CP4BA_SLOW_FILE_STORAGE_CLASSNAME" || "$prop_name" == "CP4BA_BLOCK_STORAGE_CLASS_NAME" ]]; then
                    continue
                fi
            fi
            
            # Get the actual value from the runtime variable
            case "$prop_name" in
                ENABLE_REDIS)
                    prop_value="${ENABLE_REDIS:-$prop_default}"
                    ;;
                CP4BA_SLOW_FILE_STORAGE_CLASSNAME)
                    prop_value="${CP4BA_SLOW_FILE_STORAGE_CLASSNAME:-$prop_default}"
                    ;;
                CP4BA_BLOCK_STORAGE_CLASS_NAME)
                    # Always include block storage property with clear comment
                    prop_value="${CP4BA_BLOCK_STORAGE_CLASS_NAME:-$prop_default}"
                    ;;
            esac
            
            # Print comment and property
            printf '%b\n' "$prop_comment"
            printf '%s="%s"\n' "$prop_name" "$prop_value"
            printf '\n'
        done
        
        printf '%s\n' "###############################################################################"
        printf '%s\n' "# AI Model Providers Configuration"
        printf '%s\n' "###############################################################################"
        printf '\n'
        printf '%s\n' "## IMPORTANT: Default Model Selection"
        printf '%s\n' "## - Exactly ONE model across ALL providers must have DEFAULT=true"
        printf '%s\n' "## - The model with DEFAULT=true will be used as the active_llm in the deployment"
        printf '%s\n' "## - If multiple models have DEFAULT=true, validation will fail"
        printf '%s\n' "## - If no model has DEFAULT=true, validation will fail"
        printf '\n'
        
        # Determine which provider should have the default model
        # Priority: Azure > WatsonX SaaS > WatsonX LWE
        local default_provider_index=0
        for ((i=1; i<=PROVIDER_COUNT; i++)); do
            if [[ "${PROVIDER_TYPES[$i]}" == "azure" ]]; then
                default_provider_index=$i
                break
            fi
        done
        
        if [[ $default_provider_index -eq 0 ]]; then
            for ((i=1; i<=PROVIDER_COUNT; i++)); do
                if [[ "${PROVIDER_TYPES[$i]}" == "watsonx_saas" ]]; then
                    default_provider_index=$i
                    break
                fi
            done
        fi
        
        if [[ $default_provider_index -eq 0 ]]; then
            for ((i=1; i<=PROVIDER_COUNT; i++)); do
                if [[ "${PROVIDER_TYPES[$i]}" == "watsonx_lightweightengine" ]]; then
                    default_provider_index=$i
                    break
                fi
            done
        fi
        
        # Generate configuration for each provider
        for ((i=1; i<=PROVIDER_COUNT; i++)); do
            printf '%s\n' "####################################################"
            printf '%s\n' "## Provider $i: ${PROVIDER_IDS[$i]} (${PROVIDER_TYPES[$i]})"
            printf '%s\n' "####################################################"
            printf '%s\n' "[PROVIDER_$i]"
            
            # Generate provider properties using arrays
            for prop_idx in "${!AI_SERVICES_PROVIDER_PROPERTIES[@]}"; do
                local prop_name="${AI_SERVICES_PROVIDER_PROPERTIES[$prop_idx]}"
                local prop_comment="${COMMENTS_AI_SERVICES_PROVIDER_PROPERTIES[$prop_idx]}"
                local prop_value="${DEFAULTS_AI_SERVICES_PROVIDER_PROPERTIES[$prop_idx]}"
                
                # Get actual values from provider arrays
                case "$prop_name" in
                    PROVIDER_ID)
                        prop_value="${PROVIDER_IDS[$i]}"
                        ;;
                    ENABLED)
                        prop_value="true"
                        ;;
                    PROVIDER_NAME)
                        prop_value="${PROVIDER_TYPES[$i]}"
                        ;;
                    PROVIDER_URL)
                        prop_value="${PROVIDER_URLS[$i]}"
                        ;;
                    USERNAME)
                        prop_value="${PROVIDER_USERNAMES[$i]}"
                        ;;
                    API_KEY)
                        prop_value="${PROVIDER_API_KEYS[$i]}"
                        ;;
                    PASSWORD)
                        prop_value="${PROVIDER_PASSWORDS[$i]}"
                        ;;
                    SPACE_ID)
                        prop_value="${PROVIDER_SPACE_IDS[$i]}"
                        ;;
                    PROJECT_ID)
                        prop_value="${PROVIDER_PROJECT_IDS[$i]}"
                        ;;
                    SSL_ENABLED)
                        prop_value="false"
                        ;;
                    TLS_CERT_LOCATION)
                        # Use the actual resolved path, not a variable reference
                        prop_value="${WATSONX_SSL_CERT_FOLDER}"
                        ;;
                esac
                
                # Skip properties that are not applicable for this provider type
                if [[ "$prop_name" == "USERNAME" || "$prop_name" == "PASSWORD" ]] && [[ "${PROVIDER_TYPES[$i]}" != "watsonx_lightweightengine" ]]; then
                    continue
                fi
                if [[ "$prop_name" == "SPACE_ID" || "$prop_name" == "PROJECT_ID" ]] && [[ "${PROVIDER_TYPES[$i]}" != "watsonx_saas" ]]; then
                    continue
                fi
                if [[ "$prop_name" == "SSL_ENABLED" || "$prop_name" == "TLS_CERT_LOCATION" ]] && [[ "${PROVIDER_TYPES[$i]}" != "watsonx_lightweightengine" ]]; then
                    continue
                fi
                
                # Print comment and property
                printf '%b\n' "$prop_comment"
                printf '%s = "%s"\n' "$prop_name" "$prop_value"
                printf '\n'
            done
            
            printf '%s\n' "## Models Configuration"
            printf '%s\n' "## To add additional models, copy the [[PROVIDER_${i}.MODELS]] section below"
            printf '%s\n' "## and paste it after this section, then modify the MODEL_ID and DEFAULT values."
            printf '%s\n' "## IMPORTANT: Only ONE model across ALL providers can have DEFAULT=true"
            printf '%s\n' "[[PROVIDER_${i}.MODELS]]"
            
            # Determine if this model should be the default
            # Default is true only for the first model of the highest priority provider
            local is_default_model="false"
            if [[ $i -eq $default_provider_index ]]; then
                is_default_model="true"
            fi
            
            # Generate model properties using arrays
            for model_idx in "${!AI_SERVICES_MODEL_PROPERTIES[@]}"; do
                local model_prop_name="${AI_SERVICES_MODEL_PROPERTIES[$model_idx]}"
                local model_prop_comment="${COMMENTS_AI_SERVICES_MODEL_PROPERTIES[$model_idx]}"
                local model_prop_value="${DEFAULTS_AI_SERVICES_MODEL_PROPERTIES[$model_idx]}"
                
                # Override defaults based on provider type and property name
                if [[ "$model_prop_name" == "MODEL_ID" ]]; then
                    case "${PROVIDER_TYPES[$i]}" in
                        watsonx_saas|watsonx_lightweightengine)
                            model_prop_value="openai/gpt-oss-120b"
                            ;;
                        azure)
                            model_prop_value="gpt-5.4"
                            ;;
                    esac
                elif [[ "$model_prop_name" == "DEFAULT" ]]; then
                    model_prop_value="$is_default_model"
                elif [[ "$model_prop_name" == "CONTEXT_WINDOW_TOKEN_LIMIT" ]]; then
                    case "${PROVIDER_TYPES[$i]}" in
                        watsonx_saas|watsonx_lightweightengine)
                            model_prop_value="131072"
                            ;;
                        azure)
                            model_prop_value="272000"
                            ;;
                    esac
                fi
                
                # Print comment and property
                printf '%b\n' "$model_prop_comment"
                printf '%s = "%s"\n' "$model_prop_name" "$model_prop_value"
            done
            printf '\n'
            
            if [[ $i -lt $PROVIDER_COUNT ]]; then
                printf '%s\n' "###############################################################################"
                printf '\n'
            fi
        done
        
    } > "$AI_SERVICES_PROPERTY_FILE"
    
    if [[ ! -f "$AI_SERVICES_PROPERTY_FILE" ]]; then
        error "Failed to create AI services property file"
        return 1
    fi
    
    return 0
}

# Run property mode - interactive property file generation
#
# Purpose:
#   Provides an interactive workflow to collect AI provider configuration
#   and generate a property file that can be edited and used for deployment.
#
# Prerequisites:
#   - NAMESPACE must be set
#   - AI_SERVICES_PROPERTY_FILE must be defined (output file path)
#   - Helper functions must be available:
#     * display_provider_setup_banner()
#     * prompt_provider_types_multiselect()
#     * set_default_provider_configuration()
#     * generate_multi_provider_property_file()
#
# Workflow:
#   1. Display setup banner with instructions
#   2. Initialize global arrays for provider configuration
#   3. Prompt user to select provider types (multi-select)
#   4. Display summary table of selected providers
#   5. Set default configuration for each provider
#   6. Generate property file with all settings
#   7. Display next steps for user
#
# Global Arrays Initialized:
#   - PROVIDER_TYPES: Maps provider index to type (watsonx_saas, watsonx_lightweightengine, azure)
#   - PROVIDER_IDS: Maps provider index to unique identifier
#   - PROVIDER_URLS: Maps provider index to API endpoint URL
#   - PROVIDER_API_KEYS: Maps provider index to API key
#   - PROVIDER_USERNAMES: Maps provider index to username
#   - PROVIDER_PASSWORDS: Maps provider index to password
#   - PROVIDER_SPACE_IDS: Maps provider index to WatsonX space ID
#   - PROVIDER_PROJECT_IDS: Maps provider index to WatsonX project ID
#
# User Interaction:
#   - Multi-select menu for provider types
#   - Automatic generation of provider IDs
#   - Summary table showing selected configuration
#
# Output:
#   - Property file at AI_SERVICES_PROPERTY_FILE location
#   - File contains:
#     * [COMMON] section with Redis and storage settings
#     * [PROVIDER_N] sections with provider-specific defaults
#     * [[PROVIDER_N.MODELS]] sections with model defaults
#     * Instructional comments for users
#
# Next Steps Displayed:
#   1. Review and edit property file
#   2. Fill in <Required> values
#   3. Add additional models if needed
#   4. Run generate mode to create secrets and CR
#
# Returns:
#   Does not return (exits after displaying next steps)
#
function run_property_mode() {
    display_provider_setup_banner
    
    # Clean up previous property mode artifacts to ensure fresh generation
    # Remove SSL certificate folder and property file from previous runs
    #info "Cleaning up previous property mode artifacts..."
    rm -rf "$WATSONX_SSL_CERT_FOLDER" >/dev/null 2>&1
    rm -f "$AI_SERVICES_PROPERTY_FILE" >/dev/null 2>&1
    #success "Cleanup completed"
    printf '\n'
    
    # Initialize global arrays to store provider configurations
    # These arrays are indexed by provider number (1, 2, 3, etc.)
    declare -g -A PROVIDER_TYPES
    declare -g -A PROVIDER_IDS
    declare -g -A PROVIDER_URLS
    declare -g -A PROVIDER_API_KEYS
    declare -g -A PROVIDER_USERNAMES
    declare -g -A PROVIDER_PASSWORDS
    declare -g -A PROVIDER_SPACE_IDS
    declare -g -A PROVIDER_PROJECT_IDS
    
    # Prompt for provider types using multi-select menu
    # This populates PROVIDER_COUNT, PROVIDER_TYPES, and PROVIDER_IDS
    prompt_provider_types_multiselect
    clear
    
    printf '\n'
    echo "╔════════════════════════════════════════════════════════════════════════════╗"
    echo "║                    Selected AI Provider Configuration                      ║"
    echo "╠════════════════════════════════════════════════════════════════════════════╣"
    printf "║ %-74s ║\n" "Total Providers: $PROVIDER_COUNT"
    echo "╠════════╦═══════════════════════════╦═══════════════════════════════════════╣"
    printf "║ %-6s ║ %-25s ║ %-37s ║\n" "Index" "Provider ID" "Provider Type"
    echo "╠════════╬═══════════════════════════╬═══════════════════════════════════════╣"
    for ((i=1; i<=PROVIDER_COUNT; i++)); do
        printf "║ %-6s ║ %-25s ║ %-37s ║\n" "$i" "${PROVIDER_IDS[$i]}" "${PROVIDER_TYPES[$i]}"
    done
    echo "╚════════╩═══════════════════════════╩═══════════════════════════════════════╝"
    printf '\n'
    
    # Set default configuration for each provider (no prompting)
    for ((i=1; i<=PROVIDER_COUNT; i++)); do
        set_default_provider_configuration "$i" "${PROVIDER_TYPES[$i]}" "${PROVIDER_IDS[$i]}"
    done
    
    # Generate the property file
    generate_multi_provider_property_file
    
    success "Property file for Content Cortex AI Services generated successfully!"
    printf '\n'
    info "Property file location: $AI_SERVICES_PROPERTY_FILE"
    printf '\n'
    info "Next steps:"
    echo "  1. Review and edit the property file to fill in required values"
    echo "  2. To add more models to a provider, copy the [[PROVIDER_N.MODELS]] section"
    echo "  3. Run the same script with the generate mode to create the relevant secret templates and Custom Resource File:"
    echo "     ${GREEN_TEXT}bash $SCRIPT_NAME -m generate -n $NAMESPACE${RESET_TEXT}"
    printf '\n'
}

# Parse multi-provider property file and validate configuration
#
# Purpose:
#   Reads the TOML-like property file and loads all configuration into global
#   associative arrays for use by secret and CR generation functions.
#
# Prerequisites:
#   - AI_SERVICES_PROPERTY_FILE must be defined and exist
#   - Property file must follow the TOML-like format:
#     * [COMMON] section with Redis and storage settings
#     * [PROVIDER_N] sections with provider configuration
#     * [[PROVIDER_N.MODELS]] sections with model configuration
#
# Global Variables Created:
#   - PARSED_PROVIDERS: Associative array with provider properties
#     Format: PARSED_PROVIDERS["<provider_num>_<property_name>"]="<value>"
#     Example: PARSED_PROVIDERS["1_PROVIDER_ID"]="watsonx-saas-1"
#
#   - PARSED_MODELS: Associative array with model properties
#     Format: PARSED_MODELS["<provider_num>_<model_num>_<property_name>"]="<value>"
#     Example: PARSED_MODELS["1_1_MODEL_ID"]="openai/gpt-oss-120b"
#
#   - PARSED_ENABLE_REDIS: Redis enablement flag (true/false)
#   - PARSED_SLOW_STORAGE: Slow file storage class name
#   - PARSED_BLOCK_STORAGE: Block storage class name
#
# Parsing Logic:
#   - Skips comments (lines starting with #) and empty lines
#   - Detects section headers: [PROVIDER_N], [[PROVIDER_N.MODELS]]
#   - Parses key=value pairs with optional quotes
#   - Handles common properties (Redis, storage classes)
#   - Handles provider-level properties (URL, API key, etc.)
#   - Handles model-level properties (model ID, temperature, etc.)
#
# Validation Performed:
#   1. At least one provider must be enabled (ENABLED=true)
#   2. Exactly one model across all enabled providers must be default (DEFAULT=true)
#   3. Default model must belong to an enabled provider
#
# Returns:
#   0 - Success (property file parsed and validated)
#   1 - Failure (validation errors found)
#
# Error Conditions:
#   - No enabled providers found
#   - No default model found
#   - Multiple default models found
#   - Default model in disabled provider
#
function parse_multi_provider_property_file() {
    local current_provider=""
    local current_model_index=0
    declare -g -A PARSED_PROVIDERS
    declare -g -A PARSED_MODELS
    declare -g PARSED_ENABLE_REDIS=""
    declare -g PARSED_SLOW_STORAGE=""
    declare -g PARSED_BLOCK_STORAGE=""
    
    while IFS= read -r line; do
        # Skip comments and empty lines
        [[ "$line" =~ ^[[:space:]]*# ]] && continue
        [[ "$line" =~ ^[[:space:]]*$ ]] && continue
        
        # Remove leading whitespace
        line=$(echo "$line" | sed 's/^[[:space:]]*//')
        
        # Check for section headers
        if [[ "$line" =~ ^\[PROVIDER_([0-9]+)\]$ ]]; then
            current_provider="${BASH_REMATCH[1]}"
            current_model_index=0
            continue
        fi
        
        if [[ "$line" =~ ^\[\[PROVIDER_([0-9]+)\.MODELS\]\]$ ]]; then
            current_model_index=$((current_model_index + 1))
            continue
        fi
        
        # Parse key=value pairs - allow dots, underscores, and alphanumeric in keys
        if [[ "$line" =~ ^([A-Z0-9_.]+)[[:space:]]*=[[:space:]]*\"?([^\"]*)\"?$ ]]; then
            local key="${BASH_REMATCH[1]}"
            local value="${BASH_REMATCH[2]}"
            
            # Remove trailing quotes if present
            value=$(echo "$value" | sed 's/"$//')
            
            # Parse common properties (with dots replaced by underscores for case matching)
            local key_normalized=$(echo "$key" | tr '.' '_')
            
            case "$key_normalized" in
                ENABLE_REDIS)
                    PARSED_ENABLE_REDIS="$value"
                    ;;
                CP4BA_SLOW_FILE_STORAGE_CLASSNAME)
                    PARSED_SLOW_STORAGE="$value"
                    ;;
                CP4BA_BLOCK_STORAGE_CLASS_NAME)
                    PARSED_BLOCK_STORAGE="$value"
                    ;;
                *)
                    # Parse provider or model properties
                    if [[ -n "$current_provider" ]]; then
                        if [[ $current_model_index -eq 0 ]]; then
                            # Provider-level properties
                            PARSED_PROVIDERS["${current_provider}_${key}"]="$value"
                        else
                            # Model-level properties
                            PARSED_MODELS["${current_provider}_${current_model_index}_${key}"]="$value"
                        fi
                    fi
                    ;;
            esac
        fi
    done < "$AI_SERVICES_PROPERTY_FILE"
    
    # Validate: At least one provider must be enabled
    local enabled_provider_count=0
    for key in "${!PARSED_PROVIDERS[@]}"; do
        if [[ "$key" =~ ^([0-9]+)_ENABLED$ ]]; then
            local enabled_value="${PARSED_PROVIDERS[$key]}"
            if [[ "$enabled_value" == "true" ]]; then
                enabled_provider_count=$((enabled_provider_count + 1))
            fi
        fi
    done
    
    if [[ $enabled_provider_count -eq 0 ]]; then
        error "At least one provider in the AI Services property file must be enabled to proceed and this can be done by setting ENABLED=true in the propertyfile for atleast 1 provider."
        return 1
    fi
    
    # Validate: Exactly one model must have DEFAULT=true
    local default_model_count=0
    local default_model_provider=""
    local default_model_index=""
    local -a default_models_list=()
    
    for key in "${!PARSED_MODELS[@]}"; do
        if [[ "$key" =~ ^([0-9]+)_([0-9]+)_DEFAULT$ ]]; then
            local provider_num="${BASH_REMATCH[1]}"
            local model_num="${BASH_REMATCH[2]}"
            local default_value="${PARSED_MODELS[$key]}"
            
            if [[ "$default_value" == "true" ]]; then
                # Check if this provider is enabled
                local provider_enabled="${PARSED_PROVIDERS[${provider_num}_ENABLED]}"
                if [[ "$provider_enabled" == "true" ]]; then
                    default_model_count=$((default_model_count + 1))
                    default_model_provider="$provider_num"
                    default_model_index="$model_num"
                    
                    # Get model details for error reporting
                    local model_id="${PARSED_MODELS[${provider_num}_${model_num}_MODEL_ID]}"
                    local provider_id="${PARSED_PROVIDERS[${provider_num}_PROVIDER_ID]}"
                    default_models_list+=("Provider: $provider_id (PROVIDER_$provider_num), Model: $model_id")
                fi
            fi
        fi
    done
    
    if [[ $default_model_count -eq 0 ]]; then
        error "Exactly one model across all enabled providers must be selected as the default LLM model"
        error "No default model found. Please set DEFAULT=true for exactly one model in an enabled provider"
        return 1
    elif [[ $default_model_count -gt 1 ]]; then
        error "Exactly one model across all enabled providers must be selected as the default LLM model"
        error "Found $default_model_count models with DEFAULT=true:"
        for model_info in "${default_models_list[@]}"; do
            error "  - $model_info"
        done
        error "Please set DEFAULT=false for all but one model"
        return 1
    fi
    
    return 0
}
# Validate SSL certificates for WatsonX LWE providers with SSL enabled
#
# Purpose:
#   Validates that SSL certificates exist and are valid for WatsonX Lightweight Engine
#   providers that have SSL_ENABLED=true. This is required for self-signed certificates
#   or custom CA certificates.
#
# Prerequisites:
#   - PARSED_PROVIDERS array must be populated (from parse_multi_provider_property_file)
#   - check_ssl_cert helper function must be available (from common.sh)
#   - Certificate files must be in PEM format with .crt extension
#
# Certificate Requirements:
#   - File name: lwe.crt (fixed name)
#   - Location: Specified in TLS_CERT_LOCATION property
#   - Format: PEM-encoded X.509 certificate
#   - Full path: <TLS_CERT_LOCATION>/lwe.crt
#
# Validation Process:
#   1. Counts total providers in PARSED_PROVIDERS array
#   2. Iterates through each provider
#   3. Checks if provider is:
#      - Enabled (ENABLED=true)
#      - WatsonX LWE type (PROVIDER_NAME=watsonx_lightweightengine)
#      - SSL enabled (SSL_ENABLED=true)
#   4. For matching providers:
#      - Validates TLS_CERT_LOCATION is set
#      - Calls check_ssl_cert helper to validate certificate file
#      - Checks certificate exists, is readable, and is valid PEM format
#
# Behavior:
#   - Skips disabled providers
#   - Skips non-LWE providers (WatsonX SaaS, Azure)
#   - Skips LWE providers with SSL_ENABLED=false
#   - Returns success if no LWE providers have SSL enabled
#   - Validates all LWE providers with SSL enabled
#
# Returns:
#   0 - Success (all certificates valid or no SSL-enabled LWE providers)
#   1 - Failure (certificate validation failed or TLS_CERT_LOCATION not set)
#   2 - Skipped (no LWE providers with SSL enabled found)
#
# Error Conditions:
#   - TLS_CERT_LOCATION not set when SSL_ENABLED=true
#   - Certificate file does not exist
#   - Certificate file is not readable
#   - Certificate is not valid PEM format
#   - Certificate is expired or not yet valid
#
function validate_watsonx_lwe_ssl_certificates() {
    local provider_count=0
    local has_lwe_ssl=false
    
    # Count total providers by looking for PROVIDER_ID keys
    for key in "${!PARSED_PROVIDERS[@]}"; do
        if [[ "$key" =~ ^([0-9]+)_PROVIDER_ID$ ]]; then
            provider_count=$((provider_count + 1))
        fi
    done
    
    # Check each provider for LWE with SSL enabled
    for ((i=1; i<=provider_count; i++)); do
        local provider_id="${PARSED_PROVIDERS[${i}_PROVIDER_ID]}"
        local provider_name="${PARSED_PROVIDERS[${i}_PROVIDER_NAME]}"
        local provider_enabled="${PARSED_PROVIDERS[${i}_ENABLED]}"
        local ssl_enabled="${PARSED_PROVIDERS[${i}_SSL_ENABLED]}"
        local tls_cert_location="${PARSED_PROVIDERS[${i}_TLS_CERT_LOCATION]}"
        
        # Skip if provider is disabled or not LWE or SSL not enabled
        if [[ "$provider_enabled" != "true" ]] || [[ "$provider_name" != "watsonx_lightweightengine" ]] || [[ "$ssl_enabled" != "true" ]]; then
            continue
        fi
        
        has_lwe_ssl=true
        
        # Validate certificate location is set
        if [[ -z "$tls_cert_location" ]]; then
            error "Provider $provider_id: TLS_CERT_LOCATION is required when SSL_ENABLED=true"
            return 1
        fi
        
        # Use the existing check_ssl_cert helper function from common.sh
        # This validates the certificate exists, is readable, and is valid PEM format
        local cert_file="$tls_cert_location/lwe.crt"
        check_ssl_cert \
            "certificate" \
            "WatsonX LWE ($provider_id)" \
            "$cert_file" \
            "SSL certificate for WatsonX Lightweight Engine provider '$provider_id' is missing at: $cert_file" \
            "SSL certificate for WatsonX Lightweight Engine provider '$provider_id' is invalid at: $cert_file" \
            "SSL certificate for WatsonX Lightweight Engine provider '$provider_id' is valid."
    done
    
    # If no LWE providers with SSL were found, return 2 to indicate skipped
    if [[ "$has_lwe_ssl" == "false" ]]; then
        return 2
    fi
    
    # Check if validation failed by checking the global arrays set by check_ssl_cert
    if [[ ${#MISSING_CERTS[@]} -gt 0 ]] || [[ ${#FAILING_CERTS[@]} -gt 0 ]]; then
        return 1
    fi
    
    return 0
}

# Run generate mode - read property file and generate deployment resources
#
# Purpose:
#   Reads the property file created in property mode, validates configuration,
#   and generates all necessary Kubernetes resources for deployment.
#
# Prerequisites:
#   - AI_SERVICES_PROPERTY_FILE must exist (created by property mode)
#   - NAMESPACE must be set
#   - Helper functions must be available:
#     * parse_multi_provider_property_file()
#     * validate_watsonx_lwe_ssl_certificates()
#     * generate_multi_provider_secret()
#     * create_watsonx_lwe_ssl_secret_template()
#     * generate_content_cortex_ai_services_cr()
#
# Workflow:
#   1. Check property file exists
#   2. Parse and validate property file
#      - Validates at least one enabled provider
#      - Validates exactly one default model
#   3. Set global variables from parsed configuration
#   4. Validate required storage class settings
#   5. Validate SSL certificates (if LWE with SSL enabled)
#   6. Generate provider configuration secret (JSON format)
#   7. Generate SSL secret template (if needed)
#   8. Generate Custom Resource YAML
#   9. Display generated artifact locations
#
# Validation Steps:
#   - Property file existence check
#   - Property file parsing and structure validation
#   - At least one enabled provider
#   - Exactly one default model across all providers
#   - Required storage class configuration
#   - SSL certificate validation for LWE providers with SSL enabled
#
# Generated Artifacts:
#   1. Provider Configuration Secret (always):
#      - Location: AI_SERVICES_SECRET_FILE
#      - Format: Shell script that creates Kubernetes secret
#      - Content: JSON with provider and model configurations
#
#   2. SSL Certificate Secret (conditional):
#      - Location: AI_SERVICES_SECRET_FOLDER/ibm-watsonx-lwe-ssl-cert-secret.sh
#      - Created only if: LWE provider with SSL_ENABLED=true exists
#      - Format: Shell script that creates Kubernetes secret
#      - Content: SSL certificate for WatsonX LWE
#
#   3. Custom Resource (always):
#      - Location: CONTENT_CORTEX_AI_SERVICES_PATTERN_FILE_FINAL
#      - Format: Kubernetes YAML
#      - Content: CCXAIServices CR with storage and Redis configuration
#
# Error Handling:
#   - Exits with error if property file not found
#   - Exits with error if property file validation fails
#   - Exits with error if required storage class not set
#   - Exits with error if SSL certificate validation fails
#
# Returns:
#   Does not return (exits after displaying artifact locations)
#
function run_generate_mode() {
    clear
    printf '\n'
    info "Generate Mode: Creating secrets and custom resources"
    #printf '\n'
    
    # Clean up previous generate mode artifacts to ensure fresh generation
    # Remove secret folder, temp folder, and final CR folder from previous runs
    #info "Cleaning up previous generate mode artifacts..."
    rm -rf "$AI_SERVICES_SECRET_FOLDER" >/dev/null 2>&1
    #rm -rf "$TEMP_FOLDER" >/dev/null 2>&1
    # Delete only the content cortex_ai_SERVICES CR folder
    rm -rf "$FINAL_CR_FOLDER/content-cortex-ai-services" >/dev/null 2>&1
    #success "Cleanup completed"
    printf '\n'
    
    # Check if property file exists
    if [[ ! -f "$AI_SERVICES_PROPERTY_FILE" ]]; then
        error "Property file not found: $AI_SERVICES_PROPERTY_FILE"
        error "Please run property mode first: $SCRIPT_NAME -m property -n $NAMESPACE"
        exit 1
    fi
    
    info "Validating property file: $AI_SERVICES_PROPERTY_FILE"
    
    # Parse the property file (includes validation of enabled providers and default model)
    # This populates PARSED_PROVIDERS, PARSED_MODELS, and common configuration variables
    parse_multi_provider_property_file || {
        error "AI Services Property file validation failed"
        exit 1
    }
    
    # Set global variables for CR generation from parsed values
    ENABLE_REDIS="$PARSED_ENABLE_REDIS"
    CP4BA_SLOW_FILE_STORAGE_CLASSNAME="$PARSED_SLOW_STORAGE"
    CP4BA_BLOCK_STORAGE_CLASS_NAME="$PARSED_BLOCK_STORAGE"
    
    # Validate required values are present
    if [[ -z "$CP4BA_SLOW_FILE_STORAGE_CLASSNAME" ]]; then
        error "CP4BA_SLOW_FILE_STORAGE_CLASSNAME not found in property file"
        exit 1
    fi
    
    success "Property file validated successfully"
    printf '\n'
    
    # Validate SSL certificates for LWE providers with SSL enabled
    # Returns: 0 (valid), 1 (failed), 2 (skipped - no SSL)
    wait_msg "Validating SSL certificates for WatsonX LWE providers (if applicable)"
    validate_watsonx_lwe_ssl_certificates
    local ssl_validation_result=$?
    
    if [[ $ssl_validation_result -eq 0 ]]; then
        success "SSL certificate validation completed"
    elif [[ $ssl_validation_result -eq 2 ]]; then
        success "SSL certificate validation skipped (no LWE providers with SSL enabled)"
    else
        error "SSL certificate validation failed"
        error "Please ensure all required SSL certificates are in place and valid"
        exit 1
    fi
    printf '\n'
    
    # Generate the multi-provider secret (JSON format with provider configurations)
    wait_msg "Creating Content Cortex AI Services secret template"
    generate_multi_provider_secret
    success "Created Content Cortex AI Services secret template"
    printf '\n'
    
    # Determine if SSL secret template is needed
    local ssl_secret_created=false
    local ssl_secret_file="${AI_SERVICES_SECRET_FOLDER}/ibm-watsonx-lwe-ssl-cert-secret.sh"
    
    # Check if any LWE provider has SSL enabled
    local provider_count=0
    for key in "${!PARSED_PROVIDERS[@]}"; do
        if [[ "$key" =~ ^([0-9]+)_PROVIDER_ID$ ]]; then
            provider_count=$((provider_count + 1))
        fi
    done
    
    # Scan all providers to determine if SSL secret is needed
    for ((i=1; i<=provider_count; i++)); do
        local provider_name="${PARSED_PROVIDERS[${i}_PROVIDER_NAME]}"
        local provider_enabled="${PARSED_PROVIDERS[${i}_ENABLED]}"
        local ssl_enabled="${PARSED_PROVIDERS[${i}_SSL_ENABLED]}"
        
        if [[ "$provider_enabled" == "true" ]] && [[ "$provider_name" == "watsonx_lightweightengine" ]] && [[ "$ssl_enabled" == "true" ]]; then
            ssl_secret_created=true
            break
        fi
    done
    
    # Create SSL secret template if any LWE provider has SSL enabled
    create_watsonx_lwe_ssl_secret_template
    
    echo
    # Generate the Custom Resource YAML file
    wait_msg "Generating the Content Cortex AI Services Custom Resource File..."
    generate_content_cortex_ai_services_cr
    success "The Content Cortex AI Services Custom Resource has been generated successfully."
    
    # Display completion message and artifact locations
    printf '\n'
    success "Generate mode completed successfully!"
    printf '\n'
    info "Below are the locations of the Generated artifacts that are to be reviewed and applied to start the deployment of Content Cortex AI Services:"
    printf '\n'
    echo "  [1] Content Cortex AI Services Secret:"
    echo "      $AI_SERVICES_SECRET_FILE"
    printf '\n'
    if [[ "$ssl_secret_created" == "true" ]]; then
        echo "  [2] WatsonX LWE SSL Certificate Secret:"
        echo "      $ssl_secret_file"
        printf '\n'
        echo "  [3] Content Cortex AI Services Custom Resource:"
        echo "      $CONTENT_CORTEX_AI_SERVICES_PATTERN_FILE_FINAL"
    else
        echo "  [2] Content Cortex AI Services Custom Resource:"
        echo "      $CONTENT_CORTEX_AI_SERVICES_PATTERN_FILE_FINAL"
    fi
    printf '\n'
}

# Main CLI entrypoint for standalone script execution
#
# Purpose:
#   Provides command-line interface for Content Cortex AI Services setup when
#   the script is executed directly (not sourced). Supports two modes:
#   - Property mode: Interactive provider configuration and property file generation
#   - Generate mode: Secret and Custom Resource generation from property file
#
# Usage:
#   Property Mode:
#     ./cp4a-content-cortex-ai-services-setup.sh -m property -n <namespace>
#
#   Generate Mode:
#     ./cp4a-content-cortex-ai-services-setup.sh -m generate -n <namespace>
#
# Command-Line Arguments:
#   -m <mode>      Required. Mode of operation: 'property' or 'generate'
#   -n <namespace> Required. Target OpenShift namespace/project for deployment
#   -h, --help     Display help message and exit
#
# Execution Flow:
#   1. Parse and validate command-line arguments
#   2. Source required helper libraries (common.sh, cp4ba-secret.sh, cp4ba-property.sh)
#   3. Initialize logging for the session
#   4. Validate cluster connection and namespace existence
#   5. Execute appropriate mode function (run_property_mode or run_generate_mode)
#
# Sourcing Behavior:
#   When this script is sourced by another script (e.g., cp4a-prerequisites.sh,
#   cp4a-deployment.sh), the main() function is NOT executed automatically.
#   This allows other scripts to:
#   - Import function definitions without triggering CLI behavior
#   - Call specific functions as needed (e.g., generate_multi_provider_property_file)
#   - Integrate AI Services setup into larger workflows
#
# Direct Execution vs Sourcing:
#   Direct Execution (./script.sh):
#     - main() is called automatically
#     - CLI argument parsing is performed
#     - Helper libraries are sourced
#     - Logging is initialized
#     - Full standalone workflow is executed
#
#   Sourced (source script.sh):
#     - main() is NOT called
#     - Functions are made available to calling script
#     - Calling script is responsible for:
#       * Sourcing helper libraries
#       * Setting required variables (NAMESPACE, etc.)
#       * Calling specific functions as needed
#
# Prerequisites (Direct Execution):
#   - OpenShift CLI (oc) installed and in PATH
#   - Valid cluster login (oc login completed)
#   - Target namespace/project must exist
#   - Write permissions to cp4ba-prerequisites directory
#
# Exit Codes:
#   0 - Success
#   1 - Error (invalid arguments, validation failure, etc.)
#
# Examples:
#   # Generate property file interactively
#   ./cp4a-content-cortex-ai-services-setup.sh -m property -n my-namespace
#
#   # Generate secrets and CR from property file
#   ./cp4a-content-cortex-ai-services-setup.sh -m generate -n my-namespace
#
#   # Display help
#   ./cp4a-content-cortex-ai-services-setup.sh --help
#
function main() {
    # Check for --help first
    for arg in "$@"; do
        if [[ "$arg" == "--help" ]]; then
            show_help
            exit 0
        fi
    done

    # Parse command-line arguments for direct execution.
    local MODE=""
    
    while getopts ":m:n:h" opt; do
        case "$opt" in
            m)
                MODE="$OPTARG"
                ;;
            n)
                NAMESPACE="$OPTARG"
                ;;
            h)
                show_help
                exit 0
                ;;
            :)
                printf '%s\n' "Error: Option -$OPTARG requires an argument"
                show_help
                exit 1
                ;;
            \?)
                printf '%s\n' "Error: Invalid option -$OPTARG"
                show_help
                exit 1
                ;;
        esac
    done

    # Validate that mode and namespace were supplied
    if [[ -z "$MODE" ]]; then
        printf '%s\n' "Error: Mode (-m) is required. Use 'property' or 'generate'"
        show_help
        exit 1
    fi
    
    if [[ -z "$NAMESPACE" ]]; then
        printf '%s\n' "Error: Namespace (-n) is required"
        show_help
        exit 1
    fi
    
    # Validate mode value
    if [[ "$MODE" != "property" && "$MODE" != "generate" ]]; then
        printf '%s\n' "Error: Invalid mode '$MODE'. Use 'property' or 'generate'"
        show_help
        exit 1
    fi
    
    # Source the helper libraries required only for direct execution.
    source ${CUR_DIR}/helper/common.sh "$NAMESPACE"
    source ${CUR_DIR}/helper/cp4ba-secret.sh
    source ${CUR_DIR}/helper/cp4ba-property.sh

    # Initialize logging for the script when executed on its own
    save_log "cp4a-script-logs/project/$NAMESPACE" "cp4a-content-cortex-ai-services-setup-log" "true"
    trap cleanup_log EXIT

    check_cluster_login

    # Check project name
    isProjExists=`${CLI_CMD} get project $NAMESPACE --ignore-not-found | wc -l`  >/dev/null 2>&1
    if [ $isProjExists -ne 2 ] ; then
        printf '%b\n' "\x1B[1;31mInvalid project name \"$NAMESPACE\", enter a valid name...\x1B[0m"
        exit 1
    fi

    # Begin the appropriate flow based on mode
    if [[ "$MODE" == "property" ]]; then
        run_property_mode
    elif [[ "$MODE" == "generate" ]]; then
        run_generate_mode
    fi
}

# Only execute the CLI flow when the script is run directly.
# When sourced by another script, expose the reusable functions without auto-executing.
# This is what allows other scripts to source mode_runner.sh and call only
# the specific helper they need.
if [[ "${BASH_SOURCE[0]}" == "$0" ]]; then
    main "$@"
fi