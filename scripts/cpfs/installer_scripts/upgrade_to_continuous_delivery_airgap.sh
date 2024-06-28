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
    title "Upgrade Common Service Operator to continous delivery channel."
    msg "-----------------------------------------------------------------------"

    check_preqreqs
    switch_to_continous_delivery
    check_switch_complete
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

function deprecated_operator() {
    case $1 in
        "ibm-metering-operator") return 0;;
        "ibm-monitoring-exporters-operator") return 0;;
        "ibm-monitoring-prometheusext-operator") return 0;;
        *) return 1;;
    esac
}

function switch_to_continous_delivery() {
    STEP=$((STEP + 1 ))

    title "[${STEP}] Switching to Continous Delivery Version (switching into v3 channel)..."
    msg "-----------------------------------------------------------------------"

    # msg "Updating OperandRegistry common-service in namespace ibm-common-services..."
    # msg "-----------------------------------------------------------------------"
    # oc -n ibm-common-services get operandregistry common-service -o yaml | sed 's/stable-v1/v3/g' | oc -n ibm-common-services apply -f -

    while read -r ns cssub; do

        msg "Updating subscription ${cssub} in namespace ${ns}..."
        msg "-----------------------------------------------------------------------"
        
        in_step=1
        msg "[${in_step}] Removing the startingCSV ..."
        oc patch sub ${cssub} -n ${ns} --type="json" -p '[{"op": "remove", "path":"/spec/startingCSV"}]' 2> /dev/null

        in_step=$((in_step + 1))
        msg "[${in_step}] Switching channel from stable-v1 to v3 ..."
        oc patch sub ${cssub} -n ${ns} --type="json" -p '[{"op": "replace", "path":"/spec/channel", "value":"v3"}]' 2> /dev/null

        msg ""
    done < <(oc get subscription.operators.coreos.com --all-namespaces | grep ibm-common-service-operator | awk '{print $1" "$2}')

    success "Updated all ibm-common-service-operator subscriptions successfully."
    msg ""

    delete_operator "operand-deployment-lifecycle-manager-app ibm-namespace-scope-operator-restricted ibm-namespace-scope-operator ibm-cert-manager-operator" "ibm-common-services"

    while read -r sub; do
        if [[ ${sub} == "NAME" ]]; then
            continue
        fi

        if deprecated_operator ${sub}; then
            msg "Skipped subscription ${sub} in namespace ibm-common-services..."
            msg "-----------------------------------------------------------------------"
            continue
        fi

        msg "Updating subscription ${sub} in namespace ibm-common-services..."
        msg "-----------------------------------------------------------------------"
        
        in_step=1
        msg "[${in_step}] Removing the startingCSV ..."
        oc patch sub ${sub} -n ibm-common-services --type="json" -p '[{"op": "remove", "path":"/spec/startingCSV"}]' 2> /dev/null

        in_step=$((in_step + 1))
        msg "[${in_step}] Switching channel from stable-v1 to v3 ..."
        oc patch sub ${sub} -n ibm-common-services --type="json" -p '[{"op": "replace", "path":"/spec/channel", "value":"v3"}]' 2> /dev/null

        msg ""
    done < <(oc get subscription.operators.coreos.com -n ibm-common-services | awk '{print $1}')


    msg "Creating namespace scope config in namespace ibm-common-services..."
    msg "-----------------------------------------------------------------------"
    cat <<EOF | kubectl apply -f -
apiVersion: v1
kind: ConfigMap
metadata:
  name: namespace-scope
  namespace: ibm-common-services
data:
  namespaces: ibm-common-services
EOF
    msg ""
    success "Created namespace scope config in namespace ibm-common-services."
}

function check_switch_complete() {
    STEP=$((STEP + 1 ))

    title "[${STEP}] Checking whether the channel switch is completed..."
    msg "-----------------------------------------------------------------------"

    while read -r sub; do
        if [[ ${sub} == "NAME" ]]; then
            continue
        fi

        if deprecated_operator ${sub}; then
            msg "Skipped subscription ${sub} in namespace ibm-common-services..."
            msg "-----------------------------------------------------------------------"
            continue
        fi

        msg "Checking subscription ${sub} in namespace ibm-common-services..."
        msg "-----------------------------------------------------------------------"
        
        channel=$(oc get subscription.operators.coreos.com ${sub} -n ibm-common-services -o jsonpath='{.spec.channel}')
        if [[ "$channel" != "v3" ]]; then
            error "the channel of subscription ${sub} in namespace ibm-common-services is not v3, please try to re-run the script"
        fi

    done < <(oc get subscription.operators.coreos.com -n ibm-common-services | awk '{print $1}')

    success "Updated all operator subscriptions in namespace ibm-common-services successfully."
}

function delete_operator() {
    subs=$1
    ns=$2
    for sub in ${subs}; do
        msg "Deleting ${sub} in namesapce ${ns}, it will be re-installed after the upgrade is successful ..."
        msg "-----------------------------------------------------------------------"
        csv=$(oc get subscription.operators.coreos.com ${sub} -n ${ns} -o=jsonpath='{.status.installedCSV}' --ignore-not-found)
        in_step=1
        msg "[${in_step}] Removing the subscription of ${sub} in namesapce ${ns} ..."
        oc delete sub ${sub} -n ${ns} --ignore-not-found
        in_step=$((in_step + 1))
        msg "[${in_step}] Removing the csv of ${sub} in namesapce ${ns} ..."
        [[ "X${csv}" != "X" ]] && oc delete csv ${csv}  -n ${ns} --ignore-not-found
        msg ""

        success "Remove $sub successfully."
        msg ""
    done
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

