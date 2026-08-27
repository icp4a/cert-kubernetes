#!/bin/bash
#
# Copyright 2021 IBM Corporation
#
# Licensed under the Apache License, Version 2.0 (the "License");
# you may not use this file except in compliance with the License.
# You may obtain a copy of the License at
#
# http://www.apache.org/licenses/LICENSE-2.0
#
# Unless required by applicable law or agreed to in writing, software
# distributed under the License is distributed on an "AS IS" BASIS,
# WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
# See the License for the specific language governing permissions and
# limitations under the License.
#

# counter to keep track of installation steps
# set -x
STEP=0

# set flag for channel comparing, default value is 2
# 0: current channel is equal to upgrade; 1: current is less; 2: current is greater
CHANNEL_COMP=2

# script base directory
BASE_DIR=$(dirname "$0")

CS_LIST_CSNS=("operand-deployment-lifecycle-manager-app"
        "ibm-common-service-operator"
        "ibm-cert-manager-operator"
        "ibm-mongodb-operator"
        "ibm-iam-operator"
        "ibm-monitoring-grafana-operator"
        "ibm-healthcheck-operator"
        "ibm-management-ingress-operator"
        "ibm-licensing-operator"
        "ibm-commonui-operator"
        "ibm-ingress-nginx-operator"
        "ibm-auditlogging-operator"
        "ibm-platform-api-operator"
        "ibm-namespace-scope-operator"
        "ibm-namespace-scope-operator-restricted"
        "ibm-zen-operator"
        "ibm-zen-cpp-operator"
        "ibm-crossplane-operator-app"
        "ibm-crossplane-provider-ibm-cloud-operator-app"
        "ibm-crossplane-provider-kubernetes-operator-app")

CS_LIST_CONTROLNS=(
        "ibm-cert-manager-operator"
        "ibm-namespace-scope-operator"
        "ibm-namespace-scope-operator-restricted"
        "ibm-crossplane-operator-app"
        "ibm-crossplane-provider-ibm-cloud-operator-app"
        "ibm-crossplane-provider-kubernetes-operator-app")

# ---------- Command functions ----------
function usage() {
	local script="${0##*/}"

	while read -r ; do echo "${REPLY}" ; done <<-EOF
	Usage: ${script} [OPTION]...
	Upgrade Common Services

	Options:
	Mandatory arguments to long options are mandatory for short options too.
      -h, --help                    display this help and exit
      -a                            Upgrade all Common Service instances in the cluster. By default it only uprades the common service in ibm-common-services namespace
      -csNS                         specify the namespace where common service is installed. By default it is namespace ibm-common-services.
      -cloudpaksNS                  specify the namespace where cloud paks is installed. By default it would be same as csNS.
      -controlNS                    specify the namespace where singleton services are installed. By default it it would be same as csNS.
      -c                            specify the subscription channel where common services switch. By default it is channel v3
      -sub                          specify the subscription name if it is not ibm-common-service-operator
EOF
}

