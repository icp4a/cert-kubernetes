#!/bin/bash

# Licensed Materials - Property of IBM
# Copyright IBM Corporation 2023. All Rights Reserved
# US Government Users Restricted Rights -
# Use, duplication or disclosure restricted by GSA ADP Schedule Contract with IBM Corp.
#
# This is an internal component, bundled with an official IBM product. 
# Please refer to that particular license for additional information. 


# ---------- Command variables ----------

# script base directory
BASE_DIR=$(cd $(dirname "$0")/$(dirname "$(readlink $0)") && pwd -P)

# operand namespace
CS_NAMESPACE=

# operators namespace
OPERATORS_NAMESPACE=

# zen namespace
ZEN_NAMESPACE=

# cert-manager namespace
CERT_NAMESPACE=

# license-service namespace
LICSVC_NAMESPACE=

# license-service-reporter namespace
LICSVC_REPORTER_NAMESPACE=

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
    install_policies
}

function install_policies() {
    check_prereqs # TODO: uncomment me

    if [[ -z ${UNINSTALL} ]]; then
        install_networkpolicy
    fi
    if [[ ${UNINSTALL} == "true" ]]; then
        delete_networkpolicy
    fi

    msg "-----------------------------------------------------------------------"
    success "IBM Common Services NetworkPolicies installation or removal completed at $(date) ."
    exit 0
}

function print_usage() {
    script_name=`basename ${0}`
    echo "Usage: ${script_name} [OPTIONS]..."
    echo ""
    echo "Install IBM Common Services NetworkPolicies"
    echo ""
    echo "Options:"
    echo "   -n, --namespace string                               IBM Common Services operand namespace. No default value"
    echo "   -o, --operators-namespace string                     Operators namespace. Default is same namespace as IBM Common Services operand namespace"
    echo "   -z, --zen-namespace string                           Zen namespace. Default is same namespace as IBM Common Services operand namespace"
    echo "   -c, --cert-manager-namespace string                  Cert-manager namespace. No default value"
    echo "   -l, --licensing-namespace string                     License Service namespace. No default value"
    echo "   -lsr, --licensing-svc-reporter-namespace string      License Service Reporter namespace. No default value"
    echo "   -u, --uninstall                                      Uninstall IBM Common Services Network Policies"
    echo "   -e, --egress                                         Deploy egress NetworkPolicies"
    echo "   -h, --help                                           Print usage information"
    echo ""
}

function parse_arguments() {
    # process options
    while [[ "$1" != "" ]]; do
        case "$1" in
        -n | --namespace)
            shift
            CS_NAMESPACE=$1
            ;;
        -o | --operators-namespace)
            shift
            OPERATORS_NAMESPACE=$1
            ;;
        -z | --zen-namespace)
            shift
            ZEN_NAMESPACE=$1
            ;;
        -c | --cert-manager-namespace)
            shift
            CERT_NAMESPACE=$1
            ;;
        -l | --licensing-namespace)
            shift
            LICSVC_NAMESPACE=$1
            ;;
        -lsr | --licensing-svc-reporter-namespace)
            shift
            LICSVC_REPORTER_NAMESPACE=$1
            ;;
        -u | --uninstall)
            UNINSTALL=true
            ;;
        -e | --egress)
            EGRESS=true
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

    # checking for CS_NAMESPACE, if CS_NAMESPACE is not specified, exit
    if [[ ! -z "${CS_NAMESPACE}" ]]; then
        # check existence of CS_NAMESPACE
        cs_namespace_exists=$(oc get project "${CS_NAMESPACE}" 2> /dev/null)
        if [ $? -ne 0 ]; then
            info "Creating IBM Common Services namespace: ${CS_NAMESPACE}"
            oc create namespace "${CS_NAMESPACE}"
        fi
    else
        error "IBM Common Services operand namespace not specified"
    fi

    # if OPERATORS_NAMESPACE is not specified, use CS_NAMESPACE
    if [[ -z "${OPERATORS_NAMESPACE}" && ! -z "${CS_NAMESPACE}" ]]; then
        OPERATORS_NAMESPACE=${CS_NAMESPACE}

        # check existence of OPERATORS_NAMESPACE
        operators_namespace_exists=$(oc get project "${OPERATORS_NAMESPACE}" 2> /dev/null)
        if [ $? -ne 0 ]; then
            info "Creating operators namespace: ${OPERATORS_NAMESPACE}"
            oc create namespace "${OPERATORS_NAMESPACE}"
        fi
    fi

    # checking for ibm-common-service-operator in CS_NAMESPACE
    if [[ -z "$(oc -n ${OPERATORS_NAMESPACE} get csv --ignore-not-found | grep 'ibm-common-service-operator')" ]]; then
        info "IBM Common Services are not installed in namespace ${OPERATORS_NAMESPACE}"
    else
        success "IBM Common Services found in namespace ${OPERATORS_NAMESPACE}"
    fi

    # if ZEN_NAMESPACE is not specified, use CS_NAMESPACE
    if [[ -z "${ZEN_NAMESPACE}" && ! -z "${CS_NAMESPACE}" ]]; then
        ZEN_NAMESPACE=${CS_NAMESPACE}

        # check existence of ZEN_NAMESPACE
        zen_namespace_exists=$(oc get project "${ZEN_NAMESPACE}" 2> /dev/null)
        if [ $? -ne 0 ]; then
            info "Creating Zen namespace: ${ZEN_NAMESPACE}"
            oc create namespace "${ZEN_NAMESPACE}"
        fi
    fi

}

