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

# For jsw.ibm.com/browse/DBACLD-153103 where we need to update the datavolume section of the CR to be in the right format
# Function to check PVC size for a given PVC
get_pvc_size_from_cluster() {
    pvc_name=$1
    DEFAULT_SIZE="1Gi"
    project_namespace=$2
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
    ${SED_COMMAND} -E '/jvm_customize_options:/ { /: *["'"'"']/ ! s/: *(.+)/: "\1"/ }' "${input_yaml}"

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
    output=$(${CLI_CMD} apply -f "$FILE" --dry-run=server 2>&1)
    exit_code=$?
    info "Validating the CP4BA Custom Resource file by executing a dry run..."
    printf "\n"
    # Check the exit code and output to handle different cases
    if [ $exit_code -eq 0 ]; then
        info "${GREEN_TEXT} The Custom Resource file does not contain any errors.${RESET_TEXT}"
        echo "Done!"
    else
        # Handle specific errors
        if echo "$output" | grep -q "unknown field"; then
            # The sample output of the dry run when there is an unknown/invalid field ends with "strict decoding error: unknown field \"<field_name>\""
            # The sed command first removes the entire output string before and including unknown_field " and then removes everything the next quote it finds,keep only <field_name> to be assigned to the unknownfield variable
            unknownfield=$(echo "$output" | sed 's/.*unknown field "//;s/".*//')
            error "ERROR: Unknown field \"$unknownfield\" found in ${FILE}. Please check the field names and values."
        elif echo "$output" | grep -q "error parsing"; then
            error "Error: Error parsing ${FILE}. Please fix the YAML syntax for this custom resource file."
        else
            # Handle other errors
            error "Unknown Error found while applying the Custom Resource file."
        fi
        # Display next steps when an error is encountered
        echo "${YELLOW_TEXT}[NEXT ACTIONS]:${RESET_TEXT}"
        step_num=1
        printf "\n"
        echo "${YELLOW_TEXT}- Resolve the errors that were discovered earlier by modifying the Custom Resource file \"${FILE}\" .${RESET_TEXT}"
        echo "${YELLOW_TEXT}- If the error is related to an unknown field, please remove the unknown field from the Custom Resource file \"${FILE}\" .${RESET_TEXT}"
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
    # check the cr is olm format or not
    olm_cr_flag=`${YQ_CMD} ".spec.olm_ibm_license // \"\"" "$cr_file"`
    if [[ ! -z $olm_cr_flag ]]; then
        olm_cr_flag="Yes"

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
		## - - https://jsw.ibm.com/browse/DBACLD-165625 - <cp4a-deployment script show errors when running on MacOS>
                last_element="${array[${#array[@]}-1]}"
                EXISTING_OPT_COMPONENT_ARR=( "${EXISTING_OPT_COMPONENT_ARR[@]}" "$last_element" )
                IFS=$OIFS
            elif [[ -z $olm_pattern_flag && ${OLM_OPTIONAL_COMPONENT_CR_MAPPING[$i]} != "spec.olm_production_option.workfow_authoring.ae_data_persistence" && ${OLM_OPTIONAL_COMPONENT_CR_MAPPING[$i]} != "spec.olm_production_option.workfow_runtime.elasticsearch" ]]; then
                ${YQ_CMD} -i ".${OLM_OPTIONAL_COMPONENT_CR_MAPPING[$i]} = \"false\"" ${cr_file}
            fi
        done

        # remove duplicate element
        UNIQUE_COMPONENTS=$(printf "%s\n" "${EXISTING_OPT_COMPONENT_ARR[@]}" | sort -u)
        EXISTING_OPT_COMPONENT_ARR=($UNIQUE_COMPONENTS)

        # echo "EXISTING_PATTERN_ARR: ${EXISTING_PATTERN_ARR[*]}"
        # echo "EXISTING_OPT_COMPONENT_ARR: ${EXISTING_OPT_COMPONENT_ARR[*]}"
    else
        olm_cr_flag="No"
    fi
}

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
    #         printf '%b\n' "Answer must be \"Yes\" or \"No\"\n"
    #         ;;
    #     esac
    # done
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
    scim_enabled=$(${CLI_CMD} get cm "$configmap_name" -n $namespace -o yaml | ${YQ_CMD} '.data.scim_configured // ""' -)
    if [[ ! -z "$scim_enabled" ]]; then
        echo "SCIM STATUS----$scim_enabled"
        if [[ "$scim_enabled" == "True" ]]; then
            info "${YELLOW_TEXT}When the Content Process Engine directory provider type is set to SCIM, the script will set \"shared_configuration.sc_skip_ldap_config\" as \"true\" while upgrading CP4BA deployment from version \"$cr_version\".${RESET_TEXT}"
            ${YQ_CMD} -i '.spec.shared_configuration.sc_skip_ldap_config = true' ${cr_file}
        else
            info "${YELLOW_TEXT}When Content Process Engine directory provider type is set to LDAP (not SCIM), setting \"shared_configuration.sc_skip_ldap_config\" as \"false\" while upgrading CP4BA deployment from version \"$cr_version\".${RESET_TEXT}"
            ${YQ_CMD} -i '.spec.shared_configuration.sc_skip_ldap_config = false' ${cr_file}
        fi
    fi
}

