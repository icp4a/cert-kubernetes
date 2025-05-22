#!/usr/bin/env bash

# Licensed Materials - Property of IBM
# Copyright IBM Corporation 2024. All Rights Reserved
# US Government Users Restricted Rights -
# Use, duplication or disclosure restricted by GSA ADP Schedule Contract with IBM Corp.
#
# This is an internal component, bundled with an official IBM product. 
# Please refer to that particular license for additional information. 

# ---------- Command variables ----------

# script base directory
BASE_DIR=$(cd $(dirname "$0")/$(dirname "$(readlink $0)") && pwd -P)

# services namespace
SERVICES_NAMESPACE=

# cert-manager namespace
CERT_NAMESPACE="ibm-cert-manager"

# is uninstall flag?
UNINSTALL=

IFS='
'


# counter to keep track of installation steps
STEP=0

# ---------- Main functions ----------

function msg() {
    printf '%b\n' "$1"
}

function info() {
    msg "[INFO] ${1}"
}

function success() {
    msg "\33[32m[✔] ${1}\33[0m"
}

function warning() {
    msg "\33[33m[✗] ${1}\33[0m"
}

function error() {
    msg "\33[31m[✘] ${1}\33[0m"
    exit 1
}

function title() {
    msg "\33[34m# ${1}\33[0m"
}

function translate_step() {
    local step=$1
    echo "${step}" | tr '[1-9]' '[a-i]'
}

function main() {
    parse_arguments "$@"
    install_orms
}

function install_orms() {
    check_prereqs

    if [[ -z ${UNINSTALL} ]]; then
        install_orm
    fi
    if [[ ${UNINSTALL} == "true" ]]; then
        delete_orm
    fi

    msg "-----------------------------------------------------------------------"
    success "IBM Cloud Pak foundational services OperatorResourceMapping installation or removal completed at $(date) ."
    exit 0
}

function print_usage() {
    script_name=`basename ${0}`
    echo "Usage: ${script_name} [OPTIONS]..."
    echo ""
    echo "Install IBM Cloud Pak foundational services OperatorResourceMapping"
    echo ""
    echo "Options:"
    echo "   -n, --namespace string       IBM Cloud Pak foundational services namespace. Default is same namespace as IBM Cloud Pak foundational services"
    echo "   -u, --uninstall              Uninstall IBM Cloud Pak foundational services OperatorResourceMapping"
    echo "   -h, --help                   Print usage information"
    echo ""
}

function parse_arguments() {
    # process options
    while [[ "$1" != "" ]]; do
        case "$1" in
        -n | --namespace)
            shift
            SERVICES_NAMESPACE=$1
            ;;
        -c | --cert-manager-namespace)
            shift
            CERT_NAMESPACE=$1
            ;;
        -u | --uninstall)
            shift
            UNINSTALL=true
            ;;
        -h | --help)
            print_usage
            exit 1
            ;;
        *) 
            ;;
        esac
        shift
    done
}

# ---------- Supporting functions ----------

function check_prereqs() {
    title "[$(translate_step ${STEP})] Checking prerequisites ..."
    msg "-----------------------------------------------------------------------"

    # checking oc command
    if [[ -z "$(command -v oc 2> /dev/null)" ]]; then
        error "oc command not available"
    else
        success "oc command available"
    fi

    # checking oc command logged in
    user=$(oc whoami 2> /dev/null)
    if [ $? -ne 0 ]; then
        error "You must be logged into the OpenShift Cluster from the oc command line"
    else
        success "oc command logged in as ${user}"
    fi

    # checking for SERVICES_NAMESPACE
    if [[ -z "${SERVICES_NAMESPACE}" ]]; then
        SERVICES_NAMESPACE=$(oc project -q)
    fi

    # checking for OperandRegistry in SERVICES_NAMESPACE
    if [[ -z "$(oc -n ${SERVICES_NAMESPACE} get operandregistry common-service --ignore-not-found)" ]]; then
        info "Missing OperandRegistry, likely IBM Cloud Pak foundational services are not installed in namespace ${SERVICES_NAMESPACE}"
    else
        success "Found OperandRegistry common-service in namespace ${SERVICES_NAMESPACE}"
    fi

}

function install_orm() {
    title "[$(translate_step ${STEP})] Installing IBM Cloud Pak foundational services OperatorResourceMapping ..."
    msg "-----------------------------------------------------------------------"

    info "Using IBM Cloud Pak foundational services namespace: ${SERVICES_NAMESPACE}"

    local dir="${BASE_DIR}/operands"
    
    for file in `ls -1 ${dir}/*.yaml`; do
        info "Installing `basename ${file}` ..."
        cat ${file} | sed -e "s/{{ placeholder_namespace }}/${SERVICES_NAMESPACE}/g" \
            | sed -e "s/{{ placeholder_cert_namespace }}/${CERT_NAMESPACE}/g" \
            | oc apply -f -
    done

}

function delete_orm() {
    title "[$(translate_step ${STEP})] Removing IBM Cloud Pak foundational services OperatorResourceMapping ..."
    msg "-----------------------------------------------------------------------"

    oc delete operatorresourcemapping -n ${SERVICES_NAMESPACE} --selector=component=cpfs

    local is_cert_orm=$(oc get operatorresourcemapping -n ${CERT_NAMESPACE} --ignore-not-found | grep "cert-manager")
    if [ ! -z ${is_cert_orm} ]; then
        warning "Must manually delete OperatorResourceMapping for ibm-cert-manager because other tenants could be using it"
    fi
}

# --- Run ---

main $*

