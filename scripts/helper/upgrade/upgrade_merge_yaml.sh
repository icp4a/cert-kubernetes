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

# For https://jsw.ibm.com/browse/DBACLD-154068
# Function to update the FNCM and BAW license value if it is user
# The value user is a valid license type but from 24.0.1 but the customer can also replace it with concurrent-user and authorized-user
function update_license() {
    local yaml_file="$1"
    retries=3
    license_type="$2"
    license_value=""

    # Check if the license key exists and retrieve its value
    if [[ "$license_type" == "fncm" ]]; then
        license_value=$(${YQ_CMD} r "$yaml_file" "spec.shared_configuration.sc_deployment_fncm_license")
    fi 
    if [[ "$license_type" == "baw" ]]; then
        license_value=$(${YQ_CMD} r "$yaml_file" "spec.shared_configuration.sc_deployment_baw_license")
    fi
    
    printf "\n"
    # If the value is 'user', prompt for a new value
    if [[ "$license_value" == "user" ]]; then
        while (( retries > 0 )); do
            echo "${YELLOW_TEXT}[ATTENTION]: The script detects \"user\" as the license value for sc_deployment_${license_type}_license set in the current version of the Custom Resource file.\nFrom the 24.0.1 release there are two more license values that are supported. The script will now prompt you to choose a valid license value from the list below.${RESET_TEXT}"
            printf "\n"
            echo "Select one of the following options as the updated value for sc_deployment_${license_type}_license :"
            echo "1) concurrent-user"
            echo "2) authorized-user"
            echo "3) user"

            read -p "Enter the number of your choice: " choice

            # Update the YAML with the selected value
            case $choice in
                1)
                    ${YQ_CMD} w -i "$yaml_file" "spec.shared_configuration.sc_deployment_${license_type}_license" "concurrent-user"
                    
                    break
                    ;;
                2)
                    ${YQ_CMD} w -i "$yaml_file" "spec.shared_configuration.sc_deployment_${license_type}_license" "authorized-user"
                    break
                    ;;
                3)
                    ${YQ_CMD} w -i "$yaml_file" "spec.shared_configuration.sc_deployment_${license_type}_license" "user"
                    break
                    ;;
                *)
                    echo "Invalid option. Choose again."
                    ;;
            esac

            (( retries-- ))
            if (( retries == 0 )); then
                break
            fi
        done
        success "The sc_${license_type}_license value has been successfully updated.."
        printf "\n"
    fi
}



# For jsw.ibm.com/browse/DBACLD-153103 where we need to update the datavolume section of the CR to be in the right format
# Function to check PVC size for a given PVC
get_pvc_size_from_cluster() {
    pvc_name=$1
    project_namespace=$2
    DEFAULT_SIZE="1Gi"
    size=$(kubectl get pvc "$pvc_name" -n $project_namespace -o=jsonpath='{.spec.resources.requests.storage}' 2>/dev/null)

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
    datavolume_paths=$(${YQ_CMD} r "$input_yaml" --printMode p '**.datavolume')

    # Iterate over each datavolume path found
    for path in $datavolume_paths; do
        # Find all the key names inside the datavolume section
        keys=($(${YQ_CMD} r "$input_yaml" "$path"  | grep -v '^\s'| awk -F ':' '{print $1}' | xargs -n 1))

        # Loop through the keys using the index
        for i in "${!keys[@]}"; do
            key="${keys[$i]}"
            key_path="$path.$key"
            # Check if 'name' and 'size' fields exist under this key
            name_exists=$(${YQ_CMD} r "$input_yaml" "$path.$key.name" 2>/dev/null)
            size_exists=$(${YQ_CMD} r "$input_yaml" "$path.$key.size" 2>/dev/null)

            # If the 'name' and 'size' field already exists, skip further processing for this key as it is in the right format already, otherwise the script makes changes
            if [[ ! -n "$name_exists" && ! -n "$size_exists" ]]; then
                #retrieve the current pvc name 
                current_value=$(${YQ_CMD} r "$input_yaml" "$key_path")
                # retrieve the current PVC size, default is 1Gi
                pvc_size=$(get_pvc_size_from_cluster "$current_value" "$project_namespace")

                # Write the name field with the name of the PVC
                ${YQ_CMD} w -i "$input_yaml" "$path.${key}.name" "$current_value"

                # Write the size field with the pvc size
                ${YQ_CMD} w -i "$input_yaml" "$path.${key}.size" "$pvc_size"
            fi
        done
    done
}

# For DBACLD-159463 where we need to add quotes around the jvm options string passed. In addition all custom annotations defined in the CR must be in strings
function add_quotes_to_values(){
    local input_yaml="$1"
    jvm_options_paths=$(${YQ_CMD} r "${input_yaml}" --printMode p '**.jvm_customize_options')
    for path in $jvm_options_paths; do
        current_value=$(${YQ_CMD} r "${input_yaml}" "$path")
        ${YQ_CMD} w -i "${input_yaml}" "$path" \"$current_value\"
    done

    annotations_paths=$(${YQ_CMD} r "${input_yaml}" --printMode p '**.custom_annotations')
    for path in $annotations_paths; do
        
        keys=($(${YQ_CMD} r "${input_yaml}" "$path"  | grep -v '^\s'| awk -F ':' '{print $1}' | xargs -n 1))
        # Loop through the keys using the index
        for i in "${!keys[@]}"; do
            key="${keys[$i]}"
            key_path="$path.\"$key\""
            current_value=$(${YQ_CMD} r "${input_yaml}" "$key_path")
            if [[ $current_value == true || $current_value == false ]]; then
                ${YQ_CMD} w -i "${input_yaml}" "$key_path" \"$current_value\"
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
    tag_paths_display=$(${YQ_CMD} r -j ${CR_FILE} | jq -r 'paths | select(.[-1] == "tag") | map(tostring) | join(".")')
    tag_paths_patch=$(${YQ_CMD} r -j ${CR_FILE} | jq -r 'paths | select(.[-1] == "tag") | map(tostring) | join("/")')
    # Removing tags only if the list is populated
    if [[ -n "$tag_paths_display" ]]; then
        echo "${YELLOW_TEXT}[ATTENTION]: The script detects image tags set in the current version of the Custom Resource file.\n[ATTENTION]: The script will remove the tags in the new version of the Custom Resource file and patch the current Custom Resource by removing those image tags since the tags are old and prevent the operator from deploying the updated software."
        info "The list of image tags that will be removed are listed below :"
        for path in $tag_paths_display; do
            tag_value=$(${YQ_CMD} r ${CR_FILE} "$path")
            # Extract the parent path (all parts except the last)
            parent_path=$(echo "$path" | awk -F'.' '{print substr($0, 1, length($0)-length($NF)-1)}')
            repository_value=$(${YQ_CMD} r ${CR_FILE} "$parent_path.repository")
            info "$repository_value:$tag_value"
        done
        printf "\n"
        prompt_press_any_key_to_continue "to remove the defined image tags from the Custom Resource file"
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
    output=$(kubectl apply -f "$FILE" --dry-run=server 2>&1)
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
        echo "  - STEP ${step_num} ${RED_TEXT}(Required)${RESET_TEXT}: ${GREEN_TEXT}# ./cp4a-deployment.sh -m upgradeDeployment -n $projectname${RESET_TEXT}"

        printf "\n"
        exit
    fi
}

function convert_olm_cr(){
    local cr_file=$1
    EXISTING_PATTERN_ARR=()
    EXISTING_OPT_COMPONENT_ARR=()
    # check the cr is olm format or not, it indicates that the CR is in OLM format
    olm_cr_flag=`cat $cr_file | ${YQ_CMD} r - spec.olm_ibm_license`
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
            olm_pattern_flag=`cat $cr_file | ${YQ_CMD} r - ${OLM_PATTERN_CR_MAPPING[$i]}`
            if [[ $olm_pattern_flag == "true" ]]; then
                EXISTING_PATTERN_ARR=( "${EXISTING_PATTERN_ARR[@]}" "${SCRIPT_PATTERN_CR_MAPPING[$i]}" )
                if [[ ${SCRIPT_PATTERN_CR_MAPPING[$i]} == "workflow" ]]; then
                    olm_pattern_flag=`cat $cr_file | ${YQ_CMD} r - spec.olm_production_workflow_deploy_type`
                    EXISTING_PATTERN_ARR=( "${EXISTING_PATTERN_ARR[@]}" "$olm_pattern_flag" )
                    if [[ $olm_pattern_flag == "workflow_authoring" ]]; then
                        EXISTING_OPT_COMPONENT_ARR=( "${EXISTING_OPT_COMPONENT_ARR[@]}" "baw_authoring" )
                    fi
                fi
                if [[ ${SCRIPT_PATTERN_CR_MAPPING[$i]} == "document_processing" ]]; then
                    olm_pattern_flag=`cat $cr_file | ${YQ_CMD} r - spec.olm_production_option.adp.document_processing_runtime`
                    if [[ $olm_pattern_flag == "true" ]]; then
                        EXISTING_PATTERN_ARR=( "${EXISTING_PATTERN_ARR[@]}" "document_processing_runtime" )
                    elif [[ $olm_pattern_flag == "false" ]]; then
                        EXISTING_PATTERN_ARR=( "${EXISTING_PATTERN_ARR[@]}" "document_processing_designer" )
                    fi
                fi
            elif [[ -z $olm_pattern_flag ]]; then
                ${YQ_CMD} w -i ${cr_file} ${OLM_PATTERN_CR_MAPPING[$i]} "false"
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
                olm_optional_component_flag=`cat $cr_file | ${YQ_CMD} r - ${OLM_OPTIONAL_COMPONENT_CR_MAPPING[$i]}`
                if [[ $olm_optional_component_flag == "true" ]]; then
                    ${YQ_CMD} w -i ${cr_file} spec.olm_production_option.workfow_runtime.opensearch "true"
                elif [[ $olm_optional_component_flag == "false" ]]; then
                    ${YQ_CMD} w -i ${cr_file} spec.olm_production_option.workfow_runtime.opensearch "false"
                elif [[ -z $olm_optional_component_flag ]]; then
                    olm_workflow_runtime_flag=`cat $cr_file | ${YQ_CMD} r - spec.olm_production_workflow_deploy_type`
                    if [[ $olm_workflow_runtime_flag == "workflow_runtime" ]]; then
                        ${YQ_CMD} w -i ${cr_file} spec.olm_production_option.workfow_runtime.opensearch "true"
                    fi
                fi
                ${YQ_CMD} d -i $cr_file ${OLM_OPTIONAL_COMPONENT_CR_MAPPING[$i]}
            fi

            # PFS is requird from 21.0.3/22.0.2 to 24.0.0 for workflow_authoring
            #Setting the PFS flag based on its current state in the CR file
            if [[ ${OLM_OPTIONAL_COMPONENT_CR_MAPPING[$i]} == "spec.olm_production_option.workfow_authoring.pfs" ]]; then
                olm_optional_component_flag=`cat $cr_file | ${YQ_CMD} r - ${OLM_OPTIONAL_COMPONENT_CR_MAPPING[$i]}`
                if [[ $olm_optional_component_flag == "true" ]]; then
                    ${YQ_CMD} w -i ${cr_file} spec.olm_production_option.workfow_authoring.pfs "true"
                elif [[ $olm_optional_component_flag == "false" ]]; then
                    ${YQ_CMD} w -i ${cr_file} spec.olm_production_option.workfow_authoring.pfs "false"
                elif [[ -z $olm_optional_component_flag ]]; then
                    olm_workfow_authoring_flag=`cat $cr_file | ${YQ_CMD} r - spec.olm_production_workflow_deploy_type`
                    if [[ $olm_workfow_authoring_flag == "workflow_authoring" ]]; then
                        ${YQ_CMD} w -i ${cr_file} spec.olm_production_option.workfow_authoring.pfs "true"
                    fi
                fi
            fi

            # remove ae_data_persistence and enable olm_production_application
            if [[ ${OLM_OPTIONAL_COMPONENT_CR_MAPPING[$i]} == "spec.olm_production_option.workfow_authoring.ae_data_persistence" ]]; then
                olm_optional_component_flag=`cat $cr_file | ${YQ_CMD} r - ${OLM_OPTIONAL_COMPONENT_CR_MAPPING[$i]}`
                if [[ $olm_optional_component_flag == "true" ]]; then
                    ${YQ_CMD} w -i ${cr_file} spec.olm_production_application "true"
                    ${YQ_CMD} w -i ${cr_file} spec.olm_production_option.application.ae_data_persistence "true"
                fi
                ${YQ_CMD} d -i $cr_file ${OLM_OPTIONAL_COMPONENT_CR_MAPPING[$i]}
            fi

            olm_optional_component_flag=`cat $cr_file | ${YQ_CMD} r - ${OLM_OPTIONAL_COMPONENT_CR_MAPPING[$i]}`
            if [[ $olm_optional_component_flag == "true" ]]; then
                OIFS=$IFS
                IFS='.' read -r -a array <<< "${OLM_OPTIONAL_COMPONENT_CR_MAPPING[$i]}"
                last_element="${array[-1]}"
                EXISTING_OPT_COMPONENT_ARR=( "${EXISTING_OPT_COMPONENT_ARR[@]}" "$last_element" )
                IFS=$OIFS
            elif [[ -z $olm_pattern_flag && ${OLM_OPTIONAL_COMPONENT_CR_MAPPING[$i]} != "spec.olm_production_option.workfow_authoring.ae_data_persistence" && ${OLM_OPTIONAL_COMPONENT_CR_MAPPING[$i]} != "spec.olm_production_option.workfow_runtime.elasticsearch" ]]; then
                ${YQ_CMD} w -i ${cr_file} ${OLM_OPTIONAL_COMPONENT_CR_MAPPING[$i]} "false"
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
data:
  ## The namespace for Common Service Operator
  operators_namespace: ""
  ## The namespace for Common Service
  services_namespace: ""
EOF
    success "Created YAML file for migration IBM Cloud Pak foundational services \"${UPGRADE_CS_ZEN_FILE}\"."
}

#create a YAML file for the ibm-cp4ba-shared-info ConfigMap
#used to store shared information related to the CP4BA deployment, such as operator versions and last reconciliation details
function create_ibm_cp4ba_shared_info_cm_yaml(){
    mkdir -p ${UPGRADE_DEPLOYMENT_CR}
cat << EOF > ${UPGRADE_ICP4A_SHARED_INFO_CM_FILE}
kind: ConfigMap
apiVersion: v1
metadata:
  name: ibm-cp4ba-shared-info
  namespace: <cp4a_namespace>
  labels:
    app.kubernetes.io/managed-by: Operator
    app.kubernetes.io/name: ibm-cp4ba-shared-info
    app.kubernetes.io/version: <cr_version>
    release: <cr_version>
  ownerReferences:
    - apiVersion: icp4a.ibm.com/v1
      kind: ICP4ACluster
      name: <cr_metaname>
      uid: <cr_uid>
data:
  ads_operator_of_last_reconcile: <csv_version>
  cp4ba_operator_of_last_reconcile: <csv_version>
  odm_operator_of_last_reconcile: <csv_version>
  baw_operator_of_last_reconcile: <csv_version>
EOF
}

function create_ibm_cp4ba_content_shared_info_cm_yaml(){
    mkdir -p ${UPGRADE_DEPLOYMENT_CR}
cat << EOF > ${UPGRADE_ICP4A_CONTENT_SHARED_INFO_CM_FILE}
kind: ConfigMap
apiVersion: v1
metadata:
  name: ibm-cp4ba-content-shared-info
  namespace: <content_namespace>
  labels:
    app.kubernetes.io/managed-by: Operator
    app.kubernetes.io/name: ibm-cp4ba-shared-info
    app.kubernetes.io/version: <cr_version>
    release: <cr_version>
  ownerReferences:
    - apiVersion: icp4a.ibm.com/v1
      kind: Content
      name: <cr_metaname>
      uid: <cr_uid>
data:
  content_operator_of_last_reconcile: <csv_version>
EOF
}

function select_apply_cr(){
    local cr_file=$1
    echo "${YELLOW_TEXT}[ATTENTION]: YOU NEED TO REVIEW OR MODIFY THE NEW CUSTOM RESOURCE ($cr_file) FOLLOW IBM CLOUD PAK FOR BUSINESS AUTOMATION DOCUMENTATION BEFORE APPLYING IT.${RESET_TEXT}"
    prompt_press_any_key_to_continue
    APPLY_UPDATED_CR="No"
    # while true; do
    #     printf "\n"
    #     printf "\x1B[1mDo you want to edit the new version of the custom resource with some custom settings?\n\x1B[0m"
    #     printf "If you select Yes, the script displays the next actions to update the custom resource and to apply it. If you select No, the script applies the custom resource automatically.\n"
    #     printf "(Yes/No, default: Yes): "

    #     read -rp "" ans
    #     case "$ans" in
    #     "y"|"Y"|"yes"|"Yes"|"YES"|"")
    #         APPLY_UPDATED_CR="No"
    #         break
    #         ;;
    #     "n"|"N"|"no"|"No"|"NO")
    #         if [[ " ${EXISTING_OPT_COMPONENT_ARR[@]} " =~ "css" || $css_flag == "true" ]]; then
    #             warning "The script CAN NOT apply the new version of custom resource \"$cr_file\"."
    #             info "${YELLOW_TEXT}You have Content Search Services (CSS) installed.${RESET_TEXT}${RED_TEXT} Make sure you stop the IBM Content Search Services index dispatcher follow step in [NEXT ACTION]${RESET_TEXT} ${YELLOW_TEXT}before apply the new version of custom resource.${RESET_TEXT}"
    #             APPLY_UPDATED_CR="No"
    #         else
    #             APPLY_UPDATED_CR="Yes"
    #         fi
    #         break
    #         ;;
    #     *)
    #         echo -e "Answer must be \"Yes\" or \"No\"\n"
    #         ;;
    #     esac
    # done
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
    prompt_press_any_key_to_continue
    sh ${CUR_DIR}/cp4a-network-policies.sh -m retrieveExisting -n $namespace --kind $cr_type
    sh ${CUR_DIR}/cp4a-network-policies.sh -m removeRef -n $namespace
    printf "\n"
    echo "${YELLOW_TEXT}(Notes: Starting from $CP4BA_RELEASE_BASE, the CP4BA operators no longer install network policies automatically.${RESET_TEXT}"
    echo "However, the script \"cp4a-network-policies.sh\" is provided as a tool you can optionally use to generate network policy templates which you can review and apply.  If you want to generate network policy templates, then do the following:"
    echo "1. Make sure the flag \"shared_configuration.sc_generate_sample_network_policies\" is set to \"true\" in your custom resource file. (By default, the script will set the sc_generate_sample_network_policies to \"false\" )"
    echo "2. Wait for your deployment complete."
    # Will be adding the KC link after its been created
    echo "3. You can retrieve and apply the network policies by running the cp4a-network-policies.sh script after the CP4BA upgrade has been completed ."
    printf "\n"
    prompt_press_any_key_to_continue
    # For WFPSRuntime the CR does not need the sc_generate_sample_network_policies flag nor does it have sc_restricted_internet_access
    # The operator picks those values from the ICP4ACluster
    # For https://jsw.ibm.com/browse/DBACLD-175988
    if [[ $cr_type != "WfPSRuntime" ]]; then
        ${YQ_CMD} d -i ${cr_file} spec.shared_configuration.sc_egress_configuration.sc_restricted_internet_access
        ${YQ_CMD} w -i ${cr_file} spec.shared_configuration.sc_generate_sample_network_policies "false"
    fi

}

# Function to detect if the Domain is configured with SCIM
# During upgradeOperator we check for SCIM configuration in the Domain and then save a boolean flag in the shared info configmap
# This function retrieves the flag and accordingly sets the sc_skip_ldap_config flag in the CR
# https://jsw.ibm.com/browse/DBACLD-157386 https://jsw.ibm.com/browse/DBACLD-178101 https://jsw.ibm.com/browse/DBACLD-177550 https://jsw.ibm.com/browse/DBACLD-177742
function detect_scim_configuration(){
    local namespace=$1
    local configmap_name=$2
    local cr_file=$3
    #checking if the SCIM Value is in either ibm-cp4ba-content-shared-info or ibm-cp4ba-shared-info
    scim_enabled=''
    scim_enabled=$(${CLI_CMD} get cm "$configmap_name" -n $namespace -o yaml | ${YQ_CMD} r - data.scim_configured)
    if [[ ! -z "$scim_enabled" ]]; then
        echo "SCIM STATUS----$scim_enabled"
        if [[ "$scim_enabled" == "True" ]]; then
            info "${YELLOW_TEXT}When the Content Process Engine directory provider type is set to SCIM, the script will set \"shared_configuration.sc_skip_ldap_config\" as \"true\" while upgrading CP4BA deployment from version \"$cr_version\".${RESET_TEXT}"
            ${YQ_CMD} w -i ${cr_file} spec.shared_configuration.sc_skip_ldap_config "true"
        else
            info "${YELLOW_TEXT}When Content Process Engine directory provider type is set to LDAP (not SCIM), setting \"shared_configuration.sc_skip_ldap_config\" as \"false\" while upgrading CP4BA deployment from version \"$cr_version\".${RESET_TEXT}"
            ${YQ_CMD} w -i ${cr_file} spec.shared_configuration.sc_skip_ldap_config "false"
        fi
    fi
}

