#!/bin/bash
#set -x
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

source ${CUR_DIR}/helper/common.sh

export CURR_TIME=$(date "+%Y%m%d-%H%M%S")

# Below is the list of operators that are supported for network policies
#The array must be in the following format "label_key:label_value".  The reason for this is that the pod name is not always the same as the label value.
OPER_LIST=(
    "name:icp4a-foundation-operator"
    "name:ibm-cp4a-operator"
    "name:ibm-content-operator"
    "name:ibm-dpe-operator"
    "name:ibm-insights-engine-operator"
    "name:ibm-ads-operator"
    "name:ibm-cp4a-wfps-operator"
    "name:ibm-odm-operator"
    "name:ibm-pfs-operator"
    "name:ibm-workflow-operator"
    "app.kubernetes.io/name:ibm-bts-operator"
    )

# Below two lists will be used to track the different type of CR Kind types that need to be checked for while retrieving existing network policies
ICP4ACLUSTER_CR_KIND_MAPPING_LIST=("ICP4ACluster" "Content" "InsightsEngine" "ICP4AAutomationDecisionService" "WFPSRuntime" )
CONTENT_CR_KIND_MAPPING_LIST=( "Content" "Foundation" "InsightsEngine" )


# Helper function to validate arguments
function validate_args() {
    local arg_value="$1"
    local error_message="$2"
    if [[ -z "$arg_value" ]]; then
        echo "$error_message"
        return 1
    fi
}
# Purpose: Finds pod name (if pod is found) based on label name (key/value) "arg1=arg2"
# Args:
#  - $1: the label key name 
#  - $2: value for pod label key
#  - $3: namespace
# Returns (thru "echo"): the pod name
function get_pod_name_by_label_name () {

    local pod_label_key=$1
    local pod_label_value=$2
    local pod_namespace=$3
    
    validate_args "$pod_label_key" "ERROR: No label key provided." || exit 1
    validate_args "$pod_label_value" "ERROR: No label value provided." || exit 1
    validate_args "$pod_namespace" "ERROR: No namespace provided." || exit 1
    
    local pod_label="${pod_label_key}=${pod_label_value}"
    
    local pod_name=$(${CLI_CMD} get pod -l=${pod_label} -n ${pod_namespace} --no-headers | awk '{print $1}')
    
    echo ${pod_name}

}

function renameFolderIfItExists() {
    local folderPath=$1

    if [ -d ${folderPath} ]; then
       echo 
       info "The folder ${folderPath} already exist. The folder will be renamed to ${folderPath}_old_${CURR_TIME} "
       mv ${folderPath} ${folderPath}_${CURR_TIME}
    fi
}

# function to retrieve network policy templates
# Loops through each each operator folder path and copies them to the local template folder
# Arguments
# 1. List of potential operator paths where templates could be saved . It is a list because we might have operator and operand namespaces and each would have different folders in the operator where templates are stored for that namespace
# 2. List of local template paths ,each namespace gets a different folder path
function retrieve_network_policy_templates() {
    local operator_path_list=("${!1}")
    local target_template_path_list=("${!2}")
    for path in "${target_template_path_list[@]}"; do        
        renameFolderIfItExists ${path}
    done
    len="${#operator_path_list[@]}"

    for oper_name in "${OPER_LIST[@]}"
    do
        local label_key=$(echo ${oper_name} | cut -d':' -f1)
        local label_value=$(echo ${oper_name} | cut -d':' -f2)
        local output

        # cp4ba_operators_namespace is populated by the set_operator_operand_namespaces function
        pod_name=$(get_pod_name_by_label_name "${label_key}" "${label_value}" "${cp4ba_operators_namespace}" )
        # Only retrieve network policies if operator pod was found
        if [ -n "$pod_name" ]; then
            echo
            template_copy_skipped=true # This is a outer loop variable used to detect if any template copies happened
            # Loops through a list having all potential folder paths in the operator where the templates could be saved ( operators and operands folders are possible)
            for (( i=0; i<len; i++ )); do
                
                templates_present=false # This is an iterative variable used to check if a specific folder path exists in the operator and if not just skip the copy templates to local tasks
                # If we can find the folder path then that means the script must go ahead and copy templates to local
                # Hence we set the templates_present to true and template_copy_skipped to false
                if $CLI_CMD exec "$pod_name" -n "${cp4ba_operators_namespace}" -- test -d "${operator_path_list[$i]}" >/dev/null 2>&1; then
                    templates_present=true
                    template_copy_skipped=false
                fi

                #### BEGIN Code block to copy templates to local machine ###
                if [[ "$templates_present" == true ]]; then
                    echo "Retrieving network policy templates for ${label_value} ...."
                    echo " - Copying network policy templates from pod ${pod_name} ..."
                    
                    failed_copy=true
                    output=$($CLI_CMD -n ${cp4ba_operators_namespace} cp ${pod_name}:${operator_path_list[$i]} ${target_template_path_list[$i]} 2>&1)

                    printf "%s\n" "${output}" >> "${LOG_FILE}"
                    if ! echo ${output} | grep -qE "failure|failed"; then
                        failed_copy=false
                        echo " - Copied to dir ${target_template_path_list[$i]} ..."
                    fi
                   
                    # We only want to display this message in case we could not find any NPs in any location
                    if [[ "$failed_copy" == true ]]; then
                        warning " - Warning: Failed to copy network policy templates from pod ${pod_name}. Check log for details."
                        continue
                    fi
                fi
                #### END Code block to copy templates to local machine ###
            done

            # Only if we could not find any templates to copy from both operator and operand namespace we display this
            if [[ "$template_copy_skipped" == true ]]; then
                warning "- Warning: Skipping the copy of generated network policies in the pod ${pod_name}. This is likely because ${pod_name} is not used by your deployment pattern or the templates are not generated yet. You can run the script again after the templates are generated."
            fi   
        fi
       
    done

}


