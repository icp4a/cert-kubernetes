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
    local current_version_major=$(echo $current_version | cut -d'.' -f1)
    local current_version_minor=$(echo $current_version | cut -d'.' -f2)
    local desired_version="${CP4BA_CSV_VERSION//v/}"
    local desired_version_major=$(echo $desired_version | cut -d'.' -f1)
    local desired_version_minor=$(echo $desired_version | cut -d'.' -f2)
    if [[ $current_version_major"."$current_version_minor == $desired_version_major"."$desired_version_minor ]]; then
        export is_ifix_to_ifix_upgrade="true"
        info "This is an upgrade from $current_version to $desired_version which is an Ifix to Ifix upgrade"
    else
        export is_ifix_to_ifix_upgrade="false"
        info "This is an upgrade from $current_version to $desired_version which is an n-1 to n upgrade"
    fi

}
# This function is used in check_cp4ba_operator_version where it will check the version of the operator and compare it with the array of minimum supported upgrade versions
# It will fail if the operator version is not less than the minimum supported upgrade version.
# This function takes 3 arguments:
# 1. current_csv_version: The csv of the version that needs to be checked such as "24.0.0", "24.0.4", "240.1"
# 2. failed_upgrade_message: The message that will be displayed if the version is not supported
# 3. The internal flag that will allow the customer to do direct upgrade to the desired version even though the current version is not in the minimum supported upgrade versions
function check_cp4ba_minimum_version(){

    local current_version=$1
    local failed_upgrade_message=$2
    local allow_direct_upgrade=$3

    for version in "${MINIMUM_SUPPORTED_UPGRADE_VERSIONS[@]}"; do
            if [[ "$current_version" == "${CP4BA_CSV_VERSION//v/}" ]]; then
                  info "The current IBM Cloud Pak for Business Automation Operator is already ${CP4BA_CSV_VERSION//v/}"
                  valid_version=true
                  break
            fi
            if [[ (! "$(printf '%s\n' "$version" "$current_version" | sort -V | head -n1)" = "$version") && "$allow_direct_upgrade" != 1 ]]; then
                info "Found IBM Cloud Pak for Business Automation Operator is \"$current_version\" version."
                fail "$failed_upgrade_message"
                valid_version=false
                exit 1

            else
                info "Found IBM Cloud Pak for Business Automation Operator is \"$current_version\" version."
                valid_version=true

                break
            fi

    done 
}

# function for checking operator version
function check_cp4ba_operator_version(){
    local project_name=$1
    local allow_direct_upgrade=$2
    local ALL_NAMESPACE_NAME="openshift-operators"
    local maxRetry=5
    info "Checking the version of IBM Cloud Pak for Business Automation Operator"

    cp4a_operator_csv_name_target_ns=$(${CLI_CMD} get csv -n $project_name --no-headers --ignore-not-found | grep "IBM Cloud Pak for Business Automation" | awk '{print $1}')
    cp4a_operator_csv_name_allnamespace_ns=$(${CLI_CMD} get csv -n $ALL_NAMESPACE_NAME --no-headers --ignore-not-found | grep "IBM Cloud Pak for Business Automation" | awk '{print $1}')

    if [[ -z $cp4a_operator_csv_name_allnamespace_ns && -z $cp4a_operator_csv_name_target_ns ]]; then
        fail "No IBM Cloud Pak for Business Automation Operator found in both \"$project_name\" and \"$ALL_NAMESPACE_NAME\" project."
        warning "Input correct project name for CP4BA."
        exit 1
    fi
    for ((retry=0;retry<=${maxRetry};retry++)); do
        valid_version=false  #this is flag to check if a valid for direct upgrade CP4BA operator version was found
        if [[ -z $cp4a_operator_csv_name_allnamespace_ns && (! -z $cp4a_operator_csv_name_target_ns) ]]; then
            success "Found IBM Cloud Pak for Business Automation Operator deployed in the project \"$project_name\"."
            ALL_NAMESPACE_FLAG="No"
            TEMP_OPERATOR_PROJECT_NAME=$project_name
            # We will only use the current csv versions for cp4ba and cpfs operators to perform any pre upgrade version checks.
            # https://jsw.ibm.com/browse/DBACLD-180433
            cp4a_operator_csv_version=$(${CLI_CMD} get csv $cp4a_operator_csv_name_target_ns -n $project_name --no-headers --ignore-not-found -o 'jsonpath={.spec.version}')
        elif [[ (! -z $cp4a_operator_csv_name_allnamespace_ns) && (! -z $cp4a_operator_csv_name_target_ns) ]]; then
            success "Found IBM Cloud Pak for Business Automation Operator deployed as AllNamespace mode in the project \"$ALL_NAMESPACE_NAME\"."
            ALL_NAMESPACE_FLAG="Yes"
            project_name="openshift-operators"
            TEMP_OPERATOR_PROJECT_NAME="openshift-operators"
            # We will only use the current csv versions for cp4ba and cpfs operators to perform any pre upgrade version checks.
            # https://jsw.ibm.com/browse/DBACLD-180433
            cp4a_operator_csv_version=$(${CLI_CMD} get csv $cp4a_operator_csv_name_allnamespace_ns -n $project_name --no-headers --ignore-not-found -o 'jsonpath={.spec.version}')
        fi

        

        if [[ ! -z $CP4BA_ORIGINAL_CSV_VERSION ]]; then
            CP4BA_ORIGINAL_CSV_VERSION=$(sed -e 's/^"//' -e 's/"$//' <<<"$CP4BA_ORIGINAL_CSV_VERSION")
            cp4a_operator_csv_version=$CP4BA_ORIGINAL_CSV_VERSION
        fi
        # DBACLD-164148: Calling check_cp4ba_minimum_version function to check the minimum supported version
        check_cp4ba_minimum_version "$cp4a_operator_csv_version" "Upgrade to CP4BA v24.0.0 or a later iFix first before upgrading to CP4BA $CP4BA_CSV_VERSION" "$allow_direct_upgrade"

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
    info "Checking the version of IBM CP4BA FileNet Content Manager Operator"
    for ((retry=0;retry<=${maxRetry};retry++)); do
        cp4a_content_operator_csv_name=$(${CLI_CMD} get csv -n $project_name --no-headers --ignore-not-found | grep "IBM CP4BA FileNet Content Manager" | awk '{print $1}')
        cp4a_content_operator_csv_version=$(${CLI_CMD} get csv $cp4a_content_operator_csv_name -n $project_name --no-headers --ignore-not-found -o 'jsonpath={.spec.version}')

        if [[ "$cp4a_content_operator_csv_version" == "${CP4BA_CSV_VERSION//v/}" ]]; then
            success "The current IBM CP4BA FileNet Content Manager Operator is already ${CP4BA_CSV_VERSION//v/}"
            break
        elif [[ "$cp4a_content_operator_csv_version" == "22.2."* ]]; then
            cp4a_content_operator_csv=$(${CLI_CMD} get csv $cp4a_content_operator_csv_name -n $project_name --no-headers --ignore-not-found -o 'jsonpath={.spec.version}')
            # cp4a_operator_csv="22.2.2"
            requiredver="22.2.2"
            if [ ! "$(printf '%s\n' "$requiredver" "$cp4a_content_operator_csv" | sort -V | head -n1)" = "$requiredver" ]; then
                fail "Upgrade to CP4BA 22.0.2-IF002 or later iFix first before upgrading to CP4BA $CP4BA_CSV_VERSION"
                exit 1
            else
                info "Found IBM CP4BA FileNet Content Manager Operator is \"$cp4a_content_operator_csv_version\" version."
                break
            fi
        elif [[ "$cp4a_content_operator_csv_version" == "23.1."* ]]; then
            fail "Upgrade to CP4BA 23.0.2 or later iFix first before upgrading to CP4BA $CP4BA_CSV_VERSION"
            exit 1
        elif [[ "$cp4a_content_operator_csv_version" == "22.1."* ]]; then
            fail "Upgrade to CP4BA 22.0.2 or later iFix first before upgrading to CP4BA $CP4BA_CSV_VERSION"
            exit 1
        elif [[ "$cp4a_content_operator_csv_version" != "${CP4BA_CSV_VERSION//v/}" ]]; then
            if [[ $retry -eq ${maxRetry} ]]; then
                info "Timeout Checking for the version of IBM CP4BA FileNet Content Manager Operator in the project \"$project_name\""
                exit 1
            else
                sleep 2
                printf '%s' "..."
                continue
            fi
        fi
    done
    # success "Found the IBM CP4BA FileNet Content Manager Operator $cp4a_content_operator_csv_version \n"
}

