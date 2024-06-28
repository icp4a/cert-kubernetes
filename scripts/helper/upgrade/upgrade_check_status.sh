#!/BIN/BASH
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

# function for checking operator version
function check_cp4ba_operator_version(){
    local project_name=$1
    local ALL_NAMESPACE_NAME="openshift-operators"
    local maxRetry=5
    info "Checking the version of IBM Cloud Pak for Business Automation Operator"
    for ((retry=0;retry<=${maxRetry};retry++)); do
        cp4a_operator_csv_name_target_ns=$(kubectl get csv -n $project_name --no-headers --ignore-not-found | grep "IBM Cloud Pak for Business Automation" | awk '{print $1}')
        cp4a_operator_csv_name_allnamespace_ns=$(kubectl get csv -n $ALL_NAMESPACE_NAME --no-headers --ignore-not-found | grep "IBM Cloud Pak for Business Automation" | awk '{print $1}')
        
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
        elif [[ "$cp4a_operator_csv_version" == "21.3."* ]]; then
            # cp4a_operator_csv=$(kubectl get csv $cp4a_operator_csv_name_target_ns -n $project_name -o 'jsonpath={.spec.version}')
            # cp4a_operator_csv="22.2.2"
            requiredver="21.3.31"
            if [ ! "$(printf '%s\n' "$requiredver" "$cp4a_operator_csv_version" | sort -V | head -n1)" = "$requiredver" ]; then
                info "Found IBM Cloud Pak for Business Automation Operator is \"$cp4a_operator_csv_version\" version."
                fail "Please upgrade to CP4BA v21.0.3-IF031 or later iFix first before you can upgrade to CP4BA $CP4BA_CSV_VERSION"
                exit 1
            else
                info "Found IBM Cloud Pak for Business Automation Operator is \"$cp4a_operator_csv_version\" version."
                break
            fi
        elif [[ "$cp4a_operator_csv_version" == "23.1."* ]]; then
            info "Found IBM Cloud Pak for Business Automation Operator is \"$cp4a_operator_csv_version\" version."
            fail "Please upgrade to CP4BA v23.0.2-IF003 or later iFix first before you can upgrade to CP4BA $CP4BA_CSV_VERSION"
            exit 1
        elif [[ "$cp4a_operator_csv_version" == "22.1."* ]]; then
            info "Found IBM Cloud Pak for Business Automation Operator is \"$cp4a_operator_csv_version\" version."
            fail "Please upgrade to CP4BA v22.0.2-IF006 or later iFix first before you can upgrade to CP4BA $CP4BA_CSV_VERSION"
            exit 1
        elif [[ "$cp4a_operator_csv_version" == "22.2."* ]]; then
            requiredver="22.2.6"
            if [ ! "$(printf '%s\n' "$requiredver" "$cp4a_operator_csv_version" | sort -V | head -n1)" = "$requiredver" ]; then
                info "Found IBM Cloud Pak for Business Automation Operator is \"$cp4a_operator_csv_version\" version."
                fail "Please upgrade to CP4BA v22.0.2-IF006 or later iFix first before you can upgrade to CP4BA $CP4BA_CSV_VERSION"
                exit 1
            else
                info "Found IBM Cloud Pak for Business Automation Operator is \"$cp4a_operator_csv_version\" version."
                break
            fi
        elif [[ "$cp4a_operator_csv_version" == "23.2."* ]]; then
            requiredver="23.2.3"
            if [ ! "$(printf '%s\n' "$requiredver" "$cp4a_operator_csv_version" | sort -V | head -n1)" = "$requiredver" ]; then
                info "Found IBM Cloud Pak for Business Automation Operator is \"$cp4a_operator_csv_version\" version."
                fail "Please upgrade to CP4BA v23.0.2-IF003 or later iFix first before you can upgrade to CP4BA $CP4BA_CSV_VERSION"
                exit 1
            else
                info "Found IBM Cloud Pak for Business Automation Operator is \"$cp4a_operator_csv_version\" version."
                break
            fi
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
                fail "Please upgrade to CP4BA 22.0.2-IF002 or later iFix first before you can upgrade to CP4BA $CP4BA_CSV_VERSION"
                exit 1
            else
                info "Found IBM CP4BA FileNet Content Manager Operator is \"$cp4a_content_operator_csv_version\" version."
                break
            fi
        elif [[ "$cp4a_content_operator_csv_version" == "23.1."* ]]; then
            fail "Please upgrade to CP4BA 23.0.2 or later iFix first before you can upgrade to CP4BA $CP4BA_CSV_VERSION"
            exit 1
        elif [[ "$cp4a_content_operator_csv_version" == "22.1."* ]]; then
            fail "Please upgrade to CP4BA 22.0.2 or later iFix first before you can upgrade to CP4BA $CP4BA_CSV_VERSION"
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
                echo -e "\x1B[1mPlease check the status of Pod by issue cmd:\x1B[0m"
                echo "oc describe pod $(oc get pod -n $project_name|grep ibm-common-service-operator|awk '{print $1}') -n $project_name"
                printf "\n"
                echo -e "\x1B[1mPlease check the status of ReplicaSet by issue cmd:\x1B[0m"
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
                echo -e "\x1B[1mPlease check the status of Pod by issue cmd:\x1B[0m"
                echo "oc describe pod $(oc get pod -n $project_name|grep ibm-cp4a-operator|awk '{print $1}') -n $project_name"
                printf "\n"
                echo -e "\x1B[1mPlease check the status of ReplicaSet by issue cmd:\x1B[0m"
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
                echo -e "\x1B[1mPlease check the status of Pod by issue cmd:\x1B[0m"
                echo "oc describe pod $(oc get pod -n $project_name|grep ibm-content-operator|awk '{print $1}') -n $project_name"
                printf "\n"
                echo -e "\x1B[1mPlease check the status of ReplicaSet by issue cmd:\x1B[0m"
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
            echo -e "\x1B[1mPlease check the status of Pod by issue cmd:\x1B[0m"
            echo "oc describe pod $(oc get pod -n $project_name|grep icp4a-foundation-operator|awk '{print $1}') -n $project_name"
            printf "\n"
            echo -e "\x1B[1mPlease check the status of ReplicaSet by issue cmd:\x1B[0m"
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
            echo -e "\x1B[1mPlease check the status of Pod by issue cmd:\x1B[0m"
            echo "oc describe pod $(oc get pod -n $project_name|grep ibm-ads-operator|awk '{print $1}') -n $project_name"
            printf "\n"
            echo -e "\x1B[1mPlease check the status of ReplicaSet by issue cmd:\x1B[0m"
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
                echo -e "\x1B[1mPlease check the status of Pod by issue cmd:\x1B[0m"
                echo "oc describe pod $(oc get pod -n $project_name|grep ibm-odm-operator|awk '{print $1}') -n $project_name"
                printf "\n"
                echo -e "\x1B[1mPlease check the status of ReplicaSet by issue cmd:\x1B[0m"
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
                    echo -e "\x1B[1mPlease check the status of Pod by issue cmd:\x1B[0m"
                    echo "oc describe pod $(oc get pod -n $project_name|grep ibm-dpe-operator|awk '{print $1}') -n $project_name"
                    printf "\n"
                    echo -e "\x1B[1mPlease check the status of ReplicaSet by issue cmd:\x1B[0m"
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
            echo -e "\x1B[1mPlease check the status of Pod by issue cmd:\x1B[0m"
            echo "oc describe pod $(oc get pod -n $project_name|grep ibm-cp4a-wfps-operator|awk '{print $1}') -n $project_name"
            printf "\n"
            echo -e "\x1B[1mPlease check the status of ReplicaSet by issue cmd:\x1B[0m"
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
                echo -e "\x1B[1mPlease check the status of Pod by issue cmd:\x1B[0m"
                echo "oc describe pod $(oc get pod -n $project_name|grep ibm-insights-engine-operator|awk '{print $1}') -n $project_name"
                printf "\n"
                echo -e "\x1B[1mPlease check the status of ReplicaSet by issue cmd:\x1B[0m"
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
            echo -e "\x1B[1mPlease check the status of Pod by issue cmd:\x1B[0m"
            echo "oc describe pod $(oc get pod -n $project_name|grep ibm-pfs-operator|awk '{print $1}') -n $project_name"
            printf "\n"
            echo -e "\x1B[1mPlease check the status of ReplicaSet by issue cmd:\x1B[0m"
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
            echo -e "\x1B[1mPlease check the status of Pod by issue cmd:\x1B[0m"
            echo "oc describe pod $(oc get pod -n $project_name|grep ibm-workflow-operator|awk '{print $1}') -n $project_name"
            printf "\n"
            echo -e "\x1B[1mPlease check the status of ReplicaSet by issue cmd:\x1B[0m"
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

    UPGRADE_DEPLOYMENT_ICP4ACLUSTER_CR_BAK=${CUR_DIR}/cp4ba-upgrade/project/$TARGET_PROJECT_NAME/custom_resource/backup/icp4acluster_cr_backup.yaml
    UPGRADE_DEPLOYMENT_CONTENT_CR_BAK=${CUR_DIR}/cp4ba-upgrade/project/$TARGET_PROJECT_NAME/custom_resource/backup/content_cr_backup.yaml

    cp4ba_cr_name=$(kubectl get icp4acluster -n $project_name --no-headers --ignore-not-found | awk '{print $1}')
    if [ ! -z "$cp4ba_cr_name" ]; then
        cp4ba_cr_metaname=$(kubectl get icp4acluster $cp4ba_cr_name -n $project_name --no-headers --ignore-not-found -o yaml | ${YQ_CMD} r - metadata.name)
        kubectl get icp4acluster $cp4ba_cr_name -n ${project_name} --no-headers --ignore-not-found -o yaml > ${UPGRADE_STATUS_CP4BA_FILE}
    fi

    content_cr_name=$(kubectl get content -n $project_name --no-headers --ignore-not-found | awk '{print $1}')
    if [ ! -z "$content_cr_name" ]; then
        content_cr_metaname=$(kubectl get content $content_cr_name -n $project_name --no-headers --ignore-not-found -o yaml | ${YQ_CMD} r - metadata.name)
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
            owner_ref=$(kubectl get content $content_cr_name -n $project_name --no-headers --ignore-not-found -o yaml | ${YQ_CMD} r - metadata.ownerReferences.[0].kind)
            #################### FNCM #######################
            if [[ -z "${owner_ref}" ]]; then
                #this variable is being used to check what the version of CP4BA was used before upgrade and is used later in a check if some alert message is to be printed
                # initial_app_version=`cat $UPGRADE_DEPLOYMENT_CONTENT_CR_BAK | ${YQ_CMD} r - spec.appVersion`
                CONTENT_CR_EXIST="Yes"
                source ${CUR_DIR}/helper/upgrade/deployment_check/fncm_status.sh
                bai_flag=`cat $UPGRADE_STATUS_FILE | ${YQ_CMD} r - spec.content_optional_components.bai`
                if [[ ! -z "$bai_flag" ]]; then
                    bai_flag=$(echo "$bai_flag" | tr '[:upper:]' '[:lower:]')
                    if [[ "${bai_flag}" == "true" ]]; then
                        source ${CUR_DIR}/helper/upgrade/deployment_check/bai_status.sh
                    fi
                fi
                css_flag=`cat $UPGRADE_STATUS_FILE | ${YQ_CMD} r - spec.content_optional_components.css`
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
                existing_pattern_list=`cat $UPGRADE_STATUS_FILE | ${YQ_CMD} r - spec.shared_configuration.sc_deployment_patterns`
                existing_opt_component_list=`cat $UPGRADE_STATUS_FILE | ${YQ_CMD} r - spec.shared_configuration.sc_optional_components`

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
            AE_ENGINE_DEPLOYMENT=`cat $UPGRADE_STATUS_FILE | ${YQ_CMD} r - spec.application_engine_configuration`
            cr_metaname=`cat $UPGRADE_STATUS_FILE | ${YQ_CMD} r - metadata.name`
            if [[ ! -z "$AE_ENGINE_DEPLOYMENT" ]]; then
                item=0
                while true; do
                    ae_config_name=`cat $UPGRADE_STATUS_FILE | ${YQ_CMD} r - spec.application_engine_configuration.[${item}].name`
                    if [[ -z "$ae_config_name" ]]; then
                        break
                    else
                        source ${CUR_DIR}/helper/upgrade/deployment_check/baa_status.sh
                        ((item++))
                    fi
                done
            fi
            #################### BAStudio #######################
            BASTUDIO_DEPLOYMENT=`cat $UPGRADE_STATUS_FILE | ${YQ_CMD} r - spec.bastudio_configuration.admin_user`
            if [[ ! -z "$BASTUDIO_DEPLOYMENT" ]]; then
                source ${CUR_DIR}/helper/upgrade/deployment_check/bastudio_status.sh
            fi
            #################### BAI #######################
            if [[ " ${EXISTING_OPT_COMPONENT_ARR[@]} " =~ "bai" ]]; then
                source ${CUR_DIR}/helper/upgrade/deployment_check/bai_status.sh
            fi

            #################### BAML #######################
            BAML_DEPLOYMENT=`cat $UPGRADE_STATUS_FILE | ${YQ_CMD} r - spec.baml_configuration`
            if [[ ! -z "$BAML_DEPLOYMENT" ]]; then
                source ${CUR_DIR}/helper/upgrade/deployment_check/baml_status.sh
            fi

            #################### BAW runtime Multiple instance #######################
            BAW_DEPLOYMENT=`cat $UPGRADE_STATUS_FILE | ${YQ_CMD} r - spec.baw_configuration`
            cr_metaname=`cat $UPGRADE_STATUS_FILE | ${YQ_CMD} r - metadata.name`
            if [[ ! -z "$BAW_DEPLOYMENT" ]]; then
                item=0
                while true; do
                    baw_instance_name=`cat $UPGRADE_STATUS_FILE | ${YQ_CMD} r - spec.baw_configuration.[${item}].name`
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
            cr_metaname=$(kubectl get $cr_type ${item} -n $project_name --no-headers --ignore-not-found -o yaml | ${YQ_CMD} r - metadata.name)
            kubectl get $cr_type ${item} -n $project_name --no-headers --ignore-not-found -o yaml > ${UPGRADE_STATUS_FILE}
            #################### WfPS #######################
            source ${CUR_DIR}/helper/upgrade/deployment_check/wfps_status.sh
        done

    fi

    exist_pfs_cr_array=($(kubectl get ProcessFederationServer -n $project_name --no-headers --ignore-not-found | awk '{print $1}'))
    if [ ! -z $exist_pfs_cr_array ]; then
        for item in "${exist_wfps_cr_array[@]}"
        do
            cr_type="ProcessFederationServer"
            cr_metaname=$(kubectl get $cr_type ${item} -n $project_name --no-headers --ignore-not-found -o yaml | ${YQ_CMD} r - metadata.name)
            kubectl get $cr_type ${item} -n $project_name --no-headers --ignore-not-found -o yaml > ${UPGRADE_STATUS_FILE}
            #################### WfPS #######################
            source ${CUR_DIR}/helper/upgrade/deployment_check/pfs_status.sh
        done

    fi

}