# This function will loop all the directories and sub-directories and apply or delete the network policies.  
# There are two modes: apply and delete.
# Args:
#  - $1: mode: apply or delete, replace
#  - $2: location: location of the network policy files
#  - $3: namespace: namespace where the template must be installed/patched/deleted

function install_delete_network_policies() {
    local mode=$1
    local location=$2
    local namespace=$3

    validate_args "$mode" "Invalid mode: Use 'apply' , 'delete' , 'replace'." || exit 1
    validate_args "$location" "Invalid location: Please provide a valid location." || exit 1

    local action_message=""
    if [[ "$mode" == "apply" ]]; then
        action_message="Installing"
    elif [[ "$mode" == "delete" ]]; then
        action_message="Deleting"
    # required at the time of upgrade where we want to remove the ownerreferences
    # During this step we ONLY go through the folder that with_ownerreference as that is the folder which has NPs managed by CP4BA operators and has a owner ref section that must be removed
    elif [[ "$mode" == "replace" ]]; then
        action_message="Patching"
        location="$location/with_ownerreference"
    else
        echo "Invalid mode: $mode. Use 'apply' or 'delete' or 'replace'."
        exit 1
    fi
    echo
    info "${action_message} network policies in the target namespace(s) ..."
    
    # Find all .yaml and .yml files in the directory and process them
    
    find ${location} -type f \( -name "*.yaml" -o -name "*.yml" \) | while read -r file; do
        echo
        echo " - ${action_message} network policy file ${file} ..."
        
        #retrieving the name and namespace from each template, this will be later used to check if a NP has been successfully installed/patched/deleted
        np_name=$(${YQ_CMD} ".metadata.name // \"\"" "${file}")
        np_namespace=$(${YQ_CMD} ".metadata.namespace // \"\"" "${file}")

        # For some reason there are certain components that are not generating templates with the namespace field and for those we use the namespace folder where the NP is saved
        if [[ -z $np_namespace ]]; then
            np_namespace=$namespace
        fi

        # Intervals required so that we can prevent server throttling and cache issues
        if [[ "$mode" == "delete" ]]; then
            sleep 2
            ${CLI_CMD} $mode -f "${file}" -n $np_namespace --ignore-not-found >> "${LOG_FILE}" 2>&1
        else
            sleep 2
            ${CLI_CMD} $mode -f "${file}" -n $np_namespace >> "${LOG_FILE}" 2>&1
        fi
        
        sleep 1

        # We are checking if a specific NP has been deleted/installed correctly and if not we display a message
        if ${CLI_CMD} get networkpolicy "$np_name" -n "$np_namespace" >/dev/null 2>&1; then
            if [[ "$mode" == "delete" ]]; then
                error "Error in ${action_message} network policy file ${np_name} from namespace ${np_namespace}."
            else
                success "Success in ${action_message} network policy file ${np_name} from namespace ${np_namespace}."
            fi
            continue
        else
            if [[ "$mode" == "delete" ]]; then
                success "Success in ${action_message} network policy file ${np_name} from namespace ${np_namespace}."
            else
                error "Error in ${action_message} network policy file ${np_name} from namespace ${np_namespace}."
            fi
            continue
        fi
    done

    echo
    echo "Network policies ${mode} successfully in the target namespace ${namespace} ..."
}

