#!/bin/bash

###############################################################################
#
# Licensed Materials - Property of IBM
#
# (C) Copyright IBM Corp. 2025. All Rights Reserved.
#
# US Government Users Restricted Rights - Use, duplication or
# disclosure restricted by GSA ADP Schedule Contract with IBM Corp.
#
###############################################################################


################################################################################
#### Start of Variables used by different functions defined in this script #####
################################################################################

deployment_pattern_names=("FileNet Content Manager" "Operational Decision Manager" "Automation Decision Services" "Business Automation Application" "Business Automation Workflow" "(a) Workflow Authoring" "(b) Workflow Runtime" "Automation Workstream Services" "IBM Automation Document Processing" "(a) Development Environment" "(b) Runtime Environment" "Workflow Process Service Authoring")
deployment_pattern_cr_names=("content" "decisions" "decisions_ads" "application" "workflow" "workflow-authoring" "workflow-runtime" "workstreams" "document_processing" "document_processing_designer" "document_processing_runtime" "workflow-process-service")
optional_components_names=("Content Search Services" "Content Management Interoperability Services" "IBM Enterprise Records" "IBM Content Collector for SAP" "Business Automation Insights" "Task Manager" "Decision Center" "Rule Execution Server" "Decision Runner" "Decision Designer and Decision Runtime" "Decision Runtime" "Data Collector and Data Indexer" "Exposed Kafka Services" "Exposed OpenSearch" "Workplace Assistant" "(Preview) Authoring Assistant" "Application Designer" )
optional_components_cr_names=("css" "cmis" "ier" "iccsap" "bai" "tm" "decisionCenter" "decisionServerRuntime" "decisionRunner" "ads_designer" "ads_runtime" "pfs" "kafka"  "opensearch" "workplace_assistant" "workflow_assistant" "app_designer" "document_processing_runtime" "wfps_authoring" "ae_data_persistence" "document_processing_designer" "baw_authoring")

ldap_type_cr_options=("Microsoft Active Directory" "IBM Security Directory Server" "PingDirectory Server" "Custom")
ldap_type_cr_options_mapping=("AD" "TDS" "PDS" "custom")
summary_display_keys=()
summary_display_values=()

################################################################################
###### End of Variables used by different functions defined in this script #####
################################################################################


####################################
#### Start of Utility functions ####
####################################

# Function to set the property file paths for the original property files
function set_property_file_paths(){
    local directory=$1
    ORIGINAL_PROPERTY_FILE_FOLDER=${directory}
    ORIGINAL_DB_USER_PROPERTY_FILE=${directory}/cp4ba_db_name_user.property
    ORIGINAL_DB_SERVER_PROPERTY_FILE=${directory}/cp4ba_db_server.property
    ORIGINAL_LDAP_PROPERTY_FILE=${directory}/cp4ba_LDAP.property
    ORIGINAL_USER_PROFILE_PROPERTY_FILE=${directory}/cp4ba_user_profile.property
    ORIGINAL_TMP_PROPERTY_FILE=${directory}/.original_TEMPORARY.property
}

# Function to retrieve a property value from the original LDAP property file based on a property passed as the first argument
function prop_original_ldap_property_file() {
    grep "^${1}=" ${ORIGINAL_LDAP_PROPERTY_FILE}|cut -d'"' -f2
}

# Function to retrieve a property value from the original user profile property file based on a property passed as the first argument
function prop_original_user_profile_property_file() {
    grep "^${1}=" ${ORIGINAL_USER_PROFILE_PROPERTY_FILE}|cut -d'"' -f2
}

# Function to retrieve a property value from the original DB server property file based on a property passed as the first argument
function prop_original_db_server_property_file() {
    grep "^${1}=" ${ORIGINAL_DB_SERVER_PROPERTY_FILE}|cut -d'"' -f2
}


# Function that adds new key value pairs to a set of lists used to display a summary table
function add_entry_for_summary() {
    local key="$1"
    #local val="$2"
    shift
    local val="$*"

    summary_display_keys+=("$key")
    summary_display_values+=("$val")
}

# Function to display a summary table of all current configurations selected by the user.
function print_current_summary_table() {
    local cr_namespace=$1 
    info "The current configurations for the active Deployment in $cr_namespace are listed below."
    printf "\n"
    # Header
    printf "\n%-50s | %-50s\n" "Configuration" "Value"
    printf "%-50s-+-%-50s\n" "--------------------------------------------------" "--------------------------------------------------"

    for i in "${!summary_display_keys[@]}"; do
        if [[ -z "${summary_display_values[$i]}" ]]; then
            printf "%-50s | %-50s\n" "${summary_display_keys[$i]}" "N/A"
        else
            printf "%-50s | %-50s\n" "${summary_display_keys[$i]}" "${summary_display_values[$i]}"
        fi
    done
    echo
    while true; do
        printf "\x1B[1mDo you want to continue to update the current list of Deployment Patterns and Optional Components deployed? (Yes/No)(default No): \x1B[0m"
        read -rp "" ans
        if [[ -z "$ans" ]];then
            ans="no"
        fi
        ans=$(echo "$ans" | tr '[:upper:]' '[:lower:]')
        case "$ans" in
        "y"|"yes")
            break
            ;;
        "n"|"no")
            echo
            error "The script will now exit, please run \"cp4a-prerequisites.sh\" in property mode with the \"--update-components\" to generate the updated set of property files"
            exit
            ;;
        *)
            error "Answer must be \"Yes\" or \"No\"\n"
            ;;
        esac
    done

}

