#!/usr/bin/env bash

# Licensed Materials - Property of IBM
# Copyright IBM Corporation 2023. All Rights Reserved
# US Government Users Restricted Rights -
# Use, duplication or disclosure restricted by GSA ADP Schedule Contract with IBM Corp.
#
# This is an internal component, bundled with an official IBM product. 
# Please refer to that particular license for additional information. 

# ---------- Command arguments ----------

OC=oc
YQ=yq
CONTROL_NS=""
DEBUG=0
PREVIEW_MODE=0
SKIP_USER_VERIFY=0

# ---------- Command variables ----------

# script base directory
BASE_DIR=$(cd $(dirname "$0")/$(dirname "$(readlink $0)") && pwd -P)

# counter to keep track of installation steps
STEP=0

# ---------- Main functions ----------

. ${BASE_DIR}/utils.sh

function main() {
    parse_arguments "$@"
    pre_req
    deactivate_cp2_cert_manager
}

function parse_arguments() {
    script_name=`basename ${0}`
    echo "All arguments passed into the ${script_name}: $@"
    echo ""

    # process options
    while [[ "$@" != "" ]]; do
        case "$1" in
        --oc)
            shift
            OC=$1
            ;;
        --yq)
            shift
            YQ=$1
            ;;
        --control-namespace)
            shift
            CONTROL_NS=$1
            ;;
        -v | --debug)
            shift
            DEBUG=$1
            ;;
        -h | --help)
            print_usage
            exit 1
            ;;
        *) 
            echo "wildcard"
            ;;
        esac
        shift
    done
}

function print_usage() {
    script_name=`basename ${0}`
    echo "Usage: ${script_name} --control-namespace <cert-manager-namespace> [OPTIONS]..."
    echo ""
    echo "De-activate Certificate Management for IBM Cloud Pak 2.0 Cert Manager."
    echo "The --control-namespace must be provided."
    echo ""
    echo "Options:"
    echo "   --oc string                    File path to oc CLI. Default uses oc in your PATH"
    echo "   --yq string                    File path to yq CLI. Default uses yq in your PATH"
    echo "   --control-namespace string     Required. Namespace to de-activate Cloud Pak 2.0 Cert Manager services."
    echo "   -v, --debug integer            Verbosity of logs. Default is 0. Set to 1 for debug logs."
    echo "   -h, --help                     Print usage information"
    echo ""
}

function pre_req() {
    check_command "${OC}"
    check_command "${YQ}"
    check_yq_version

    # checking oc command logged in
    user=$(${OC} whoami 2> /dev/null)
    if [ $? -ne 0 ]; then
        error "You must be logged into the OpenShift Cluster from the oc command line"
    else
        success "oc command logged in as ${user}"
    fi

    if [ "$CONTROL_NS" == "" ]; then
        error "Must provide control namespace"
    fi
}

function deactivate_cp2_cert_manager() {
    title "De-activating IBM Cloud Pak 2.0 Cert Manager in ${CONTROL_NS}...\n"

    info "Configuring Common Services Cert Manager.."
    result=$(${OC} get configmap ibm-cpp-config -n ${CONTROL_NS} -o yaml --ignore-not-found)
    if [[ -z "${result}" ]]; then
        cat <<EOF > /tmp/ibm-cpp-config.yaml
kind: ConfigMap
apiVersion: v1
metadata:
    name: ibm-cpp-config
    namespace: ${CONTROL_NS}
data:
    deployCSCertManagerOperands: "false"
EOF
    else
        ${OC} get configmap ibm-cpp-config -n ${CONTROL_NS} -o yaml | ${YQ} eval 'select(.kind == "ConfigMap") | .data += {"deployCSCertManagerOperands": "'"false"'"}' > /tmp/ibm-cpp-config.yaml
    fi
    
    
    ${OC} apply -f /tmp/ibm-cpp-config.yaml
    if [ $? -ne 0 ]; then
        rm /tmp/ibm-cpp-config.yaml
        error "Failed to patch ibm-cpp-config ConfigMap in ${CONTROL_NS}"
    fi
    rm /tmp/ibm-cpp-config.yaml
    msg ""

    info "Deleting existing Cert Manager CR..."
    ${OC} delete certmanager.operator.ibm.com default --ignore-not-found --timeout=10s
    if [ $? -ne 0 ]; then
        warning "Failed to delete Cert Manager CR, patching its finalizer to null..."
        ${OC} patch certmanagers.operator.ibm.com default --type="json" -p '[{"op": "remove", "path":"/metadata/finalizers"}]'
    fi
    msg ""

    is_exist=$(${OC} get pod -l name=ibm-cert-manager-operator -n ${CONTROL_NS} --ignore-not-found | grep "ibm-cert-manager-operator" || echo "failed")
    if  [[ $is_exist != "failed" ]]; then
        info "Restarting IBM Cloud Pak 2.0 Cert Manager to provide cert-rotation only..."
            ${OC} delete pod -l name=ibm-cert-manager-operator -n ${CONTROL_NS} --ignore-not-found
        msg ""
        wait_for_pod ${CONTROL_NS} "ibm-cert-manager-operator"
    else
        warning "IBM Cloud Pak 2.0 Cert Manager does not exist in namespace ${CONTROL_NS}, skip restarting cert manager pod..."
    fi
    wait_for_no_pod ${CONTROL_NS} "cert-manager-cainjector"
    wait_for_no_pod ${CONTROL_NS} "cert-manager-controller"
    wait_for_no_pod ${CONTROL_NS} "cert-manager-webhook"

}

main $*