function upgrade_deployment(){
    local deployment_project_name=$1
    local operator_project_name=$2
    mkdir -p ${UPGRADE_DEPLOYMENT_CR} >/dev/null 2>&1
    # trap 'startup_operator $deployment_project_name' EXIT
    shutdown_operator $operator_project_name
    # Retrieve existing Content CR
    ${CLI_CMD} get crd |grep contents.icp4a.ibm.com >/dev/null 2>&1
    if [ $? -eq 0 ]; then
        content_cr_name=$(${CLI_CMD} get content -n $deployment_project_name --no-headers --ignore-not-found | awk '{print $1}')
        if [ ! -z $content_cr_name ]; then
            info "Retrieving existing CP4BA Content (Kind: content.icp4a.ibm.com) Custom Resource"
            cr_type="content"
            cr_metaname=$(${CLI_CMD} get content $content_cr_name -n $deployment_project_name -o yaml | ${YQ_CMD} '.metadata.name' -)
            cr_version=$(${CLI_CMD} get content $content_cr_name -n $deployment_project_name -o yaml | ${YQ_CMD} '.spec.appVersion' -)
            owner_ref=$(${CLI_CMD} get content $content_cr_name -n $deployment_project_name -o yaml | ${YQ_CMD} '.metadata.ownerReferences.[0].kind' -)
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
                foundationrequest_cr_name=$(${CLI_CMD} get foundationrequest -n $deployment_project_name --no-headers --ignore-not-found | awk '{print $1}')
                ${CLI_CMD} patch foundationrequest $foundationrequest_cr_name -n $deployment_project_name -p '{"spec":{"appVersion":"$CP4BA_RELEASE_BASE"}}' --type=merge >/dev/null 2>&1

                # Backup existing content CR
                mkdir -p ${UPGRADE_DEPLOYMENT_CR_BAK}
                ${COPY_CMD} -rf ${UPGRADE_DEPLOYMENT_CONTENT_CR_TMP} ${UPGRADE_DEPLOYMENT_CONTENT_CR_BAK}
                # fi

                # DBACLD-190549 - Remove "null" values from jvm_customize_options before any yq operations
                ${SED_COMMAND} -E '
                  /jvm_customize_options/ {
                    s/: "null, */: "/g
                    s/: null, */: /g
                    s/, *null, */,/g
                    s/, *null"/"/g
                    s/, *null$//g
                  }
                ' "${UPGRADE_DEPLOYMENT_CONTENT_CR_TMP}"

                info "Merging existing CP4BA Content Custom Resource with new version ($CP4BA_RELEASE_BASE)"
                # Delete unnecessary section in CR
                ${YQ_CMD} -i 'del(.status)' "${UPGRADE_DEPLOYMENT_CONTENT_CR_TMP}"
                #${YQ_CMD} d -i ${UPGRADE_DEPLOYMENT_CONTENT_CR_TMP} metadata.annotations
                ${YQ_CMD} -i 'del(.metadata.creationTimestamp)' "${UPGRADE_DEPLOYMENT_CONTENT_CR_TMP}"
                ${YQ_CMD} -i 'del(.metadata.generation)' "${UPGRADE_DEPLOYMENT_CONTENT_CR_TMP}"
                ${YQ_CMD} -i 'del(.metadata.resourceVersion)' "${UPGRADE_DEPLOYMENT_CONTENT_CR_TMP}"
                ${YQ_CMD} -i 'del(.metadata.uid)' "${UPGRADE_DEPLOYMENT_CONTENT_CR_TMP}"

                
                #Validate the CR by performing a dry run
                dryrun $UPGRADE_DEPLOYMENT_CONTENT_CR_TMP $deployment_project_name
                #applying the latest tmp CR so that we can update the kubectl.kubernetes.io/last-applied-configuration section to include any potential user edits
                ${CLI_CMD} apply -f ${UPGRADE_DEPLOYMENT_CONTENT_CR_TMP} -n $deployment_project_name >/dev/null 2>&1

                # replace release/appVersion
                ${SED_COMMAND} "s|release: .*|release: ${CP4BA_RELEASE_BASE}|g" ${UPGRADE_DEPLOYMENT_CONTENT_CR_TMP}
                ${SED_COMMAND} "s|appVersion: .*|appVersion: ${CP4BA_RELEASE_BASE}|g" ${UPGRADE_DEPLOYMENT_CONTENT_CR_TMP}

                # remove sc_common_services
                # ${YQ_CMD} m -i -a -M --overwrite ${UPGRADE_DEPLOYMENT_CONTENT_CR_TMP} ${UPGRADE_CS_ZEN_FILE}
                ${YQ_CMD} -i 'del(.spec.shared_configuration.sc_common_service)' "${UPGRADE_DEPLOYMENT_CONTENT_CR_TMP}"
                ${YQ_CMD} -i 'del(.spec.shared_configuration.sc_common_service)' "${UPGRADE_DEPLOYMENT_CONTENT_CR_TMP}"

                ${SED_COMMAND} "s/route_reencrypt: .*/route_reencrypt: $ZEN_ROUTE_REENCRYPT/g" ${UPGRADE_DEPLOYMENT_CONTENT_CR_TMP}

                if [[ ! ("$cp4ba_original_csv_ver_for_upgrade_script" == "24.0."*) ]]; then
                    # Merge BAI save point into content cr
                    bai_flag=`${YQ_CMD} ".spec.content_optional_components.bai" "$UPGRADE_DEPLOYMENT_CONTENT_CR_TMP"`
                    bai_flag=$(echo "$bai_flag" | tr '[:upper:]' '[:lower:]')
                    if [[ $bai_flag == "true" ]]; then
                        info "Merging Flink job savepoint from \"${UPGRADE_DEPLOYMENT_BAI_TMP}\" into new version of custom resource \"${UPGRADE_DEPLOYMENT_CONTENT_CR}\"."
                        if [ -s ${UPGRADE_DEPLOYMENT_BAI_TMP} ]; then
                            ${YQ_CMD} eval-all -i 'select(fi==0) *+ select(fi==1)' ${UPGRADE_DEPLOYMENT_CONTENT_CR_TMP} ${UPGRADE_DEPLOYMENT_BAI_TMP}
                            success "Merged Flink job savepoint into new version of custom resource."
                        else
                        warning "Not found file ${UPGRADE_DEPLOYMENT_BAI_TMP}."
                        fi
                    fi
                fi
                # Disable sc_content_initialization/sc_content_verification
                if [[ $olm_cr_flag == "No" ]]; then
                    ${YQ_CMD} -i '.spec.shared_configuration.sc_content_initialization = false' ${UPGRADE_DEPLOYMENT_CONTENT_CR_TMP}
                    ${YQ_CMD} -i '.spec.shared_configuration.sc_content_verification = false' ${UPGRADE_DEPLOYMENT_CONTENT_CR_TMP}
                else
                    ${YQ_CMD} -i '.spec.shared_configuration.olm_sc_content_initialization = false' ${UPGRADE_DEPLOYMENT_CONTENT_CR_TMP}
                    ${YQ_CMD} -i '.spec.shared_configuration.olm_sc_content_verification = false' ${UPGRADE_DEPLOYMENT_CONTENT_CR_TMP}
                fi
                ${YQ_CMD} -i 'del(.spec.shared_configuration.sc_content_initialization_update_scim)' "${UPGRADE_DEPLOYMENT_CONTENT_CR_TMP}"

                # remove initialize_configuration/verify_configuration
                info "Remove initialize_configuration/verify_configuration from new version of CP4BA Content Custom Resource"
                ${YQ_CMD} -i 'del(.spec.verify_configuration)' "${UPGRADE_DEPLOYMENT_CONTENT_CR_TMP}"
                ${YQ_CMD} -i 'del(.spec.initialize_configuration)' "${UPGRADE_DEPLOYMENT_CONTENT_CR_TMP}"
                # ${YQ_CMD} w -i ${UPGRADE_DEPLOYMENT_CONTENT_CR_TMP} spec.verify_configuration
                # ${YQ_CMD} w -i ${UPGRADE_DEPLOYMENT_CONTENT_CR_TMP} spec.initialize_configuration

                # Function to detect if the Domain is configured with SCIM
                # https://jsw.ibm.com/browse/DBACLD-157386 https://jsw.ibm.com/browse/DBACLD-178101 https://jsw.ibm.com/browse/DBACLD-177550 https://jsw.ibm.com/browse/DBACLD-177742
                detect_scim_configuration "$deployment_project_name" "ibm-cp4ba-content-shared-info" "${UPGRADE_DEPLOYMENT_CONTENT_CR_TMP}"

                # Only always set as false when upgrade from 21.0.3/22.0.2
                if [[ $cr_version != "${CP4BA_RELEASE_BASE}" && $cr_version != "23.0.2" ]]; then
                    # Set sc_restricted_internet_access always "false" in upgrade
                    info "${RED_TEXT}Setting \"shared_configuration.sc_egress_configuration.sc_restricted_internet_access\" as \"false\" when upgrade CP4BA deployment, you could change it according to your requirements of security.${RESET_TEXT}"
                    ${YQ_CMD} -i '.spec.shared_configuration.sc_egress_configuration.sc_restricted_internet_access = false' ${UPGRADE_DEPLOYMENT_CONTENT_CR_TMP}
                    # Set shared_configuration.enable_fips always "false" in upgrade
                    info "${RED_TEXT}Setting \"shared_configuration.enable_fips\" as \"false\" when upgrade CP4BA deployment, you could change it according to your requirements.${RESET_TEXT}"
                    ${YQ_CMD} -i '.spec.shared_configuration.enable_fips = false' ${UPGRADE_DEPLOYMENT_CONTENT_CR_TMP}
                fi

                ${SED_COMMAND} "s|'\"|\"|g" ${UPGRADE_DEPLOYMENT_CONTENT_CR_TMP}
                ${SED_COMMAND} "s|\"'|\"|g" ${UPGRADE_DEPLOYMENT_CONTENT_CR_TMP}
                ${SED_COMMAND} "s/route_reencrypt: .*/route_reencrypt: $ZEN_ROUTE_REENCRYPT/g" ${UPGRADE_DEPLOYMENT_CONTENT_CR_TMP}

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
                
                echo "${YELLOW_TEXT}[ATTENTION]: ${RESET_TEXT}${YELLOW_TEXT}DON'T SET ${RESET_TEXT}${RED_TEXT}\"shared_configuration.sc_egress_configuration.sc_restricted_internet_access\"${RESET_TEXT}${YELLOW_TEXT} AS ${RESET_TEXT}${RED_TEXT}\"true\"${RESET_TEXT}${YELLOW_TEXT} UNTIL AFTER YOU'VE COMPLETED THE CP4BA UPGRADE TO $CP4BA_RELEASE_BASE.${RESET_TEXT} ${GREEN_TEXT}(UNLESS YOU ALREADY HAD THIS SET TO \"true\" IN THE CP4BA 23.0.2.X)${RESET_TEXT}"
                prompt_press_any_key_to_continue
                printf "\n"

                select_apply_cr $UPGRADE_DEPLOYMENT_CONTENT_CR

                if [[ $APPLY_UPDATED_CR == "Yes" ]]; then
                    info "Remove initialize_configuration/verify_configuration from CP4BA Content Custom Resource"
                    ${CLI_CMD} patch content $content_cr_name -n $deployment_project_name --type=json -p='[{"op": "remove", "path": "/spec/initialize_configuration"}]' >/dev/null 2>&1
                    ${CLI_CMD} patch content $content_cr_name -n $deployment_project_name --type=json -p='[{"op": "remove", "path": "/spec/verify_configuration"}]' >/dev/null 2>&1

                    info "Applying the custom resource ${UPGRADE_DEPLOYMENT_CONTENT_CR}"
                    ${CLI_CMD} annotate content $content_cr_name kubectl.kubernetes.io/last-applied-configuration- -n $deployment_project_name >/dev/null 2>&1
                    ${CLI_CMD} apply -f ${UPGRADE_DEPLOYMENT_CONTENT_CR} -n $deployment_project_name >/dev/null 2>&1

                    if [ $? -ne 0 ]; then
                        fail "Failed to update IBM CP4BA Content Custom Resource."
                    else
                        echo "Done!"
                        printf "\n"
                    fi

                    echo "${YELLOW_TEXT}[NEXT ACTION]:${RESET_TEXT}"
                    echo "${YELLOW_TEXT}- How to check the overall upgrade status for CP4BA/zenService/IM.${RESET_TEXT}"
                    echo "${YELLOW_TEXT}  [TIPS]: ${RESET_TEXT}The [upgradeDeploymentStatus] option will start necessary CP4BA operators (ibm-cp4a-operator/icp4a-foundation-operator) first to upgrade zenService, and then will start all other CP4BA operators when zenService upgrade done."
                    CUR_DIR=$(realpath "$(dirname "${BASH_SOURCE[0]}")")
                    SCRIPTS_DIR="$(realpath "$CUR_DIR/../..")"
                    echo "  STEP1 ${RED_TEXT}(Required)${RESET_TEXT}:${GREEN_TEXT} # ${SCRIPTS_DIR}/cp4a-deployment.sh -m upgradeDeploymentStatus -n $TARGET_PROJECT_NAME${RESET_TEXT}"
                else

                    initialize_cfg_flag=$(${CLI_CMD} get content $content_cr_name -n $deployment_project_name --no-headers --ignore-not-found -o 'jsonpath={.spec.initialize_configuration}') >/dev/null 2>&1
                    verify_cfg_flag=$(${CLI_CMD} get content $content_cr_name -n $deployment_project_name --no-headers --ignore-not-found -o 'jsonpath={.spec.verify_configuration}') >/dev/null 2>&1

                    printf "\n"
                    echo "${YELLOW_TEXT}[NEXT ACTION]:${RESET_TEXT}"
                    step_num=1
                    printf "\n"

                    echo "${YELLOW_TEXT}- Refer to the Knowledge Center: \"Updating the custom resource for each capability in your deployment\" topic to complete REQUIRED steps for the installed pattern(s)."
                    echo "  - if upgrading from 21.0.3 or 22.0.2: [From https://www.ibm.com/docs/en/cloud-paks/cp-biz-automation/24.0.0 navigate to Upgrading --> Upgrading from 21.0.3 or 22.0.2 --> Upgrading CP4BA multi-pattern cluster from 21.0.3 or 22.0.2 --> Upgrading your IBM Cloud Pak deployment --> Updating the custom resource for each capability in your deployment]"
                    echo "  - if upgrading from 23.0.2: [From https://www.ibm.com/docs/en/cloud-paks/cp-biz-automation/24.0.0 navigate to Upgrading --> Upgrading from 23.0.2 --> Upgrading CP4BA multi-pattern cluster from 23.0.2 --> Upgrading your IBM Cloud Pak deployment from 23.0.2 --> Updating the custom resource for each capability in your deployment] ${RESET_TEXT}"
                    echo "${YELLOW_TEXT}- After reviewing or modifying the custom resource file \"${UPGRADE_DEPLOYMENT_CONTENT_CR}\", you need to follow the steps below to upgrade this CP4BA deployment.${RESET_TEXT}"
                    # As a part of DBACLD-149126 solution we no longer needed the user to patch or annotate the custom resource file
                    echo "  - STEP ${step_num} ${RED_TEXT}(Required)${RESET_TEXT}:${GREEN_TEXT} # ${CLI_CMD} apply -f ${UPGRADE_DEPLOYMENT_CONTENT_CR} -n $deployment_project_name${RESET_TEXT}" && step_num=$((step_num + 1))

                    printf "\n"
                    echo "${YELLOW_TEXT}- How to check the overall upgrade status for CP4BA/zenService/IM.${RESET_TEXT}"
                    echo "${YELLOW_TEXT}  [TIPS]: ${RESET_TEXT}The [upgradeDeploymentStatus] option will start CP4BA operators automatically after zenService ready."
                    CUR_DIR=$(realpath "$(dirname "${BASH_SOURCE[0]}")")
                    SCRIPTS_DIR="$(realpath "$CUR_DIR/../..")"
                    echo "  - STEP ${step_num} ${RED_TEXT}(Required)${RESET_TEXT}: ${GREEN_TEXT}# ${SCRIPTS_DIR}/cp4a-deployment.sh -m upgradeDeploymentStatus -n $TARGET_PROJECT_NAME${RESET_TEXT}"
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

    # Retrieve existing WfPSRuntime CR
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

            # Backup existing WfPSRuntime CR
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

            # replace release/appVersion
            # ${SED_COMMAND} "s|release: .*|release: ${CP4BA_RELEASE_BASE}|g" ${UPGRADE_DEPLOYMENT_PFS_CR_TMP}
            ${SED_COMMAND} "s|appVersion: .*|appVersion: ${CP4BA_RELEASE_BASE}|g" ${UPGRADE_DEPLOYMENT_WFPS_CR_TMP}

            # # change failureThreshold/periodSeconds for WfPS before upgrade
            # ${YQ_CMD} w -i ${UPGRADE_DEPLOYMENT_WFPS_CR_TMP} spec.node.probe.startupProbe.failureThreshold 800
            # ${YQ_CMD} w -i ${UPGRADE_DEPLOYMENT_WFPS_CR_TMP} spec.node.probe.startupProbe.periodSeconds 10

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

    # Retrieve existing ICP4ACluster CR
    icp4acluster_cr_name=$(${CLI_CMD} get icp4acluster -n $deployment_project_name --no-headers --ignore-not-found | awk '{print $1}')
    if [ ! -z $icp4acluster_cr_name ]; then
        info "Retrieving existing CP4BA ICP4ACluster (Kind: icp4acluster.icp4a.ibm.com) Custom Resource"
        cr_type="icp4acluster"
        cr_metaname=$(${CLI_CMD} get icp4acluster $icp4acluster_cr_name -n $deployment_project_name -o yaml | ${YQ_CMD} '.metadata.name' -)
        cr_version=$(${CLI_CMD} get icp4acluster $icp4acluster_cr_name -n $deployment_project_name -o yaml | ${YQ_CMD} '.spec.appVersion' -)

        ${CLI_CMD} get $cr_type $icp4acluster_cr_name -n $deployment_project_name -o yaml > ${UPGRADE_DEPLOYMENT_ICP4ACLUSTER_CR_TMP}

        convert_olm_cr "${UPGRADE_DEPLOYMENT_ICP4ACLUSTER_CR_TMP}"
        if [[ $olm_cr_flag == "No" ]]; then
            existing_pattern_list=""
            existing_opt_component_list=""

            EXISTING_PATTERN_ARR=()
            EXISTING_OPT_COMPONENT_ARR=()
            existing_pattern_list=`${YQ_CMD} ".spec.shared_configuration.sc_deployment_patterns" "$UPGRADE_DEPLOYMENT_ICP4ACLUSTER_CR_TMP"`
            existing_opt_component_list=`${YQ_CMD} ".spec.shared_configuration.sc_optional_components" "$UPGRADE_DEPLOYMENT_ICP4ACLUSTER_CR_TMP"`

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
        ${YQ_CMD} -i 'del(.status)' "${UPGRADE_DEPLOYMENT_ICP4ACLUSTER_CR_TMP}"
        #${YQ_CMD} d -i ${UPGRADE_DEPLOYMENT_ICP4ACLUSTER_CR_TMP} metadata.annotations
        ${YQ_CMD} -i 'del(.metadata.creationTimestamp)' "${UPGRADE_DEPLOYMENT_ICP4ACLUSTER_CR_TMP}"
        ${YQ_CMD} -i 'del(.metadata.generation)' "${UPGRADE_DEPLOYMENT_ICP4ACLUSTER_CR_TMP}"
        ${YQ_CMD} -i 'del(.metadata.resourceVersion)' "${UPGRADE_DEPLOYMENT_ICP4ACLUSTER_CR_TMP}"
        ${YQ_CMD} -i 'del(.metadata.uid)' "${UPGRADE_DEPLOYMENT_ICP4ACLUSTER_CR_TMP}"
       

        #Validate the CR by performing a dry run
        dryrun $UPGRADE_DEPLOYMENT_ICP4ACLUSTER_CR_TMP $deployment_project_name
	
        #applying the latest tmp CR so that we can update the kubectl.kubernetes.io/last-applied-configuration section to include any potential user edits
        ${CLI_CMD} apply -f ${UPGRADE_DEPLOYMENT_ICP4ACLUSTER_CR_TMP} -n $deployment_project_name >/dev/null 2>&1

        # replace release/appVersion
        ${SED_COMMAND} "s|release: .*|release: ${CP4BA_RELEASE_BASE}|g" ${UPGRADE_DEPLOYMENT_ICP4ACLUSTER_CR_TMP}
        ${SED_COMMAND} "s|appVersion: .*|appVersion: ${CP4BA_RELEASE_BASE}|g" ${UPGRADE_DEPLOYMENT_ICP4ACLUSTER_CR_TMP}


        # 21.0.3
        # if select baw authoring
        if [[ $cr_version != "${CP4BA_RELEASE_BASE}" && $cr_version == "21.0.3" && (" ${EXISTING_OPT_COMPONENT_ARR[@]} " =~ "baw_authoring") ]]; then
            # Add application to sc_deployment_patterns and add app_designer to sc_optional_components to keep application pattern
            EXISTING_PATTERN_ARR=( "${EXISTING_PATTERN_ARR[@]}" "application" )
            EXISTING_OPT_COMPONENT_ARR=( "${EXISTING_OPT_COMPONENT_ARR[@]}" "app_designer" )


            # Fixing pvc logstore size for cp4ba-shared-log only for baw authoring
            ensure_baw_logstore_size "${UPGRADE_DEPLOYMENT_ICP4ACLUSTER_CR_TMP}" "${deployment_project_name}"

            # Replace the database name of Business Automation Studio with the database name of Business Automation Workflow Authoring, for example, replace bastudio_configuration.database.Name with workflow_authoring_configuration.database.database_name.
            baw_auth_db_name=`${YQ_CMD} ".spec.workflow_authoring_configuration.database.database_name // \"\"" "$UPGRADE_DEPLOYMENT_ICP4ACLUSTER_CR_TMP"`
            if [[ ! -z $baw_auth_db_name ]]; then
                ${YQ_CMD} -i ".spec.bastudio_configuration.database.name = \"$baw_auth_db_name\"" ${UPGRADE_DEPLOYMENT_ICP4ACLUSTER_CR_TMP}
            else
                warning "Not found the value of \"spec.workflow_authoring_configuration.database.database_name\" from ${UPGRADE_DEPLOYMENT_ICP4ACLUSTER_CR_TMP}"
            fi

            # Update the Business Automation Studio admin secret to replace the database username and password of Business Automation Studio with the database username and password of Business Automation Workflow Authoring.
            baw_auth_db_secret_name=`${YQ_CMD} ".spec.workflow_authoring_configuration.database.secret_name // \"\"" "$UPGRADE_DEPLOYMENT_ICP4ACLUSTER_CR_TMP"`
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

                bas_db_secret_name=`${YQ_CMD} ".spec.bastudio_configuration.admin_secret_name // \"\"" "$UPGRADE_DEPLOYMENT_ICP4ACLUSTER_CR_TMP"`
                if [[ ! -z $bas_db_secret_name ]]; then
                    if [[ $bas_db_secret_name == *"meta.name"* ]]; then
                        bas_db_secret_name=$(echo "$bas_db_secret_name" | sed "s/{{\s*meta\.name\s*}}/${cr_metaname}/g")
                    fi

                    # Update User Name
                    bas_db_user_name=$(${CLI_CMD} get secret $bas_db_secret_name --no-headers --ignore-not-found -n $deployment_project_name -o jsonpath='{.data.dbUsername}' | base64 -d)
                    if [[ -z $bas_db_user_name ]]; then
                        bas_db_user_name=$(${CLI_CMD} get secret $bas_db_secret_name --no-headers --ignore-not-found -n $deployment_project_name -o jsonpath='{.stringData.dbUsername}' | base64 -d)
                        if [[ ! -z $bas_db_user_name ]]; then
                            ${CLI_CMD} patch secret $bas_db_secret_name -n $deployment_project_name -p '{"stringData":{"dbUsername":"'$(printf '%s' "$baw_auth_db_user_name" | base64)'"}}' >/dev/null 2>&1
                        else
                            warning "Not found the value of \"dbUsername\" from secret $bas_db_secret_name in the project \"$deployment_project_name\"."
                        fi
                    else
                        ${CLI_CMD} patch secret $bas_db_secret_name -n $deployment_project_name -p '{"data":{"dbUsername":"'$(printf '%s' "$baw_auth_db_user_name" | base64)'"}}' >/dev/null 2>&1
                    fi

                    # Update User Password
                    bas_db_user_pwd=$(${CLI_CMD} get secret $bas_db_secret_name --no-headers --ignore-not-found -n $deployment_project_name -o jsonpath='{.data.dbPassword}' | base64 -d)
                    if [[ -z $bas_db_user_pwd ]]; then
                        bas_db_user_pwd=$(${CLI_CMD} get secret $bas_db_secret_name --no-headers --ignore-not-found -n $deployment_project_name -o jsonpath='{.stringData.dbPassword}' | base64 -d)
                        if [[ ! -z $bas_db_user_pwd ]]; then
                            ${CLI_CMD} patch secret $bas_db_secret_name -n $deployment_project_name -p '{"stringData":{"dbPassword":"'$(printf '%s' "$baw_auth_db_user_pwd" | base64)'"}}' >/dev/null 2>&1
                        else
                            warning "Not found the value of \"dbPassword\" from secret $bas_db_secret_name in the project \"$deployment_project_name\"."
                        fi
                    else
                        ${CLI_CMD} patch secret $bas_db_secret_name -n $deployment_project_name -p '{"data":{"dbPassword":"'$(printf '%s' "$baw_auth_db_user_pwd" | base64)'"}}' >/dev/null 2>&1
                    fi
                else
                    warning "Not found the value of \"spec.bastudio_configuration.admin_secret_name\" from ${UPGRADE_DEPLOYMENT_ICP4ACLUSTER_CR_TMP}"
                fi

            else
                warning "Not found the value of \"spec.workflow_authoring_configuration.database.secret_name\" from ${UPGRADE_DEPLOYMENT_ICP4ACLUSTER_CR_TMP}"
            fi
        fi

        # Fixing pvc logstore size for cp4a-shared-log for NON-authoring scenarios
        # This handles BAW Runtime, ADP with BAStudio, etc. (authoring already handled above)
        if [[ $cr_version != "${CP4BA_RELEASE_BASE}" && $cr_version == "21.0.3" && ! (" ${EXISTING_OPT_COMPONENT_ARR[@]} " =~ "baw_authoring") ]]; then
            ensure_baw_logstore_size "${UPGRADE_DEPLOYMENT_ICP4ACLUSTER_CR_TMP}" "${deployment_project_name}"
        fi

        # Add "kafka" into sc_optional_component if kafka_services.enable is true when upgrade
        if [[ ((" ${EXISTING_PATTERN_ARR[@]} " =~ "workflow") && (" ${EXISTING_OPT_COMPONENT_ARR[@]} " =~ "baw_authoring")) ]]; then
            kafka_flag=`${YQ_CMD} ".spec.workflow_authoring_configuration.kafka_services" "$UPGRADE_DEPLOYMENT_ICP4ACLUSTER_CR_TMP"`
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
            ${YQ_CMD} -i 'del(.spec.pfs_configuration)' "${UPGRADE_DEPLOYMENT_ICP4ACLUSTER_CR_TMP}"
            baw_instance_index=0
            while true; do
                baw_instance_flag=`${YQ_CMD} ".spec.baw_configuration.[${baw_instance_index}] // \"\"" "$UPGRADE_DEPLOYMENT_ICP4ACLUSTER_CR_TMP"`
                if [[ ! -z "$baw_instance_flag" ]]; then
                    ${YQ_CMD} -i "del(.spec.baw_configuration[${baw_instance_index}].pfs_bpd_database_init_job)" "${UPGRADE_DEPLOYMENT_ICP4ACLUSTER_CR_TMP}"
                    ((baw_instance_index++))
                else
                    break
                fi
            done
            ${YQ_CMD} -i 'del(.spec.workflow_authoring_configuration.pfs_bpd_database_init_job)' "${UPGRADE_DEPLOYMENT_ICP4ACLUSTER_CR_TMP}"
            # DBACLD-113568
            ${YQ_CMD} -i 'del(.spec.workflow_authoring_configuration.kafka_services)' "${UPGRADE_DEPLOYMENT_ICP4ACLUSTER_CR_TMP}"

            ${CLI_CMD} patch icp4acluster $icp4acluster_cr_name -n $deployment_project_name --type=json -p='[{"op": "remove", "path": "/spec/pfs_configuration"}]' >/dev/null 2>&1
            ${CLI_CMD} patch icp4acluster $icp4acluster_cr_name -n $deployment_project_name --type=json -p='[{"op": "remove", "path": "/spec/baw_configuration/0/pfs_bpd_database_init_job"}]' >/dev/null 2>&1
            ${CLI_CMD} patch icp4acluster $icp4acluster_cr_name -n $deployment_project_name --type=json -p='[{"op": "remove", "path": "/spec/workflow_authoring_configuration/pfs_bpd_database_init_job"}]' >/dev/null 2>&1
            ${CLI_CMD} patch icp4acluster $icp4acluster_cr_name -n $deployment_project_name --type=json -p='[{"op": "remove", "path": "/spec/workflow_authoring_configuration/kafka_services"}]' >/dev/null 2>&1
            # ${CLI_CMD} patch icp4acluster $icp4acluster_cr_name -n $deployment_project_name --type=json -p='[{"op": "remove", "path": "/spec/workflow_authoring_configuration/database"}]' >/dev/null 2>&1
        fi

        # Change ssl_protocol for PFS required in $CP4BA_RELEASE_BASE release
        pfs_ssl_protocol=`${YQ_CMD} ".spec.pfs_configuration.security.ssl_protocol // \"\"" "$UPGRADE_DEPLOYMENT_ICP4ACLUSTER_CR_TMP"`
        if [ ! -z "$pfs_ssl_protocol" ]; then
            ${YQ_CMD} -i '.spec.pfs_configuration.security.ssl_protocol = "TLSv1.2"' ${UPGRADE_DEPLOYMENT_ICP4ACLUSTER_CR_TMP}
        fi
        # remove sc_common_services
        # ${YQ_CMD} m -i -a -M --overwrite ${UPGRADE_DEPLOYMENT_ICP4ACLUSTER_CR_TMP} ${UPGRADE_CS_ZEN_FILE}
        ${YQ_CMD} -i 'del(.spec.shared_configuration.sc_common_service)' "${UPGRADE_DEPLOYMENT_ICP4ACLUSTER_CR_TMP}"
        ${YQ_CMD} -i 'del(.spec.shared_configuration.sc_common_service)' "${UPGRADE_DEPLOYMENT_ICP4ACLUSTER_CR_TMP}"

        if [[ ! ("$cp4ba_original_csv_ver_for_upgrade_script" == "24.0."*) ]]; then
            # Merge BAI save point into content cr
            if [[ (" ${EXISTING_OPT_COMPONENT_ARR[@]} " =~ "bai") ]]; then
                info "Merging Flink job savepoint from \"${UPGRADE_DEPLOYMENT_BAI_TMP}\" into new version of custom resource \"${UPGRADE_DEPLOYMENT_ICP4ACLUSTER_CR}\"."
                if [ -s ${UPGRADE_DEPLOYMENT_BAI_TMP} ]; then
                    ${YQ_CMD} eval-all -i 'select(fi==0) *+ select(fi==1)' ${UPGRADE_DEPLOYMENT_ICP4ACLUSTER_CR_TMP} ${UPGRADE_DEPLOYMENT_BAI_TMP}
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
                baw_datasource_name_tos=`${YQ_CMD} ".spec.workflow_authoring_configuration.case.datasource_name_tos // \"\"" "$UPGRADE_DEPLOYMENT_ICP4ACLUSTER_CR_TMP"`
                baw_connection_point_name_tos=`${YQ_CMD} ".spec.workflow_authoring_configuration.case.connection_point_name_tos // \"\"" "$UPGRADE_DEPLOYMENT_ICP4ACLUSTER_CR_TMP"`
                if [[ -z "$baw_datasource_name_tos" || -z "$baw_connection_point_name_tos" ]]; then
                    init_section=`${YQ_CMD} ".spec.initialize_configuration // \"\"" "$UPGRADE_DEPLOYMENT_ICP4ACLUSTER_CR_TMP"`
                    if [[ -z "$init_section" ]]; then
                        info "Not found initialize_configuration, continue..."
                        # For upgrade to 23.0.1 olny, remove it in 23.0.2 release
                        # info "If you want to add workflow_authoring_configuration.case.datasource_name_tos/connection_point_name_tos manually following https://www.ibm.com/docs/en/cloud-paks/cp-biz-automation/$CP4BA_RELEASE_BASE?topic=upgrade-upgrading-business-automation-workflow-authoring"
                    else
                        os_index=0
                        while true; do
                            os_flag=`${YQ_CMD} ".spec.initialize_configuration.ic_obj_store_creation.object_stores.[${os_index}].oc_cpe_obj_store_symb_name // \"\"" "$UPGRADE_DEPLOYMENT_ICP4ACLUSTER_CR_TMP"`
                            if [[ ! -z "$os_flag" ]]; then
                                enable_workflow=`${YQ_CMD} ".spec.initialize_configuration.ic_obj_store_creation.object_stores.[${os_index}].oc_cpe_obj_store_enable_workflow" "$UPGRADE_DEPLOYMENT_ICP4ACLUSTER_CR_TMP"`
                                if [[ "$enable_workflow" == "true" ]]; then
                                    tos_datasource_name=`${YQ_CMD} ".spec.initialize_configuration.ic_obj_store_creation.object_stores.[${os_index}].oc_cpe_obj_store_conn.dc_os_datasource_name // \"\"" "$UPGRADE_DEPLOYMENT_ICP4ACLUSTER_CR_TMP"`
                                    tos_connection=`${YQ_CMD} ".spec.initialize_configuration.ic_obj_store_creation.object_stores.[${os_index}].oc_cpe_obj_store_workflow_pe_conn_point_name // \"\"" "$UPGRADE_DEPLOYMENT_ICP4ACLUSTER_CR_TMP"`
                                    if [[ ! -z "$tos_datasource_name" ]]; then
                                        ${YQ_CMD} -i ".spec.workflow_authoring_configuration.case.datasource_name_tos = \"$tos_datasource_name\"" ${UPGRADE_DEPLOYMENT_ICP4ACLUSTER_CR_TMP}
                                    fi
                                    if [[ ! -z "$tos_connection" ]]; then
                                        ${YQ_CMD} -i ".spec.workflow_authoring_configuration.case.connection_point_name_tos = \"$tos_connection\"" ${UPGRADE_DEPLOYMENT_ICP4ACLUSTER_CR_TMP}
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
                    baw_instance_flag=`${YQ_CMD} ".spec.baw_configuration.[${baw_instance_index}].case // \"\"" "$UPGRADE_DEPLOYMENT_ICP4ACLUSTER_CR_TMP"`
                    if [[ ! -z "$baw_instance_flag" ]]; then
                        baw_datasource_name_tos=`${YQ_CMD} ".spec.baw_configuration.[${baw_instance_index}].case.datasource_name_tos // \"\"" "$UPGRADE_DEPLOYMENT_ICP4ACLUSTER_CR_TMP"`
                        baw_connection_point_name_tos=`${YQ_CMD} ".spec.baw_configuration.[${baw_instance_index}].case.connection_point_name_tos // \"\"" "$UPGRADE_DEPLOYMENT_ICP4ACLUSTER_CR_TMP"`
                        if [[ -z "$baw_datasource_name_tos" || -z "$baw_connection_point_name_tos" ]]; then
                            init_section=`${YQ_CMD} ".spec.initialize_configuration // \"\"" "$UPGRADE_DEPLOYMENT_ICP4ACLUSTER_CR_TMP"`
                            if [[ -z "$init_section" ]]; then
                                info "Not found initialize_configuration, continue..."
                                # For upgrade to 23.0.1 olny, remove it in 23.0.2 release
                                # info "If you want to add baw_configuration.[0].case.datasource_name_tos/connection_point_name_tos manually following https://www.ibm.com/docs/en/cloud-paks/cp-biz-automation/$CP4BA_RELEASE_BASE?topic=upgrade-upgrading-business-automation-workflow-authoring"
                            else
                                os_index=0
                                while true; do
                                    os_flag=`${YQ_CMD} ".spec.initialize_configuration.ic_obj_store_creation.object_stores.[${os_index}].oc_cpe_obj_store_symb_name // \"\"" "$UPGRADE_DEPLOYMENT_ICP4ACLUSTER_CR_TMP"`
                                    if [[ ! -z "$os_flag" ]]; then
                                        enable_workflow=`${YQ_CMD} ".spec.initialize_configuration.ic_obj_store_creation.object_stores.[${os_index}].oc_cpe_obj_store_enable_workflow" "$UPGRADE_DEPLOYMENT_ICP4ACLUSTER_CR_TMP"`
                                        if [[ "$enable_workflow" == "true" ]]; then
                                            tos_datasource_name=`${YQ_CMD} ".spec.initialize_configuration.ic_obj_store_creation.object_stores.[${os_index}].oc_cpe_obj_store_conn.dc_os_datasource_name // \"\"" "$UPGRADE_DEPLOYMENT_ICP4ACLUSTER_CR_TMP"`
                                            tos_connection=`${YQ_CMD} ".spec.initialize_configuration.ic_obj_store_creation.object_stores.[${os_index}].oc_cpe_obj_store_workflow_pe_conn_point_name // \"\"" "$UPGRADE_DEPLOYMENT_ICP4ACLUSTER_CR_TMP"`
                                            if [[ ! -z "$tos_datasource_name" ]]; then
                                                ${YQ_CMD} -i ".spec.baw_configuration[${baw_instance_index}].case.datasource_name_tos = \"$tos_datasource_name\"" ${UPGRADE_DEPLOYMENT_ICP4ACLUSTER_CR_TMP}
                                            fi
                                            if [[ ! -z "$tos_connection" ]]; then
                                                ${YQ_CMD} -i ".spec.baw_configuration[${baw_instance_index}].case.connection_point_name_tos = \"$tos_connection\"" ${UPGRADE_DEPLOYMENT_ICP4ACLUSTER_CR_TMP}
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
                baw_instance_flag=`${YQ_CMD} ".spec.workflow_authoring_configuration.case.event_emitter // \"\"" "$UPGRADE_DEPLOYMENT_ICP4ACLUSTER_CR_TMP"`
                if [[ ! -z "$baw_instance_flag" ]]; then
                    ## https://jsw.ibm.com/browse/DBACLD-154386
                    ## Referencing the object store name instead of datasource name
                    baw_event_emitter_tos_name=`${YQ_CMD} ".spec.workflow_authoring_configuration.case.object_store_name_tos // \"\"" "$UPGRADE_DEPLOYMENT_ICP4ACLUSTER_CR_TMP"`
                    baw_event_emitter_connection_point_name=`${YQ_CMD} ".spec.workflow_authoring_configuration.case.connection_point_name_tos // \"\"" "$UPGRADE_DEPLOYMENT_ICP4ACLUSTER_CR_TMP"`
                    baw_event_emitter_date_sql=`${YQ_CMD} ".spec.workflow_authoring_configuration.case.event_emitter.date_sql // \"\"" "$UPGRADE_DEPLOYMENT_ICP4ACLUSTER_CR_TMP"`
                    baw_event_emitter_logical_unique_id=`${YQ_CMD} ".spec.workflow_authoring_configuration.case.event_emitter.logical_unique_id // \"\"" "$UPGRADE_DEPLOYMENT_ICP4ACLUSTER_CR_TMP"`
                    baw_event_emitter_solution_list=`${YQ_CMD} ".spec.workflow_authoring_configuration.case.event_emitter.solution_list // \"\"" "$UPGRADE_DEPLOYMENT_ICP4ACLUSTER_CR_TMP"`
                    baw_event_emitter_casetype_list=`${YQ_CMD} ".spec.workflow_authoring_configuration.case.event_emitter.casetype_list // \"\"" "$UPGRADE_DEPLOYMENT_ICP4ACLUSTER_CR_TMP"`
                    baw_event_emitter_emitter_batch_size=`${YQ_CMD} ".spec.workflow_authoring_configuration.case.event_emitter.emitter_batch_size // \"\"" "$UPGRADE_DEPLOYMENT_ICP4ACLUSTER_CR_TMP"`
                    baw_event_emitter_process_pe_events=`${YQ_CMD} ".spec.workflow_authoring_configuration.case.event_emitter.process_pe_events // \"\"" "$UPGRADE_DEPLOYMENT_ICP4ACLUSTER_CR_TMP"`

                    ${YQ_CMD} -i ".spec.workflow_authoring_configuration.case.event_emitter = [{
                    \"tos_name\": \"$baw_event_emitter_tos_name\",
                    \"connection_point_name\": \"$baw_event_emitter_connection_point_name\",
                    \"date_sql\": \"$baw_event_emitter_date_sql\",
                    \"logical_unique_id\": \"$baw_event_emitter_logical_unique_id\",
                    \"solution_list\": \"$baw_event_emitter_solution_list\",
                    \"casetype_list\": \"$baw_event_emitter_casetype_list\",
                    \"emitter_batch_size\": \"$baw_event_emitter_emitter_batch_size\",
                    \"process_pe_events\": \"$baw_event_emitter_process_pe_events\"
                    }]" ${UPGRADE_DEPLOYMENT_ICP4ACLUSTER_CR_TMP}

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
                    baw_instance_flag=`${YQ_CMD} ".spec.baw_configuration.[${baw_instance_index}].case.event_emitter // \"\"" "$UPGRADE_DEPLOYMENT_ICP4ACLUSTER_CR_TMP"`
                    if [[ ! -z "$baw_instance_flag" ]]; then
                        ## https://jsw.ibm.com/browse/DBACLD-154386
                        ## Referencing the object store name instead of datasource name
                        baw_event_emitter_tos_name=`${YQ_CMD} ".spec.baw_configuration.[${baw_instance_index}].case.object_store_name_tos // \"\"" "$UPGRADE_DEPLOYMENT_ICP4ACLUSTER_CR_TMP"`
                        baw_event_emitter_connection_point_name=`${YQ_CMD} ".spec.baw_configuration.[${baw_instance_index}].case.connection_point_name_tos // \"\"" "$UPGRADE_DEPLOYMENT_ICP4ACLUSTER_CR_TMP"`
                        baw_event_emitter_date_sql=`${YQ_CMD} ".spec.baw_configuration.[${baw_instance_index}].case.event_emitter.date_sql // \"\"" "$UPGRADE_DEPLOYMENT_ICP4ACLUSTER_CR_TMP"`
                        baw_event_emitter_logical_unique_id=`${YQ_CMD} ".spec.baw_configuration.[${baw_instance_index}].case.event_emitter.logical_unique_id // \"\"" "$UPGRADE_DEPLOYMENT_ICP4ACLUSTER_CR_TMP"`
                        baw_event_emitter_solution_list=`${YQ_CMD} ".spec.baw_configuration.[${baw_instance_index}].case.event_emitter.solution_list // \"\"" "$UPGRADE_DEPLOYMENT_ICP4ACLUSTER_CR_TMP"`
                        baw_event_emitter_casetype_list=`${YQ_CMD} ".spec.baw_configuration.[${baw_instance_index}].case.event_emitter.casetype_list // \"\"" "$UPGRADE_DEPLOYMENT_ICP4ACLUSTER_CR_TMP"`
                        baw_event_emitter_emitter_batch_size=`${YQ_CMD} ".spec.baw_configuration.[${baw_instance_index}].case.event_emitter.emitter_batch_size // \"\"" "$UPGRADE_DEPLOYMENT_ICP4ACLUSTER_CR_TMP"`
                        baw_event_emitter_process_pe_events=`${YQ_CMD} ".spec.baw_configuration.[${baw_instance_index}].case.event_emitter.process_pe_events // \"\"" "$UPGRADE_DEPLOYMENT_ICP4ACLUSTER_CR_TMP"`

                        ${YQ_CMD} -i ".spec.baw_configuration[${baw_instance_index}].case.event_emitter = [{
                        \"tos_name\": \"$baw_event_emitter_tos_name\",
                        \"connection_point_name\": \"$baw_event_emitter_connection_point_name\",
                        \"date_sql\": \"$baw_event_emitter_date_sql\",
                        \"logical_unique_id\": \"$baw_event_emitter_logical_unique_id\",
                        \"solution_list\": \"$baw_event_emitter_solution_list\",
                        \"casetype_list\": \"$baw_event_emitter_casetype_list\",
                        \"emitter_batch_size\": \"$baw_event_emitter_emitter_batch_size\",
                        \"process_pe_events\": \"$baw_event_emitter_process_pe_events\"
                        }]" ${UPGRADE_DEPLOYMENT_ICP4ACLUSTER_CR_TMP}

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
                baw_instance_flag=`${YQ_CMD} ".spec.workflow_authoring_configuration.case // \"\"" "$UPGRADE_DEPLOYMENT_ICP4ACLUSTER_CR_TMP"`
                if [[ ! -z "$baw_instance_flag" ]]; then
                    baw_object_store_name_tos=`${YQ_CMD} ".spec.workflow_authoring_configuration.case.object_store_name_tos // \"\"" "$UPGRADE_DEPLOYMENT_ICP4ACLUSTER_CR_TMP"`
                    baw_connection_point_name_tos=`${YQ_CMD} ".spec.workflow_authoring_configuration.case.connection_point_name_tos // \"\"" "$UPGRADE_DEPLOYMENT_ICP4ACLUSTER_CR_TMP"`
                    baw_target_environment_name=`${YQ_CMD} ".spec.workflow_authoring_configuration.case.target_environment_name // \"\"" "$UPGRADE_DEPLOYMENT_ICP4ACLUSTER_CR_TMP"`
                    baw_desktop_name=`${YQ_CMD} ".spec.workflow_authoring_configuration.case.desktop_name // \"\"" "$UPGRADE_DEPLOYMENT_ICP4ACLUSTER_CR_TMP"`

                    if [[ (-z $baw_connection_point_name_tos || -z $baw_object_store_name_tos) && (-z $init_section) ]]; then
                        warning "Not found both workflow_authoring_configuration.case.connection_point_name_tos/object_store_name_tos and oc_cpe_obj_store_workflow_pe_conn_point_name under initialize_configuration, please refer KC from https://www.ibm.com/docs/en/cloud-paks/cp-biz-automation/$CP4BA_RELEASE_BASE navigate to Upgrading --> Upgrading from 24.0.0 --> Upgrading CP4BA multi-pattern cluster from 24.0.0 --> Upgrading your IBM Cloud Pak deployment from 24.0.0 --> Updating the custom resource for each capability in your deployment --> Upgrading IBM Business Automation Workflow Authoring"
                    fi
                    if [[ ! -z "$baw_object_store_name_tos" ]]; then
                        ${YQ_CMD} -i ".spec.workflow_authoring_configuration.case.tos_list[0].object_store_name = \"$baw_object_store_name_tos\"" ${UPGRADE_DEPLOYMENT_ICP4ACLUSTER_CR_TMP}

                        if [[ ! -z $baw_connection_point_name_tos ]]; then
                            ${YQ_CMD} -i ".spec.workflow_authoring_configuration.case.tos_list[0].connection_point_name = \"$baw_connection_point_name_tos\"" ${UPGRADE_DEPLOYMENT_ICP4ACLUSTER_CR_TMP}
                        fi

                        ${YQ_CMD} -i 'del(.spec.workflow_authoring_configuration.case.object_store_name_tos)' "${UPGRADE_DEPLOYMENT_ICP4ACLUSTER_CR_TMP}"
                        ${YQ_CMD} -i 'del(.spec.workflow_authoring_configuration.case.connection_point_name_tos)' "${UPGRADE_DEPLOYMENT_ICP4ACLUSTER_CR_TMP}"
                        ${YQ_CMD} -i 'del(.spec.workflow_authoring_configuration.case.datasource_name_tos)' "${UPGRADE_DEPLOYMENT_ICP4ACLUSTER_CR_TMP}"

                        if [[ -z $baw_target_environment_name ]]; then
                            ${YQ_CMD} -i '.spec.workflow_authoring_configuration.case.tos_list[0].target_environment_name = "dev_env_connection_definition"' ${UPGRADE_DEPLOYMENT_ICP4ACLUSTER_CR_TMP}
                        else
                            ${YQ_CMD} -i ".spec.workflow_authoring_configuration.case.tos_list[0].target_environment_name = \"$baw_target_environment_name\"" ${UPGRADE_DEPLOYMENT_ICP4ACLUSTER_CR_TMP}
                        fi
                        ${YQ_CMD} -i 'del(.spec.workflow_authoring_configuration.case.target_environment_name)' "${UPGRADE_DEPLOYMENT_ICP4ACLUSTER_CR_TMP}"

                        if [[ -z $baw_desktop_name ]]; then
                            ${YQ_CMD} -i '.spec.workflow_authoring_configuration.case.tos_list[0].desktop_id = "baw"' ${UPGRADE_DEPLOYMENT_ICP4ACLUSTER_CR_TMP}
                        else
                            ${YQ_CMD} -i ".spec.workflow_authoring_configuration.case.tos_list[0].desktop_id = \"$baw_desktop_name\"" ${UPGRADE_DEPLOYMENT_ICP4ACLUSTER_CR_TMP}
                        fi
                        ${YQ_CMD} -i 'del(.spec.workflow_authoring_configuration.case.desktop_name)' "${UPGRADE_DEPLOYMENT_ICP4ACLUSTER_CR_TMP}"
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

        # for 23.0.2.X release
        # for BAW authoring, set workflow_authoring_configuration.case.tos_list
        # Support multiple tos instance from $CP4BA_RELEASE_BASE
        if [[ $cr_version != "${CP4BA_RELEASE_BASE}" && $cr_version == "23.0.2" ]]; then
            if [[ " ${EXISTING_OPT_COMPONENT_ARR[@]} " =~ "baw_authoring" ]]; then
                # Support multiple tos instance from $CP4BA_RELEASE_BASE
                tos_instance_index=0
                while true; do
                    baw_instance_flag=`${YQ_CMD} ".spec.workflow_authoring_configuration.case // \"\"" "$UPGRADE_DEPLOYMENT_ICP4ACLUSTER_CR_TMP"`
                    if [[ ! -z "$baw_instance_flag" ]]; then
                        baw_object_store_name_tos=`${YQ_CMD} ".spec.workflow_authoring_configuration.case.tos_list.[${tos_instance_index}].object_store_name // \"\"" "$UPGRADE_DEPLOYMENT_ICP4ACLUSTER_CR_TMP"`
                        baw_connection_point_name_tos=`${YQ_CMD} ".spec.workflow_authoring_configuration.case.tos_list.[${tos_instance_index}].connection_point_name // \"\"" "$UPGRADE_DEPLOYMENT_ICP4ACLUSTER_CR_TMP"`
                        baw_target_environment_name=`${YQ_CMD} ".spec.workflow_authoring_configuration.case.tos_list.[${tos_instance_index}].target_environment_name // \"\"" "$UPGRADE_DEPLOYMENT_ICP4ACLUSTER_CR_TMP"`
                        desktop_id=`${YQ_CMD} ".spec.workflow_authoring_configuration.case.tos_list.[${tos_instance_index}].desktop_id // \"\"" "$UPGRADE_DEPLOYMENT_ICP4ACLUSTER_CR_TMP"`
                        if [[ (! -z "$baw_object_store_name_tos") && -z "$baw_connection_point_name_tos" ]]; then
                            init_section=`${YQ_CMD} ".spec.initialize_configuration // \"\"" "$UPGRADE_DEPLOYMENT_ICP4ACLUSTER_CR_TMP"`
                            if [[ -z "$init_section" ]]; then
                                info "Not found initialize_configuration, continue..."
                            else
                                os_index=0
                                while true; do
                                    os_flag=`${YQ_CMD} ".spec.initialize_configuration.ic_obj_store_creation.object_stores.[${os_index}].oc_cpe_obj_store_symb_name // \"\"" "$UPGRADE_DEPLOYMENT_ICP4ACLUSTER_CR_TMP"`
                                    if [[ ! -z "$os_flag" ]]; then
                                        enable_workflow=`${YQ_CMD} ".spec.initialize_configuration.ic_obj_store_creation.object_stores.[${os_index}].oc_cpe_obj_store_enable_workflow" "$UPGRADE_DEPLOYMENT_ICP4ACLUSTER_CR_TMP"`
                                        if [[ "$enable_workflow" == "true" ]]; then
                                            tos_datasource_name=`${YQ_CMD} ".spec.initialize_configuration.ic_obj_store_creation.object_stores.[${os_index}].oc_cpe_obj_store_conn.dc_os_datasource_name // \"\"" "$UPGRADE_DEPLOYMENT_ICP4ACLUSTER_CR_TMP"`
                                            tos_connection=`${YQ_CMD} ".spec.initialize_configuration.ic_obj_store_creation.object_stores.[${os_index}].oc_cpe_obj_store_workflow_pe_conn_point_name // \"\"" "$UPGRADE_DEPLOYMENT_ICP4ACLUSTER_CR_TMP"`
                                            if [[ $baw_object_store_name_tos == $tos_datasource_name ]]; then
                                                if [[ ! -z "$tos_datasource_name" ]]; then
                                                    ${YQ_CMD} -i ".spec.workflow_authoring_configuration.case.tos_list[${tos_instance_index}].object_store_name = \"$tos_datasource_name\"" ${UPGRADE_DEPLOYMENT_ICP4ACLUSTER_CR_TMP}
                                                fi
                                                if [[ ! -z "$tos_connection" ]]; then
                                                    ${YQ_CMD} -i ".spec.workflow_authoring_configuration.case.tos_list[${tos_instance_index}].connection_point_name = \"$tos_connection\"" ${UPGRADE_DEPLOYMENT_ICP4ACLUSTER_CR_TMP}
                                                fi
                                                # if [[ -z "$baw_target_environment_name" ]]; then
                                                #     tmp_val_ds_name=$(echo "$tos_datasource_name" | tr '[:upper:]' '[:lower:]')
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
                    baw_instance_flag=`${YQ_CMD} ".spec.baw_configuration.[${baw_instance_index}].case // \"\"" "$UPGRADE_DEPLOYMENT_ICP4ACLUSTER_CR_TMP"`
                    if [[ ! -z "$baw_instance_flag" ]]; then
                        baw_object_store_name_tos=`${YQ_CMD} ".spec.baw_configuration.[${baw_instance_index}].case.object_store_name_tos // \"\"" "$UPGRADE_DEPLOYMENT_ICP4ACLUSTER_CR_TMP"`
                        baw_connection_point_name_tos=`${YQ_CMD} ".spec.baw_configuration.[${baw_instance_index}].case.connection_point_name_tos // \"\"" "$UPGRADE_DEPLOYMENT_ICP4ACLUSTER_CR_TMP"`
                        baw_target_environment_name=`${YQ_CMD} ".spec.baw_configuration.[${baw_instance_index}].case.target_environment_name // \"\"" "$UPGRADE_DEPLOYMENT_ICP4ACLUSTER_CR_TMP"`
                        baw_desktop_name=`${YQ_CMD} ".spec.baw_configuration.[${baw_instance_index}].case.desktop_name // \"\"" "$UPGRADE_DEPLOYMENT_ICP4ACLUSTER_CR_TMP"`
                        if [[ (-z $baw_connection_point_name_tos || -z $baw_object_store_name_tos) && (-z $init_section) ]]; then
                            warning "Not found both baw_configuration.[${baw_instance_index}].case.connection_point_name_tos/object_store_name_tos and oc_cpe_obj_store_workflow_pe_conn_point_name under initialize_configuration, please refer KC from https://www.ibm.com/docs/en/cloud-paks/cp-biz-automation/$CP4BA_RELEASE_BASE navigate to Upgrading --> Upgrading from 24.0.0 --> Upgrading CP4BA multi-pattern cluster from 24.0.0 --> Upgrading your IBM Cloud Pak deployment from 24.0.0 --> Updating the custom resource for each capability in your deployment --> Upgrading IBM Business Automation Workflow Runtime"
                        fi
                        if [[ ! -z "$baw_object_store_name_tos" ]]; then
                            ${YQ_CMD} -i ".spec.baw_configuration[${baw_instance_index}].case.tos_list[0].object_store_name = \"$baw_object_store_name_tos\"" ${UPGRADE_DEPLOYMENT_ICP4ACLUSTER_CR_TMP}

                            if [[ ! -z $baw_connection_point_name_tos ]]; then
                                ${YQ_CMD} -i ".spec.baw_configuration[${baw_instance_index}].case.tos_list[0].connection_point_name = \"$baw_connection_point_name_tos\"" ${UPGRADE_DEPLOYMENT_ICP4ACLUSTER_CR_TMP}
                            fi

                            ${YQ_CMD} -i "del(.spec.baw_configuration[${baw_instance_index}].case.object_store_name_tos)" "${UPGRADE_DEPLOYMENT_ICP4ACLUSTER_CR_TMP}"
                            ${YQ_CMD} -i "del(.spec.baw_configuration[${baw_instance_index}].case.connection_point_name_tos)" "${UPGRADE_DEPLOYMENT_ICP4ACLUSTER_CR_TMP}"
                            ${YQ_CMD} -i "del(.spec.baw_configuration[${baw_instance_index}].case.datasource_name_tos)" "${UPGRADE_DEPLOYMENT_ICP4ACLUSTER_CR_TMP}"

                            if [[ -z $baw_target_environment_name ]]; then
                                ${YQ_CMD} -i ".spec.baw_configuration[${baw_instance_index}].case.tos_list[0].target_environment_name = \"target_env\"" ${UPGRADE_DEPLOYMENT_ICP4ACLUSTER_CR_TMP}
                            else
                                ${YQ_CMD} -i ".spec.baw_configuration[${baw_instance_index}].case.tos_list[0].target_environment_name = \"$baw_target_environment_name\"" ${UPGRADE_DEPLOYMENT_ICP4ACLUSTER_CR_TMP}
                            fi
                            ${YQ_CMD} -i "del(.spec.baw_configuration[${baw_instance_index}].case.target_environment_name)" "${UPGRADE_DEPLOYMENT_ICP4ACLUSTER_CR_TMP}"

                            if [[ -z $baw_desktop_name ]]; then
                                ${YQ_CMD} -i ".spec.baw_configuration[${baw_instance_index}].case.tos_list[0].desktop_id = \"baw\"" ${UPGRADE_DEPLOYMENT_ICP4ACLUSTER_CR_TMP}
                            else
                                ${YQ_CMD} -i ".spec.baw_configuration[${baw_instance_index}].case.tos_list[0].desktop_id = \"$baw_desktop_name\"" ${UPGRADE_DEPLOYMENT_ICP4ACLUSTER_CR_TMP}
                            fi
                            ${YQ_CMD} -i "del(.spec.baw_configuration[${baw_instance_index}].case.desktop_name)" "${UPGRADE_DEPLOYMENT_ICP4ACLUSTER_CR_TMP}"
                        fi
                        ((baw_instance_index++))
                    else
                        break
                    fi
                done
                # Delete datasource_name_tos/object_store_name_tos and so on from existing CR
                baw_instance_index=0
                while true; do
                    baw_instance_flag=`${YQ_CMD} ".spec.baw_configuration.[${baw_instance_index}].case // \"\"" "$UPGRADE_DEPLOYMENT_ICP4ACLUSTER_CR_TMP"`
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
                    baw_instance_flag=`${YQ_CMD} ".spec.baw_configuration.[${baw_instance_index}] // \"\"" "$UPGRADE_DEPLOYMENT_ICP4ACLUSTER_CR_TMP"`
                    if [[ ! -z "$baw_instance_flag" ]]; then
                        ((baw_instance_index++))
                    else
                        break
                    fi
                done

                for ((num=0;num<${baw_instance_index};num++)); do
                    # ${YQ_CMD} d -i ${UPGRADE_DEPLOYMENT_ICP4ACLUSTER_CR_TMP} spec.baw_configuration.[${num}].host_federated_portal
                    ${YQ_CMD} -i "del(.spec.baw_configuration[${num}].pfs_bpd_database_init_job)" "${UPGRADE_DEPLOYMENT_ICP4ACLUSTER_CR_TMP}"
                    ${YQ_CMD} -i "del(.spec.baw_configuration[${num}].ibm_workplace_job)" "${UPGRADE_DEPLOYMENT_ICP4ACLUSTER_CR_TMP}"

                    # ${CLI_CMD} patch icp4acluster $icp4acluster_cr_name -n $deployment_project_name --type=json -p="[{\"op\": \"remove\", \"path\": \"/spec/baw_configuration/${num}/host_federated_portal\"}]" >/dev/null 2>&1
                    ${CLI_CMD} patch icp4acluster $icp4acluster_cr_name -n $deployment_project_name --type=json -p="[{\"op\": \"remove\", \"path\": \"/spec/baw_configuration/${num}/pfs_bpd_database_init_job\"}]" >/dev/null 2>&1
                    ${CLI_CMD} patch icp4acluster $icp4acluster_cr_name -n $deployment_project_name --type=json -p="[{\"op\": \"remove\", \"path\": \"/spec/baw_configuration/${num}/ibm_workplace_job\"}]" >/dev/null 2>&1
                done

                ${YQ_CMD} -i 'del(.spec.pfs_configuration)' "${UPGRADE_DEPLOYMENT_ICP4ACLUSTER_CR_TMP}"
                ${CLI_CMD} patch icp4acluster $icp4acluster_cr_name -n $deployment_project_name --type=json -p='[{"op": "remove", "path": "/spec/pfs_configuration"}]' >/dev/null 2>&1
            fi
        fi

        # for 23.0.2.X release
        # for BAW Runtime, set baw_configuration.case.tos_list
        # Support multiple tos instance from $CP4BA_RELEASE_BASE
        if [[ $cr_version != "${CP4BA_RELEASE_BASE}" && $cr_version == "23.0.2" ]]; then
            if [[ (! " ${EXISTING_OPT_COMPONENT_ARR[@]} " =~ "baw_authoring") && (" ${EXISTING_PATTERN_ARR[@]} " =~ "workflow" || " ${EXISTING_PATTERN_ARR[@]} " =~ "workflow-workstreams") ]]; then
                # Support multiple tos instance from $CP4BA_RELEASE_BASE
                baw_instance_index=0
                while true; do
                    baw_instance_flag=`${YQ_CMD} ".spec.baw_configuration.[${baw_instance_index}].case // \"\"" "$UPGRADE_DEPLOYMENT_ICP4ACLUSTER_CR_TMP"`
                    if [[ ! -z "$baw_instance_flag" ]]; then
                        # Support multiple tos instance from $CP4BA_RELEASE_BASE
                        tos_instance_index=0
                        while true; do
                            baw_instance_flag=`${YQ_CMD} ".spec.baw_configuration.[${baw_instance_index}].case // \"\"" "$UPGRADE_DEPLOYMENT_ICP4ACLUSTER_CR_TMP"`
                            if [[ ! -z "$baw_instance_flag" ]]; then
                                baw_object_store_name_tos=`${YQ_CMD} ".spec.baw_configuration.[${baw_instance_index}].case.tos_list.[${tos_instance_index}].object_store_name // \"\"" "$UPGRADE_DEPLOYMENT_ICP4ACLUSTER_CR_TMP"`
                                baw_connection_point_name_tos=`${YQ_CMD} ".spec.baw_configuration.[${baw_instance_index}].case.tos_list.[${tos_instance_index}].connection_point_name // \"\"" "$UPGRADE_DEPLOYMENT_ICP4ACLUSTER_CR_TMP"`
                                baw_target_environment_name=`${YQ_CMD} ".spec.baw_configuration.[${baw_instance_index}].case.tos_list.[${tos_instance_index}].target_environment_name // \"\"" "$UPGRADE_DEPLOYMENT_ICP4ACLUSTER_CR_TMP"`
                                desktop_id=`${YQ_CMD} ".spec.baw_configuration.[${baw_instance_index}].case.tos_list.[${tos_instance_index}].desktop_id // \"\"" "$UPGRADE_DEPLOYMENT_ICP4ACLUSTER_CR_TMP"`
                                if [[ (! -z "$baw_object_store_name_tos") && -z "$baw_connection_point_name_tos" ]]; then
                                    init_section=`${YQ_CMD} ".spec.initialize_configuration // \"\"" "$UPGRADE_DEPLOYMENT_ICP4ACLUSTER_CR_TMP"`
                                    if [[ -z "$init_section" ]]; then
                                        info "Not found initialize_configuration, continue..."
                                    else
                                        os_index=0
                                        while true; do
                                            os_flag=`${YQ_CMD} ".spec.initialize_configuration.ic_obj_store_creation.object_stores.[${os_index}].oc_cpe_obj_store_symb_name // \"\"" "$UPGRADE_DEPLOYMENT_ICP4ACLUSTER_CR_TMP"`
                                            if [[ ! -z "$os_flag" ]]; then
                                                enable_workflow=`${YQ_CMD} ".spec.initialize_configuration.ic_obj_store_creation.object_stores.[${os_index}].oc_cpe_obj_store_enable_workflow" "$UPGRADE_DEPLOYMENT_ICP4ACLUSTER_CR_TMP"`
                                                if [[ "$enable_workflow" == "true" ]]; then
                                                    tos_datasource_name=`${YQ_CMD} ".spec.initialize_configuration.ic_obj_store_creation.object_stores.[${os_index}].oc_cpe_obj_store_conn.dc_os_datasource_name // \"\"" "$UPGRADE_DEPLOYMENT_ICP4ACLUSTER_CR_TMP"`
                                                    tos_connection=`${YQ_CMD} ".spec.initialize_configuration.ic_obj_store_creation.object_stores.[${os_index}].oc_cpe_obj_store_workflow_pe_conn_point_name // \"\"" "$UPGRADE_DEPLOYMENT_ICP4ACLUSTER_CR_TMP"`
                                                    if [[ $baw_object_store_name_tos == $tos_datasource_name ]]; then
                                                        if [[ ! -z "$tos_datasource_name" ]]; then
                                                            ${YQ_CMD} -i ".spec.baw_configuration[${baw_instance_index}].case.tos_list[${tos_instance_index}].object_store_name = \"$tos_datasource_name\"" ${UPGRADE_DEPLOYMENT_ICP4ACLUSTER_CR_TMP}
                                                        fi
                                                        if [[ ! -z "$tos_connection" ]]; then
                                                            ${YQ_CMD} -i ".spec.baw_configuration[${baw_instance_index}].case.tos_list[${tos_instance_index}].connection_point_name = \"$tos_connection\"" ${UPGRADE_DEPLOYMENT_ICP4ACLUSTER_CR_TMP}
                                                        fi
                                                        # if [[ -z "$baw_target_environment_name" ]]; then
                                                        #     tmp_val_ds_name=$(echo "$tos_datasource_name" | tr '[:upper:]' '[:lower:]')
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
            # Disable sc_content_initialization/sc_content_verification
                ${YQ_CMD} -i '.spec.shared_configuration.sc_content_initialization = false' ${UPGRADE_DEPLOYMENT_ICP4ACLUSTER_CR_TMP}
                ${YQ_CMD} -i '.spec.shared_configuration.sc_content_verification = false' ${UPGRADE_DEPLOYMENT_ICP4ACLUSTER_CR_TMP}
            else
                ${YQ_CMD} -i '.spec.shared_configuration.olm_sc_content_initialization = false' ${UPGRADE_DEPLOYMENT_ICP4ACLUSTER_CR_TMP}
                ${YQ_CMD} -i '.spec.shared_configuration.olm_sc_content_verification = false' ${UPGRADE_DEPLOYMENT_ICP4ACLUSTER_CR_TMP}
            fi
            ${YQ_CMD} -i 'del(.spec.shared_configuration.sc_content_initialization_update_scim)' "${UPGRADE_DEPLOYMENT_ICP4ACLUSTER_CR_TMP}"

            # remove initialize_configuration/verify_configuration
            info "Remove initialize_configuration/verify_configuration from new version of CP4BA Custom Resource"
            ${YQ_CMD} -i 'del(.spec.verify_configuration)' "${UPGRADE_DEPLOYMENT_ICP4ACLUSTER_CR_TMP}"
            ${YQ_CMD} -i 'del(.spec.initialize_configuration)' "${UPGRADE_DEPLOYMENT_ICP4ACLUSTER_CR_TMP}"
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
        
        # Only always set as false when upgrade from 21.0.3/22.0.2
        if [[ $cr_version != "${CP4BA_RELEASE_BASE}" && $cr_version != "23.0.2" ]]; then
            # Set sc_restricted_internet_access always "false" in upgrade
            info "${YELLOW_TEXT}Setting \"shared_configuration.sc_egress_configuration.sc_restricted_internet_access\" to \"false\" when upgrade CP4BA deployment, you could change it according to your requirements of security.${RESET_TEXT}"
            printf "\n"
            ${YQ_CMD} -i '.spec.shared_configuration.sc_egress_configuration.sc_restricted_internet_access = false' ${UPGRADE_DEPLOYMENT_ICP4ACLUSTER_CR_TMP}
            # Set shared_configuration.enable_fips always "false" in upgrade
            info "${YELLOW_TEXT}Setting \"shared_configuration.enable_fips\" as \"false\" when upgrade CP4BA deployment, you could change it according to your requirements.${RESET_TEXT}"
            ${YQ_CMD} -i '.spec.shared_configuration.enable_fips = false' ${UPGRADE_DEPLOYMENT_ICP4ACLUSTER_CR_TMP}
            
            echo "Status of Content Process Engine SCIM configuration: $IS_SCIM_ENABLED"
            # set sc_skip_ldap_config when upgrade from 21.0.3/22.0.2 to 24.0.0+
            # DBACLD-157386: remove LDAP configuration when SCIM is configured
            if [[ "$(echo "$IS_SCIM_ENABLED" | tr '[:upper:]' '[:lower:]')" == "true" ]]; then
                    info "${YELLOW_TEXT}When Content Process Engine directory provider type is set to SCIM, setting \"shared_configuration.sc_skip_ldap_config\" as \"true\" when upgrade CP4BA deployment from version \"$cr_version\".${RESET_TEXT}"
                    ${YQ_CMD} -i '.spec.shared_configuration.sc_skip_ldap_config = true' ${UPGRADE_DEPLOYMENT_ICP4ACLUSTER_CR_TMP}
            else
                    info "${YELLOW_TEXT}When Content Process Engine directory provider type is set to LDAP (not SCIM), setting \"shared_configuration.sc_skip_ldap_config\" as \"false\" when upgrade CP4BA deployment from version \"$cr_version\".${RESET_TEXT}"
                    ${YQ_CMD} -i '.spec.shared_configuration.sc_skip_ldap_config = false' ${UPGRADE_DEPLOYMENT_ICP4ACLUSTER_CR_TMP}
            fi
        fi
        
        # For jsw.ibm.com/browse/DBACLD-153103 where we need to update the datavolume section of the CR to be in the right format
        if [[ $cr_version != "${CP4BA_RELEASE_BASE}" && ($cr_version == "21.0.3") ]]; then
            #function to update datastore section to the current format if required
            process_datavolumes ${UPGRADE_DEPLOYMENT_ICP4ACLUSTER_CR_TMP} $deployment_project_name
        fi

        # Set host_federated_portal as false in upgrade if it exist
        if [[ $cr_version != "${CP4BA_RELEASE_BASE}" && ($cr_version == "21.0.3" || $cr_version == "22.0.2") ]]; then
            if [[ (! " ${EXISTING_OPT_COMPONENT_ARR[@]} " =~ "baw_authoring") && (" ${EXISTING_PATTERN_ARR[@]} " =~ "workflow" || " ${EXISTING_PATTERN_ARR[@]} " =~ "workflow-workstreams") ]]; then
                baw_instance_index=0
                while true; do
                    baw_instance_flag=`${YQ_CMD} ".spec.baw_configuration.[${baw_instance_index}] // \"\"" "$UPGRADE_DEPLOYMENT_ICP4ACLUSTER_CR_TMP"`
                    if [[ ! -z "$baw_instance_flag" ]]; then

                        flag_host=`${YQ_CMD} ".spec.baw_configuration.[${baw_instance_index}].host_federated_portal // \"\"" "${UPGRADE_DEPLOYMENT_ICP4ACLUSTER_CR_TMP}"`
                        if [[ ! -z $flag_host ]]; then
                        ${YQ_CMD} -i ".spec.baw_configuration[${baw_instance_index}].host_federated_portal = \"false\"" ${UPGRADE_DEPLOYMENT_ICP4ACLUSTER_CR_TMP}
                        fi
                        ((baw_instance_index++))
                    else
                        break
                    fi
                done
            fi
        fi

        # Convert pattern array to list by common
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
        info "Remove pfs_configuration/pfs_bpd_database_init_job/elasticsearch_configuration from CP4BA Custom Resource"
        # if [[ ! (" ${EXISTING_OPT_COMPONENT_ARR[@]} " =~ "pfs") ]]; then
        #     EXISTING_OPT_COMPONENT_ARR=( "${EXISTING_OPT_COMPONENT_ARR[@]}" "pfs" )
        # fi
        # Workflow authoring/runtime and WfPS authoring use embedded PFS starting from $CP4BA_RELEASE_BASE
        ${CLI_CMD} patch icp4acluster $icp4acluster_cr_name -n $deployment_project_name --type=json -p='[{"op": "remove", "path": "/spec/pfs_configuration"}]' >/dev/null 2>&1
        ${CLI_CMD} patch icp4acluster $icp4acluster_cr_name -n $deployment_project_name --type=json -p='[{"op": "remove", "path": "/spec/elasticsearch_configuration"}]' >/dev/null 2>&1
        ${CLI_CMD} patch icp4acluster $icp4acluster_cr_name -n $deployment_project_name --type=json -p='[{"op": "remove", "path": "/spec/baw_configuration/0/pfs_bpd_database_init_job"}]' >/dev/null 2>&1
        ${CLI_CMD} patch icp4acluster $icp4acluster_cr_name -n $deployment_project_name --type=json -p='[{"op": "remove", "path": "/spec/workflow_authoring_configuration/pfs_bpd_database_init_job"}]' >/dev/null 2>&1
        # fi

        #Comment out workflow_authoring_configuration.database
        if [[ (" ${EXISTING_PATTERN_ARR[@]} " =~ "workflow") || (" ${EXISTING_PATTERN_ARR[@]} " =~ "workflow-process-service") ]]; then
            ${YQ_CMD} -i 'del(.spec.workflow_authoring_configuration.database)' "${UPGRADE_DEPLOYMENT_ICP4ACLUSTER_CR_TMP}"
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

        echo "${YELLOW_TEXT}[ATTENTION]: ${RESET_TEXT}${YELLOW_TEXT}DON'T SET ${RESET_TEXT}${RED_TEXT}\"shared_configuration.sc_egress_configuration.sc_restricted_internet_access\"${RESET_TEXT}${YELLOW_TEXT} AS ${RESET_TEXT}${RED_TEXT}\"true\"${RESET_TEXT}${YELLOW_TEXT} UNTIL AFTER YOU'VE COMPLETED THE CP4BA UPGRADE TO $CP4BA_RELEASE_BASE.${RESET_TEXT} ${GREEN_TEXT}(UNLESS YOU ALREADY HAD THIS SET TO \"true\" IN THE CP4BA 23.0.2.X)${RESET_TEXT}"
        prompt_press_any_key_to_continue
        printf "\n"
        select_apply_cr $UPGRADE_DEPLOYMENT_ICP4ACLUSTER_CR

        if [[ $APPLY_UPDATED_CR == "Yes" ]]; then
            info "Remove initialize_configuration/verify_configuration from CP4BA Custom Resource"
            ${CLI_CMD} patch icp4acluster $icp4acluster_cr_name -n $deployment_project_name --type=json -p='[{"op": "remove", "path": "/spec/initialize_configuration"}]' >/dev/null 2>&1
            ${CLI_CMD} patch icp4acluster $icp4acluster_cr_name -n $deployment_project_name --type=json -p='[{"op": "remove", "path": "/spec/verify_configuration"}]' >/dev/null 2>&1

            info "Applying the custom resource ${UPGRADE_DEPLOYMENT_ICP4ACLUSTER_CR}"
            ${CLI_CMD} annotate icp4acluster $icp4acluster_cr_name kubectl.kubernetes.io/last-applied-configuration- -n $deployment_project_name >/dev/null 2>&1
            ${CLI_CMD} apply -f ${UPGRADE_DEPLOYMENT_ICP4ACLUSTER_CR} -n $deployment_project_name >/dev/null 2>&1
            if [ $? -ne 0 ]; then
                fail "Failed to update IBM CP4BA Custom Resource."
            else
                echo "Done!"
                printf "\n"
            fi

            echo "${YELLOW_TEXT}[NEXT ACTION]:${RESET_TEXT}"
            echo "${YELLOW_TEXT}- How to check the overall upgrade status for CP4BA/zenService/IM.${RESET_TEXT}"
            echo "${YELLOW_TEXT}  [TIPS]: ${RESET_TEXT}The [upgradeDeploymentStatus] option will start necessary CP4BA operators (ibm-cp4a-operator/icp4a-foundation-operator) first to upgrade zenService, and then will start all other CP4BA operators when zenService upgrade done."
            CUR_DIR=$(realpath "$(dirname "${BASH_SOURCE[0]}")")
            SCRIPTS_DIR="$(realpath "$CUR_DIR/../..")"
            echo "  STEP1 ${RED_TEXT}(Required)${RESET_TEXT}:${GREEN_TEXT} # ${SCRIPTS_DIR}/cp4a-deployment.sh -m upgradeDeploymentStatus -n $TARGET_PROJECT_NAME${RESET_TEXT}"
        else
            initialize_cfg_flag=$(${CLI_CMD} get icp4acluster $icp4acluster_cr_name -n $deployment_project_name --no-headers --ignore-not-found -o 'jsonpath={.spec.initialize_configuration}') >/dev/null 2>&1
            verify_cfg_flag=$(${CLI_CMD} get icp4acluster $icp4acluster_cr_name -n $deployment_project_name --no-headers --ignore-not-found -o 'jsonpath={.spec.verify_configuration}') >/dev/null 2>&1
            printf "\n"

            echo "${YELLOW_TEXT}[NEXT ACTION]:${RESET_TEXT}"
            step_num=1
            for element in "${EXISTING_PATTERN_ARR[@]}"; do
                if [[ "$element" != "decisions" && "$element" == "decisions_ads" ]]; then
                    printf '%b\n' "\x1B[33;5m- Automation Decision Services capability is installed in this CP4BA deployment: \x1B[0m"
                    echo "  - STEP ${step_num} ${RED_TEXT}(Required)${RESET_TEXT}: Refer to the Knowledge Center: \"Upgrading IBM Automation Decision Services\" topic:"
                    echo "    - if upgrading from 21.0.3 or 22.0.2: [From https://www.ibm.com/docs/en/cloud-paks/cp-biz-automation/24.0.0 navigate to Upgrading --> Upgrading from 21.0.3 or 22.0.2 --> Upgrading CP4BA multi-pattern cluster from 21.0.3 or 22.0.2 --> Upgrading your IBM Cloud Pak deployment --> Updating the custom resource for each capability in your deployment --> Upgrading IBM Automation Decision Services]"
                    echo "    - if upgrading from 23.0.2: [From https://www.ibm.com/docs/en/cloud-paks/cp-biz-automation/24.0.0 navigate to Upgrading --> Upgrading from 23.0.2 --> Upgrading CP4BA multi-pattern cluster from 23.0.2 --> Upgrading your IBM Cloud Pak deployment from 23.0.2 --> Updating the custom resource for each capability in your deployment --> Upgrading IBM Automation Decision Services]"
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

            # output info for upgrading document process databases
            if [[ (" ${EXISTING_PATTERN_ARR[@]} " =~ "document_processing") ]]; then
                    printf '%b\n' "\x1B[33;5m- Automation Document Processing capability is installed in this CP4BA deployment: \x1B[0m"
                    echo "  - STEP ${step_num} ${RED_TEXT}(Required)${RESET_TEXT}: Upgrade the Automation Document Processing databases"
                    echo "    - If you are upgrading from 21.0.3 or 22.0.2, go to the following KC version:"
                    printf '%b\n' "      ${GREEN_TEXT}https://www.ibm.com/docs/en/cloud-paks/cp-biz-automation/$CP4BA_RELEASE_BASE${RESET_TEXT}\n      Navigate to:\n        - \"Upgrading from 21.0.3 or 22.0.2\"\n        - \"Upgrading your IBM Cloud Pak deployment\"\n        - \"Updating the custom resource for each capability in your deployment\"\n        - \"Upgrading IBM Automation Document Processing\""
                    echo "    - If you are upgrading from 23.0.2, go to the following KC version:"
                    printf '%b\n' "      ${GREEN_TEXT}https://www.ibm.com/docs/en/cloud-paks/cp-biz-automation/$CP4BA_RELEASE_BASE${RESET_TEXT}\n      Navigate to:\n        - \"Upgrading from 23.0.2\"\n        - \"Upgrading your IBM Cloud Pak deployment\"\n        - \"Updating the custom resource for each capability in your deployment\"\n        - \"Upgrading IBM Automation Document Processing\""
                    step_num=$((step_num + 1))

                    # NOTE: After discussion with ADP team, we will only output a link to KC since the details of the steps may change based on the ADP version.
                    # NOTE: The commented-out code below is included just in case we change our minds and want to include more specific info in our steps.

                    # aca_db_type=`cat $UPGRADE_DEPLOYMENT_ICP4ACLUSTER_CR_TMP | ${YQ_CMD} r - spec.datasource_configuration.dc_ca_datasource.dc_database_type`
                    # aca_db_server=`cat $UPGRADE_DEPLOYMENT_ICP4ACLUSTER_CR_TMP | ${YQ_CMD} r - spec.datasource_configuration.dc_ca_datasource.database_servername`
                    # aca_base_db=`cat $UPGRADE_DEPLOYMENT_ICP4ACLUSTER_CR_TMP | ${YQ_CMD} r - spec.datasource_configuration.dc_ca_datasource.database_name`
                    # aca_tenant_db=()

                    # if [[ $aca_db_type == "db2" ]]; then
                    #    aca_db_dir="DB2"
                    # else
                    #    aca_db_dir="PG"
                    # fi

                    # # Get tenant_db list
                    # item=0
                    # while true; do
                    #     tenant_name=`cat $UPGRADE_DEPLOYMENT_ICP4ACLUSTER_CR_TMP | ${YQ_CMD} r - spec.datasource_configuration.dc_ca_datasource.tenant_databases.[${item}]`
                    #     if [[ -z "$tenant_name" ]]; then
                    #         break
                    #     else
                    #         aca_tenant_db=( "${aca_tenant_db[@]}" "${tenant_name}" )
                    #         ((item++))
                    #     fi
                    # done

                    # # Convert aca_tenant_db array to list by common
                    # delim=""
                    # aca_tenant_db_joined=""
                    # for item in "${aca_tenant_db[@]}"; do
                    #     aca_tenant_db_joined="$aca_tenant_db_joined$delim$item"
                    #     delim=","
                    # done

                    # echo "    1. Upgrade the base database:"
                    # echo "      - Copy ${GREEN_TEXT}\"${PARENT_DIR}/ACA/configuration-ha/${aca_db_dir}\"${RESET_TEXT} to database server ${GREEN_TEXT}\"$aca_db_server\"${RESET_TEXT}"
                    # echo "      - Run ${GREEN_TEXT}\"${PARENT_DIR}/ACA/configuration-ha/${aca_db_dir}/UpgradeBaseDB.sh\"${RESET_TEXT} (or \"UpgradeBaseDB.bat\" if Windows) to update the base database: ${GREEN_TEXT}\"$aca_base_db\"${RESET_TEXT}"
                    # echo "    2. Upgrade the tenant databases:"
                    # echo "      - Run ${GREEN_TEXT}\"${PARENT_DIR}/ACA/configuration-ha/${aca_db_dir}/UpgradeTenantDB.sh\"${RESET_TEXT} (or \"UpgradeTenantDB.bat\" if Windows) for each tenant database: ${GREEN_TEXT}\"$aca_tenant_db_joined\"${RESET_TEXT}"
                    printf "\n"
            fi
            echo "${YELLOW_TEXT}- Refer to the Knowledge Center: \"Updating the custom resource for each capability in your deployment\" topic to complete REQUIRED steps for the installed pattern(s)."
            echo "  - if upgrading from 21.0.3 or 22.0.2: [From https://www.ibm.com/docs/en/cloud-paks/cp-biz-automation/24.0.0 navigate to Upgrading --> Upgrading from 21.0.3 or 22.0.2 --> Upgrading CP4BA multi-pattern cluster from 21.0.3 or 22.0.2 --> Upgrading your IBM Cloud Pak deployment --> Updating the custom resource for each capability in your deployment]"
            echo "  - if upgrading from 23.0.2: [From https://www.ibm.com/docs/en/cloud-paks/cp-biz-automation/24.0.0 navigate to Upgrading --> Upgrading from 23.0.2 --> Upgrading CP4BA multi-pattern cluster from 23.0.2 --> Upgrading your IBM Cloud Pak deployment from 23.0.2 --> Updating the custom resource for each capability in your deployment]${RESET_TEXT}"
            echo "${YELLOW_TEXT}- After reviewing or modifying the custom resource file \"${UPGRADE_DEPLOYMENT_ICP4ACLUSTER_CR}\", you need to follow the steps below to upgrade this CP4BA deployment.${RESET_TEXT}"
            # As a part of DBACLD-149126 solution we no longer needed the user to patch or annotate the custom resource file
            echo "  - STEP ${step_num} ${RED_TEXT}(Required)${RESET_TEXT}:${GREEN_TEXT} # ${CLI_CMD} apply -f ${UPGRADE_DEPLOYMENT_ICP4ACLUSTER_CR} -n $deployment_project_name${RESET_TEXT}"  && step_num=$((step_num + 1))

            printf "\n"
            echo "${YELLOW_TEXT}- How to check the overall upgrade status for CP4BA/zenService/IM.${RESET_TEXT}"
            echo "${YELLOW_TEXT}  [TIPS]: ${RESET_TEXT}The [upgradeDeploymentStatus] option will start necessary CP4BA operators (ibm-cp4a-operator/icp4a-foundation-operator) first to upgrade zenService, and then will start all other CP4BA operators when zenService upgrade done."
            CUR_DIR=$(realpath "$(dirname "${BASH_SOURCE[0]}")")
            SCRIPTS_DIR="$(realpath "$CUR_DIR/../..")"
            echo "  - STEP ${step_num} ${RED_TEXT}(Required)${RESET_TEXT}:${GREEN_TEXT} # ${SCRIPTS_DIR}/cp4a-deployment.sh -m upgradeDeploymentStatus -n $TARGET_PROJECT_NAME${RESET_TEXT}"
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
        fail "No Content or ICP4ACluster or WfPSRuntime custom resource found in the project \"$deployment_project_name\""
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