function main() {
    CS_NAMESPACE=${CS_NAMESPACE:-ibm-common-services}
    DESTINATION_CHANNEL=${DESTINATION_CHANNEL:-v3}
    ALL_NAMESPACE=${ALL_NAMESPACE:-false}
    
    while [ "$#" -gt "0" ]
    do
        case "$1" in
        "-h"|"--help")
            usage
            exit 0
            ;;
        "-csNS")
            CS_NAMESPACE=$2
            shift
            ;;
        "-cloudpaksNS")
            CLOUDPAKS_NAMESPACE=$2
            shift
            ;;
        "-controlNS")
            CONTROL_NAMESPACE=$2
            shift
            ;;
        "-sub")
            subName=$2
            shift
            ;;
        "-c")
            DESTINATION_CHANNEL=$2
            shift
            ;;
        "-a")
            ALL_NAMESPACE="true"
            ;;
        *)
            warning "invalid option -- \`$1\`"
            usage
            exit 1
            ;;
        esac
        shift
    done

    CLOUDPAKS_NAMESPACE=${CLOUDPAKS_NAMESPACE:-${CS_NAMESPACE}}
    CONTROL_NAMESPACE=${CONTROL_NAMESPACE:-${CS_NAMESPACE}}
    subName=${subName:-"ibm-common-service-operator"}

    if [[ "${ALL_NAMESPACE}" == "true" ]]; then
        title "Upgrade Commmon Service Operator in all namespaces."
    else
        title "Upgrade Common Service Operator to ${DESTINATION_CHANNEL} channel in ${CS_NAMESPACE} namespace."
    fi
    msg "-----------------------------------------------------------------------"
    
    check_preqreqs "${CS_NAMESPACE}" "${CLOUDPAKS_NAMESPACE}" "${CONTROL_NAMESPACE}"
    pre_zen "${CS_NAMESPACE}"
    zenopr_check "${CS_NAMESPACE}" "${subName}"
    zensvc_check "${CS_NAMESPACE}" "${CLOUDPAKS_NAMESPACE}" "${ALL_NAMESPACE}"
    deployment_check "${subName}" "${CS_NAMESPACE}" "${DESTINATION_CHANNEL}"
    switch_channel "${subName}" "${CS_NAMESPACE}" "${CLOUDPAKS_NAMESPACE}" "${CONTROL_NAMESPACE}" "${DESTINATION_CHANNEL}" "${ALL_NAMESPACE}"
    check_switch_complete "${CS_NAMESPACE}" "${CLOUDPAKS_NAMESPACE}" "${CONTROL_NAMESPACE}" "${DESTINATION_CHANNEL}" "${ALL_NAMESPACE}"
}

function check_preqreqs() {
    local csNS=$1
    local cloudpaksNS=$2
    local controlNS=$3

    msg ""
    title "[${STEP}] Checking prerequisites..."
    msg "-----------------------------------------------------------------------"

    # checking oc command
    if [[ -z "$(command -v oc 2> /dev/null)" ]]; then
        error "OpenShift Command Line tool oc is not available"
    else
        success "OpenShift Command Line tool oc is available."
    fi

    # checking oc command logged in
    user=$(oc whoami 2> /dev/null)
    if [ $? -ne 0 ]; then
        error "You must be logged into the OpenShift Cluster from the oc command line."
    else
        success "oc command logged in as ${user}"
    fi

    # checking namespace if it is specified
    if [[ -z "$(oc get namespace ${csNS})" ]]; then
        error "Namespace ${csNS} for Common Service Operator is not found."
    fi

    # checking namespace if it is specified
    if [[ -z "$(oc get namespace ${cloudpaksNS})" ]]; then
        error "Namespace ${cloudpaksNS} for Cloud Paks is not found."
    fi

    # checking namespace if it is specified
    if [[ -z "$(oc get namespace ${controlNS})" ]]; then
        error "Namespace ${controlNS} for singleton services is not found."
    fi
}

function pre_zen(){
    local csNS=$1

    STEP=$((STEP + 1 ))
    msg ""
    title "[${STEP}] Detecting Operator Condition of zen operator v1.4.2 in ${csNS} namespace..."
    msg "-----------------------------------------------------------------------"

    if oc get operatorcondition -n ${csNS} 2>/dev/null | grep ibm-zen-operator ; then
        list=$(oc get operatorcondition -o custom-columns=operatorcondition:.metadata.name --no-headers -n ${csNS} | grep ibm-zen-operator 2>/dev/null)
        for name in ${list};do
            if [ ! -z "${name}" ] && [[ "${name}" =~ ibm-zen-operator.v1.4.2 ]]; then
                oc delete operatorcondition ${name} -n ${csNS} || true
            fi
        done
    fi
}