# This function will retrieve all existing network polices owned by a kind such as Content, ICP4AClusters,etc, then save them to a location
# Find all network policies in the namespace that has ownerReferences like this
# ownerReferences:
# - apiVersion: operator.ibm.com/v1
#   kind: ICP4ACluster
#   name: icp4adeploy
#   uid: 1b3b3b3b-3b3b-3b3b-3b3b-3b3b3b3b3b3b
# For NPs that do not have this section , they get saved to another folder
# Args:
#  - $1: kind: kind of the network policy
#  - $2: namespace: namespace of the network policy
#  - $3: location: location to save the network policy files

function retrieve_existing_network_policies() {
    local kind=$1
    local namespace=$2
    local location=$3
    validate_args "$kind" "Invalid kind: Please provide a valid kind." || exit 1
    validate_args "$namespace" "Invalid namespace: Please provide a valid namespace." || exit 1
    validate_args "$location" "Invalid location: Please provide a valid location." || exit 1

    renameFolderIfItExists ${location}
    mkdir -p "${location}"
    
    mkdir -p "${location}/with_ownerreference" # this location will be the one where we have NPs we need to further modify
    mkdir -p "${location}/without_ownerreference"  # this location will be the one where all other NPs will be present

    # Based on the CR type we have different child CR types that need to be checked for
    cr_kind_list=("${ICP4ACLUSTER_CR_KIND_MAPPING_LIST[@]}")
    if [[ $kind == "Content" ]]; then
        cr_kind_list=("${CONTENT_CR_KIND_MAPPING_LIST[@]}")
    fi
        
    
    # Get all NP names in a specific namespace
    np_names=$(${CLI_CMD} get networkpolicy -n "$namespace" -o jsonpath='{.items[*].metadata.name}')

    ### BEGIN Code to retrieve existing NPs from the cluster ####
    if [[ ! -z "$np_names" ]]; then
        echo "Retrieving existing network policies in the target namespace ${namespace}"
        for np in $np_names; do
            # Get the kind type mentioned in the ownerReference section
            np_kind=$(${CLI_CMD} get networkpolicy "$np" -n "$namespace" -o json | jq -r '.metadata.ownerReferences[0].kind // ""')
            matched=false
            # checking if the kind matches any of the CRs CP4BA owns
            for target_kind in "${cr_kind_list[@]}"; do
                if [[ "$np_kind" == "$target_kind" ]]; then
                    matched=true
                    break
                fi
            done
            echo
            echo " - Retrieving network policy ${np} ..."

            # if the kind type of the owner reference section matches with the list of kind CRs we are looking for then we save it a specific folder
            # the remaining NPs go into a different folder
            target_file="${location}/with_ownerreference/${np}_${namespace}.yaml"
            if [[ "$matched" == false ]]; then
                target_file="${location}/without_ownerreference/${np}_${namespace}.yaml"
            fi
            ${CLI_CMD} get networkpolicy "$np" -n "$namespace" -o yaml > "$target_file"
            if [[ $? -ne 0 ]]; then
                error " - Error: retrieving network policy ${np}."
                continue
            else
                echo " - Retrieved network policy ${np} ..."
            fi
        done
    else
        warning "There are no existing network policies in the target namespace ${namespace} ..." 
    fi
    ### END Code to retrieve existing NPs from the cluster ####

}

# This function will remove the owner reference from all the network policies for a location
# Find all .yaml and .yml files in the directory and remove the following block from the file
  # metadata.ownerReferences[]
  #metadata.creationTimestamp
  #metadata.generation
  #metadata.managedFields
  #metadata.resourceVersion
  #metadata.selfLink
  #metadata.uid
  #status
# Args:
#  - $1: location of the network policy files

