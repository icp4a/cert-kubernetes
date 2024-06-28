#!/bin/bash
# set -x
###############################################################################
#
# Licensed Materials - Property of IBM
#
# (C) Copyright IBM Corp. 2021. All Rights Reserved.
#
# US Government Users Restricted Rights - Use, duplication or
# disclosure restricted by GSA ADP Schedule Contract with IBM Corp.
#
###############################################################################

PROGRAM_NAME=$(basename "$0")
SKIP_CONFIRM=0
VALIDATE_COUNTS="${VALIDATE_COUNTS:-10}"
VALIDATE_WAIT="${VALIDATE_WAIT:-20}"
VALIDATE_PASS=0

NAMESPACE=
CS_NS=
CS_CTRL_NS=

CS_CATALOG="opencloud-operators"
BTS_CATALOG="bts-operator"
POSTGRES_CATALOG="cloud-native-postgresql-catalog"
CS_CATALOG_LIST="${CS_CATALOG} ${BTS_CATALOG} ${POSTGRES_CATALOG}"
CP4BA_CATALOG="ibm-cp4a-operator-catalog"
IAF_CATALOG="ibm-cp-automation-foundation-catalog"
IAF_CORE_CATALOG="ibm-automation-foundation-core-catalog"
CP4BA_CATALOG_LIST="${CP4BA_CATALOG} ${IAF_CATALOG} ${IAF_CORE_CATALOG}"
CS_SUBS="operand-deployment-lifecycle-manager-app ibm-events-operator ibm-common-service-operator ibm-commonui-operator 
    ibm-iam-operator ibm-ingress-nginx-operator ibm-management-ingress-operator ibm-mongodb-operator 
    ibm-platform-api-operator ibm-zen-operator ibm-namespace-scope-operator"
CS_CTRL_SUBS="ibm-cert-manager-operator ibm-crossplane-operator-app ibm-crossplane-provider-kubernetes-operator-app 
    ibm-licensing-operator ibm-namespace-scope-operator"

###############################################################################
# Script usage info
###############################################################################
function usage() {
    cat << EOF

This script is to update the subscriptions to use pinned-catalog that are using 
IBM Operator Catalog.

Prerequisites:
   1. Have OC CLI installed and Logged in to your cluster.
   2. CatalogSources for pinned-catalog was applied to the cluster in openshift-marketplace.

Usage 1: When CS not installed as multi-namespace/dedicated (no configmap 'common-service-maps' in kube-public created)
    ./${PROGRAM_NAME} [-n NAMESPACE] [-s]
  -n    string      specify CP4BA namespace, 'openshift-operators' if all-namespace
  -s                skip confirmation
    
Usage 2: When multi-namespace/dedicated CS is installed, all 3 namespaces (CP4BA, CS, CS control) are required
    ./${PROGRAM_NAME} -n NAMESPACE -c CS_NAMESPACE -t CS_CONTROL_NAMESPACE [-s]
  -n    string      specify CP4BA namespace
  -c    string      specify CommonServices namespace 
  -t    string      specify CommonServices-Control namespace
  -s                skip confirmation

EOF
}

###############################################################################
# Command line interface
###############################################################################
function cli() {
    while getopts "h?sn:c:t:" opt; do
        case "$opt" in
        n)
            NAMESPACE=${OPTARG}
            ;;
        c)
            CS_NS=${OPTARG}
            ;;
        t)
            CS_CTRL_NS=${OPTARG}
            ;;
        s)
            SKIP_CONFIRM=1
            ;;
        h|\?)
            usage
            exit 0
            ;;
        :)  
            echo "Invalid option: -${OPTARG} requires an argument"
            usage
            exit 1
            ;;
        esac
    done
}