function zenopr_check() {
    local csNS=$1
    local subName=$2

    currentChannel=$(oc get subscription.operators.coreos.com -n ${csNS} | grep ${subName} | awk '{print $4}')
    STEP=$((STEP + 1 ))
    msg ""
    title "[${STEP}] Waiting for IBM Zen Operator upgrading to latest version in the ${currentChannel} channel..."
    msg "-----------------------------------------------------------------------"

    # check if zen operator is installed or not
    sub=$(oc get subscription.operators.coreos.com ibm-zen-operator --ignore-not-found)
    if [[ "X${sub}" == "X" ]]; then
        msg "ibm-zen-operator in namespace ${csNS} not found, skipping..."
        return 0
    fi

    sleep 60
    while true; do
        # check if installedCSV is the same as currentCSV
        installedCSV=$(oc get subscription.operators.coreos.com ibm-zen-operator -n ${csNS} --ignore-not-found -o jsonpath={.status.installedCSV})
        currentCSV=$(oc get subscription.operators.coreos.com ibm-zen-operator -n ${csNS} --ignore-not-found -o jsonpath={.status.currentCSV})

        if [[ -z $installedCSV || -z $currentCSV ]]; then
            error "fail to get installed or current CSV, abort the upgrade procedure. Please check ibm-zen-operator subscription status."
        fi
        if [[ $installedCSV != $currentCSV ]]; then
            approval_mode=$(oc get subscription.operators.coreos.com ibm-zen-operator -n ${csNS} --ignore-not-found -o jsonpath={.spec.installPlanApproval})
            if [[ $approval_mode == "Manual" ]]; then
                error "ibm-zen-operator subscription is set to Manual Approval mode, please approve installPlan to upgrade Zen operator."
            fi
            warning "ibm-zen-operator subscription is set to Automatic Approval mode, waiting for the upgrade from ${installedCSV} to ${currentCSV}..."
            sleep 5
        else
            success "${installedCSV} is now the latest available version in ${currentChannel} channel."
            break
        fi
    done

    index=0
    while true; do
        # check Zen operator CSV status
        csv_status=$(oc get clusterserviceversion.operators.coreos.com ${currentCSV} -n ${csNS} -o jsonpath={.status.phase})
        if [[ $csv_status == "Succeeded" ]]; then
            success "${currentCSV} phase is ${csv_status}."
            break
        fi
        sleep 10
        # wait 10 mins
        index=$(( index + 1 ))
        if [[ $index -eq 60 ]]; then
            error "${currentCSV} phase is ${csv_status}, abort the upgrade procedure. Please check ${currentCSV} CSV status."
        fi
    done
}

function single_zensvc() {
    local ns=$1
    local cr=$2

    msg "Checking ZenService ${cr} status in ${ns}..."

    index=0
    while true; do
        zenProgress=$(oc get zenservice ${cr} -n ${ns} -ojsonpath={.status.Progress})
        zenMSG=$(oc get zenservice ${cr} -n ${ns} -ojsonpath={.status.ProgressMessage})
        zenStatus=$(oc get zenservice ${cr} -n ${ns} -ojsonpath={.status.zenStatus})
        if [[ "$zenStatus" == "Completed" ]]; then
            success "ZenService CR ${cr} progress is ${zenProgress}."
            success "ZenService CR ${cr} message: ${zenMSG}."
            success "ZenService CR ${cr} status is ${zenStatus}."
            msg "-----------------------------------------------------------------------"
            break
        fi

        msg "Waiting for ZenService CR ready..."
        sleep 20
        # wait an hour
        index=$(( index + 1 ))
        if [[ $index -eq 180 ]]; then
            warning "ZenService CR ${cr} progress is ${zenProgress}."
            warning "ZenService CR ${cr} message: ${zenMSG}."
            warning "ZenService CR ${cr} status is ${zenStatus}."
            error "Fail to upgrade ZenService ${cr}, time out and abort the upgrade procedure."
        fi
    done
}