function remove_owner_reference() {
    # The only NPs that require patching will be in the folder ending with with_ownerreference
    local location="$1/with_ownerreference"
    local namespace=$2
    validate_args "$location" "Invalid location: Please provide a valid location." || exit 1
    echo
    info "Removing owner reference from network policies in the target namespace ${namespace} ..."

    find ${location} -type f \( -name "*.yaml" -o -name "*.yml" \) | while read -r file; do
      echo
      echo " - Removing owner reference from network policy file ${file} ..."
        # Remove the specified metadata fields
        ${YQ_CMD} -i 'del(.metadata.ownerReferences)' "${file}" >> "${LOG_FILE}" 2>&1
        ${YQ_CMD} -i 'del(.metadata.creationTimestamp)' "${file}" >> "${LOG_FILE}" 2>&1
        ${YQ_CMD} -i 'del(.metadata.generation)' "${file}" >> "${LOG_FILE}" 2>&1
        ${YQ_CMD} -i 'del(.metadata.managedFields)' "${file}" >> "${LOG_FILE}" 2>&1
        ${YQ_CMD} -i 'del(.metadata.resourceVersion)' "${file}" >> "${LOG_FILE}" 2>&1
        ${YQ_CMD} -i 'del(.metadata.selfLink)' "${file}" >> "${LOG_FILE}" 2>&1
        ${YQ_CMD} -i 'del(.metadata.uid)' "${file}" >> "${LOG_FILE}" 2>&1
        ${YQ_CMD} -i 'del(.status)' "${file}" >> "${LOG_FILE}" 2>&1
        
        echo " - Removed owner reference and metadata from ${file}."
    done
    echo
    echo "Completed removing owner references and metadata from all network policy files in ${location}."
}

function cleanup_log() {
    # Check if the log file already exists
    if [[ -e $LOG_FILE ]]; then
        # Remove ANSI escape sequences from log file
        sed -E 's/\x1B\[[0-9;]+[A-Za-z]//g' "$LOG_FILE" > "$LOG_FILE.tmp" && mv "$LOG_FILE.tmp" "$LOG_FILE"
    fi
}

function save_log1() {    
    local LOG_DIR="$CUR_DIR/$1"
    LOG_FILE="$LOG_DIR/$2_$(date +'%Y%m%d%H%M%S').log"

    if [[ ! -d $LOG_DIR ]]; then
        mkdir -p "$LOG_DIR"
    fi

    # Commenting this out as it is throwing syntax errors in some machines
    # Redirect stdout and stderr directly to the log file
    #exec > >(tee -a "$LOG_FILE") 2>&1

#   # Redirect stdout and stderr directly to the log file
#    exec 3>&1 4>&2
#    exec > >(tee -a $LOG_FILE >&3) 2> >(tee -a $LOG_FILE >&4)
#    exec >>(tee -a "$LOG_FILE") 2>&1
#    #exec &> >(tee -a "$LOG_FILE")
#    #"$@" 2>&1 | tee "$LOG_FILE"
}


# Function that detects the operator and operand namespace so that the different modes can retrieve network policies accordingly
# Uses ibm-cp4ba-common-config to retrieve these values
function set_operator_operand_namespaces(){
    local namespace=$1
    if ${CLI_CMD} get configMap ibm-cp4ba-common-config -n $namespace >/dev/null 2>&1; then
        cp4ba_services_namespace=$(${CLI_CMD} get configMap ibm-cp4ba-common-config -n $namespace --no-headers --ignore-not-found -o jsonpath='{.data.services_namespace}')
        cp4ba_operators_namespace=$(${CLI_CMD} get configMap ibm-cp4ba-common-config -n $namespace --no-headers --ignore-not-found -o jsonpath='{.data.operators_namespace}')
    else
        warning "ibm-cp4ba-common-config configmap was not found in the project \"$namespace\"."
        warning " If the deployment being used has separate namespaces for operators and operands , please use the operands namespace while executing the cp4a-network-policies.sh script"
        # For https://jsw.ibm.com/browse/DBACLD-160661 where we have added remediation steps on how to recreate the configmap
        fail "You NEED to first create the \"ibm-cp4ba-common-config\" configMap in the project (namespace) where have deployed or upgraded CP4BA operands (i.e., runtime pods)."
        info "${YELLOW_TEXT}- [NEXT-STEPS]${RESET_TEXT}"
        echo "  - STEP 1 ${RED_TEXT}(Required)${RESET_TEXT}:${GREEN_TEXT} # Execute the cp4a-clusteradmin-setup.sh script with the \"-fix_configmap\" option to re-create the missing \"ibm-cp4ba-common-config\" configMap in the target namespace.For additional information refer to the Troubleshooting page in the Upgrade Section of the Knowledge Center.${RESET_TEXT}"
        exit 1
    fi
    if [[ "$cp4ba_services_namespace" != "$cp4ba_operators_namespace" ]]; then
        separation_of_duties_flag=true
    fi
}
