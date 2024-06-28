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

# operator list
operatorlist=("ibm-common-service-operator"
            "ibm-cert-manager-operator"
            "ibm-mongodb-operator"
            "ibm-iam-operator"
            "ibm-monitoring-exporters-operator"
            "ibm-monitoring-prometheusext-operator"
            "ibm-monitoring-grafana-operator"
            "ibm-healthcheck-operator"
            "ibm-management-ingress-operator"
            "ibm-licensing-operator"
            "ibm-metering-operator"
            "ibm-commonui-operator"
            "ibm-elastic-stack-operator"
            "ibm-ingress-nginx-operator"
            "ibm-auditlogging-operator"
            "ibm-platform-api-operator"
            "ibm-namespace-scope-operator"
            "ibm-events-operator"
            )

# ---------- Command functions ----------

function main() {
    title "Rollback Common Service Operators to EUS channel."
    msg "-----------------------------------------------------------------------"

    if [[ $# -eq 0 ]]; then
        CS_NAMESPACE="ibm-common-services"
        msg "Rollback Commmon Service Operators in default namespace ibm-common-services."
    else
        CS_NAMESPACE="$1"
        msg "Rollback Commmon Service Operators in namespace $1."
    fi
    check_preqreqs $CS_NAMESPACE
    switch_to_eus $CS_NAMESPACE
    success "Successfully cleaned up CD version of foundational services, please manually install EUS version of foundational services."
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
    local namespace="$1"

    if [[ -z "$(oc get namespace ${namespace} --ignore-not-found)" ]]; then
    error "Namespace ${namespace} for Common Service Operators is not found."
    fi

}

function switch_to_eus() {
    local namespace="$1"

    STEP=$((STEP + 1 ))

    title "[${STEP}] Removing the cd version of Common Service Operators..."
    msg "-----------------------------------------------------------------------"

    msg "Deleteing licensing Bindinfo"    
    oc -n $namespace delete operandbindinfo ibm-licensing-bindinfo --ignore-not-found
    msg ""

    delete_operator "operand-deployment-lifecycle-manager-app" $namespace
    
    msg "Delete default OperandRegistry and OperandConfig CRs..."
    oc -n $namespace delete operandregistry common-service --ignore-not-found
    oc -n $namespace delete operandconfig common-service --ignore-not-found
    msg ""

    oc delete certmanager default --ignore-not-found
    msg ""
    
    for sub in ${operatorlist[@]}; do
        delete_operator $sub $namespace
    done

    while read -r ns cssub; do
        delete_operator $cssub $ns
    done < <(oc get subscription.operators.coreos.com --all-namespaces --ignore-not-found | grep ibm-common-service-operator | awk '{print $1" "$2}')

    success "Remove all Common Service Operators successfully."
    msg ""

    STEP=$((STEP + 1 ))
    title "[${STEP}] Cleaning up additional resources..."
    msg "-----------------------------------------------------------------------"
    in_step=1
    msg "[${in_step}] Deleting RBAC resources of foundational services"
    delete_rbac_resource $namespace

    in_step=$((in_step + 1))
    msg "[${in_step}] Deleting iam-status configMap in kube-public namespace" 
    oc delete configmap ibm-common-services-status -n kube-public --ignore-not-found

    in_step=$((in_step + 1))
    msg "[${in_step}] Deleting cert-manager webhooks and apiservice" 
    oc delete ValidatingWebhookConfiguration cert-manager-webhook --ignore-not-found
    oc delete MutatingWebhookConfiguration cert-manager-webhook --ignore-not-found
    oc delete apiservice v1beta1.webhook.certmanager.k8s.io --ignore-not-found

    in_step=$((in_step + 1))
    msg "[${in_step}] Deleting metering apiservice" 
    oc delete apiservice v1.metering.ibm.com --ignore-not-found
    
    in_step=$((in_step + 1))
    msg "[${in_step}] Deleting LicenseServiceReporter instance"
    oc -n $namespace delete ibmlicenseservicereporters instance --ignore-not-found
}

function delete_operator() {
    sub=$1
    ns=$2
    msg "Deleting ${sub} in namespace ${ns}..."
    msg "-----------------------------------------------------------------------"
    csv=$(oc get subscription.operators.coreos.com ${sub} -n ${ns} -o=jsonpath='{.status.installedCSV}' --ignore-not-found)
    in_step=1
    msg "[${in_step}] Removing the subscription of ${sub} in namespace ${ns} ..."
    oc delete sub ${sub} -n ${ns} --ignore-not-found
    in_step=$((in_step + 1))
    msg "[${in_step}] Removing the csv of ${sub} in namespace ${ns} ..."
    [[ "X${csv}" != "X" ]] && oc delete csv ${csv}  -n ${ns} --ignore-not-found
    msg ""

    success "Remove $sub successfully."
    msg ""
}

function delete_rbac_resource() {
  oc delete ClusterRoleBinding ibm-common-service-webhook secretshare-$1 --ignore-not-found
  oc delete ClusterRole ibm-common-service-webhook secretshare --ignore-not-found
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