#manages the shutdown of the CP4BA operator and retrieves existing CR's,to prevent conflicts during the upgrade
#handles their processing based on their ownership.
function upgrade_deployment(){
    local deployment_project_name=$1
    local operator_project_name=$2
    local allow_direct_upgrade=$3
    # local cr_version=$4
    mkdir -p ${UPGRADE_DEPLOYMENT_CR} >/dev/null 2>&1
    # trap 'startup_operator $deployment_project_name' EXIT, to preventing issues during the upgrade
    shutdown_operator $operator_project_name
    source ${CUR_DIR}/helper/upgrade/upgrade_check_status.sh
    
    # Retrieve existing Content CR, to verify if there are any 'content' CRs that need to be processed
    ${CLI_CMD} get crd |grep contents.icp4a.ibm.com >/dev/null 2>&1
    if [ $? -eq 0 ]; then
        content_cr_name=$(${CLI_CMD} get content -n $deployment_project_name --no-headers --ignore-not-found | awk '{print $1}')
        if [ ! -z $content_cr_name ]; then
            info "Retrieving existing CP4BA Content (Kind: content.icp4a.ibm.com) Custom Resource"
            cr_type="content"
            cr_metaname=$(${CLI_CMD} get content $content_cr_name -n $deployment_project_name -o yaml | ${YQ_CMD} r - metadata.name)
            cr_version=$(${CLI_CMD} get content $content_cr_name -n $deployment_project_name -o yaml | ${YQ_CMD} r - spec.appVersion)
            owner_ref=$(${CLI_CMD} get content $content_cr_name -n $deployment_project_name -o yaml | ${YQ_CMD} r - metadata.ownerReferences.[0].kind)
            if [[ ${owner_ref} == "ICP4ACluster" ]]; then
                warning "Found one Content (Kind: content.icp4a.ibm.com) Custom Resource which is generated by CP4BA operator. The script will not change it."
                CONTENT_CR_EXIST="No"
                sleep 5
            else
                CONTENT_CR_EXIST="Yes"
                # # Check if the cp-console-iam-provider/cp-console-iam-idmgmt already created before upgrade Content deployment.
                # iam_idprovider=$(${CLI_CMD} get route -n $deployment_project_name -o 'custom-columns=NAME:.metadata.name' --no-headers --ignore-not-found | grep cp-console-iam-provider)
                # iam_idmgmt=$(${CLI_CMD} get route -n $deployment_project_name -o 'custom-columns=NAME:.metadata.name' --no-headers --ignore-not-found | grep cp-console-iam-idmgmt)
                # if [[ -z $iam_idprovider || -z $iam_idmgmt ]]; then
                #     fail "Not found route \"cp-console-iam-idmgmt\" and \"cp-console-iam-provider\" in the project \"$deployment_project_name\"."
                #     info "You have to create \"cp-console-iam-idmgmt\" and \"cp-console-iam-provider\" before upgrade CP4BA deployment."
                #     exit 1
                # fi
                # if [[ ! -f $UPGRADE_DEPLOYMENT_CONTENT_CR_TMP ]]; then
                ${CLI_CMD} get $cr_type $content_cr_name -n $deployment_project_name -o yaml > ${UPGRADE_DEPLOYMENT_CONTENT_CR_TMP}

                # Update the appVersion in foundationrequest
                # Updates the 'appVersion' field in the FoundationRequest CR to match the new release version of CP4BA
                foundationrequest_cr_name=$(${CLI_CMD} get foundationrequest -n $deployment_project_name --no-headers --ignore-not-found | awk '{print $1}')
                ${CLI_CMD} patch foundationrequest $foundationrequest_cr_name -n $deployment_project_name -p '{"spec":{"appVersion":"$CP4BA_RELEASE_BASE"}}' --type=merge >/dev/null 2>&1

                # Backup existing content CR, creates a backup of the existing content Custom Resource to avoid data loss
                mkdir -p ${UPGRADE_DEPLOYMENT_CR_BAK}
                ${COPY_CMD} -rf ${UPGRADE_DEPLOYMENT_CONTENT_CR_TMP} ${UPGRADE_DEPLOYMENT_CONTENT_CR_BAK}
                # fi

                info "Merging existing CP4BA Content Custom Resource with new version ($CP4BA_RELEASE_BASE)"
                # Delete unnecessary section in CR
                ${YQ_CMD} d -i ${UPGRADE_DEPLOYMENT_CONTENT_CR_TMP} status
                #${YQ_CMD} d -i ${UPGRADE_DEPLOYMENT_CONTENT_CR_TMP} metadata.annotations
                ${YQ_CMD} d -i ${UPGRADE_DEPLOYMENT_CONTENT_CR_TMP} metadata.creationTimestamp
                ${YQ_CMD} d -i ${UPGRADE_DEPLOYMENT_CONTENT_CR_TMP} metadata.generation
                ${YQ_CMD} d -i ${UPGRADE_DEPLOYMENT_CONTENT_CR_TMP} metadata.resourceVersion
                ${YQ_CMD} d -i ${UPGRADE_DEPLOYMENT_CONTENT_CR_TMP} metadata.uid
                #Validate the CR by performing a dry run
                dryrun $UPGRADE_DEPLOYMENT_CONTENT_CR_TMP $deployment_project_name
                #applying the latest tmp CR so that we can update the kubectl.kubernetes.io/last-applied-configuration section to include any potential user edits
                kubectl apply -f ${UPGRADE_DEPLOYMENT_CONTENT_CR_TMP} -n $deployment_project_name >/dev/null 2>&1

                # replace release/appVersion
                ${SED_COMMAND} "s|release: .*|release: ${CP4BA_RELEASE_BASE}|g" ${UPGRADE_DEPLOYMENT_CONTENT_CR_TMP}
                ${SED_COMMAND} "s|appVersion: .*|appVersion: ${CP4BA_RELEASE_BASE}|g" ${UPGRADE_DEPLOYMENT_CONTENT_CR_TMP}

                # For https://jsw.ibm.com/browse/DBACLD-154068
                # Update FNCM license if required
                # The value user is a valid license type from 24.0.1 but the customer can also replace it with concurrent-user and authorized-user
                update_license ${UPGRADE_DEPLOYMENT_CONTENT_CR_TMP} "fncm"

                # remove sc_common_services, section is no longer needed
                # ${YQ_CMD} m -i -a -M --overwrite ${UPGRADE_DEPLOYMENT_CONTENT_CR_TMP} ${UPGRADE_CS_ZEN_FILE}
                ${YQ_CMD} d -i ${UPGRADE_DEPLOYMENT_CONTENT_CR_TMP} spec.shared_configuration.sc_common_service
                ${YQ_CMD} d -i ${UPGRADE_DEPLOYMENT_CONTENT_CR_TMP} spec.shared_configuration.sc_common_service

                ${SED_COMMAND} "s/route_reencrypt: .*/route_reencrypt: $ZEN_ROUTE_REENCRYPT/g" ${UPGRADE_DEPLOYMENT_CONTENT_CR_TMP}

                # This block of is used to merge the BAI save point into the CR.  It's only executed when it's an n-1 to n upgrade, not ifix to ifix
                # The is_ifix_to_ifix_upgrade is set to false in the determine_type_of_upgrade function.
                # if [[ ! ("$cp4ba_original_csv_ver_for_upgrade_script" == "24.0."*) ]]; then
                # Sourcing upgrade_check_status.sh and calling determine_type_of_upgrade to dertmine the type of upgrade
    
                info "CR Version: $cr_version"
                determine_type_of_upgrade "$cr_version"
                if [[ "$is_ifix_to_ifix_upgrade" == "false" ]]; then
                    # Merge BAI save point into content cr, to check whether BAI savepoints are needed for the upgrade
                    bai_flag=`cat $UPGRADE_DEPLOYMENT_CONTENT_CR_TMP | ${YQ_CMD} r - spec.content_optional_components.bai`
                    bai_flag=$(echo $bai_flag | tr '[:upper:]' '[:lower:]')
                    if [[ $bai_flag == "true" ]]; then
                        info "Merging Flink job savepoint from \"${UPGRADE_DEPLOYMENT_BAI_TMP}\" into new version of custom resource \"${UPGRADE_DEPLOYMENT_CONTENT_CR}\"."
                        if [ -s ${UPGRADE_DEPLOYMENT_BAI_TMP} ]; then
                            ${YQ_CMD} m -i -a -M --overwrite ${UPGRADE_DEPLOYMENT_CONTENT_CR_TMP} ${UPGRADE_DEPLOYMENT_BAI_TMP}
                            success "Merged Flink job savepoint into new version of custom resource."
                        else
                            warning "Not found file ${UPGRADE_DEPLOYMENT_BAI_TMP}."
                        fi
                    fi
                fi
                # Disable sc_content_initialization/sc_content_verification
                if [[ $olm_cr_flag == "No" ]]; then
                    ${YQ_CMD} w -i ${UPGRADE_DEPLOYMENT_CONTENT_CR_TMP} spec.shared_configuration.sc_content_initialization "false"
                    ${YQ_CMD} w -i ${UPGRADE_DEPLOYMENT_CONTENT_CR_TMP} spec.shared_configuration.sc_content_verification "false"
                else
                    ${YQ_CMD} w -i ${UPGRADE_DEPLOYMENT_CONTENT_CR_TMP} spec.shared_configuration.olm_sc_content_initialization "false"
                    ${YQ_CMD} w -i ${UPGRADE_DEPLOYMENT_CONTENT_CR_TMP} spec.shared_configuration.olm_sc_content_verification "false"
                fi
                ${YQ_CMD} d -i ${UPGRADE_DEPLOYMENT_CONTENT_CR_TMP} spec.shared_configuration.sc_content_initialization_update_scim

                # remove initialize_configuration/verify_configuration, no longer required in the new version of CP4BA
                info "Remove initialize_configuration/verify_configuration from new version of CP4BA Content Custom Resource"
                ${YQ_CMD} d -i ${UPGRADE_DEPLOYMENT_CONTENT_CR_TMP} spec.verify_configuration
                ${YQ_CMD} d -i ${UPGRADE_DEPLOYMENT_CONTENT_CR_TMP} spec.initialize_configuration
                # ${YQ_CMD} w -i ${UPGRADE_DEPLOYMENT_CONTENT_CR_TMP} spec.verify_configuration
                # ${YQ_CMD} w -i ${UPGRADE_DEPLOYMENT_CONTENT_CR_TMP} spec.initialize_configuration

                # Function to detect if the Domain is configured with SCIM
                # https://jsw.ibm.com/browse/DBACLD-157386 https://jsw.ibm.com/browse/DBACLD-178101 https://jsw.ibm.com/browse/DBACLD-177550 https://jsw.ibm.com/browse/DBACLD-177742
                detect_scim_configuration "$deployment_project_name" "ibm-cp4ba-content-shared-info" "${UPGRADE_DEPLOYMENT_CONTENT_CR_TMP}"
                
                if [[ "$allow_direct_upgrade" == 1 ]]; then
                    
                    # Set shared_configuration.enable_fips always "false" in upgrade
                    info "${RED_TEXT}Setting \"shared_configuration.enable_fips\" as \"false\" when upgrade CP4BA deployment, you could change it according to your requirements.${RESET_TEXT}"
                    ${YQ_CMD} w -i ${UPGRADE_DEPLOYMENT_CONTENT_CR_TMP} spec.shared_configuration.enable_fips "false"
                fi

                ${SED_COMMAND} "s|'\"|\"|g" ${UPGRADE_DEPLOYMENT_CONTENT_CR_TMP}
                ${SED_COMMAND} "s|\"'|\"|g" ${UPGRADE_DEPLOYMENT_CONTENT_CR_TMP}
                ${SED_COMMAND} "s/route_reencrypt: .*/route_reencrypt: $ZEN_ROUTE_REENCRYPT/g" ${UPGRADE_DEPLOYMENT_CONTENT_CR_TMP}
                
                # Function that will retrieve the network policies created in 24.0.1 by the operators and remove the references and re-apply them 
                # For https://jsw.ibm.com/browse/DBACLD-167387
                update_network_policies $deployment_project_name "Content" ${UPGRADE_DEPLOYMENT_CONTENT_CR_TMP}

                # Function that retrieves the networktype and network cidr range
                # https://jsw.ibm.com/browse/DBACLD-173602
                retrieve_network_details "upgrade" $deployment_project_name

                # convert ssl enable true or false to meet CSV
                ${SED_COMMAND} "s/: \"True\"/: true/g" ${UPGRADE_DEPLOYMENT_CONTENT_CR_TMP}
                ${SED_COMMAND} "s/: \"False\"/: false/g" ${UPGRADE_DEPLOYMENT_CONTENT_CR_TMP}
                ${SED_COMMAND} "s/: \"true\"/: true/g" ${UPGRADE_DEPLOYMENT_CONTENT_CR_TMP}
                ${SED_COMMAND} "s/: \"false\"/: false/g" ${UPGRADE_DEPLOYMENT_CONTENT_CR_TMP}
                ${SED_COMMAND} "s/: \"Yes\"/: true/g" ${UPGRADE_DEPLOYMENT_CONTENT_CR_TMP}
                ${SED_COMMAND} "s/: \"yes\"/: true/g" ${UPGRADE_DEPLOYMENT_CONTENT_CR_TMP}
                ${SED_COMMAND} "s/: \"No\"/: false/g" ${UPGRADE_DEPLOYMENT_CONTENT_CR_TMP}
                ${SED_COMMAND} "s/: \"no\"/: false/g" ${UPGRADE_DEPLOYMENT_CONTENT_CR_TMP}

                #For DBACLD-159463 to make sure all jvm options defined and all custom annotations are strings
                add_quotes_to_values "${UPGRADE_DEPLOYMENT_CONTENT_CR_TMP}"

                # Remove all null string
                ${SED_COMMAND} "s/: null/: /g" ${UPGRADE_DEPLOYMENT_CONTENT_CR_TMP}

                ${COPY_CMD} -rf ${UPGRADE_DEPLOYMENT_CONTENT_CR_TMP} ${UPGRADE_DEPLOYMENT_CONTENT_CR}

                # Disable CSS indexing
                # scale down FNCM Deployment
                info "Scaling down CSS deployment"
                css_instance_number=0
                css_instance_index=1
                while true; do
                    ${CLI_CMD} get deployment ${cr_metaname}-css-deploy-${css_instance_index} >/dev/null 2>&1
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
                        ${CLI_CMD} scale --replicas=0 deployment ${cr_metaname}-css-deploy-${j} -n $deployment_project_name >/dev/null 2>&1
                    done
                fi
                #Scaling down CPE and Navigator deployment to avoid unnecessary data
                info "Scaling down CPE deployment"
                ${CLI_CMD} scale --replicas=0 deployment ${cr_metaname}-cpe-deploy -n $deployment_project_name >/dev/null 2>&1
                echo "Done!"
                # To allow any changes to creation of the zen extension configuration that we make from IFIX to IFIX,its best if the watcher pods are scaled down prior to applying the new CR
                # DBACLD-171900
                info "Scaling down CPE Watcher deployment"
                ${CLI_CMD} scale --replicas=0 deployment ${cr_metaname}-cpe-watcher -n $deployment_project_name >/dev/null 2>&1
                echo "Done!"
                info "Scaling down Navigator deployment"
                ${CLI_CMD} scale --replicas=0 deployment ${cr_metaname}-navigator-deploy -n $deployment_project_name >/dev/null 2>&1
                echo "Done!"
                # To allow any changes to creation of the zen extension configuration that we make from IFIX to IFIX,its best if the watcher pods are scaled down prior to applying the new CR
                # DBACLD-171900
                info "Scaling down Navigator Watcher deployment"
                ${CLI_CMD} scale --replicas=0 deployment ${cr_metaname}-navigator-watcher -n $deployment_project_name >/dev/null 2>&1
                echo "Done!"

                # For jsw.ibm.com/browse/DBACLD-153103 where we need to update the datavolume section of the CR to be in the right format
                if [[ $cr_version != "${CP4BA_RELEASE_BASE}" && ($cr_version == "21.0.3") ]]; then
                    #function to update datastore section to the current format if required
                    process_datavolumes ${UPGRADE_DEPLOYMENT_CONTENT_CR_TMP} $deployment_project_name
                fi

                # info "Remove initialize_configuration/verify_configuration from CP4BA Content Custom Resource"
                # ${CLI_CMD} patch content $content_cr_name -n $deployment_project_name --type=json -p='[{"op": "remove", "path": "/spec/initialize_configuration"}]' >/dev/null 2>&1
                # ${CLI_CMD} patch content $content_cr_name -n $deployment_project_name --type=json -p='[{"op": "remove", "path": "/spec/verify_configuration"}]' >/dev/null 2>&1
                info "The new version ($CP4BA_RELEASE_BASE) of CP4BA Content Custom Resource is created ${UPGRADE_DEPLOYMENT_CONTENT_CR}"

                #Function to remove the image tags from the CR if present
                remove_image_tags $UPGRADE_DEPLOYMENT_CONTENT_CR_TMP
                ${COPY_CMD} -rf ${UPGRADE_DEPLOYMENT_CONTENT_CR_TMP} ${UPGRADE_DEPLOYMENT_CONTENT_CR}
                if [[ $TAGS_REMOVED == "true" ]]; then
                    info "IMAGE TAGS ARE REMOVED FROM THE NEW VERSION OF THE CUSTOM RESOURCE \"${UPGRADE_DEPLOYMENT_CONTENT_CR}\"."
                    printf "\n"
                fi
                

                #function for applying CR
                select_apply_cr $UPGRADE_DEPLOYMENT_CONTENT_CR

                if [[ $APPLY_UPDATED_CR == "Yes" ]]; then
                    info "Remove initialize_configuration/verify_configuration from CP4BA Content Custom Resource"
                    ${CLI_CMD} patch content $content_cr_name -n $deployment_project_name --type=json -p='[{"op": "remove", "path": "/spec/initialize_configuration"}]' >/dev/null 2>&1
                    ${CLI_CMD} patch content $content_cr_name -n $deployment_project_name --type=json -p='[{"op": "remove", "path": "/spec/verify_configuration"}]' >/dev/null 2>&1

                    info "Applying the custom resource ${UPGRADE_DEPLOYMENT_CONTENT_CR}"
                    kubectl annotate content $content_cr_name kubectl.kubernetes.io/last-applied-configuration- -n $deployment_project_name >/dev/null 2>&1
                    kubectl apply -f ${UPGRADE_DEPLOYMENT_CONTENT_CR} -n $deployment_project_name >/dev/null 2>&1

                    if [ $? -ne 0 ]; then
                        fail "Failed to update IBM CP4BA Content Custom Resource."
                    else
                        echo "Done!"
                        printf "\n"
                    fi

                    echo "${YELLOW_TEXT}[NEXT ACTION]:${RESET_TEXT}"
                    echo "${YELLOW_TEXT}- How to check the overall upgrade status for CP4BA/zenService/IM.${RESET_TEXT}"
                    echo "${YELLOW_TEXT}  [TIPS]: ${RESET_TEXT}The [upgradeDeploymentStatus] option will start necessary CP4BA operators (ibm-cp4a-operator/icp4a-foundation-operator) first to upgrade zenService, and then will start all other CP4BA operators when zenService upgrade done."
                    echo "  STEP1 ${RED_TEXT}(Required)${RESET_TEXT}:${GREEN_TEXT} # ./cp4a-deployment.sh -m upgradeDeploymentStatus -n $TARGET_PROJECT_NAME${RESET_TEXT}"
                else

                    initialize_cfg_flag=$(${CLI_CMD} get content $content_cr_name -n $deployment_project_name --no-headers --ignore-not-found -o 'jsonpath={.spec.initialize_configuration}') >/dev/null 2>&1
                    verify_cfg_flag=$(${CLI_CMD} get content $content_cr_name -n $deployment_project_name --no-headers --ignore-not-found -o 'jsonpath={.spec.verify_configuration}') >/dev/null 2>&1

                    printf "\n"
                    echo "${YELLOW_TEXT}[NEXT ACTION]:${RESET_TEXT}"
                    step_num=1
                    printf "\n"

                    echo "${YELLOW_TEXT}- Refer to the Knowledge Center: \"Updating the custom resource for each capability in your deployment\" topic to complete REQUIRED steps for the installed pattern(s)."
                    if [[ $allow_direct_upgrade == 1 ]]; then
                        echo "  - If upgrading from 21.0.3 or 22.0.2: [https://www.ibm.com/docs/en/cloud-paks/cp-biz-automation/24.0.0?topic=uycpd-updating-custom-resource-each-capability-in-your-deployment]"
                        echo "  - If upgrading from 23.0.2: [https://www.ibm.com/docs/en/cloud-paks/cp-biz-automation/24.0.0?topic=uycpdf2-updating-custom-resource-each-capability-in-your-deployment]"
                        echo "  - If upgrading from 24.0.0: [https://www.ibm.com/docs/en/cloud-paks/cp-biz-automation/24.0.1?topic=uycpdf2-updating-custom-resource-each-capability-in-your-deployment]${RESET_TEXT}"
                    fi
                    echo "  - If upgrading from 24.0.1: [https://www.ibm.com/docs/en/cloud-paks/cp-biz-automation/$CP4BA_RELEASE_BASE?topic=uycpdf2-updating-custom-resource-each-capability-in-your-deployment] ${RESET_TEXT}"
                    echo "${YELLOW_TEXT}- After reviewing or modifying the custom resource file \"${UPGRADE_DEPLOYMENT_CONTENT_CR}\", you need to follow the steps below to upgrade this CP4BA deployment.${RESET_TEXT}"

                    # As a part of DBACLD-149126 solution we no longer needed the user to patch or annotate the custom resource file
                    echo "  - STEP ${step_num} ${RED_TEXT}(Required)${RESET_TEXT}:${GREEN_TEXT} # ${CLI_CMD} apply -f ${UPGRADE_DEPLOYMENT_CONTENT_CR} -n $deployment_project_name${RESET_TEXT}" && step_num=$((step_num + 1))

                    printf "\n"
                    echo "${YELLOW_TEXT}- How to check the overall upgrade status for CP4BA/zenService/IM.${RESET_TEXT}"
                    echo "${YELLOW_TEXT}  [TIPS]: ${RESET_TEXT}The [upgradeDeploymentStatus] option will start CP4BA operators automatically after zenService ready."
                    echo "  - STEP ${step_num} ${RED_TEXT}(Required)${RESET_TEXT}: ${GREEN_TEXT}# ./cp4a-deployment.sh -m upgradeDeploymentStatus -n $TARGET_PROJECT_NAME${RESET_TEXT}"
                fi
                printf "\n"
                echo "${YELLOW_TEXT}[ATTENTION]: The zenService will be ready in about 120 minutes after the new version ($CP4BA_RELEASE_BASE) of the CP4BA custom resource was applied.${RESET_TEXT}"

                # if [ $? -ne 0 ]; then
                #     fail "IBM Cloud Pak for Business Automation Content custom resource update failed"
                #     exit 1
                # else
                #     echo "Done!"

                #     printf "\n"
                #     # echo "${YELLOW_TEXT}[NEXT ACTION]${RESET_TEXT}: "
                #     # msgB "Run \"cp4a-deployment.sh -m upgradeDeploymentStatus -n $deployment_project_name\" to get overview upgrade status for CP4BA"
                # fi
            fi
        fi
    fi

    # Retrieve existing WfPSRuntime CR, to get list of existing WfPSRuntime cr's in the specified namespace
    exist_wfps_cr_array=($(${CLI_CMD} get WfPSRuntime -n $deployment_project_name --no-headers --ignore-not-found | awk '{print $1}'))
    if [ ! -z $exist_wfps_cr_array ]; then
        for item in "${exist_wfps_cr_array[@]}"
        do
            info "Retrieving existing IBM CP4BA Workflow Process Service (Kind: WfPSRuntime.icp4a.ibm.com) Custom Resource: \"${item}\""
            cr_type="WfPSRuntime"
            cr_metaname=$(${CLI_CMD} get $cr_type ${item} -n $deployment_project_name -o yaml | ${YQ_CMD} r - metadata.name)
            UPGRADE_DEPLOYMENT_WFPS_CR=${UPGRADE_DEPLOYMENT_CR}/wfps_${cr_metaname}.yaml
            UPGRADE_DEPLOYMENT_WFPS_CR_TMP=${UPGRADE_DEPLOYMENT_CR}/.wfps_${cr_metaname}_tmp.yaml
            UPGRADE_DEPLOYMENT_WFPS_CR_BAK=${UPGRADE_DEPLOYMENT_CR_BAK}/wfps_cr_${cr_metaname}_backup.yaml

            ${CLI_CMD} get $cr_type ${item} -n $deployment_project_name -o yaml > ${UPGRADE_DEPLOYMENT_WFPS_CR_TMP}

            # Backup existing WfPSRuntime CR, make backup of the WfPSRuntime custom resource to preserve its original state before applying any upgrades
            mkdir -p ${UPGRADE_DEPLOYMENT_CR_BAK}
            ${COPY_CMD} -rf ${UPGRADE_DEPLOYMENT_WFPS_CR_TMP} ${UPGRADE_DEPLOYMENT_WFPS_CR_BAK}

            info "Merging existing IBM CP4BA Workflow Process Service custom resource: \"${item}\" with new version ($CP4BA_RELEASE_BASE)"
            # Delete unnecessary section in CR
            ${YQ_CMD} d -i ${UPGRADE_DEPLOYMENT_WFPS_CR_TMP} status
            #${YQ_CMD} d -i ${UPGRADE_DEPLOYMENT_WFPS_CR_TMP} metadata.annotations
            ${YQ_CMD} d -i ${UPGRADE_DEPLOYMENT_WFPS_CR_TMP} metadata.creationTimestamp
            ${YQ_CMD} d -i ${UPGRADE_DEPLOYMENT_WFPS_CR_TMP} metadata.generation
            ${YQ_CMD} d -i ${UPGRADE_DEPLOYMENT_WFPS_CR_TMP} metadata.resourceVersion
            ${YQ_CMD} d -i ${UPGRADE_DEPLOYMENT_WFPS_CR_TMP} metadata.uid

            # Scale up wfps operator deployment to enable webhook for CR validation
            kubectl scale --replicas=1 deployment ibm-cp4a-wfps-operator -n $operator_project_name >/dev/null 2>&1
            wait_for_pod $operator_project_name ibm-cp4a-wfps-operator
            #Validate the CR by performing a dry run
            dryrun $UPGRADE_DEPLOYMENT_WFPS_CR_TMP $deployment_project_name
            #applying the latest tmp CR so that we can update the kubectl.kubernetes.io/last-applied-configuration section to include any potential user edits
            kubectl apply -f ${UPGRADE_DEPLOYMENT_WFPS_CR_TMP} -n $deployment_project_name >/dev/null 2>&1
            # Scale down wfps operator deployment again
            kubectl scale --replicas=0 deployment ibm-cp4a-wfps-operator -n $operator_project_name >/dev/null 2>&1

            # replace release/appVersion
            # ${SED_COMMAND} "s|release: .*|release: ${CP4BA_RELEASE_BASE}|g" ${UPGRADE_DEPLOYMENT_PFS_CR_TMP}
            ${SED_COMMAND} "s|appVersion: .*|appVersion: ${CP4BA_RELEASE_BASE}|g" ${UPGRADE_DEPLOYMENT_WFPS_CR_TMP}

            # For https://jsw.ibm.com/browse/DBACLD-154068
            # Update BAW license if required
            # The value user is a valid license type but from 24.0.1 but the customer can also replace it with concurrent-user and authorized-user
            update_license ${UPGRADE_DEPLOYMENT_WFPS_CR_TMP} "baw"

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
                    echo -e "\x1B[1mCheck the status of Pod by issuing the following command:\x1B[0m"
                    echo "oc describe pod $(oc get pod -n $operator_project_name|grep ibm-cp4a-wfps-operator|awk '{print $1}') -n $operator_project_name"
                    printf "\n"
                    echo -e "\x1B[1mCheck the status of ReplicaSet by issuing the following command:\x1B[0m"
                    echo "oc describe rs $(oc get rs -n $operator_project_name|grep ibm-cp4a-wfps-operator|awk '{print $1}') -n $operator_project_name"
                    printf "\n"
                    exit 1
                    else
                    sleep 30
                    echo -n "..."
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
            kubectl apply -f ${UPGRADE_DEPLOYMENT_WFPS_CR} -n $deployment_project_name >/dev/null 2>&1
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

    # Retrieve existing ICP4ACluster CR, to get the name of the existing ICP4ACluster custom resource in the specified namespace
    icp4acluster_cr_name=$(${CLI_CMD} get icp4acluster -n $deployment_project_name --no-headers --ignore-not-found | awk '{print $1}')
    if [ ! -z $icp4acluster_cr_name ]; then
        info "Retrieving existing CP4BA ICP4ACluster (Kind: icp4acluster.icp4a.ibm.com) Custom Resource"
        cr_type="icp4acluster"
        cr_metaname=$(${CLI_CMD} get icp4acluster $icp4acluster_cr_name -n $deployment_project_name -o yaml | ${YQ_CMD} r - metadata.name)
        cr_version=$(${CLI_CMD} get icp4acluster $icp4acluster_cr_name -n $deployment_project_name -o yaml | ${YQ_CMD} r - spec.appVersion)
        ${CLI_CMD} get $cr_type $icp4acluster_cr_name -n $deployment_project_name -o yaml > ${UPGRADE_DEPLOYMENT_ICP4ACLUSTER_CR_TMP}
        

        convert_olm_cr "${UPGRADE_DEPLOYMENT_ICP4ACLUSTER_CR_TMP}"
        if [[ $olm_cr_flag == "No" ]]; then
            existing_pattern_list=""
            existing_opt_component_list=""

            EXISTING_PATTERN_ARR=()
            EXISTING_OPT_COMPONENT_ARR=()
            existing_pattern_list=`cat $UPGRADE_DEPLOYMENT_ICP4ACLUSTER_CR_TMP | ${YQ_CMD} r - spec.shared_configuration.sc_deployment_patterns`
            existing_opt_component_list=`cat $UPGRADE_DEPLOYMENT_ICP4ACLUSTER_CR_TMP | ${YQ_CMD} r - spec.shared_configuration.sc_optional_components`

            OIFS=$IFS
            IFS=',' read -r -a EXISTING_PATTERN_ARR <<< "$existing_pattern_list"
            IFS=',' read -r -a EXISTING_OPT_COMPONENT_ARR <<< "$existing_opt_component_list"
            IFS=$OIFS
        fi

        # # Check if the cp-console-iam-provider/cp-console-iam-idmgmt already created before upgrade CP4BA deployment.
        # if [[ (" ${EXISTING_PATTERN_ARR[@]} " =~ "content") || (" ${EXISTING_PATTERN_ARR[@]} " =~ "workflow") || (" ${EXISTING_PATTERN_ARR[@]} " =~ "document_processing") || (" ${EXISTING_OPT_COMPONENT_ARR[@]} " =~ "baw_authoring") || (" ${EXISTING_OPT_COMPONENT_ARR[@]} " =~ "ae_data_persistence") ]]; then
        #     iam_idprovider=$(${CLI_CMD} get route -n $deployment_project_name -o 'custom-columns=NAME:.metadata.name' --no-headers --ignore-not-found | grep cp-console-iam-provider)
        #     iam_idmgmt=$(${CLI_CMD} get route -n $deployment_project_name -o 'custom-columns=NAME:.metadata.name' --no-headers --ignore-not-found | grep cp-console-iam-idmgmt)
        #     if [[ -z $iam_idprovider || -z $iam_idmgmt ]]; then
        #         fail "Not found route \"cp-console-iam-idmgmt\" and \"cp-console-iam-provider\" in the project \"$deployment_project_name\"."
        #         info "You have to create \"cp-console-iam-idmgmt\" and \"cp-console-iam-provider\" before upgrade CP4BA deployment."
        #         exit 1
        #     fi
        # fi

        # Backup existing icp4acluster CR
        mkdir -p ${UPGRADE_DEPLOYMENT_CR_BAK}
        ${COPY_CMD} -rf ${UPGRADE_DEPLOYMENT_ICP4ACLUSTER_CR_TMP} ${UPGRADE_DEPLOYMENT_ICP4ACLUSTER_CR_BAK}
        # fi
        info "Merging existing CP4BA Custom Resource with new version ($CP4BA_RELEASE_BASE)"
        # Delete unnecessary section in CR
        ${YQ_CMD} d -i ${UPGRADE_DEPLOYMENT_ICP4ACLUSTER_CR_TMP} status
        #${YQ_CMD} d -i ${UPGRADE_DEPLOYMENT_ICP4ACLUSTER_CR_TMP} metadata.annotations
        ${YQ_CMD} d -i ${UPGRADE_DEPLOYMENT_ICP4ACLUSTER_CR_TMP} metadata.creationTimestamp
        ${YQ_CMD} d -i ${UPGRADE_DEPLOYMENT_ICP4ACLUSTER_CR_TMP} metadata.generation
        ${YQ_CMD} d -i ${UPGRADE_DEPLOYMENT_ICP4ACLUSTER_CR_TMP} metadata.resourceVersion
        ${YQ_CMD} d -i ${UPGRADE_DEPLOYMENT_ICP4ACLUSTER_CR_TMP} metadata.uid
        #Validate the CR by performing a dry run
        dryrun $UPGRADE_DEPLOYMENT_ICP4ACLUSTER_CR_TMP $deployment_project_name
        #applying the latest tmp CR so that we can update the kubectl.kubernetes.io/last-applied-configuration section to include any potential user edits
        kubectl apply -f ${UPGRADE_DEPLOYMENT_ICP4ACLUSTER_CR_TMP} -n $deployment_project_name >/dev/null 2>&1

        # replace release/appVersion
        ${SED_COMMAND} "s|release: .*|release: ${CP4BA_RELEASE_BASE}|g" ${UPGRADE_DEPLOYMENT_ICP4ACLUSTER_CR_TMP}
        ${SED_COMMAND} "s|appVersion: .*|appVersion: ${CP4BA_RELEASE_BASE}|g" ${UPGRADE_DEPLOYMENT_ICP4ACLUSTER_CR_TMP}

        
        # For https://jsw.ibm.com/browse/DBACLD-154068
        # Update FNCM and BAW license if required
        # The value user is a valid license type but from 24.0.1 but the customer can also replace it with concurrent-user and authorized-user
        update_license ${UPGRADE_DEPLOYMENT_ICP4ACLUSTER_CR_TMP} "fncm"
        update_license ${UPGRADE_DEPLOYMENT_ICP4ACLUSTER_CR_TMP} "baw"

        # 24.0.1
        # Add "dc_adp_datasource" into datasource_configuration if upgrading from 24.0.1 and existing pattern is document_processing
        upgrade_scenario="" 
        cpe_database_servername=""
        if [[ $cr_version != "${CP4BA_RELEASE_BASE}" && $cr_version == "24.0.1" && (" ${EXISTING_PATTERN_ARR[@]} " =~ "document_processing") && (" ${EXISTING_OPT_COMPONENT_ARR[@]} " =~ "document_processing_designer")]]; then
            ${YQ_CMD} w -i $UPGRADE_DEPLOYMENT_ICP4ACLUSTER_CR_TMP spec.datasource_configuration.dc_adp_datasource.dc_database_type "postgresql"
            ${YQ_CMD} w -i $UPGRADE_DEPLOYMENT_ICP4ACLUSTER_CR_TMP spec.datasource_configuration.dc_adp_datasource.database_name "adpggdb"

            info "Determining if EnterpriseDB PostgreSQL \"$EDB_INSTANCE_CP4BA_NAME\" is installed for IBM Cloud Pak for Business Automation."
            edb_instance_cp4ba_cr=$( ${CLI_CMD} get cluster.postgresql.k8s.enterprisedb.io -n $deployment_project_name --no-headers --ignore-not-found $EDB_INSTANCE_CP4BA_NAME | awk '{print $1}' )
	    if [[ $edb_instance_cp4ba_cr == $EDB_INSTANCE_CP4BA_NAME ]]; then
                info "Found EnterpriseDB PostgreSQL instance \"$EDB_INSTANCE_CP4BA_NAME\"" 
                upgrade_scenario="edb-already-exists"  # Postgres EDB exists
                ${YQ_CMD} w -i $UPGRADE_DEPLOYMENT_ICP4ACLUSTER_CR_TMP spec.datasource_configuration.dc_adp_datasource.database_servername "\"postgres-cp4ba-rw.{{ meta.namespace }}.svc\""
                ${YQ_CMD} w -i $UPGRADE_DEPLOYMENT_ICP4ACLUSTER_CR_TMP spec.datasource_configuration.dc_adp_datasource.database_port "\"5432\""
                ${YQ_CMD} w -i $UPGRADE_DEPLOYMENT_ICP4ACLUSTER_CR_TMP spec.datasource_configuration.dc_adp_datasource.database_ssl_secret_name "\"{{ meta.name }}-pg-client-cert-secret\""
                ${YQ_CMD} w -i $UPGRADE_DEPLOYMENT_ICP4ACLUSTER_CR_TMP spec.datasource_configuration.dc_adp_datasource.dc_use_postgres "true"
            else 
                info "Not found EnterpriseDB PostgreSQL instance \"$EDB_INSTANCE_CP4BA_NAME\""
                cpe_database_type=`cat $UPGRADE_DEPLOYMENT_ICP4ACLUSTER_CR_TMP | ${YQ_CMD} r - spec.datasource_configuration.dc_gcd_datasource.dc_database_type`
		if [[ $cpe_database_type == "postgresql" ]]; then
  		    # FNCM is using external Postgres, so ADPGG will use the same external Postgres
                    upgrade_scenario="external-postgres"  # External Postgres is used
                    cpe_database_servername=`cat $UPGRADE_DEPLOYMENT_ICP4ACLUSTER_CR_TMP | ${YQ_CMD} r - spec.datasource_configuration.dc_gcd_datasource.database_servername`
                    cpe_database_port=`cat $UPGRADE_DEPLOYMENT_ICP4ACLUSTER_CR_TMP | ${YQ_CMD} r - spec.datasource_configuration.dc_gcd_datasource.database_port`
                    cpe_database_ssl_secret_name=`cat $UPGRADE_DEPLOYMENT_ICP4ACLUSTER_CR_TMP | ${YQ_CMD} r - spec.datasource_configuration.dc_gcd_datasource.database_ssl_secret_name`
                    ${YQ_CMD} w -i $UPGRADE_DEPLOYMENT_ICP4ACLUSTER_CR_TMP spec.datasource_configuration.dc_adp_datasource.database_servername "$cpe_database_servername"
                    ${YQ_CMD} w -i $UPGRADE_DEPLOYMENT_ICP4ACLUSTER_CR_TMP spec.datasource_configuration.dc_adp_datasource.database_port "\"$cpe_database_port\""
                    ${YQ_CMD} w -i $UPGRADE_DEPLOYMENT_ICP4ACLUSTER_CR_TMP spec.datasource_configuration.dc_adp_datasource.database_ssl_secret_name "$cpe_database_ssl_secret_name"
                    ${YQ_CMD} w -i $UPGRADE_DEPLOYMENT_ICP4ACLUSTER_CR_TMP spec.datasource_configuration.dc_adp_datasource.dc_use_postgres "false"
                else 
		    # FNCM is not using Postgres, so ADPGG will use Postgres EDB
                    upgrade_scenario="new-edb"  # Provision Postgres EDB for ADPGG 
                    ${YQ_CMD} w -i $UPGRADE_DEPLOYMENT_ICP4ACLUSTER_CR_TMP spec.datasource_configuration.dc_adp_datasource.database_servername "\"postgres-cp4ba-rw.{{ meta.namespace }}.svc\""
                    ${YQ_CMD} w -i $UPGRADE_DEPLOYMENT_ICP4ACLUSTER_CR_TMP spec.datasource_configuration.dc_adp_datasource.database_port "\"5432\""
                    ${YQ_CMD} w -i $UPGRADE_DEPLOYMENT_ICP4ACLUSTER_CR_TMP spec.datasource_configuration.dc_adp_datasource.database_ssl_secret_name "\"{{ meta.name }}-pg-client-cert-secret\""
                    ${YQ_CMD} w -i $UPGRADE_DEPLOYMENT_ICP4ACLUSTER_CR_TMP spec.datasource_configuration.dc_adp_datasource.dc_use_postgres "true"
                fi
            fi
        fi

        # 24.0.1
        # Add "dc_ads_designer_datasource" into datasource_configuration if upgrading from 24.0.1 and existing pattern is decisions_ads and optional component is ads_designer
        icn_database_servername=""
        if [[ $cr_version != "${CP4BA_RELEASE_BASE}" && $cr_version == "24.0.1" && (" ${EXISTING_PATTERN_ARR[@]} " =~ "decisions_ads") && (" ${EXISTING_OPT_COMPONENT_ARR[@]} " =~ "ads_designer") ]]; then
            ${YQ_CMD} w -i $UPGRADE_DEPLOYMENT_ICP4ACLUSTER_CR_TMP spec.datasource_configuration.dc_ads_designer_datasource.dc_database_type "postgresql"
            ${YQ_CMD} w -i $UPGRADE_DEPLOYMENT_ICP4ACLUSTER_CR_TMP spec.datasource_configuration.dc_ads_designer_datasource.database_name "\"adsdesignerdb\""
            ${YQ_CMD} w -i $UPGRADE_DEPLOYMENT_ICP4ACLUSTER_CR_TMP spec.datasource_configuration.dc_ads_designer_datasource.current_schema "\"adsdesigner\""
            ${YQ_CMD} w -i $UPGRADE_DEPLOYMENT_ICP4ACLUSTER_CR_TMP spec.datasource_configuration.dc_ads_designer_datasource.database_instance_secret "\"ibm-ads-designer-database\""
            info "Determining if EnterpriseDB PostgreSQL \"$EDB_INSTANCE_CP4BA_NAME\" is installed for IBM Cloud Pak for Business Automation."
            edb_instance_cp4ba_cr=$( ${CLI_CMD} get cluster.postgresql.k8s.enterprisedb.io -n $deployment_project_name --no-headers --ignore-not-found $EDB_INSTANCE_CP4BA_NAME | awk '{print $1}' )
	    if [[ $edb_instance_cp4ba_cr == $EDB_INSTANCE_CP4BA_NAME ]]; then
                info "Found EnterpriseDB PostgreSQL instance \"$EDB_INSTANCE_CP4BA_NAME\"" 
                upgrade_scenario="edb-already-exists"  # Postgres EDB exists
                ${YQ_CMD} w -i $UPGRADE_DEPLOYMENT_ICP4ACLUSTER_CR_TMP spec.datasource_configuration.dc_ads_designer_datasource.database_servername "\"postgres-cp4ba-rw.{{ meta.namespace }}.svc\""
                ${YQ_CMD} w -i $UPGRADE_DEPLOYMENT_ICP4ACLUSTER_CR_TMP spec.datasource_configuration.dc_ads_designer_datasource.database_port "\"5432\""
                ${YQ_CMD} w -i $UPGRADE_DEPLOYMENT_ICP4ACLUSTER_CR_TMP spec.datasource_configuration.dc_ads_designer_datasource.ssl_secret_name "\"{{ meta.name }}-pg-client-cert-secret\""
                ${YQ_CMD} w -i $UPGRADE_DEPLOYMENT_ICP4ACLUSTER_CR_TMP spec.datasource_configuration.dc_ads_designer_datasource.dc_use_postgres "true"
            else 
                info "Not found EnterpriseDB PostgreSQL instance \"$EDB_INSTANCE_CP4BA_NAME\""
                icn_database_type=`cat $UPGRADE_DEPLOYMENT_ICP4ACLUSTER_CR_TMP | ${YQ_CMD} r - spec.datasource_configuration.dc_icn_datasource.dc_database_type`
		if [[ $icn_database_type == "postgresql" ]]; then
                    # ICN is using external Postgres, so ADS will use the same external Postgres
                    upgrade_scenario="external-postgres"  # External Postgres is used
                    icn_database_servername=`cat $UPGRADE_DEPLOYMENT_ICP4ACLUSTER_CR_TMP | ${YQ_CMD} r - spec.datasource_configuration.dc_icn_datasource.database_servername`
                    icn_database_port=`cat $UPGRADE_DEPLOYMENT_ICP4ACLUSTER_CR_TMP | ${YQ_CMD} r - spec.datasource_configuration.dc_icn_datasource.database_port`
                    icn_database_ssl_secret_name=`cat $UPGRADE_DEPLOYMENT_ICP4ACLUSTER_CR_TMP | ${YQ_CMD} r - spec.datasource_configuration.dc_icn_datasource.database_ssl_secret_name`
                    database_ssl_enabled=`cat $UPGRADE_DEPLOYMENT_ICP4ACLUSTER_CR_TMP | ${YQ_CMD} r - spec.datasource_configuration.dc_ssl_enabled`
                    ${YQ_CMD} w -i $UPGRADE_DEPLOYMENT_ICP4ACLUSTER_CR_TMP spec.datasource_configuration.dc_ads_designer_datasource.database_servername "$icn_database_servername"
                    ${YQ_CMD} w -i $UPGRADE_DEPLOYMENT_ICP4ACLUSTER_CR_TMP spec.datasource_configuration.dc_ads_designer_datasource.database_port "\"$icn_database_port\""
                    ${YQ_CMD} w -i $UPGRADE_DEPLOYMENT_ICP4ACLUSTER_CR_TMP spec.datasource_configuration.dc_ads_designer_datasource.ssl_enabled "$database_ssl_enabled"
                    ${YQ_CMD} w -i $UPGRADE_DEPLOYMENT_ICP4ACLUSTER_CR_TMP spec.datasource_configuration.dc_ads_designer_datasource.ssl_mode "verify-full"
                    ${YQ_CMD} w -i $UPGRADE_DEPLOYMENT_ICP4ACLUSTER_CR_TMP spec.datasource_configuration.dc_ads_designer_datasource.ssl_secret_name "\"$icn_database_ssl_secret_name\""
                    ${YQ_CMD} w -i $UPGRADE_DEPLOYMENT_ICP4ACLUSTER_CR_TMP spec.datasource_configuration.dc_ads_designer_datasource.dc_use_postgres "false"
                else 
		    # ICN is not using Postgres, so ADS will use Postgres EDB
                    upgrade_scenario="new-edb"  # Provision Postgres EDB for ADS
                    ${YQ_CMD} w -i $UPGRADE_DEPLOYMENT_ICP4ACLUSTER_CR_TMP spec.datasource_configuration.dc_ads_designer_datasource.database_servername "\"postgres-cp4ba-rw.{{ meta.namespace }}.svc\""
                    ${YQ_CMD} w -i $UPGRADE_DEPLOYMENT_ICP4ACLUSTER_CR_TMP spec.datasource_configuration.dc_ads_designer_datasource.database_port "\"5432\""
                    ${YQ_CMD} w -i $UPGRADE_DEPLOYMENT_ICP4ACLUSTER_CR_TMP spec.datasource_configuration.dc_ads_designer_datasource.ssl_secret_name "\"{{ meta.name }}-pg-client-cert-secret\""
                    ${YQ_CMD} w -i $UPGRADE_DEPLOYMENT_ICP4ACLUSTER_CR_TMP spec.datasource_configuration.dc_ads_designer_datasource.dc_use_postgres "true"
                fi
            fi
        fi

        # 24.0.1
        # Add "dc_ads_runtime_datasource" into datasource_configuration if upgrading from 24.0.1 and existing pattern is decisions_ads and optional component is ads_runtime
        if [[ $cr_version != "${CP4BA_RELEASE_BASE}" && $cr_version == "24.0.1" && (" ${EXISTING_PATTERN_ARR[@]} " =~ "decisions_ads") && (" ${EXISTING_OPT_COMPONENT_ARR[@]} " =~ "ads_runtime") ]]; then
            ${YQ_CMD} w -i $UPGRADE_DEPLOYMENT_ICP4ACLUSTER_CR_TMP spec.datasource_configuration.dc_ads_runtime_datasource.dc_database_type "postgresql"
            ${YQ_CMD} w -i $UPGRADE_DEPLOYMENT_ICP4ACLUSTER_CR_TMP spec.datasource_configuration.dc_ads_runtime_datasource.database_name "\"adsruntimedb\""
            ${YQ_CMD} w -i $UPGRADE_DEPLOYMENT_ICP4ACLUSTER_CR_TMP spec.datasource_configuration.dc_ads_runtime_datasource.current_schema "\"adsruntime\""
            ${YQ_CMD} w -i $UPGRADE_DEPLOYMENT_ICP4ACLUSTER_CR_TMP spec.datasource_configuration.dc_ads_runtime_datasource.database_instance_secret "\"ibm-ads-runtime-database\""
            info "Determining if EnterpriseDB PostgreSQL \"$EDB_INSTANCE_CP4BA_NAME\" is installed for IBM Cloud Pak for Business Automation."
            edb_instance_cp4ba_cr=$( ${CLI_CMD} get cluster.postgresql.k8s.enterprisedb.io -n $deployment_project_name --no-headers --ignore-not-found $EDB_INSTANCE_CP4BA_NAME | awk '{print $1}' )
	    if [[ $edb_instance_cp4ba_cr == $EDB_INSTANCE_CP4BA_NAME ]]; then
                info "Found EnterpriseDB PostgreSQL instance \"$EDB_INSTANCE_CP4BA_NAME\"" 
                upgrade_scenario="edb-already-exists"  # Postgres EDB exists
                ${YQ_CMD} w -i $UPGRADE_DEPLOYMENT_ICP4ACLUSTER_CR_TMP spec.datasource_configuration.dc_ads_runtime_datasource.dc_use_postgres "true"
                ${YQ_CMD} w -i $UPGRADE_DEPLOYMENT_ICP4ACLUSTER_CR_TMP spec.datasource_configuration.dc_ads_runtime_datasource.database_servername "\"postgres-cp4ba-rw.{{ meta.namespace }}.svc\""
                ${YQ_CMD} w -i $UPGRADE_DEPLOYMENT_ICP4ACLUSTER_CR_TMP spec.datasource_configuration.dc_ads_runtime_datasource.database_port "\"5432\""
                ${YQ_CMD} w -i $UPGRADE_DEPLOYMENT_ICP4ACLUSTER_CR_TMP spec.datasource_configuration.dc_ads_runtime_datasource.ssl_secret_name "\"{{ meta.name }}-pg-client-cert-secret\""
            else 
                info "Not found EnterpriseDB PostgreSQL instance \"$EDB_INSTANCE_CP4BA_NAME\""
                icn_database_type=`cat $UPGRADE_DEPLOYMENT_ICP4ACLUSTER_CR_TMP | ${YQ_CMD} r - spec.datasource_configuration.dc_icn_datasource.dc_database_type`
		if [[ $icn_database_type == "postgresql" ]]; then
                    # ICN is using external Postgres, so ADS will use the same external Postgres
                    upgrade_scenario="external-postgres"  # External Postgres is used
                    icn_database_servername=`cat $UPGRADE_DEPLOYMENT_ICP4ACLUSTER_CR_TMP | ${YQ_CMD} r - spec.datasource_configuration.dc_icn_datasource.database_servername`
                    icn_database_port=`cat $UPGRADE_DEPLOYMENT_ICP4ACLUSTER_CR_TMP | ${YQ_CMD} r - spec.datasource_configuration.dc_icn_datasource.database_port`
                    icn_database_ssl_secret_name=`cat $UPGRADE_DEPLOYMENT_ICP4ACLUSTER_CR_TMP | ${YQ_CMD} r - spec.datasource_configuration.dc_icn_datasource.database_ssl_secret_name`
                    database_ssl_enabled=`cat $UPGRADE_DEPLOYMENT_ICP4ACLUSTER_CR_TMP | ${YQ_CMD} r - spec.datasource_configuration.dc_ssl_enabled`
                    ${YQ_CMD} w -i $UPGRADE_DEPLOYMENT_ICP4ACLUSTER_CR_TMP spec.datasource_configuration.dc_ads_runtime_datasource.dc_use_postgres "false"
                    ${YQ_CMD} w -i $UPGRADE_DEPLOYMENT_ICP4ACLUSTER_CR_TMP spec.datasource_configuration.dc_ads_runtime_datasource.database_servername "$icn_database_servername"
                    ${YQ_CMD} w -i $UPGRADE_DEPLOYMENT_ICP4ACLUSTER_CR_TMP spec.datasource_configuration.dc_ads_runtime_datasource.database_port "\"$icn_database_port\""
                    ${YQ_CMD} w -i $UPGRADE_DEPLOYMENT_ICP4ACLUSTER_CR_TMP spec.datasource_configuration.dc_ads_runtime_datasource.ssl_enabled "$database_ssl_enabled"
                    ${YQ_CMD} w -i $UPGRADE_DEPLOYMENT_ICP4ACLUSTER_CR_TMP spec.datasource_configuration.dc_ads_runtime_datasource.ssl_mode "verify-full"
                    ${YQ_CMD} w -i $UPGRADE_DEPLOYMENT_ICP4ACLUSTER_CR_TMP spec.datasource_configuration.dc_ads_runtime_datasource.ssl_secret_name "\"$icn_database_ssl_secret_name\""
                else 
		    # FNCM is not using Postgres, so ADPGG wil use Postgres EDB
                    upgrade_scenario="new-edb"  # Provision Postgres EDB for ADS
                    ${YQ_CMD} w -i $UPGRADE_DEPLOYMENT_ICP4ACLUSTER_CR_TMP spec.datasource_configuration.dc_ads_runtime_datasource.dc_use_postgres "true"
                    ${YQ_CMD} w -i $UPGRADE_DEPLOYMENT_ICP4ACLUSTER_CR_TMP spec.datasource_configuration.dc_ads_runtime_datasource.database_servername "\"postgres-cp4ba-rw.{{ meta.namespace }}.svc\""
                    ${YQ_CMD} w -i $UPGRADE_DEPLOYMENT_ICP4ACLUSTER_CR_TMP spec.datasource_configuration.dc_ads_runtime_datasource.database_port "\"5432\""
                    ${YQ_CMD} w -i $UPGRADE_DEPLOYMENT_ICP4ACLUSTER_CR_TMP spec.datasource_configuration.dc_ads_runtime_datasource.ssl_secret_name "\"{{ meta.name }}-pg-client-cert-secret\""
                fi
            fi
        fi

        # 21.0.3
        # if select baw authoring, handles specific upgrades for versions and optional components related to BAW authoring
        if [[ $cr_version != "${CP4BA_RELEASE_BASE}" && $cr_version == "21.0.3" && (" ${EXISTING_OPT_COMPONENT_ARR[@]} " =~ "baw_authoring") ]]; then
            # Add application to sc_deployment_patterns and add app_designer to sc_optional_components to keep application pattern
            EXISTING_PATTERN_ARR=( "${EXISTING_PATTERN_ARR[@]}" "application" )
            EXISTING_OPT_COMPONENT_ARR=( "${EXISTING_OPT_COMPONENT_ARR[@]}" "app_designer" )

            # Replace the database name of Business Automation Studio with the database name of Business Automation Workflow Authoring, for example, replace bastudio_configuration.database.Name with workflow_authoring_configuration.database.database_name.
            baw_auth_db_name=`cat $UPGRADE_DEPLOYMENT_ICP4ACLUSTER_CR_TMP | ${YQ_CMD} r - spec.workflow_authoring_configuration.database.database_name`
            if [[ ! -z $baw_auth_db_name ]]; then
                ${YQ_CMD} w -i ${UPGRADE_DEPLOYMENT_ICP4ACLUSTER_CR_TMP} spec.bastudio_configuration.database.name "\"$baw_auth_db_name\""
            else
                warning "Not found the value of \"spec.workflow_authoring_configuration.database.database_name\" from ${UPGRADE_DEPLOYMENT_ICP4ACLUSTER_CR_TMP}"
            fi

            # Update the Business Automation Studio admin secret to replace the database username and password of Business Automation Studio with the database username and password of Business Automation Workflow Authoring.
            baw_auth_db_secret_name=`cat $UPGRADE_DEPLOYMENT_ICP4ACLUSTER_CR_TMP | ${YQ_CMD} r - spec.workflow_authoring_configuration.database.secret_name`
            if [[ ! -z $baw_auth_db_secret_name ]]; then
                if [[ $baw_auth_db_secret_name == *"meta.name"* ]]; then
                    baw_auth_db_secret_name=$(echo "$baw_auth_db_secret_name" | sed "s/{{\s*meta\.name\s*}}/${cr_metaname}/g")
                fi
                baw_auth_db_user_name=$(${CLI_CMD} get secret $baw_auth_db_secret_name --no-headers --ignore-not-found -n $deployment_project_name -o jsonpath='{.data.dbUser}' | base64 -d)

                if [[ -z $baw_auth_db_user_name ]]; then
                    baw_auth_db_user_name=$(${CLI_CMD} get secret $baw_auth_db_secret_name --no-headers --ignore-not-found -n $deployment_project_name -o jsonpath='{.stringData.dbUser}' | base64 -d)
                fi

                baw_auth_db_user_pwd=$(${CLI_CMD} get secret $baw_auth_db_secret_name --no-headers --ignore-not-found -n $deployment_project_name -o jsonpath='{.data.password}' | base64 -d)

                if [[ -z $baw_auth_db_user_pwd ]]; then
                    baw_auth_db_user_pwd=$(${CLI_CMD} get secret $baw_auth_db_secret_name --no-headers --ignore-not-found -n $deployment_project_name -o jsonpath='{.stringData.password}' | base64 -d)
                fi

                bas_db_secret_name=`cat $UPGRADE_DEPLOYMENT_ICP4ACLUSTER_CR_TMP | ${YQ_CMD} r - spec.bastudio_configuration.admin_secret_name`
                if [[ ! -z $bas_db_secret_name ]]; then
                    if [[ $bas_db_secret_name == *"meta.name"* ]]; then
                        bas_db_secret_name=$(echo "$bas_db_secret_name" | sed "s/{{\s*meta\.name\s*}}/${cr_metaname}/g")
                    fi

                    # Update User Name
                    bas_db_user_name=$(${CLI_CMD} get secret $bas_db_secret_name --no-headers --ignore-not-found -n $deployment_project_name -o jsonpath='{.data.dbUsername}' | base64 -d)
                    if [[ -z $bas_db_user_name ]]; then
                        bas_db_user_name=$(${CLI_CMD} get secret $bas_db_secret_name --no-headers --ignore-not-found -n $deployment_project_name -o jsonpath='{.stringData.dbUsername}' | base64 -d)
                        if [[ ! -z $bas_db_user_name ]]; then
                            ${CLI_CMD} patch secret $bas_db_secret_name -n $deployment_project_name -p '{"stringData":{"dbUsername":"'$(echo -n "$baw_auth_db_user_name" | base64)'"}}' >/dev/null 2>&1
                        else
                            warning "Not found the value of \"dbUsername\" from secret $bas_db_secret_name in the project \"$deployment_project_name\"."
                        fi
                    else
                        ${CLI_CMD} patch secret $bas_db_secret_name -n $deployment_project_name -p '{"data":{"dbUsername":"'$(echo -n "$baw_auth_db_user_name" | base64)'"}}' >/dev/null 2>&1
                    fi

                    # Update User Password
                    bas_db_user_pwd=$(${CLI_CMD} get secret $bas_db_secret_name --no-headers --ignore-not-found -n $deployment_project_name -o jsonpath='{.data.dbPassword}' | base64 -d)
                    if [[ -z $bas_db_user_pwd ]]; then
                        bas_db_user_pwd=$(${CLI_CMD} get secret $bas_db_secret_name --no-headers --ignore-not-found -n $deployment_project_name -o jsonpath='{.stringData.dbPassword}' | base64 -d)
                        if [[ ! -z $bas_db_user_pwd ]]; then
                            ${CLI_CMD} patch secret $bas_db_secret_name -n $deployment_project_name -p '{"stringData":{"dbPassword":"'$(echo -n "$baw_auth_db_user_pwd" | base64)'"}}' >/dev/null 2>&1
                        else
                            warning "Not found the value of \"dbPassword\" from secret $bas_db_secret_name in the project \"$deployment_project_name\"."
                        fi
                    else
                        ${CLI_CMD} patch secret $bas_db_secret_name -n $deployment_project_name -p '{"data":{"dbPassword":"'$(echo -n "$baw_auth_db_user_pwd" | base64)'"}}' >/dev/null 2>&1
                    fi
                else
                    warning "Not found the value of \"spec.bastudio_configuration.admin_secret_name\" from ${UPGRADE_DEPLOYMENT_ICP4ACLUSTER_CR_TMP}"
                fi

            else
                warning "Not found the value of \"spec.workflow_authoring_configuration.database.secret_name\" from ${UPGRADE_DEPLOYMENT_ICP4ACLUSTER_CR_TMP}"
            fi
        fi

        # Add "kafka" into sc_optional_component if kafka_services.enable is true when upgrade
        if [[ ((" ${EXISTING_PATTERN_ARR[@]} " =~ "workflow") && (" ${EXISTING_OPT_COMPONENT_ARR[@]} " =~ "baw_authoring")) ]]; then
            kafka_flag=`cat $UPGRADE_DEPLOYMENT_ICP4ACLUSTER_CR_TMP | ${YQ_CMD} r - spec.workflow_authoring_configuration.kafka_services`
            if [[ $kafka_flag == "True" || $kafka_flag == "true" ]]; then
                EXISTING_OPT_COMPONENT_ARR=( "${EXISTING_OPT_COMPONENT_ARR[@]}" "kafka" )
            fi
        fi

        # make PFS as an optional component for BAW and WfPS Authoring
        if [[ (" ${EXISTING_PATTERN_ARR[@]} " =~ "workflow") || (" ${EXISTING_PATTERN_ARR[@]} " =~ "workflow-process-service") ]]; then
            if [[ (" ${EXISTING_OPT_COMPONENT_ARR[@]} " =~ "baw_authoring") || (" ${EXISTING_PATTERN_ARR[@]} " =~ "workflow-process-service") ]]; then
                if [[ ! (" ${EXISTING_OPT_COMPONENT_ARR[@]} " =~ "pfs") ]]; then
                    if [[ $cr_version != "${CP4BA_RELEASE_BASE}" && ($cr_version == "21.0.3" || $cr_version == "22.0.2") ]]; then
                        EXISTING_OPT_COMPONENT_ARR=( "${EXISTING_OPT_COMPONENT_ARR[@]}" "pfs" )
                    fi
                fi
            fi
            # Workflow authoring/WfPS authoring use embedded PFS starting from $CP4BA_RELEASE_BASE
            ${YQ_CMD} d -i ${UPGRADE_DEPLOYMENT_ICP4ACLUSTER_CR_TMP} spec.pfs_configuration
            baw_instance_index=0
            while true; do
                baw_instance_flag=`cat $UPGRADE_DEPLOYMENT_ICP4ACLUSTER_CR_TMP | ${YQ_CMD} r - spec.baw_configuration.[${baw_instance_index}]`
                if [[ ! -z "$baw_instance_flag" ]]; then
                    ${YQ_CMD} d -i ${UPGRADE_DEPLOYMENT_ICP4ACLUSTER_CR_TMP} spec.baw_configuration.[${baw_instance_index}].pfs_bpd_database_init_job
                    ((baw_instance_index++))
                else
                    break
                fi
            done
            ${YQ_CMD} d -i ${UPGRADE_DEPLOYMENT_ICP4ACLUSTER_CR_TMP} spec.workflow_authoring_configuration.pfs_bpd_database_init_job
            # DBACLD-113568
            ${YQ_CMD} d -i ${UPGRADE_DEPLOYMENT_ICP4ACLUSTER_CR_TMP} spec.workflow_authoring_configuration.kafka_services

            ${CLI_CMD} patch icp4acluster $icp4acluster_cr_name -n $deployment_project_name --type=json -p='[{"op": "remove", "path": "/spec/pfs_configuration"}]' >/dev/null 2>&1
            ${CLI_CMD} patch icp4acluster $icp4acluster_cr_name -n $deployment_project_name --type=json -p='[{"op": "remove", "path": "/spec/baw_configuration/0/pfs_bpd_database_init_job"}]' >/dev/null 2>&1
            ${CLI_CMD} patch icp4acluster $icp4acluster_cr_name -n $deployment_project_name --type=json -p='[{"op": "remove", "path": "/spec/workflow_authoring_configuration/pfs_bpd_database_init_job"}]' >/dev/null 2>&1
            ${CLI_CMD} patch icp4acluster $icp4acluster_cr_name -n $deployment_project_name --type=json -p='[{"op": "remove", "path": "/spec/workflow_authoring_configuration/kafka_services"}]' >/dev/null 2>&1
            # ${CLI_CMD} patch icp4acluster $icp4acluster_cr_name -n $deployment_project_name --type=json -p='[{"op": "remove", "path": "/spec/workflow_authoring_configuration/database"}]' >/dev/null 2>&1
        fi

        # Change ssl_protocol for PFS required in $CP4BA_RELEASE_BASE release
        pfs_ssl_protocol=`cat $UPGRADE_DEPLOYMENT_ICP4ACLUSTER_CR_TMP | ${YQ_CMD} r - spec.pfs_configuration.security.ssl_protocol`
        if [ ! -z "$pfs_ssl_protocol" ]; then
            ${YQ_CMD} w -i ${UPGRADE_DEPLOYMENT_ICP4ACLUSTER_CR_TMP} spec.pfs_configuration.security.ssl_protocol "TLSv1.2"
        fi
        # remove sc_common_services
        # ${YQ_CMD} m -i -a -M --overwrite ${UPGRADE_DEPLOYMENT_ICP4ACLUSTER_CR_TMP} ${UPGRADE_CS_ZEN_FILE}
        ${YQ_CMD} d -i ${UPGRADE_DEPLOYMENT_ICP4ACLUSTER_CR_TMP} spec.shared_configuration.sc_common_service
        ${YQ_CMD} d -i ${UPGRADE_DEPLOYMENT_ICP4ACLUSTER_CR_TMP} spec.shared_configuration.sc_common_service

        # This block of is used to merge the BAI save point into the CR.  It's only executed when it's an n-1 to n upgrade, not ifix to ifix
        # The is_ifix_to_ifix_upgrade is set to false in the determine_type_of_upgrade function.
        info "CR Version: $cr_version"
        determine_type_of_upgrade "$cr_version"
        # if [[ ! ("$cp4ba_original_csv_ver_for_upgrade_script" == "24.0."*) ]]; then
        if [[ "$is_ifix_to_ifix_upgrade" == "false" ]]; then
            # Merge BAI save point into content cr, determine if the Flink job savepoint should be merged or not
            if [[ (" ${EXISTING_OPT_COMPONENT_ARR[@]} " =~ "bai") ]]; then
                info "Merging Flink job savepoint from \"${UPGRADE_DEPLOYMENT_BAI_TMP}\" into new version of custom resource \"${UPGRADE_DEPLOYMENT_ICP4ACLUSTER_CR}\"."
                if [ -s ${UPGRADE_DEPLOYMENT_BAI_TMP} ]; then
                    ${YQ_CMD} m -i -a -M --overwrite ${UPGRADE_DEPLOYMENT_ICP4ACLUSTER_CR_TMP} ${UPGRADE_DEPLOYMENT_BAI_TMP}
                    success "Merged Flink job savepoint into new version of custom resource."
                else
                    warning "Not found file ${UPGRADE_DEPLOYMENT_BAI_TMP}."
                fi
            fi
        fi

        ${SED_COMMAND} "s/route_reencrypt: .*/route_reencrypt: $ZEN_ROUTE_REENCRYPT/g" ${UPGRADE_DEPLOYMENT_ICP4ACLUSTER_CR_TMP}

        # Function to detect if the Domain is configured with SCIM
        # https://jsw.ibm.com/browse/DBACLD-157386 https://jsw.ibm.com/browse/DBACLD-178101 https://jsw.ibm.com/browse/DBACLD-177550 https://jsw.ibm.com/browse/DBACLD-177742
        detect_scim_configuration "$deployment_project_name" "ibm-cp4ba-shared-info" "${UPGRADE_DEPLOYMENT_ICP4ACLUSTER_CR_TMP}"

        # for BAW authoring, base on initialize_configuration to set workflow_authoring_configuration.case.datasource_name_tos/connection_point_name_tos
        if [[ $cr_version != "${CP4BA_RELEASE_BASE}" && ($cr_version == "21.0.3" || $cr_version == "22.0.2") ]]; then
            if [[ " ${EXISTING_OPT_COMPONENT_ARR[@]} " =~ "baw_authoring" ]]; then
                baw_datasource_name_tos=`cat $UPGRADE_DEPLOYMENT_ICP4ACLUSTER_CR_TMP | ${YQ_CMD} r - spec.workflow_authoring_configuration.case.datasource_name_tos`
                baw_connection_point_name_tos=`cat $UPGRADE_DEPLOYMENT_ICP4ACLUSTER_CR_TMP | ${YQ_CMD} r - spec.workflow_authoring_configuration.case.connection_point_name_tos`
                if [[ -z "$baw_datasource_name_tos" || -z "$baw_connection_point_name_tos" ]]; then
                    init_section=`cat $UPGRADE_DEPLOYMENT_ICP4ACLUSTER_CR_TMP | ${YQ_CMD} r - spec.initialize_configuration`
                    if [[ -z "$init_section" ]]; then
                        info "Not found initialize_configuration, continue..."
                        # For upgrade to 23.0.1 olny, remove it in 23.0.2 release
                        # info "If you want to add workflow_authoring_configuration.case.datasource_name_tos/connection_point_name_tos manually following https://www.ibm.com/docs/en/cloud-paks/cp-biz-automation/$CP4BA_RELEASE_BASE?topic=upgrade-upgrading-business-automation-workflow-authoring"
                    else
                        os_index=0
                        while true; do
                            os_flag=`cat $UPGRADE_DEPLOYMENT_ICP4ACLUSTER_CR_TMP | ${YQ_CMD} r - spec.initialize_configuration.ic_obj_store_creation.object_stores.[${os_index}].oc_cpe_obj_store_symb_name`
                            #check if os_flag is not empty
                            if [[ ! -z "$os_flag" ]]; then
                                enable_workflow=`cat $UPGRADE_DEPLOYMENT_ICP4ACLUSTER_CR_TMP | ${YQ_CMD} r - spec.initialize_configuration.ic_obj_store_creation.object_stores.[${os_index}].oc_cpe_obj_store_enable_workflow`
                                if [[ "$enable_workflow" == "true" ]]; then
                                    tos_datasource_name=`cat $UPGRADE_DEPLOYMENT_ICP4ACLUSTER_CR_TMP | ${YQ_CMD} r - spec.initialize_configuration.ic_obj_store_creation.object_stores.[${os_index}].oc_cpe_obj_store_conn.dc_os_datasource_name`
                                    tos_connection=`cat $UPGRADE_DEPLOYMENT_ICP4ACLUSTER_CR_TMP | ${YQ_CMD} r - spec.initialize_configuration.ic_obj_store_creation.object_stores.[${os_index}].oc_cpe_obj_store_workflow_pe_conn_point_name`
                                    if [[ ! -z "$tos_datasource_name" ]]; then
                                        ${YQ_CMD} w -i ${UPGRADE_DEPLOYMENT_ICP4ACLUSTER_CR_TMP} spec.workflow_authoring_configuration.case.datasource_name_tos "$tos_datasource_name"
                                    fi
                                    if [[ ! -z "$tos_connection" ]]; then
                                        ${YQ_CMD} w -i ${UPGRADE_DEPLOYMENT_ICP4ACLUSTER_CR_TMP} spec.workflow_authoring_configuration.case.connection_point_name_tos "$tos_connection"
                                    fi
                                fi
                                ((os_index++))
                            else
                                break
                            fi
                        done
                    fi
                fi
            fi
        fi

        # for BAW runtime, base on initialize_configuration set baw_configuration[0].case.datasource_name_tos/connection_point_name_tos
        if [[ $cr_version != "${CP4BA_RELEASE_BASE}" && ($cr_version == "21.0.3" || $cr_version == "22.0.2") ]]; then
            if [[ (! " ${EXISTING_OPT_COMPONENT_ARR[@]} " =~ "baw_authoring") && (" ${EXISTING_PATTERN_ARR[@]} " =~ "workflow" || " ${EXISTING_PATTERN_ARR[@]} " =~ "workflow-workstreams") ]]; then
                baw_instance_index=0
                while true; do
                    baw_instance_flag=`cat $UPGRADE_DEPLOYMENT_ICP4ACLUSTER_CR_TMP | ${YQ_CMD} r - spec.baw_configuration.[${baw_instance_index}].case`
                    if [[ ! -z "$baw_instance_flag" ]]; then
                        baw_datasource_name_tos=`cat $UPGRADE_DEPLOYMENT_ICP4ACLUSTER_CR_TMP | ${YQ_CMD} r - spec.baw_configuration.[${baw_instance_index}].case.datasource_name_tos`
                        baw_connection_point_name_tos=`cat $UPGRADE_DEPLOYMENT_ICP4ACLUSTER_CR_TMP | ${YQ_CMD} r - spec.baw_configuration.[${baw_instance_index}].case.connection_point_name_tos`
                        if [[ -z "$baw_datasource_name_tos" || -z "$baw_connection_point_name_tos" ]]; then
                            init_section=`cat $UPGRADE_DEPLOYMENT_ICP4ACLUSTER_CR_TMP | ${YQ_CMD} r - spec.initialize_configuration`
                            if [[ -z "$init_section" ]]; then
                                info "Not found initialize_configuration, continue..."
                                # For upgrade to 23.0.1 only, remove it in 23.0.2 release
                                # info "If you want to add baw_configuration.[0].case.datasource_name_tos/connection_point_name_tos manually following https://www.ibm.com/docs/en/cloud-paks/cp-biz-automation/$CP4BA_RELEASE_BASE?topic=upgrade-upgrading-business-automation-workflow-authoring"
                            else
                                os_index=0
                                while true; do
                                    os_flag=`cat $UPGRADE_DEPLOYMENT_ICP4ACLUSTER_CR_TMP | ${YQ_CMD} r - spec.initialize_configuration.ic_obj_store_creation.object_stores.[${os_index}].oc_cpe_obj_store_symb_name`
                                    if [[ ! -z "$os_flag" ]]; then
                                        enable_workflow=`cat $UPGRADE_DEPLOYMENT_ICP4ACLUSTER_CR_TMP | ${YQ_CMD} r - spec.initialize_configuration.ic_obj_store_creation.object_stores.[${os_index}].oc_cpe_obj_store_enable_workflow`
                                        if [[ "$enable_workflow" == "true" ]]; then
                                            tos_datasource_name=`cat $UPGRADE_DEPLOYMENT_ICP4ACLUSTER_CR_TMP | ${YQ_CMD} r - spec.initialize_configuration.ic_obj_store_creation.object_stores.[${os_index}].oc_cpe_obj_store_conn.dc_os_datasource_name`
                                            tos_connection=`cat $UPGRADE_DEPLOYMENT_ICP4ACLUSTER_CR_TMP | ${YQ_CMD} r - spec.initialize_configuration.ic_obj_store_creation.object_stores.[${os_index}].oc_cpe_obj_store_workflow_pe_conn_point_name`
                                            if [[ ! -z "$tos_datasource_name" ]]; then
                                                ${YQ_CMD} w -i ${UPGRADE_DEPLOYMENT_ICP4ACLUSTER_CR_TMP} spec.baw_configuration.[${baw_instance_index}].case.datasource_name_tos "$tos_datasource_name"
                                            fi
                                            if [[ ! -z "$tos_connection" ]]; then
                                                ${YQ_CMD} w -i ${UPGRADE_DEPLOYMENT_ICP4ACLUSTER_CR_TMP} spec.baw_configuration.[${baw_instance_index}].case.connection_point_name_tos "$tos_connection"
                                            fi
                                        fi
                                        ((os_index++))
                                    else
                                        break
                                    fi
                                done
                            fi
                        fi
                        ((baw_instance_index++))
                    else
                        break
                    fi
                done
            fi
        fi

        # convert event_emitter to list for workflow authoring
        if [[ (" ${EXISTING_OPT_COMPONENT_ARR[@]} " =~ "baw_authoring") ]]; then
            if [[ $cr_version != "${CP4BA_RELEASE_BASE}" && ($cr_version == "21.0.3" || $cr_version == "22.0.2") ]]; then
                baw_instance_flag=`cat $UPGRADE_DEPLOYMENT_ICP4ACLUSTER_CR_TMP | ${YQ_CMD} r - spec.workflow_authoring_configuration.case.event_emitter`
                if [[ ! -z "$baw_instance_flag" ]]; then
                    ## https://jsw.ibm.com/browse/DBACLD-154386
                    ## Referencing the object store name instead of datasource name                
                    baw_event_emitter_tos_name=`cat $UPGRADE_DEPLOYMENT_ICP4ACLUSTER_CR_TMP | ${YQ_CMD} r - spec.workflow_authoring_configuration.case.object_store_name_tos`
                    baw_event_emitter_connection_point_name=`cat $UPGRADE_DEPLOYMENT_ICP4ACLUSTER_CR_TMP | ${YQ_CMD} r - spec.workflow_authoring_configuration.case.connection_point_name_tos`
                    baw_event_emitter_date_sql=`cat $UPGRADE_DEPLOYMENT_ICP4ACLUSTER_CR_TMP | ${YQ_CMD} r - spec.workflow_authoring_configuration.case.event_emitter.date_sql`
                    baw_event_emitter_logical_unique_id=`cat $UPGRADE_DEPLOYMENT_ICP4ACLUSTER_CR_TMP | ${YQ_CMD} r - spec.workflow_authoring_configuration.case.event_emitter.logical_unique_id`
                    baw_event_emitter_solution_list=`cat $UPGRADE_DEPLOYMENT_ICP4ACLUSTER_CR_TMP | ${YQ_CMD} r - spec.workflow_authoring_configuration.case.event_emitter.solution_list`
                    baw_event_emitter_casetype_list=`cat $UPGRADE_DEPLOYMENT_ICP4ACLUSTER_CR_TMP | ${YQ_CMD} r - spec.workflow_authoring_configuration.case.event_emitter.casetype_list`
                    baw_event_emitter_emitter_batch_size=`cat $UPGRADE_DEPLOYMENT_ICP4ACLUSTER_CR_TMP | ${YQ_CMD} r - spec.workflow_authoring_configuration.case.event_emitter.emitter_batch_size`
                    baw_event_emitter_process_pe_events=`cat $UPGRADE_DEPLOYMENT_ICP4ACLUSTER_CR_TMP | ${YQ_CMD} r - spec.workflow_authoring_configuration.case.event_emitter.process_pe_events`

                    ${YQ_CMD} w -i ${UPGRADE_DEPLOYMENT_ICP4ACLUSTER_CR_TMP} spec.workflow_authoring_configuration.case.event_emitter.[0].tos_name "$baw_event_emitter_tos_name"
                    ${YQ_CMD} w -i ${UPGRADE_DEPLOYMENT_ICP4ACLUSTER_CR_TMP} spec.workflow_authoring_configuration.case.event_emitter.[0].connection_point_name "$baw_event_emitter_connection_point_name"
                    ${YQ_CMD} w -i ${UPGRADE_DEPLOYMENT_ICP4ACLUSTER_CR_TMP} spec.workflow_authoring_configuration.case.event_emitter.[0].date_sql "$baw_event_emitter_date_sql"
                    ${YQ_CMD} w -i ${UPGRADE_DEPLOYMENT_ICP4ACLUSTER_CR_TMP} spec.workflow_authoring_configuration.case.event_emitter.[0].logical_unique_id "$baw_event_emitter_logical_unique_id"
                    ${YQ_CMD} w -i ${UPGRADE_DEPLOYMENT_ICP4ACLUSTER_CR_TMP} spec.workflow_authoring_configuration.case.event_emitter.[0].solution_list "$baw_event_emitter_solution_list"
                    ${YQ_CMD} w -i ${UPGRADE_DEPLOYMENT_ICP4ACLUSTER_CR_TMP} spec.workflow_authoring_configuration.case.event_emitter.[0].casetype_list "$baw_event_emitter_casetype_list"
                    ${YQ_CMD} w -i ${UPGRADE_DEPLOYMENT_ICP4ACLUSTER_CR_TMP} spec.workflow_authoring_configuration.case.event_emitter.[0].emitter_batch_size "$baw_event_emitter_emitter_batch_size"
                    ${YQ_CMD} w -i ${UPGRADE_DEPLOYMENT_ICP4ACLUSTER_CR_TMP} spec.workflow_authoring_configuration.case.event_emitter.[0].process_pe_events "$baw_event_emitter_process_pe_events"

                    ${CLI_CMD} patch icp4acluster $icp4acluster_cr_name -n $deployment_project_name --type=json -p='[{"op": "remove", "path": "/spec/workflow_authoring_configuration/case/event_emitter/tos_name"}]' >/dev/null 2>&1
                    ${CLI_CMD} patch icp4acluster $icp4acluster_cr_name -n $deployment_project_name --type=json -p='[{"op": "remove", "path": "/spec/workflow_authoring_configuration/case/event_emitter/connection_point_name"}]' >/dev/null 2>&1
                    ${CLI_CMD} patch icp4acluster $icp4acluster_cr_name -n $deployment_project_name --type=json -p='[{"op": "remove", "path": "/spec/workflow_authoring_configuration/case/event_emitter/date_sql"}]' >/dev/null 2>&1
                    ${CLI_CMD} patch icp4acluster $icp4acluster_cr_name -n $deployment_project_name --type=json -p='[{"op": "remove", "path": "/spec/workflow_authoring_configuration/case/event_emitter/logical_unique_id"}]' >/dev/null 2>&1
                    ${CLI_CMD} patch icp4acluster $icp4acluster_cr_name -n $deployment_project_name --type=json -p='[{"op": "remove", "path": "/spec/workflow_authoring_configuration/case/event_emitter/solution_list"}]' >/dev/null 2>&1
                    ${CLI_CMD} patch icp4acluster $icp4acluster_cr_name -n $deployment_project_name --type=json -p='[{"op": "remove", "path": "/spec/workflow_authoring_configuration/case/event_emitter/casetype_list"}]' >/dev/null 2>&1
                    ${CLI_CMD} patch icp4acluster $icp4acluster_cr_name -n $deployment_project_name --type=json -p='[{"op": "remove", "path": "/spec/workflow_authoring_configuration/case/event_emitter/emitter_batch_size"}]' >/dev/null 2>&1
                    ${CLI_CMD} patch icp4acluster $icp4acluster_cr_name -n $deployment_project_name --type=json -p='[{"op": "remove", "path": "/spec/workflow_authoring_configuration/case/event_emitter/process_pe_events"}]' >/dev/null 2>&1
                fi
            fi
        fi

        # convert event_emitter to list for workflow-runtime and workflow-worksteams
        if [[ (! " ${EXISTING_OPT_COMPONENT_ARR[@]} " =~ "baw_authoring") && (" ${EXISTING_PATTERN_ARR[@]} " =~ "workflow" || " ${EXISTING_PATTERN_ARR[@]} " =~ "workflow-workstreams") ]]; then
            # baw_instance_index=0
            if [[ $cr_version != "${CP4BA_RELEASE_BASE}" && ($cr_version == "21.0.3" || $cr_version == "22.0.2") ]]; then
                baw_instance_index=0
                while true; do
                    baw_instance_flag=`cat $UPGRADE_DEPLOYMENT_ICP4ACLUSTER_CR_TMP | ${YQ_CMD} r - spec.baw_configuration.[${baw_instance_index}].case.event_emitter`
                    if [[ ! -z "$baw_instance_flag" ]]; then
                        ## https://jsw.ibm.com/browse/DBACLD-154386
                        ## Referencing the object store name instead of datasource name                    
                        baw_event_emitter_tos_name=`cat $UPGRADE_DEPLOYMENT_ICP4ACLUSTER_CR_TMP | ${YQ_CMD} r - spec.baw_configuration.[${baw_instance_index}].case.object_store_name_tos`
                        baw_event_emitter_connection_point_name=`cat $UPGRADE_DEPLOYMENT_ICP4ACLUSTER_CR_TMP | ${YQ_CMD} r - spec.baw_configuration.[${baw_instance_index}].case.connection_point_name_tos`
                        baw_event_emitter_date_sql=`cat $UPGRADE_DEPLOYMENT_ICP4ACLUSTER_CR_TMP | ${YQ_CMD} r - spec.baw_configuration.[${baw_instance_index}].case.event_emitter.date_sql`
                        baw_event_emitter_logical_unique_id=`cat $UPGRADE_DEPLOYMENT_ICP4ACLUSTER_CR_TMP | ${YQ_CMD} r - spec.baw_configuration.[${baw_instance_index}].case.event_emitter.logical_unique_id`
                        baw_event_emitter_solution_list=`cat $UPGRADE_DEPLOYMENT_ICP4ACLUSTER_CR_TMP | ${YQ_CMD} r - spec.baw_configuration.[${baw_instance_index}].case.event_emitter.solution_list`
                        baw_event_emitter_casetype_list=`cat $UPGRADE_DEPLOYMENT_ICP4ACLUSTER_CR_TMP | ${YQ_CMD} r - spec.baw_configuration.[${baw_instance_index}].case.event_emitter.casetype_list`
                        baw_event_emitter_emitter_batch_size=`cat $UPGRADE_DEPLOYMENT_ICP4ACLUSTER_CR_TMP | ${YQ_CMD} r - spec.baw_configuration.[${baw_instance_index}].case.event_emitter.emitter_batch_size`
                        baw_event_emitter_process_pe_events=`cat $UPGRADE_DEPLOYMENT_ICP4ACLUSTER_CR_TMP | ${YQ_CMD} r - spec.baw_configuration.[${baw_instance_index}].case.event_emitter.process_pe_events`

                        ${YQ_CMD} w -i ${UPGRADE_DEPLOYMENT_ICP4ACLUSTER_CR_TMP} spec.baw_configuration.[${baw_instance_index}].case.event_emitter.[0].tos_name "$baw_event_emitter_tos_name"
                        ${YQ_CMD} w -i ${UPGRADE_DEPLOYMENT_ICP4ACLUSTER_CR_TMP} spec.baw_configuration.[${baw_instance_index}].case.event_emitter.[0].connection_point_name "$baw_event_emitter_connection_point_name"
                        ${YQ_CMD} w -i ${UPGRADE_DEPLOYMENT_ICP4ACLUSTER_CR_TMP} spec.baw_configuration.[${baw_instance_index}].case.event_emitter.[0].date_sql "$baw_event_emitter_date_sql"
                        ${YQ_CMD} w -i ${UPGRADE_DEPLOYMENT_ICP4ACLUSTER_CR_TMP} spec.baw_configuration.[${baw_instance_index}].case.event_emitter.[0].logical_unique_id "$baw_event_emitter_logical_unique_id"
                        ${YQ_CMD} w -i ${UPGRADE_DEPLOYMENT_ICP4ACLUSTER_CR_TMP} spec.baw_configuration.[${baw_instance_index}].case.event_emitter.[0].solution_list "$baw_event_emitter_solution_list"
                        ${YQ_CMD} w -i ${UPGRADE_DEPLOYMENT_ICP4ACLUSTER_CR_TMP} spec.baw_configuration.[${baw_instance_index}].case.event_emitter.[0].casetype_list "$baw_event_emitter_casetype_list"
                        ${YQ_CMD} w -i ${UPGRADE_DEPLOYMENT_ICP4ACLUSTER_CR_TMP} spec.baw_configuration.[${baw_instance_index}].case.event_emitter.[0].emitter_batch_size "$baw_event_emitter_emitter_batch_size"
                        ${YQ_CMD} w -i ${UPGRADE_DEPLOYMENT_ICP4ACLUSTER_CR_TMP} spec.baw_configuration.[${baw_instance_index}].case.event_emitter.[0].process_pe_events "$baw_event_emitter_process_pe_events"

                        ${CLI_CMD} patch icp4acluster $icp4acluster_cr_name -n $deployment_project_name --type=json -p="[{\"op\": \"remove\", \"path\": \"/spec/baw_configuration/${baw_instance_index}/case/event_emitter/tos_name\"}]" >/dev/null 2>&1
                        ${CLI_CMD} patch icp4acluster $icp4acluster_cr_name -n $deployment_project_name --type=json -p="[{\"op\": \"remove\", \"path\": \"/spec/baw_configuration/${baw_instance_index}/case/event_emitter/connection_point_name\"}]" >/dev/null 2>&1
                        ${CLI_CMD} patch icp4acluster $icp4acluster_cr_name -n $deployment_project_name --type=json -p="[{\"op\": \"remove\", \"path\": \"/spec/baw_configuration/${baw_instance_index}/case/event_emitter/date_sql\"}]" >/dev/null 2>&1
                        ${CLI_CMD} patch icp4acluster $icp4acluster_cr_name -n $deployment_project_name --type=json -p="[{\"op\": \"remove\", \"path\": \"/spec/baw_configuration/${baw_instance_index}/case/event_emitter/logical_unique_id\"}]" >/dev/null 2>&1
                        ${CLI_CMD} patch icp4acluster $icp4acluster_cr_name -n $deployment_project_name --type=json -p="[{\"op\": \"remove\", \"path\": \"/spec/baw_configuration/${baw_instance_index}/case/event_emitter/solution_list\"}]" >/dev/null 2>&1
                        ${CLI_CMD} patch icp4acluster $icp4acluster_cr_name -n $deployment_project_name --type=json -p="[{\"op\": \"remove\", \"path\": \"/spec/baw_configuration/${baw_instance_index}/case/event_emitter/casetype_list\"}]" >/dev/null 2>&1
                        ${CLI_CMD} patch icp4acluster $icp4acluster_cr_name -n $deployment_project_name --type=json -p="[{\"op\": \"remove\", \"path\": \"/spec/baw_configuration/${baw_instance_index}/case/event_emitter/emitter_batch_size\"}]" >/dev/null 2>&1
                        ${CLI_CMD} patch icp4acluster $icp4acluster_cr_name -n $deployment_project_name --type=json -p="[{\"op\": \"remove\", \"path\": \"/spec/baw_configuration/${baw_instance_index}/case/event_emitter/process_pe_events\"}]" >/dev/null 2>&1
                        ((baw_instance_index++))
                    else
                        break
                    fi
                done
            fi
        fi

        # for BAW authoring, set workflow_authoring_configuration.case.tos_list
        # Support multiple tos instance from $CP4BA_RELEASE_BASE
        if [[ $cr_version != "${CP4BA_RELEASE_BASE}" && ($cr_version == "21.0.3" || $cr_version == "22.0.2") ]]; then
            if [[ " ${EXISTING_OPT_COMPONENT_ARR[@]} " =~ "baw_authoring" ]]; then
                baw_instance_flag=`cat $UPGRADE_DEPLOYMENT_ICP4ACLUSTER_CR_TMP | ${YQ_CMD} r - spec.workflow_authoring_configuration.case`
                if [[ ! -z "$baw_instance_flag" ]]; then
                    baw_object_store_name_tos=`cat $UPGRADE_DEPLOYMENT_ICP4ACLUSTER_CR_TMP | ${YQ_CMD} r - spec.workflow_authoring_configuration.case.object_store_name_tos`
                    baw_connection_point_name_tos=`cat $UPGRADE_DEPLOYMENT_ICP4ACLUSTER_CR_TMP | ${YQ_CMD} r - spec.workflow_authoring_configuration.case.connection_point_name_tos`
                    baw_target_environment_name=`cat $UPGRADE_DEPLOYMENT_ICP4ACLUSTER_CR_TMP | ${YQ_CMD} r - spec.workflow_authoring_configuration.case.target_environment_name`
                    baw_desktop_name=`cat $UPGRADE_DEPLOYMENT_ICP4ACLUSTER_CR_TMP | ${YQ_CMD} r - spec.workflow_authoring_configuration.case.desktop_name`

                    if [[ (-z $baw_connection_point_name_tos || -z $baw_object_store_name_tos) && (-z $init_section) ]]; then
                        warning "Not found both workflow_authoring_configuration.case.connection_point_name_tos/object_store_name_tos and oc_cpe_obj_store_workflow_pe_conn_point_name under initialize_configuration, refer KC https://www.ibm.com/docs/en/cloud-paks/cp-biz-automation/$CP4BA_RELEASE_BASE?topic=deployment-upgrading-business-automation-workflow-authoring"
                    fi
                    if [[ ! -z "$baw_object_store_name_tos" ]]; then
                        ${YQ_CMD} w -i ${UPGRADE_DEPLOYMENT_ICP4ACLUSTER_CR_TMP} spec.workflow_authoring_configuration.case.tos_list.[0].object_store_name "$baw_object_store_name_tos"

                        if [[ ! -z $baw_connection_point_name_tos ]]; then
                            ${YQ_CMD} w -i ${UPGRADE_DEPLOYMENT_ICP4ACLUSTER_CR_TMP} spec.workflow_authoring_configuration.case.tos_list.[0].connection_point_name "$baw_connection_point_name_tos"
                        fi

                        ${YQ_CMD} d -i ${UPGRADE_DEPLOYMENT_ICP4ACLUSTER_CR_TMP} spec.workflow_authoring_configuration.case.object_store_name_tos
                        ${YQ_CMD} d -i ${UPGRADE_DEPLOYMENT_ICP4ACLUSTER_CR_TMP} spec.workflow_authoring_configuration.case.connection_point_name_tos
                        ${YQ_CMD} d -i ${UPGRADE_DEPLOYMENT_ICP4ACLUSTER_CR_TMP} spec.workflow_authoring_configuration.case.datasource_name_tos

                        if [[ -z $baw_target_environment_name ]]; then
                            ${YQ_CMD} w -i ${UPGRADE_DEPLOYMENT_ICP4ACLUSTER_CR_TMP} spec.workflow_authoring_configuration.case.tos_list.[0].target_environment_name "dev_env_connection_definition"
                        else
                            ${YQ_CMD} w -i ${UPGRADE_DEPLOYMENT_ICP4ACLUSTER_CR_TMP} spec.workflow_authoring_configuration.case.tos_list.[0].target_environment_name "$baw_target_environment_name"
                        fi
                        ${YQ_CMD} d -i ${UPGRADE_DEPLOYMENT_ICP4ACLUSTER_CR_TMP} spec.workflow_authoring_configuration.case.target_environment_name

                        if [[ -z $baw_desktop_name ]]; then
                            ${YQ_CMD} w -i ${UPGRADE_DEPLOYMENT_ICP4ACLUSTER_CR_TMP} spec.workflow_authoring_configuration.case.tos_list.[0].desktop_id "baw"
                        else
                            ${YQ_CMD} w -i ${UPGRADE_DEPLOYMENT_ICP4ACLUSTER_CR_TMP} spec.workflow_authoring_configuration.case.tos_list.[0].desktop_id "$baw_desktop_name"
                        fi
                        ${YQ_CMD} d -i ${UPGRADE_DEPLOYMENT_ICP4ACLUSTER_CR_TMP} spec.workflow_authoring_configuration.case.desktop_name
                    fi
                    # Delete datasource_name_tos/object_store_name_tos and so on from existing CR
                    ${CLI_CMD} patch icp4acluster $icp4acluster_cr_name -n $deployment_project_name --type=json -p='[{"op": "remove", "path": "/spec/workflow_authoring_configuration/case/object_store_name_tos"}]' >/dev/null 2>&1
                    ${CLI_CMD} patch icp4acluster $icp4acluster_cr_name -n $deployment_project_name --type=json -p='[{"op": "remove", "path": "/spec/workflow_authoring_configuration/case/connection_point_name_tos"}]' >/dev/null 2>&1
                    ${CLI_CMD} patch icp4acluster $icp4acluster_cr_name -n $deployment_project_name --type=json -p='[{"op": "remove", "path": "/spec/workflow_authoring_configuration/case/datasource_name_tos"}]' >/dev/null 2>&1
                    ${CLI_CMD} patch icp4acluster $icp4acluster_cr_name -n $deployment_project_name --type=json -p='[{"op": "remove", "path": "/spec/workflow_authoring_configuration/case/target_environment_name"}]' >/dev/null 2>&1
                    ${CLI_CMD} patch icp4acluster $icp4acluster_cr_name -n $deployment_project_name --type=json -p='[{"op": "remove", "path": "/spec/workflow_authoring_configuration/case/desktop_name"}]' >/dev/null 2>&1
                fi
            fi
        fi

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
                    baw_instance_flag=`cat $UPGRADE_DEPLOYMENT_ICP4ACLUSTER_CR_TMP | ${YQ_CMD} r - spec.workflow_authoring_configuration.case`
                    if [[ ! -z "$baw_instance_flag" ]]; then
                        baw_object_store_name_tos=`cat $UPGRADE_DEPLOYMENT_ICP4ACLUSTER_CR_TMP | ${YQ_CMD} r - spec.workflow_authoring_configuration.case.tos_list.[${tos_instance_index}].object_store_name`
                        baw_connection_point_name_tos=`cat $UPGRADE_DEPLOYMENT_ICP4ACLUSTER_CR_TMP | ${YQ_CMD} r - spec.workflow_authoring_configuration.case.tos_list.[${tos_instance_index}].connection_point_name`
                        baw_target_environment_name=`cat $UPGRADE_DEPLOYMENT_ICP4ACLUSTER_CR_TMP | ${YQ_CMD} r - spec.workflow_authoring_configuration.case.tos_list.[${tos_instance_index}].target_environment_name`
                        desktop_id=`cat $UPGRADE_DEPLOYMENT_ICP4ACLUSTER_CR_TMP | ${YQ_CMD} r - spec.workflow_authoring_configuration.case.tos_list.[${tos_instance_index}].desktop_id`
                        if [[ (! -z "$baw_object_store_name_tos") && -z "$baw_connection_point_name_tos" ]]; then
                            init_section=`cat $UPGRADE_DEPLOYMENT_ICP4ACLUSTER_CR_TMP | ${YQ_CMD} r - spec.initialize_configuration`
                            if [[ -z "$init_section" ]]; then
                                info "Not found initialize_configuration, continue..."
                            else
                                os_index=0
                                while true; do
                                    os_flag=`cat $UPGRADE_DEPLOYMENT_ICP4ACLUSTER_CR_TMP | ${YQ_CMD} r - spec.initialize_configuration.ic_obj_store_creation.object_stores.[${os_index}].oc_cpe_obj_store_symb_name`
                                    if [[ ! -z "$os_flag" ]]; then
                                        enable_workflow=`cat $UPGRADE_DEPLOYMENT_ICP4ACLUSTER_CR_TMP | ${YQ_CMD} r - spec.initialize_configuration.ic_obj_store_creation.object_stores.[${os_index}].oc_cpe_obj_store_enable_workflow`
                                        if [[ "$enable_workflow" == "true" ]]; then
                                            tos_datasource_name=`cat $UPGRADE_DEPLOYMENT_ICP4ACLUSTER_CR_TMP | ${YQ_CMD} r - spec.initialize_configuration.ic_obj_store_creation.object_stores.[${os_index}].oc_cpe_obj_store_conn.dc_os_datasource_name`
                                            tos_connection=`cat $UPGRADE_DEPLOYMENT_ICP4ACLUSTER_CR_TMP | ${YQ_CMD} r - spec.initialize_configuration.ic_obj_store_creation.object_stores.[${os_index}].oc_cpe_obj_store_workflow_pe_conn_point_name`
                                            if [[ $baw_object_store_name_tos == $tos_datasource_name ]]; then
                                                if [[ ! -z "$tos_datasource_name" ]]; then
                                                    ${YQ_CMD} w -i ${UPGRADE_DEPLOYMENT_ICP4ACLUSTER_CR_TMP} spec.workflow_authoring_configuration.case.tos_list.[${tos_instance_index}].object_store_name "$tos_datasource_name"
                                                fi
                                                if [[ ! -z "$tos_connection" ]]; then
                                                    ${YQ_CMD} w -i ${UPGRADE_DEPLOYMENT_ICP4ACLUSTER_CR_TMP} spec.workflow_authoring_configuration.case.tos_list.[${tos_instance_index}].connection_point_name "$tos_connection"
                                                fi
                                                # if [[ -z "$baw_target_environment_name" ]]; then
                                                #     tmp_val_ds_name=$(echo $tos_datasource_name | tr '[:upper:]' '[:lower:]')
                                                #     ${YQ_CMD} w -i ${UPGRADE_DEPLOYMENT_ICP4ACLUSTER_CR_TMP} spec.workflow_authoring_configuration.case.tos_list.[${tos_instance_index}].target_environment_name "$tmp_val_ds_name"
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

        # for BAW Runtime, set baw_configuration.case.tos_list
        # Support multiple tos instance from $CP4BA_RELEASE_BASE
        if [[ $cr_version != "${CP4BA_RELEASE_BASE}" && ($cr_version == "21.0.3" || $cr_version == "22.0.2") ]]; then
            if [[ (! " ${EXISTING_OPT_COMPONENT_ARR[@]} " =~ "baw_authoring") && (" ${EXISTING_PATTERN_ARR[@]} " =~ "workflow" || " ${EXISTING_PATTERN_ARR[@]} " =~ "workflow-workstreams") ]]; then
                # Support multiple tos instance from $CP4BA_RELEASE_BASE
                baw_instance_index=0
                while true; do
                    baw_instance_flag=`cat $UPGRADE_DEPLOYMENT_ICP4ACLUSTER_CR_TMP | ${YQ_CMD} r - spec.baw_configuration.[${baw_instance_index}].case`
                    if [[ ! -z "$baw_instance_flag" ]]; then
                        baw_object_store_name_tos=`cat $UPGRADE_DEPLOYMENT_ICP4ACLUSTER_CR_TMP | ${YQ_CMD} r - spec.baw_configuration.[${baw_instance_index}].case.object_store_name_tos`
                        baw_connection_point_name_tos=`cat $UPGRADE_DEPLOYMENT_ICP4ACLUSTER_CR_TMP | ${YQ_CMD} r - spec.baw_configuration.[${baw_instance_index}].case.connection_point_name_tos`
                        baw_target_environment_name=`cat $UPGRADE_DEPLOYMENT_ICP4ACLUSTER_CR_TMP | ${YQ_CMD} r - spec.baw_configuration.[${baw_instance_index}].case.target_environment_name`
                        baw_desktop_name=`cat $UPGRADE_DEPLOYMENT_ICP4ACLUSTER_CR_TMP | ${YQ_CMD} r - spec.baw_configuration.[${baw_instance_index}].case.desktop_name`
                        if [[ (-z $baw_connection_point_name_tos || -z $baw_object_store_name_tos) && (-z $init_section) ]]; then
                            warning "Not found both baw_configuration.[${baw_instance_index}].case.connection_point_name_tos/object_store_name_tos and oc_cpe_obj_store_workflow_pe_conn_point_name under initialize_configuration, refer KC https://www.ibm.com/docs/en/cloud-paks/cp-biz-automation/$CP4BA_RELEASE_BASE?topic=deployment-upgrading-business-automation-workflow-runtime"
                        fi
                        if [[ ! -z "$baw_object_store_name_tos" ]]; then
                            ${YQ_CMD} w -i ${UPGRADE_DEPLOYMENT_ICP4ACLUSTER_CR_TMP} spec.baw_configuration.[${baw_instance_index}].case.tos_list.[0].object_store_name "$baw_object_store_name_tos"

                            if [[ ! -z $baw_connection_point_name_tos ]]; then
                                ${YQ_CMD} w -i ${UPGRADE_DEPLOYMENT_ICP4ACLUSTER_CR_TMP} spec.baw_configuration.[${baw_instance_index}].case.tos_list.[0].connection_point_name "$baw_connection_point_name_tos"
                            fi

                            ${YQ_CMD} d -i ${UPGRADE_DEPLOYMENT_ICP4ACLUSTER_CR_TMP} spec.baw_configuration.[${baw_instance_index}].case.object_store_name_tos
                            ${YQ_CMD} d -i ${UPGRADE_DEPLOYMENT_ICP4ACLUSTER_CR_TMP} spec.baw_configuration.[${baw_instance_index}].case.connection_point_name_tos
                            ${YQ_CMD} d -i ${UPGRADE_DEPLOYMENT_ICP4ACLUSTER_CR_TMP} spec.baw_configuration.[${baw_instance_index}].case.datasource_name_tos

                            if [[ -z $baw_target_environment_name ]]; then
                                ${YQ_CMD} w -i ${UPGRADE_DEPLOYMENT_ICP4ACLUSTER_CR_TMP} spec.baw_configuration.[${baw_instance_index}].case.tos_list.[0].target_environment_name "target_env"
                            else
                                ${YQ_CMD} w -i ${UPGRADE_DEPLOYMENT_ICP4ACLUSTER_CR_TMP} spec.baw_configuration.[${baw_instance_index}].case.tos_list.[0].target_environment_name "$baw_target_environment_name"
                            fi
                            ${YQ_CMD} d -i ${UPGRADE_DEPLOYMENT_ICP4ACLUSTER_CR_TMP} spec.baw_configuration.[${baw_instance_index}].case.target_environment_name

                            if [[ -z $baw_desktop_name ]]; then
                                ${YQ_CMD} w -i ${UPGRADE_DEPLOYMENT_ICP4ACLUSTER_CR_TMP} spec.baw_configuration.[${baw_instance_index}].case.tos_list.[0].desktop_id "baw"
                            else
                                ${YQ_CMD} w -i ${UPGRADE_DEPLOYMENT_ICP4ACLUSTER_CR_TMP} spec.baw_configuration.[${baw_instance_index}].case.tos_list.[0].desktop_id "$baw_desktop_name"
                            fi
                            ${YQ_CMD} d -i ${UPGRADE_DEPLOYMENT_ICP4ACLUSTER_CR_TMP} spec.baw_configuration.[${baw_instance_index}].case.desktop_name
                        fi
                        ((baw_instance_index++))
                    else
                        break
                    fi
                done
                # Delete datasource_name_tos/object_store_name_tos and so on from existing CR
                baw_instance_index=0
                while true; do
                    baw_instance_flag=`cat $UPGRADE_DEPLOYMENT_ICP4ACLUSTER_CR_TMP | ${YQ_CMD} r - spec.baw_configuration.[${baw_instance_index}].case`
                    if [[ ! -z "$baw_instance_flag" ]]; then
                        ${CLI_CMD} patch icp4acluster $icp4acluster_cr_name -n $deployment_project_name --type=json -p="[{\"op\": \"remove\", \"path\": \"/spec/baw_configuration/${baw_instance_index}/case/object_store_name_tos\"}]" >/dev/null 2>&1
                        ${CLI_CMD} patch icp4acluster $icp4acluster_cr_name -n $deployment_project_name --type=json -p="[{\"op\": \"remove\", \"path\": \"/spec/baw_configuration/${baw_instance_index}/case/connection_point_name_tos\"}]" >/dev/null 2>&1
                        ${CLI_CMD} patch icp4acluster $icp4acluster_cr_name -n $deployment_project_name --type=json -p="[{\"op\": \"remove\", \"path\": \"/spec/baw_configuration/${baw_instance_index}/case/datasource_name_tos\"}]" >/dev/null 2>&1
                        ${CLI_CMD} patch icp4acluster $icp4acluster_cr_name -n $deployment_project_name --type=json -p="[{\"op\": \"remove\", \"path\": \"/spec/baw_configuration/${baw_instance_index}/case/target_environment_name\"}]" >/dev/null 2>&1
                        ${CLI_CMD} patch icp4acluster $icp4acluster_cr_name -n $deployment_project_name --type=json -p="[{\"op\": \"remove\", \"path\": \"/spec/baw_configuration/${baw_instance_index}/case/desktop_name\"}]" >/dev/null 2>&1
                        ((baw_instance_index++))
                    else
                        break
                    fi
                done

                # Direct upgrade from 21.0.3/22.0.2, remove pfs_bpd_database_init_job/ibm_workplace_job/pfs_configuration
                baw_instance_index=0
                while true; do
                    baw_instance_flag=`cat $UPGRADE_DEPLOYMENT_ICP4ACLUSTER_CR_TMP | ${YQ_CMD} r - spec.baw_configuration.[${baw_instance_index}]`
                    if [[ ! -z "$baw_instance_flag" ]]; then
                        ((baw_instance_index++))
                    else
                        break
                    fi
                done

                for ((num=0;num<${baw_instance_index};num++)); do
                    # ${YQ_CMD} d -i ${UPGRADE_DEPLOYMENT_ICP4ACLUSTER_CR_TMP} spec.baw_configuration.[${num}].host_federated_portal
                    ${YQ_CMD} d -i ${UPGRADE_DEPLOYMENT_ICP4ACLUSTER_CR_TMP} spec.baw_configuration.[${num}].pfs_bpd_database_init_job
                    ${YQ_CMD} d -i ${UPGRADE_DEPLOYMENT_ICP4ACLUSTER_CR_TMP} spec.baw_configuration.[${num}].ibm_workplace_job

                    # ${CLI_CMD} patch icp4acluster $icp4acluster_cr_name -n $deployment_project_name --type=json -p="[{\"op\": \"remove\", \"path\": \"/spec/baw_configuration/${num}/host_federated_portal\"}]" >/dev/null 2>&1
                    ${CLI_CMD} patch icp4acluster $icp4acluster_cr_name -n $deployment_project_name --type=json -p="[{\"op\": \"remove\", \"path\": \"/spec/baw_configuration/${num}/pfs_bpd_database_init_job\"}]" >/dev/null 2>&1
                    ${CLI_CMD} patch icp4acluster $icp4acluster_cr_name -n $deployment_project_name --type=json -p="[{\"op\": \"remove\", \"path\": \"/spec/baw_configuration/${num}/ibm_workplace_job\"}]" >/dev/null 2>&1
                done

                ${YQ_CMD} d -i ${UPGRADE_DEPLOYMENT_ICP4ACLUSTER_CR_TMP} spec.pfs_configuration
                ${CLI_CMD} patch icp4acluster $icp4acluster_cr_name -n $deployment_project_name --type=json -p='[{"op": "remove", "path": "/spec/pfs_configuration"}]' >/dev/null 2>&1
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
                    baw_instance_flag=`cat $UPGRADE_DEPLOYMENT_ICP4ACLUSTER_CR_TMP | ${YQ_CMD} r - spec.baw_configuration.[${baw_instance_index}].case`
                    if [[ ! -z "$baw_instance_flag" ]]; then
                        # Support multiple tos instance from $CP4BA_RELEASE_BASE
                        tos_instance_index=0
                        while true; do
                            baw_instance_flag=`cat $UPGRADE_DEPLOYMENT_ICP4ACLUSTER_CR_TMP | ${YQ_CMD} r - spec.baw_configuration.[${baw_instance_index}].case`
                            if [[ ! -z "$baw_instance_flag" ]]; then
                                baw_object_store_name_tos=`cat $UPGRADE_DEPLOYMENT_ICP4ACLUSTER_CR_TMP | ${YQ_CMD} r - spec.baw_configuration.[${baw_instance_index}].case.tos_list.[${tos_instance_index}].object_store_name`
                                baw_connection_point_name_tos=`cat $UPGRADE_DEPLOYMENT_ICP4ACLUSTER_CR_TMP | ${YQ_CMD} r - spec.baw_configuration.[${baw_instance_index}].case.tos_list.[${tos_instance_index}].connection_point_name`
                                baw_target_environment_name=`cat $UPGRADE_DEPLOYMENT_ICP4ACLUSTER_CR_TMP | ${YQ_CMD} r - spec.baw_configuration.[${baw_instance_index}].case.tos_list.[${tos_instance_index}].target_environment_name`
                                desktop_id=`cat $UPGRADE_DEPLOYMENT_ICP4ACLUSTER_CR_TMP | ${YQ_CMD} r - spec.baw_configuration.[${baw_instance_index}].case.tos_list.[${tos_instance_index}].desktop_id`
                                if [[ (! -z "$baw_object_store_name_tos") && -z "$baw_connection_point_name_tos" ]]; then
                                    init_section=`cat $UPGRADE_DEPLOYMENT_ICP4ACLUSTER_CR_TMP | ${YQ_CMD} r - spec.initialize_configuration`
                                    if [[ -z "$init_section" ]]; then
                                        info "Not found initialize_configuration, continue..."
                                    else
                                        os_index=0
                                        while true; do
                                            os_flag=`cat $UPGRADE_DEPLOYMENT_ICP4ACLUSTER_CR_TMP | ${YQ_CMD} r - spec.initialize_configuration.ic_obj_store_creation.object_stores.[${os_index}].oc_cpe_obj_store_symb_name`
                                            if [[ ! -z "$os_flag" ]]; then
                                                enable_workflow=`cat $UPGRADE_DEPLOYMENT_ICP4ACLUSTER_CR_TMP | ${YQ_CMD} r - spec.initialize_configuration.ic_obj_store_creation.object_stores.[${os_index}].oc_cpe_obj_store_enable_workflow`
                                                if [[ "$enable_workflow" == "true" ]]; then
                                                    tos_datasource_name=`cat $UPGRADE_DEPLOYMENT_ICP4ACLUSTER_CR_TMP | ${YQ_CMD} r - spec.initialize_configuration.ic_obj_store_creation.object_stores.[${os_index}].oc_cpe_obj_store_conn.dc_os_datasource_name`
                                                    tos_connection=`cat $UPGRADE_DEPLOYMENT_ICP4ACLUSTER_CR_TMP | ${YQ_CMD} r - spec.initialize_configuration.ic_obj_store_creation.object_stores.[${os_index}].oc_cpe_obj_store_workflow_pe_conn_point_name`
                                                    if [[ $baw_object_store_name_tos == $tos_datasource_name ]]; then
                                                        if [[ ! -z "$tos_datasource_name" ]]; then
                                                            ${YQ_CMD} w -i ${UPGRADE_DEPLOYMENT_ICP4ACLUSTER_CR_TMP} spec.baw_configuration.[${baw_instance_index}].case.tos_list.[${tos_instance_index}].object_store_name "$tos_datasource_name"
                                                        fi
                                                        if [[ ! -z "$tos_connection" ]]; then
                                                            ${YQ_CMD} w -i ${UPGRADE_DEPLOYMENT_ICP4ACLUSTER_CR_TMP} spec.baw_configuration.[${baw_instance_index}].case.tos_list.[${tos_instance_index}].connection_point_name "$tos_connection"
                                                        fi
                                                        # if [[ -z "$baw_target_environment_name" ]]; then
                                                        #     tmp_val_ds_name=$(echo $tos_datasource_name | tr '[:upper:]' '[:lower:]')
                                                        #     ${YQ_CMD} w -i ${UPGRADE_DEPLOYMENT_ICP4ACLUSTER_CR_TMP} spec.baw_configuration.[${baw_instance_index}].case.tos_list.[${tos_instance_index}].target_environment_name "$tmp_val_ds_name"
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

        # if the baw runtim pattern selected
        # For 21.0.3/22.0.2 upgrade, the opensearch should add into sc_optional_components,
        # for 23.0.2 upgrade, if elasticsearch existing in sc_optional_components, then add opensearch in sc_optional_components.
        if [[ (! " ${EXISTING_OPT_COMPONENT_ARR[@]} " =~ "baw_authoring") && (" ${EXISTING_PATTERN_ARR[@]} " =~ "workflow" || " ${EXISTING_PATTERN_ARR[@]} " =~ "workflow-workstreams") ]]; then
            if [[ $cr_version != "${CP4BA_RELEASE_BASE}" && $cr_version == "23.0.2" ]]; then
                if [[ " ${EXISTING_OPT_COMPONENT_ARR[@]}" =~ "elasticsearch" ]]; then
                    EXISTING_OPT_COMPONENT_ARR=( "${EXISTING_OPT_COMPONENT_ARR[@]}" "opensearch" )

                    # remove elasticsearch from sc_optional_components
                    TEMP_ARRAY=()
                    for item in "${EXISTING_OPT_COMPONENT_ARR[@]}"; do
                        if [[ "$item" != "elasticsearch" ]]; then
                            TEMP_ARRAY+=("$item")
                        fi
                    done
                    EXISTING_OPT_COMPONENT_ARR=("${TEMP_ARRAY[@]}")
                fi
            fi

            if [[ $cr_version != "${CP4BA_RELEASE_BASE}" && ($cr_version == "21.0.3" || $cr_version == "22.0.2") ]]; then
                EXISTING_OPT_COMPONENT_ARR=( "${EXISTING_OPT_COMPONENT_ARR[@]}" "opensearch" )

                # remove elasticsearch from sc_optional_components
                TEMP_ARRAY=()
                for item in "${EXISTING_OPT_COMPONENT_ARR[@]}"; do
                    if [[ "$item" != "elasticsearch" ]]; then
                        TEMP_ARRAY+=("$item")
                    fi
                done
                EXISTING_OPT_COMPONENT_ARR=("${TEMP_ARRAY[@]}")
            fi
        fi

        if [[ (" ${EXISTING_PATTERN_ARR[@]} " =~ "content") || (" ${EXISTING_PATTERN_ARR[@]} " =~ "workflow") || (" ${EXISTING_PATTERN_ARR[@]} " =~ "document_processing") || (" ${EXISTING_OPT_COMPONENT_ARR[@]} " =~ "baw_authoring") || (" ${EXISTING_OPT_COMPONENT_ARR[@]} " =~ "ae_data_persistence") ]]; then
            if [[ $olm_cr_flag == "No" ]]; then
            # Disable sc_content_initialization/sc_content_verification, to ensure these configurations are disabled if OLM is not managing the deployment
                ${YQ_CMD} w -i ${UPGRADE_DEPLOYMENT_ICP4ACLUSTER_CR_TMP} spec.shared_configuration.sc_content_initialization "false"
                ${YQ_CMD} w -i ${UPGRADE_DEPLOYMENT_ICP4ACLUSTER_CR_TMP} spec.shared_configuration.sc_content_verification "false"
            else
                ${YQ_CMD} w -i ${UPGRADE_DEPLOYMENT_ICP4ACLUSTER_CR_TMP} spec.shared_configuration.olm_sc_content_initialization "false"
                ${YQ_CMD} w -i ${UPGRADE_DEPLOYMENT_ICP4ACLUSTER_CR_TMP} spec.shared_configuration.olm_sc_content_verification "false"
            fi
            ${YQ_CMD} d -i ${UPGRADE_DEPLOYMENT_ICP4ACLUSTER_CR_TMP} spec.shared_configuration.sc_content_initialization_update_scim

            # remove initialize_configuration/verify_configuration
            info "Remove initialize_configuration/verify_configuration from new version of CP4BA Custom Resource"
            ${YQ_CMD} d -i ${UPGRADE_DEPLOYMENT_ICP4ACLUSTER_CR_TMP} spec.verify_configuration
            ${YQ_CMD} d -i ${UPGRADE_DEPLOYMENT_ICP4ACLUSTER_CR_TMP} spec.initialize_configuration
            # ${YQ_CMD} w -i ${UPGRADE_DEPLOYMENT_ICP4ACLUSTER_CR_TMP} spec.verify_configuration
            # ${YQ_CMD} w -i ${UPGRADE_DEPLOYMENT_ICP4ACLUSTER_CR_TMP} spec.initialize_configuration

            if [[ " ${EXISTING_OPT_COMPONENT_ARR[@]} " =~ "css" ]]; then
                # scale down FNCM Deployment
                info "Scaling down CSS deployment"
                css_instance_number=0
                css_instance_index=1
                while true; do
                    ${CLI_CMD} get deployment ${cr_metaname}-css-deploy-${css_instance_index} >/dev/null 2>&1
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
                        ${CLI_CMD} scale --replicas=0 deployment ${cr_metaname}-css-deploy-${j} -n $deployment_project_name >/dev/null 2>&1
                    done
                fi
                echo "Done!"
            fi

            info "Scaling down CPE deployment"
            ${CLI_CMD} scale --replicas=0 deployment ${cr_metaname}-cpe-deploy -n $deployment_project_name >/dev/null 2>&1
            echo "Done!"
            # To allow any changes to creation of the zen extension configuration that we make from IFIX to IFIX,its best if the watcher pods are scaled down prior to applying the new CR
            # DBACLD-171900
            info "Scaling down CPE Watcher deployment"
            ${CLI_CMD} scale --replicas=0 deployment ${cr_metaname}-cpe-watcher -n $deployment_project_name >/dev/null 2>&1
            echo "Done!"
            info "Scaling down Navigator deployment"
            ${CLI_CMD} scale --replicas=0 deployment ${cr_metaname}-navigator-deploy -n $deployment_project_name >/dev/null 2>&1
            echo "Done!"
            # To allow any changes to creation of the zen extension configuration that we make from IFIX to IFIX,its best if the watcher pods are scaled down prior to applying the new CR
            # DBACLD-171900
            info "Scaling down Navigator Watcher deployment"
            ${CLI_CMD} scale --replicas=0 deployment ${cr_metaname}-navigator-watcher -n $deployment_project_name >/dev/null 2>&1
            echo "Done!"
        fi

        if [[ "$allow_direct_upgrade" == 1 ]]; then
            # Only always set as false when upgrade from 21.0.3/22.0.2
            if [[ $cr_version != "${CP4BA_RELEASE_BASE}" && $cr_version != "23.0.2" ]]; then
                # Set shared_configuration.enable_fips always "false" in upgrade
                info "${YELLOW_TEXT}Setting \"shared_configuration.enable_fips\" as \"false\" when upgrade CP4BA deployment, you could change it according to your requirements.${RESET_TEXT}"
                ${YQ_CMD} w -i ${UPGRADE_DEPLOYMENT_ICP4ACLUSTER_CR_TMP} spec.shared_configuration.enable_fips "false"
            fi
        fi

        # For jsw.ibm.com/browse/DBACLD-153103 where we need to update the datavolume section of the CR to be in the right format
        if [[ $cr_version != "${CP4BA_RELEASE_BASE}" && ($cr_version == "21.0.3") ]]; then
            #function to update datastore section to the current format if required
            process_datavolumes ${UPGRADE_DEPLOYMENT_ICP4ACLUSTER_CR_TMP} $deployment_project_name
        fi

        # Set host_federated_portal as false in upgrade if it exist
        if [[ $cr_version != "${CP4BA_RELEASE_BASE}" && ($cr_version == "21.0.3" || $cr_version == "22.0.2") ]]; then
            #check baw_authoring does not exist and the patterns 'workflow' or 'workflow-workstreams' are present
            if [[ (! " ${EXISTING_OPT_COMPONENT_ARR[@]} " =~ "baw_authoring") && (" ${EXISTING_PATTERN_ARR[@]} " =~ "workflow" || " ${EXISTING_PATTERN_ARR[@]} " =~ "workflow-workstreams") ]]; then
                baw_instance_index=0
                while true; do
                    # Get BAW instance configuration
                    baw_instance_flag=`cat $UPGRADE_DEPLOYMENT_ICP4ACLUSTER_CR_TMP | ${YQ_CMD} r - spec.baw_configuration.[${baw_instance_index}]`
                    if [[ ! -z "$baw_instance_flag" ]]; then

                        flag_host=`cat ${UPGRADE_DEPLOYMENT_ICP4ACLUSTER_CR_TMP} | ${YQ_CMD} r - spec.baw_configuration.[${baw_instance_index}].host_federated_portal`
                        if [[ ! -z $flag_host ]]; then
                        ${YQ_CMD} w -i ${UPGRADE_DEPLOYMENT_ICP4ACLUSTER_CR_TMP} spec.baw_configuration.[${baw_instance_index}].host_federated_portal  "false"
                        fi
                        ((baw_instance_index++))
                    else
                        #Exit if no more BAW instances are found
                        break
                    fi
                done
            fi
        fi

        # Convert pattern array to list by common, format required for the CR specification
        delim=""
        patterns_joined=""
        for item in "${EXISTING_PATTERN_ARR[@]}"; do
            patterns_joined="$patterns_joined$delim$item"
            delim=","
        done
        ${SED_COMMAND} "s|sc_deployment_patterns:.*|sc_deployment_patterns: \"$patterns_joined\"|g" ${UPGRADE_DEPLOYMENT_ICP4ACLUSTER_CR_TMP}

        # Convert optional components array to list by common
        delim=""
        opt_components_joined=""
        for item in "${EXISTING_OPT_COMPONENT_ARR[@]}"; do
            opt_components_joined="$opt_components_joined$delim$item"
            delim=","
        done

        # Set sc_optional_components='' when none optional component selected
        if [ "${#EXISTING_OPT_COMPONENT_ARR[@]}" -eq "0" ]; then
            ${SED_COMMAND} "s|sc_optional_components:.*|sc_optional_components: \"\"|g" ${UPGRADE_DEPLOYMENT_ICP4ACLUSTER_CR_TMP}
        else
            ${SED_COMMAND} "s|sc_optional_components:.*|sc_optional_components: \"$opt_components_joined\"|g" ${UPGRADE_DEPLOYMENT_ICP4ACLUSTER_CR_TMP}
        fi

        # Function that will retrieve the network policies created in 24.0.1 by the operators and remove the references and re-apply them 
        # For https://jsw.ibm.com/browse/DBACLD-167387
        update_network_policies $deployment_project_name "ICP4ACluster" ${UPGRADE_DEPLOYMENT_ICP4ACLUSTER_CR_TMP}

        # Function that retrieves the networktype and network cidr range
        # https://jsw.ibm.com/browse/DBACLD-173602
        retrieve_network_details "upgrade" $deployment_project_name

        ${SED_COMMAND} "s|'\"|\"|g" ${UPGRADE_DEPLOYMENT_ICP4ACLUSTER_CR_TMP}
        ${SED_COMMAND} "s|\"'|\"|g" ${UPGRADE_DEPLOYMENT_ICP4ACLUSTER_CR_TMP}

        # convert ssl enable true or false to meet CSV
        ${SED_COMMAND} "s/: \"True\"/: true/g" ${UPGRADE_DEPLOYMENT_ICP4ACLUSTER_CR_TMP}
        ${SED_COMMAND} "s/: \"False\"/: false/g" ${UPGRADE_DEPLOYMENT_ICP4ACLUSTER_CR_TMP}
        ${SED_COMMAND} "s/: \"true\"/: true/g" ${UPGRADE_DEPLOYMENT_ICP4ACLUSTER_CR_TMP}
        ${SED_COMMAND} "s/: \"false\"/: false/g" ${UPGRADE_DEPLOYMENT_ICP4ACLUSTER_CR_TMP}
        ${SED_COMMAND} "s/: \"Yes\"/: true/g" ${UPGRADE_DEPLOYMENT_ICP4ACLUSTER_CR_TMP}
        ${SED_COMMAND} "s/: \"yes\"/: true/g" ${UPGRADE_DEPLOYMENT_ICP4ACLUSTER_CR_TMP}
        ${SED_COMMAND} "s/: \"No\"/: false/g" ${UPGRADE_DEPLOYMENT_ICP4ACLUSTER_CR_TMP}
        ${SED_COMMAND} "s/: \"no\"/: false/g" ${UPGRADE_DEPLOYMENT_ICP4ACLUSTER_CR_TMP}

        #For DBACLD-159463 to make sure all jvm options defined and all custom annotations are strings
        add_quotes_to_values "${UPGRADE_DEPLOYMENT_ICP4ACLUSTER_CR_TMP}"

        # must use string type for nodelabel_value in ADP
        if [[ (" ${EXISTING_PATTERN_ARR[@]} " =~ "document_processing") ]]; then
            ${SED_COMMAND} 's/\(nodelabel_value: \)\([^"][^ ]*\)/\1"\2"/' ${UPGRADE_DEPLOYMENT_ICP4ACLUSTER_CR_TMP} >/dev/null 2>&1
        fi
        # Remove all null string
        ${SED_COMMAND} "s/: null/: /g" ${UPGRADE_DEPLOYMENT_ICP4ACLUSTER_CR_TMP}

        ${COPY_CMD} -rf ${UPGRADE_DEPLOYMENT_ICP4ACLUSTER_CR_TMP} ${UPGRADE_DEPLOYMENT_ICP4ACLUSTER_CR}
        success "Completed to merge existing CP4BA Custom Resource with new version ($CP4BA_RELEASE_BASE)"
        # info "Remove initialize_configuration/verify_configuration from CP4BA Custom Resource"
        # ${CLI_CMD} patch icp4acluster $icp4acluster_cr_name -n $deployment_project_name --type=json -p='[{"op": "remove", "path": "/spec/initialize_configuration"}]' >/dev/null 2>&1
        # ${CLI_CMD} patch icp4acluster $icp4acluster_cr_name -n $deployment_project_name --type=json -p='[{"op": "remove", "path": "/spec/verify_configuration"}]' >/dev/null 2>&1

        # if [[ ((" ${EXISTING_PATTERN_ARR[@]} " =~ "workflow") && (" ${EXISTING_OPT_COMPONENT_ARR[@]} " =~ "baw_authoring")) || (" ${EXISTING_PATTERN_ARR[@]} " =~ "workflow-process-service") ]]; then
        if [[ $allow_direct_upgrade == 1 ]]; then
            info "Remove pfs_configuration/pfs_bpd_database_init_job/elasticsearch_configuration from CP4BA Custom Resource"
            # if [[ ! (" ${EXISTING_OPT_COMPONENT_ARR[@]} " =~ "pfs") ]]; then
            #     EXISTING_OPT_COMPONENT_ARR=( "${EXISTING_OPT_COMPONENT_ARR[@]}" "pfs" )
            # fi
            # Workflow authoring/runtime and WfPS authoring use embedded PFS starting from $CP4BA_RELEASE_BASE
            ${CLI_CMD} patch icp4acluster $icp4acluster_cr_name -n $deployment_project_name --type=json -p='[{"op": "remove", "path": "/spec/pfs_configuration"}]' >/dev/null 2>&1
            ${CLI_CMD} patch icp4acluster $icp4acluster_cr_name -n $deployment_project_name --type=json -p='[{"op": "remove", "path": "/spec/elasticsearch_configuration"}]' >/dev/null 2>&1
            ${CLI_CMD} patch icp4acluster $icp4acluster_cr_name -n $deployment_project_name --type=json -p='[{"op": "remove", "path": "/spec/baw_configuration/0/pfs_bpd_database_init_job"}]' >/dev/null 2>&1
            ${CLI_CMD} patch icp4acluster $icp4acluster_cr_name -n $deployment_project_name --type=json -p='[{"op": "remove", "path": "/spec/workflow_authoring_configuration/pfs_bpd_database_init_job"}]' >/dev/null 2>&1
        fi

        #Comment out workflow_authoring_configuration.database
        if [[ (" ${EXISTING_PATTERN_ARR[@]} " =~ "workflow") || (" ${EXISTING_PATTERN_ARR[@]} " =~ "workflow-process-service") ]]; then
            ${YQ_CMD} d -i ${UPGRADE_DEPLOYMENT_ICP4ACLUSTER_CR_TMP} spec.workflow_authoring_configuration.database
            ${CLI_CMD} patch icp4acluster $icp4acluster_cr_name -n $deployment_project_name --type=json -p='[{"op": "remove", "path": "/spec/workflow_authoring_configuration/database"}]' >/dev/null 2>&1
        fi

        info "The new version ($CP4BA_RELEASE_BASE) of CP4BA Custom Resource is created ${UPGRADE_DEPLOYMENT_ICP4ACLUSTER_CR}"

        #Function to remove the image tags from the CR if present
        remove_image_tags $UPGRADE_DEPLOYMENT_ICP4ACLUSTER_CR_TMP
        ${COPY_CMD} -rf ${UPGRADE_DEPLOYMENT_ICP4ACLUSTER_CR_TMP} ${UPGRADE_DEPLOYMENT_ICP4ACLUSTER_CR}
        if [[ $TAGS_REMOVED == "true" ]]; then
            info "IMAGE TAGS ARE REMOVED FROM THE NEW VERSION OF THE CUSTOM RESOURCE \"${UPGRADE_DEPLOYMENT_ICP4ACLUSTER_CR}\"."
            printf "\n"
        fi
        printf "\n"
        select_apply_cr $UPGRADE_DEPLOYMENT_ICP4ACLUSTER_CR

        if [[ $APPLY_UPDATED_CR == "Yes" ]]; then
            info "Remove initialize_configuration/verify_configuration from CP4BA Custom Resource"
            # Remove the initialize_configuration from CP4BA Custom Resource
            ${CLI_CMD} patch icp4acluster $icp4acluster_cr_name -n $deployment_project_name --type=json -p='[{"op": "remove", "path": "/spec/initialize_configuration"}]' >/dev/null 2>&1
            #Remove the verify_configuration from CP4BA Custom Resource
            ${CLI_CMD} patch icp4acluster $icp4acluster_cr_name -n $deployment_project_name --type=json -p='[{"op": "remove", "path": "/spec/verify_configuration"}]' >/dev/null 2>&1

            info "Applying the custom resource ${UPGRADE_DEPLOYMENT_ICP4ACLUSTER_CR}"
            kubectl annotate icp4acluster $icp4acluster_cr_name kubectl.kubernetes.io/last-applied-configuration- -n $deployment_project_name >/dev/null 2>&1
            #Apply CR to new configuration from the CR file to the cluster, updating the ICP4ACluster resource as per the new specifications
            kubectl apply -f ${UPGRADE_DEPLOYMENT_ICP4ACLUSTER_CR} -n $deployment_project_name >/dev/null 2>&1

            # Check if above kubectl apply command was successful
            if [ $? -ne 0 ]; then
                fail "Failed to update IBM CP4BA Custom Resource."
            else
                echo "Done!"
                printf "\n"
            fi

            echo "${YELLOW_TEXT}[NEXT ACTION]:${RESET_TEXT}"
            echo "${YELLOW_TEXT}- How to check the overall upgrade status for CP4BA/zenService/IM.${RESET_TEXT}"
            echo "${YELLOW_TEXT}  [TIPS]: ${RESET_TEXT}The [upgradeDeploymentStatus] option will start necessary CP4BA operators (ibm-cp4a-operator/icp4a-foundation-operator) first to upgrade zenService, and then will start all other CP4BA operators when zenService upgrade done."
            echo "  STEP1 ${RED_TEXT}(Required)${RESET_TEXT}:${GREEN_TEXT} # ./cp4a-deployment.sh -m upgradeDeploymentStatus -n $TARGET_PROJECT_NAME${RESET_TEXT}"
        else
            initialize_cfg_flag=$(${CLI_CMD} get icp4acluster $icp4acluster_cr_name -n $deployment_project_name --no-headers --ignore-not-found -o 'jsonpath={.spec.initialize_configuration}') >/dev/null 2>&1
            verify_cfg_flag=$(${CLI_CMD} get icp4acluster $icp4acluster_cr_name -n $deployment_project_name --no-headers --ignore-not-found -o 'jsonpath={.spec.verify_configuration}') >/dev/null 2>&1
            printf "\n"

            echo "${YELLOW_TEXT}[NEXT ACTION]:${RESET_TEXT}"
            step_num=1
            for element in "${EXISTING_PATTERN_ARR[@]}"; do
                if [[ "$element" != "decisions" && "$element" == "decisions_ads" && "$allow_direct_upgrade" == 1 ]]; then
                    echo -e "\x1B[33;5m- Automation Decision Services capability is installed in this CP4BA deployment: \x1B[0m"
                    echo "  - STEP ${step_num} ${RED_TEXT}(Required)${RESET_TEXT}: Refer to the Knowledge Center: \"Upgrading IBM Automation Decision Services\" topic:"
                    echo "    - if upgrading from 21.0.3 or 22.0.2: [https://www.ibm.com/docs/en/cloud-paks/cp-biz-automation/24.0.0?topic=deployment-upgrading-automation-decision-services]"
                    echo "    - if upgrading from 23.0.2: [https://www.ibm.com/docs/en/cloud-paks/cp-biz-automation/24.0.0?topic=ucreciyd-upgrading-automation-decision-services]"
                    echo "  - Add the storage_configuration.sc_block_storage_classname property in the CR file if it is not already included."
                    # echo "  - Optional: If the decision runtime secret was manually created, add the following properties:"
                    # echo "    - deploymentSpaceManagerUsername"
                    # echo "    - deploymentSpaceManagerPassword"
                    # echo "    - asraManagerUsername"
                    # echo "    - asraManagerPassword"
                    step_num=$((step_num + 1))
                    printf "\n"
                fi
            done            
            
            # output info for upgrading ADS (from 24.0.1 to 25.0.0)
            if [[ $cr_version != "${CP4BA_RELEASE_BASE}" && $cr_version == "24.0.1" && ${CP4BA_RELEASE_BASE} == "25.0.0" && (" ${EXISTING_PATTERN_ARR[@]} " =~ "decisions_ads") ]]; then
                echo -e "\x1B[33;5m- Automation Decision Services capability is installed in this CP4BA deployment: \x1B[0m"
                if [[ $upgrade_scenario == "edb-already-exists" ]]; then
                        echo "        - You are upgrading from 24.0.1 to 25.0.0, and EDB Postgres instance \"$EDB_INSTANCE_CP4BA_NAME\" is already installed for IBM Cloud Pak for Business Automation.  Before proceeding, make sure you: "
                        echo "            a. ${RED_TEXT}(Required)${RESET_TEXT} create ADS designer and/or runtime database(s) on this EDB Postgres instance. (from https://www.ibm.com/docs/en/cloud-paks/cp-biz-automation/$CP4BA_RELEASE_BASE?topic=automation-upgrading, navigate to \"Upgrading your IBM Cloud Pak deployment from 24.0.1 -> Option 1\" for the sample scripts)."
                        echo "            b. ${RED_TEXT}(Required)${RESET_TEXT} create ADS database_instance_secret secret(s) for ADS designer/runtime database 's username and password. (from https://www.ibm.com/docs/en/cloud-paks/cp-biz-automation/$CP4BA_RELEASE_BASE?topic=automation-upgrading, navigate to \"Upgrading your IBM Cloud Pak deployment from 24.0.1 -> Option 1\" for the sample scripts)."
                        echo "            c. ${RED_TEXT}(Required)${RESET_TEXT} review and modify dc_ads_designer_datasource and/or dc_ads_runtime_datasource section(s) in the custom resource file \"${UPGRADE_DEPLOYMENT_ICP4ACLUSTER_CR}\" to match your EDB Postgres configuration."
                        printf "\n"
                elif [[ $upgrade_scenario == "external-postgres" ]]; then
                        echo "        - You are upgrading from 24.0.1 to 25.0.0, and external PostgreSQL server ${icn_database_servername} is used for ICN database.  Before proceeding, make sure you: "
                        echo "            a. ${RED_TEXT}(Required)${RESET_TEXT} create ADS designer and/or runtime database(s) on this external PostgreSQL. (from https://www.ibm.com/docs/en/cloud-paks/cp-biz-automation/$CP4BA_RELEASE_BASE?topic=automation-upgrading, navigate to \"Upgrading your IBM Cloud Pak deployment from 24.0.1 -> Option 2\" for the sample scripts)."
                        echo "            b. ${RED_TEXT}(Required)${RESET_TEXT} create ADS database_instance_secret secret(s) for ADS designer/runtime database 's username and password. (from https://www.ibm.com/docs/en/cloud-paks/cp-biz-automation/$CP4BA_RELEASE_BASE?topic=automation-upgrading, navigate to \"Upgrading your IBM Cloud Pak deployment from 24.0.1 -> Option 2\" for the sample scripts)."
                        echo "            c. ${RED_TEXT}(Required)${RESET_TEXT} review and modify dc_ads_designer_datasource and/or dc_ads_runtime_datasource section(s) in the custom resource file \"${UPGRADE_DEPLOYMENT_ICP4ACLUSTER_CR}\" to match your external PostgreSQL configuration. "
                        echo " ${RED_TEXT}[IMPORTANT]${RESET_TEXT} If you have set \"sc_restricted_internet_access\" to \"true\" in your applied custom resource file , you must follow the information detailed in https://www.ibm.com/docs/en/cloud-paks/cp-biz-automation/$CP4BA_RELEASE_BASE?topic=uycpdf2-option-2-upgrading-cp4ba-deployment-that-uses-external-postgresql to create any custom Network policies before applying the generated Custom Resource file."
                        printf "\n"
                elif [[ $upgrade_scenario == "new-edb" ]]; then
                        echo "        - You are upgrading from 24.0.1 to 25.0.0, EDB Postgres instance \"$EDB_INSTANCE_CP4BA_NAME\" will be provisioned for ADS Designer/Runtime database.  Before proceeding, make sure you: "
                        echo "            a. ${RED_TEXT}(Required)${RESET_TEXT} review and modify dc_ads_designer_datasource and/or dc_ads_runtime_datasource section(s) in the custom resource file \"${UPGRADE_DEPLOYMENT_ICP4ACLUSTER_CR}\" to match your EDB Postgres configuration."
                        printf "\n"
                fi
            fi

            # output info for upgrading document process databases
            if [[ (" ${EXISTING_PATTERN_ARR[@]} " =~ "document_processing") ]]; then
                    echo -e "\x1B[33;5m- Automation Document Processing capability is installed in this CP4BA deployment: \x1B[0m"
                    echo "  - STEP ${step_num} ${RED_TEXT}(Required)${RESET_TEXT}: Upgrade the Automation Document Processing databases"
                if [[ $allow_direct_upgrade == 1 ]]; then # only show the direct upgrade link if the user is allowed to do a direct upgrade
                    echo "    - If you are upgrading from 21.0.3 or 22.0.2, refer to the Knowledge Center topic: ${GREEN_TEXT}\"Upgrading your Automation Document Processing databases\"${RESET_TEXT} https://www.ibm.com/docs/en/cloud-paks/cp-biz-automation/$CP4BA_RELEASE_BASE?topic=deployment-upgrading-your-automation-document-processing-databases"
                    echo "    - If you are upgrading from 23.0.2, refer to the Knowledge Center topic: ${GREEN_TEXT}\"Upgrading your Automation Document Processing databases\"${RESET_TEXT} https://www.ibm.com/docs/en/cloud-paks/cp-biz-automation/$CP4BA_RELEASE_BASE?topic=ucreciyd-upgrading-automation-document-processing#tasktask_upgrd_adp__postreq__1"
                    echo "    - If you are upgrading from 24.0.0, refer to the Knowledge Center topic: ${GREEN_TEXT}\"Upgrading your Automation Document Processing databases\"${RESET_TEXT} https://www.ibm.com/docs/en/cloud-paks/cp-biz-automation/$CP4BA_RELEASE_BASE?topic=deployment-upgrading-automation-document-processing#tasktask_upgrd_adp__postreq__1"
                fi
                echo "        - If you are upgrading from 24.0.1, refer to the Knowledge Center topic: ${GREEN_TEXT}\"Upgrading your Automation Document Processing databases\"${RESET_TEXT} https://www.ibm.com/docs/en/cloud-paks/cp-biz-automation/$CP4BA_RELEASE_BASE?topic=deployment-upgrading-automation-document-processing#tasktask_upgrd_adp__postreq__1"
                step_num=$((step_num + 1))
                printf "\n"
                if [[ $cr_version != "${CP4BA_RELEASE_BASE}" && $cr_version == "24.0.1" && ${CP4BA_RELEASE_BASE} == "25.0.0" && (" ${EXISTING_OPT_COMPONENT_ARR[@]} " =~ "document_processing_designer")]]; then
                    if [[ $upgrade_scenario == "edb-already-exists" ]]; then
                        echo "        - You are upgrading from 24.0.1 to 25.0.0, and EDB Postgres instance \"$EDB_INSTANCE_CP4BA_NAME\" is already installed for IBM Cloud Pak for Business Automation.  Before proceeding, make sure you: "
                        echo "            a. ${RED_TEXT}(Required)${RESET_TEXT} create ADPGG database on this EDB Postgres instance. (from https://www.ibm.com/docs/en/cloud-paks/cp-biz-automation/$CP4BA_RELEASE_BASE?topic=automation-upgrading, navigate to \"Upgrading your IBM Cloud Pak deployment from 24.0.1 -> Option 1\" for the sample scripts)."
                        echo "            b. ${RED_TEXT}(Required)${RESET_TEXT} update ibm-adp-secret to include adpggDBUsername and adpggDBPassword (the ADPGG database 's username and password)."
                        echo "            c. ${RED_TEXT}(Required)${RESET_TEXT} do NOT delete mongoUri key from ibm-adp-secret."
                        echo "            d. ${RED_TEXT}(Required)${RESET_TEXT} review and modify dc_adp_datasource section in the custom resource file \"${UPGRADE_DEPLOYMENT_ICP4ACLUSTER_CR}\" to match your Postgres configuration."
                        printf "\n"
                    elif [[ $upgrade_scenario == "external-postgres" ]]; then
                        echo "        - You are upgrading from 24.0.1 to 25.0.0, and External PostgreSQL server ${cpe_database_servername} is used for CPE GCD database.  Before proceeding, make sure you: "
                        echo "            a. ${RED_TEXT}(Required)${RESET_TEXT} create ADPGG database on this external PostgreSQL (from https://www.ibm.com/docs/en/cloud-paks/cp-biz-automation/$CP4BA_RELEASE_BASE?topic=automation-upgrading, navigate to \"Upgrading your IBM Cloud Pak deployment from 24.0.1 -> Option 2\" for the sample scripts)."
                        echo "            b. ${RED_TEXT}(Required)${RESET_TEXT} update ibm-adp-secret to include adpggDBUsername and adpggDBPassword (the ADPGG database 's username and password). \n"
                        echo "            c. ${RED_TEXT}(Required)${RESET_TEXT} do NOT delete mongoUri key from ibm-adp-secret. "
                        echo "            d. ${RED_TEXT}(Required)${RESET_TEXT} review and modify dc_adp_datasource section in the custom resource file \"${UPGRADE_DEPLOYMENT_ICP4ACLUSTER_CR}\" to match your Postgres configuration. "
                        printf "\n"
                    elif [[ $upgrade_scenario == "new-edb" ]]; then
                        echo "        - You are upgrading from 24.0.1 to 25.0.0, EDB Postgres instance \"$EDB_INSTANCE_CP4BA_NAME\" will be provisioned for ADP Gitgateway.  Before proceeding, make sure you:"
                        echo "            a. ${RED_TEXT}(Required)${RESET_TEXT} Do NOT delete mongoUri key from ibm-adp-secret."
                        echo "            b. ${RED_TEXT}(Required)${RESET_TEXT} review and modify dc_adp_datasource section in the custom resource file \"${UPGRADE_DEPLOYMENT_ICP4ACLUSTER_CR}\" to match your Postgres configuration."
                        printf "\n"
                    fi
                fi
            fi
                echo "${YELLOW_TEXT}- Refer to the Knowledge Center: \"Updating the custom resource for each capability in your deployment\" topic to complete REQUIRED steps for the installed pattern(s)."
            
            # Adding a statement to delete the old elastic search CR since we are updating the elastic search CR to switch the quiesce flag from false to true in 24.0.1 to 25.0.0 upgrade
            # https://jsw.ibm.com/browse/DBACLD-166681
            if [[ (" ${EXISTING_OPT_COMPONENT_ARR[@]} " =~ "bai") || (" ${EXISTING_OPT_COMPONENT_ARR[@]} " =~ "pfs") ]]; then
                echo -e "\x1B[33;5m- Optional Components Business Automation Insights (BAI) or Data Collector and Data Indexer (PFS) are installed in this CP4BA deployment: \x1B[0m"
                echo "${YELLOW_TEXT}[IMPORTANT]: ${RESET_TEXT}From ($CP4BA_RELEASE_BASE) ,CP4BA will be moving from Opensearch version 2.17.0 (kind: ElasticsearchCluster) to Opensearch version 2.19.x (kind: Cluster). The upgrade process will automatically migrate all the existing indices to new Opensearch version.After the upgrade is completed you must validate and verify all the existing indices are migrated successfully."
                echo "Once you have verified that indices are migrated successfully you may delete the old Opensearch instance (kind: ElasticsearchCluster) by executing \"${GREEN_TEXT} ${CLI_CMD} delete ElasticsearchCluster opensearch -n $deployment_project_name${RESET_TEXT} \" . "
                echo "${YELLOW_TEXT}[NOTE]: ${RESET_TEXT} There will be no functional impact of leaving the old Opensearch  (kind: ElasticsearchCluster) running in the cluster."
                printf "\n"
            fi
            if [[ $allow_direct_upgrade == 1 ]]; then
                echo "  - If upgrading from 21.0.3 or 22.0.2: [https://www.ibm.com/docs/en/cloud-paks/cp-biz-automation/24.0.0?topic=uycpd-updating-custom-resource-each-capability-in-your-deployment]"
                echo "  - If upgrading from 23.0.2: [https://www.ibm.com/docs/en/cloud-paks/cp-biz-automation/24.0.0?topic=uycpdf2-updating-custom-resource-each-capability-in-your-deployment] ${RESET_TEXT}"
                echo "  - If upgrading from 24.0.0: [https://www.ibm.com/docs/en/cloud-paks/cp-biz-automation/24.0.1?topic=uycpdf2-updating-custom-resource-each-capability-in-your-deployment] ${RESET_TEXT}"
            fi
                echo "  - If upgrading from 24.0.1: [https://www.ibm.com/docs/en/cloud-paks/cp-biz-automation/$CP4BA_RELEASE_BASE?topic=uycpdf2-updating-custom-resource-each-capability-in-your-deployment] ${RESET_TEXT}"
                echo "${YELLOW_TEXT}- After reviewing or modifying the custom resource file \"${UPGRADE_DEPLOYMENT_ICP4ACLUSTER_CR}\", you need to follow the steps below to upgrade this CP4BA deployment.${RESET_TEXT}"
            # As a part of DBACLD-149126 solution we no longer needed the user to patch or annotate the custom resource file
            echo "  - STEP ${step_num} ${RED_TEXT}(Required)${RESET_TEXT}:${GREEN_TEXT} # ${CLI_CMD} apply -f ${UPGRADE_DEPLOYMENT_ICP4ACLUSTER_CR} -n $deployment_project_name${RESET_TEXT}"  && step_num=$((step_num + 1))

            printf "\n"
            echo "${YELLOW_TEXT}- How to check the overall upgrade status for CP4BA/zenService/IM.${RESET_TEXT}"
            echo "${YELLOW_TEXT}  [TIPS]: ${RESET_TEXT}The [upgradeDeploymentStatus] option will start necessary CP4BA operators (ibm-cp4a-operator/icp4a-foundation-operator) first to upgrade zenService, and then will start all other CP4BA operators when zenService upgrade done."
            echo "  - STEP ${step_num} ${RED_TEXT}(Required)${RESET_TEXT}:${GREEN_TEXT} # ./cp4a-deployment.sh -m upgradeDeploymentStatus -n $TARGET_PROJECT_NAME${RESET_TEXT}"
        fi
        printf "\n"
        echo "${YELLOW_TEXT}[ATTENTION]: The zenService will be ready in about 120 minutes after the new version ($CP4BA_RELEASE_BASE) of CP4BA custom resource was applied.${RESET_TEXT}"
        printf "\n"

        # if [ $? -ne 0 ]; then
        #     fail "IBM Cloud Pak for Business Automation custom resource update failed"
        #     exit 1
        # else
        #     echo "Done!"

        #     printf "\n"
        #     # echo "${YELLOW_TEXT}[NEXT ACTION]${RESET_TEXT}: "
        #     # msgB "Run \"cp4a-deployment.sh -m upgradeDeploymentStatus -n $deployment_project_name\" to get overview upgrade status for CP4BA"
        # fi
    fi

    if [[ (-z $icp4acluster_cr_name) && (-z $content_cr_name) && (-z $exist_wfps_cr_array) ]]; then
        fail "No found Content or ICP4ACluster or WfPSRuntime custom resource in the project \"$deployment_project_name\""
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