function zensvc_check() {
    local csNS=$1
    local cloudpaksNS=$2
    local allNamespace=$3

    STEP=$((STEP + 1 ))
    msg ""
    title "[${STEP}] Checking ZenService in every namespace..."
    msg "-----------------------------------------------------------------------"

    if [[ "${allNamespace}" == "true" ]]; then
        while read -r ns zencr; do
            single_zensvc  "${ns}" "${zencr}" 
        done < <(oc get zenservice --all-namespaces --ignore-not-found --no-headers | awk '{print $1" "$2}')
    else
        if [[ "$cloudpaksNS" != "$csNS" ]]; then
            while read -r zencr; do
                single_zensvc  "${cloudpaksNS}" "${zencr}" 
            done < <(oc get zenservice -n ${cloudpaksNS} --ignore-not-found --no-headers | awk '{print $1}')  
        fi
        while read -r zencr; do
            single_zensvc  "${csNS}" "${zencr}" 
        done < <(oc get zenservice -n ${csNS} --ignore-not-found --no-headers | awk '{print $1}')       
    fi
    success "All ZenService CRs have been upgraded to latest version."
}

function switch_channel_operator() {
    local subName=$1
    local namespace=$2
    local channel=$3

    while read -r cssub; do
        msg "Updating subscription ${cssub} in namespace ${namespace}..."
        
        in_step=1
        msg "[${in_step}] Removing the startingCSV..."
        oc patch subscription.operators.coreos.com ${cssub} -n ${namespace} --type="json" -p '[{"op": "remove", "path":"/spec/startingCSV"}]' 2> /dev/null

        in_step=$((in_step + 1))
        msg "[${in_step}] Upgrading channel to ${channel}..."
        
        cat <<EOF | oc patch subscription.operators.coreos.com ${cssub} -n ${namespace} --type="json" -p '[{"op": "replace", "path":"/spec/channel", "value":"'"${channel}"'"}]' | 2> /dev/null
EOF

        msg ""
    done < <(oc get subscription.operators.coreos.com -n ${namespace} --ignore-not-found | grep ${subName} | awk '{print $1}')
}