function check_operator_status(){
    local maxRetry=60
    local project_name=$1
    local check_mode=$2 # full or part
    local check_channel=$3
    CHECK_CP4BA_OPERATOR_RESULT=()

    # Check Common Service Operator 4.0
    if [[ "$check_mode" == "full" ]]; then
        local maxRetry=30
        echo "****************************************************************************"
        info "Checking for IBM Cloud Pak foundational operator pod initialization"
        for ((retry=0;retry<=${maxRetry};retry++)); do
            isReady=$(${CLI_CMD} get csv ibm-common-service-operator.$CS_OPERATOR_VERSION --no-headers --ignore-not-found -n $project_name -o jsonpath='{.status.phase}')
            # isReady=$(kubectl exec $cpe_pod_name -c ${meta_name}-cpe-deploy -n $project_name -- cat /opt/ibm/version.txt |grep -F "P8 Content Platform Engine 23.0.1")
            if [[ $isReady != "Succeeded" ]]; then
                if [[ $retry -eq ${maxRetry} ]]; then
                printf "\n"
                warning "Timeout waiting for IBM Cloud Pak foundational operator to start"
                printf '%b\n' "\x1B[1mCheck the status of Pod by issuing the following command:\x1B[0m"
                echo "${CLI_CMD} describe pod $(${CLI_CMD} get pod -n $project_name|grep ibm-common-service-operator|awk '{print $1}') -n $project_name"
                printf "\n"
                printf '%b\n' "\x1B[1mCheck the status of ReplicaSet by issuing the following command:\x1B[0m"
                echo "${CLI_CMD} describe rs $(${CLI_CMD} get rs -n $project_name|grep ibm-common-service-operator|awk '{print $1}') -n $project_name"
                printf "\n"
                exit 1
                else
                sleep 30
                printf '%s' "..."
                continue
                fi
            elif [[ $isReady == "Succeeded" ]]; then
                pod_name=$(${CLI_CMD} get pod -l=name=ibm-common-service-operator -n $project_name -o 'custom-columns=NAME:.metadata.name,PHASE:.status.phase,READY:.status.containerStatuses[0].ready,DELETED:.metadata.deletionTimestamp' --no-headers --ignore-not-found | grep 'Running' | grep 'true' | grep '<none>' | head -1 | awk '{print $1}')
                if [ -z $pod_name ]; then
                    error "IBM Cloud Pak foundational Operator pod is NOT running"
                    CHECK_CP4BA_OPERATOR_RESULT=( "${CHECK_CP4BA_OPERATOR_RESULT[@]}" "FAIL" )
                    break
                else
                    success "IBM Cloud Pak foundational Operator is running"
                    info "Pod: $pod_name"
                    CHECK_CP4BA_OPERATOR_RESULT=( "${CHECK_CP4BA_OPERATOR_RESULT[@]}" "PASS" )
                    break
                fi
            fi
        done
        echo "****************************************************************************"
    fi

    # if [[ "$check_mode" == "full" ]]; then
    #     if [[ (" ${EXISTING_OPT_COMPONENT_ARR[@]} " =~ "bai") || $bai_flag == "true" ]]; then
    #         # Check IBM Events Operator $EVENTS_OPERATOR_VERSION
    #         local maxRetry=10
    #         echo "****************************************************************************"
    #         info "Checking for IBM Events operator pod initialization"
    #         for ((retry=0;retry<=${maxRetry};retry++)); do
    #             isReady=$(${CLI_CMD} get csv ibm-events-operator.$EVENTS_OPERATOR_VERSION --no-headers --ignore-not-found -n $project_name -o jsonpath='{.status.phase}')
    #             # isReady=$(${CLI_CMD} exec $cpe_pod_name -c ${meta_name}-cpe-deploy -n $project_name -- cat /opt/ibm/version.txt |grep -F "P8 Content Platform Engine $CP4BA_RELEASE_BASE")
    #             if [[ $isReady != "Succeeded" ]]; then
    #                 if [[ $retry -eq ${maxRetry} ]]; then
    #                 printf "\n"
    #                 warning "Timeout waiting for IBM Events operator to start"
    #                 printf '%b\n' "\x1B[1mPlease check the status of Pod by issue cmd:\x1B[0m"
    #                 echo "${CLI_CMD} describe pod $(${CLI_CMD} get pod -n $project_name|grep ibm-events-operator|awk '{print $1}') -n $project_name"
    #                 printf "\n"
    #                 printf '%b\n' "\x1B[1mPlease check the status of ReplicaSet by issue cmd:\x1B[0m"
    #                 echo "${CLI_CMD} describe rs $(${CLI_CMD} get rs -n $project_name|grep ibm-events-operator|awk '{print $1}') -n $project_name"
    #                 printf "\n"
    #                 exit 1
    #                 else
    #                 sleep 30
    #                 printf '%s' "..."
    #                 continue
    #                 fi
    #             elif [[ $isReady == "Succeeded" ]]; then
    #                 pod_name=$(${CLI_CMD} get pod -l=name=ibm-events-operator -n $project_name -o 'custom-columns=NAME:.metadata.name,PHASE:.status.phase,READY:.status.containerStatuses[0].ready,DELETED:.metadata.deletionTimestamp' --no-headers --ignore-not-found | grep 'Running' | grep 'true' | grep '<none>' | head -1 | awk '{print $1}')
    #                 if [ -z $pod_name ]; then
    #                     error "IBM Events Operator pod is NOT running"
    #                     CHECK_CP4BA_OPERATOR_RESULT=( "${CHECK_CP4BA_OPERATOR_RESULT[@]}" "FAIL" )
    #                     break
    #                 else
    #                     success "IBM Events Operator is running"
    #                     info "Pod: $pod_name"
    #                     CHECK_CP4BA_OPERATOR_RESULT=( "${CHECK_CP4BA_OPERATOR_RESULT[@]}" "PASS" )
    #                     break
    #                 fi
    #             fi
    #         done
    #         echo "****************************************************************************"
    #     fi
    # fi

    # Check CP4BA operator upgrade status
    if [[ "$check_mode" == "full" ]]; then
        local maxRetry=30
        echo "****************************************************************************"
        info "Checking for IBM Cloud Pak for Business Automation (CP4BA) multi-pattern operator pod initialization"
        for ((retry=0;retry<=${maxRetry};retry++)); do
            isReady=$(${CLI_CMD} get csv ibm-cp4a-operator.$CP4BA_CSV_VERSION --no-headers --ignore-not-found -n $project_name -o jsonpath='{.status.phase}')
            # isReady=$(kubectl exec $cpe_pod_name -c ${meta_name}-cpe-deploy -n $project_name -- cat /opt/ibm/version.txt |grep -F "P8 Content Platform Engine 23.0.1")
            if [[ -z $isReady ]]; then
                fail "Failed to upgrade the IBM Cloud Pak for Business Automation (CP4BA) multi-pattern operator to ibm-cp4a-operator.$CP4BA_CSV_VERSION in the project \"$project_name\"" 
                msg "Check the Subscription and ClusterServiceVersions and then fix issue first."
                exit 1
            elif [[ $isReady != "Succeeded" ]]; then
                if [[ $retry -eq ${maxRetry} ]]; then
                printf "\n"
                warning "Timeout waiting for IBM Cloud Pak for Business Automation (CP4BA) multi-pattern operator to start"
                printf '%b\n' "\x1B[1mCheck the status of Pod by issuing the following command:\x1B[0m"
                echo "${CLI_CMD} describe pod $(${CLI_CMD} get pod -n $project_name|grep ibm-cp4a-operator|awk '{print $1}') -n $project_name"
                printf "\n"
                printf '%b\n' "\x1B[1mCheck the status of ReplicaSet by issuing the following command:\x1B[0m"
                echo "${CLI_CMD} describe rs $(${CLI_CMD} get rs -n $project_name|grep ibm-cp4a-operator|awk '{print $1}') -n $project_name"
                printf "\n"
                exit 1
                else
                sleep 30
                printf '%s' "..."
                continue
                fi
            elif [[ $isReady == "Succeeded" ]]; then
                if [[ "$check_channel" != "channel" ]]; then
                    pod_name=$(${CLI_CMD} get pod -l=name=ibm-cp4a-operator,release=23.0.1 -n $project_name -o 'custom-columns=NAME:.metadata.name,PHASE:.status.phase,READY:.status.containerStatuses[0].ready,DELETED:.metadata.deletionTimestamp' --no-headers --ignore-not-found | grep 'Running' | grep 'true' | grep '<none>' | head -1 | awk '{print $1}')
                    if [ -z $pod_name ]; then
                        error "IBM Cloud Pak for Business Automation (CP4BA) multi-pattern Operator pod is NOT running"
                        CHECK_CP4BA_OPERATOR_RESULT=( "${CHECK_CP4BA_OPERATOR_RESULT[@]}" "FAIL" )
                        break
                    else
                        success "IBM Cloud Pak for Business Automation (CP4BA) multi-pattern Operator is running"
                        info "Pod: $pod_name"
                        CHECK_CP4BA_OPERATOR_RESULT=( "${CHECK_CP4BA_OPERATOR_RESULT[@]}" "PASS" )
                        break
                    fi
                elif [[ "$check_channel" == "channel" ]]; then
                    success "IBM Cloud Pak for Business Automation (CP4BA) multi-pattern Operator is in the phase of \"$isReady\"!"
                    CHECK_CP4BA_OPERATOR_RESULT=( "${CHECK_CP4BA_OPERATOR_RESULT[@]}" "PASS" )
                    break
                fi
            fi
        done
        echo "****************************************************************************"
    fi

    # Check IBM CP4BA FileNet Content Manager operator upgrade status
    echo "****************************************************************************"
    info "Checking for IBM CP4BA FileNet Content Manager operator pod initialization"
    for ((retry=0;retry<=${maxRetry};retry++)); do
        isReady=$(${CLI_CMD} get csv ibm-content-operator.$CP4BA_CSV_VERSION --no-headers --ignore-not-found -n $project_name -o jsonpath='{.status.phase}')
        # isReady=$(kubectl exec $cpe_pod_name -c ${meta_name}-cpe-deploy -n $project_name -- cat /opt/ibm/version.txt |grep -F "P8 Content Platform Engine 23.0.1")
        if [[ -z $isReady ]]; then
            csv_version=""
            csv_version=$(${CLI_CMD} get csv $(${CLI_CMD} get csv --no-headers --ignore-not-found -n $project_name | grep ibm-content-operator.v |awk '{print $1}') --no-headers --ignore-not-found -n $project_name -o jsonpath='{.spec.version}')
            if [[ "v$csv_version" != $CP4BA_CSV_VERSION ]]; then
                if [[ $retry -eq ${maxRetry} ]]; then
                    fail "Failed to upgrade the IBM CP4BA FileNet Content Manager operator to ibm-content-operator.$CP4BA_CSV_VERSION in the project \"$project_name\"" 
                    msg "Check the Subscription and ClusterServiceVersions and then fix issue first."
                    exit 1
                else
                    sleep 30
                    printf '%s' "..."
                    continue
                fi
            fi
        elif [[ $isReady != "Succeeded" ]]; then
            if [[ $retry -eq ${maxRetry} ]]; then
                printf "\n"
                warning "Timeout waiting for IBM CP4BA FileNet Content Manager operator to start"
                printf '%b\n' "\x1B[1mCheck the status of Pod by issuing the following command:\x1B[0m"
                echo "${CLI_CMD} describe pod $(${CLI_CMD} get pod -n $project_name|grep ibm-content-operator|awk '{print $1}') -n $project_name"
                printf "\n"
                printf '%b\n' "\x1B[1mCheck the status of ReplicaSet by issuing the following command:\x1B[0m"
                echo "${CLI_CMD} describe rs $(${CLI_CMD} get rs -n $project_name|grep ibm-content-operator|awk '{print $1}') -n $project_name"
                printf "\n"
                exit 1
            else
                sleep 30
                printf '%s' "..."
                continue
            fi
        elif [[ $isReady == "Succeeded" ]]; then
            if [[ "$check_channel" != "channel" ]]; then
                pod_name=$(${CLI_CMD} get pod -l=name=ibm-content-operator,release=$CP4BA_RELEASE_BASE --no-headers --ignore-not-found -n $project_name -o 'custom-columns=NAME:.metadata.name,PHASE:.status.phase,READY:.status.containerStatuses[0].ready,DELETED:.metadata.deletionTimestamp' | grep 'Running' | grep 'true' | grep '<none>' | head -1 | awk '{print $1}')
                if [ -z $pod_name ]; then
                    error "IBM CP4BA FileNet Content Manager operator pod is NOT running"
                    CHECK_CP4BA_OPERATOR_RESULT=( "${CHECK_CP4BA_OPERATOR_RESULT[@]}" "FAIL" )
                    break
                else
                    success "IBM CP4BA FileNet Content Manager operator is running"
                    info "Pod: $pod_name"
                    CHECK_CP4BA_OPERATOR_RESULT=( "${CHECK_CP4BA_OPERATOR_RESULT[@]}" "PASS" )
                    break
                fi
            elif [[ "$check_channel" == "channel" ]]; then
                success "IBM CP4BA FileNet Content Manager operator is in the phase of \"$isReady\"!"
                CHECK_CP4BA_OPERATOR_RESULT=( "${CHECK_CP4BA_OPERATOR_RESULT[@]}" "PASS" )
                break
            fi
        fi
    done
    echo "****************************************************************************"

    # Check CP4BA Foundation operator upgrade status
    echo "****************************************************************************"
    info "Checking for CP4BA Foundation operator pod initialization"
    for ((retry=0;retry<=${maxRetry};retry++)); do
        isReady=$(${CLI_CMD} get csv icp4a-foundation-operator.$CP4BA_CSV_VERSION --no-headers --ignore-not-found -n $project_name -o jsonpath='{.status.phase}')
        # isReady=$(kubectl exec $cpe_pod_name -c ${meta_name}-cpe-deploy -n $project_name -- cat /opt/ibm/version.txt |grep -F "P8 Content Platform Engine 23.0.1")
        if [[ -z $isReady ]]; then
            csv_version=""
            csv_version=$(${CLI_CMD} get csv $(${CLI_CMD} get csv --no-headers --ignore-not-found -n $project_name | grep icp4a-foundation-operator.v |awk '{print $1}') --no-headers --ignore-not-found -n $project_name -o jsonpath='{.spec.version}')
            if [[ "v$csv_version" != $CP4BA_CSV_VERSION ]]; then
                if [[ $retry -eq ${maxRetry} ]]; then
                    fail "Failed to upgrade the IBM CP4BA Foundation operator to icp4a-foundation-operator.$CP4BA_CSV_VERSION in the project \"$project_name\"" 
                    msg "Check the Subscription and ClusterServiceVersions and then fix issue first."
                    exit 1
                else
                    sleep 30
                    printf '%s' "..."
                    continue
                fi
            fi
        elif [[ $isReady != "Succeeded" ]]; then
            if [[ $retry -eq ${maxRetry} ]]; then
            printf "\n"
            warning "Timeout waiting for CP4BA Foundation operator to start"
            printf '%b\n' "\x1B[1mCheck the status of Pod by issuing the following command:\x1B[0m"
            echo "${CLI_CMD} describe pod $(${CLI_CMD} get pod -n $project_name|grep icp4a-foundation-operator|awk '{print $1}') -n $project_name"
            printf "\n"
            printf '%b\n' "\x1B[1mCheck the status of ReplicaSet by issuing the following command:\x1B[0m"
            echo "${CLI_CMD} describe rs $(${CLI_CMD} get rs -n $project_name|grep icp4a-foundation-operator|awk '{print $1}') -n $project_name"
            printf "\n"
            exit 1
            else
            sleep 30
            printf '%s' "..."
            continue
            fi
        elif [[ $isReady == "Succeeded" ]]; then
            if [[ "$check_channel" != "channel" ]]; then
                pod_name=$(${CLI_CMD} get pod -l=name=icp4a-foundation-operator,release=$CP4BA_RELEASE_BASE --no-headers --ignore-not-found -n $project_name -o 'custom-columns=NAME:.metadata.name,PHASE:.status.phase,READY:.status.containerStatuses[0].ready,DELETED:.metadata.deletionTimestamp' | grep 'Running' | grep 'true' | grep '<none>' | head -1 | awk '{print $1}')
                if [ -z $pod_name ]; then
                    error "IBM CP4BA Foundation operator pod is NOT running"
                    CHECK_CP4BA_OPERATOR_RESULT=( "${CHECK_CP4BA_OPERATOR_RESULT[@]}" "FAIL" )
                    break
                else
                    success "IBM CP4BA Foundation operator is running"
                    info "Pod: $pod_name"
                    CHECK_CP4BA_OPERATOR_RESULT=( "${CHECK_CP4BA_OPERATOR_RESULT[@]}" "PASS" )
                    break
                fi
            elif [[ "$check_channel" == "channel" ]]; then
                success "IBM CP4BA Foundation operator is in the phase of \"$isReady\"!"
                CHECK_CP4BA_OPERATOR_RESULT=( "${CHECK_CP4BA_OPERATOR_RESULT[@]}" "PASS" )
                break
            fi
        fi
    done
    echo "****************************************************************************"

    # Check IBM CP4BA Automation Decision Service operator upgrade status
    echo "****************************************************************************"
    info "Checking for IBM CP4BA Automation Decision Service operator pod initialization"
    for ((retry=0;retry<=${maxRetry};retry++)); do
        isReady=$(${CLI_CMD} get csv ibm-ads-operator.$CP4BA_CSV_VERSION --no-headers --ignore-not-found -n $project_name -o jsonpath='{.status.phase}')
        # isReady=$(kubectl exec $cpe_pod_name -c ${meta_name}-cpe-deploy -n $project_name -- cat /opt/ibm/version.txt |grep -F "P8 Content Platform Engine 23.0.1")
        if [[ -z $isReady ]]; then
            csv_version=""
            csv_version=$(${CLI_CMD} get csv $(${CLI_CMD} get csv --no-headers --ignore-not-found -n $project_name | grep ibm-ads-operator.v |awk '{print $1}') --no-headers --ignore-not-found -n $project_name -o jsonpath='{.spec.version}')
            if [[ "v$csv_version" != $CP4BA_CSV_VERSION ]]; then
                if [[ $retry -eq ${maxRetry} ]]; then
                    fail "Failed to upgrade the IBM CP4BA Automation Decision Service operator to ibm-ads-operator.$CP4BA_CSV_VERSION in the project \"$project_name\"" 
                    msg "Check the Subscription and ClusterServiceVersions and then fix issue first."
                    exit 1
                else
                    sleep 30
                    printf '%s' "..."
                    continue
                fi
            fi
        elif [[ $isReady != "Succeeded" ]]; then
            if [[ $retry -eq ${maxRetry} ]]; then
            printf "\n"
            warning "Timeout waiting for IBM CP4BA Automation Decision Service operator to start"
            printf '%b\n' "\x1B[1mCheck the status of Pod by issuing the following command:\x1B[0m"
            echo "${CLI_CMD} describe pod $(${CLI_CMD} get pod -n $project_name|grep ibm-ads-operator|awk '{print $1}') -n $project_name"
            printf "\n"
            printf '%b\n' "\x1B[1mCheck the status of ReplicaSet by issuing the following command:\x1B[0m"
            echo "${CLI_CMD} describe rs $(${CLI_CMD} get rs -n $project_name|grep ibm-ads-operator|awk '{print $1}') -n $project_name"
            printf "\n"
            exit 1
            else
            sleep 30
            printf '%s' "..."
            continue
            fi
        elif [[ $isReady == "Succeeded" ]]; then
            if [[ "$check_channel" != "channel" ]]; then
                pod_name=$(${CLI_CMD} get pod -l=name=ibm-ads-operator -n $project_name -o 'custom-columns=NAME:.metadata.name,PHASE:.status.phase,READY:.status.containerStatuses[0].ready,DELETED:.metadata.deletionTimestamp' --no-headers --ignore-not-found | grep 'Running' | grep 'true' | grep '<none>' | head -1 | awk '{print $1}')
                if [ -z $pod_name ]; then
                    error "IBM CP4BA Automation Decision Service operator pod is NOT running"
                    CHECK_CP4BA_OPERATOR_RESULT=( "${CHECK_CP4BA_OPERATOR_RESULT[@]}" "FAIL" )
                    break
                else
                    success "IBM CP4BA Automation Decision Service operator is running"
                    info "Pod: $pod_name"
                    CHECK_CP4BA_OPERATOR_RESULT=( "${CHECK_CP4BA_OPERATOR_RESULT[@]}" "PASS" )
                    break
                fi
            elif [[ "$check_channel" == "channel" ]]; then
                success "IBM CP4BA Automation Decision Service operator is in the phase of \"$isReady\"!"
                CHECK_CP4BA_OPERATOR_RESULT=( "${CHECK_CP4BA_OPERATOR_RESULT[@]}" "PASS" )
                break
            fi
        fi
    done
    echo "****************************************************************************"


    # Check IBM Operational Decision Manager operator upgrade status
    if [[ "$check_mode" == "full" ]]; then
        echo "****************************************************************************"
        info "Checking for IBM Operational Decision Manager operator pod initialization"
        for ((retry=0;retry<=${maxRetry};retry++)); do
            isReady=$(${CLI_CMD} get csv ibm-odm-operator.$CP4BA_CSV_VERSION --no-headers --ignore-not-found -n $project_name -o jsonpath='{.status.phase}')
            # isReady=$(kubectl exec $cpe_pod_name -c ${meta_name}-cpe-deploy -n $project_name -- cat /opt/ibm/version.txt |grep -F "P8 Content Platform Engine 23.0.1")
            if [[ -z $isReady ]]; then
                csv_version=""
                csv_version=$(${CLI_CMD} get csv $(${CLI_CMD} get csv --no-headers --ignore-not-found -n $project_name | grep ibm-odm-operator.v |awk '{print $1}') --no-headers --ignore-not-found -n $project_name -o jsonpath='{.spec.version}')
                if [[ "v$csv_version" != $CP4BA_CSV_VERSION ]]; then
                    if [[ $retry -eq ${maxRetry} ]]; then
                        fail "Failed to upgrade the IBM Operational Decision Manager operator to ibm-odm-operator.$CP4BA_CSV_VERSION in the project \"$project_name\"" 
                        msg "Check the Subscription and ClusterServiceVersions and then fix issue first."
                        exit 1
                    else
                        sleep 30
                        printf '%s' "..."
                        continue
                    fi
                fi
            elif [[ $isReady != "Succeeded" ]]; then
                if [[ $retry -eq ${maxRetry} ]]; then
                printf "\n"
                warning "Timeout waiting for IBM Operational Decision Manager operator to start"
                printf '%b\n' "\x1B[1mCheck the status of Pod by issuing the following command:\x1B[0m"
                echo "${CLI_CMD} describe pod $(${CLI_CMD} get pod -n $project_name|grep ibm-odm-operator|awk '{print $1}') -n $project_name"
                printf "\n"
                printf '%b\n' "\x1B[1mCheck the status of ReplicaSet by issuing the following command:\x1B[0m"
                echo "${CLI_CMD} describe rs $(${CLI_CMD} get rs -n $project_name|grep ibm-odm-operator|awk '{print $1}') -n $project_name"
                printf "\n"
                exit 1
                else
                sleep 30
                printf '%s' "..."
                continue
                fi
            elif [[ $isReady == "Succeeded" ]]; then
                if [[ "$check_channel" != "channel" ]]; then
                    pod_name=$(${CLI_CMD} get pod -l=name=ibm-odm-operator -n $project_name -o 'custom-columns=NAME:.metadata.name,PHASE:.status.phase,READY:.status.containerStatuses[0].ready,DELETED:.metadata.deletionTimestamp' --no-headers --ignore-not-found | grep 'Running' | grep 'true' | grep '<none>' | head -1 | awk '{print $1}')
                    if [ -z $pod_name ]; then
                        error "IBM Operational Decision Manager pod is NOT running"
                        CHECK_CP4BA_OPERATOR_RESULT=( "${CHECK_CP4BA_OPERATOR_RESULT[@]}" "FAIL" )
                        break
                    else
                        success "IBM Operational Decision Manager operator is running"
                        info "Pod: $pod_name"
                        CHECK_CP4BA_OPERATOR_RESULT=( "${CHECK_CP4BA_OPERATOR_RESULT[@]}" "PASS" )
                        break
                    fi
                elif [[ "$check_channel" == "channel" ]]; then
                    success "IBM Operational Decision Manager operator is in the phase of \"$isReady\"!"
                    CHECK_CP4BA_OPERATOR_RESULT=( "${CHECK_CP4BA_OPERATOR_RESULT[@]}" "PASS" )
                    break
                fi
            fi
        done
        echo "****************************************************************************"
    fi

    # Check IBM Document Processing Engine operator upgrade status
    if [[ "$check_mode" == "full" ]]; then
        # Check the target cluster arch type

        arch_type=$(${CLI_CMD} get cm cluster-config-v1 -n kube-system --no-headers --ignore-not-found -o yaml | grep -i architecture|tail -1| awk '{print $2}')
        if [[ "$arch_type" == "amd64" ]]; then
            echo "****************************************************************************"
            info "Checking for IBM Document Processing Engine operator pod initialization"
            for ((retry=0;retry<=${maxRetry};retry++)); do
                isReady=$(${CLI_CMD} get csv ibm-dpe-operator.$CP4BA_CSV_VERSION --no-headers --ignore-not-found -n $project_name -o jsonpath='{.status.phase}')
                # isReady=$(kubectl exec $cpe_pod_name -c ${meta_name}-cpe-deploy -n $project_name -- cat /opt/ibm/version.txt |grep -F "P8 Content Platform Engine 23.0.1")
                if [[ -z $isReady ]]; then
                    csv_version=""
                    csv_version=$(${CLI_CMD} get csv $(${CLI_CMD} get csv --no-headers --ignore-not-found -n $project_name | grep ibm-dpe-operator.v |awk '{print $1}') --no-headers --ignore-not-found -n $project_name -o jsonpath='{.spec.version}')
                    if [[ "v$csv_version" != $CP4BA_CSV_VERSION ]]; then
                        if [[ $retry -eq ${maxRetry} ]]; then
                            fail "Failed to upgrade the IBM Document Processing Engine operator to ibm-dpe-operator.$CP4BA_CSV_VERSION in the project \"$project_name\"" 
                            msg "Check the Subscription and ClusterServiceVersions and then fix issue first."
                            exit 1
                        else
                            sleep 30
                            printf '%s' "..."
                            continue
                        fi
                    fi
                elif [[ $isReady != "Succeeded" ]]; then
                    if [[ $retry -eq ${maxRetry} ]]; then
                    printf "\n"
                    warning "Timeout waiting for IBM Document Processing Engine operator to start"
                    printf '%b\n' "\x1B[1mCheck the status of Pod by issuing the following command:\x1B[0m"
                    echo "${CLI_CMD} describe pod $(${CLI_CMD} get pod -n $project_name|grep ibm-dpe-operator|awk '{print $1}') -n $project_name"
                    printf "\n"
                    printf '%b\n' "\x1B[1mCheck the status of ReplicaSet by issuing the following command:\x1B[0m"
                    echo "${CLI_CMD} describe rs $(${CLI_CMD} get rs -n $project_name|grep ibm-dpe-operator|awk '{print $1}') -n $project_name"
                    printf "\n"
                    exit 1
                    else
                    sleep 30
                    printf '%s' "..."
                    continue
                    fi
                elif [[ $isReady == "Succeeded" ]]; then
                    if [[ "$check_channel" != "channel" ]]; then
                        pod_name=$(${CLI_CMD} get pod -l=name=ibm-dpe-operator -n $project_name -o 'custom-columns=NAME:.metadata.name,PHASE:.status.phase,READY:.status.containerStatuses[0].ready,DELETED:.metadata.deletionTimestamp' --no-headers --ignore-not-found | grep 'Running' | grep 'true' | grep '<none>' | head -1 | awk '{print $1}')
                        if [ -z $pod_name ]; then
                            error "IBM Document Processing Engine pod is NOT running"
                            CHECK_CP4BA_OPERATOR_RESULT=( "${CHECK_CP4BA_OPERATOR_RESULT[@]}" "FAIL" )
                            break
                        else
                            success "IBM Document Processing Engine operator is running"
                            info "Pod: $pod_name"
                            CHECK_CP4BA_OPERATOR_RESULT=( "${CHECK_CP4BA_OPERATOR_RESULT[@]}" "PASS" )
                            break
                        fi
                    elif [[ "$check_channel" == "channel" ]]; then
                        success "IBM Document Processing Engine operator is in the phase of \"$isReady\"!"
                        CHECK_CP4BA_OPERATOR_RESULT=( "${CHECK_CP4BA_OPERATOR_RESULT[@]}" "PASS" )
                        break
                    fi
                fi
            done
            echo "****************************************************************************"
        fi
    fi

    # Check IBM CP4BA Workflow Process Service operator upgrade status
    echo "****************************************************************************"
    info "Checking for IBM CP4BA Workflow Process Service operator pod initialization"
    for ((retry=0;retry<=${maxRetry};retry++)); do
        isReady=$(${CLI_CMD} get csv ibm-cp4a-wfps-operator.$CP4BA_CSV_VERSION --no-headers --ignore-not-found -n $project_name -o jsonpath='{.status.phase}')
        if [[ -z $isReady ]]; then
            csv_version=""
            csv_version=$(${CLI_CMD} get csv $(${CLI_CMD} get csv --no-headers --ignore-not-found -n $project_name | grep ibm-cp4a-wfps-operator.v |awk '{print $1}') --no-headers --ignore-not-found -n $project_name -o jsonpath='{.spec.version}')
            if [[ "v$csv_version" != $CP4BA_CSV_VERSION ]]; then
                if [[ $retry -eq ${maxRetry} ]]; then
                    fail "Failed to upgrade the IBM CP4BA Workflow Process Service operator to ibm-cp4a-wfps-operator.$CP4BA_CSV_VERSION in the project \"$project_name\"" 
                    msg "Check the Subscription and ClusterServiceVersions and then fix issue first."
                    exit 1
                else
                    sleep 30
                    printf '%s' "..."
                    continue
                fi
            fi
        # isReady=$(kubectl exec $cpe_pod_name -c ${meta_name}-cpe-deploy -n $project_name -- cat /opt/ibm/version.txt |grep -F "P8 Content Platform Engine 23.0.1")
        elif [[ $isReady != "Succeeded" ]]; then
            if [[ $retry -eq ${maxRetry} ]]; then
            printf "\n"
            warning "Timeout waiting for IBM CP4BA Workflow Process Service operator to start"
            printf '%b\n' "\x1B[1mCheck the status of Pod by issuing the following command:\x1B[0m"
            echo "${CLI_CMD} describe pod $(${CLI_CMD} get pod -n $project_name|grep ibm-cp4a-wfps-operator|awk '{print $1}') -n $project_name"
            printf "\n"
            printf '%b\n' "\x1B[1mCheck the status of ReplicaSet by issuing the following command:\x1B[0m"
            echo "${CLI_CMD} describe rs $(${CLI_CMD} get rs -n $project_name|grep ibm-cp4a-wfps-operator|awk '{print $1}') -n $project_name"
            printf "\n"
            exit 1
            else
            sleep 30
            printf '%s' "..."
            continue
            fi
        elif [[ $isReady == "Succeeded" ]]; then
            if [[ "$check_channel" != "channel" ]]; then
                pod_name=$(${CLI_CMD} get pod -l=name=ibm-cp4a-wfps-operator -n $project_name -o 'custom-columns=NAME:.metadata.name,PHASE:.status.phase,READY:.status.containerStatuses[0].ready,DELETED:.metadata.deletionTimestamp' --no-headers --ignore-not-found | grep 'Running' | grep 'true' | grep '<none>' | head -1 | awk '{print $1}')
                if [ -z $pod_name ]; then
                    error "IBM CP4BA Workflow Process Service operator pod is NOT running"
                    CHECK_CP4BA_OPERATOR_RESULT=( "${CHECK_CP4BA_OPERATOR_RESULT[@]}" "FAIL" )
                    break
                else
                    success "IBM CP4BA Workflow Process Service operator is running"
                    info "Pod: $pod_name"
                    CHECK_CP4BA_OPERATOR_RESULT=( "${CHECK_CP4BA_OPERATOR_RESULT[@]}" "PASS" )
                    break
                fi
            elif [[ "$check_channel" == "channel" ]]; then
                success "IBM CP4BA Workflow Process Service operator is in the phase of \"$isReady\"!"
                CHECK_CP4BA_OPERATOR_RESULT=( "${CHECK_CP4BA_OPERATOR_RESULT[@]}" "PASS" )
                break
            fi
        fi
    done
    echo "****************************************************************************"

    # Check IBM CP4BA Insights Engine operator upgrade status
    if [[ "$check_mode" == "full" ]]; then
        echo "****************************************************************************"
        info "Checking for IBM CP4BA Insights Engine operator pod initialization"
        for ((retry=0;retry<=${maxRetry};retry++)); do
            isReady=$(${CLI_CMD} get csv ibm-insights-engine-operator.$CP4BA_CSV_VERSION --no-headers --ignore-not-found -n $project_name -o jsonpath='{.status.phase}')
            # isReady=$(kubectl exec $cpe_pod_name -c ${meta_name}-cpe-deploy -n $project_name -- cat /opt/ibm/version.txt |grep -F "P8 Content Platform Engine 23.0.1")
            if [[ -z $isReady ]]; then
                csv_version=""
                csv_version=$(${CLI_CMD} get csv $(${CLI_CMD} get csv --no-headers --ignore-not-found -n $project_name | grep ibm-insights-engine-operator.v |awk '{print $1}') --no-headers --ignore-not-found -n $project_name -o jsonpath='{.spec.version}')
                if [[ "v$csv_version" != $CP4BA_CSV_VERSION ]]; then
                    if [[ $retry -eq ${maxRetry} ]]; then
                        fail "Failed to upgrade the IBM CP4BA Insights Engine operator to ibm-insights-engine-operator.$CP4BA_CSV_VERSION in the project \"$project_name\"" 
                        msg "Check the Subscription and ClusterServiceVersions and then fix issue first."
                        exit 1
                    else
                        sleep 30
                        printf '%s' "..."
                        continue
                    fi
                fi
            elif [[ $isReady != "Succeeded" ]]; then
                if [[ $retry -eq ${maxRetry} ]]; then
                printf "\n"
                warning "Timeout waiting for IBM CP4BA Insights Engine operator to start"
                printf '%b\n' "\x1B[1mCheck the status of Pod by issuing the following command:\x1B[0m"
                echo "${CLI_CMD} describe pod $(${CLI_CMD} get pod -n $project_name|grep ibm-insights-engine-operator|awk '{print $1}') -n $project_name"
                printf "\n"
                printf '%b\n' "\x1B[1mCheck the status of ReplicaSet by issuing the following command:\x1B[0m"
                echo "${CLI_CMD} describe rs $(${CLI_CMD} get rs -n $project_name|grep ibm-insights-engine-operator|awk '{print $1}') -n $project_name"
                printf "\n"
                exit 1
                else
                sleep 30
                printf '%s' "..."
                continue
                fi
            elif [[ $isReady == "Succeeded" ]]; then
                if [[ "$check_channel" != "channel" ]]; then
                    pod_name=$(${CLI_CMD} get pod -l=name=ibm-insights-engine-operator -n $project_name -o 'custom-columns=NAME:.metadata.name,PHASE:.status.phase,READY:.status.containerStatuses[0].ready,DELETED:.metadata.deletionTimestamp' --no-headers --ignore-not-found | grep 'Running' | grep 'true' | grep '<none>' | head -1 | awk '{print $1}')
                    if [ -z $pod_name ]; then
                        error "IBM CP4BA Insights Engine operator pod is NOT running"
                        CHECK_CP4BA_OPERATOR_RESULT=( "${CHECK_CP4BA_OPERATOR_RESULT[@]}" "FAIL" )
                        break
                    else
                        success "IBM CP4BA Insights Engine operator is running"
                        info "Pod: $pod_name"
                        CHECK_CP4BA_OPERATOR_RESULT=( "${CHECK_CP4BA_OPERATOR_RESULT[@]}" "PASS" )
                        break
                    fi
                elif [[ "$check_channel" == "channel" ]]; then
                    success "IBM CP4BA Insights Engine operator is in the phase of \"$isReady\"!"
                    CHECK_CP4BA_OPERATOR_RESULT=( "${CHECK_CP4BA_OPERATOR_RESULT[@]}" "PASS" )
                    break
                fi
            fi
        done
        echo "****************************************************************************"
    fi

    # Check CP4BA IBM CP4BA Process Federation Server operator upgrade status
    echo "****************************************************************************"
    info "Checking for IBM CP4BA Process Federation Server operator pod initialization"
    for ((retry=0;retry<=${maxRetry};retry++)); do
        isReady=$(${CLI_CMD} get csv ibm-pfs-operator.$CP4BA_CSV_VERSION --no-headers --ignore-not-found -n $project_name -o jsonpath='{.status.phase}')
        # isReady=$(kubectl exec $cpe_pod_name -c ${meta_name}-cpe-deploy -n $project_name -- cat /opt/ibm/version.txt |grep -F "P8 Content Platform Engine 23.0.1")
        if [[ -z $isReady ]]; then
            csv_version=""
            csv_version=$(${CLI_CMD} get csv $(${CLI_CMD} get csv --no-headers --ignore-not-found -n $project_name | grep ibm-pfs-operator.v |awk '{print $1}') --no-headers --ignore-not-found -n $project_name -o jsonpath='{.spec.version}')
            if [[ "v$csv_version" != $CP4BA_CSV_VERSION ]]; then
                if [[ $retry -eq ${maxRetry} ]]; then
                    fail "Failed to upgrade the IBM CP4BA Process Federation Server operator to ibm-pfs-operator.$CP4BA_CSV_VERSION in the project \"$project_name\"" 
                    msg "Check the Subscription and ClusterServiceVersions and then fix issue first."
                    exit 1
                else
                    sleep 30
                    printf '%s' "..."
                    continue
                fi
            fi
        elif [[ $isReady != "Succeeded" ]]; then
            if [[ $retry -eq ${maxRetry} ]]; then
            printf "\n"
            warning "Timeout waiting for IBM CP4BA Process Federation Server operator to start"
            printf '%b\n' "\x1B[1mCheck the status of Pod by issuing the following command:\x1B[0m"
            echo "${CLI_CMD} describe pod $(${CLI_CMD} get pod -n $project_name|grep ibm-pfs-operator|awk '{print $1}') -n $project_name"
            printf "\n"
            printf '%b\n' "\x1B[1mCheck the status of ReplicaSet by issuing the following command:\x1B[0m"
            echo "${CLI_CMD} describe rs $(${CLI_CMD} get rs -n $project_name|grep ibm-pfs-operator|awk '{print $1}') -n $project_name"
            printf "\n"
            exit 1
            else
            sleep 30
            printf '%s' "..."
            continue
            fi
        elif [[ $isReady == "Succeeded" ]]; then
            if [[ "$check_channel" != "channel" ]]; then
                pod_name=$(${CLI_CMD} get pod -l=name=ibm-pfs-operator -n $project_name -o 'custom-columns=NAME:.metadata.name,PHASE:.status.phase,READY:.status.containerStatuses[0].ready,DELETED:.metadata.deletionTimestamp' --no-headers --ignore-not-found | grep 'Running' | grep 'true' | grep '<none>' | head -1 | awk '{print $1}')
                if [ -z $pod_name ]; then
                    error "IBM CP4BA Process Federation Server operator pod is NOT running"
                    CHECK_CP4BA_OPERATOR_RESULT=( "${CHECK_CP4BA_OPERATOR_RESULT[@]}" "FAIL" )
                    break
                else
                    success "IBM CP4BA Process Federation Server operator is running"
                    info "Pod: $pod_name"
                    CHECK_CP4BA_OPERATOR_RESULT=( "${CHECK_CP4BA_OPERATOR_RESULT[@]}" "PASS" )
                    break
                fi
            elif [[ "$check_channel" == "channel" ]]; then
                success "IBM CP4BA Process Federation Server operator is in the phase of \"$isReady\"!"
                CHECK_CP4BA_OPERATOR_RESULT=( "${CHECK_CP4BA_OPERATOR_RESULT[@]}" "PASS" )
                break
            fi
        fi
    done
    echo "****************************************************************************"


    # Check CP4BA IBM CP4BA Workflow operator upgrade status
    echo "****************************************************************************"
    info "Checking for IBM CP4BA Workflow operator pod initialization"
    for ((retry=0;retry<=${maxRetry};retry++)); do
        isReady=$(${CLI_CMD} get csv ibm-workflow-operator.$CP4BA_CSV_VERSION --no-headers --ignore-not-found -n $project_name -o jsonpath='{.status.phase}')
        # isReady=$(kubectl exec $cpe_pod_name -c ${meta_name}-cpe-deploy -n $project_name -- cat /opt/ibm/version.txt |grep -F "P8 Content Platform Engine 23.0.1")
        if [[ -z $isReady ]]; then
            csv_version=""
            csv_version=$(${CLI_CMD} get csv $(${CLI_CMD} get csv --no-headers --ignore-not-found -n $project_name | grep ibm-workflow-operator.v |awk '{print $1}') --no-headers --ignore-not-found -n $project_name -o jsonpath='{.spec.version}')
            if [[ "v$csv_version" != $CP4BA_CSV_VERSION ]]; then
                if [[ $retry -eq ${maxRetry} ]]; then
                    fail "Failed to upgrade the IBM CP4BA Workflow operator to ibm-workflow-operator.$CP4BA_CSV_VERSION in the project \"$project_name\"" 
                    msg "Check the Subscription and ClusterServiceVersions and then fix issue first."
                    exit 1
                else
                    sleep 30
                    printf '%s' "..."
                    continue
                fi
            fi
        elif [[ $isReady != "Succeeded" ]]; then
            if [[ $retry -eq ${maxRetry} ]]; then
            printf "\n"
            warning "Timeout waiting for IBM CP4BA Workflow operator to start"
            printf '%b\n' "\x1B[1mCheck the status of Pod by issuing the following command:\x1B[0m"
            echo "${CLI_CMD} describe pod $(${CLI_CMD} get pod -n $project_name|grep ibm-workflow-operator|awk '{print $1}') -n $project_name"
            printf "\n"
            printf '%b\n' "\x1B[1mCheck the status of ReplicaSet by issuing the following command:\x1B[0m"
            echo "${CLI_CMD} describe rs $(${CLI_CMD} get rs -n $project_name|grep ibm-workflow-operator|awk '{print $1}') -n $project_name"
            printf "\n"
            exit 1
            else
            sleep 30
            printf '%s' "..."
            continue
            fi
        elif [[ $isReady == "Succeeded" ]]; then
            if [[ "$check_channel" != "channel" ]]; then
                pod_name=$(${CLI_CMD} get pod -l=name=ibm-workflow-operator -n $project_name -o 'custom-columns=NAME:.metadata.name,PHASE:.status.phase,READY:.status.containerStatuses[0].ready,DELETED:.metadata.deletionTimestamp' --no-headers --ignore-not-found | grep 'Running' | grep 'true' | grep '<none>' | head -1 | awk '{print $1}')
                if [ -z $pod_name ]; then
                    error "IBM CP4BA Workflow operator pod is NOT running"
                    CHECK_CP4BA_OPERATOR_RESULT=( "${CHECK_CP4BA_OPERATOR_RESULT[@]}" "FAIL" )
                    break
                else
                    success "IBM CP4BA Workflow operator is running"
                    info "Pod: $pod_name"
                    CHECK_CP4BA_OPERATOR_RESULT=( "${CHECK_CP4BA_OPERATOR_RESULT[@]}" "PASS" )
                    break
                fi
            elif [[ "$check_channel" == "channel" ]]; then
                success "IBM CP4BA Workflow operator is in the phase of \"$isReady\"!"
                CHECK_CP4BA_OPERATOR_RESULT=( "${CHECK_CP4BA_OPERATOR_RESULT[@]}" "PASS" )
                break
            fi
        fi
    done
    echo "****************************************************************************"
}

