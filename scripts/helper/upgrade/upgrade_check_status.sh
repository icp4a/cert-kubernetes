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
# This function is used in check_cp4ba_operator_version where it will check the version of the operator and compare it with the array of minimum supported upgrade versions
# It will fail if the operator version is not less than the minimum supported upgrade version.
# This function takes 2 arguments:
# 1. version_prefix: The prefix of the version that needs to be checked such as "21.3.", "22.2.", "23.2."
# 2. upgrade_message: The message that will be displayed if the version is not supported
function check_cp4ba_minimum_version(){

    local version_prefix=$1
    local upgrade_message=$2

    for line in "${MINIMUM_SUPPORTED_UPGRADE_VERSIONS[@]}"; do
        if [[ $line == "$version_prefix"* ]]; then
            if [ ! "$(printf '%s\n' "$line" "$cp4a_operator_csv_version" | sort -V | head -n1)" = "$line" ]; then
                info "Found IBM Cloud Pak for Business Automation Operator is \"$cp4a_operator_csv_version\" version."
                fail "$upgrade_message"
                exit 1
            else
                info "Found IBM Cloud Pak for Business Automation Operator is \"$cp4a_operator_csv_version\" version."
                break
            fi
        fi
    done 
}

#DBACLD-163192: Check and make sure that only the version in the MINIMUM_SUPPORTED_BAW_AUTHORING_UPGRADE_VERSIONS array is allowed for direct upgrade to 24.0.0-IF004 or later when BAW authoring is enabled
# The cp4a_operator_csv_version is the version of the operator that is currently installed in the cluster
# The MINIMUM_SUPPORTED_BAW_AUTHORING_UPGRADE_VERSIONS is an array of minimum supported upgrade versions for BAW Authoring.  It is defined in the common.sh file
function check_cp4ba_baw_authoring_minimum_version(){

if [[ ! " ${MINIMUM_SUPPORTED_BAW_AUTHORING_UPGRADE_VERSIONS[*]} " =~ ${cp4a_operator_csv_version} ]]; then
    warning "There is a known issue with the following capabilities: ADS, ADP Development, BAA, Automation Workstream Services, BAW Authoring, BAW Runtime in CP4BA ${cp4a_operator_csv_version} when upgrading to CP4BA ${CP4BA_CSV_VERSION}.  Please refer to the technote https://www.ibm.com/mysupport/aCIKe000000CkmPOAS to check and perform the necessary steps before you can upgrade to CP4BA ${CP4BA_CSV_VERSION}"
    read -r -p "Select 'Yes' to continue with the upgrade if you have checked and confirmed that the database schema is in the correct state.  (Yes/No) (Default: No): " confirmation
    if [[ ! $confirmation =~ ^[Yy]([Ee][Ss])?$ ]]; then
        fail "Upgrade is stopped. Check and perform the necessary steps from the above technote before upgrading to CP4BA ${CP4BA_CSV_VERSION}"
        exit 1
    else
        info "Upgrade is continued."
    fi
fi

}
#DBACLD-163910: Checking the validity of EDB license.
# We will check for the validity of EDB license.  We'll display the valid license along with the expired license (if any).  We'll prompt the user to review the technote to update the license before  continue with the upgrade if the license is expired.
function check_edb_license(){
    info "Checking the validity of EDB license(s)"
    edb_license_status=$(oc get cluster.postgresql -A -o jsonpath='{range .items[*]}{.metadata.namespace}{"\t"}{.metadata.name}{"\t"}{.status.licenseStatus.licenseExpiration}{"\t"}{.status.licenseStatus.licenseStatus}{"\n"}{end}')
    edb_license_expired=$( grep -E -i '^.*invalid' <<< "$edb_license_status")
    edb_license_valid=$( grep -E -i '^.*valid' <<< "$edb_license_status" | grep -v -i 'invalid' )
    if [[ -n "$edb_license_valid" ]]; then
        success "The license(s) for the following EDB instance(s) are valid:"
        printf "%s\n" "$edb_license_valid"
        printf "\n"
    fi

    if [[ -n "$edb_license_expired" ]]; then
        warning "The license(s) for the following EDB instance(s) have expired. Follow this technote to renew the license: https://www.ibm.com/support/pages/embedded-postgresql-database-license-key-expires-october-1st-2024-cloud-pak-business-automation-and-can-cause-outages before continuing with the upgrade to CP4BA ${CP4BA_CSV_VERSION}"
        printf "%s\n" "$edb_license_expired"
        read -r -p "Select 'Yes' to continue with the upgrade if you have checked and confirmed that the license(s) have been updated.  (Yes/No) (Default: No): " confirmation
        if [[ ! $confirmation =~ ^[Yy]([Ee][Ss])?$ ]]; then
            fail "Upgrade is stopped. Check and perform the necessary steps from the above technote before upgrading to CP4BA ${CP4BA_CSV_VERSION}"
            exit 1
        else
            info "Upgrade is continued"
        fi
    fi
    # return edb_licenses_expired in this function so that it can be used in the main script
    echo "$edb_license_expired"

}