###############################################################################
# Script requirement checks
###############################################################################
function prereq_check() {
    if ! [ -x "$(command -v oc)" ]; then
        echo 'Error: oc cli is not installed.' >&2
        exit 1
    fi
    oc get pod >/dev/null 2>&1
    if [ $? -gt 0 ]; then
        echo -e "oc login required" >&2
        exit 1
    fi
    if oc get cm -n kube-public common-service-maps &> /dev/null; then 
        if [ -z "${NAMESPACE}" ]; then
            echo -e "Error: CP4BA namespace must be provided." >&2
            exit 1
        fi
        if [ -z "${CS_NS}" ]; then
            echo -e "Error: CS namespace must be provided." >&2
            exit 1
        fi
        if [ -z "${CS_CTRL_NS}" ]; then
            echo -e "Error: CS Control namespace must be provided." >&2
            exit 1
        fi
    elif [ -z "${NAMESPACE}" ]; then
        CP4BA_SUB=$(oc get sub -A | grep "ibm-cp4a-operator " | grep -v "wfps")
        CP4BA_SUB_COUNT=$(oc get sub -A | grep "ibm-cp4a-operator " | grep -v -c "wfps")
        if [ "${CP4BA_SUB_COUNT}" -le "0" ]; then
            echo -e "Error: CP4BA subscription not found in any namespace." >&2
            exit 1
        elif [ "${CP4BA_SUB_COUNT}" -eq "1" ]; then
            NAMESPACE=$(echo "${CP4BA_SUB}" | awk '{print $1}')
        else
            echo -e "Error: More than one project with CP4BA subscription found, please specify namespace using '-n'" >&2
            exit 1
        fi
    fi
    CP4BA_SUB_COUNT=$(oc get sub -n "${NAMESPACE}" | grep "ibm-cp4a-operator " | grep -v -c "wfps")
    if ! [[ ${NAMESPACE} =~ ^[0-9a-z][-0-9a-zA-Z]{2,62}$ ]]; then
        echo -e "Error: Invalid namespace input '${NAMESPACE}'." >&2
        exit 1
    elif [[ ${NAMESPACE} == "default" ]]; then
        echo -e "Error: CP4BA should not be deploy on default namespace '${NAMESPACE}'." >&2
        exit 1
    elif [[ ${NAMESPACE} == "openshift-"* ]] && [[ ${NAMESPACE} != "openshift-operators" ]]; then
        echo -e "Error: CP4BA should not be deploy on openshift namespace '${NAMESPACE}'." >&2
        exit 1
    elif [[ "${CP4BA_SUB_COUNT}" -eq "0" ]]; then
        echo -e "Error: CP4BA subscription not found in provided namespace: '${NAMESPACE}'." >&2
        exit 1
    fi
    if [ -z "$(oc get project "${NAMESPACE}" 2>/dev/null)" ]; then
        echo -e "Error: Project ${NAMESPACE} does not exist. Specify an existing project where CP4BA is installed." >&2
        exit 1
    fi
    echo -e "CP4BA operators namespace: ${NAMESPACE}"

    local opencloud_check
    for catalog in ${CS_CATALOG_LIST}; do
        if ! [ "$(oc get catalogsource "${catalog}" -n openshift-marketplace --ignore-not-found)" ]; then 
            echo -e "Error: check your catalogsource, \"${catalog}\" is missing."
            exit 1;
        fi
        opencloud_check=$(oc get catalogsource "${catalog}" -n openshift-marketplace -o yaml | grep -c 'bedrock_catalogsource_priority:')
        if [ "${opencloud_check}" -lt 1 ]; then
            echo -e "Error: CatalogSource \"${catalog}\" missing annotation \"bedrock_catalogsource_priority: '1'\""
            exit 1
        fi
    done

    for catalog in ${CP4BA_CATALOG_LIST}; do
        if ! [ "$(oc get catalogsource "${catalog}" -n openshift-marketplace --ignore-not-found)" ]; then 
            echo -e "Error: check your catalogsource, \"${catalog}\" is missing."
            exit 1;
        fi
    done
}

