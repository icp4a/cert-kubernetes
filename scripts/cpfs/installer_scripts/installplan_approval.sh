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

function main() {
    title "Upgrade Manual Approval Mode Common Service."
    msg "-----------------------------------------------------------------------"
    
    if [[ $# -eq 0 ]]; then
        CS_NAMESPACES="ibm-common-services"
        msg "Upgrade Commmon Service Operator in all namespaces."
    else
        CS_NAMESPACES=("$@")
    fi

    check_preqreqs "${CS_NAMESPACES[@]}"
    approve_install_plan "${CS_NAMESPACES[@]}"
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

    # checking namespace if it is specified
    local namespaces=("$@")

    if [[ "$namespaces" != "" ]]; then
        for ns in "${namespaces[@]}"
        do
            if [[ -z "$(oc get namespace ${ns} --ignore-not-found)" ]]; then
            error "Namespace ${ns} for Common Service Operator is not found."
            fi
        done
    fi

}

function approve_install_plan() {
    STEP=$((STEP + 1 ))

    title "[${STEP}] Approve InstallPlan for Common Services..."
    msg "-----------------------------------------------------------------------"

    local namespaces=("$@")
    for ns in "${namespaces[@]}"
    do
        while read -r install_plan approved; do
            if [[ ${approved} == "false" ]]; then
                msg "Approve InstallPlan ${install_plan} in namespace ${ns} ..."
                msg "-----------------------------------------------------------------------"
                
                oc patch installplan ${install_plan} -n ${ns} --type merge --patch '{"spec":{"approved":true}}' 2> /dev/null

                msg ""
            fi
        done < <(oc get ip -n ${ns} | grep false | awk '{print $1" "$4}')
        success "Approve all InstallPlan in ${ns} successfully."
    done
    
    info "Please wait a moment for all the common service pods are healthy and the cloudpak console works."
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

# --- Run ---

main $*

