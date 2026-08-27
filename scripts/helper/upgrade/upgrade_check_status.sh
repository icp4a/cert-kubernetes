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
# Import common utilities and environment variables
# source "${CUR_DIR}/../common.sh"

#list of versions for which direct upgrade to 24.0.1 is not supported
# upgrade_blocked_versions=("21.3." "23.1." "22.1." "22.2." "23.2.")
# #list of versions for which direct upgrade to 24.0.1 is supported
# upgrade_valid_versions=("24.0." "24.1.")

#Determine if it's an Ifix to ifix upgrade or a n-1 upgrade using CSV
# Format of CSV x.y.z where x is major version, y is minor version and z is ifix version
# For example: 
# - 24.0.1 version will have 24.1.0 in the CSV
# - 24.0.1-IF001 version will 24.1.1 in the CSV
# - 25.0.0-GA version will have 25.0.0 in the CSV 
# The rules are:
# 1. n-1 upgrade: Use the desired major version such as 24 from the CP4BA_CSV_VERSION in the common.sh  to compare with the current install version
#   - If x version of the current CSV is equal to the desired major version, then it's a n-1 upgrade.  For example, if the current version is 24.0.0-IF003 (24.0.3) and the desired version is 24.0.1 (24.1.0), then it's a n-1 upgrade
#   - If x version of the current CSV is equal to the desired major version (x+1), then it's the n-1 upgrade. For example, if the current version is 24.x and the desired version is 25.x, then it's a n-1 upgrade
# 2. Ifix to Ifix upgrade: Use the desired major version such as 24 from the CP4BA_CSV_VERSION in the common.sh  to compare with the current install version
#   - If x.y version of the current CSV is equal to x.y of the desired major version, then it's an Ifix to Ifix upgrade. For example, if the current version is 24.0.0-IF003 (24.0.3) and the desired version is 24.0.0-IF004 (24.0.4), then it's an Ifix to Ifix upgrade
# The function will set the is_ifix_to_ifix_upgrade flag to 1 if it's an Ifix to Ifix upgrade and 0 if it's a n-1 upgrade
function determine_type_of_upgrade() {
    info "Determining the type of upgrade"
    local current_version=$1
    local current_version_major=$(echo "$current_version" | cut -d'.' -f1)
    local current_version_minor=$(echo "$current_version" | cut -d'.' -f2)
    local desired_version="${CP4BA_CSV_VERSION//v/}"
    local desired_version_major=$(echo "$desired_version" | cut -d'.' -f1)
    local desired_version_minor=$(echo "$desired_version" | cut -d'.' -f2)
    if [[ $current_version_major"."$current_version_minor == $desired_version_major"."$desired_version_minor ]]; then
        export is_ifix_to_ifix_upgrade="true"
        info "This is an upgrade from $current_version to $desired_version which is an Ifix to Ifix upgrade"
    else
        export is_ifix_to_ifix_upgrade="false"
        info "This is an upgrade from $current_version to $desired_version which is a major release upgrade"
    fi

}
# This function is used in check_cp4ba_operator_version where it will check the version of the operator and compare it with the array of minimum supported upgrade versions
# It will fail if the operator version is not less than the minimum supported upgrade version.
# This function takes 3 arguments:
# 1. current_csv_version: The csv of the version that needs to be checked such as "24.0.0", "24.0.4", "24.0.1"
# 2. The internal flag that will allow the customer to do direct upgrade to the desired version even though the current version is not in the minimum supported upgrade versions
# 3. The current cpfs csv version so that it can be used to compare against the cpfs csv version in the common.sh defined as CS_OPERATOR_VERSION.
# 4. The function will return true if the version is supported and false if it is not supported
function check_cp4ba_minimum_version(){

    local existing_cp4ba_csv_version=$1
    local _allow_direct_upgrade=$2
    local existing_cpfs_csv_version=$3
    local cpfs_csv_version=${CS_OPERATOR_VERSION//v/}
    local versions_string="${MINIMUM_SUPPORTED_UPGRADE_VERSIONS[*]}"
    local valid_cp4ba_version=false
    local valid_cpfs_version=false
    valid_version=false

    # Check for CP4BA version  by comparing the existing cp4ba csv version with the minimum supported upgrade versions defined in the array
    info "Checking existing CP4BA version $existing_cp4ba_csv_version against the minimum supported upgrade version(s) ($versions_string) defined in the common.sh"
    info "Checking the existing CPfS version $existing_cpfs_csv_version against the $cpfs_csv_version defined in the common.sh"
    for abs_min in "${MINIMUM_SUPPORTED_UPGRADE_VERSIONS[@]}"; do
        # Extract major.minor from both versions
        local abs_major_minor="${abs_min%.*}"
        local curr_major_minor="${existing_cp4ba_csv_version%.*}"
   
        if [[ "$curr_major_minor" == "$abs_major_minor" ]]; then
            # Print the versions, sort 2 number using version sort which understands the versioning scheme(24.1.0 is after 24.1.2), take the first/smallest one
            # and compare it with the absolute minimum version. If the smallest version is abs_min, then the current version is equal or greater than the abs_min
            if [[ "$(printf '%s\n' "$abs_min" "$existing_cp4ba_csv_version" | sort -V | head -n1)" = "$abs_min"  && "$_allow_direct_upgrade" != 1 ]]; then  
                valid_cp4ba_version=true

            else
                fail "The current IBM Cloud Pak for Business Automation (CP4BA) version you are upgrading from is $existing_cp4ba_csv_version  and it does not meet the minimum requirement. Please upgrade CP4BA to "$abs_min" or higher before upgrading to "$CP4BA_CSV_VERSION"."
                valid_cp4ba_version=false
                break
            fi

        fi
    done

    # Check for CPFS version by comparing existing_cpfs_csv_version with the cpfs_csv_version which is CS_OPERATOR_VERSION without the `v` prefix
    # If the existing_cpfs_csv_version is less than or equal the cpfs_csv_version, then it's a valid version
    # If the existing_cpfs_csv_version is greater than the cpfs_csv_version, then it's not a valid version
    if [[ "$valid_cp4ba_version" == true ]]; then
        # Compare versions using sort -V
        if [[ "$(printf '%s\n' "$existing_cpfs_csv_version" "$cpfs_csv_version" | sort -V | head -n1)" = "$existing_cpfs_csv_version"  ]]; then
            valid_cpfs_version=true
        else
            valid_cpfs_version=false
            fail "The current IBM Cloud Pak foundational services (CPfs) version you are upgrading from is $existing_cpfs_csv_version and it is newer than the CPfs version ("$cpfs_csv_version") you are upgrading to. If you wish to upgrade to the CP4BA release stream $CP4BA_RELEASE_BASE you must check for newer $CP4BA_RELEASE_BASE IFIX versions that contain CPFS $existing_cpfs_csv_version or newer. You may have to wait until a new $CP4BA_RELEASE_BASE IFIX version is released before you can upgrade."

        fi
    fi

    if [[ ("$valid_cp4ba_version" == true && "$valid_cpfs_version" == true) || ("$_allow_direct_upgrade" == 1) ]]; then
        export valid_version=true
        success "The IBM Cloud Pak for Business Automation version "$existing_cp4ba_csv_version" with Cloud Pak foundational services version "$existing_cpfs_csv_version" is supported for upgrade to "$CP4BA_CSV_VERSION"."
    else
        export valid_version=false
        fail "The IBM Cloud Pak for Business Automation version "$existing_cp4ba_csv_version" with Cloud Pak foundational services version "$existing_cpfs_csv_version" is NOT supported for upgrade to "$CP4BA_CSV_VERSION"."
        exit 1
    fi
    
}

# function for checking operator version
function check_cp4ba_operator_version(){
    local project_name=$1
    local allow_direct_upgrade=$2
    local ALL_NAMESPACE_NAME="openshift-operators"
    local maxRetry=5

#DBACLD-202417: Update logic to check for the MINIMUM_SUPPORTED_UPGRADE_VERSIONS array before proceeding with the upgrade checks. If it's empty then we will exit with a message indicating that only refresh installation is supported.
    if [[ ${#MINIMUM_SUPPORTED_UPGRADE_VERSIONS[@]} -eq 0 ]]; then
        info "NOTE: Only fresh installation of CP4BA "$CP4BA_CSV_VERSION" is supported. Upgrading from any previous releases to CP4BA "$CP4BA_CSV_VERSION" is not supported as it is a Limited Support Release (LSR)"
        exit 1
    fi

    info "Checking the version of IBM Cloud Pak for Business Automation Operator"

    cp4a_operator_csv_name_target_ns=$(${CLI_CMD} get csv -n $project_name --no-headers --ignore-not-found | grep "IBM Cloud Pak for Business Automation" | awk '{print $1}')
    cp4a_operator_csv_name_allnamespace_ns=$(${CLI_CMD} get csv -n $ALL_NAMESPACE_NAME --no-headers --ignore-not-found | grep "IBM Cloud Pak for Business Automation" | awk '{print $1}')

    cpfs_operator_csv_name_target_ns=$(${CLI_CMD} get csv -n $project_name --no-headers --ignore-not-found | grep "IBM Cloud Pak foundational services" | awk '{print $1}')
    cpfs_operator_csv_name_allnamespace_ns=$(${CLI_CMD} get csv -n $ALL_NAMESPACE_NAME --no-headers --ignore-not-found | grep "IBM Cloud Pak foundational services" | awk '{print $1}')

    if [[ -z $cp4a_operator_csv_name_allnamespace_ns && -z $cp4a_operator_csv_name_target_ns ]]; then
        fail "No IBM Cloud Pak for Business Automation Operator found in both \"$project_name\" and \"$ALL_NAMESPACE_NAME\" project."
        warning "Input correct project name for CP4BA."
        exit 1
    fi
    if [[ -z $cpfs_operator_csv_name_target_ns && -z $cpfs_operator_csv_name_allnamespace_ns ]]; then
        fail "No IBM Cloud Pak foundational services CSV found in both \"$project_name\" and \"$ALL_NAMESPACE_NAME\" project."
        warning "Input correct project name for CP4BA."
        exit 1
    fi
    info "Checking the IBM Foundational Services Operator CSV version"
    for ((retry=0;retry<=${maxRetry};retry++)); do
        valid_version=false  #this is flag to check if a valid for direct upgrade CP4BA operator version was found
        if [[ -z $cp4a_operator_csv_name_allnamespace_ns && (! -z $cp4a_operator_csv_name_target_ns) ]]; then
            success "Found IBM Cloud Pak for Business Automation Operator deployed in the project \"$project_name\"."
            ALL_NAMESPACE_FLAG="No"
            TEMP_OPERATOR_PROJECT_NAME=$project_name
            # We will only use the current csv versions for cp4ba and cpfs operators to perform any pre upgrade version checks.
            # https://jsw.ibm.com/browse/DBACLD-180433
            cp4a_operator_csv_version=$(${CLI_CMD} get csv $cp4a_operator_csv_name_target_ns -n $project_name --no-headers --ignore-not-found -o 'jsonpath={.spec.version}')
            cpfs_operator_csv_version=$(${CLI_CMD} get csv $cpfs_operator_csv_name_target_ns -n $project_name --no-headers --ignore-not-found -o 'jsonpath={.spec.version}')
            success "IBM Foundational Services Operator version is $cpfs_operator_csv_version"
         
        elif [[ (! -z $cp4a_operator_csv_name_allnamespace_ns) && (! -z $cp4a_operator_csv_name_target_ns) ]]; then
            success "Found IBM Cloud Pak for Business Automation Operator deployed as AllNamespace mode in the project \"$ALL_NAMESPACE_NAME\"."
            ALL_NAMESPACE_FLAG="Yes"
            project_name="openshift-operators"
            TEMP_OPERATOR_PROJECT_NAME="openshift-operators"
            # We will only use the current csv versions for cp4ba and cpfs operators to perform any pre upgrade version checks.
            # https://jsw.ibm.com/browse/DBACLD-180433
            cp4a_operator_csv_version=$(${CLI_CMD} get csv $cp4a_operator_csv_name_allnamespace_ns -n $project_name --no-headers --ignore-not-found -o 'jsonpath={.spec.version}')
            cpfs_operator_csv_version=$(${CLI_CMD} get csv $cpfs_operator_csv_name_allnamespace_ns -n $project_name --no-headers --ignore-not-found -o 'jsonpath={.spec.version}')
            success "IBM Foundational Services Operator version is $cpfs_operator_csv_version"
        fi
        

        # Check ConfigMaps for original CSV version before validation
        # Priority: ibm-cp4ba-shared-info, then ibm-cp4ba-content-shared-info
        #info "Checking for original CP4BA version in ConfigMaps..."
        local cm_original_version=""
        local cm_name=""
        
        # Try ibm-cp4ba-shared-info first
        if ${CLI_CMD} get configmap ibm-cp4ba-shared-info -n ${CP4BA_SERVICES_NS} --ignore-not-found &>/dev/null; then
            cm_name="ibm-cp4ba-shared-info"
            cm_original_version=$(${CLI_CMD} get configmap ibm-cp4ba-shared-info -n ${CP4BA_SERVICES_NS} -o jsonpath='{.data.cp4ba_original_csv_ver_for_upgrade_script}' 2>/dev/null || echo "")
        # If not found, try ibm-cp4ba-content-shared-info
        elif ${CLI_CMD} get configmap ibm-cp4ba-content-shared-info -n ${CP4BA_SERVICES_NS} --ignore-not-found &>/dev/null; then
            cm_name="ibm-cp4ba-content-shared-info"
            cm_original_version=$(${CLI_CMD} get configmap ibm-cp4ba-content-shared-info -n ${CP4BA_SERVICES_NS} -o jsonpath='{.data.cp4ba_original_csv_ver_for_upgrade_script}' 2>/dev/null || echo "")
        fi
        
        # If ConfigMap has original version and it's less than current CSV version, use it
        if [[ ! -z "$cm_original_version" ]]; then
            #info "Found cp4ba_original_csv_ver_for_upgrade_script: $cm_original_version in ConfigMap $cm_name"
            # Compare versions using sort -V (version sort)
            # If cm_original_version is the smaller one (comes first), use it
            if [[ "$(printf '%s\n' "$cm_original_version" "$cp4a_operator_csv_version" | sort -V | head -n1)" = "$cm_original_version" ]]; then
                info "Using original version $cm_original_version from ConfigMap (current CSV version: $cp4a_operator_csv_version) since the upgrade to $CP4BA_RELEASE_BASE did not completely finish."
                cp4a_operator_csv_version="$cm_original_version"
            else
                info "ConfigMap version $cm_original_version is not less than current CSV version $cp4a_operator_csv_version, using current CSV version"
            fi
        fi

        if [[ ! -z $CP4BA_ORIGINAL_CSV_VERSION ]]; then
            CP4BA_ORIGINAL_CSV_VERSION=$(sed -e 's/^"//' -e 's/"$//' <<<"$CP4BA_ORIGINAL_CSV_VERSION")
            cp4a_operator_csv_version=$CP4BA_ORIGINAL_CSV_VERSION
        fi
 
        # Calling check_cp4ba_minimum_version function to check if the current version is in the minimum supported upgrade versions
        check_cp4ba_minimum_version "$cp4a_operator_csv_version" "$allow_direct_upgrade" "$cpfs_operator_csv_version"
        # Calling determine_type_of_upgrade function to determine the type of upgrade
        determine_type_of_upgrade "$cp4a_operator_csv_version"
        if [[ "$valid_version" == true ]]; then
            break
        fi
        if [[ "$cp4a_operator_csv_version" != "${CP4BA_CSV_VERSION//v/}" ]]; then
            if [[ $retry -eq ${maxRetry} ]]; then
                info "Timeout Checking for the version of IBM Cloud Pak for Business Automation in the project \"$project_name\""
                exit 1
            else
                sleep 2
                printf '%s' "..."
                continue
            fi
        fi
    done
    # success "Found the IBM Cloud Pak for Business Automation Operator $cp4a_operator_csv_version \n"
}

# function for checking operator version
function check_content_operator_version(){
    local project_name=$1
    local maxRetry=5
    info "Checking the version of IBM CP4BA Content Cortex Operator"
    for ((retry=0;retry<=${maxRetry};retry++)); do
        cp4a_content_operator_csv_name=$(${CLI_CMD} get csv -n $project_name --no-headers --ignore-not-found | grep "IBM CP4BA Content Cortex" | awk '{print $1}')
        cp4a_content_operator_csv_version=$(${CLI_CMD} get csv $cp4a_content_operator_csv_name -n $project_name --no-headers --ignore-not-found -o 'jsonpath={.spec.version}')

        if [[ "$cp4a_content_operator_csv_version" == "${CP4BA_CSV_VERSION//v/}" ]]; then
            success "The current IBM CP4BA Content Cortex Operator is already ${CP4BA_CSV_VERSION//v/}"
            break
        elif [[ "$cp4a_content_operator_csv_version" != "${CP4BA_CSV_VERSION//v/}" ]]; then
            if [[ $retry -eq ${maxRetry} ]]; then
                info "Timeout Checking for the version of IBM CP4BA Content Cortex Operator in the project \"$project_name\""
                exit 1
            else
                sleep 2
                printf '%s' "..."
                continue
            fi
        fi
    done
    # success "Found the IBM CP4BA Content Cortex Operator $cp4a_content_operator_csv_version \n"
}

# Utility function to check whether an operator CSV has succeeded and whether its pod is running.
# Arguments:
#   $1 - namespace where the operator resources are installed
#   $2 - csv prefix/name prefix, for example: ibm-cp4a-operator
#   $3 - expected CSV version, for example: 25.0.0
#   $4 - pod label value used in label selector name=<value>
#   $5 - display name used in log/success/error messages
#   $6 - check mode for channel-only validation or full pod validation
#   $7 - release label value, if required by the pod selector; pass "" if not needed
#   $8 - max retry count
function check_operator_pod_initialization() {
    local namespace="$1"
    local csv_prefix="$2"
    local csv_version="$3"
    local pod_label="$4"
    local display_name="$5"
    local check_channel="$6"
    local release_label="$7"
    local max_retry="${8:-30}"

    local retry
    local isReady=""
    local pod_name=""
    local csv_version_found=""

    echo "****************************************************************************"
    info "Checking for ${display_name} pod initialization"

    for ((retry=0; retry<=max_retry; retry++)); do
        isReady=$(${CLI_CMD} get csv "${csv_prefix}.${csv_version}" \
            --no-headers --ignore-not-found -n "$namespace" \
            -o jsonpath='{.status.phase}')

        if [[ -z "$isReady" ]]; then
            csv_version_found=$(${CLI_CMD} get csv --no-headers --ignore-not-found -n "$namespace" | \
                grep "${csv_prefix}.v" | awk '{print $1}' | head -1)

            if [[ -n "$csv_version_found" ]]; then
                csv_version_found=$(${CLI_CMD} get csv "$csv_version_found" \
                    --no-headers --ignore-not-found -n "$namespace" \
                    -o jsonpath='{.spec.version}')
            fi

            if [[ "v$csv_version_found" != "$csv_version" ]]; then
                if [[ $retry -eq $max_retry ]]; then
                    fail "Failed to upgrade the ${display_name} to ${csv_prefix}.${csv_version} in the project \"$namespace\""
                    msg "Check the Subscription and ClusterServiceVersions and then fix issue first."
                    exit 1
                else
                    sleep 30
                    printf '%s' "..."
                    continue
                fi
            fi

        elif [[ "$isReady" != "Succeeded" ]]; then
            if [[ $retry -eq $max_retry ]]; then
                printf "\n"
                warning "Timeout waiting for ${display_name} to start"
                printf '%b\n' "\x1B[1mCheck the status of Pod by issuing the following command:\x1B[0m"
                echo "${CLI_CMD} describe pod \$(${CLI_CMD} get pod -n $namespace | grep ${pod_label} | awk '{print \$1}') -n $namespace"
                printf "\n"
                printf '%b\n' "\x1B[1mCheck the status of ReplicaSet by issuing the following command:\x1B[0m"
                echo "${CLI_CMD} describe rs \$(${CLI_CMD} get rs -n $namespace | grep ${pod_label} | awk '{print \$1}') -n $namespace"
                printf "\n"
                exit 1
            else
                sleep 30
                printf '%s' "..."
                continue
            fi

        elif [[ "$isReady" == "Succeeded" ]]; then
            if [[ "$check_channel" != "channel" ]]; then
                if [[ -n "$release_label" ]]; then
                    pod_name=$(${CLI_CMD} get pod -l"name=${pod_label},release=${release_label}" \
                        -n "$namespace" \
                        -o 'custom-columns=NAME:.metadata.name,PHASE:.status.phase,READY:.status.containerStatuses[0].ready,DELETED:.metadata.deletionTimestamp' \
                        --no-headers --ignore-not-found | \
                        grep 'Running' | grep 'true' | grep '<none>' | head -1 | awk '{print $1}')
                else
                    pod_name=$(${CLI_CMD} get pod -l"name=${pod_label}" \
                        -n "$namespace" \
                        -o 'custom-columns=NAME:.metadata.name,PHASE:.status.phase,READY:.status.containerStatuses[0].ready,DELETED:.metadata.deletionTimestamp' \
                        --no-headers --ignore-not-found | \
                        grep 'Running' | grep 'true' | grep '<none>' | head -1 | awk '{print $1}')
                fi

                if [[ -z "$pod_name" ]]; then
                    error "${display_name} pod is NOT running"
                    CHECK_CP4BA_OPERATOR_RESULT=( "${CHECK_CP4BA_OPERATOR_RESULT[@]}" "FAIL" )
                    break
                else
                    success "${display_name} is running"
                    info "Pod: $pod_name"
                    CHECK_CP4BA_OPERATOR_RESULT=( "${CHECK_CP4BA_OPERATOR_RESULT[@]}" "PASS" )
                    break
                fi
            else
                success "${display_name} is in the phase of \"$isReady\"!"
                CHECK_CP4BA_OPERATOR_RESULT=( "${CHECK_CP4BA_OPERATOR_RESULT[@]}" "PASS" )
                break
            fi
        fi
    done

    echo "****************************************************************************"
    echo
}


# Function to check the current operator status after upgrade
# Used in upgradeOperatorStatus mode
function check_operator_status(){
    local maxRetry=60
    local project_name=$1
    local check_mode=$2 # full or part
    local check_channel=$3
    CHECK_CP4BA_OPERATOR_RESULT=()

    
    if [[ "$check_mode" == "full" ]]; then
        
        # Check Common Service Operator upgrade status
        check_operator_pod_initialization "$project_name" "ibm-common-service-operator" "$CS_OPERATOR_VERSION" "ibm-common-service-operator" "IBM Cloud Pak foundational Operator" "$check_channel" "" 30

        # Check Usage metering service Operator upgrade status
        check_operator_pod_initialization "$project_name" "ibm-usage-metering-operator" "$UMS_CSV_VERSION" "ibm-usage-metering-operator" "IBM Usage Metering Operator" "$check_channel" "" 30
        
        # Check CP4BA operator upgrade status
        check_operator_pod_initialization "$project_name" "ibm-cp4a-operator" "$CP4BA_CSV_VERSION" "ibm-cp4a-operator" "IBM Cloud Pak for Business Automation (CP4BA) multi-pattern Operator" "$check_channel" "$CP4BA_RELEASE_BASE" 30
        
        # Check IBM Operational Decision Manager operator upgrade status
        check_operator_pod_initialization "$project_name" "ibm-odm-operator" "$CP4BA_CSV_VERSION" "ibm-odm-operator" "IBM Operational Decision Manager operator" "$check_channel" "" 30
        
        # Check IBM Document Processing Engine operator upgrade status
        arch_type=$(${CLI_CMD} get cm cluster-config-v1 -n kube-system --no-headers --ignore-not-found -o yaml | grep -i architecture | tail -1 | awk '{print $2}')
        if [[ "$arch_type" == "amd64" ]]; then
            check_operator_pod_initialization "$project_name" "ibm-dpe-operator" "$CP4BA_CSV_VERSION" "ibm-dpe-operator" "IBM Document Processing Engine operator" "$check_channel" "" 30
        fi
        
        # Check IBM CP4BA Insights Engine operator upgrade status
        check_operator_pod_initialization "$project_name" "ibm-insights-engine-operator" "$CP4BA_CSV_VERSION" "ibm-insights-engine-operator" "IBM CP4BA Insights Engine operator" "$check_channel" "" 30
        
        # Check IBM CCX AI Services operator upgrade status
        check_operator_pod_initialization "$project_name" "ibm-ccx-ai-services-operator" "$CP4BA_CSV_VERSION" "ibm-ccx-ai-services-operator" "IBM Content Cortex AI Services operator" "$check_channel" "" 30
    fi


    # Check IBM CP4BA Content Cortex operator upgrade status
    check_operator_pod_initialization "$project_name" "ibm-content-operator" "$CP4BA_CSV_VERSION" "ibm-content-operator" "IBM CP4BA Content Cortex operator" "$check_channel" "$CP4BA_RELEASE_BASE" 30

    # Check CP4BA Foundation operator upgrade status
    check_operator_pod_initialization "$project_name" "icp4a-foundation-operator" "$CP4BA_CSV_VERSION" "icp4a-foundation-operator" "IBM CP4BA Foundation operator" "$check_channel" "$CP4BA_RELEASE_BASE" 30

    # Check IBM CP4BA Automation Decision Service operator upgrade status
    check_operator_pod_initialization "$project_name" "ibm-ads-operator" "$CP4BA_CSV_VERSION" "ibm-ads-operator" "IBM CP4BA Automation Decision Service operator" "$check_channel" "" 30


    # Check IBM CP4BA Workflow Process Service operator upgrade status
    check_operator_pod_initialization "$project_name" "ibm-cp4a-wfps-operator" "$CP4BA_CSV_VERSION" "ibm-cp4a-wfps-operator" "IBM CP4BA Workflow Process Service operator" "$check_channel" "" 30

    # Check IBM CP4BA Process Federation Server operator upgrade status
    check_operator_pod_initialization "$project_name" "ibm-pfs-operator" "$CP4BA_CSV_VERSION" "ibm-pfs-operator" "IBM CP4BA Process Federation Server operator" "$check_channel" "" 30

    # Check IBM CP4BA Workflow operator upgrade status
    check_operator_pod_initialization "$project_name" "ibm-workflow-operator" "$CP4BA_CSV_VERSION" "ibm-workflow-operator" "IBM CP4BA Workflow operator" "$check_channel" "" 30

}


# This function goes over the different patterns and builds a table that is displayed with the current status
function check_cp4ba_deployment_status(){
    local project_name=$1
    local current_cr_kind=$2
    local current_cr_name=$3
    local current_cr_details_location=$4
    # local meta_name=$2
    UPGRADE_DEPLOYMENT_ICP4ACLUSTER_CR_BAK=${CUR_DIR}/cp4ba-upgrade/project/$project_name/custom_resource/backup/icp4acluster_cr_backup.yaml
    UPGRADE_DEPLOYMENT_CONTENT_CR_BAK=${CUR_DIR}/cp4ba-upgrade/project/$project_name/custom_resource/backup/content_cr_backup.yaml

    # Get the current status of the top level CR before we process what the status of each deployed component is
    ${CLI_CMD} get $current_cr_kind $current_cr_name -n $project_name -o yaml > ${current_cr_details_location}
    
    # Instead of checking if a crd type content is present and then checking if it is a top level CR and then taking the CR details,
    # we can just use the variables loaded by the retrieve_custom_resource_details function which does all this at the start of each mode
    if [[ "$current_cr_kind" == "content" ]]; then
        source ${CUR_DIR}/helper/upgrade/deployment_check/fncm_status.sh
        # Add FNCM component status variables to overall status array
        CP4BA_COMPONENT_STATUS_VALUES+=("$CP4BA_CPE_DEPLOYMENT_STATUS" "$CP4BA_GRAPHQL_DEPLOYMENT_STATUS" "$CP4BA_CSS_DEPLOYMENT_STATUS" "$CP4BA_CMIS_DEPLOYMENT_STATUS" "$CP4BA_IER_DEPLOYMENT_STATUS" "$CP4BA_ICC_DEPLOYMENT_STATUS" "$CP4BA_TM_DEPLOYMENT_STATUS" "$CP4BA_BAN_DEPLOYMENT_STATUS" "$CP4BA_ES_DEPLOYMENT_STATUS" "$CP4BA_CCXMO_DEPLOYMENT_STATUS")
        bai_flag=`${YQ_CMD} ".spec.content_optional_components.bai" "$current_cr_details_location"`
        if [[ ! -z "$bai_flag" ]]; then
            bai_flag=$(echo "$bai_flag" | tr '[:upper:]' '[:lower:]')
            if [[ "${bai_flag}" == "true" ]]; then
                source ${CUR_DIR}/helper/upgrade/deployment_check/bai_status.sh
                CP4BA_COMPONENT_STATUS_VALUES+=("$CP4BA_BAI_DEPLOYMENT_STATUS")
            fi
        fi
        css_flag=`${YQ_CMD} ".spec.content_optional_components.css" "$current_cr_details_location"`
        css_flag=$(echo "$css_flag" | tr '[:upper:]' '[:lower:]')
    elif [[ "$current_cr_kind" == "icp4acluster" ]]; then
        
        convert_olm_cr "${current_cr_details_location}"
        if [[ $olm_cr_flag == "No" ]]; then
            #this variable is being used to check what the version of CP4BA was used before upgrade and is used later in a check if some alert message is to be printed
            # initial_app_version=`cat $UPGRADE_DEPLOYMENT_ICP4ACLUSTER_CR_BAK | ${YQ_CMD} r - spec.appVersion`
            existing_pattern_list=""
            existing_opt_component_list=""
            EXISTING_PATTERN_ARR=()
            EXISTING_OPT_COMPONENT_ARR=()
            existing_pattern_list=`${YQ_CMD} ".spec.shared_configuration.sc_deployment_patterns" "$current_cr_details_location"`
            existing_opt_component_list=`${YQ_CMD} ".spec.shared_configuration.sc_optional_components" "$current_cr_details_location"`

            OIFS=$IFS
            IFS=',' read -r -a EXISTING_PATTERN_ARR <<< "$existing_pattern_list"
            IFS=',' read -r -a EXISTING_OPT_COMPONENT_ARR <<< "$existing_opt_component_list"
            IFS=$OIFS
        fi
        #################### FNCM #######################
        if [[ " ${EXISTING_PATTERN_ARR[@]}" =~ "workflow-runtime" || " ${EXISTING_PATTERN_ARR[@]}" =~ "workflow-authoring" || " ${EXISTING_PATTERN_ARR[@]}" =~ "content" || " ${EXISTING_PATTERN_ARR[@]}" =~ "document_processing" || "${EXISTING_OPT_COMPONENT_ARR[@]}" =~ "ae_data_persistence" ]]; then
            source ${CUR_DIR}/helper/upgrade/deployment_check/fncm_status.sh
            # Add FNCM component status variables to array
            CP4BA_COMPONENT_STATUS_VALUES+=("$CP4BA_CPE_DEPLOYMENT_STATUS" "$CP4BA_GRAPHQL_DEPLOYMENT_STATUS" "$CP4BA_CSS_DEPLOYMENT_STATUS" "$CP4BA_CMIS_DEPLOYMENT_STATUS" "$CP4BA_IER_DEPLOYMENT_STATUS" "$CP4BA_ICC_DEPLOYMENT_STATUS" "$CP4BA_TM_DEPLOYMENT_STATUS" "$CP4BA_BAN_DEPLOYMENT_STATUS" "$CP4BA_ES_DEPLOYMENT_STATUS" "$CP4BA_CCXMO_DEPLOYMENT_STATUS")
        fi

        #################### ADP #######################
        if [[ " ${EXISTING_PATTERN_ARR[@]}" =~ "document_processing" ]]; then
            source ${CUR_DIR}/helper/upgrade/deployment_check/adp_status.sh
            CP4BA_COMPONENT_STATUS_VALUES+=("$CP4BA_ADP_ACA_DEPLOYMENT_STATUS" "$CP4BA_ADP_VIEWONE_DEPLOYMENT_STATUS" "$CP4BA_ADP_CDRA_DEPLOYMENT_STATUS" "$CP4BA_ADP_CDS_DEPLOYMENT_STATUS" "$CP4BA_ADP_CPDS_DEPLOYMENT_STATUS" "$CP4BA_ADP_GITSVC_DEPLOYMENT_STATUS")
        fi

        #################### DICMS #######################
        if [[ " ${EXISTING_PATTERN_ARR[@]}" =~ "decisions_ads" ]]; then
            source ${CUR_DIR}/helper/upgrade/deployment_check/dicms_status.sh
            CP4BA_COMPONENT_STATUS_VALUES+=("$CP4BA_ADS_CREDENTIALS_SERVICE_DEPLOYMENT_STATUS" "$CP4BA_ADS_GIT_SERVICE_DEPLOYMENT_STATUS" "$CP4BA_ADS_LTPA_CREATION_DEPLOYMENT_STATUS" "$CP4BA_ADS_PARSING_SERVICE_DEPLOYMENT_STATUS" "$CP4BA_ADS_RESTAPI_DEPLOYMENT_STATUS" "$CP4BA_ADS_RRREGISTRATION_DEPLOYMENT_STATUS" "$CP4BA_ADS_RUN_SERVICE_DEPLOYMENT_STATUS" "$CP4BA_ADS_RUNTIME_SERVICE_DEPLOYMENT_STATUS")
        fi

        #################### ODM #######################
        containsElement "decisions" "${EXISTING_PATTERN_ARR[@]}"
        odm_Val=$?
        if [[ $odm_Val -eq 0 ]]; then
            source ${CUR_DIR}/helper/upgrade/deployment_check/odm_status.sh
            CP4BA_COMPONENT_STATUS_VALUES+=("$CP4BA_ODM_DECISION_CENTER_DEPLOYMENT_STATUS" "$CP4BA_ODM_DECISION_RUNNER_DEPLOYMENT_STATUS" "$CP4BA_ODM_DECISIONSERVER_CONSOLE_DEPLOYMENT_STATUS" "$CP4BA_ODM_DECISIONSERVER_RUNTIME_DEPLOYMENT_STATUS")
        fi

        #################### RR #######################
        source ${CUR_DIR}/helper/upgrade/deployment_check/rr_status.sh
        CP4BA_COMPONENT_STATUS_VALUES+=("$CP4BA_RR_DEPLOYMENT_STATUS")


        #################### BAA AE Multiple instance #######################
        AE_ENGINE_DEPLOYMENT=`${YQ_CMD} ".spec.application_engine_configuration // \"\"" "$current_cr_details_location"`
        if [[ ! -z "$AE_ENGINE_DEPLOYMENT" ]]; then
            item=0
            while true; do
                ae_config_name=`${YQ_CMD} ".spec.application_engine_configuration.[${item}].name // \"\"" "$current_cr_details_location"`
                if [[ -z "$ae_config_name" ]]; then
                    break
                else
                    source ${CUR_DIR}/helper/upgrade/deployment_check/baa_status.sh
                    CP4BA_COMPONENT_STATUS_VALUES+=("$CP4BA_BAA_WORKSPACE_AAE_DEPLOYMENT_STATUS")
                    ((item++))
                fi
            done
        fi
        #################### BAStudio #######################
        BASTUDIO_DEPLOYMENT=`${YQ_CMD} ".spec.bastudio_configuration.admin_user // \"\"" "$current_cr_details_location"`
        if [[ ! -z "$BASTUDIO_DEPLOYMENT" ]]; then
            source ${CUR_DIR}/helper/upgrade/deployment_check/bastudio_status.sh
            CP4BA_COMPONENT_STATUS_VALUES+=("$CP4BA_BASTUDIO_DEPLOYMENT_STATUS")

        fi
        #################### BAI #######################
        if [[ " ${EXISTING_OPT_COMPONENT_ARR[@]} " =~ "bai" ]]; then
            source ${CUR_DIR}/helper/upgrade/deployment_check/bai_status.sh
            CP4BA_COMPONENT_STATUS_VALUES+=("$CP4BA_BAI_DEPLOYMENT_STATUS")

        fi

        #################### BAML #######################
        BAML_DEPLOYMENT=`${YQ_CMD} ".spec.baml_configuration // \"\"" "$current_cr_details_location"`
        if [[ ! -z "$BAML_DEPLOYMENT" ]]; then
            source ${CUR_DIR}/helper/upgrade/deployment_check/baml_status.sh
            CP4BA_COMPONENT_STATUS_VALUES+=("$CP4BA_BAML_DEPLOYMENT_STATUS")

        fi

        #################### BAW runtime Multiple instance #######################
        BAW_DEPLOYMENT=`${YQ_CMD} ".spec.baw_configuration // \"\"" "$current_cr_details_location"`
        if [[ ! -z "$BAW_DEPLOYMENT" ]]; then
            item=0
            while true; do
                baw_instance_name=`${YQ_CMD} ".spec.baw_configuration.[${item}].name // \"\"" "$current_cr_details_location"`
                if [[ -z "$baw_instance_name" ]]; then
                    break
                else
                    source ${CUR_DIR}/helper/upgrade/deployment_check/baw_runtime_status.sh
                    CP4BA_COMPONENT_STATUS_VALUES+=("$CP4BA_BAW_DEPLOYMENT_STATUS")
                    ((item++))
                fi
            done
        fi
    else
        fail "No top level CP4BA custom resource found on this cluster in the project \"$project_name\"."
        exit 1
    fi

    
    exist_wfps_cr_array=($(${CLI_CMD} get WfPSRuntime -n $project_name --no-headers --ignore-not-found | awk '{print $1}'))
    if [ ! -z $exist_wfps_cr_array ]; then
        for item in "${exist_wfps_cr_array[@]}"
        do
            cr_type="WfPSRuntime"
            wfps_cr_metaname=$(${CLI_CMD} get $cr_type ${item} -n $project_name --no-headers --ignore-not-found -o yaml | ${YQ_CMD} '.metadata.name' -)
            ${CLI_CMD} get $cr_type ${item} -n $project_name --no-headers --ignore-not-found -o yaml > ${UPGRADE_DEPLOYMENT_WFPSRUNTIME_CR_TMP}
            #################### WfPS #######################
            source ${CUR_DIR}/helper/upgrade/deployment_check/wfps_status.sh
            CP4BA_COMPONENT_STATUS_VALUES+=("$CP4BA_WFPS_DEPLOYMENT_STATUS")
            CP4BA_COMPONENT_STATUS_VALUES+=("$CP4BA_WFPS_SERVICE_DEPLOYMENT_STATUS")
        done

    fi

    exist_pfs_cr_array=($(${CLI_CMD} get ProcessFederationServer -n $project_name --no-headers --ignore-not-found | awk '{print $1}'))
    if [ ! -z $exist_pfs_cr_array ]; then
        for item in "${exist_pfs_cr_array[@]}"
        do
            cr_type="ProcessFederationServer"
            pfs_cr_metaname=$(${CLI_CMD} get $cr_type ${item} -n $project_name --no-headers --ignore-not-found -o yaml | ${YQ_CMD} '.metadata.name' -)
            ${CLI_CMD} get $cr_type ${item} -n $project_name --no-headers --ignore-not-found -o yaml > ${UPGRADE_DEPLOYMENT_PFS_CR_TMP}
            #################### WfPS #######################
            source ${CUR_DIR}/helper/upgrade/deployment_check/pfs_status.sh
            CP4BA_COMPONENT_STATUS_VALUES+=("$CP4BA_PFS_DEPLOYMENT_STATUS")
        done

    fi

}

# This function picks up the table built from the check_cp4ba_deployment_status and in addition shows some more messages based on the components displayed
# This function is called in loop untill failure or all components are upgraded
function show_cp4ba_upgrade_status() {
    printf '%s %s\n' "$(date)"

    check_cp4ba_deployment_status "${CP4BA_SERVICES_NS}" "$top_level_cr_kind" "$top_level_cr_name" "$top_level_cr_details_location"
    
    _original_cr_version=${original_cr_version:-"PREVIOUS"}
    ## <https://jsw.ibm.com/browse/DBACLD-177133> - Change the upgrade version to CP4BA_RELEASE_BASE_MAJOR_VERSION, so we don't need to update the version here when we move to a later version.
    if [[ ! ("$cp4ba_original_csv_ver_for_upgrade_script" == "$CP4BA_RELEASE_BASE_MAJOR_VERSION"*) ]]; then
        printf "\n"
        step_num=1
        echo "${YELLOW_TEXT}[NEXT ACTION]${RESET_TEXT}:"
        echo "${YELLOW_TEXT}  * The status above will be refreshing every 30 seconds.  You can continue to monitor and when all the status for the CP4BA components is ${RESET_TEXT}${GREEN_TEXT}\"Done\"${RESET_TEXT}${YELLOW_TEXT},the script will gracefully exit.${RESET_TEXT}:"

        if [[ $css_flag == "true" || " ${EXISTING_OPT_COMPONENT_ARR[@]} " =~ "css" ]]; then
            echo "  - STEP ${step_num} ${RED_TEXT}(Required)${RESET_TEXT}: You have Content Search Services (CSS) installed. Make sure you start the IBM Content Search Services index dispatcher. Refer to the FileNet P8 Platform Documentation for more details."
            echo "    ${YELLOW_TEXT}* Starting the IBM Content Search Services index dispatcher.${RESET_TEXT}"
            echo "      1. Log in to the Administration Console for Content Platform Engine."
            echo "      2. In the navigation pane, select the domain icon."
            echo "      3. In the edit pane, click the Text Search Subsystem tab and select the Enable indexing check box."
            echo "      4. Click Save to save your changes."
            printf "\n"
            step_num=$((step_num + 1))
        fi

        # echo "  - STEP ${step_num} ${RED_TEXT}(Required)${RESET_TEXT}: Run ${GREEN_TEXT}\"./cp4a-deployment.sh -m upgradePostconfig -n $TARGET_PROJECT_NAME\"${RESET_TEXT} to show any action required post CP4BA upgrade."
        # step_num=$((step_num + 1))

        if [[  " ${EXISTING_OPT_COMPONENT_ARR[@]} " =~ "bai" || "${bai_flag}" == "true" ]]; then
            printf "\n"
            echo "${RED_TEXT}(REQUIRED)${RESET_TEXT}:"
            printf '%b\n' "  ${YELLOW_TEXT}* AFTER UPGRADING IBM CLOUD PAK FOR BUSINESS AUTOMATION (CP4BA) DEPLOYMENT SUCCESSFULLY, YOU NEED TO REMOVE${RESET_TEXT} ${RED_TEXT}\"recovery_path\"${RESET_TEXT} ${YELLOW_TEXT}FROM CUSTOM RESOURCE UNDER${RESET_TEXT} ${RED_TEXT}\"bai_configuration\"${RESET_TEXT} ${YELLOW_TEXT}MANUALLY IF EXISTING.${RESET_TEXT}"
        fi

        printf "\n"
    else
        printf "\n"
        step_num=1
        echo "${YELLOW_TEXT}[NEXT ACTION]${RESET_TEXT}:"
        echo "${YELLOW_TEXT}  * The status above will be refreshing every 30 seconds.  You can continue to monitor and when all the status for the CP4BA components is ${RESET_TEXT}${GREEN_TEXT}\"Done\"${RESET_TEXT}${YELLOW_TEXT}, the script will gracefully exit.${RESET_TEXT}"
        printf "\n"
    fi
}

function check_cp4ba_separate_operand(){
    local project=$1
    # Check whether the CP4BA is separation of operators and operands.
    # also need to consider upgrade to 24.0.0 eGA 
    # operators_namespace: openshift-operators
    # services_namespace: ibm-common-services

    # operators_namespace: ibm-common-services
    # services_namespace: ibm-common-services

    # operators_namespace: cp4a-ns
    # services_namespace: cp4a-ns

    if ${CLI_CMD} get configMap ibm-cp4ba-common-config -n $project >/dev/null 2>&1; then
        success "Found \"ibm-cp4ba-common-config\" configMap in the project \"$project\"."
    else
        warning "\"ibm-cp4ba-common-config\" configMap was not found in the project \"$project\"."
        while [[ $CP4BA_SERVICES_NS == "" ]];
        do
            printf "\n"
            if [[ ($SCRIPT_MODE == "" && $RUNTIME_MODE == "") || ($SCRIPT_MODE == "dev" && $RUNTIME_MODE == "") || ($SCRIPT_MODE == "review" && $RUNTIME_MODE == "") || ($SCRIPT_MODE == "baw-dev" && $RUNTIME_MODE == "") ]]; then
                printf '%b\n' "\x1B[1mWhere (namespace) do you want to deploy CP4BA operands (i.e., runtime pods)? \x1B[0m"
            else
                printf '%b\n' "\x1B[1mWhere (namespace) did you deploy CP4BA operands (i.e., runtime pods)? \x1B[0m"
            fi
            read -p "Enter the name for an existing project (namespace): " CP4BA_SERVICES_NS
            if [ -z "$CP4BA_SERVICES_NS" ]; then
                printf '%b\n' "\x1B[1;31mEnter a valid project name, project name can not be blank\x1B[0m"
            elif [[ "$CP4BA_SERVICES_NS" == openshift* ]]; then
                printf '%b\n' "\x1B[1;31mEnter a valid project name, project name should not be 'openshift' or start with 'openshift' \x1B[0m"
                CP4BA_SERVICES_NS=""
            elif [[ "$CP4BA_SERVICES_NS" == kube* ]]; then
                printf '%b\n' "\x1B[1;31mEnter a valid project name, project name should not be 'kube' or start with 'kube' \x1B[0m"
                CP4BA_SERVICES_NS=""
            else
                isProjExists=`${CLI_CMD} get project $CP4BA_SERVICES_NS --ignore-not-found | wc -l`  >/dev/null 2>&1

                if [ "$isProjExists" -ne 2 ] ; then
                    printf '%b\n' "\x1B[1;31mInvalid project name, enter a existing project name ...\x1B[0m"
                    CP4BA_SERVICES_NS=""
                else
                    printf '%b\n' "\x1B[1mUsing project ${CP4BA_SERVICES_NS}...\x1B[0m"
                    if ${CLI_CMD} get configMap ibm-cp4ba-common-config -n $CP4BA_SERVICES_NS >/dev/null 2>&1; then
                        success "Found \"ibm-cp4ba-common-config\" configMap in the project \"$CP4BA_SERVICES_NS\"."
                    else
                        warning "\"ibm-cp4ba-common-config\" configMap not found in the project \"$CP4BA_SERVICES_NS\"."
                        CP4BA_SERVICES_NS=""
                        if [[ ($SCRIPT_MODE == "" && $RUNTIME_MODE == "") || ($SCRIPT_MODE == "dev" && $RUNTIME_MODE == "") || ($SCRIPT_MODE == "review" && $RUNTIME_MODE == "") || ($SCRIPT_MODE == "baw-dev" && $RUNTIME_MODE == "") || ($SCRIPT_MODE == "" && $RUNTIME_MODE == "upgradeOperator")|| ($SCRIPT_MODE == "" && $RUNTIME_MODE == "upgradeDeployment") || ($SCRIPT_MODE == "" && $RUNTIME_MODE == "upgradeDeploymentStatus") ]]; then
                            # For https://jsw.ibm.com/browse/DBACLD-160661 where we have added remediation steps on how to recreate the configmap
                            fail "You NEED to first create the \"ibm-cp4ba-common-config\" configMap in the project (namespace) where you want to deploy or upgrade CP4BA operands (i.e., runtime pods)."
                            info "${YELLOW_TEXT}- [NEXT-STEPS]${RESET_TEXT}"
                            echo "  - STEP 1 ${RED_TEXT}(Required)${RESET_TEXT}:${GREEN_TEXT} # Execute the cp4a-clusteradmin-setup.sh script with the \"-fix_configmap\" option to re-create the missing \"ibm-cp4ba-common-config\" configMap in the target namespace.For additional information refer to the Troubleshooting page in the Upgrade Section of the Knowledge Center.${RESET_TEXT}"
                            exit 1
                        fi
                    fi
                fi
            fi
        done
    fi
    tmp_namespace_val=""
    if [[ $CP4BA_SERVICES_NS != "" ]]; then
        tmp_namespace_val=$CP4BA_SERVICES_NS
    else
        tmp_namespace_val=$project
    fi
    cp4ba_services_namespace=$(${CLI_CMD} get configMap ibm-cp4ba-common-config -n $tmp_namespace_val --no-headers --ignore-not-found -o jsonpath='{.data.services_namespace}')
    cp4ba_operators_namespace=$(${CLI_CMD} get configMap ibm-cp4ba-common-config -n $tmp_namespace_val --no-headers --ignore-not-found -o jsonpath='{.data.operators_namespace}')
    if [[ (! -z $CP4BA_SERVICES_NS) ]]; then
        if [[ $cp4ba_services_namespace != $CP4BA_SERVICES_NS ]]; then
            fail "Your input value for CP4BA operands (i.e., runtime pods) is NOT equal to the value of \"services_namespace\" in \"ibm-cp4ba-common-config\" configMap under the project \"$CP4BA_SERVICES_NS\"."
            exit 1
        fi
    fi
    
    if [[ (! -z $cp4ba_services_namespace) && (! -z $cp4ba_operators_namespace) ]]; then
        # The IF condition below checks for separation of duties scenario (note: all-ns and shared CPfs are not considered separation of duties):
        #  - ($cp4ba_services_namespace != $cp4ba_operators_namespace) -> confirms that operator and services ns are different
        #  - ($cp4ba_operators_namespace != "openshift-operators") -> confirms that scenario is NOT all-ns
        #  - ($cp4ba_operators_namespace != "ibm-common-services") -> confirms that scenario is NOT shared/cluster-scoped CPfs scenario
        if [[ ($cp4ba_services_namespace != $cp4ba_operators_namespace) && ($cp4ba_operators_namespace != "openshift-operators" && $cp4ba_operators_namespace != "ibm-common-services") ]]; then
            info "This CP4BA deployment has been deployed with operators and operands in separate namespaces."
            SEPARATE_OPERAND_FLAG="Yes"
            CP4BA_SERVICES_NS=$cp4ba_services_namespace
            CP4BA_OPERATOR_NS=$cp4ba_operators_namespace #DBACLD-185209: Update logic to return Operator ns for separation of duty deployment.
        else
            SEPARATE_OPERAND_FLAG="No"
            CP4BA_SERVICES_NS=$cp4ba_services_namespace
            CP4BA_OPERATOR_NS=$cp4ba_operators_namespace
        fi
    else
        warning "\"operator_namespace\\services_namespace\" was not found in \"ibm-cp4ba-common-config\" configMap under the project \"$tmp_namespace_val\""
        fail "You need to set correct value(s) in \"ibm-cp4ba-common-config\" configMap for CP4BA seperate of operand under the project \"$tmp_namespace_val\""
        exit 1
    fi
}