function install_networkpolicy() {
    title "[$(translate_step ${STEP})] Installing IBM Common Services Network Policies ..."
    msg "-----------------------------------------------------------------------"

    info "Using IBM Common Services namespace: ${CS_NAMESPACE}"
    info "Using operators namespace: ${OPERATORS_NAMESPACE}"
    info "Using Zen namespace: ${ZEN_NAMESPACE}"
    info "Using cert-manager namespace: ${CERT_NAMESPACE}"
    info "Using license-service namespace: ${LICSVC_NAMESPACE}"
    info "Using license-service-reporter namespace: ${LICSVC_REPORTER_NAMESPACE}"

    if [[ ${EGRESS} == "true" ]]; then
        BASE_DIR="${BASE_DIR}/egress"
    else
        BASE_DIR="${BASE_DIR}/ingress"
    fi

    if [[ ! -z "${CS_NAMESPACE}" ]]; then
        for policyfile in `ls -1 ${BASE_DIR}/services/*.yaml`; do
            info "Installing `basename ${policyfile}` ..."
            cat ${policyfile} | sed -e "s/csNamespace/${CS_NAMESPACE}/g" | sed -e "s/opNamespace/${OPERATORS_NAMESPACE}/g" | sed -e "s/zenNamespace/${ZEN_NAMESPACE}/g" | oc apply -f -
        done
    fi

    if [[ ! -z "${OPERATORS_NAMESPACE}" ]]; then    
        for policyfile in `ls -1 ${BASE_DIR}/operators/*.yaml`; do
            info "Installing `basename ${policyfile}` ..."
            cat ${policyfile} | sed -e "s/csNamespace/${CS_NAMESPACE}/g" | sed -e "s/opNamespace/${OPERATORS_NAMESPACE}/g" | sed -e "s/zenNamespace/${ZEN_NAMESPACE}/g" | oc apply -f -
        done
    fi

    # Installing cert-manager policies
    if [[ ! -z "${CERT_NAMESPACE}" ]]; then
        for policyfile in `ls -1 ${BASE_DIR}/cert-manager/*.yaml`; do
            info "Installing `basename ${policyfile}` ..."
            cat ${policyfile} | sed -e "s/certNamespace/${CERT_NAMESPACE}/g" | oc apply -f -
        done
    fi

    # Installing license-service policies
    if [[ ! -z "${LICSVC_NAMESPACE}" ]]; then
        for policyfile in `ls -1 ${BASE_DIR}/license-service/*.yaml`; do
            info "Installing `basename ${policyfile}` ..."
            cat ${policyfile} | sed -e "s/licNamespace/${LICSVC_NAMESPACE}/g" | oc apply -f -
        done
    fi

    # Installing license-service-reporter policies
    if [[ ! -z "${LICSVC_REPORTER_NAMESPACE}" ]]; then
        for policyfile in `ls -1 ${BASE_DIR}/license-service-reporter/*.yaml`; do
            info "Installing `basename ${policyfile}` ..."
            cat ${policyfile} | sed -e "s/lsrNamespace/${LICSVC_REPORTER_NAMESPACE}/g" | oc apply -f -
        done
    fi

    # Installing zen policies
    if [[ ! -z "${ZEN_NAMESPACE}" ]]; then
        for policyfile in `ls -1 ${BASE_DIR}/zen/*.yaml`; do
            info "Installing `basename ${policyfile}` ..."
            cat ${policyfile} | sed -e "s/zenNamespace/${ZEN_NAMESPACE}/g" | sed -e "s/csNamespace/${CS_NAMESPACE}/g" | sed -e "s/opNamespace/${OPERATORS_NAMESPACE}/g" | oc apply -f -
        done
    fi

}

function delete_networkpolicy() {
    title "[$(translate_step ${STEP})] Removing IBM Common Services Network Policies ..."
    msg "-----------------------------------------------------------------------"

    if [[ ! -z "${CS_NAMESPACE}" ]]; then
        oc delete networkpolicies -n ${CS_NAMESPACE} --selector=component=cpfs3
    fi

    if [[ ! -z "${OPERATORS_NAMESPACE}" ]]; then
        oc delete networkpolicies -n ${OPERATORS_NAMESPACE} --selector=component=cpfs3
    fi

    if [[ ! -z "${CERT_NAMESPACE}" ]]; then
        oc delete networkpolicies -n ${CERT_NAMESPACE} --selector=component=cpfs3
    fi

    if [[ ! -z "${LICSVC_NAMESPACE}" ]]; then
        oc delete networkpolicies -n ${LICSVC_NAMESPACE} --selector=component=cpfs3
    fi

    if [[ ! -z "${LICSVC_REPORTER_NAMESPACE}" ]]; then
        oc delete networkpolicies -n ${LICSVC_REPORTER_NAMESPACE} --selector=component=cpfs3
    fi

    if [[ ! -z "${ZEN_NAMESPACE}" ]]; then
        oc delete networkpolicies -n ${ZEN_NAMESPACE} --selector=component=cpfs3
    fi

}

# --- Run ---

main $*