function check_cp4ba_deployment_status(){
    local project_name=$1
    # local meta_name=$2

    UPGRADE_STATUS_CONTENT_FOLDER=${TEMP_FOLDER}/${project_name}
    UPGRADE_STATUS_CP4BA_FOLDER=${TEMP_FOLDER}/${project_name}
    mkdir -p ${UPGRADE_STATUS_CONTENT_FOLDER}
    mkdir -p ${UPGRADE_STATUS_CP4BA_FOLDER}

    UPGRADE_STATUS_CONTENT_FILE=${UPGRADE_STATUS_CONTENT_FOLDER}/.content_status.yaml
    UPGRADE_STATUS_CP4BA_FILE=${UPGRADE_STATUS_CP4BA_FOLDER}/.icp4acluster_status.yaml

    UPGRADE_DEPLOYMENT_ICP4ACLUSTER_CR_BAK=${CUR_DIR}/cp4ba-upgrade/project/$project_name/custom_resource/backup/icp4acluster_cr_backup.yaml
    UPGRADE_DEPLOYMENT_CONTENT_CR_BAK=${CUR_DIR}/cp4ba-upgrade/project/$project_name/custom_resource/backup/content_cr_backup.yaml

    cp4ba_cr_name=$(${CLI_CMD} get icp4acluster -n $project_name --no-headers --ignore-not-found | awk '{print $1}')
    if [ ! -z "$cp4ba_cr_name" ]; then
        cp4ba_cr_metaname=$(${CLI_CMD} get icp4acluster $cp4ba_cr_name -n $project_name --no-headers --ignore-not-found -o yaml | ${YQ_CMD} '.metadata.name' -)
        ${CLI_CMD} get icp4acluster $cp4ba_cr_name -n ${project_name} --no-headers --ignore-not-found -o yaml > ${UPGRADE_STATUS_CP4BA_FILE}
    fi

    content_cr_name=$(${CLI_CMD} get content -n $project_name --no-headers --ignore-not-found | awk '{print $1}')
    if [ ! -z "$content_cr_name" ]; then
        content_cr_metaname=$(${CLI_CMD} get content $content_cr_name -n $project_name --no-headers --ignore-not-found -o yaml | ${YQ_CMD} '.metadata.name' -)
        ${CLI_CMD} get content $content_cr_name -n ${project_name} --no-headers --ignore-not-found -o yaml > ${UPGRADE_STATUS_CONTENT_FILE}
    fi

    if [[ -z "${cp4ba_cr_name}" && -z "${content_cr_name}" ]]; then
        fail "Not found any content and icp4acluster custom resource files in the project \"$project_name\", exiting ..."
        exit 1
    fi

    if [ -z "${cp4ba_cr_name}" ]; then
        UPGRADE_STATUS_FILE=${UPGRADE_STATUS_CONTENT_FILE}
    elif [ ! -z "${cp4ba_cr_name}" ]; then
        UPGRADE_STATUS_FILE=${UPGRADE_STATUS_CP4BA_FILE}
    fi
    
    if [[ ( ! -z "${content_cr_name}" ) || ( ! -z "${cp4ba_cr_name}" ) ]]; then
        if [[ ! -z "${content_cr_name}" ]]; then
            owner_ref=$(${CLI_CMD} get content $content_cr_name -n $project_name --no-headers --ignore-not-found -o yaml | ${YQ_CMD} '.metadata.ownerReferences.[0].kind // ""' -)
            #################### FNCM #######################
            if [[ -z "${owner_ref}" ]]; then
                #this variable is being used to check what the version of CP4BA was used before upgrade and is used later in a check if some alert message is to be printed
                # initial_app_version=`cat $UPGRADE_DEPLOYMENT_CONTENT_CR_BAK | ${YQ_CMD} r - spec.appVersion`
                CONTENT_CR_EXIST="Yes"
                source ${CUR_DIR}/helper/upgrade/deployment_check/fncm_status.sh
                # Add FNCM component status variables to overall status array
                CP4BA_COMPONENT_STATUS_VALUES+=("$CP4BA_CPE_DEPLOYMENT_STATUS" "$CP4BA_GRAPHQL_DEPLOYMENT_STATUS" "$CP4BA_CSS_DEPLOYMENT_STATUS" "$CP4BA_CMIS_DEPLOYMENT_STATUS" "$CP4BA_IER_DEPLOYMENT_STATUS" "$CP4BA_ICC_DEPLOYMENT_STATUS" "$CP4BA_TM_DEPLOYMENT_STATUS" "$CP4BA_BAN_DEPLOYMENT_STATUS" "$CP4BA_ES_DEPLOYMENT_STATUS")
                bai_flag=`${YQ_CMD} ".spec.content_optional_components.bai // \"\"" "$UPGRADE_STATUS_FILE"`
                if [[ ! -z "$bai_flag" ]]; then
                    bai_flag=$(echo "$bai_flag" | tr '[:upper:]' '[:lower:]')
                    if [[ "${bai_flag}" == "true" ]]; then
                        source ${CUR_DIR}/helper/upgrade/deployment_check/bai_status.sh
                        CP4BA_COMPONENT_STATUS_VALUES+=("$CP4BA_BAI_DEPLOYMENT_STATUS")
                    fi
                fi
                css_flag=`${YQ_CMD} ".spec.content_optional_components.css" "$UPGRADE_STATUS_FILE"`
                css_flag=$(echo $css_flag | tr '[:upper:]' '[:lower:]')
            else
                CONTENT_CR_EXIST="No"
            fi
        fi
        if [[ ! -z "${cp4ba_cr_name}" ]]; then
            convert_olm_cr "${UPGRADE_STATUS_FILE}"
            if [[ $olm_cr_flag == "No" ]]; then
                #this variable is being used to check what the version of CP4BA was used before upgrade and is used later in a check if some alert message is to be printed
                # initial_app_version=`cat $UPGRADE_DEPLOYMENT_ICP4ACLUSTER_CR_BAK | ${YQ_CMD} r - spec.appVersion`
                existing_pattern_list=""
                existing_opt_component_list=""
                EXISTING_PATTERN_ARR=()
                EXISTING_OPT_COMPONENT_ARR=()
                existing_pattern_list=`${YQ_CMD} ".spec.shared_configuration.sc_deployment_patterns" "$UPGRADE_STATUS_FILE"`
                existing_opt_component_list=`${YQ_CMD} ".spec.shared_configuration.sc_optional_components" "$UPGRADE_STATUS_FILE"`

                OIFS=$IFS
                IFS=',' read -r -a EXISTING_PATTERN_ARR <<< "$existing_pattern_list"
                IFS=',' read -r -a EXISTING_OPT_COMPONENT_ARR <<< "$existing_opt_component_list"
                IFS=$OIFS
            fi
            #################### FNCM #######################
            if [[ $CONTENT_CR_EXIST == "Yes" || " ${EXISTING_PATTERN_ARR[@]}" =~ "workflow-runtime" || " ${EXISTING_PATTERN_ARR[@]}" =~ "workflow-authoring" || " ${EXISTING_PATTERN_ARR[@]}" =~ "content" || " ${EXISTING_PATTERN_ARR[@]}" =~ "document_processing" || "${EXISTING_OPT_COMPONENT_ARR[@]}" =~ "ae_data_persistence" ]]; then
                source ${CUR_DIR}/helper/upgrade/deployment_check/fncm_status.sh
                # Add FNCM component status variables to array
                CP4BA_COMPONENT_STATUS_VALUES+=("$CP4BA_CPE_DEPLOYMENT_STATUS" "$CP4BA_GRAPHQL_DEPLOYMENT_STATUS" "$CP4BA_CSS_DEPLOYMENT_STATUS" "$CP4BA_CMIS_DEPLOYMENT_STATUS" "$CP4BA_IER_DEPLOYMENT_STATUS" "$CP4BA_ICC_DEPLOYMENT_STATUS" "$CP4BA_TM_DEPLOYMENT_STATUS" "$CP4BA_BAN_DEPLOYMENT_STATUS" "$CP4BA_ES_DEPLOYMENT_STATUS")
            fi

            #################### ADP #######################
            if [[ " ${EXISTING_PATTERN_ARR[@]}" =~ "document_processing" ]]; then
                source ${CUR_DIR}/helper/upgrade/deployment_check/adp_status.sh
                CP4BA_COMPONENT_STATUS_VALUES+=("$CP4BA_ADP_ACA_DEPLOYMENT_STATUS" "$CP4BA_ADP_VIEWONE_DEPLOYMENT_STATUS" "$CP4BA_ADP_CDRA_DEPLOYMENT_STATUS" "$CP4BA_ADP_CDS_DEPLOYMENT_STATUS" "$CP4BA_ADP_CPDS_DEPLOYMENT_STATUS" "$CP4BA_ADP_GITSVC_DEPLOYMENT_STATUS")
            fi

            #################### ADS #######################
            if [[ " ${EXISTING_PATTERN_ARR[@]}" =~ "decisions_ads" ]]; then
                source ${CUR_DIR}/helper/upgrade/deployment_check/ads_status.sh
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
            AE_ENGINE_DEPLOYMENT=`${YQ_CMD} ".spec.application_engine_configuration // \"\"" "$UPGRADE_STATUS_FILE"`
            cr_metaname=`${YQ_CMD} ".metadata.name" "$UPGRADE_STATUS_FILE"`
            if [[ ! -z "$AE_ENGINE_DEPLOYMENT" ]]; then
                item=0
                while true; do
                    ae_config_name=`${YQ_CMD} ".spec.application_engine_configuration.[${item}].name // \"\"" "$UPGRADE_STATUS_FILE"`
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
            BASTUDIO_DEPLOYMENT=`${YQ_CMD} ".spec.bastudio_configuration.admin_user // \"\"" "$UPGRADE_STATUS_FILE"`
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
            BAML_DEPLOYMENT=`${YQ_CMD} ".spec.baml_configuration // \"\"" "$UPGRADE_STATUS_FILE"`
            if [[ ! -z "$BAML_DEPLOYMENT" ]]; then
                source ${CUR_DIR}/helper/upgrade/deployment_check/baml_status.sh
                CP4BA_COMPONENT_STATUS_VALUES+=("$CP4BA_BAML_DEPLOYMENT_STATUS")
            fi

            #################### BAW runtime Multiple instance #######################
            BAW_DEPLOYMENT=`${YQ_CMD} ".spec.baw_configuration // \"\"" "$UPGRADE_STATUS_FILE"`
            cr_metaname=`${YQ_CMD} ".metadata.name" "$UPGRADE_STATUS_FILE"`
            if [[ ! -z "$BAW_DEPLOYMENT" ]]; then
                item=0
                while true; do
                    baw_instance_name=`${YQ_CMD} ".spec.baw_configuration.[${item}].name // \"\"" "$UPGRADE_STATUS_FILE"`
                    if [[ -z "$baw_instance_name" ]]; then
                        break
                    else
                        source ${CUR_DIR}/helper/upgrade/deployment_check/baw_runtime_status.sh
                        CP4BA_COMPONENT_STATUS_VALUES+=("$CP4BA_BAW_DEPLOYMENT_STATUS")
                        ((item++))
                    fi
                done
            fi
        fi
    fi

    exist_wfps_cr_array=($(${CLI_CMD} get WfPSRuntime -n $project_name --no-headers --ignore-not-found | awk '{print $1}'))
    if [ ! -z $exist_wfps_cr_array ]; then
        for item in "${exist_wfps_cr_array[@]}"
        do
            cr_type="WfPSRuntime"
            cr_metaname=$(${CLI_CMD} get $cr_type ${item} -n $project_name --no-headers --ignore-not-found -o yaml | ${YQ_CMD} '.metadata.name' -)
            ${CLI_CMD} get $cr_type ${item} -n $project_name --no-headers --ignore-not-found -o yaml > ${UPGRADE_STATUS_FILE}
            #################### WfPS #######################
            source ${CUR_DIR}/helper/upgrade/deployment_check/wfps_status.sh
            CP4BA_COMPONENT_STATUS_VALUES+=("$CP4BA_WFPS_DEPLOYMENT_STATUS")
        done

    fi

    exist_pfs_cr_array=($(${CLI_CMD} get ProcessFederationServer -n $project_name --no-headers --ignore-not-found | awk '{print $1}'))
    if [ ! -z $exist_pfs_cr_array ]; then
        for item in "${exist_pfs_cr_array[@]}"
        do
            cr_type="ProcessFederationServer"
            cr_metaname=$(${CLI_CMD} get $cr_type ${item} -n $project_name --no-headers --ignore-not-found -o yaml | ${YQ_CMD} '.metadata.name' -)
            ${CLI_CMD} get $cr_type ${item} -n $project_name --no-headers --ignore-not-found -o yaml > ${UPGRADE_STATUS_FILE}
            #################### WfPS #######################
            source ${CUR_DIR}/helper/upgrade/deployment_check/pfs_status.sh
            CP4BA_COMPONENT_STATUS_VALUES+=("$CP4BA_PFS_DEPLOYMENT_STATUS")
        done

    fi

}