# Preserve Bastudio/BAW logstore size across upgrade by reading the live PVC.
# If missing in the merged temp CR, set it. No-op if already present.
# $1 = path to temp ICP4ACluster CR (e.g., ${UPGRADE_DEPLOYMENT_ICP4ACLUSTER_CR_TMP})
# $2 = project namespace (e.g., ${PROJECT_NAMESPACE})


function ensure_baw_logstore_size() {
  local tmp_cr="$1"
  local ns="$2"
  local pvc_name="cp4a-shared-log-pvc"

  if [[ -z "${YQ_CMD}" ]]; then
    echo "[WARN] YQ_CMD not set; cannot ensure logstore size." >&2
    return 0
  fi
  if [[ ! -f "$tmp_cr" ]]; then
    echo "[WARN] Temp CR not found: $tmp_cr" >&2
    return 0
  fi

  # Check what configurations exist
  local section_type_ba
  section_type_ba="$(${YQ_CMD} ".spec.bastudio_configuration | type" "$tmp_cr" 2>/dev/null)"

  if [[ "$section_type_ba" == "!!null" || -z "$section_type_ba" ]]; then
    echo "[INFO] bastudio_configuration not present—skipping BA Studio logstore sizing." >&2
    return 0
  fi

  # Read live PVC size (authoritative source)
  local live_size
  live_size=$(${CLI_CMD} get pvc "$pvc_name" -n "$ns" \
    -o=jsonpath='{.spec.resources.requests.storage}' 2>/dev/null)

  if [[ -z "$live_size" ]]; then
    echo "[INFO] Could not read PVC '${pvc_name}' size in namespace '${ns}'. Leaving CR unchanged." >&2
    return 0
  fi

  echo "[INFO] Ensuring BA Studio logstore size = ${live_size}" >&2

  # -----------------------------------
  # Handle bastudio_configuration
  # -----------------------------------
  if [[ "$section_type_ba" == "!!seq" ]]; then
    # Multiple BA Studio configs
    local cnt
    cnt=$(${YQ_CMD} ".spec.bastudio_configuration | length" "$tmp_cr" 2>/dev/null)

    for ((i=0; i<cnt; i++)); do
      ${YQ_CMD} -i \
        ".spec.bastudio_configuration[$i].storage = (.spec.bastudio_configuration[$i].storage // {})" \
        "$tmp_cr"

      ${YQ_CMD} -i \
        ".spec.bastudio_configuration[$i].storage.size_for_logstore = \
         (.spec.bastudio_configuration[$i].storage.size_for_logstore // \"${live_size}\")" \
        "$tmp_cr"
    done

  elif [[ "$section_type_ba" == "!!map" ]]; then
    # Single BA Studio config
    ${YQ_CMD} -i \
      ".spec.bastudio_configuration.storage = (.spec.bastudio_configuration.storage // {})" \
      "$tmp_cr"

    ${YQ_CMD} -i \
      ".spec.bastudio_configuration.storage.size_for_logstore = \
       (.spec.bastudio_configuration.storage.size_for_logstore // \"${live_size}\")" \
      "$tmp_cr"
  fi

  # -----------------------------------
  # Handle playback_server (optional)
  # -----------------------------------
  local pb_type
  pb_type="$(${YQ_CMD} ".spec.bastudio_configuration.playback_server | type" "$tmp_cr" 2>/dev/null)"

  if [[ "$pb_type" != "!!null" && -n "$pb_type" ]]; then
    ${YQ_CMD} -i \
      ".spec.bastudio_configuration.playback_server.storage = \
       (.spec.bastudio_configuration.playback_server.storage // {})" \
      "$tmp_cr"

    ${YQ_CMD} -i \
      ".spec.bastudio_configuration.playback_server.storage.size_for_logstore = \
       (.spec.bastudio_configuration.playback_server.storage.size_for_logstore // \"${live_size}\")" \
      "$tmp_cr"

    echo "[INFO] playback_server logstore size ensured (${live_size})" >&2
  fi
}