# Function to copy original property files to a subfolder where the new property files get generated
function copy_original_property_files(){
    if [[ -d "$PROPERTY_FILE_FOLDER/original_property_files" ]]; then
        rm -rf "$PROPERTY_FILE_FOLDER/original_property_files"
    fi
    mkdir -p $PROPERTY_FILE_FOLDER/original_property_files
    cp $ORIGINAL_DB_USER_PROPERTY_FILE $PROPERTY_FILE_FOLDER/original_property_files/
    cp $ORIGINAL_DB_SERVER_PROPERTY_FILE $PROPERTY_FILE_FOLDER/original_property_files/
    cp $ORIGINAL_LDAP_PROPERTY_FILE $PROPERTY_FILE_FOLDER/original_property_files/
    cp $ORIGINAL_USER_PROFILE_PROPERTY_FILE $PROPERTY_FILE_FOLDER/original_property_files/
    set_property_file_paths "$PROPERTY_FILE_FOLDER/original_property_files"
}

# Function to copy original CR to a subfolder where the new CR gets generated
function copy_original_cr(){
    local cr_type=$1
    local cr_name=$2
    local cr_namespace=$3
    local folder_name=$FINAL_CR_FOLDER/original_custom_resource_file
    # Making sure the Final CR folder and the sub folder i.e original_custom_resource_file is recreated each time update-components flag is being called
    # https://jsw.ibm.com/browse/DBACLD-200329
    rm -rf $FINAL_CR_FOLDER >/dev/null 2>&1
    mkdir -p $FINAL_CR_FOLDER >/dev/null 2>&1
    mkdir -p $folder_name >/dev/null 2>&1
    
    current_cr=$(${CLI_CMD} get $cr_type $cr_name -n $cr_namespace -o yaml)
    if [[ "$cr_type" == "content" ]]; then
        filename=$folder_name/original_ibm_content_cr.yaml
    else
        filename=$folder_name/original_ibm_cp4a_cr.yaml
    fi
    printf "%s\n" "$current_cr" > $filename
    #cp -r $ORIGINAL_PROPERTY_FILE_FOLDER/* $PROPERTY_FILE_FOLDER/original_property_files/

}

# Function to update a single property file
# The function loops over each property in the new property file and if it finds a matching key in the original property file, it updates the new property file with the corresponding value
function update_single_property_file(){
    local updated_property_file=$1
    local original_property_file=$2
    local skip_keys=$3
    local prefix="${db_server_array[0]}"
    
    # Check if this is a property file that might contain Case History Emitter properties
    local is_case_history_file=false
    if grep -q "$prefix.CHOS_DB_NAME" "$original_property_file" || grep -q "Case History Emitter" "$original_property_file"; then
        is_case_history_file=true
        
        # Hardcoded list of Case History Emitter properties that might need uncommenting
        local case_history_keys="$prefix.CHOS_DB_NAME $prefix.CHOS_DB_CURRENT_SCHEMA $prefix.CHOS_DB_USER_NAME $prefix.CHOS_DB_USER_PASSWORD"
        
        # First pass: Check if any of these keys are uncommented in the original file
        # If they are, we'll uncomment them in the updated file
        for case_key in $case_history_keys; do
            if grep -q "^[[:space:]]*$case_key=" "$original_property_file"; then
                
                # Get value from original property file
                val=$(grep "^[[:space:]]*$case_key=" "$original_property_file" | cut -d'=' -f2- | sed -e 's/^[[:space:]]*"//' -e 's/"[[:space:]]*$//')
                
                # Skip if value is empty
                if [[ -z "$val" ]]; then
                    continue
                fi
                
                # Properly escape special characters for sed
                val_escaped=$(printf '%s' "$val" | sed -e 's/\\/\\\\/g' -e 's/&/\\\&/g' -e 's/\//\\\//g' -e 's/(/\\(/g' -e 's/)/\\)/g' -e 's/|/\\|/g')
                
                # Add quotes back
                val_escaped="\"$val_escaped\""
                
                # Uncomment and update the line in the target file
                # First check if the commented version exists
                if grep -q "^[[:space:]]*#[[:space:]]*$case_key=" "$updated_property_file"; then
                    ${SED_COMMAND} "s|^[[:space:]]*#[[:space:]]*$case_key=.*|$case_key=$val_escaped|" "$updated_property_file"
                fi
            fi
        done
    fi
    # Process the updated file for regular properties
    while IFS= read -r line; do
        # Skip empty lines
        if [[ -z "$line" ]]; then
            continue
        fi

        # Skip pure comment lines (lines starting with ##)
        if echo "$line" | grep -q "^[[:space:]]*##"; then
            continue
        fi
        
        # Skip commented property lines (already handled above for Case History)
        if echo "$line" | grep -q "^[[:space:]]*#[[:space:]]*[^#][^=]*="; then
            continue
        fi
        
        # Process regular property lines
        if echo "$line" | grep -q "^[[:space:]]*[^#][^=]*="; then
            # Extract the key and remove whitespace
            key=$(echo "$line" | sed -e 's/=.*//' | tr -d '[:space:]')
            
            # Skip if key is in skip_keys list
            skip=false
            if [[ -n "$skip_keys" ]]; then
                for skip_key in $skip_keys; do
                    if [[ "$key" == "$skip_key" ]]; then
                        skip=true
                        break
                    fi
                done
            fi
            
            if [[ "$skip" == "true" ]]; then
                continue
            fi
            
            # Get value from original property file
            val=$(grep "^[[:space:]]*$key=" "$original_property_file" | cut -d'=' -f2- | sed -e 's/^[[:space:]]*"//' -e 's/"[[:space:]]*$//')
            
            # Skip if value is empty
            if [[ -z "$val" ]]; then
                continue
            fi
            
            # Properly escape special characters for sed
            val_escaped=$(printf '%s' "$val" | sed -e 's/\\/\\\\/g' -e 's/&/\\\&/g' -e 's/\//\\\//g' -e 's/(/\\(/g' -e 's/)/\\)/g' -e 's/|/\\|/g')
            
            # Add quotes back
            val_escaped="\"$val_escaped\""
            
            # Update the value
            ${SED_COMMAND} "s|^[[:space:]]*$key=.*|$key=$val_escaped|" "$updated_property_file"
        fi
    done < "$updated_property_file"
}