# This function picks up the table built from the check_cp4ba_deployment_status and in addition shows some more messages based on the components displayed
# This function is called in loop until failure or all components are upgraded
function show_cp4ba_upgrade_status() {
    printf '%s %s\n' "$(date)"
    check_cp4ba_deployment_status "${CP4BA_SERVICES_NS}"
    _original_cr_version=${original_cr_version:-"PREVIOUS"}
    ## <https://jsw.ibm.com/browse/DBACLD-159411> - Change the upgrade version to 24.1.* so it will detect as n-1 to n upgrade when upgrading from 24.0.0 to 24.0.1
    if [[ ! ("$cp4ba_original_csv_ver_for_upgrade_script" == "24.1."*) ]]; then
        printf "\n"
        step_num=1
        echo "${YELLOW_TEXT}[NEXT ACTION]${RESET_TEXT}:"
        echo "${YELLOW_TEXT}  * The status above will be refreshing every 30 seconds.  You can continue to monitor and when all the status for the CP4BA components is ${RESET_TEXT}${GREEN_TEXT}\"Done\"${RESET_TEXT}${YELLOW_TEXT}, you can press CTRL+C to exit anytime and then follow the steps below.${RESET_TEXT}:"

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
            echo "${YELLOW_TEXT}[ATTENTION] ${RESET_TEXT}${RED_TEXT}(REQUIRED)${RESET_TEXT}:"
            printf '%b\n' "  ${YELLOW_TEXT}-  AFTER UPGRADING IBM CLOUD PAK FOR BUSINESS AUTOMATION (CP4BA) DEPLOYMENT SUCCESSFULLY, YOU NEED TO REMOVE${RESET_TEXT} ${RED_TEXT}\"recovery_path\"${RESET_TEXT} ${YELLOW_TEXT}FROM CUSTOM RESOURCE UNDER${RESET_TEXT} ${RED_TEXT}\"bai_configuration\"${RESET_TEXT} ${YELLOW_TEXT}MANUALLY IF EXISTING.${RESET_TEXT}"
        fi

        printf "\n"
        echo "${YELLOW_TEXT}[ATTENTION]: ${RESET_TEXT}${YELLOW_TEXT}DON'T SET ${RESET_TEXT}${RED_TEXT}\"shared_configuration.sc_egress_configuration.sc_restricted_internet_access\"${RESET_TEXT}${YELLOW_TEXT} TO ${RESET_TEXT}${RED_TEXT}\"true\"${RESET_TEXT}${YELLOW_TEXT} UNTIL AFTER YOU'VE COMPLETED THE CP4BA UPGRADE TO $CP4BA_RELEASE_BASE.${RESET_TEXT} ${GREEN_TEXT}(UNLESS YOU ALREADY HAD THIS SET TO \"true\" IN THE ${_original_cr_version} CP4BA VERSION)${RESET_TEXT}"
    ## <https://jsw.ibm.com/browse/DBACLD-159411>
    ###### This "else" section is for 24.0.1 ifix to ifix scenario, the instructions are not needed for this scenario, so it is being commented out. ######
    # else
    #     printf "\n"
    #     step_num=1
    #     echo "${YELLOW_TEXT}[NEXT ACTION]${RESET_TEXT}:"
    #     echo "${YELLOW_TEXT}  * After the status of upgrade for CP4BA components showing as ${RESET_TEXT}${GREEN_TEXT}\"Done\"${RESET_TEXT}${YELLOW_TEXT}, you need to execute the following steps${RESET_TEXT}:"
    #     if [[ $css_flag == "true" || " ${EXISTING_OPT_COMPONENT_ARR[@]} " =~ "css" ]]; then
    #         echo "  - STEP ${step_num} ${RED_TEXT}(Required)${RESET_TEXT}: You have Content Search Services (CSS) installed. Make sure you start the IBM Content Search Services index dispatcher. Refer to the FileNet P8 Platform Documentation for more details."
    #         echo "    ${YELLOW_TEXT}* Starting the IBM Content Search Services index dispatcher.${RESET_TEXT}"
    #         echo "      1. Log in to the Administration Console for Content Platform Engine."
    #         echo "      2. In the navigation pane, select the domain icon."
    #         echo "      3. In the edit pane, click the Text Search Subsystem tab and select the Enable indexing check box."
    #         echo "      4. Click Save to save your changes."
    #         printf "\n"
    #         step_num=$((step_num + 1))
    #     fi
    ######
    else
        printf "\n"
        step_num=1
        echo "${YELLOW_TEXT}[NEXT ACTION]${RESET_TEXT}:"
        echo "${YELLOW_TEXT}  * The status above will be refreshing every 30 seconds.  You can continue to monitor and when all the status for the CP4BA components is ${RESET_TEXT}${GREEN_TEXT}\"Done\"${RESET_TEXT}${YELLOW_TEXT}, you can press CTRL+C to exit anytime.${RESET_TEXT}"
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
                        warning "\"ibm-cp4ba-common-config\" configMap was not found in the project \"$CP4BA_SERVICES_NS\"."
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
            info "This CP4BA deployment is separation of operators and operands"
            SEPARATE_OPERAND_FLAG="Yes"
            CP4BA_SERVICES_NS=$cp4ba_services_namespace
            CP4BA_OPERATOR_NS=$cp4ba_operators_namespace
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