###############################################################################
# Get subscription name
# Arguments:
#   filter for grep command on getting sub
# Outputs:
#   name of subscription(s)
###############################################################################
function get_sub_name() {
    local sub_list
    local sub_match
    local sub_match_count
    sub_list=$(oc get sub --no-headers | awk '{print $1}')
    sub_match=$(echo "${sub_list}" | grep -E "$1")
    sub_match_count=$(echo "${sub_list}" | grep -E -c "$1")
    if [ "${sub_match_count}" -eq 1 ]; then
        echo "${sub_match}"
    elif [ "${sub_match_count}" -gt 1 ]; then
        sub_match=$(echo "${sub_match}" | tr '\n' ' ')
        echo "${sub_match}"
    else
        echo "SUB_DNE"
    fi
}

###############################################################################
# Patch the source of subscription
# Arguments:
#   name of subscription
#   source to patch
###############################################################################
function patch_sub() {
    local source
    if oc get sub "$1" --no-headers &> /dev/null ; then
        source=$(oc get sub "$1" --no-headers | awk '{print $3}')
        if [ "${source}" == "$2" ]; then return 0; fi
        while :; do
            oc patch sub "$1" --type=json -p '[{"op": "replace", "path": "/spec/source", "value": "'"$2"'"}]'
            sleep 1
            source=$(oc get sub "$1" --no-headers | awk '{print $3}') 
            if [ "${source}" == "$2" ]; then
                break
            fi
        done
    fi
}

###############################################################################
# Patch all subscription in CS namespace
###############################################################################
function patch_cs_sub() {
    oc project "${CS_NS}" >/dev/null
    # for subs uses opencloud-operators in CS namespace
    for sub in ${CS_SUBS}; do
        patch_sub "${sub}" "${CS_CATALOG}"
    done

    # for ibm-bts-operator sub in CS namespace
    BTS_SUB=$(get_sub_name "bts-operator")
    patch_sub "${BTS_SUB}" "${BTS_CATALOG}"
    
    # for cloud-native-postgresql sub in CS namespace
    POSTGRES_SUB=$(get_sub_name "cloud-native-postgresql")
    patch_sub "${POSTGRES_SUB}" "${POSTGRES_CATALOG}"
}

###############################################################################
# Patch all subscription in CS-control namespace
###############################################################################
function patch_cs_ctrl_sub() {
    oc project "${CS_CTRL_NS}" >/dev/null
    # for subs uses opencloud-operators in CS-control namespace
    for sub in ${CS_CTRL_SUBS}; do
        patch_sub "${sub}" "${CS_CATALOG}"
    done
}

###############################################################################
# Patch all subscription in cp4ba namespace
###############################################################################
function patch_ns_sub() {
    oc project "${NAMESPACE}" >/dev/null
    # for iaf subs in cp4ba namespace
    IAF_SUBS=$(get_sub_name "^ibm-automation-[^c]")
    for sub in ${IAF_SUBS}; do
        patch_sub "${sub}" "${IAF_CATALOG}"
    done
    
    # for iaf core sub in cp4ba namespace
    IAF_CORE_SUB=$(get_sub_name "ibm-automation-core")
    patch_sub "${IAF_CORE_SUB}" "${IAF_CORE_CATALOG}"

    # for ibm-common-service-operator sub in cp4ba namespace
    CS_SUB=$(get_sub_name "ibm-common-service-operator")
    patch_sub "${CS_SUB}" "${CS_CATALOG}"

    # for cp4a subs in cp4ba namespace
    CP4BA_SUBS=$(get_sub_name "ibm-cp4a-")
    for sub in ${CP4BA_SUBS}; do
        patch_sub "${sub}" "${CP4BA_CATALOG}"
    done
    
    # for ibm-content-operator sub in cp4ba namespace
    FNCM_SUB=$(get_sub_name "ibm-content-operator")
    patch_sub "${FNCM_SUB}" "${CP4BA_CATALOG}"
    
    # for ibm-pfs-operator sub in cp4ba namespace
    PFS_SUB=$(get_sub_name "ibm-pfs-operator")
    patch_sub "${PFS_SUB}" "${CP4BA_CATALOG}"
    
    # for icp4a-foundation-operator sub in cp4ba namespace
    ICP4A_SUB=$(get_sub_name "icp4a-foundation-operator")
    patch_sub "${ICP4A_SUB}" "${CP4BA_CATALOG}"
    
    # for ibm-ads-operator sub in cp4ba namespace
    ADS_SUB=$(get_sub_name "ibm-ads-operator")
    patch_sub "${ADS_SUB}" "${CP4BA_CATALOG}"
}