# Function to check if all required files exist in a given directory
function check_required_files() {
  local folder="$1"
  local required_files=("cp4ba_db_name_user.property" "cp4ba_db_server.property" "cp4ba_LDAP.property" "cp4ba_user_profile.property")
  missing_files=()
  for file in "${required_files[@]}"; do
    if [[ ! -f "$folder/$file" ]]; then
      missing_files+=("$file")
    fi
  done
  if [[ ${#missing_files[@]} -eq 0 ]]; then
    return 0  # All files present
  else
    return 1  # Some files missing
  fi
}

# Function that checks if the SSL cert folder exists when the user is executing the script in update-components mopde
# IF it does we only recreate the empty directories, any 
function recreate_empty_ssl_directories() {
    local folder_path="$1"
    
    # Check if the folder path exists
    if [ ! -d "$folder_path" ]; then
        echo "Error: Directory '$folder_path' does not exist"
        return 1
    fi
    
    # Find all directories recursively
    find "$folder_path" -type d | while read -r dir; do
        # Check if the directory has atleast 1 file
        file_count=$(find "$dir" -maxdepth 1 -type f -name "*.crt" | wc -l)
        
        # IF it does not have any files we can enter this loop to check if it does not have any sub directories
        if [ "$file_count" -eq 0 ]; then
            # check if the directory is a sub directory or not
            subdir_count=$(find "$dir" -mindepth 1 -maxdepth 1 -type d | wc -l)
            
            # If it has no files and no subdirectories, it's completely empty
            if [ "$subdir_count" -eq 0 ]; then
                # Remove and recreate the directory
                rm -rf "$dir"
                mkdir -p "$dir"
            fi
        fi
    done

}


####################################
#### END of Utility functions ######
####################################



############################################################################################################################
#### Start of function definitions of helper functions used to retrieve the relevant details of the current deployment #####
############################################################################################################################

# Function to retrieve the current deployment patterns from the live CR file
function retrieve_current_deployment_patterns(){
    local cr_type=$1
    # Based on the CR type, the CR parameters that hold the deployment patterns and list of optional components are different.
    if [[ "$cr_type" == "icp4acluster" ]]; then 
        current_cr_deployment_patterns=$(echo "$cr_output" | ${YQ_CMD} '.spec.shared_configuration.sc_deployment_patterns' -)
    elif [[ "$cr_type" == "content" ]]; then
        current_cr_deployment_patterns="content"
    fi
        
    current_cr_deployment_patterns_name_array=()
    current_cr_deployment_patterns_name_display_array=""
    current_cr_deployment_patterns=$(echo "$current_cr_deployment_patterns" | sed 's/\(,\)\?foundation\(,\)\?//g' | sed 's/,,/,/g' | sed 's/^,//' | sed 's/,$//')
    IFS=',' read -ra current_cr_deployment_patterns_array <<< "$current_cr_deployment_patterns"
    
    
    # From the list of deployment patterns and optional components , we want to create a list of their full names that would be used by cp4a-prerequisites.sh script in different parts of the script
    for input in "${current_cr_deployment_patterns_array[@]}"; do
        if [[ "$input" == "workflow" ]]; then
            workflow_pattern_selected="true"
        fi
        for i in "${!deployment_pattern_cr_names[@]}"; do
            if [[ "${deployment_pattern_cr_names[$i]}" == "$input" ]]; then
                # Defensive check to ensure index $i is valid for deployment_pattern_names
                if [[ $i -ge 0 && $i -lt ${#deployment_pattern_names[@]} ]]; then
                    current_cr_deployment_patterns_name_array+=("${deployment_pattern_names[$i]}")
                    # Using this array only for display purposes
                    current_cr_deployment_patterns_name_display_array=${deployment_pattern_names[$i]},$current_cr_deployment_patterns_name_display_array
                fi
            fi
        done
    done


        
    # THESE VARIABLES that are getting assigned must not change.
    # These variables are referenced by the functions in cp4a-prerequisites.sh to generate property files and in different code areas.
    EXISTING_PATTERN_ARR=("${current_cr_deployment_patterns_array[@]}")

    # Creating a summary dictionary to display the different configurations currently chosen
    # %? strips the last character, which i want to do because it would be a trailing comma
    add_entry_for_summary "Current Deployment Patterns Selected" "${current_cr_deployment_patterns_name_display_array%?}"  
}

# Function to retrieve the current optional components from the live CR file
function retrieve_current_optional_components(){
    local cr_type=$1
    # Based on the CR type, the CR parameters that hold the list of optional components are different.
    if [[ "$cr_type" == "icp4acluster" ]]; then 
        current_cr_optional_components=$(echo "$cr_output" | ${YQ_CMD} '.spec.shared_configuration.sc_optional_components' -)
    elif [[ "$cr_type" == "content" ]]; then
        current_cr_optional_components=$(
            echo "$cr_output" | ${YQ_CMD} '.spec.content_optional_components' - \
            | grep ': true' \
            | awk -F':' '{print $1}' \
            | tr -d ' ' \
            | paste -sd "," -
        )
    fi
        
    current_cr_optional_components_name_array=()
    current_cr_optional_components_name_display_array=""
    if [[ ! -z "$current_cr_optional_components" ]]; then
        IFS=',' read -ra current_cr_optional_components_array <<< "$current_cr_optional_components"
    fi
        
    # From the list of optional components , we want to create a list of their full names that would be used by cp4a-prerequisites.sh script in different parts of the script
    for input in "${current_cr_optional_components_array[@]}"; do
        for i in "${!optional_components_cr_names[@]}"; do
            if [[ "${optional_components_cr_names[$i]}" == "$input" ]]; then
                # Defensive check to ensure index $i is valid for deployment_pattern_names
                if [[ $i -ge 0 && $i -lt ${#optional_components_names[@]} ]]; then
                    current_cr_optional_components_name_array+=("${optional_components_names[$i]}")
                    # Using this array only for display purposes
                    current_cr_optional_components_name_display_array=${optional_components_names[$i]},$current_cr_optional_components_name_display_array
                fi
            fi
        done
    done

        
    # THESE VARIABLES that are getting assigned must not change.
    # These variables are referenced by the functions in cp4a-prerequisites.sh to generate property files and in different code areas.  
    EXISTING_OPT_COMPONENT_ARR=("${current_cr_optional_components_array[@]}")
    for input in "${current_cr_optional_components_array[@]}"; do
        if [[ "$input" == "baw_authoring" ]]; then
            current_cr_deployment_patterns_name_array+=("workflow-authoring")
            EXISTING_PATTERN_ARR+=("workflow-authoring")
        fi
        if [[ "$input" == "document_processing_designer" ||  "$input" == "document_processing_runtime" ]]; then
            EXISTING_PATTERN_ARR+=("$input")
            current_cr_deployment_patterns_name_array+=("$input")
        fi
    done

    # If workflow pattern is selected, either workflow authoring or workflow runtime is selected NOT BOTH
    # If baw_authoring is there in the optional components then workflow authoring is selected and if its not then we know workflow runtime was selected
    if [[ $workflow_pattern_selected == "true" && !(" ${EXISTING_OPT_COMPONENT_ARR[@]} " =~ "baw_authoring") ]]; then
        EXISTING_PATTERN_ARR+=("workflow-runtime")
        current_cr_deployment_patterns_name_array+=("workflow-runtime")
    fi

    # Creating a summary dictionary to display the different configurations currently chosen
    # # %? strips the last character, which i want to do because it would be a trailing comma
    add_entry_for_summary "Current Optional Components Selected" "${current_cr_optional_components_name_display_array%?}" 
}


# Function to retrieve the currently chosen LDAP type from the original LDAP property files
function retrieve_ldap_type(){

    current_ldap_type_full_name="$(prop_original_ldap_property_file LDAP_TYPE)"
    for i in "${!ldap_type_cr_options[@]}"; do
        if [[ "${ldap_type_cr_options[$i]}" == "$current_ldap_type_full_name" ]]; then
            current_ldap_type="${ldap_type_cr_options_mapping[$i]}"
        fi
    done
    
    # THESE VARIABLES that are getting assigned must not change.
    # These variables are referenced by the functions in cp4a-prerequisites.sh to generate property files and in different code areas.
    LDAP_TYPE=$current_ldap_type
    
    # Creating a summary dictionary to display the different configurations currently chosen
    add_entry_for_summary "LDAP Directory Type" "${current_ldap_type_full_name}"
}

# Function to retrieve the currently chosen LDAP type from the live CR file.
function retrieve_storage_class(){
    current_slow_file_storage_classname=$(echo "$cr_output" | ${YQ_CMD} '.spec.shared_configuration.storage_configuration.sc_slow_file_storage_classname' -)
    current_medium_file_storage_classname=$(echo "$cr_output" | ${YQ_CMD} '.spec.shared_configuration.storage_configuration.sc_medium_file_storage_classname' -)
    current_fast_file_storage_classname=$(echo "$cr_output" | ${YQ_CMD} '.spec.shared_configuration.storage_configuration.sc_fast_file_storage_classname' -)
    current_block_storage_classname=$(echo "$cr_output" | ${YQ_CMD} '.spec.shared_configuration.storage_configuration.sc_block_storage_classname' -)

    
    # THESE VARIABLES that are getting assigned must not change.
    # These variables are referenced by the functions in cp4a-prerequisites.sh to generate property files and in different code areas.
    SLOW_STORAGE_CLASS_NAME=${current_slow_file_storage_classname}
    MEDIUM_STORAGE_CLASS_NAME=${current_medium_file_storage_classname}
    FAST_STORAGE_CLASS_NAME=${current_fast_file_storage_classname}
    BLOCK_STORAGE_CLASS_NAME=${current_block_storage_classname}


    # Creating a summary dictionary to display the different configurations currently chosen
    add_entry_for_summary "Slow Storage Class Name" "${current_slow_file_storage_classname}"
    add_entry_for_summary "Medium Storage Class Name" "${current_medium_file_storage_classname}"
    add_entry_for_summary "Fast Storage Class Name" "${current_fast_file_storage_classname}"
    add_entry_for_summary "Block Storage Class Name" "${current_block_storage_classname}"
}


# Function to retrieve the currently chosen profile size from the live CR file.
function retrieve_profile_size(){
    current_profile_size=$(echo "$cr_output" | ${YQ_CMD} '.spec.shared_configuration.sc_deployment_profile_size' -)
    
    # THESE VARIABLES that are getting assigned must not change.
    # These variables are referenced by the functions in cp4a-prerequisites.sh to generate property files and in different code areas.
    if [[ "$current_profile_size" != "null" ]]; then
        PROFILE_TYPE=${current_profile_size}
    else
        PROFILE_TYPE="small"
    fi

    # Creating a summary dictionary to display the different configurations currently chosen
    add_entry_for_summary "Deployment Profile Size" "${current_profile_size}"
    
}

# Function to retrieve the currently chosen jdbc drivers url if applicable from the live CR file.
function retrieve_jdbc_drivers_url(){
    current_jdbc_drivers_url=$(echo "$cr_output" | ${YQ_CMD} '.spec.shared_configuration.sc_drivers_url' -)
    
    if [[ "$current_jdbc_drivers_url" != "null" ]]; then
        # THESE VARIABLES that are getting assigned must not change.
        # These variables are referenced by the functions in cp4a-prerequisites.sh to generate property files and in different code areas.
        CP4BA_JDBC_URL=${current_jdbc_drivers_url}
    fi
}

# Function to retrieve the currently chosen deployment from the live CR file.
function retrieve_deployment_type(){
    local cr_type=$1
    
    # Based on the CR type the key that stores the deployment type is different
    if [[ "$cr_type" == "icp4acluster" ]]; then
        cr_key="spec.shared_configuration.sc_deployment_type"
    else
        cr_key="spec.content_deployment_type"
    fi
    current_deployment_type=$(echo "$cr_output" | ${YQ_CMD} ".$cr_key" -)
    
    # THESE VARIABLES that are getting assigned must not change.
    # These variables are referenced by the functions in cp4a-prerequisites.sh to generate property files and in different code areas.
    DEPLOYMENT_TYPE=${current_deployment_type}
    
}

# Function to retrieve the currently chosen deployment platform from the live CR file.
function retrieve_deployment_platform(){
    current_deployment_platform=$(echo "$cr_output" | ${YQ_CMD} '.spec.shared_configuration.sc_deployment_platform' -)
    
    # THESE VARIABLES that are getting assigned must not change.
    # These variables are referenced by the functions in cp4a-prerequisites.sh to generate property files and in different code areas.
    PLATFORM_SELECTED=${current_deployment_platform}
    
}

# Function to retrieve the currently chosen Database,database server name and list from the orginal database property file.
function retrieve_db_type(){
    current_db_servers="$(prop_original_db_server_property_file DB_SERVER_LIST)"
    IFS=',' read -ra current_db_servers_array <<< "$current_db_servers"
    current_db_server_number=${#current_db_servers_array[@]}
    
    current_db_server_type="$(prop_original_db_server_property_file ${current_db_servers_array[0]}.DATABASE_TYPE)"
    
    # THESE VARIABLES that are getting assigned must not change.
    # These variables are referenced by the functions in cp4a-prerequisites.sh to generate property files and in different code areas.
    db_server_number=${current_db_server_number}
    db_server_array=("${current_db_servers_array[@]}")
    DB_TYPE=${current_db_server_type}
    
    # Creating a summary dictionary to display the different configurations currently chosen
    add_entry_for_summary "Database Server Type" "${current_db_server_type}"
    add_entry_for_summary "Database Server List" "${current_db_servers_array[@]}"
}

# Function to retrieve the currently chosen fips configuration value from the live CR file.
function retrieve_fips_flag(){
    current_fips_flag=$(echo "$cr_output" | ${YQ_CMD} '.spec.shared_configuration.enable_fips' -)
    
    # THESE VARIABLES that are getting assigned must not change.
    # These variables are referenced by the functions in cp4a-prerequisites.sh to generate property files and in different code areas.
    if [[ "$current_fips_flag" != "null" ]]; then
        FIPS_ENABLED=${current_fips_flag}
    else
        FIPS_ENABLED="false"
    fi
    
}

# Function to retrieve the currently chosen value for generating network policy templates from the live CR file.
function retrieve_network_policy_flag(){
    current_network_policy_flag=$(echo "$cr_output" | ${YQ_CMD} '.spec.shared_configuration.sc_generate_sample_network_policies' -)
    
    # THESE VARIABLES that are getting assigned must not change.
    # These variables are referenced by the functions in cp4a-prerequisites.sh to generate property files and in different code areas.
    if [[ "$current_network_policy_flag" != "null" ]]; then
        GENERATE_SAMPLE_NETWORK_POLICIES=${current_network_policy_flag}
    else
        GENERATE_SAMPLE_NETWORK_POLICIES="false"
    fi

    # Creating a summary dictionary to display the different configurations currently chosen
    add_entry_for_summary "Network Policy template generation" "${current_network_policy_flag}"
    
}

# Function to retrieve the currently configured image repository from the live CR file.
function retrieve_current_image_repository(){
    current_image_repository_chosen=$(echo "$cr_output" | ${YQ_CMD} '.spec.shared_configuration.sc_image_repository' -)
    if [[ "$current_network_policy_flag" == "null" ]]; then
        current_image_repository_chosen="cp.icr.io"
    fi

}

# Function to retrieve the currently chosen iam admin value from the live CR file.
function retrieve_default_iam_admin(){
    current_default_iam_admin=$(echo "$cr_output" | ${YQ_CMD} '.spec.shared_configuration.sc_iam.default_admin_username' -)
    
    # THESE VARIABLES that are getting assigned must not change.
    # These variables are referenced by the functions in cp4a-prerequisites.sh to generate property files and in different code areas.
    if [[ -z "$current_default_iam_admin" ]]; then
        USE_DEFAULT_IAM_ADMIN="Yes"
    else
        if [[ "$current_default_iam_admin" == "cpadmin" ]]; then
            USE_DEFAULT_IAM_ADMIN="Yes"
        else
            USE_DEFAULT_IAM_ADMIN="No"
            NON_DEFAULT_IAM_ADMIN=${current_default_iam_admin}
            
        fi
    fi
    
}

# Function to retrieve the object store count from the live CR/ original property files.
function retrieve_object_store_count(){
    local cr_type=$1
    if [[ "$cr_type" == "content" ]]; then
        key_path=".spec.datasource_configuration.dc_os_datasources"

        # Check if the key exists
        if echo "$cr_output" | ${YQ_CMD} "$key_path" - >/dev/null 2>&1; then
            count=$(echo "$cr_output" | ${YQ_CMD} "$key_path" - | grep -c '^- ')
            content_os_number=$count
        else
            echo "$key_path not found"
            content_os_number=0
        fi
    else
        prefix="${db_server_array[0]}.OS"
        # Extract all keys that match the pattern PREFIX_DB_NAME
        # For example, dbserver.OS1_DB_NAME, dbserver.OS2_DB_NAME, etc.
        # if it cant find any such instances in the property file it will default to zero
        content_os_number=$(grep -E "^${prefix}[0-9]+_DB_NAME=" "$ORIGINAL_DB_USER_PROPERTY_FILE" | wc -l | tr -d ' ')
    fi

    # Creating a summary dictionary to display the different configurations currently chosen
    add_entry_for_summary "Number of Content Object Stores configured" "${content_os_number}"

}

# Function to retrieve the kafka details if applicable from the live CR file.
function retrieve_external_cert_opensearch_kafka(){
    current_external_cert_opensearch_kafka_flag="$(prop_original_user_profile_property_file CP4BA.EXTERNAL_ROOT_CA_FOR_OPENSEARCH_KAFKA_FOLDER)"
    
    # THESE VARIABLES that are getting assigned must not change.
    # These variables are referenced by the functions in cp4a-prerequisites.sh to generate property files and in different code areas.
    if [[ -z "$current_external_cert_opensearch_kafka_flag" ]]; then
        EXTERNAL_CERT_OPENSEARCH_KAFKA="false"
    else
        EXTERNAL_CERT_OPENSEARCH_KAFKA="true"
    fi

}

# Function to retrieve the cpe full storage details if applicable from the live CR file.
function retrieve_cpe_full_storage_value(){
    current_cpe_limited_storage_flag=$(echo "$cr_output" | ${YQ_CMD} '.spec.shared_configuration.sc_cpe_limited_storage' -)
    # THESE VARIABLES that are getting assigned must not change.
    # These variables are referenced by the functions in cp4a-prerequisites.sh to generate property files and in different code areas.
    if [[ -z "$current_cpe_limited_storage_flag" ]]; then
        CPE_FULL_STORAGE="No"
    else
        if [[ "$current_cpe_limited_storage_flag" == "true" ]]; then
            CPE_FULL_STORAGE="No"
        else
            CPE_FULL_STORAGE="Yes"
        fi
    fi

}

# Function to retrieve the gpu details if applicable from the live CR file.
function retrieve_gpu_value(){
    current_gpu_flag=$(echo "$cr_output" | ${YQ_CMD} '.spec.ca_configuration.deeplearning.gpu_enabled' -)
    
    if [[ -z "$current_gpu_flag" ]]; then
        ENABLE_GPU_ARIA="No"
    else
        if [[ "$current_gpu_flag" == "true" ]]; then
            ENABLE_GPU_ARIA="Yes"
        else
            ENABLE_GPU_ARIA="No"
        fi
    fi

}


# Function to retrieve if external postgresql has been enabled for any of IM/BTS/ZEN from the original user property file
function retrieve_current_external_zen_configurations(){
    # THESE VARIABLES that are getting assigned must not change.
    # These variables are referenced by the functions in cp4a-prerequisites.sh to generate property files and in different code areas.
    check_external_im_property="$(prop_original_user_profile_property_file CP4BA.IM_EXTERNAL_POSTGRES_DATABASE_USER)"
    if [[ -z "$check_external_im_property" ]]; then
        EXTERNAL_POSTGRESDB_FOR_IM="false"
    else
        EXTERNAL_POSTGRESDB_FOR_IM="true"
    fi
    check_external_zen_property="$(prop_original_user_profile_property_file CP4BA.ZEN_EXTERNAL_POSTGRES_DATABASE_USER)"
    if [[ -z "$check_external_zen_property" ]]; then
        EXTERNAL_POSTGRESDB_FOR_ZEN="false"
    else
        EXTERNAL_POSTGRESDB_FOR_ZEN="true"
    fi
    check_external_bts_property="$(prop_original_user_profile_property_file CP4BA.BTS_EXTERNAL_POSTGRES_DATABASE_USER_NAME)"
    if [[ -z "$check_external_bts_property" ]]; then
        EXTERNAL_POSTGRESDB_FOR_BTS="false"
    else
        EXTERNAL_POSTGRESDB_FOR_BTS="true"
    fi
    

    # Creating a summary dictionary to display the different configurations currently chosen
    add_entry_for_summary "External PostgresDB enabled for IM" "${EXTERNAL_POSTGRESDB_FOR_IM}"
    add_entry_for_summary "External PostgresDB enabled for ZEN" "${EXTERNAL_POSTGRESDB_FOR_ZEN}"
    add_entry_for_summary "External PostgresDB enabled for BTS" "${EXTERNAL_POSTGRESDB_FOR_BTS}"
}

# Function to detect if the new CR is going to be a ICP4ACluster type CR
function required_icp4acluster_cr() {
    for pattern in "${PATTERNS_CR_SELECTED[@]}"; do
        if [[ "$pattern" != "foundation" && "$pattern" != "content" ]]; then
            return 0  
        fi    
    done
    
    return 1  
}

# Function that scaled down the foundation operator and deletes the foundation-cr-info configmap that is a required step when the new CR is ICP4ACluster CR and the live CR is Content type
function remove_foundation_cr_resources(){
    local cr_namespace=$1
    local foundation_deployment="icp4a-foundation-operator"
    local foundation_cr_info_configmap="ibm-cp4ba-foundation-cr-info"

    if $CLI_CMD get deployment "$foundation_deployment" -n "$cr_namespace" &>/dev/null; then
        $CLI_CMD scale deployment "$foundation_deployment" --replicas=0 -n "$cr_namespace"
    else
        info "Deployment $foundation_deployment not found.If the \"$foundation_deployment\" deployment is found in $cr_namespace namespace, make sure it has been scaled down before applying the new custom resource file."
    fi

    if $CLI_CMD get configmap "$foundation_cr_info_configmap" -n "$cr_namespace" &>/dev/null; then
        $CLI_CMD delete configmap "$foundation_cr_info_configmap" -n "$cr_namespace"
    else
        info "ConfigMap $foundation_cr_info_configmap not found. If the \"$foundation_cr_info_configmap\" configmap is found in $cr_namespace namespace, make sure it has been deleted before applying the new custom resource file."
    fi

}

# This is a sub function that takes in 4 parameters
# 1. Type of CR 
# 2. CR Name
# 3. Target Namespace where the CR has been applied
# 4. The script that is calling this is internally calling this function
function retrieve_current_specifications(){
    local cr_type=$1
    local cr_name=$2
    local cr_namespace=$3
    local script_request=$4
    
    # This variable will have the entire CR output
    cr_output="$(${CLI_CMD} get "$cr_type" "$cr_name" -n "$cr_namespace" -o yaml)"

    # Creating a summary dictionary to display the different configurations currently chosen
    add_entry_for_summary "Current Custom Resource Type" "$cr_type"
    add_entry_for_summary "Current Custom Resource Name" "$cr_name"
    
    # This code block retrieves all details required when the cp4a-prerequisites.sh script is run with the --update-components flag
    if [[ "$script_request" == "prerequisites_script" ]]; then

        # These functions retrieve values of certain configurations by either using the existing property files or by using the live CR
        # Once again these functions set the values retrieved in the same variables as the cp4a-prerequisites.sh would set if the script was being executed for a complete fresh install.
        retrieve_current_deployment_patterns "$cr_type"
        retrieve_current_optional_components "$cr_type"
        retrieve_ldap_type
        retrieve_storage_class
        retrieve_profile_size
        retrieve_db_type
        retrieve_fips_flag
        retrieve_network_policy_flag 
        retrieve_current_external_zen_configurations
        retrieve_object_store_count 
        retrieve_external_cert_opensearch_kafka
        retrieve_cpe_full_storage_value 
        retrieve_gpu_value

    fi

    # This code block retrieves all details required required by the cp4a-deployment.sh script to generate the new CR
    if [[ "$script_request" == "deployment_script" ]]; then
        
        # These functions retrieve values of certain configurations by either using the existing property files or by using the live CR
        # Once again these functions set the values retrieved in the same variables as the cp4a-prerequisites.sh would set if the script was being executed for a complete fresh install.
        retrieve_deployment_type "$cr_type"
        retrieve_deployment_platform 
        retrieve_storage_class
        retrieve_jdbc_drivers_url 
        retrieve_default_iam_admin
        retrieve_current_image_repository
        
        # Function that copies the live CR to a local folder
        copy_original_cr "$cr_type" "$cr_name" "$cr_namespace"
        
        # If the current CR type is Content and the script is going to generate a ICP4ACluster CR, certain foundation resources must be scaled down/deleted.
        if [[ "$cr_type" == "content" ]]; then
            if required_icp4acluster_cr; then
                echo
                remove_foundation_cr_resources "$cr_namespace"
            fi
        fi
    fi

}


############################################################################################################################
###### END of function definitions of helper functions used to retrieve the relevant details of the current deployment #####
############################################################################################################################


################################################################################################
##### Start of Main functions that are called by cp4a-prerequisites.sh & cp4a-deployment.sh ####
################################################################################################


# Function that requests the user to enter a folder path that has all 4 property files.
# The function will check if the folder supplied has all 4 property files and if not exits out
# This function is called directly by cp4a-prerequisites.sh when run with the property mode and the --update-components flag
function retrieve_existing_property_files() {
    local folder_path
    local default_path=$PROPERTY_FILE_FOLDER
    
    # Attempt to use the default path
    info "The \"cp4a-prerequisites.sh\" script is being executed in update mode to modify the selected deployment patterns and optional components for the current deployment. For more details on modifying the selected deployment patterns and optional components for the current deployment refer to https://www.ibm.com/docs/en/cloud-paks/cp-biz-automation/$CP4BA_RELEASE_BASE."
    echo 
    info "Checking if the default property file directory -> \"$default_path\" contains all required property files..."

    if check_required_files "$default_path"; then
        echo
        while true; do
            read -rp $'\033[1mAll required property files are found in the default path. Do you want to use this path? (Yes/No)[Default: Yes]: \033[0m' use_default
            use_default=$(echo "$use_default" | tr '[:upper:]' '[:lower:]')

            if [[ -z "$use_default" ]]; then
                use_default="yes"
            fi

            case "$use_default" in
                "y"|"yes")
                    folder_path="$default_path"
                    info "Using default directory: $folder_path"
                    break
                    ;;
                "n"|"no")
                    folder_path=""
                    break
                    ;;
                *)
                    echo -e "\033[1;33mPlease enter 'yes' or 'no'.\033[0m"
                    ;;
            esac
        done
    else
        warning "The required property files were not found in the default path: $default_path"
        folder_path=""
    fi

    # If not using default, prompt user for a directory
    if [[ -z "$folder_path" ]]; then
        echo
        echo "\033[1mEnter the directory path that contains all required property files:\033[0m"
        read -r folder_path

        # Validate directory
        if [[ ! -d "$folder_path" ]]; then
            error "Directory does not exist: $folder_path"
            exit 1
        fi

        # Check if required files are present
        if ! check_required_files "$folder_path"; then
            error "The following required property files are missing: ${missing_files[*]}"
            echo
            error "Please copy all required property files used to generate the custom resource file to a specific folder prior to running the \"cp4a-prerequisites.sh -m property\" with the --update-components flag."
            exit 1
        fi
    fi

    success "All required property files are present in the directory: $folder_path"

    set_property_file_paths "$folder_path"
    
    # Copy original property files
    copy_original_property_files
}



# Based the script_request -> prerequisites_script / deployment_script the details retrieved will be different
# cr_namespace is the target_namespace where the CR has been applied

function retrieve_current_custom_resource_file(){
    local cr_namespace=$1
    local script_request=$2
    cluster_cr_type=""
    cluster_cr_name=""

    #Logic that detects what the top level CR is in the deployment
    # If the content CR does not have an owner reference , it is the top level CR otherwise the top level CR is the ICP4ACLuster CR
    ${CLI_CMD} get crd |grep contents.icp4a.ibm.com >/dev/null 2>&1
    if [[ $? -eq 0 ]]; then
        cluster_cr_name=$(${CLI_CMD} get content -n $cr_namespace --no-headers --ignore-not-found | awk '{print $1}')
        if [[ ! -z $cluster_cr_name ]]; then
            owner_ref=$(${CLI_CMD} get content $cluster_cr_name -n $cr_namespace -o yaml | ${YQ_CMD} '.metadata.ownerReferences.[0].kind' -)
            if [[ ${owner_ref} != "ICP4ACluster" ]]; then
                cluster_cr_type="content"                
            fi
        fi
    fi

    if [[ -z "$cluster_cr_type" ]]; then
        cluster_cr_name=$(${CLI_CMD} get icp4acluster -n $cr_namespace --no-headers --ignore-not-found | awk '{print $1}')
        if [[ ! -z $cluster_cr_name ]]; then
            cluster_cr_type="icp4acluster"
        fi
    fi

    if [[ -z "$cluster_cr_type" || -z "$cluster_cr_name" ]]; then
        error "Could not find a IC4ACluster Kind Custom Resource file or a Content Kind Custom Resource file in the $cr_namespace namespace. The script will now exit."
        exit
    fi

    info "Processing the $cluster_cr_type Kind Custom Resource file named \"$cluster_cr_name\" to detect the current selection of deployment patterns, optional components and other specifications made by the user...."
    retrieve_current_specifications "$cluster_cr_type" "$cluster_cr_name" "$cr_namespace" "$script_request"
}


# Function that updates the set of new property files with properties that exist in the original property file
# For each property file that we update, certain properties will be skipped from being copied such as the SSL certificate folder paths
function update_property_files(){
    
    
    # Update LDAP property file
    info "Updating $LDAP_PROPERTY_FILE using the properties from the original property file"
    echo
    skip_ldap_properties_list=("LDAP_SSL_CERT_FILE_FOLDER")
    update_single_property_file "$LDAP_PROPERTY_FILE" "$ORIGINAL_LDAP_PROPERTY_FILE" "${skip_ldap_properties_list[@]}"
    success "Successfully updated the [cp4ba_LDAP.property] property file"

    
    # Update DB server property file
    skip_dbserver_properties_list=()
    for server in "${current_db_servers_array[@]}"; do
        skip_dbserver_properties_list+=("$server.DATABASE_SSL_CERT_FILE_FOLDER")
    done
    info "Updating $DB_SERVER_INFO_PROPERTY_FILE using the properties from the original property file"
    update_single_property_file "$DB_SERVER_INFO_PROPERTY_FILE" "$ORIGINAL_DB_SERVER_PROPERTY_FILE" "${skip_dbserver_properties_list[@]}"
    success "Successfully updated the [cp4ba_db_server.property] property file"

    # Update DB name user property file
    skip_dbnameuser_properties_list=()
    info "Updating $DB_NAME_USER_PROPERTY_FILE using the properties from the original property file"
    update_single_property_file "$DB_NAME_USER_PROPERTY_FILE" "$ORIGINAL_DB_USER_PROPERTY_FILE" "${skip_dbnameuser_properties_list[@]}"
    success "Successfully updated the [cp4ba_db_name_user.property] property file"

    # Update user profile property file
    skip_userprofile_properties_list=()
    info "Updating $USER_PROFILE_PROPERTY_FILE using the properties from the original property file"
    update_single_property_file "$USER_PROFILE_PROPERTY_FILE" "$ORIGINAL_USER_PROFILE_PROPERTY_FILE" "${skip_userprofile_properties_list[@]}"
    success "Successfully updated the [cp4ba_user_profile.property] property file"

    
}


################################################################################################
###### END of Main functions that are called by cp4a-prerequisites.sh & cp4a-deployment.sh #####
################################################################################################