# function for checking operator version
function check_cp4ba_operator_version(){
    local project_name=$1
    local ALL_NAMESPACE_NAME="openshift-operators"
    local maxRetry=5
    info "Checking the version of IBM Cloud Pak for Business Automation Operator"

    cp4a_operator_csv_name_target_ns=$(kubectl get csv -n $project_name --no-headers --ignore-not-found | grep "IBM Cloud Pak for Business Automation" | awk '{print $1}')
    cp4a_operator_csv_name_allnamespace_ns=$(kubectl get csv -n $ALL_NAMESPACE_NAME --no-headers --ignore-not-found | grep "IBM Cloud Pak for Business Automation" | awk '{print $1}')

    if [[ -z $cp4a_operator_csv_name_allnamespace_ns && -z $cp4a_operator_csv_name_target_ns ]]; then
        fail "No IBM Cloud Pak for Business Automation Operator found in both \"$project_name\" and \"$ALL_NAMESPACE_NAME\" project."
        warning "Input correct project name for CP4BA."
        exit 1
    fi
    for ((retry=0;retry<=${maxRetry};retry++)); do
       
        if [[ -z $cp4a_operator_csv_name_allnamespace_ns && (! -z $cp4a_operator_csv_name_target_ns) ]]; then
            success "Found IBM Cloud Pak for Business Automation Operator deployed in the project \"$project_name\"."
            ALL_NAMESPACE_FLAG="No"
            TEMP_OPERATOR_PROJECT_NAME=$project_name
        elif [[ (! -z $cp4a_operator_csv_name_allnamespace_ns) && (! -z $cp4a_operator_csv_name_target_ns) ]]; then
            success "Found IBM Cloud Pak for Business Automation Operator deployed as AllNamespace mode in the project \"$ALL_NAMESPACE_NAME\"."
            ALL_NAMESPACE_FLAG="Yes"
            project_name="openshift-operators"
            TEMP_OPERATOR_PROJECT_NAME="openshift-operators"
        fi

        cp4a_operator_csv_version=$(kubectl get csv $cp4a_operator_csv_name_target_ns -n $project_name --no-headers --ignore-not-found -o 'jsonpath={.spec.version}')

        if [[ ! -z $CP4BA_ORIGINAL_CSV_VERSION ]]; then
            CP4BA_ORIGINAL_CSV_VERSION=$(sed -e 's/^"//' -e 's/"$//' <<<"$CP4BA_ORIGINAL_CSV_VERSION")
            cp4a_operator_csv_version=$CP4BA_ORIGINAL_CSV_VERSION
        fi


        if [[ "$cp4a_operator_csv_version" == "${CP4BA_CSV_VERSION//v/}" ]]; then
            success "The current IBM Cloud Pak for Business Automation Operator is already ${CP4BA_CSV_VERSION//v/}"
            break
            # exit 1
        elif [[ "$cp4a_operator_csv_version" == "24.0."* ]]; then
            info "Found IBM Cloud Pak for Business Automation Operator is \"$cp4a_operator_csv_version\" version."
            break

        # CP4BA 21.0.3.x.  Minimum version is defined in MINIMUM_SUPPORTED_UPGRADE_VERSIONS array
        elif [[ "$cp4a_operator_csv_version" == "21.3."* ]]; then
            check_cp4ba_minimum_version "21.3." "Please upgrade to CP4BA v21.0.3-IF031 or later iFix first before you can upgrade to CP4BA $CP4BA_CSV_VERSION"
            
            #DBACLD-163192: Call check_cp4ba_baw_authoring_minimum_version function to check the minimum supported version for  BAW Authoring.
            check_cp4ba_baw_authoring_minimum_version

            break
        #CP4BA 22.0.1.x
        elif [[ "$cp4a_operator_csv_version" == "22.1."* ]]; then
            fail "Upgrade to CP4BA v22.0.2 IF006 first, then upgrade to CP4BA $CP4BA_CSV_VERSION"
            exit 1

        # CP4BA 22.0.2.x
        elif [[ "$cp4a_operator_csv_version" == "22.2."* ]]; then
            check_cp4ba_minimum_version "22.2." "Please upgrade to CP4BA v22.2.6 or later iFix first before you can upgrade to CP4BA $CP4BA_CSV_VERSION"
            break
        # CP4BA 23.0.1.x
        elif [[ "$cp4a_operator_csv_version" == "23.1."* ]]; then
            fail "Upgrade to CP4BA v23.0.2 IF006 first, then upgrade to CP4BA $CP4BA_CSV_VERSION"
            exit 1
        
        # CP4BA 23.0.2.x. Minimum version is defined in MINIMUM_SUPPORTED_UPGRADE_VERSIONS array
        elif [[ "$cp4a_operator_csv_version" == "23.2."* ]]; then
            check_cp4ba_minimum_version "23.2." "Please upgrade to CP4BA v23.2.6 or later iFix first before you can upgrade to CP4BA $CP4BA_CSV_VERSION"
            break
        
        elif [[ "$cp4a_operator_csv_version" != "${CP4BA_CSV_VERSION//v/}" ]]; then
            if [[ $retry -eq ${maxRetry} ]]; then
                info "Timeout Checking for the version of IBM Cloud Pak for Business Automation in the project \"$project_name\""
                exit 1
            else
                sleep 2
                echo -n "..."
                continue
            fi
        fi
    done
    # success "Found the IBM Cloud Pak for Business Automation Operator $cp4a_operator_csv_version \n"
}

