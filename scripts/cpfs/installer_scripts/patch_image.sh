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
STEP=0

# script base directory
BASE_DIR=$(dirname "$0")

# ---------- Command functions ----------

function main() {
    title "Patch Common Service Operator and ODLM images"
    msg "-----------------------------------------------------------------------"

    CS_IMAGE=""
    ODLM_IMAGE=""
    while [ "$#" -gt "0" ]
    do
        case "$1" in
        "-h"|"--help")
            usage
            exit 0
            ;;
        "-cs")
            CS_IMAGE=$2
            shift
            ;;
        "-odlm")
            ODLM_IMAGE=$2
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
    check_preqreqs
    patch_new_images
}

function usage() {
	local script="${0##*/}"

	while read -r ; do echo "${REPLY}" ; done <<-EOF
	Usage: ${script} [OPTION]...
	Patch common services operator and ODLM
	Options:
	Mandatory arguments to long options are mandatory for short options too.
	  -h, --help                     display this help and exit
	  -cs                            specify the patched image of ibm-common-service-operator
	  -odlm                          specify the patched image of operand-deployment-lifecycle-manager
	EOF
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

function patch_new_images {
    STEP=$((STEP + 1 ))

    title "[${STEP}] Patching CSV of ibm-common-service-operator ..."
    msg "-----------------------------------------------------------------------"

    if [ "${CS_IMAGE}" != "" ]; then
        while read -r ns cscsv; do

            msg "Updating csv ${cscsv} in namespace ${ns}..."
            msg "-----------------------------------------------------------------------"
            
            in_step=1
            msg "[${in_step}] Updating the image ..."

            template='[{"op": "replace", "path":"/spec/install/spec/deployments/0/spec/template/spec/containers/0/image", "value":"%s"}]'
            json_string=$(printf "$template" "${CS_IMAGE}")
            oc patch csv ${cscsv} -n ${ns} --type="json" -p "${json_string}" 2> /dev/null
            msg ""
        done < <(oc get csv --all-namespaces | grep ibm-common-service-operator | awk '{print $1" "$2}')
    
        success "Updated csv of ibm-common-service-operator successfully."
        msg ""
    fi

    if [ "${ODLM_IMAGE}" != "" ]; then
        while read -r ns odlmcsv; do

            msg "Updating csv ${odlmcsv} in namespace ${ns}..."
            msg "-----------------------------------------------------------------------"
            
            in_step=1
            msg "[${in_step}] Updating the image ..."

            template='[{"op": "replace", "path":"/spec/install/spec/deployments/0/spec/template/spec/containers/0/image", "value":"%s"}]'
            json_string=$(printf "$template" "${ODLM_IMAGE}")
            oc patch csv ${odlmcsv} -n ${ns} --type="json" -p "${json_string}" 2> /dev/null

            msg ""
        done < <(oc get csv --all-namespaces | grep operand-deployment-lifecycle-manager | awk '{print $1" "$2}')
    
        success "Updated csv of operand-deployment-lifecycle-manager successfully."
        msg ""
    fi
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