# Function to patch the cluster CR directly with logstore size (for ifix upgrades only)
function patch_cluster_baw_logstore_size() {
  local ns="$1"
  local cr_name="$2"
  local pvc_name="cp4a-shared-log-pvc"

  # Check if bastudio_configuration exists in cluster CR
  local bastudio_exists
  bastudio_exists=$(${CLI_CMD} get icp4acluster "${cr_name}" -n "${ns}" \
    -o jsonpath='{.spec.bastudio_configuration}' 2>/dev/null || echo "")

  if [[ -z "$bastudio_exists" || "$bastudio_exists" == "null" ]]; then
    return 0
  fi

  # Get live PVC size
  local live_size
  live_size=$(${CLI_CMD} get pvc "${pvc_name}" -n "${ns}" \
    -o jsonpath='{.spec.resources.requests.storage}' 2>/dev/null || echo "")

  if [[ -z "$live_size" ]]; then
    return 0
  fi

  # Check if it's array or single object
  local is_array
  is_array=$(${CLI_CMD} get icp4acluster "${cr_name}" -n "${ns}" \
    -o jsonpath='{.spec.bastudio_configuration[0]}' 2>/dev/null || echo "")

  if [[ -n "$is_array" ]]; then
    # Array - patch first element (typically there's only one)
    # Try to add storage section first, ignore error if exists
    ${CLI_CMD} patch icp4acluster "${cr_name}" -n "${ns}" --type=json -p='[
      {"op":"add","path":"/spec/bastudio_configuration/0/storage","value":{}}
    ]' >/dev/null 2>&1
    # Now add/replace the size_for_logstore value
    ${CLI_CMD} patch icp4acluster "${cr_name}" -n "${ns}" --type=merge -p='
      {"spec":{"bastudio_configuration":[{"storage":{"size_for_logstore":"'"${live_size}"'"}}]}}
    ' >/dev/null 2>&1
  else
    # Single object
    # Try to add storage section first, ignore error if exists
    ${CLI_CMD} patch icp4acluster "${cr_name}" -n "${ns}" --type=json -p='[
      {"op":"add","path":"/spec/bastudio_configuration/storage","value":{}}
    ]' >/dev/null 2>&1
    # Now add/replace the size_for_logstore value using merge patch
    ${CLI_CMD} patch icp4acluster "${cr_name}" -n "${ns}" --type=merge -p='
      {"spec":{"bastudio_configuration":{"storage":{"size_for_logstore":"'"${live_size}"'"}}}}
    ' >/dev/null 2>&1
  fi
}