# function for checking operator version
# Not being used. This is just for reference
function check_content_operator_version(){
    local project_name=$1
    local maxRetry=5
    info "Checking the version of IBM CP4BA FileNet Content Manager Operator"
    for ((retry=0;retry<=${maxRetry};retry++)); do
        cp4a_content_operator_csv_name=$(kubectl get csv -n $project_name --no-headers --ignore-not-found | grep "IBM CP4BA FileNet Content Manager" | awk '{print $1}')
        cp4a_content_operator_csv_version=$(kubectl get csv $cp4a_content_operator_csv_name -n $project_name --no-headers --ignore-not-found -o 'jsonpath={.spec.version}')

        if [[ "$cp4a_content_operator_csv_version" == "${CP4BA_CSV_VERSION//v/}" ]]; then
            success "The current IBM CP4BA FileNet Content Manager Operator is already ${CP4BA_CSV_VERSION//v/}"
            break
        elif [[ "$cp4a_content_operator_csv_version" == "22.2."* ]]; then
            cp4a_content_operator_csv=$(kubectl get csv $cp4a_content_operator_csv_name -n $project_name --no-headers --ignore-not-found -o 'jsonpath={.spec.version}')
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
                echo -n "..."
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
            isReady=$(kubectl get csv ibm-common-service-operator.$CS_OPERATOR_VERSION --no-headers --ignore-not-found -n $project_name -o jsonpath='{.status.phase}')
            # isReady=$(kubectl exec $cpe_pod_name -c ${meta_name}-cpe-deploy -n $project_name -- cat /opt/ibm/version.txt |grep -F "P8 Content Platform Engine 23.0.1")
            if [[ $isReady != "Succeeded" ]]; then
                if [[ $retry -eq ${maxRetry} ]]; then
                printf "\n"
                warning "Timeout waiting for IBM Cloud Pak foundational operator to start"
                echo -e "\x1B[1mCheck the status of Pod by issuing the following command:\x1B[0m"
                echo "oc describe pod $(oc get pod -n $project_name|grep ibm-common-service-operator|awk '{print $1}') -n $project_name"
                printf "\n"
                echo -e "\x1B[1mCheck the status of ReplicaSet by issuing the following command:\x1B[0m"
                echo "oc describe rs $(oc get rs -n $project_name|grep ibm-common-service-operator|awk '{print $1}') -n $project_name"
                printf "\n"
                exit 1
                else
                sleep 30
                echo -n "..."
                continue
                fi
            elif [[ $isReady == "Succeeded" ]]; then
                pod_name=$(kubectl get pod -l=name=ibm-common-service-operator -n $project_name -o 'custom-columns=NAME:.metadata.name,PHASE:.status.phase,READY:.status.containerStatuses[0].ready,DELETED:.metadata.deletionTimestamp' --no-headers --ignore-not-found | grep 'Running' | grep 'true' | grep '<none>' | head -1 | awk '{print $1}')
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
    #                 echo -e "\x1B[1mPlease check the status of Pod by issue cmd:\x1B[0m"
    #                 echo "${CLI_CMD} describe pod $(${CLI_CMD} get pod -n $project_name|grep ibm-events-operator|awk '{print $1}') -n $project_name"
    #                 printf "\n"
    #                 echo -e "\x1B[1mPlease check the status of ReplicaSet by issue cmd:\x1B[0m"
    #                 echo "${CLI_CMD} describe rs $(${CLI_CMD} get rs -n $project_name|grep ibm-events-operator|awk '{print $1}') -n $project_name"
    #                 printf "\n"
    #                 exit 1
    #                 else
    #                 sleep 30
    #                 echo -n "..."
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
            isReady=$(kubectl get csv ibm-cp4a-operator.$CP4BA_CSV_VERSION --no-headers --ignore-not-found -n $project_name -o jsonpath='{.status.phase}')
            # isReady=$(kubectl exec $cpe_pod_name -c ${meta_name}-cpe-deploy -n $project_name -- cat /opt/ibm/version.txt |grep -F "P8 Content Platform Engine 23.0.1")
            if [[ -z $isReady ]]; then
                fail "Failed to upgrade the IBM Cloud Pak for Business Automation (CP4BA) multi-pattern operator to ibm-cp4a-operator.$CP4BA_CSV_VERSION in the project \"$project_name\"" 
                msg "Check the Subscription and ClusterServiceVersions and then fix issue first."
                exit 1
            elif [[ $isReady != "Succeeded" ]]; then
                if [[ $retry -eq ${maxRetry} ]]; then
                printf "\n"
                warning "Timeout waiting for IBM Cloud Pak for Business Automation (CP4BA) multi-pattern operator to start"
                echo -e "\x1B[1mCheck the status of Pod by issuing the following command:\x1B[0m"
                echo "oc describe pod $(oc get pod -n $project_name|grep ibm-cp4a-operator|awk '{print $1}') -n $project_name"
                printf "\n"
                echo -e "\x1B[1mCheck the status of ReplicaSet by issuing the following command:\x1B[0m"
                echo "oc describe rs $(oc get rs -n $project_name|grep ibm-cp4a-operator|awk '{print $1}') -n $project_name"
                printf "\n"
                exit 1
                else
                sleep 30
                echo -n "..."
                continue
                fi
            elif [[ $isReady == "Succeeded" ]]; then
                if [[ "$check_channel" != "channel" ]]; then
                    pod_name=$(kubectl get pod -l=name=ibm-cp4a-operator,release=23.0.1 -n $project_name -o 'custom-columns=NAME:.metadata.name,PHASE:.status.phase,READY:.status.containerStatuses[0].ready,DELETED:.metadata.deletionTimestamp' --no-headers --ignore-not-found | grep 'Running' | grep 'true' | grep '<none>' | head -1 | awk '{print $1}')
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
        isReady=$(kubectl get csv ibm-content-operator.$CP4BA_CSV_VERSION --no-headers --ignore-not-found -n $project_name -o jsonpath='{.status.phase}')
        # isReady=$(kubectl exec $cpe_pod_name -c ${meta_name}-cpe-deploy -n $project_name -- cat /opt/ibm/version.txt |grep -F "P8 Content Platform Engine 23.0.1")
        if [[ -z $isReady ]]; then
            csv_version=""
            csv_version=$(kubectl get csv $(kubectl get csv --no-headers --ignore-not-found -n $project_name | grep ibm-content-operator.v |awk '{print $1}') --no-headers --ignore-not-found -n $project_name -o jsonpath='{.spec.version}')
            if [[ "v$csv_version" != $CP4BA_CSV_VERSION ]]; then
                if [[ $retry -eq ${maxRetry} ]]; then
                    fail "Failed to upgrade the IBM CP4BA FileNet Content Manager operator to ibm-content-operator.$CP4BA_CSV_VERSION in the project \"$project_name\"" 
                    msg "Check the Subscription and ClusterServiceVersions and then fix issue first."
                    exit 1
                else
                    sleep 30
                    echo -n "..."
                    continue
                fi
            fi
        elif [[ $isReady != "Succeeded" ]]; then
            if [[ $retry -eq ${maxRetry} ]]; then
                printf "\n"
                warning "Timeout waiting for IBM CP4BA FileNet Content Manager operator to start"
                echo -e "\x1B[1mCheck the status of Pod by issuing the following command:\x1B[0m"
                echo "oc describe pod $(oc get pod -n $project_name|grep ibm-content-operator|awk '{print $1}') -n $project_name"
                printf "\n"
                echo -e "\x1B[1mCheck the status of ReplicaSet by issuing the following command:\x1B[0m"
                echo "oc describe rs $(oc get rs -n $project_name|grep ibm-content-operator|awk '{print $1}') -n $project_name"
                printf "\n"
                exit 1
            else
                sleep 30
                echo -n "..."
                continue
            fi
        elif [[ $isReady == "Succeeded" ]]; then
            if [[ "$check_channel" != "channel" ]]; then
                pod_name=$(kubectl get pod -l=name=ibm-content-operator,release=$CP4BA_RELEASE_BASE --no-headers --ignore-not-found -n $project_name -o 'custom-columns=NAME:.metadata.name,PHASE:.status.phase,READY:.status.containerStatuses[0].ready,DELETED:.metadata.deletionTimestamp' | grep 'Running' | grep 'true' | grep '<none>' | head -1 | awk '{print $1}')
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
        isReady=$(kubectl get csv icp4a-foundation-operator.$CP4BA_CSV_VERSION --no-headers --ignore-not-found -n $project_name -o jsonpath='{.status.phase}')
        # isReady=$(kubectl exec $cpe_pod_name -c ${meta_name}-cpe-deploy -n $project_name -- cat /opt/ibm/version.txt |grep -F "P8 Content Platform Engine 23.0.1")
        if [[ -z $isReady ]]; then
            csv_version=""
            csv_version=$(kubectl get csv $(kubectl get csv --no-headers --ignore-not-found -n $project_name | grep icp4a-foundation-operator.v |awk '{print $1}') --no-headers --ignore-not-found -n $project_name -o jsonpath='{.spec.version}')
            if [[ "v$csv_version" != $CP4BA_CSV_VERSION ]]; then
                if [[ $retry -eq ${maxRetry} ]]; then
                    fail "Failed to upgrade the IBM CP4BA Foundation operator to icp4a-foundation-operator.$CP4BA_CSV_VERSION in the project \"$project_name\"" 
                    msg "Check the Subscription and ClusterServiceVersions and then fix issue first."
                    exit 1
                else
                    sleep 30
                    echo -n "..."
                    continue
                fi
            fi
        elif [[ $isReady != "Succeeded" ]]; then
            if [[ $retry -eq ${maxRetry} ]]; then
            printf "\n"
            warning "Timeout waiting for CP4BA Foundation operator to start"
            echo -e "\x1B[1mCheck the status of Pod by issuing the following command:\x1B[0m"
            echo "oc describe pod $(oc get pod -n $project_name|grep icp4a-foundation-operator|awk '{print $1}') -n $project_name"
            printf "\n"
            echo -e "\x1B[1mCheck the status of ReplicaSet by issuing the following command:\x1B[0m"
            echo "oc describe rs $(oc get rs -n $project_name|grep icp4a-foundation-operator|awk '{print $1}') -n $project_name"
            printf "\n"
            exit 1
            else
            sleep 30
            echo -n "..."
            continue
            fi
        elif [[ $isReady == "Succeeded" ]]; then
            if [[ "$check_channel" != "channel" ]]; then
                pod_name=$(kubectl get pod -l=name=icp4a-foundation-operator,release=$CP4BA_RELEASE_BASE --no-headers --ignore-not-found -n $project_name -o 'custom-columns=NAME:.metadata.name,PHASE:.status.phase,READY:.status.containerStatuses[0].ready,DELETED:.metadata.deletionTimestamp' | grep 'Running' | grep 'true' | grep '<none>' | head -1 | awk '{print $1}')
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
        isReady=$(kubectl get csv ibm-ads-operator.$CP4BA_CSV_VERSION --no-headers --ignore-not-found -n $project_name -o jsonpath='{.status.phase}')
        # isReady=$(kubectl exec $cpe_pod_name -c ${meta_name}-cpe-deploy -n $project_name -- cat /opt/ibm/version.txt |grep -F "P8 Content Platform Engine 23.0.1")
        if [[ -z $isReady ]]; then
            csv_version=""
            csv_version=$(kubectl get csv $(kubectl get csv --no-headers --ignore-not-found -n $project_name | grep ibm-ads-operator.v |awk '{print $1}') --no-headers --ignore-not-found -n $project_name -o jsonpath='{.spec.version}')
            if [[ "v$csv_version" != $CP4BA_CSV_VERSION ]]; then
                if [[ $retry -eq ${maxRetry} ]]; then
                    fail "Failed to upgrade the IBM CP4BA Automation Decision Service operator to ibm-ads-operator.$CP4BA_CSV_VERSION in the project \"$project_name\"" 
                    msg "Check the Subscription and ClusterServiceVersions and then fix issue first."
                    exit 1
                else
                    sleep 30
                    echo -n "..."
                    continue
                fi
            fi
        elif [[ $isReady != "Succeeded" ]]; then
            if [[ $retry -eq ${maxRetry} ]]; then
            printf "\n"
            warning "Timeout waiting for IBM CP4BA Automation Decision Service operator to start"
            echo -e "\x1B[1mCheck the status of Pod by issuing the following command:\x1B[0m"
            echo "oc describe pod $(oc get pod -n $project_name|grep ibm-ads-operator|awk '{print $1}') -n $project_name"
            printf "\n"
            echo -e "\x1B[1mCheck the status of ReplicaSet by issuing the following command:\x1B[0m"
            echo "oc describe rs $(oc get rs -n $project_name|grep ibm-ads-operator|awk '{print $1}') -n $project_name"
            printf "\n"
            exit 1
            else
            sleep 30
            echo -n "..."
            continue
            fi
        elif [[ $isReady == "Succeeded" ]]; then
            if [[ "$check_channel" != "channel" ]]; then
                pod_name=$(kubectl get pod -l=name=ibm-ads-operator -n $project_name -o 'custom-columns=NAME:.metadata.name,PHASE:.status.phase,READY:.status.containerStatuses[0].ready,DELETED:.metadata.deletionTimestamp' --no-headers --ignore-not-found | grep 'Running' | grep 'true' | grep '<none>' | head -1 | awk '{print $1}')
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
            isReady=$(kubectl get csv ibm-odm-operator.$CP4BA_CSV_VERSION --no-headers --ignore-not-found -n $project_name -o jsonpath='{.status.phase}')
            # isReady=$(kubectl exec $cpe_pod_name -c ${meta_name}-cpe-deploy -n $project_name -- cat /opt/ibm/version.txt |grep -F "P8 Content Platform Engine 23.0.1")
            if [[ -z $isReady ]]; then
                csv_version=""
                csv_version=$(kubectl get csv $(kubectl get csv --no-headers --ignore-not-found -n $project_name | grep ibm-odm-operator.v |awk '{print $1}') --no-headers --ignore-not-found -n $project_name -o jsonpath='{.spec.version}')
                if [[ "v$csv_version" != $CP4BA_CSV_VERSION ]]; then
                    if [[ $retry -eq ${maxRetry} ]]; then
                        fail "Failed to upgrade the IBM Operational Decision Manager operator to ibm-odm-operator.$CP4BA_CSV_VERSION in the project \"$project_name\"" 
                        msg "Check the Subscription and ClusterServiceVersions and then fix issue first."
                        exit 1
                    else
                        sleep 30
                        echo -n "..."
                        continue
                    fi
                fi
            elif [[ $isReady != "Succeeded" ]]; then
                if [[ $retry -eq ${maxRetry} ]]; then
                printf "\n"
                warning "Timeout waiting for IBM Operational Decision Manager operator to start"
                echo -e "\x1B[1mCheck the status of Pod by issuing the following command:\x1B[0m"
                echo "oc describe pod $(oc get pod -n $project_name|grep ibm-odm-operator|awk '{print $1}') -n $project_name"
                printf "\n"
                echo -e "\x1B[1mCheck the status of ReplicaSet by issuing the following command:\x1B[0m"
                echo "oc describe rs $(oc get rs -n $project_name|grep ibm-odm-operator|awk '{print $1}') -n $project_name"
                printf "\n"
                exit 1
                else
                sleep 30
                echo -n "..."
                continue
                fi
            elif [[ $isReady == "Succeeded" ]]; then
                if [[ "$check_channel" != "channel" ]]; then
                    pod_name=$(kubectl get pod -l=name=ibm-odm-operator -n $project_name -o 'custom-columns=NAME:.metadata.name,PHASE:.status.phase,READY:.status.containerStatuses[0].ready,DELETED:.metadata.deletionTimestamp' --no-headers --ignore-not-found | grep 'Running' | grep 'true' | grep '<none>' | head -1 | awk '{print $1}')
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

        arch_type=$(kubectl get cm cluster-config-v1 -n kube-system --no-headers --ignore-not-found -o yaml | grep -i architecture|tail -1| awk '{print $2}')
        if [[ "$arch_type" == "amd64" ]]; then
            echo "****************************************************************************"
            info "Checking for IBM Document Processing Engine operator pod initialization"
            for ((retry=0;retry<=${maxRetry};retry++)); do
                isReady=$(kubectl get csv ibm-dpe-operator.$CP4BA_CSV_VERSION --no-headers --ignore-not-found -n $project_name -o jsonpath='{.status.phase}')
                # isReady=$(kubectl exec $cpe_pod_name -c ${meta_name}-cpe-deploy -n $project_name -- cat /opt/ibm/version.txt |grep -F "P8 Content Platform Engine 23.0.1")
                if [[ -z $isReady ]]; then
                    csv_version=""
                    csv_version=$(kubectl get csv $(kubectl get csv --no-headers --ignore-not-found -n $project_name | grep ibm-dpe-operator.v |awk '{print $1}') --no-headers --ignore-not-found -n $project_name -o jsonpath='{.spec.version}')
                    if [[ "v$csv_version" != $CP4BA_CSV_VERSION ]]; then
                        if [[ $retry -eq ${maxRetry} ]]; then
                            fail "Failed to upgrade the IBM Document Processing Engine operator to ibm-dpe-operator.$CP4BA_CSV_VERSION in the project \"$project_name\"" 
                            msg "Check the Subscription and ClusterServiceVersions and then fix issue first."
                            exit 1
                        else
                            sleep 30
                            echo -n "..."
                            continue
                        fi
                    fi
                elif [[ $isReady != "Succeeded" ]]; then
                    if [[ $retry -eq ${maxRetry} ]]; then
                    printf "\n"
                    warning "Timeout waiting for IBM Document Processing Engine operator to start"
                    echo -e "\x1B[1mCheck the status of Pod by issuing the following command:\x1B[0m"
                    echo "oc describe pod $(oc get pod -n $project_name|grep ibm-dpe-operator|awk '{print $1}') -n $project_name"
                    printf "\n"
                    echo -e "\x1B[1mCheck the status of ReplicaSet by issuing the following command:\x1B[0m"
                    echo "oc describe rs $(oc get rs -n $project_name|grep ibm-dpe-operator|awk '{print $1}') -n $project_name"
                    printf "\n"
                    exit 1
                    else
                    sleep 30
                    echo -n "..."
                    continue
                    fi
                elif [[ $isReady == "Succeeded" ]]; then
                    if [[ "$check_channel" != "channel" ]]; then
                        pod_name=$(kubectl get pod -l=name=ibm-dpe-operator -n $project_name -o 'custom-columns=NAME:.metadata.name,PHASE:.status.phase,READY:.status.containerStatuses[0].ready,DELETED:.metadata.deletionTimestamp' --no-headers --ignore-not-found | grep 'Running' | grep 'true' | grep '<none>' | head -1 | awk '{print $1}')
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
        isReady=$(kubectl get csv ibm-cp4a-wfps-operator.$CP4BA_CSV_VERSION --no-headers --ignore-not-found -n $project_name -o jsonpath='{.status.phase}')
        if [[ -z $isReady ]]; then
            csv_version=""
            csv_version=$(kubectl get csv $(kubectl get csv --no-headers --ignore-not-found -n $project_name | grep ibm-cp4a-wfps-operator.v |awk '{print $1}') --no-headers --ignore-not-found -n $project_name -o jsonpath='{.spec.version}')
            if [[ "v$csv_version" != $CP4BA_CSV_VERSION ]]; then
                if [[ $retry -eq ${maxRetry} ]]; then
                    fail "Failed to upgrade the IBM CP4BA Workflow Process Service operator to ibm-cp4a-wfps-operator.$CP4BA_CSV_VERSION in the project \"$project_name\"" 
                    msg "Check the Subscription and ClusterServiceVersions and then fix issue first."
                    exit 1
                else
                    sleep 30
                    echo -n "..."
                    continue
                fi
            fi
        # isReady=$(kubectl exec $cpe_pod_name -c ${meta_name}-cpe-deploy -n $project_name -- cat /opt/ibm/version.txt |grep -F "P8 Content Platform Engine 23.0.1")
        elif [[ $isReady != "Succeeded" ]]; then
            if [[ $retry -eq ${maxRetry} ]]; then
            printf "\n"
            warning "Timeout waiting for IBM CP4BA Workflow Process Service operator to start"
            echo -e "\x1B[1mCheck the status of Pod by issuing the following command:\x1B[0m"
            echo "oc describe pod $(oc get pod -n $project_name|grep ibm-cp4a-wfps-operator|awk '{print $1}') -n $project_name"
            printf "\n"
            echo -e "\x1B[1mCheck the status of ReplicaSet by issuing the following command:\x1B[0m"
            echo "oc describe rs $(oc get rs -n $project_name|grep ibm-cp4a-wfps-operator|awk '{print $1}') -n $project_name"
            printf "\n"
            exit 1
            else
            sleep 30
            echo -n "..."
            continue
            fi
        elif [[ $isReady == "Succeeded" ]]; then
            if [[ "$check_channel" != "channel" ]]; then
                pod_name=$(kubectl get pod -l=name=ibm-cp4a-wfps-operator -n $project_name -o 'custom-columns=NAME:.metadata.name,PHASE:.status.phase,READY:.status.containerStatuses[0].ready,DELETED:.metadata.deletionTimestamp' --no-headers --ignore-not-found | grep 'Running' | grep 'true' | grep '<none>' | head -1 | awk '{print $1}')
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
            isReady=$(kubectl get csv ibm-insights-engine-operator.$CP4BA_CSV_VERSION --no-headers --ignore-not-found -n $project_name -o jsonpath='{.status.phase}')
            # isReady=$(kubectl exec $cpe_pod_name -c ${meta_name}-cpe-deploy -n $project_name -- cat /opt/ibm/version.txt |grep -F "P8 Content Platform Engine 23.0.1")
            if [[ -z $isReady ]]; then
                csv_version=""
                csv_version=$(kubectl get csv $(kubectl get csv --no-headers --ignore-not-found -n $project_name | grep ibm-insights-engine-operator.v |awk '{print $1}') --no-headers --ignore-not-found -n $project_name -o jsonpath='{.spec.version}')
                if [[ "v$csv_version" != $CP4BA_CSV_VERSION ]]; then
                    if [[ $retry -eq ${maxRetry} ]]; then
                        fail "Failed to upgrade the IBM CP4BA Insights Engine operator to ibm-insights-engine-operator.$CP4BA_CSV_VERSION in the project \"$project_name\"" 
                        msg "Check the Subscription and ClusterServiceVersions and then fix issue first."
                        exit 1
                    else
                        sleep 30
                        echo -n "..."
                        continue
                    fi
                fi
            elif [[ $isReady != "Succeeded" ]]; then
                if [[ $retry -eq ${maxRetry} ]]; then
                printf "\n"
                warning "Timeout waiting for IBM CP4BA Insights Engine operator to start"
                echo -e "\x1B[1mCheck the status of Pod by issuing the following command:\x1B[0m"
                echo "oc describe pod $(oc get pod -n $project_name|grep ibm-insights-engine-operator|awk '{print $1}') -n $project_name"
                printf "\n"
                echo -e "\x1B[1mCheck the status of ReplicaSet by issuing the following command:\x1B[0m"
                echo "oc describe rs $(oc get rs -n $project_name|grep ibm-insights-engine-operator|awk '{print $1}') -n $project_name"
                printf "\n"
                exit 1
                else
                sleep 30
                echo -n "..."
                continue
                fi
            elif [[ $isReady == "Succeeded" ]]; then
                if [[ "$check_channel" != "channel" ]]; then
                    pod_name=$(kubectl get pod -l=name=ibm-insights-engine-operator -n $project_name -o 'custom-columns=NAME:.metadata.name,PHASE:.status.phase,READY:.status.containerStatuses[0].ready,DELETED:.metadata.deletionTimestamp' --no-headers --ignore-not-found | grep 'Running' | grep 'true' | grep '<none>' | head -1 | awk '{print $1}')
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
        isReady=$(kubectl get csv ibm-pfs-operator.$CP4BA_CSV_VERSION --no-headers --ignore-not-found -n $project_name -o jsonpath='{.status.phase}')
        # isReady=$(kubectl exec $cpe_pod_name -c ${meta_name}-cpe-deploy -n $project_name -- cat /opt/ibm/version.txt |grep -F "P8 Content Platform Engine 23.0.1")
        if [[ -z $isReady ]]; then
            csv_version=""
            csv_version=$(kubectl get csv $(kubectl get csv --no-headers --ignore-not-found -n $project_name | grep ibm-pfs-operator.v |awk '{print $1}') --no-headers --ignore-not-found -n $project_name -o jsonpath='{.spec.version}')
            if [[ "v$csv_version" != $CP4BA_CSV_VERSION ]]; then
                if [[ $retry -eq ${maxRetry} ]]; then
                    fail "Failed to upgrade the IBM CP4BA Process Federation Server operator to ibm-pfs-operator.$CP4BA_CSV_VERSION in the project \"$project_name\"" 
                    msg "Check the Subscription and ClusterServiceVersions and then fix issue first."
                    exit 1
                else
                    sleep 30
                    echo -n "..."
                    continue
                fi
            fi
        elif [[ $isReady != "Succeeded" ]]; then
            if [[ $retry -eq ${maxRetry} ]]; then
            printf "\n"
            warning "Timeout waiting for IBM CP4BA Process Federation Server operator to start"
            echo -e "\x1B[1mCheck the status of Pod by issuing the following command:\x1B[0m"
            echo "oc describe pod $(oc get pod -n $project_name|grep ibm-pfs-operator|awk '{print $1}') -n $project_name"
            printf "\n"
            echo -e "\x1B[1mCheck the status of ReplicaSet by issuing the following command:\x1B[0m"
            echo "oc describe rs $(oc get rs -n $project_name|grep ibm-pfs-operator|awk '{print $1}') -n $project_name"
            printf "\n"
            exit 1
            else
            sleep 30
            echo -n "..."
            continue
            fi
        elif [[ $isReady == "Succeeded" ]]; then
            if [[ "$check_channel" != "channel" ]]; then
                pod_name=$(kubectl get pod -l=name=ibm-pfs-operator -n $project_name -o 'custom-columns=NAME:.metadata.name,PHASE:.status.phase,READY:.status.containerStatuses[0].ready,DELETED:.metadata.deletionTimestamp' --no-headers --ignore-not-found | grep 'Running' | grep 'true' | grep '<none>' | head -1 | awk '{print $1}')
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
        isReady=$(kubectl get csv ibm-workflow-operator.$CP4BA_CSV_VERSION --no-headers --ignore-not-found -n $project_name -o jsonpath='{.status.phase}')
        # isReady=$(kubectl exec $cpe_pod_name -c ${meta_name}-cpe-deploy -n $project_name -- cat /opt/ibm/version.txt |grep -F "P8 Content Platform Engine 23.0.1")
        if [[ -z $isReady ]]; then
            csv_version=""
            csv_version=$(kubectl get csv $(kubectl get csv --no-headers --ignore-not-found -n $project_name | grep ibm-workflow-operator.v |awk '{print $1}') --no-headers --ignore-not-found -n $project_name -o jsonpath='{.spec.version}')
            if [[ "v$csv_version" != $CP4BA_CSV_VERSION ]]; then
                if [[ $retry -eq ${maxRetry} ]]; then
                    fail "Failed to upgrade the IBM CP4BA Workflow operator to ibm-workflow-operator.$CP4BA_CSV_VERSION in the project \"$project_name\"" 
                    msg "Check the Subscription and ClusterServiceVersions and then fix issue first."
                    exit 1
                else
                    sleep 30
                    echo -n "..."
                    continue
                fi
            fi
        elif [[ $isReady != "Succeeded" ]]; then
            if [[ $retry -eq ${maxRetry} ]]; then
            printf "\n"
            warning "Timeout waiting for IBM CP4BA Workflow operator to start"
            echo -e "\x1B[1mCheck the status of Pod by issuing the following command:\x1B[0m"
            echo "oc describe pod $(oc get pod -n $project_name|grep ibm-workflow-operator|awk '{print $1}') -n $project_name"
            printf "\n"
            echo -e "\x1B[1mCheck the status of ReplicaSet by issuing the following command:\x1B[0m"
            echo "oc describe rs $(oc get rs -n $project_name|grep ibm-workflow-operator|awk '{print $1}') -n $project_name"
            printf "\n"
            exit 1
            else
            sleep 30
            echo -n "..."
            continue
            fi
        elif [[ $isReady == "Succeeded" ]]; then
            if [[ "$check_channel" != "channel" ]]; then
                pod_name=$(kubectl get pod -l=name=ibm-workflow-operator -n $project_name -o 'custom-columns=NAME:.metadata.name,PHASE:.status.phase,READY:.status.containerStatuses[0].ready,DELETED:.metadata.deletionTimestamp' --no-headers --ignore-not-found | grep 'Running' | grep 'true' | grep '<none>' | head -1 | awk '{print $1}')
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

    cp4ba_cr_name=$(kubectl get icp4acluster -n $project_name --no-headers --ignore-not-found | awk '{print $1}')
    if [ ! -z "$cp4ba_cr_name" ]; then
        cp4ba_cr_metaname=$(kubectl get icp4acluster $cp4ba_cr_name -n $project_name --no-headers --ignore-not-found -o yaml | ${YQ_CMD} '.metadata.name' -)
        kubectl get icp4acluster $cp4ba_cr_name -n ${project_name} --no-headers --ignore-not-found -o yaml > ${UPGRADE_STATUS_CP4BA_FILE}
    fi

    content_cr_name=$(kubectl get content -n $project_name --no-headers --ignore-not-found | awk '{print $1}')
    if [ ! -z "$content_cr_name" ]; then
        content_cr_metaname=$(kubectl get content $content_cr_name -n $project_name --no-headers --ignore-not-found -o yaml | ${YQ_CMD} '.metadata.name' -)
        kubectl get content $content_cr_name -n ${project_name} --no-headers --ignore-not-found -o yaml > ${UPGRADE_STATUS_CONTENT_FILE}
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
            owner_ref=$(kubectl get content $content_cr_name -n $project_name --no-headers --ignore-not-found -o yaml | ${YQ_CMD} '.metadata.ownerReferences.[0].kind // ""' -)
            #################### FNCM #######################
            if [[ -z "${owner_ref}" ]]; then
                #this variable is being used to check what the version of CP4BA was used before upgrade and is used later in a check if some alert message is to be printed
                # initial_app_version=`cat $UPGRADE_DEPLOYMENT_CONTENT_CR_BAK | ${YQ_CMD} r - spec.appVersion`
                CONTENT_CR_EXIST="Yes"
                source ${CUR_DIR}/helper/upgrade/deployment_check/fncm_status.sh
                bai_flag=`${YQ_CMD} ".spec.content_optional_components.bai // \"\"" "$UPGRADE_STATUS_FILE"`
                if [[ ! -z "$bai_flag" ]]; then
                    bai_flag=$(echo "$bai_flag" | tr '[:upper:]' '[:lower:]')
                    if [[ "${bai_flag}" == "true" ]]; then
                        source ${CUR_DIR}/helper/upgrade/deployment_check/bai_status.sh
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
            fi

            #################### ADP #######################
            if [[ " ${EXISTING_PATTERN_ARR[@]}" =~ "document_processing" ]]; then
                source ${CUR_DIR}/helper/upgrade/deployment_check/adp_status.sh
            fi

            #################### ADS #######################
            if [[ " ${EXISTING_PATTERN_ARR[@]}" =~ "decisions_ads" ]]; then
            source ${CUR_DIR}/helper/upgrade/deployment_check/ads_status.sh
            fi

            #################### ODM #######################
            containsElement "decisions" "${EXISTING_PATTERN_ARR[@]}"
            odm_Val=$?
            if [[ $odm_Val -eq 0 ]]; then
                source ${CUR_DIR}/helper/upgrade/deployment_check/odm_status.sh
            fi

            #################### RR #######################
            source ${CUR_DIR}/helper/upgrade/deployment_check/rr_status.sh

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
                        ((item++))
                    fi
                done
            fi
            #################### BAStudio #######################
            BASTUDIO_DEPLOYMENT=`${YQ_CMD} ".spec.bastudio_configuration.admin_user // \"\"" "$UPGRADE_STATUS_FILE"`
            if [[ ! -z "$BASTUDIO_DEPLOYMENT" ]]; then
                source ${CUR_DIR}/helper/upgrade/deployment_check/bastudio_status.sh
            fi
            #################### BAI #######################
            if [[ " ${EXISTING_OPT_COMPONENT_ARR[@]} " =~ "bai" ]]; then
                source ${CUR_DIR}/helper/upgrade/deployment_check/bai_status.sh
            fi

            #################### BAML #######################
            BAML_DEPLOYMENT=`${YQ_CMD} ".spec.baml_configuration // \"\"" "$UPGRADE_STATUS_FILE"`
            if [[ ! -z "$BAML_DEPLOYMENT" ]]; then
                source ${CUR_DIR}/helper/upgrade/deployment_check/baml_status.sh
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
                        ((item++))
                    fi
                done
            fi
        fi
    fi

    exist_wfps_cr_array=($(kubectl get WfPSRuntime -n $project_name --no-headers --ignore-not-found | awk '{print $1}'))
    if [ ! -z $exist_wfps_cr_array ]; then
        for item in "${exist_wfps_cr_array[@]}"
        do
            cr_type="WfPSRuntime"
            cr_metaname=$(kubectl get $cr_type ${item} -n $project_name --no-headers --ignore-not-found -o yaml | ${YQ_CMD} '.metadata.name' -)
            kubectl get $cr_type ${item} -n $project_name --no-headers --ignore-not-found -o yaml > ${UPGRADE_STATUS_FILE}
            #################### WfPS #######################
            source ${CUR_DIR}/helper/upgrade/deployment_check/wfps_status.sh
        done

    fi

    exist_pfs_cr_array=($(kubectl get ProcessFederationServer -n $project_name --no-headers --ignore-not-found | awk '{print $1}'))
    if [ ! -z $exist_pfs_cr_array ]; then
        for item in "${exist_pfs_cr_array[@]}"
        do
            cr_type="ProcessFederationServer"
            cr_metaname=$(kubectl get $cr_type ${item} -n $project_name --no-headers --ignore-not-found -o yaml | ${YQ_CMD} '.metadata.name' -)
            kubectl get $cr_type ${item} -n $project_name --no-headers --ignore-not-found -o yaml > ${UPGRADE_STATUS_FILE}
            #################### WfPS #######################
            source ${CUR_DIR}/helper/upgrade/deployment_check/pfs_status.sh
        done

    fi

}

