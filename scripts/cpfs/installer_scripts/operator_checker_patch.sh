#!/bin/bash
#
# Copyright 2022 IBM Corporation
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
STEP=0

# script base directory
BASE_DIR=$(dirname "$0")

# ---------- Command functions ----------
function usage() {
	local script="${0##*/}"

	while read -r ; do echo "${REPLY}" ; done <<-EOF
	Usage: ${script} [OPTION]...
	Patch common services Operator Checker

	Options:
	Mandatory arguments to long options are mandatory for short options too.
	  -h, --help                     display this help and exit
	  --csns                         specify the namespace where common service operator is installed
	  --odlmns                       specify the namespace where operand deployment lifecycle manager(ODLM) is installed
	EOF
}

function main() {
    COMMON_SERVICES_NS=${COMMON_SERVICES_NS:-ibm-common-services}
    ODLM_NS=${ODLM_NS:-ibm-common-services}
    while [ "$#" -gt "0" ]
    do
        case "$1" in
        "-h"|"--help")
            usage
            exit 0
            ;;
        "--csns")
            COMMON_SERVICES_NS=$2
            shift
            ;;
        "--odlmns")
            ODLM_NS=$2
            shift
            ;;
        *)
            warning "invalid option -- \`$1\`"
            usage
            exit 1
            ;;
        esac
        shift
    done

    title "Upgrade Manual Approval Mode Common Service."
    msg "-----------------------------------------------------------------------"

    check_preqreqs 
    AllNamespaceMode=false
    if [[ ${COMMON_SERVICES_NS} == "openshift-operators" ]]; then
        AllNamespaceMode=true
    fi
    edit_cs_csv "${COMMON_SERVICES_NS}"
    wait_for_scasle_down "${COMMON_SERVICES_NS}" "ibm-common-service-operator"
    edit_odlm_sub "${ODLM_NS}" ${AllNamespaceMode}

}

function check_preqreqs() {
    title "[${STEP}] Checking prerequesites ..."
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
}

function edit_cs_csv() {
    STEP=$((STEP + 1 ))

    title "[${STEP}] Scale down common service operator..."
    msg "-----------------------------------------------------------------------"

    local namespace=$1
    while read -r cs_csv; do
        msg "Edit ${cs_csv} in namespace ${namespace} ..."
        msg "-----------------------------------------------------------------------"
        
        oc patch csv ${cs_csv} -n ${namespace} --type="json" -p '[{"op": "replace", "path":"/spec/install/spec/deployments/0/spec/replicas", "value": 0}]' 2> /dev/null

        msg ""
    done < <(oc get csv -n ${namespace} | grep ibm-common-service-operator | awk '{print $1}')
    success "Scale down ${cs_csv} in ${namespace} successfully."
}

function edit_odlm_sub() {
    STEP=$((STEP + 1 ))

    title "[${STEP}] Disable ODLM operator checker..."
    msg "-----------------------------------------------------------------------"

    local namespace=$1
    local allNamespaceMode=$2
    while read -r odlm_sub; do
        msg "Edit ${odlm_sub} in namespace ${namespace} ..."
        msg "-----------------------------------------------------------------------"
        
        oc patch subscription ${odlm_sub} -n ${namespace} --type="json" -p '[{"op": "replace", "path":"/spec/config/env/2/value", "value": "false"}]' 2> /dev/null
        if [[ ($? -ne 0) && ("${allNamespaceMode}" = true) ]]; then
            oc patch subscription ${odlm_sub} -n ${namespace} --type merge --patch '{"spec":{"config":{"env":[{"name": "OPERATORCHECKER_MODE", "value": "false"}]}}}' 2> /dev/null
        fi

        msg ""
    done < <(oc get subscription.operators.coreos.com -n ${namespace} | grep operand-deployment-lifecycle-manager-app | awk '{print $1}')
    success "Disable ${odlm_sub} operator checker in ${namespace} successfully."
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

function wait_for_scasle_down() {
    local namespace=$1
    local name=$2
    local condition="oc -n ${namespace} get deployment --no-headers --ignore-not-found | egrep '0/0' | grep ^${name}"
    local retries=30
    local sleep_time=10
    local total_time_mins=$(( sleep_time * retries / 60))
    local wait_message="Waiting for deployment ${name} in namespace ${namespace} to be scaled down ..."
    local success_message="Deployment ${name} in namespace ${namespace} is scaled down."
    local error_message="Timeout after ${total_time_mins} minutes waiting for deployment ${name} in namespace ${namespace} to be scaled down."
 
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

# --- Run ---

main $*