function show_cp4ba_upgrade_status() {
    printf '%s %s\n' "$(date)" "[refresh interval: 30s]"
    echo -en "[Press Ctrl+C to exit] \t\t"
    check_cp4ba_deployment_status "${TARGET_PROJECT_NAME}"
    printf "\n"
    step_num=1
    echo "${YELLOW_TEXT}[NEXT ACTION]${RESET_TEXT}:"
    echo "${YELLOW_TEXT}  * After the status of upgrade for CP4BA components showing as ${RESET_TEXT}${GREEN_TEXT}\"Done\"${RESET_TEXT}${YELLOW_TEXT}, and then you need to execute follow steps${RESET_TEXT}:"
    if [[ $CONTENT_CR_EXIST == "Yes" || (" ${EXISTING_PATTERN_ARR[@]} " =~ "content") || ((" ${EXISTING_PATTERN_ARR[@]} " =~ "workflow") && (! " ${EXISTING_PATTERN_ARR[@]} " =~ "workflow-process-service")) || (" ${EXISTING_PATTERN_ARR[@]} " =~ "document_processing") || (" ${EXISTING_OPT_COMPONENT_ARR[@]} " =~ "baw_authoring") || (" ${EXISTING_OPT_COMPONENT_ARR[@]} " =~ "ae_data_persistence") ]]; then
        echo -e "  - STEP ${step_num} ${RED_TEXT}(Required)${RESET_TEXT}: Run ${GREEN_TEXT}\"./cp4a-pre-upgrade-and-post-upgrade-optional.sh post-upgrade\"${RESET_TEXT} ${YELLOW_TEXT}(NOTES: AFTER UPGRADING IBM CLOUD PAK FOR BUSINESS AUTOMATION (CP4BA) DEPLOYMENT SUCCESSFULLY, YOU NEED TO RUN \"./cp4a-pre-upgrade-and-post-upgrade-optional.sh post-upgrade\", AND THEN CLEAN BROWSER COOKIE BEFORE LOGIN.${RESET_TEXT}"
        echo -e "    ${YELLOW_TEXT}[ATTENTION]${RESET_TEXT}: ${RED_TEXT}DO NOT need to run it when upgrade CP4BA from 23.0.2.X to 24.0.0 (migration IBM Cloud Pak foundational services from Cluster-scoped -> Cluster-scoped or Namespace-scoped -> Namespace-scoped).${RESET_TEXT}"
        echo -e "    ${YELLOW_TEXT}[NOTES]${RESET_TEXT}: After running ${GREEN_TEXT}\"./cp4a-pre-upgrade-and-post-upgrade-optional.sh post-upgrade\"${RESET_TEXT}, you can access the Administration Console for Content Platform Engine after next reconcile finishing for new custom resource."

        printf "\n"
        step_num=$((step_num + 1))
    fi
        # echo "${YELLOW_TEXT}[ATTENTION] ${RESET_TEXT}${RED_TEXT}(REQUIRED)${RESET_TEXT}:"
    if [[ $CONTENT_CR_EXIST == "Yes" || (" ${EXISTING_PATTERN_ARR[@]} " =~ "content") || ((" ${EXISTING_PATTERN_ARR[@]} " =~ "workflow") && (! " ${EXISTING_PATTERN_ARR[@]} " =~ "workflow-process-service")) || (" ${EXISTING_PATTERN_ARR[@]} " =~ "document_processing") || (" ${EXISTING_OPT_COMPONENT_ARR[@]} " =~ "baw_authoring") || (" ${EXISTING_OPT_COMPONENT_ARR[@]} " =~ "ae_data_persistence") ]]; then
        echo "  - STEP ${step_num} ${RED_TEXT}(Required)${RESET_TEXT}: ${YELLOW_TEXT}After completion of upgrade of IBM Cloud Pak for Business Automation deployment, enable the Content Event Emitter if it is configured on an object store for Content Platform Engine.${RESET_TEXT}"
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
    echo "${YELLOW_TEXT}[ATTENTION]: ${RESET_TEXT}${YELLOW_TEXT}PLEASE DON'T SET ${RESET_TEXT}${RED_TEXT}\"shared_configuration.sc_egress_configuration.sc_restricted_internet_access\"${RESET_TEXT}${YELLOW_TEXT} AS ${RESET_TEXT}${RED_TEXT}\"true\"${RESET_TEXT}${YELLOW_TEXT} UNTIL AFTER YOU'VE COMPLETED THE CP4BA UPGRADE TO $CP4BA_RELEASE_BASE.${RESET_TEXT} ${GREEN_TEXT}(UNLESS YOU ALREADY HAD THIS SET TO \"true\" IN THE CP4BA 23.0.2.X)${RESET_TEXT}"
}