###############################################################################
# Check if any subscription still using ibm-operator-catalog, repatch if needed
###############################################################################
function validate_sub() {
    echo -e "\nValidating subscription in '$1' namespace..."
    x=$VALIDATE_COUNTS
    while :; do
        if [ "$x" -le 0 ]; then 
            echo -e "Failed to patch following subscriptions from 'ibm-operator-catalog' to pinned-catalogs!"
            echo -e "(Ignore this error if below operator subscriptions is not one of the CP4BA operators)"
            echo -e "---------------------------------------------------------------------------------------"
            oc get sub -n "$1" | grep -E 'ibm-operator-catalog |NAME'
            echo -e "---------------------------------------------------------------------------------------\n"
            VALIDATE_PASS=0
            break
        fi
        if [ "$(oc get sub -n "$1" --no-headers | awk '{print $3}' | grep -c 'ibm-operator-catalog')" -ge 1 ]; then
            if [ "$1" == "${CS_NS}" ]; then patch_cs_sub;
            elif [ "$1" == "${CS_CTRL_NS}" ]; then patch_cs_ctrl_sub;
            elif [ "$1" == "${NAMESPACE}" ]; then patch_ns_sub; fi 
            sleep 2
        else
            echo -e "Subscription validation completed for '$1' namespace."
            VALIDATE_PASS=1
            break
        fi
        x=$((x-1))
    done
}

### MAIN ###
cli "$@"
prereq_check
CS_NS="${CS_NS:-ibm-common-services}"
CS_CTRL_NS="${CS_CTRL_NS:-ibm-common-services}"

echo
echo "All prereq checks passed!"
echo

if [[ "${SKIP_CONFIRM}" -eq "0" ]]; then
    echo -e "This script will update subscription for 'IBM Cloud Pak for Business Autmation' operator and it's dependencies, 
        including 'IBM Automation Foundation' and 'IBM Cloud Pak foundational services'."
    echo -e "Use -s argument to skip this confirmation, -h for help."
    read -p "Press 'Y' to continue: " -n 1 -r
    echo
    if [[ ! ${REPLY} =~ ^[Yy]$ ]]; then
        echo "Exiting..."
        exit 0
    fi
    echo -e "OK. Continuing...."
    echo
fi

oc project "${CS_NS}" >/dev/null
echo -e "Recreating operandregistry common-service..."
oc delete opreg common-service -n "${CS_NS}" 
oc delete pod "$(oc get pod -n "${CS_NS}" | grep ibm-common-service-operator | awk '{print $1}')" -n "${CS_NS}"
sleep 3
while :; do
    if [ "$(oc get opreg -n "${CS_NS}" common-service --ignore-not-found)" ]; then
        break
    else
        echo "Waiting for operandregistry 'common-service' to be recreated..."
        sleep 10
    fi
done

echo -e "\nUpdating subscription in '${CS_NS}' (CS namespace)..."
patch_cs_sub

echo -e "\nUpdating subscription in '${CS_CTRL_NS}' (CS Control namespace)..."
patch_cs_ctrl_sub

echo -e "\nUpdating subscription in '${NAMESPACE}' (CP4BA namespace)..."
patch_ns_sub

echo -e "\nWait ${VALIDATE_WAIT} seconds before validating Subscriptions..."
sleep $((VALIDATE_WAIT))

validate_sub "${CS_NS}"
validate_sub "${CS_CTRL_NS}"
validate_sub "${NAMESPACE}"

if [ "${VALIDATE_PASS}" -eq 1 ]; then
    echo -e "\nDone! Subscriptions now using pinned-catalogsources!"
else
    echo -e "\nFailed!"
fi