function show_cp4ba_upgrade_status() {
    printf '%s %s\n' "$(date)"
    check_cp4ba_deployment_status "${CP4BA_SERVICES_NS}"

    if [[ ! ("$cp4ba_original_csv_ver_for_upgrade_script" == "24.0."*) ]]; then
        printf "\n"
        step_num=1
        echo "${YELLOW_TEXT}[NEXT ACTION]${RESET_TEXT}:"
        echo "${YELLOW_TEXT}  * The status above will be refreshing every 30 seconds.  You can continue to monitor and when all the status for the CP4BA components is ${RESET_TEXT}${GREEN_TEXT}\"Done\"${RESET_TEXT}${YELLOW_TEXT}, you can press CTRL+C to exit anytime and then follow the steps below.${RESET_TEXT}:"
        if [[ $CONTENT_CR_EXIST == "Yes" || (" ${EXISTING_PATTERN_ARR[@]} " =~ "content") || ((" ${EXISTING_PATTERN_ARR[@]} " =~ "workflow") && (! " ${EXISTING_PATTERN_ARR[@]} " =~ "workflow-process-service")) || (" ${EXISTING_PATTERN_ARR[@]} " =~ "document_processing") || (" ${EXISTING_OPT_COMPONENT_ARR[@]} " =~ "baw_authoring") || (" ${EXISTING_OPT_COMPONENT_ARR[@]} " =~ "ae_data_persistence") ]]; then
            echo -e "  - STEP ${step_num} ${RED_TEXT}(Required)${RESET_TEXT}: Run ${GREEN_TEXT}\"./cp4a-pre-upgrade-and-post-upgrade-optional.sh post-upgrade\"${RESET_TEXT} ${YELLOW_TEXT}(NOTES: AFTER UPGRADING IBM CLOUD PAK FOR BUSINESS AUTOMATION (CP4BA) DEPLOYMENT SUCCESSFULLY, YOU NEED TO RUN \"./cp4a-pre-upgrade-and-post-upgrade-optional.sh post-upgrade\", AND THEN CLEAN BROWSER COOKIE BEFORE LOGIN.${RESET_TEXT}"
            echo -e "    ${YELLOW_TEXT}[ATTENTION]${RESET_TEXT}: ${RED_TEXT}DO NOT need to run it when upgrade CP4BA from 23.0.2.X to 24.0.0 (migration IBM Cloud Pak foundational services from Cluster-scoped -> Cluster-scoped or Namespace-scoped -> Namespace-scoped).${RESET_TEXT}"
            echo -e "    ${YELLOW_TEXT}[NOTES]${RESET_TEXT}: After running ${GREEN_TEXT}\"./cp4a-pre-upgrade-and-post-upgrade-optional.sh post-upgrade\"${RESET_TEXT}, allow the Content operator to complete one reconcile with the newly applied custom resource (CR) before accessing the Administration Console for Content Platform Engine (ACCE)."

            printf "\n"
            step_num=$((step_num + 1))
        fi
            # echo "${YELLOW_TEXT}[ATTENTION] ${RESET_TEXT}${RED_TEXT}(REQUIRED)${RESET_TEXT}:"
        if [[ $CONTENT_CR_EXIST == "Yes" || (" ${EXISTING_PATTERN_ARR[@]} " =~ "content") || ((" ${EXISTING_PATTERN_ARR[@]} " =~ "workflow") && (! " ${EXISTING_PATTERN_ARR[@]} " =~ "workflow-process-service")) || (" ${EXISTING_PATTERN_ARR[@]} " =~ "document_processing") || (" ${EXISTING_OPT_COMPONENT_ARR[@]} " =~ "baw_authoring") || (" ${EXISTING_OPT_COMPONENT_ARR[@]} " =~ "ae_data_persistence") ]]; then
            echo "  - STEP ${step_num} ${RED_TEXT}(Required if Business Automation Insights (BAI) is installed)${RESET_TEXT}: ${YELLOW_TEXT}After completion of upgrade of IBM Cloud Pak for Business Automation deployment, enable the Content Event Emitter if it is configured on an object store for Content Platform Engine.${RESET_TEXT}"
            echo "    1. Log in to the Administration Console for Content Platform Engine."
            echo "    2. Go to Object Stores > object store name > Events, Actions, Processes > Subscriptions."
            echo "    3. Click ContentEventEmitterSubscription or the name of the existing subscription used by the Content event emitter."
            echo "    4. Clicked the Properties tab."
            echo "    5. For the row with the Property Name of Is Enabled, click the Property Value dropdown and select ${GREEN_TEXT}True${RESET_TEXT}."
            echo "    6. Click Save."
            printf "\n"
            step_num=$((step_num + 1))
        fi

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
            echo -e "  ${YELLOW_TEXT}-  AFTER UPGRADING IBM CLOUD PAK FOR BUSINESS AUTOMATION (CP4BA) DEPLOYMENT SUCCESSFULLY, YOU NEED TO REMOVE${RESET_TEXT} ${RED_TEXT}\"recovery_path\"${RESET_TEXT} ${YELLOW_TEXT}FROM CUSTOM RESOURCE UNDER${RESET_TEXT} ${RED_TEXT}\"bai_configuration\"${RESET_TEXT} ${YELLOW_TEXT}MANUALLY IF EXISTING.${RESET_TEXT}"
        fi

        printf "\n"
        echo "${YELLOW_TEXT}[ATTENTION]: ${RESET_TEXT}${YELLOW_TEXT}DON'T SET ${RESET_TEXT}${RED_TEXT}\"shared_configuration.sc_egress_configuration.sc_restricted_internet_access\"${RESET_TEXT}${YELLOW_TEXT} AS ${RESET_TEXT}${RED_TEXT}\"true\"${RESET_TEXT}${YELLOW_TEXT} UNTIL AFTER YOU'VE COMPLETED THE CP4BA UPGRADE TO $CP4BA_RELEASE_BASE.${RESET_TEXT} ${GREEN_TEXT}(UNLESS YOU ALREADY HAD THIS SET TO \"true\" IN THE CP4BA 23.0.2.X)${RESET_TEXT}"
    else
        printf "\n"
        step_num=1
        echo "${YELLOW_TEXT}[NEXT ACTION]${RESET_TEXT}:"
        echo "${YELLOW_TEXT}  * The status above will be refreshing every 30 seconds.  You can continue to monitor and when all the status for the CP4BA components is ${RESET_TEXT}${GREEN_TEXT}\"Done\"${RESET_TEXT}${YELLOW_TEXT}, you can press CTRL+C to exit anytime.${RESET_TEXT}"

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
                echo -e "\x1B[1mWhere (namespace) do you want to deploy CP4BA operands (i.e., runtime pods)? \x1B[0m"
            else
                echo -e "\x1B[1mWhere (namespace) did you deploy CP4BA operands (i.e., runtime pods)? \x1B[0m"
            fi
            read -p "Enter the name for an existing project (namespace): " CP4BA_SERVICES_NS
            if [ -z "$CP4BA_SERVICES_NS" ]; then
                echo -e "\x1B[1;31mEnter a valid project name, project name can not be blank\x1B[0m"
            elif [[ "$CP4BA_SERVICES_NS" == openshift* ]]; then
                echo -e "\x1B[1;31mEnter a valid project name, project name should not be 'openshift' or start with 'openshift' \x1B[0m"
                CP4BA_SERVICES_NS=""
            elif [[ "$CP4BA_SERVICES_NS" == kube* ]]; then
                echo -e "\x1B[1;31mEnter a valid project name, project name should not be 'kube' or start with 'kube' \x1B[0m"
                CP4BA_SERVICES_NS=""
            else
                isProjExists=`${CLI_CMD} get project $CP4BA_SERVICES_NS --ignore-not-found | wc -l`  >/dev/null 2>&1

                if [ "$isProjExists" -ne 2 ] ; then
                    echo -e "\x1B[1;31mInvalid project name, enter a existing project name ...\x1B[0m"
                    CP4BA_SERVICES_NS=""
                else
                    echo -e "\x1B[1mUsing project ${CP4BA_SERVICES_NS}...\x1B[0m"
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
        else
            SEPARATE_OPERAND_FLAG="No"
            CP4BA_SERVICES_NS=$TARGET_PROJECT_NAME
        fi
    else
        warning "\"operator_namespace\\services_namespace\" was not found in \"ibm-cp4ba-common-config\" configMap under the project \"$tmp_namespace_val\""
        fail "You need to set correct value(s) in \"ibm-cp4ba-common-config\" configMap for CP4BA seperate of operand under the project \"$tmp_namespace_val\""
        exit 1
    fi
}