# This function checks the current version of the installed bedrock instance automatically
# so that the user doesn't have to do so manually. If the current version on-cluster 
# is already higher than the desired one the user indicates, the script will indicate this
# to the user and abort the script since bedrock is already above the desired version.
function compare_channel() {
    local subName=$1
    local namespace=$2
    local channel=$3
    local cur_channel=$4
    
    # remove all chars before "v"
    trimmed_channel="$(echo $channel | awk -Fv '{print $NF}')"
    trimmed_cur_channel="$(echo $cur_channel | awk -Fv '{print $NF}')"

    msg "Comparing channels in ${namespace} namespace..."

    # compare channel before channel switching
    IFS='.' read -ra current_channel <<< "${trimmed_cur_channel}"
    IFS='.' read -ra upgrade_channel <<< "${trimmed_channel}"

    # fill empty fields in current channel version with zeros
    for ((i=${#current_channel[@]}; i<${#upgrade_channel[@]}; i++)); do
        current_channel[i]=0
    done

    for index in ${!current_channel[@]}; do

        # fill empty fields in upgrade channel version with zeros
        if [[ -z ${upgrade_channel[index]} ]]; then
            upgrade_channel[index]=0
        fi

        if [[ ${current_channel[index]} -gt ${upgrade_channel[index]} ]]; then
            CHANNEL_COMP=2
            error "current channel ${cur_channel} is greater than upgrade channel ${channel}, abort the upgrade procedure"
            
        elif [[ ${current_channel[index]} -lt ${upgrade_channel[index]} ]]; then
            CHANNEL_COMP=1
            success "current channel ${cur_channel} is less than upgrade channel ${channel}, ready for channel switch"
            return 0
        fi
    done
    CHANNEL_COMP=0
    success "current channel ${cur_channel} is equal to upgrade channel ${channel}, do not need channel switch"  
}

function deployment_check(){
    local subName=$1
    local csNS=$2
    local channel=$3

    STEP=$((STEP + 1 ))
    msg ""
    title "[${STEP}] Checking ${subName} deployment in ${csNS} namespace..."
    msg "-----------------------------------------------------------------------"

    # get current cs opertor channel version 
    csoperator_channel=$(oc get subscription.operators.coreos.com -n ${csNS} | grep ${subName} | awk '{print $4}')
    compare_channel "${subName}" "${csNS}" "${channel}" "${csoperator_channel}"
    
    if [[ $CHANNEL_COMP == 1 ]]; then
        msg "current channel version of ${subName} ${csoperator_channel} is less then upgrade channel version ${channel}"
        msg ""

        in_step=1
        # scale down cs operator to prevent reconciliation
        msg "[${in_step}] Scaling down ${subName} deployment in ${csNS} namespace to 0"
        oc scale deployment -n "${csNS}" "${subName}" --replicas=0

        # delete OperandRegistry
        in_step=$((in_step + 1))
        msg "[${in_step}] Deleting OperandRegistry common-service in ${csNS} namespace..."
        oc delete operandregistry common-service -n ${csNS} --ignore-not-found
        
    elif [[ $CHANNEL_COMP != 1 ]]; then
        msg "current channel version of ${subName} ${csoperator_channel} is not less than upgrade channel version ${channel}"
        msg ""

        # get installedCSV from subscription
        csv=$(oc get subscription.operators.coreos.com ${subName} -n ${csNS} -o=jsonpath='{.status.installedCSV}' --ignore-not-found)
        msg "existing installedCSV is ${csv}"

        # remove all chars before "v"
        trimmed_csv="$(echo $csv | awk -Fv '{print $NF}')"
        trimmed_channel="$(echo $channel | awk -Fv '{print $NF}')"

        if [[ "$trimmed_csv" == *"$trimmed_channel"* ]]; then
            in_step=1
            msg "installedCSV ${csv} matches upgrade channel version ${channel}"
            msg ""
            # scale up cs operator back to 1
            msg "[${in_step}] Scaling up ${subName} deployment in ${csNS} namespace to 1"
            oc scale deployment -n "${csNS}" "${subName}" --replicas=1
        fi
    fi
}

function switch_channel() {
    local subName=$1
    local csNS=$2
    local cloudpaksNS=$3
    local controlNS=$4
    local channel=$5
    local allNamespace=$6

    STEP=$((STEP + 1 ))
    msg ""
    title "[${STEP}] Comparing and switching given upgrade channel version ${channel} of ${subName} with current one..."
    msg "-----------------------------------------------------------------------"

    if [[ "${allNamespace}" == "true" ]]; then
        while read -r ns cur_channel; do
            compare_channel "${subname}" "${ns}" "${channel}" "${cur_channel}"

            # switch channel only happens when current channel is less than upgrade 
            if [[ $CHANNEL_COMP == 1 ]]; then
                msg ""
                msg "Switching channel into ${channel}..."
                switch_channel_operator "${subName}" "${ns}" "${channel}"
            fi 
        done < <(oc get subscription.operators.coreos.com --all-namespaces --ignore-not-found | grep ${subName}  | awk '{print $1" "$5}')
    else
        if [[ "$cloudpaksNS" != "$csNS" ]]; then
            while read -r cur_channel; do
                compare_channel "${subName}" "${cloudpaksNS}" "${channel}" "${cur_channel}"
                if [[ $CHANNEL_COMP == 1 ]]; then
                    msg ""
                    msg "Switching channel into ${channel}..."
                    switch_channel_operator "${subName}" "${cloudpaksNS}" "${channel}"
                fi
            done < <(oc get subscription.operators.coreos.com -n ${cloudpaksNS} --ignore-not-found | grep ${subName}  | awk '{print $4}')
            
        fi
        while read -r cur_channel; do
            compare_channel "${subname}" "${csNS}" "${channel}" "${cur_channel}"
            if [[ $CHANNEL_COMP == 1 ]]; then
                msg ""
                msg "Switching channel into ${channel}..."
                switch_channel_operator "${subName}" "${csNS}" "${channel}"
            fi
        done < <(oc get subscription.operators.coreos.com -n ${csNS} --ignore-not-found | grep ${subName}  | awk '{print $4}')
    fi
    success "Updated ${subName} subscriptions successfully."
    
    # switch channel for remaining CS components
    STEP=$((STEP + 1 ))
    msg ""
    title "[${STEP}] Switching channel version for remaining CS components in ${csNS} namespace..."
    msg "-----------------------------------------------------------------------"

    for sub_name in "${CS_LIST_CSNS[@]}"; do
        msg "Starting with ${sub_name}..."
        current=$(oc get subscription.operators.coreos.com -n ${csNS} --ignore-not-found | grep ${sub_name} | awk '{print $4}')
        if [[ ! -z "${current}" ]]; then 
            compare_channel "${sub_name}" "${csNS}" "${channel}" "${current}"
            if [[ $CHANNEL_COMP == 1 ]]; then
                msg ""
                msg "Switching channel into ${channel}..."
                switch_channel_operator "${sub_name}" "${csNS}" "${channel}"
            fi
        else
            msg "${sub_name} in namespace ${csNS} not found, skipping..."
            msg ""
        fi
    done
    for sub_name in "${CS_LIST_CONTROLNS[@]}"; do
        msg "Starting with ${sub_name}..."
        current_control=$(oc get subscription.operators.coreos.com -n ${controlNS} --ignore-not-found | grep ${sub_name} | awk '{print $4}')
        if [[ ! -z "${current_control}" ]]; then
            compare_channel "${sub_name}" "${controlNS}" "${channel}" "${current_control}"
            if [[ $CHANNEL_COMP == 1 ]]; then
                msg ""
                msg "Switching channel into ${channel}..."
                switch_channel_operator "${sub_name}" "${controlNS}" "${channel}"
            fi
        else
            msg "${sub_name} in namespace ${controlNS} not found, skipping..."
            msg ""
        fi
    done
}

function check_switch_complete() {
    local csNS=$1
    local cloudpaksNS=$2
    local controlNS=$3
    local destChannel=$4
    local allNamespace=$5

    STEP=$((STEP + 1 ))
    title "[${STEP}] Checking whether the channel switch is completed..."
    msg "-----------------------------------------------------------------------"

    for sub_name in "${CS_LIST_CSNS[@]}"; do
        channel=$(oc get subscription.operators.coreos.com ${sub_name} -n ${csNS} -o jsonpath='{.spec.channel}' --ignore-not-found)
        if [[ "X${channel}" != "X" ]] && [[ "$channel" != "${destChannel}" ]]; then
            error "the channel of subscription ${sub_name} in namespace ${csNS} is not ${destChannel}, please try to re-run the script"
        fi
    done

    for sub_name in "${CS_LIST_CONTROLNS[@]}"; do
        channel=$(oc get subscription.operators.coreos.com ${sub_name} -n ${controlNS} -o jsonpath='{.spec.channel}' --ignore-not-found)
        if [[ "X${channel}" != "X" ]] && [[ "$channel" != "${destChannel}" ]]; then
            error "the channel of subscription ${sub_name} in namespace ${controlNS} is not ${destChannel}, please try to re-run the script"
        fi
    done

    success "Updated all Common Service components' subscriptions successfully."
}

function msg() {
    printf '%b\n' "$1"
}

function success() {
    msg "\33[32m[✔] ${1}\33[0m"
}

function error() {
    msg "\33[31m[✘] ${1}\33[0m"
    exit 1
}

function title() {
    msg "\33[34m# ${1}\33[0m"
}

function info() {
    msg "[INFO] ${1}"
}

function warning() {
    msg "\33[33m[✗] ${1}\33[0m"
}

# --- Run ---

main $*
